extends GdUnitTestSuite
## E4.2 (#346): the `spawn_tables` kind. §4.10 step 5's invariants and the location's respawn
## policy are attributed errors; the canonical text is the committed canon layout.

const SCENE := "res://world/test_room.tscn"
const ANCHOR := "SpawnSlotGladeSouth"
const CANON_FILE := "res://canon/dom/spawn_tables/wilds-glade-ambient.json"

var _kind: WeftluminSpawnTablesKind


func before_test() -> void:
	_kind = WeftluminSpawnTablesKind.new()
	_kind.policies_for_tests = {SCENE: "wilderness"}


func _table(slots: Array = []) -> Dictionary:
	return {
		"schema": WeftluminSpawnTablesKind.SCHEMA,
		"id": "fixture-table",
		"scene_path": SCENE,
		"slots": slots if not slots.is_empty() else [_slot()],
		"caps": {},
		WeftluminSpawnTablesKind.META_FILE: "fixture.json",
	}


func _slot(slot_id: String = "glade-south", anchor: String = ANCHOR) -> Dictionary:
	return {
		"id": slot_id, "anchor": anchor, "respawn_days": 1,
		"entries": [{"archetype_id": "bog-wight", "weight": 40}, {"empty": true, "weight": 20}],
		"pack_size": {"min": 1, "max": 2},
	}


func _errors_for(table: Dictionary) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var documents: Array[Dictionary] = [table]
	var normalised: Array[Dictionary] = _kind.validate(documents, errors)
	if not errors.is_empty():
		assert_array(normalised).is_empty()
	return errors


func _has(errors: Array[Dictionary], field: String, code: String) -> bool:
	for error: Dictionary in errors:
		if error["field"] == field and error["code"] == code and error["file"] == "fixture.json":
			return true
	return false


func test_committed_canon_validates_and_its_canonical_text_is_byte_identical() -> void:
	var canon_kind := WeftluminSpawnTablesKind.new()
	var errors: Array[Dictionary] = []
	var documents: Array[Dictionary] = WeftluminSpawnTablesKind.load_canon(errors)
	assert_array(errors).is_empty()
	assert_int(documents.size()).is_greater(0)
	var normalised: Array[Dictionary] = canon_kind.validate(documents.duplicate(true), errors)
	assert_array(errors).override_failure_message(str(errors)).is_empty()
	assert_int(normalised.size()).is_equal(documents.size())
	for index: int in documents.size():
		var path: String = documents[index][WeftluminSpawnTablesKind.META_FILE]
		var row: Dictionary = {}
		for candidate: Dictionary in normalised:
			if candidate["id"] == documents[index]["id"]:
				row = candidate
		assert_str(WeftluminSpawnTablesKind.canon_text(row)).is_equal(FileAccess.get_file_as_string(path))
		# The kind and the runtime agree: what the kind accepts, SpawnDirector loads.
		assert_array(Array(SpawnDirector.table_problems(row))).is_empty()
	# Canon now holds more than one table (Kesselford, C1 / #238); pin the Dom fixture by id.
	var glade: Dictionary = {}
	for candidate: Dictionary in normalised:
		if candidate["id"] == "wilds-glade-ambient":
			glade = candidate
	assert_str(WeftluminSpawnTablesKind.canon_text(glade)).is_equal(FileAccess.get_file_as_string(CANON_FILE))


func test_a_valid_table_normalises_numbers_to_ints_and_drops_meta_keys() -> void:
	var table := _table()
	table["slots"][0]["respawn_days"] = 2.0
	var errors: Array[Dictionary] = []
	var documents: Array[Dictionary] = [table]
	var normalised: Array[Dictionary] = _kind.validate(documents, errors)
	assert_array(errors).is_empty()
	var row: Dictionary = normalised[0]
	assert_bool(row.has(WeftluminSpawnTablesKind.META_FILE)).is_false()
	assert_bool(row["slots"][0]["respawn_days"] is int).is_true()
	assert_bool(row["slots"][0]["entries"][0]["weight"] is int).is_true()


func test_every_section_4_10_invariant_is_an_attributed_error() -> void:
	var slot := _slot()
	slot["entries"] = [{"empty": true, "weight": 3}, {"archetype_id": "bog-wight", "weight": 0}]
	slot["respawn_days"] = 0
	slot["pack_size"] = {"min": 0, "max": 2}
	var errors := _errors_for(_table([slot]))
	assert_bool(_has(errors, "slots[0].entries[1].weight", "invalid_weight")).override_failure_message(str(errors)).is_true()
	assert_bool(_has(errors, "slots[0].entries", "no_creature_entry")).is_true()
	assert_bool(_has(errors, "slots[0].respawn_days", "out_of_range")).is_true()
	assert_bool(_has(errors, "slots[0].pack_size.min", "out_of_range")).is_true()

	var fractional := _slot()
	fractional["entries"] = [{"archetype_id": "bog-wight", "weight": 2.5}]
	errors = _errors_for(_table([fractional]))
	assert_bool(_has(errors, "slots[0].entries[0].weight", "invalid_weight")).is_true()
	assert_bool(_has(errors, "slots[0].entries", "no_creature_entry")).is_true()

	var inverted := _slot()
	inverted["pack_size"] = {"min": 3, "max": 1}
	assert_bool(_has(_errors_for(_table([inverted])), "slots[0].pack_size.max", "out_of_range")).is_true()

	var missing := _errors_for(_table([_slot("hollow-east", "SpawnSlotHollowEast")]))
	assert_bool(_has(missing, "slots[0].anchor", "missing_anchor")).is_true()
	assert_str(String(missing[0]["message"])).contains("SpawnSlotHollowEast")


func test_structural_problems_are_attributed() -> void:
	var table := _table([_slot(), _slot()])
	table["surprise"] = true
	table["slots"][1]["entries"].append({"archetype_id": "bog-wight", "weight": 1, "colour": "red"})
	table["caps"] = {"max_alive": 0}
	var errors := _errors_for(table)
	assert_bool(_has(errors, "surprise", "unknown_field")).is_true()
	assert_bool(_has(errors, "slots[1].id", "duplicate_slot")).is_true()
	assert_bool(_has(errors, "slots[1].entries[2].colour", "unknown_field")).is_true()
	assert_bool(_has(errors, "caps.max_alive", "out_of_range")).is_true()
	var no_slots := _table()
	no_slots["slots"] = []
	assert_bool(_has(_errors_for(no_slots), "slots", "invalid_slots")).is_true()
	var bad_scene := _table()
	bad_scene["scene_path"] = "res://world/does_not_exist.tscn"
	assert_bool(_has(_errors_for(bad_scene), "scene_path", "missing_scene")).is_true()


func test_a_marker_placed_in_the_live_scene_satisfies_the_anchor_invariant() -> void:
	var table := _table([_slot("hollow-east", "SpawnSlotHollowEast")])
	assert_bool(_has(_errors_for(table), "slots[0].anchor", "missing_anchor")).is_true()
	_kind.extra_anchors = {SCENE: ["SpawnSlotHollowEast"]}
	assert_array(_errors_for(table)).is_empty()


func test_respawn_policy_refusals_are_attributed_to_the_table() -> void:
	_kind.policies_for_tests = {SCENE: "none"}
	var refused := _errors_for(_table())
	assert_bool(_has(refused, "respawn_policy", "policy_refused")).is_true()
	assert_str(String(refused[0]["message"])).contains("\"none\"")

	_kind.policies_for_tests = {SCENE: "limited"}
	var limited := _errors_for(_table())
	var messages: Array[String] = []
	for error: Dictionary in limited:
		assert_str(String(error["code"])).is_equal("policy_refused")
		messages.append(String(error["message"]))
	var joined := " | ".join(messages)
	assert_str(joined).contains("requires at least %d" % SpawnMath.LIMITED_MIN_RESPAWN_DAYS)

	_kind.policies_for_tests = {"res://world/elsewhere.tscn": "wilderness"}
	var orphan := _errors_for(_table())
	assert_bool(_has(orphan, "respawn_policy", "policy_refused")).is_true()
	assert_str(String(orphan[0]["message"])).contains("No location document")


func test_canon_location_policy_is_read_from_the_locations_kind() -> void:
	var canon_kind := WeftluminSpawnTablesKind.new()
	assert_str(canon_kind.policy_for_scene(SCENE)).is_equal(String(LocationRegistry.by_scene(SCENE).respawn_policy))
	assert_str(canon_kind.policy_for_scene("res://world/nowhere.tscn")).is_equal("none")


func test_duplicate_table_ids_are_refused() -> void:
	var errors: Array[Dictionary] = []
	var documents: Array[Dictionary] = [_table(), _table()]
	assert_array(_kind.validate(documents, errors)).is_empty()
	assert_bool(_has(errors, "id", "duplicate_id")).is_true()


func test_anchor_names_are_spawn_slot_pascal_case() -> void:
	assert_str(WeftluminSpawnTablesKind.anchor_name_for("hollow-east")).is_equal("SpawnSlotHollowEast")
	assert_str(WeftluminSpawnTablesKind.anchor_name_for("glade_south")).is_equal("SpawnSlotGladeSouth")
	assert_str(WeftluminSpawnTablesKind.anchor_name_for("ridge")).is_equal("SpawnSlotRidge")


func test_diff_and_notes() -> void:
	var errors: Array[Dictionary] = []
	var documents: Array[Dictionary] = [_table()]
	var before: Array[Dictionary] = _kind.validate(documents, errors)
	var edited := _table()
	edited["slots"][0]["respawn_days"] = 3
	var after_documents: Array[Dictionary] = [edited]
	var after: Array[Dictionary] = _kind.validate(after_documents, errors)
	var changes: Dictionary = _kind.diff(before, after)
	assert_bool(bool(changes["changed"])).is_true()
	assert_array(changes["modified"]).contains_exactly(["fixture-table"])
	assert_bool(bool(_kind.diff(before, before)["changed"])).is_false()
	var unknown := after[0].duplicate(true)
	unknown["slots"][0]["entries"][0]["archetype_id"] = "no-such-beast"
	assert_str(" ".join(WeftluminSpawnTablesKind.notes(unknown))).contains("no-such-beast")
	assert_array(WeftluminSpawnTablesKind.notes(after[0])).is_empty()
