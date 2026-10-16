extends GdUnitTestSuite
## E3.3a (#341): the `locations` kind, its bake and tools/generate_locations.gd.
## Acceptance: canon reproduces the committed `world/locations/*.tres` and the location index
## byte-for-byte, deterministically; validation refuses malformed documents with attributed
## errors; drafts promote into canon only for existing locations.

const GeneratorScript := preload("res://tools/generate_locations.gd")
const SCRATCH := "user://gdunit-weftlumin-locations"
const MACRO_IDS: Array[String] = ["dom", "dorthkor_road", "kesselford", "wilds", "wound_lip"]

var _kind: WeftluminLocationsKind


func before_test() -> void:
	_kind = WeftluminLocationsKind.new()
	_remove_tree(SCRATCH)


func after_test() -> void:
	_remove_tree(SCRATCH)


func _canon() -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var documents: Array[Dictionary] = WeftluminLocationsKind.load_canon(errors)
	assert_array(errors).is_empty()
	var normalised: Array[Dictionary] = _kind.validate(documents, errors)
	assert_array(errors).override_failure_message(str(errors)).is_empty()
	return normalised


func _scene_rows(rows: Array[Dictionary]) -> Array[Dictionary]:
	var scenes: Array[Dictionary] = []
	for row: Dictionary in rows:
		if row.has("scene_path"):
			scenes.append(row)
	return scenes


func _valid_scene_document() -> Dictionary:
	return {
		"schema": "weftlumin.location.v1", "id": "probe_location",
		"definition_path": "res://world/locations/probe.tres",
		"scene_path": "res://world/test_room.tscn", "allowed_gameplay": true,
		"default_spawn_id": "default", "spawns": {"from_dom": "from_dom"},
		"arrival_flag": "", "arrival_checkpoint": "", "harmonic_accord": 85.0,
		"thinning_tier": 1.0, "weather_default": "mozh", "no_combat_zone": false,
		"respawn_policy": "wilderness",
	}


func _codes(document: Dictionary) -> Array[String]:
	var errors: Array[Dictionary] = []
	var batch: Array[Dictionary] = [document]
	assert_array(_kind.validate(batch, errors)).is_empty()
	var codes: Array[String] = []
	for error: Dictionary in errors:
		for key: String in ["file", "field", "expected", "code", "message"]:
			assert_bool(error.has(key)).override_failure_message("error lacks %s" % key).is_true()
		codes.append(String(error["code"]))
	return codes


# --- Canon and the committed artifacts -------------------------------------------------------


func test_canon_holds_the_five_macro_and_twenty_three_interior_scenes_plus_the_cities() -> void:
	var rows: Array[Dictionary] = _canon()
	var scenes: Array[Dictionary] = _scene_rows(rows)
	assert_int(scenes.size()).is_equal(LocationRegistry.ALL.size())
	var interiors: int = 0
	for row: Dictionary in scenes:
		if String(row["definition_path"]).begins_with("res://world/locations/interiors/"):
			interiors += 1
	# Dom's twenty-one plus Kesselford's wayhouse and chandlery (C1 / #238).
	assert_int(interiors).is_equal(23)
	assert_int(scenes.size() - interiors).is_equal(MACRO_IDS.size())
	# The twelve gazetteer cities stay; Dom is the one location carrying both facets.
	var gazetteer: int = 0
	for row: Dictionary in rows:
		if row.has("vault_id"):
			gazetteer += 1
			assert_bool(row.has("scene_path")).is_equal(row["id"] == "dom")
	assert_int(gazetteer).is_equal(12)


func test_canon_bakes_to_the_committed_artifacts_byte_for_byte() -> void:
	var report: Dictionary = _kind.bake(_canon(), "res://", false, false)
	assert_str(String(report["schema"])).is_equal("weftlumin.bake.v1")
	assert_str(String(report["mode"])).is_equal("report")
	for entry: Dictionary in report["planned"]:
		assert_str(String(entry["action"])).override_failure_message(String(entry["path"])).is_equal("unchanged")
	assert_array(report["orphans"]).is_empty()
	assert_bool(WeftluminLocationsKind.report_is_clean(report)).is_true()
	assert_int((report["planned"] as Array).size()).is_equal(LocationRegistry.ALL.size() + 1)


func test_the_generator_is_deterministic_and_matches_the_committed_files() -> void:
	var first: String = SCRATCH.path_join("first")
	var second: String = SCRATCH.path_join("second")
	for target: String in [first, second]:
		var result: Dictionary = GeneratorScript.generate(false, WeftluminLocationsKind.CANON_ROOT, target)
		assert_array(result["errors"]).is_empty()
		assert_int((result["report"]["written"] as Array).size()).is_equal(LocationRegistry.ALL.size() + 1)
	for path: String in WeftluminLocationsKind.artifacts(_canon()):
		var relative: String = path.trim_prefix("res://")
		var committed: PackedByteArray = FileAccess.get_file_as_bytes(path)
		assert_int(committed.size()).is_greater(0)
		assert_bool(FileAccess.get_file_as_bytes(first.path_join(relative)) == committed) \
			.override_failure_message("first bake differs from committed %s" % path).is_true()
		assert_bool(FileAccess.get_file_as_bytes(second.path_join(relative)) == committed) \
			.override_failure_message("second bake differs from committed %s" % path).is_true()


func test_drift_check_mode_reports_no_drift_and_writes_nothing() -> void:
	var result: Dictionary = GeneratorScript.generate(true)
	assert_array(result["errors"]).is_empty()
	assert_bool(result["drift"]).is_false()
	assert_array(result["report"]["written"]).is_empty()


func test_every_baked_definition_loads_with_the_registry_values() -> void:
	var by_path: Dictionary = {}
	for row: Dictionary in _scene_rows(_canon()):
		by_path[row["definition_path"]] = row
	for definition: LocationDefinition in LocationRegistry.ALL:
		var row: Dictionary = by_path[definition.resource_path]
		assert_str(String(definition.id)).is_equal(String(row["id"]))
		assert_str(definition.scene_path).is_equal(String(row["scene_path"]))
		assert_bool(definition.allowed_gameplay).is_equal(bool(row["allowed_gameplay"]))
		assert_str(String(definition.default_spawn_id)).is_equal(String(row["default_spawn_id"]))
		assert_dict(definition.spawns).is_equal(row["spawns"])
		assert_str(definition.arrival_flag).is_equal(String(row["arrival_flag"]))
		assert_str(definition.arrival_checkpoint).is_equal(String(row["arrival_checkpoint"]))
		assert_float(definition.harmonic_accord).is_equal(float(row["harmonic_accord"]))
		assert_int(definition.thinning_tier).is_equal(int(row["thinning_tier"]))
		assert_str(String(definition.weather_default)).is_equal(String(row["weather_default"]))
		assert_str(definition.respawn_policy).is_equal(String(row["respawn_policy"]))
		# Until E3.3b, canon's no-combat flag must agree with what FieldMap derives.
		assert_bool(bool(row["no_combat_zone"])).is_equal(definition.scene_path.begins_with("res://world/interiors/"))
		assert_array(WeftluminLocationsKind.runtime_notes(row)).is_empty()


func test_canon_documents_are_stored_in_canonical_text() -> void:
	var errors: Array[Dictionary] = []
	for document: Dictionary in WeftluminLocationsKind.load_canon(errors):
		var path: String = document[WeftluminLocationsKind.META_FILE]
		var batch: Array[Dictionary] = [document.duplicate(true)]
		var normalised: Array[Dictionary] = _kind.validate(batch, errors)
		assert_str(WeftluminLocationsKind.canon_text(normalised[0])).override_failure_message(path) \
			.is_equal(FileAccess.get_file_as_string(path))
	assert_array(errors).is_empty()


func test_index_rows_cover_every_canon_location_with_both_facets() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WeftluminLocationsKind.INDEX_PATH))
	assert_str(String(parsed["schema"])).is_equal("weftlumin.location_index.v1")
	var rows: Dictionary = {}
	for row: Dictionary in parsed["locations"]:
		rows[row["id"]] = row
	assert_int(rows.size()).is_equal(_canon().size())
	assert_str(String(rows["dom"]["patron"])).is_equal("Kero")
	assert_str(String(rows["dom"]["definition_path"])).is_equal("res://world/locations/dom.tres")
	assert_str(String(rows["loamgate"]["scene_path"])).is_empty()
	assert_bool(bool(rows["bell_house_interior"]["no_combat_zone"])).is_true()
	assert_bool(bool(rows["wilds"]["no_combat_zone"])).is_false()


# --- Validation --------------------------------------------------------------------------------


func test_a_valid_scene_document_normalises_to_typed_values() -> void:
	var errors: Array[Dictionary] = []
	var batch: Array[Dictionary] = [_valid_scene_document()]
	var rows: Array[Dictionary] = _kind.validate(batch, errors)
	assert_array(errors).is_empty()
	assert_int(typeof(rows[0]["thinning_tier"])).is_equal(TYPE_INT)
	assert_int(typeof(rows[0]["harmonic_accord"])).is_equal(TYPE_FLOAT)
	assert_str(WeftluminLocationsKind.definition_text(rows[0])).contains('weather_default = &"mozh"')


func test_validation_refuses_malformed_fields_with_attributed_errors() -> void:
	var cases: Array[Array] = [
		["schema", "weftlumin.location.v0", "unsupported_schema"],
		["id", "Bad Id", "invalid_id"],
		["harmonic_accord", 101.0, "out_of_range"],
		["harmonic_accord", "95", "out_of_range"],
		["thinning_tier", 4.0, "out_of_range"],
		["thinning_tier", 1.5, "out_of_range"],
		["weather_default", "storm", "unknown_weather"],
		["respawn_policy", "sometimes", "invalid_enum"],
		["no_combat_zone", "yes", "invalid_field_type"],
		["allowed_gameplay", 1.0, "invalid_field_type"],
		["default_spawn_id", "", "invalid_field_type"],
		["spawns", {"from_dom": ""}, "invalid_spawn"],
		["spawns", [], "invalid_field_type"],
		["arrival_flag", null, "invalid_field_type"],
		["scene_path", "res://world/no_such_scene.tscn", "missing_scene"],
		["definition_path", "res://elsewhere/probe.tres", "invalid_definition_path"],
		["definition_path", "res://world/locations/../probe.tres", "invalid_definition_path"],
		["harmonic_acord", 90.0, "unknown_field"],
	]
	for case: Array in cases:
		var document: Dictionary = _valid_scene_document()
		document[case[0]] = case[1]
		assert_array(_codes(document)).override_failure_message("%s=%s" % [case[0], case[1]]).contains([case[2]])
	var missing: Dictionary = _valid_scene_document()
	missing.erase("respawn_policy")
	assert_array(_codes(missing)).contains(["invalid_enum"])


func test_validation_refuses_partial_gazetteer_and_empty_documents() -> void:
	var partial: Dictionary = _valid_scene_document()
	partial["patron"] = "Kero"
	assert_array(_codes(partial)).contains(["invalid_field_type"])
	assert_array(_codes({"schema": "weftlumin.location.v1", "id": "nothing"})).contains(["empty_location"])


func test_validation_refuses_duplicate_ids_scenes_and_definitions() -> void:
	var first: Dictionary = _valid_scene_document()
	var same_id: Dictionary = _valid_scene_document()
	same_id["definition_path"] = "res://world/locations/other.tres"
	var same_scene: Dictionary = _valid_scene_document()
	same_scene["id"] = "other_location"
	same_scene["definition_path"] = "res://world/locations/other.tres"
	for pair: Array in [[same_id, "duplicate_id"], [same_scene, "duplicate_scene_path"]]:
		var errors: Array[Dictionary] = []
		var batch: Array[Dictionary] = [first.duplicate(true), (pair[0] as Dictionary).duplicate(true)]
		assert_array(_kind.validate(batch, errors)).is_empty()
		var codes: Array[String] = []
		for error: Dictionary in errors:
			codes.append(String(error["code"]))
		assert_array(codes).contains([pair[1]])


## E3.3b (#342): the runtime reads canon `no_combat_zone`, so a value off the interior-prefix rule
## is no longer one the runtime would ignore.
func test_runtime_notes_no_longer_flag_a_no_combat_value_off_the_prefix_rule() -> void:
	var errors: Array[Dictionary] = []
	var document: Dictionary = _valid_scene_document()
	document["no_combat_zone"] = true
	var batch: Array[Dictionary] = [document]
	var rows: Array[Dictionary] = _kind.validate(batch, errors)
	assert_array(WeftluminLocationsKind.runtime_notes(rows[0])).is_empty()


func test_definition_text_omits_script_defaults_in_the_committed_order() -> void:
	var errors: Array[Dictionary] = []
	var batch: Array[Dictionary] = [_valid_scene_document()]
	var row: Dictionary = _kind.validate(batch, errors)[0]
	row["respawn_policy"] = "limited"
	row["thinning_tier"] = 0
	row["weather_default"] = ""
	row["allowed_gameplay"] = false
	row["arrival_flag"] = "probe_reached"
	var text: String = WeftluminLocationsKind.definition_text(row)
	assert_bool(text.contains("respawn_policy")).is_false()
	assert_bool(text.contains("thinning_tier")).is_false()
	assert_bool(text.contains("weather_default")).is_false()
	assert_bool(text.contains("arrival_checkpoint")).is_false()
	var order: Array[String] = ["id =", "scene_path =", "allowed_gameplay = false", "harmonic_accord = 85.0",
		"default_spawn_id =", 'arrival_flag = "probe_reached"', "spawns = {"]
	var cursor: int = -1
	for needle: String in order:
		var at: int = text.find(needle)
		assert_int(at).override_failure_message(needle).is_greater(cursor)
		cursor = at


func test_diff_reports_added_modified_and_removed_ids() -> void:
	var canon: Array[Dictionary] = _canon()
	var next: Array[Dictionary] = canon.duplicate(true)
	for row: Dictionary in next:
		if row["id"] == "wilds":
			row["harmonic_accord"] = 80.0
	next = next.filter(func(row: Dictionary) -> bool: return row["id"] != "loamgate")
	assert_bool(_kind.diff(canon, canon.duplicate(true))["changed"]).is_false()
	var changes: Dictionary = _kind.diff(canon, next)
	assert_bool(changes["changed"]).is_true()
	assert_array(changes["modified"]).contains_exactly(["wilds"])
	assert_array(changes["removed"]).contains_exactly(["loamgate"])
	assert_bool(_kind.register(next)).is_false()


# --- Draft promotion ------------------------------------------------------------------------


func test_drafts_promote_into_canon_and_rebake_only_their_definition() -> void:
	var canon_root: String = SCRATCH.path_join("canon")
	var target: String = SCRATCH.path_join("out")
	var drafts: String = SCRATCH.path_join("drafts")
	_copy_canon(canon_root)
	assert_array(GeneratorScript.generate(false, canon_root, target)["errors"]).is_empty()
	DirAccess.make_dir_recursive_absolute(drafts)
	var draft: Dictionary = {}
	for row: Dictionary in _canon():
		if row["id"] == "wilds":
			draft = row.duplicate(true)
	draft["harmonic_accord"] = 80.0
	_write(drafts.path_join("wilds.json"), WeftluminLocationsKind.canon_text(draft))
	var result: Dictionary = GeneratorScript.generate(false, canon_root, target, drafts)
	assert_array(result["errors"]).is_empty()
	assert_array(result["promoted"]).contains_exactly([canon_root.path_join("dom/locations/wilds.json")])
	assert_array(result["report"]["written"]).contains_exactly(["res://world/locations/wilds.tres"])
	assert_str(FileAccess.get_file_as_string(target.path_join("world/locations/wilds.tres"))) \
		.contains("harmonic_accord = 80.0")
	assert_str(FileAccess.get_file_as_string(canon_root.path_join("dom/locations/wilds.json"))) \
		.contains('"harmonic_accord":80.0')
	# Re-running with no drafts is now clean against the promoted canon.
	assert_bool(GeneratorScript.generate(true, canon_root, target)["drift"]).is_false()


func test_a_draft_for_an_unknown_location_or_an_invalid_draft_is_refused() -> void:
	var canon_root: String = SCRATCH.path_join("canon")
	var drafts: String = SCRATCH.path_join("drafts")
	_copy_canon(canon_root)
	DirAccess.make_dir_recursive_absolute(drafts)
	var unknown: Dictionary = _valid_scene_document()
	_write(drafts.path_join("probe_location.json"), JSON.stringify(unknown))
	var result: Dictionary = GeneratorScript.generate(false, canon_root, SCRATCH.path_join("out"), drafts)
	assert_str(String((result["errors"] as Array)[0]["code"])).is_equal("unknown_location")
	assert_array(result["promoted"]).is_empty()
	DirAccess.remove_absolute(drafts.path_join("probe_location.json"))
	var bad: Dictionary = {}
	for row: Dictionary in _canon():
		if row["id"] == "wilds":
			bad = row.duplicate(true)
	bad["thinning_tier"] = 9
	_write(drafts.path_join("wilds.json"), JSON.stringify(bad))
	result = GeneratorScript.generate(false, canon_root, SCRATCH.path_join("out"), drafts)
	assert_str(String((result["errors"] as Array)[0]["code"])).is_equal("out_of_range")
	assert_str(FileAccess.get_file_as_string(canon_root.path_join("dom/locations/wilds.json"))) \
		.contains('"thinning_tier":1')


func test_an_orphan_definition_is_drift() -> void:
	var target: String = SCRATCH.path_join("out")
	assert_array(GeneratorScript.generate(false, WeftluminLocationsKind.CANON_ROOT, target)["errors"]).is_empty()
	_write(target.path_join("world/locations/interiors/stray.tres"), "[gd_resource]\n")
	var result: Dictionary = GeneratorScript.generate(true, WeftluminLocationsKind.CANON_ROOT, target)
	assert_bool(result["drift"]).is_true()
	assert_array(result["report"]["orphans"]).contains_exactly(["res://world/locations/interiors/stray.tres"])


func _copy_canon(destination: String) -> void:
	var errors: Array[Dictionary] = []
	for document: Dictionary in WeftluminLocationsKind.load_canon(errors):
		var source: String = document[WeftluminLocationsKind.META_FILE]
		var relative: String = source.trim_prefix(WeftluminLocationsKind.CANON_ROOT + "/")
		_write(destination.path_join(relative), FileAccess.get_file_as_string(source))


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_tree(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for child: String in DirAccess.get_directories_at(absolute):
		_remove_tree(absolute.path_join(child))
	for file_name: String in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(file_name))
	DirAccess.remove_absolute(absolute)
