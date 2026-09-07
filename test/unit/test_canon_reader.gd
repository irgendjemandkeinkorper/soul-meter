extends GdUnitTestSuite

const SeedPandora := preload("res://tools/seed_pandora.gd")

const KINDS := ["factions", "elements", "classes", "peoples", "lore"]

var _original_backend: PandoraEntityBackend
var _original_ids: PandoraIDGenerator
var _canon_root: String
var _fixture_files: Array[String] = []


func before_test() -> void:
	if not Pandora.is_loaded():
		Pandora.load_data()
	# Seed only an isolated in-memory copy; keep all shared runtime references intact.
	_original_backend = Pandora._entity_backend
	_original_ids = Pandora._id_generator
	Pandora._id_generator = PandoraIDGenerator.new()
	Pandora._id_generator.load_data(_original_ids.save_data().duplicate(true))
	Pandora._entity_backend = PandoraEntityBackend.new(Pandora._id_generator)
	Pandora._entity_backend.load_data(_original_backend.save_data().duplicate(true))
	_canon_root = "user://canon-reader-%d" % Time.get_ticks_usec()
	_fixture_files.clear()
	for kind: String in KINDS:
		DirAccess.make_dir_recursive_absolute(_canon_root.path_join("dom").path_join(kind))


func after_test() -> void:
	Pandora._entity_backend._clear()
	Pandora._entity_backend = _original_backend
	Pandora._id_generator = _original_ids
	_original_backend = null
	_original_ids = null
	for filename: String in _fixture_files:
		DirAccess.remove_absolute(filename)
	for kind: String in KINDS:
		DirAccess.remove_absolute(_canon_root.path_join("dom").path_join(kind))
	DirAccess.remove_absolute(_canon_root.path_join("dom"))
	DirAccess.remove_absolute(_canon_root)


func test_load_returns_all_factions_with_unique_stable_ids() -> void:
	var factions: Array[Dictionary] = SeedPandora.CanonReader.load("factions")
	var stable_ids: Dictionary = {}

	assert_int(factions.size()).is_equal(18)
	for faction: Dictionary in factions:
		assert_str(faction.get("schema", "")).is_equal("weftlumin.faction.v1")
		assert_str(faction.get("id", "")).is_not_empty()
		assert_bool(stable_ids.has(faction["id"])).is_false()
		stable_ids[faction["id"]] = true


func test_load_is_deterministic() -> void:
	var first_load: Array[Dictionary] = SeedPandora.CanonReader.load("factions")
	var second_load: Array[Dictionary] = SeedPandora.CanonReader.load("factions")

	assert_array(first_load).is_equal(second_load)


func test_faction_reseed_upserts_instead_of_creating_duplicates() -> void:
	if not Pandora.is_loaded():
		Pandora.load_data()
	var faction_root: PandoraCategory = _faction_root()
	var before_count: int = Pandora.get_all_entities(faction_root).size()
	var seeder: Node = SeedPandora.new()

	seeder._seed_factions()

	var after_count: int = Pandora.get_all_entities(faction_root).size()
	assert_int(after_count).is_equal(before_count)
	seeder.free()


func test_new_faction_reseed_uses_id_independent_of_display_name() -> void:
	var row: Dictionary = _row("new-order", "The New Order")
	_write_document("new-order.json", row)
	var seeder: Node = auto_free(SeedPandora.new())
	var before_count: int = Pandora.get_all_entities(_faction_root()).size()
	seeder._seed_factions(_canon_root)
	row["display_name"] = "A Different Banner"
	_write_document("new-order.json", row)
	seeder._seed_factions(_canon_root)
	assert_int(Pandora.get_all_entities(_faction_root()).size()).is_equal(before_count + 1)
	var entity: PandoraEntity = seeder._find_by_stable_id(_faction_root(), "new-order")
	assert_object(entity).is_not_null()
	if entity != null:
		assert_str(entity.get_entity_name()).is_equal("new-order")
		assert_str(entity.get_entity_property("Display Name").get_default_value()).is_equal(
			"A Different Banner"
		)


func test_exact_internal_id_wins_over_legacy_slug_match() -> void:
	var root: PandoraCategory = _faction_root()
	Pandora.create_entity("Test Identity", root)
	var exact: PandoraEntity = Pandora.create_entity("test-identity", root)
	var seeder: Node = auto_free(SeedPandora.new())
	var found: PandoraEntity = seeder._find_by_stable_id(root, "test-identity")
	assert_str(found.get_entity_id()).is_equal(exact.get_entity_id())


func test_distinct_canon_ids_cannot_alias_through_legacy_slug_fallback() -> void:
	_write_document("a.json", _row("New_Order", "First Order"))
	_write_document("b.json", _row("new-order", "Second Order"))
	var seeder: Node = auto_free(SeedPandora.new())
	var before_count: int = Pandora.get_all_entities(_faction_root()).size()
	seeder._seed_factions(_canon_root)
	seeder._seed_factions(_canon_root)
	assert_int(Pandora.get_all_entities(_faction_root()).size()).is_equal(before_count + 2)
	var first: PandoraEntity = seeder._find_by_stable_id(_faction_root(), "New_Order")
	var second: PandoraEntity = seeder._find_by_stable_id(_faction_root(), "new-order")
	assert_str(first.get_entity_id()).is_not_equal(second.get_entity_id())
	assert_str(first.get_entity_property("Display Name").get_default_value()).is_equal("First Order")
	assert_str(second.get_entity_property("Display Name").get_default_value()).is_equal("Second Order")


func test_incremental_ambiguous_ids_after_reload_refuse_without_mutation() -> void:
	_write_document("a.json", _row("New_Order", "New_Order"))
	var initial_seeder: Node = auto_free(SeedPandora.new())
	assert_bool(initial_seeder._seed_factions(_canon_root)).is_true()
	var saved_data: Dictionary = Pandora._entity_backend.save_data().duplicate(true)
	Pandora._entity_backend._clear()
	Pandora._entity_backend.load_data(saved_data)
	_write_document("b.json", _row("new-order", "Second Order"))
	var seeder: Node = auto_free(SeedPandora.new())
	var before: String = JSON.stringify(Pandora._entity_backend.save_data())
	var ids_before: String = JSON.stringify(Pandora._id_generator.save_data())
	var result: Array[bool] = [true]
	var error := "CANON-SEED: faction ids 'New_Order' and 'new-order' claim the same existing entity."
	await assert_error(func(): result[0] = seeder._seed_factions(_canon_root)).is_push_error(error)
	assert_bool(result[0]).is_false()
	assert_str(JSON.stringify(Pandora._entity_backend.save_data())).is_equal(before)
	assert_str(JSON.stringify(Pandora._id_generator.save_data())).is_equal(ids_before)


func test_ambiguous_claim_on_existing_legacy_entity_refuses_all_updates() -> void:
	_write_document("a-new-claim.json", _row("The Registry", "A Different Organization"))
	_write_document("b-legacy-id.json", _row("the-registry", "The Existing Registry"))
	var seeder: Node = auto_free(SeedPandora.new())
	var before: String = JSON.stringify(Pandora._entity_backend.save_data())
	var ids_before: String = JSON.stringify(Pandora._id_generator.save_data())
	var result: Array[bool] = [true]
	var error := (
		"CANON-SEED: faction ids 'The Registry' and 'the-registry' "
		+ "claim the same existing entity."
	)
	await assert_error(func(): result[0] = seeder._seed_factions(_canon_root)).is_push_error(error)
	assert_bool(result[0]).is_false()
	assert_bool(JSON.stringify(Pandora._entity_backend.save_data()) == before).is_true()
	assert_str(JSON.stringify(Pandora._id_generator.save_data())).is_equal(ids_before)
	await assert_error(func(): result[0] = seeder._seed_from_canon(_canon_root)).is_push_error(error)
	assert_bool(result[0]).is_false()
	assert_bool(JSON.stringify(Pandora._entity_backend.save_data()) == before).is_true()
	assert_str(JSON.stringify(Pandora._id_generator.save_data())).is_equal(ids_before)


func test_existing_canon_reseed_preserves_all_authored_pandora_data() -> void:
	var before: String = JSON.stringify(Pandora._entity_backend.save_data())
	var ids_before: String = JSON.stringify(Pandora._id_generator.save_data())
	var seeder: Node = auto_free(SeedPandora.new())
	seeder._seed_factions()
	assert_str(JSON.stringify(Pandora._entity_backend.save_data())).is_equal(before)
	assert_str(JSON.stringify(Pandora._id_generator.save_data())).is_equal(ids_before)


func test_malformed_document_refuses_all_faction_updates() -> void:
	_write_document("a-valid.json", _row("the-registry", "Must not overwrite the Registry"))
	_write_text("z-invalid.json", "{ malformed")
	var before: String = JSON.stringify(Pandora._entity_backend.save_data())
	var seeder: Node = auto_free(SeedPandora.new())
	await assert_error(seeder._seed_factions.bind(_canon_root)).is_push_error(
		"CANON-SEED: %s must contain one JSON object." % _fixture_path("z-invalid.json")
	)
	assert_str(JSON.stringify(Pandora._entity_backend.save_data())).is_equal(before)


func test_required_fields_reject_missing_and_wrong_types_before_updates() -> void:
	var seeder: Node = auto_free(SeedPandora.new())
	var before: String = JSON.stringify(Pandora._entity_backend.save_data())
	for field: String in ["schema", "id", "display_name", "summary", "seat", "vault_id"]:
		for missing: bool in [true, false]:
			var row: Dictionary = _row("the-registry", "Must not overwrite the Registry")
			if missing:
				row.erase(field)
			else:
				row[field] = 42
			_write_document("invalid.json", row)
			await assert_error(seeder._seed_factions.bind(_canon_root)).is_push_error(
				"CANON-SEED: %s requires string '%s'." % [_fixture_path("invalid.json"), field]
			)
			assert_str(JSON.stringify(Pandora._entity_backend.save_data())).is_equal(before)


func test_duplicate_stable_ids_refuse_all_faction_updates() -> void:
	_write_document("a-first.json", _row("the-registry", "Must not overwrite the Registry"))
	_write_document("z-second.json", _row("the-registry", "Duplicate"))
	var before: String = JSON.stringify(Pandora._entity_backend.save_data())
	var seeder: Node = auto_free(SeedPandora.new())
	await assert_error(seeder._seed_factions.bind(_canon_root)).is_push_error(
		"CANON-SEED: duplicate faction id 'the-registry' in %s." % _fixture_path("z-second.json")
	)
	assert_str(JSON.stringify(Pandora._entity_backend.save_data())).is_equal(before)


func test_shared_vault_ids_are_valid_and_do_not_merge_factions() -> void:
	_write_document("a.json", _row("test-first-order", "First Order"))
	_write_document("b.json", _row("test-second-order", "Second Order"))
	var seeder: Node = auto_free(SeedPandora.new())
	var before_count: int = Pandora.get_all_entities(_faction_root()).size()
	seeder._seed_factions(_canon_root)
	seeder._seed_factions(_canon_root)
	assert_int(Pandora.get_all_entities(_faction_root()).size()).is_equal(before_count + 2)
	var first: PandoraEntity = seeder._find_by_stable_id(_faction_root(), "test-first-order")
	var second: PandoraEntity = seeder._find_by_stable_id(_faction_root(), "test-second-order")
	assert_str(first.get_entity_id()).is_not_equal(second.get_entity_id())


func test_unsupported_schema_and_empty_identity_are_rejected() -> void:
	var seeder: Node = auto_free(SeedPandora.new())
	var before: String = JSON.stringify(Pandora._entity_backend.save_data())
	var row: Dictionary = _row("the-registry", "Must not overwrite the Registry")
	row["schema"] = "weftlumin.faction.v2"
	_write_document("invalid.json", row)
	await assert_error(seeder._seed_factions.bind(_canon_root)).is_push_error(
		"CANON-SEED: unsupported faction schema in %s." % _fixture_path("invalid.json")
	)
	row["schema"] = "weftlumin.faction.v1"
	row["id"] = "   "
	_write_document("invalid.json", row)
	await assert_error(seeder._seed_factions.bind(_canon_root)).is_push_error(
		"CANON-SEED: empty faction id in %s." % _fixture_path("invalid.json")
	)
	assert_str(JSON.stringify(Pandora._entity_backend.save_data())).is_equal(before)


func test_invalid_canon_refuses_empty_database_initialization() -> void:
	Pandora._entity_backend._clear()
	_write_document("a-valid.json", _row("test-order", "Test Order"))
	_write_text("z-invalid.json", "[]")
	var seeder: Node = auto_free(SeedPandora.new())
	var result: Array[bool] = [true]
	await assert_error(func(): result[0] = seeder._seed_from_canon(_canon_root)).is_push_error(
		"CANON-SEED: %s must contain one JSON object." % _fixture_path("z-invalid.json")
	)
	assert_bool(result[0]).is_false()
	assert_array(Pandora.get_all_roots()).is_empty()


func test_empty_faction_set_is_not_a_successful_seed() -> void:
	var seeder: Node = auto_free(SeedPandora.new())
	var before: String = JSON.stringify(Pandora._entity_backend.save_data())
	var result: Array[bool] = [true]
	await assert_error(func(): result[0] = seeder._seed_from_canon(_canon_root)).is_push_error(
		"CANON-SEED: no faction documents found in %s." % _canon_root
	)
	assert_bool(result[0]).is_false()
	assert_str(JSON.stringify(Pandora._entity_backend.save_data())).is_equal(before)


# --- E1.4a: elements, classes and peoples --------------------------------------------------


func test_the_wheel_loads_in_wheel_order_and_not_in_filename_order() -> void:
	# The order is canon, not incidental: ring distance and the clash pairs are read off it, and
	# `DirAccess.get_files_at()` sorts alphabetically. Without the explicit `order` field the
	# wheel would silently load as khash, khor, luth, ... and nothing else here would notice.
	var elements: Array[Dictionary] = SeedPandora.CanonReader.load("elements")
	assert_int(elements.size()).is_equal(10)

	var loaded_ids: Array[String] = []
	for element: Dictionary in elements:
		loaded_ids.append(String(element["id"]))
	var token_ids: Array[String] = []
	for token: Dictionary in DS.WHEEL:
		token_ids.append(String(token["id"]))
	assert_array(loaded_ids).is_equal(token_ids)

	var alphabetical: Array[String] = loaded_ids.duplicate()
	alphabetical.sort()
	assert_array(loaded_ids).override_failure_message(
		"the wheel happens to be alphabetical, so this test no longer proves anything"
	).is_not_equal(alphabetical)


func test_every_element_has_a_design_system_token_and_the_reverse() -> void:
	# Canon owns identity and order; `DS.WHEEL` owns sigil, colour and glow, because those are
	# design tokens synced from the design-system project and copying their hex into canon/
	# would create a second source to drift. The two lists must agree in both directions — an
	# eleventh element added on either side is what this catches.
	var seeder: Node = auto_free(SeedPandora.new())
	var elements: Array[Dictionary] = SeedPandora.CanonReader.load("elements")
	assert_bool(seeder._elements_match_the_design_system(elements)).is_true()

	var extra: Array[Dictionary] = elements.duplicate()
	extra.append({"schema": "weftlumin.element.v1", "id": "eleventh", "display_name": "Eleventh",
		"order": 10, "clash": "sul"})
	var matched: Array[bool] = [true]
	await assert_error(
		func(): matched[0] = seeder._elements_match_the_design_system(extra)
	).is_push_error("CANON-SEED: element 'eleventh' has no DS.WHEEL token.")
	assert_bool(matched[0]).is_false()


func test_the_real_clash_pairs_are_symmetric() -> void:
	var elements: Array[Dictionary] = SeedPandora.CanonReader.load("elements")
	var clash_by_id: Dictionary = {}
	for element: Dictionary in elements:
		clash_by_id[element["id"]] = element["clash"]
	for element_id: String in clash_by_id:
		assert_str(String(clash_by_id[clash_by_id[element_id]])).override_failure_message(
			"'%s' clashes with '%s', which must clash back" % [element_id, clash_by_id[element_id]]
		).is_equal(element_id)


func test_a_one_sided_clash_refuses_the_whole_element_set() -> void:
	# Two documents each name their opposite independently, so a rename that touched only one
	# side would otherwise seed a half-broken wheel and surface much later as a wrong matrix.
	_write_wheel_fixture({"sul": "mozh"})
	var loaded: Array[Array] = [[{}]]
	await assert_error(
		func(): loaded[0] = SeedPandora.CanonReader.load("elements", _canon_root)
	).is_push_error("CANON-SEED: clash is not symmetric — 'sul' names 'mozh', which names 'vel'.")
	assert_array(loaded[0]).is_empty()


func test_an_element_clashing_with_something_that_does_not_exist_is_refused() -> void:
	_write_wheel_fixture({"sul": "nowhere"})
	var loaded: Array[Array] = [[{}]]
	await assert_error(
		func(): loaded[0] = SeedPandora.CanonReader.load("elements", _canon_root)
	).is_push_error("CANON-SEED: element 'sul' clashes with unknown 'nowhere'.")
	assert_array(loaded[0]).is_empty()


func test_an_ordered_kind_rejects_a_document_with_no_order() -> void:
	_write_wheel_fixture({})
	var row: Dictionary = _element_row("sul", 0, "vekh")
	row.erase("order")
	_write_kind("elements", "sul.json", row)
	var loaded: Array[Array] = [[{}]]
	await assert_error(
		func(): loaded[0] = SeedPandora.CanonReader.load("elements", _canon_root)
	).is_push_error(
		"CANON-SEED: %s requires numeric 'order'." % _kind_path("elements", "sul.json")
	)
	assert_array(loaded[0]).is_empty()


func test_classes_and_peoples_load_with_the_fields_the_seeder_assigns() -> void:
	var classes: Array[Dictionary] = SeedPandora.CanonReader.load("classes")
	assert_int(classes.size()).is_equal(10)
	for row: Dictionary in classes:
		for field: String in ["id", "display_name", "patron", "resource_name", "vault_id"]:
			assert_str(String(row.get(field, ""))).is_not_empty()

	var peoples: Array[Dictionary] = SeedPandora.CanonReader.load("peoples")
	assert_int(peoples.size()).is_equal(9)
	for row: Dictionary in peoples:
		for field: String in ["id", "display_name", "analogue", "homeland", "vault_id"]:
			assert_str(String(row.get(field, ""))).is_not_empty()


func test_reseeding_the_three_migrated_kinds_creates_no_duplicates() -> void:
	var seeder: Node = auto_free(SeedPandora.new())
	var before: Dictionary = {}
	for root_name: String in ["Elements", "Classes", "Peoples"]:
		before[root_name] = Pandora.get_all_entities(_root(root_name)).size()

	for _repeat: int in 2:
		seeder._apply_elements(SeedPandora.CanonReader.load("elements"))
		seeder._apply_classes(SeedPandora.CanonReader.load("classes"))
		seeder._apply_peoples(SeedPandora.CanonReader.load("peoples"))

	for root_name: String in ["Elements", "Classes", "Peoples"]:
		assert_int(Pandora.get_all_entities(_root(root_name)).size()).override_failure_message(
			"%s gained entities on a re-seed" % root_name
		).is_equal(int(before[root_name]))


func test_a_full_reseed_from_real_canon_changes_nothing() -> void:
	# The same property CI's CANON-SEED drift stage checks, asserted here so a break shows up as
	# a named test rather than as a red stage with a stringified database to read.
	var before: String = JSON.stringify(Pandora._entity_backend.save_data())
	var ids_before: String = JSON.stringify(Pandora._id_generator.save_data())
	var seeder: Node = auto_free(SeedPandora.new())
	assert_bool(seeder._seed_from_canon()).is_true()
	assert_str(JSON.stringify(Pandora._entity_backend.save_data())).is_equal(before)
	assert_str(JSON.stringify(Pandora._id_generator.save_data())).is_equal(ids_before)


func test_element_names_still_resolve_through_the_legacy_slug_fallback() -> void:
	# The committed entities are named "Sul", not "sul", so the migration only avoids creating
	# duplicates because `_find_by_stable_id` falls back to the slug. Pinned because renaming an
	# id to something whose slug no longer matches would silently double the wheel.
	var seeder: Node = auto_free(SeedPandora.new())
	for element: Dictionary in SeedPandora.CanonReader.load("elements"):
		var entity: PandoraEntity = seeder._find_by_stable_id(_root("Elements"), element["id"])
		assert_object(entity).override_failure_message(
			"no existing entity resolves for element id '%s'" % element["id"]
		).is_not_null()


# --- E1.4f: lore bridge rows -------------------------------------------------------------


func test_lore_documents_bridge_to_the_vault_without_conflating_the_two_ids() -> void:
	# A lore document's own id and its `vault_id` are different fields on purpose: "The Soul
	# Gauge" bridges to `souls`, "The Taubstummers" to `last-great-war`. Collapsing them would
	# look harmless until a bridge stopped resolving.
	var lore: Array[Dictionary] = SeedPandora.CanonReader.load("lore")
	assert_int(lore.size()).is_equal(6)
	var differing: int = 0
	for row: Dictionary in lore:
		for field: String in ["id", "display_name", "summary", "vault_id", "vault_path"]:
			assert_str(String(row.get(field, ""))).is_not_empty()
		assert_str(String(row["vault_path"])).ends_with(".md")
		if String(row["vault_id"]) != String(row["id"]):
			differing += 1
	assert_int(differing).override_failure_message(
		"no document distinguishes its own id from its vault_id, so the test proves nothing"
	).is_greater(0)


func test_reseeding_lore_creates_no_duplicates() -> void:
	var seeder: Node = auto_free(SeedPandora.new())
	var before: int = Pandora.get_all_entities(_root("Lore")).size()
	for _repeat: int in 2:
		seeder._apply_lore(SeedPandora.CanonReader.load("lore"))
	assert_int(Pandora.get_all_entities(_root("Lore")).size()).is_equal(before)


func test_lore_names_still_resolve_through_the_legacy_slug_fallback() -> void:
	var seeder: Node = auto_free(SeedPandora.new())
	for row: Dictionary in SeedPandora.CanonReader.load("lore"):
		assert_object(
			seeder._find_by_stable_id(_root("Lore"), row["id"])
		).override_failure_message(
			"no existing entity resolves for lore id '%s'" % row["id"]
		).is_not_null()


func test_a_malformed_lore_document_refuses_the_whole_seed() -> void:
	var row: Dictionary = {
		"schema": "weftlumin.lore.v1",
		"id": "test-entry",
		"display_name": "Test Entry",
		"summary": "A test summary.",
		"vault_id": "test-entry",
	}
	_write_kind("lore", "test-entry.json", row)
	var loaded: Array[Array] = [[{}]]
	await assert_error(
		func(): loaded[0] = SeedPandora.CanonReader.load("lore", _canon_root)
	).is_push_error(
		"CANON-SEED: %s requires string 'vault_path'." % _kind_path("lore", "test-entry.json")
	)
	assert_array(loaded[0]).is_empty()


func _element_row(element_id: String, order: int, clash: String) -> Dictionary:
	return {
		"schema": "weftlumin.element.v1",
		"id": element_id,
		"display_name": element_id.capitalize(),
		"order": order,
		"clash": clash,
	}


## Writes the ten real elements into the fixture root, with `overrides` replacing clashes.
func _write_wheel_fixture(overrides: Dictionary) -> void:
	for element: Dictionary in SeedPandora.CanonReader.load("elements"):
		var element_id: String = element["id"]
		var clash: String = String(overrides.get(element_id, element["clash"]))
		_write_kind(
			"elements", "%s.json" % element_id,
			_element_row(element_id, int(element["order"]), clash)
		)


func _kind_path(kind: String, filename: String) -> String:
	return _canon_root.path_join("dom").path_join(kind).path_join(filename)


func _write_kind(kind: String, filename: String, row: Dictionary) -> void:
	var path: String = _kind_path(kind, filename)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(row))
	file.close()
	if not _fixture_files.has(path):
		_fixture_files.append(path)


func _root(root_name: String) -> PandoraCategory:
	for root: PandoraCategory in Pandora.get_all_roots():
		if root.get_entity_name() == root_name:
			return root
	return null


func _fixture_path(filename: String) -> String:
	return _canon_root.path_join("dom/factions").path_join(filename)


func _row(stable_id: String, display_name: String) -> Dictionary:
	return {
		"schema": "weftlumin.faction.v1",
		"id": stable_id,
		"display_name": display_name,
		"summary": "Test summary",
		"seat": "Test seat",
		"vault_id": "shared-test-vault",
	}


func _write_document(filename: String, row: Dictionary) -> void:
	_write_text(filename, JSON.stringify(row))


func _write_text(filename: String, contents: String) -> void:
	var path: String = _fixture_path(filename)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()
	if not _fixture_files.has(path):
		_fixture_files.append(path)


func _faction_root() -> PandoraCategory:
	for root: PandoraCategory in Pandora.get_all_roots():
		if root.get_entity_name() == "Factions":
			return root
	return null
