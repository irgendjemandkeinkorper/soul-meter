extends GdUnitTestSuite
## E5.1 (#347): the `characters` kind (weftlumin.character.v1) — open kind and stat-schema
## registries declared by the adapter, opaque stats, the vault_id rules — and the generator's
## roster/placement emit from canon.
## Acceptance: the roster/placements generated from canon match the committed JSON
## byte-for-byte; a recruit without a vault_id is refused.

const SeedPandora := preload("res://tools/seed_pandora.gd")
const GenerateGloot := preload("res://tools/generate_gloot.gd")
const PickersScript := preload("res://weftlumin/panels/pickers.gd")
const AdapterScript := preload("res://addons/weftlumin/shell/soul_meter_adapter.gd")
const ROSTER_PATH := "res://data/generated/dom_npc_roster.json"
const PLACEMENTS_PATH := "res://data/generated/dom_npc_placements.json"
const SCRATCH := "user://gdunit-weftlumin-characters"
const VAULT_FIXTURE := SCRATCH + "/index.json"

var _kind: WeftluminCharactersKind


func before_test() -> void:
	_remove_tree(SCRATCH)
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	var index := FileAccess.open(VAULT_FIXTURE, FileAccess.WRITE)
	index.store_string(JSON.stringify({"entities": [
		{"id": "serai-lun", "name": "Serai-Lun", "type": "character"},
		{"id": "themka-gaath", "name": "Themka Gaath", "type": "character"},
		{"id": "trial-council", "name": "Trial Council", "type": "faction"},
	]}))
	index.close()
	_kind = WeftluminCharactersKind.soul_meter()
	_kind.vault_index_path_for_tests = VAULT_FIXTURE


func after_test() -> void:
	_remove_tree(SCRATCH)


func _canon() -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var documents: Array[Dictionary] = WeftluminCharactersKind.load_canon(errors)
	assert_array(errors).is_empty()
	var normalised: Array[Dictionary] = _kind.validate(documents, errors)
	assert_array(errors).override_failure_message(str(errors)).is_empty()
	return normalised


func _codes(document: Dictionary) -> Array[String]:
	var errors: Array[Dictionary] = []
	var batch: Array[Dictionary] = [document]
	var normalised: Array[Dictionary] = _kind.validate(batch, errors)
	assert_bool(normalised.is_empty() != errors.is_empty()).is_true()
	return _codes_of(errors)


static func _codes_of(errors: Array[Dictionary]) -> Array[String]:
	var codes: Array[String] = []
	for error: Dictionary in errors:
		codes.append(String(error["code"]))
	return codes


func _recruit(vault_id: String = "serai-lun") -> Dictionary:
	return _kind.skeleton("recruit", "probe-recruit", "Probe Recruit", vault_id, 900)


func _canon_document(character_id: String) -> Dictionary:
	for row: Dictionary in _canon():
		if row["id"] == character_id:
			return row
	return {}


# --- canon --------------------------------------------------------------------------------


func test_every_canon_character_validates_and_the_bake_is_clean() -> void:
	var rows: Array[Dictionary] = _canon()
	var kinds: Dictionary = {}
	var npcs_by_hub: Dictionary = {}
	for row: Dictionary in rows:
		kinds[row["kind"]] = int(kinds.get(row["kind"], 0)) + 1
		if row["kind"] == "npc":
			var hub: String = String(row[WeftluminCharactersKind.META_HUB])
			npcs_by_hub[hub] = int(npcs_by_hub.get(hub, 0)) + 1
	assert_dict(kinds).is_equal({"npc": 80, "archetype": 6})
	# Dom's sixty stay exactly sixty; Kesselford (C1 / #238) and Ashlaren (C2 / #239) add six each,
	# the Long Verge camp (C3 / #240, a roster town that is not a hub) adds five, and Hollowmere's
	# three posted outsiders (C4 / #241) follow the same pattern.
	assert_dict(npcs_by_hub).is_equal({"dom": 60, "kesselford": 6, "ashlaren": 6, "long_verge": 5, "hollowmere": 3})
	var report: Dictionary = _kind.bake(rows, "res://", false, false)
	assert_bool(WeftluminCharactersKind.report_is_clean(report)).override_failure_message(str(report)).is_true()
	assert_array(report["regenerated"]).is_empty()


func test_canon_text_reproduces_every_canonically_written_document() -> void:
	# Two authored files predate the canonical writer (an escaped em dash, a missing final
	# newline); every other file is exactly what canon_text writes, and all are same_content.
	var differing: Array[String] = []
	for row: Dictionary in _canon():
		var path: String = row[WeftluminCharactersKind.META_FILE]
		var text: String = FileAccess.get_file_as_string(path)
		assert_bool(WeftluminCharactersKind.same_content(JSON.parse_string(text), row)).is_true()
		if WeftluminCharactersKind.canon_text(row) != text:
			differing.append(path.get_file())
	assert_array(differing).contains_exactly_in_any_order(["loam-maddened-boar.json", "themka-gaath.json"])


func test_npc_and_archetype_contracts_match_the_canon_reader() -> void:
	var reader: Dictionary = SeedPandora.CanonReader.SCHEMAS["characters"]["kinds"]
	for kind_name: String in ["npc", "archetype"]:
		var scoped: Dictionary = reader[kind_name]
		var shapes: Dictionary = _kind.field_shapes(kind_name)
		for field: String in scoped.get("fields", []):
			assert_str(String(shapes.get(field, ""))).override_failure_message("%s.%s" % [kind_name, field]) \
				.is_equal(WeftluminCharactersKind.STRING)
			assert_bool(_kind.is_required(kind_name, field)).is_true()
		for pair: Array in [
			["number_pairs", WeftluminCharactersKind.NUMBER_PAIR], ["booleans", WeftluminCharactersKind.BOOLEAN],
			["routines", WeftluminCharactersKind.ROUTINE], ["stat_blocks", WeftluminCharactersKind.STATS],
			["anatomy_maps", WeftluminCharactersKind.ANATOMY],
		]:
			for field: String in scoped.get(pair[0], []):
				assert_str(String(shapes.get(field, ""))).is_equal(pair[1])
		for field: String in scoped.get("stat_blocks", []):
			assert_bool(_kind.is_required(kind_name, field)).is_true()


# --- generator: roster/placements from canon ----------------------------------------------


func test_roster_and_placements_generated_from_canon_match_the_committed_json() -> void:
	var factions: Dictionary = {}
	for faction: Dictionary in SeedPandora.CanonReader.load("factions"):
		factions[String(faction["vault_id"])] = true
	var artifacts: Dictionary = GenerateGloot.npc_artifacts_from_canon(SeedPandora.CanonReader.load("characters"), factions)
	assert_int(int(artifacts["count"])).is_equal(60)
	assert_str(artifacts["roster_json"]).is_equal(FileAccess.get_file_as_string(ROSTER_PATH))
	assert_str(artifacts["placements_json"]).is_equal(FileAccess.get_file_as_string(PLACEMENTS_PATH))
	assert_str(artifacts["dialogue"]).is_equal(FileAccess.get_file_as_string(GenerateGloot.DOM_NPC_DIALOGUE_PATH))


func test_the_generator_reads_the_npc_rows_and_skips_other_kinds() -> void:
	var documents: Array[Dictionary] = SeedPandora.CanonReader.load("characters")
	var factions: Dictionary = {}
	for faction: Dictionary in SeedPandora.CanonReader.load("factions"):
		factions[String(faction["vault_id"])] = true
	var npc_only: Array[Dictionary] = []
	for document: Dictionary in documents:
		if document["kind"] == "npc":
			npc_only.append(document)
	var with_archetypes: Dictionary = GenerateGloot.npc_artifacts_from_canon(documents, factions)
	var without: Dictionary = GenerateGloot.npc_artifacts_from_canon(npc_only, factions)
	assert_str(with_archetypes["roster_json"]).is_equal(without["roster_json"])
	# A canon edit reaches the roster: the generator is reading canon, not Pandora.
	var edited: Array[Dictionary] = documents.duplicate(true)
	for document: Dictionary in edited:
		if document["id"] == "sella-varn":
			document["role"] = "Bell keeper"
	var roster: Dictionary = JSON.parse_string(GenerateGloot.npc_artifacts_from_canon(edited, factions)["roster_json"])
	assert_str(String(roster["npcs"]["sella-varn"]["role"])).is_equal("Bell keeper")


# --- open registries ----------------------------------------------------------------------


func test_the_adapter_declares_three_kinds_and_two_stat_schemas() -> void:
	var adapter: WeftluminGameAdapter = AdapterScript.new()
	var kinds: Array[WeftluminKind] = adapter.kinds()
	assert_int(kinds.size()).is_equal(1)
	var characters := kinds[0] as WeftluminCharactersKind
	assert_object(characters).is_not_null()
	assert_str(String(characters.id)).is_equal("characters")
	assert_array(characters.character_kinds()).contains_exactly_in_any_order(["npc", "archetype", "recruit"])
	assert_array(characters.stat_schemas()).contains_exactly_in_any_order(["dramgid.v1", "six-stat.v1"])


func test_an_undeclared_kind_is_refused_until_the_host_declares_it() -> void:
	var spirit: Dictionary = {
		"schema": WeftluminCharactersKind.SCHEMA, "kind": "spirit", "id": "probe-spirit",
		"order": 1, "display_name": "Probe Spirit", "omen": "low tide",
	}
	assert_array(_codes(spirit)).contains(["unknown_character_kind"])
	assert_bool(_kind.register_character_kind("spirit", {"fields": {"omen": WeftluminCharactersKind.STRING}})).is_true()
	var errors: Array[Dictionary] = []
	var batch: Array[Dictionary] = [spirit]
	assert_int(_kind.validate(batch, errors).size()).is_equal(1)
	assert_array(errors).is_empty()
	# Registries refuse duplicates and contracts that would redefine identity.
	assert_bool(_kind.register_character_kind("spirit", {})).is_false()
	assert_bool(_kind.register_character_kind("ghost", {"fields": {"id": WeftluminCharactersKind.STRING}})).is_false()


func test_stats_are_opaque_and_validated_only_by_the_named_schema() -> void:
	var boar: Dictionary = _canon_document("loam-maddened-boar")
	var unknown: Dictionary = boar.duplicate(true)
	unknown["stats"]["schema"] = "seven-stat.v9"
	assert_array(_codes(unknown)).contains(["invalid_field_type"])
	var nameless: Dictionary = boar.duplicate(true)
	(nameless["stats"] as Dictionary).erase("schema")
	assert_array(_codes(nameless)).contains(["invalid_field_type"])
	# dramgid.v1 reads DramgidSchema: every attribute present and whole, nothing more.
	var fractional: Dictionary = boar.duplicate(true)
	fractional["stats"]["grit"] = 1.5
	assert_array(_codes(fractional)).contains(["invalid_field_type"])
	var missing: Dictionary = boar.duplicate(true)
	(missing["stats"] as Dictionary).erase("decorum")
	assert_array(_codes(missing)).contains(["invalid_field_type"])
	var extra: Dictionary = boar.duplicate(true)
	extra["stats"]["anything_the_seeder_reads"] = "kept verbatim"
	assert_array(_codes(extra)).is_empty()
	# six-stat.v1 has no installed definition: any object naming it passes.
	var retired: Dictionary = boar.duplicate(true)
	retired["stats"] = {"schema": "six-stat.v1", "edge": 3}
	assert_array(_codes(retired)).is_empty()
	# A host-installed schema validates with its own rules.
	assert_bool(_kind.register_stat_schema("probe.v1", {
		"fields": PackedStringArray(["pluck"]),
		"validate": func(stats: Dictionary) -> Array[String]:
			var problems: Array[String] = []
			if not stats.has("pluck"):
				problems.append("pluck is required")
			return problems,
	})).is_true()
	var probed: Dictionary = boar.duplicate(true)
	probed["stats"] = {"schema": "probe.v1"}
	assert_array(_codes(probed)).contains(["invalid_field_type"])
	probed["stats"] = {"schema": "probe.v1", "pluck": 2, "zeal": 1}
	assert_array(_codes(probed)).is_empty()
	assert_array(_kind.stat_fields(probed["stats"])).is_equal(["pluck", "zeal"])


func test_stat_fields_follow_the_schema_declaration_order() -> void:
	var boar: Dictionary = _canon_document("loam-maddened-boar")
	var expected: Array[String] = []
	for attribute: String in DramgidSchema.ATTRIBUTE_IDS:
		expected.append(attribute)
	expected.append_array(["attack", "balance_affinity", "balance_pressure", "defense", "max_hp"])
	assert_array(_kind.stat_fields(boar["stats"])).is_equal(expected)
	assert_str(_kind.stat_field_label("dramgid.v1", "grit")).is_equal(DramgidSchema.attribute_label("grit"))


func test_unknown_fields_and_bad_shapes_are_refused_with_attributed_errors() -> void:
	var sella: Dictionary = _canon_document("sella-varn")
	var typo: Dictionary = sella.duplicate(true)
	typo["rol"] = "Bell warden"
	assert_array(_codes(typo)).contains(["unknown_field"])
	var routine: Dictionary = sella.duplicate(true)
	routine["routine"] = {"morning": {"position": [1], "state": "working"}}
	assert_array(_codes(routine)).contains(["invalid_field_type"])
	var portrait: Dictionary = sella.duplicate(true)
	portrait["portrait_path"] = "res://globals/game_state.gd"
	assert_array(_codes(portrait)).contains(["invalid_portrait_path"])
	var dropped: Dictionary = sella.duplicate(true)
	dropped.erase("placement_anchor")
	var errors: Array[Dictionary] = []
	var batch: Array[Dictionary] = [dropped]
	_kind.validate(batch, errors)
	assert_str(String(errors[0]["field"])).is_equal("placement_anchor")
	assert_str(String(errors[0]["code"])).is_equal("missing_field")
	for key: String in ["file", "field", "expected", "code", "message"]:
		assert_bool(errors[0].has(key)).is_true()


# --- vault_id -------------------------------------------------------------------------------


func test_a_recruit_without_a_vault_id_is_refused() -> void:
	var recruit: Dictionary = _recruit("")
	assert_array(_codes(recruit)).contains(["missing_vault_id"])
	var errors: Array[Dictionary] = _kind.create_problems(recruit, _canon())
	assert_array(_codes_of(errors)).contains(["missing_vault_id"])
	# The skeleton never fills one in.
	assert_str(String(recruit["vault_id"])).is_empty()


func test_a_recruit_vault_id_must_be_a_vault_character() -> void:
	assert_array(_kind.create_problems(_recruit("serai-lun"), _canon())).is_empty()
	var faction: Array[Dictionary] = _kind.create_problems(_recruit("trial-council"), _canon())
	assert_array(_codes_of(faction)).is_equal(["invalid_vault_id"])
	var invented: Array[Dictionary] = _kind.create_problems(_recruit("not-in-the-vault"), _canon())
	assert_array(_codes_of(invented)).is_equal(["invalid_vault_id"])
	# No vault beside the repository: the id cannot be checked, so it is refused.
	var blind := WeftluminCharactersKind.soul_meter()
	blind.vault_index_path_for_tests = SCRATCH + "/missing.json"
	assert_array(_codes_of(blind.create_problems(_recruit("serai-lun"), _canon()))).is_equal(["invalid_vault_id"])


func test_a_vault_id_is_never_renamed_but_an_empty_one_may_be_linked() -> void:
	var themka: Dictionary = _canon_document("themka-gaath")
	var renamed: Dictionary = themka.duplicate(true)
	renamed["vault_id"] = "serai-lun"
	assert_array(_codes_of(_kind.edit_problems(themka, renamed))).is_equal(["vault_id_rename"])
	var cleared: Dictionary = themka.duplicate(true)
	cleared["vault_id"] = ""
	assert_array(_codes_of(_kind.edit_problems(themka, cleared))).is_equal(["vault_id_rename"])
	var sella: Dictionary = _canon_document("sella-varn")
	var linked: Dictionary = sella.duplicate(true)
	linked["vault_id"] = "serai-lun"
	assert_array(_kind.edit_problems(sella, linked)).is_empty()
	linked["vault_id"] = "made-up-person"
	assert_array(_codes_of(_kind.edit_problems(sella, linked))).is_equal(["invalid_vault_id"])
	var rekinded: Dictionary = sella.duplicate(true)
	rekinded["kind"] = "archetype"
	assert_array(_codes_of(_kind.edit_problems(sella, rekinded))).contains(["identity_change"])


func test_party_member_vault_id_hook() -> void:
	var known: Dictionary = {"serai-lun": "Serai-Lun"}
	assert_str(PartyMember.vault_id_refusal("serai-lun", known)).is_empty()
	assert_str(PartyMember.vault_id_refusal("", known)).contains("never generated")
	assert_str(PartyMember.vault_id_refusal("Serai Lun", known)).contains("not a vault id")
	assert_str(PartyMember.vault_id_refusal("old-grumbrand", known)).contains("not a character")
	assert_str(PartyMember.vault_id_refusal("serai-lun", {})).contains("unavailable")


# --- text forms, diff, bake ---------------------------------------------------------------


func test_canon_text_writes_whole_numbers_as_integers_and_drops_meta_keys() -> void:
	var text: String = WeftluminCharactersKind.canon_text({
		"schema": WeftluminCharactersKind.SCHEMA, "order": 3.0, "pair": [100.0, -2.5],
		WeftluminCharactersKind.META_FILE: "x", WeftluminCharactersKind.META_HUB: "dom",
	})
	assert_str(text).is_equal('{"schema":"weftlumin.character.v1","order":3,"pair":[100,-2.5]}\n')


func test_a_new_recruit_bakes_to_a_new_canon_document_and_regenerates_nothing() -> void:
	var rows: Array[Dictionary] = _canon()
	rows.append(_kind.validate([_recruit()] as Array[Dictionary], [] as Array[Dictionary])[0])
	var report: Dictionary = _kind.bake(rows, "res://", false, false)
	var planned: Dictionary = {}
	for entry: Dictionary in report["planned"]:
		planned[entry["path"]] = entry["action"]
	assert_str(String(planned["res://canon/dom/characters/probe-recruit.json"])).is_equal("create")
	assert_array(report["regenerated"]).is_empty()
	assert_bool(FileAccess.file_exists("res://canon/dom/characters/probe-recruit.json")).is_false()
	assert_str(String(_kind.diff(_canon(), rows)["added"][0])).is_equal("probe-recruit")


func test_writing_an_npc_edit_reports_the_roster_regeneration() -> void:
	var sella: Dictionary = _canon_document("sella-varn")
	sella["role"] = "Bell keeper"
	var rows: Array[Dictionary] = [sella]
	var report: Dictionary = _kind.bake(rows, SCRATCH, true, false)
	assert_array(report["written"]).contains_exactly(["res://canon/dom/characters/sella-varn.json"])
	assert_array(report["regenerated"]).contains([ROSTER_PATH, PLACEMENTS_PATH])
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH.path_join("canon/dom/characters/sella-varn.json")))
	assert_str(String(written["role"])).is_equal("Bell keeper")
	assert_str(FileAccess.get_file_as_string("res://canon/dom/characters/sella-varn.json")).contains("Bell warden")


# --- pickers ------------------------------------------------------------------------------


func test_portrait_and_sprite_pickers_list_and_preview_canon_art() -> void:
	var table: Dictionary = PickersScript.new().table()
	var portraits: PackedStringArray = (table["portraits"]["options"] as Callable).call(null)
	var sella: Dictionary = _canon_document("sella-varn")
	assert_bool(portraits.has(String(sella["portrait_path"]))).is_true()
	assert_object(PickersScript.portrait_texture(String(sella["portrait_path"]))).is_not_null()
	assert_object(PickersScript.portrait_texture("res://globals/game_state.gd")).is_null()
	var sprites: PackedStringArray = (table["sprites"]["options"] as Callable).call(null)
	assert_bool(sprites.has("bog-wight")).is_true()
	assert_bool(sprites.has("sella-varn")).is_true()
	assert_object(PickersScript.sprite_texture("bog-wight")).is_not_null()
	assert_str(String((table["sprites"]["validate"] as Callable).call("no-such-unit", null))).contains("not a known id")
	assert_array(Array(table["portraits"]["properties"])).is_equal(["portrait_path"])


func _remove_tree(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for child: String in DirAccess.get_directories_at(absolute):
		_remove_tree(absolute.path_join(child))
	for file_name: String in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(file_name))
	DirAccess.remove_absolute(absolute)
