extends GdUnitTestSuite

const SeedPandora := preload("res://tools/seed_pandora.gd")

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
	DirAccess.make_dir_recursive_absolute(_canon_root.path_join("dom/factions"))


func after_test() -> void:
	Pandora._entity_backend._clear()
	Pandora._entity_backend = _original_backend
	Pandora._id_generator = _original_ids
	_original_backend = null
	_original_ids = null
	for filename: String in _fixture_files:
		DirAccess.remove_absolute(filename)
	DirAccess.remove_absolute(_canon_root.path_join("dom/factions"))
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
