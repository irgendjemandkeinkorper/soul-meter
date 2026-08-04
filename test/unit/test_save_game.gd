extends GdUnitTestSuite

const SaveGameScript := preload("res://globals/save_game.gd")
var saves
var test_save_paths: Array[String] = []
var diagnostics: Array[Dictionary] = []


func before_test() -> void:
	saves = auto_free(SaveGameScript.new())
	saves.save_path = "user://gdunit_save_game_fallback.save"
	saves.temp_path = "user://gdunit_save_game_fallback.save.tmp"
	saves.backup_path = "user://gdunit_save_game_fallback.save.bak"
	test_save_paths = [saves.save_path, saves.temp_path, saves.backup_path]
	diagnostics.clear()
	saves.spawn_marker_diagnostic.connect(_record_spawn_diagnostic)
	_remove_test_saves()


func after_test() -> void:
	_remove_test_saves()


func test_validation_accepts_a_complete_current_payload() -> void:
	var payload := {
		"version": SaveGameScript.FORMAT_VERSION,
		"scene": GameFlow.TOWN_SCENE,
		"game_state": {},
		"reputation": {},
		"renown": {},
		"quests": {},
	}
	assert_bool(saves.validate_payload(payload)).is_true()


func test_validation_rejects_unknown_versions_and_partial_payloads() -> void:
	assert_bool(saves.validate_payload({"version": 999})).is_false()
	assert_bool(saves.validate_payload({"version": 1})).is_false()
	assert_bool(saves.validate_payload(null)).is_false()
	assert_bool(saves.validate_payload({"schema_version": 999})).is_false()


func test_current_envelope_has_schema_manifest_and_ng_plus_defaults() -> void:
	var payload: Dictionary = saves._build_payload()
	assert_int(payload["schema_version"]).is_equal(SaveGameScript.SCHEMA_VERSION)
	assert_bool(payload.has("id_schemas")).is_true()
	assert_int(payload["ng_plus"]["style_points"]).is_equal(0)
	assert_array(payload["ng_plus"]["purchased_carry_overs"]).is_empty()
	assert_bool(payload["zhavar"] is Dictionary).is_true()


func test_legacy_schema_migrates_without_losing_existing_values() -> void:
	var current: Dictionary = saves._build_payload()
	current["version"] = SaveGameScript.FORMAT_VERSION
	current.erase("schema_version")
	current.erase("id_schemas")
	current["game_state"]["skills"] = {
		"vex": {"persuasion": {"percentage": 61, "tier": "Expert", "advancement_points_spent": 4}}
	}
	current["game_state"]["var_harmony"] = {"vex": -3}
	current["zhavar"] = {"dom": "tolling"}
	current["ng_plus"] = {
		"style_points": 17,
		"purchased_carry_overs": ["keep-skill-persuasion"],
		"completion_metadata": {"ending": "stillpoint"},
	}
	assert_bool(saves.validate_payload(current)).is_true()
	var prepared: Dictionary = saves._prepare_for_load(current)
	var migrated: Dictionary = prepared["payload"]
	assert_int(migrated["schema_version"]).is_equal(SaveGameScript.SCHEMA_VERSION)
	assert_int(migrated["game_state"]["skills"]["vex"]["persuasion"]["advancement_points_spent"]).is_equal(4)
	assert_int(migrated["game_state"]["var_harmony"]["vex"]).is_equal(-3)
	assert_str(migrated["zhavar"]["dom"]).is_equal("tolling")
	assert_int(migrated["ng_plus"]["style_points"]).is_equal(17)


func test_envelope_round_trip_preserves_all_ratified_save_sections() -> void:
	var payload: Dictionary = saves._build_payload()
	payload["game_state"]["flags"] = {"chapter_dorthkor_commissioned": true}
	payload["game_state"]["skills"] = {
		"vex": {"persuasion": {"percentage": 74.5, "tier": "Trained", "advancement_points_spent": 9}}
	}
	payload["game_state"]["var_harmony"] = {"vex": 5}
	payload["reputation"] = {
		"log": [{"actor": "player", "faction": "mirror-choir", "delta": 12.0}],
		"next_order": 1,
	}
	payload["renown"] = {
		"log": [{"actor": "player", "kind": "infamy", "delta": 3.0}],
		"next_order": 1,
	}
	payload["quests"] = {"available": [], "active": [], "completed": []}
	payload["zhavar"] = {"dom": "rising", "dorthkor": "unprecedented"}
	payload["ng_plus"] = {
		"style_points": 31,
		"purchased_carry_overs": ["keep-renown"],
		"completion_metadata": {"ending_family": "stillpoint"},
	}
	var prepared: Dictionary = saves._prepare_for_load(payload)
	assert_bool(prepared["ok"]).is_true()
	var restored: Dictionary = prepared["payload"]
	assert_bool(restored["game_state"]["flags"]["chapter_dorthkor_commissioned"]).is_true()
	assert_float(restored["game_state"]["skills"]["vex"]["persuasion"]["percentage"]).is_equal_approx(74.5, 0.001)
	assert_str(restored["game_state"]["skills"]["vex"]["persuasion"]["tier"]).is_equal("Trained")
	assert_int(restored["game_state"]["skills"]["vex"]["persuasion"]["advancement_points_spent"]).is_equal(9)
	assert_int(restored["game_state"]["var_harmony"]["vex"]).is_equal(5)
	assert_float(restored["reputation"]["log"][0]["delta"]).is_equal_approx(12.0, 0.001)
	assert_str(restored["renown"]["log"][0]["kind"]).is_equal("infamy")
	assert_str(restored["zhavar"]["dorthkor"]).is_equal("unprecedented")
	assert_int(restored["ng_plus"]["style_points"]).is_equal(31)


func test_envelope_round_trip_preserves_var_harmony_boundaries() -> void:
	for boundary in [-5, 5]:
		var payload: Dictionary = saves._build_payload()
		payload["game_state"]["var_harmony"] = {"vex": boundary}

		var prepared: Dictionary = saves._prepare_for_load(payload)
		assert_bool(prepared["ok"]).is_true()
		assert_int(prepared["payload"]["game_state"]["var_harmony"]["vex"]).is_equal(
			boundary
		)


func test_corrupt_payload_fails_loudly_before_state_application() -> void:
	var corrupt: Dictionary = saves._build_payload()
	corrupt["game_state"]["skills"] = ["not-a-skill-map"]
	assert_bool(saves.validate_payload(corrupt)).is_false()
	assert_str(saves._prepare_for_load(corrupt)["error"]).contains("game_state")
	corrupt["game_state"] = "not-a-dictionary"
	assert_bool(saves.validate_payload(corrupt)).is_false()


func test_ng_plus_transform_is_idempotent_and_preserves_metadata() -> void:
	var initial := {"game_state": {"flags": {"new_game": true}}}
	var block := {
		"style_points": 23,
		"purchased_carry_overs": ["keep-renown", "keep-renown", "signature-item"],
		"completion_metadata": {"chapter": 1},
	}
	var once: Dictionary = saves.apply_ng_plus_to_new_game(initial, block)
	var twice: Dictionary = saves.apply_ng_plus_to_new_game(once, block)
	assert_int(once["ng_plus"]["style_points"]).is_equal(23)
	assert_int(twice["ng_plus"]["style_points"]).is_equal(23)
	assert_array(once["ng_plus"]["purchased_carry_overs"]).is_equal([
		"keep-renown", "signature-item"
	])
	assert_array(twice["ng_plus"]["purchased_carry_overs"]).is_equal([
		"keep-renown", "signature-item"
	])


func test_validation_rejects_non_gameplay_scene_injection() -> void:
	var payload := {
		"version": SaveGameScript.FORMAT_VERSION,
		"scene": "res://ui/screens/main_menu.tscn",
		"game_state": {},
		"reputation": {},
		"renown": {},
		"quests": {},
	}
	assert_bool(saves.validate_payload(payload)).is_false()


func test_format_two_is_an_intentional_clean_break() -> void:
	assert_int(SaveGameScript.FORMAT_VERSION).is_equal(2)


func test_named_spawn_ids_map_to_scene_marker_names() -> void:
	assert_str(saves._pascal_case("from_dorthkor")).is_equal("FromDorthkor")


func test_checkpoint_contract_names_player_visible_recovery_moments() -> void:
	assert_str(saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.NEW_GAME]).is_equal(
		"initial-spawn"
	)
	assert_str(saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.PARTY_FORMED]).is_equal(
		"party-formed"
	)
	assert_str(saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.COMMISSION]).is_equal(
		"commission-accepted"
	)
	assert_str(
		saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.LOCATION_ARRIVAL]
	).is_equal("arrived")
	assert_str(saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.ENCOUNTER_RESOLUTION]).is_equal(
		"encounter"
	)
	assert_str(saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.RULING]).is_equal("ruling")
	assert_str(saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.FREE_ROAM_UNLOCK]).is_equal(
		"free-roam-unlocked"
	)


func test_checkpoint_request_keeps_detail_in_autosave_reason() -> void:
	saves.request_checkpoint(SaveGameScript.Checkpoint.LOCATION_ARRIVAL, "dorthkor_reached")
	assert_str(saves._pending_autosave_reason).is_equal("arrived-dorthkor_reached")


func test_invalid_primary_payload_can_be_rejected_before_fallback() -> void:
	var invalid := {"version": SaveGameScript.FORMAT_VERSION, "scene": "user://broken"}
	assert_bool(saves.validate_payload(invalid)).is_false()
	assert_object(saves._read_payload("user://file-that-does-not-exist.save")).is_null()


func test_corrupted_primary_save_loads_from_last_known_good_backup() -> void:
	assert_bool(saves.save()).is_true()
	assert_bool(saves.save()).is_true()
	assert_bool(FileAccess.file_exists(saves.backup_path)).is_true()

	var corrupted := FileAccess.open(saves.save_path, FileAccess.WRITE)
	assert_object(corrupted).is_not_null()
	corrupted.store_string("truncated save")
	corrupted.close()

	assert_bool(saves.load_save()).is_true()


func test_missing_spawn_markers_are_resolved_as_a_diagnostic_failure() -> void:
	var scene := Node2D.new()
	scene.name = "MissingSpawnScene"
	var player := Node2D.new()
	player.name = "Player"
	scene.add_child(player)
	add_child(scene)
	saves.has_pending_player_position = false
	saves.pending_spawn_id = &"missing_arrival"

	assert_object(saves._resolve_spawn_marker(scene, "SpawnMissingArrival")).is_null()
	assert_int(diagnostics.size()).is_equal(2)
	assert_str(diagnostics[0]["severity"]).is_equal("warning")
	assert_str(diagnostics[0]["marker_name"]).is_equal("SpawnMissingArrival")
	assert_str(diagnostics[0]["scene_path"]).is_equal("MissingSpawnScene")
	assert_str(diagnostics[1]["severity"]).is_equal("error")
	assert_str(diagnostics[1]["marker_name"]).is_equal("SpawnDefault")
	assert_str(diagnostics[1]["scene_path"]).is_equal("MissingSpawnScene")
	saves.apply_pending_location(scene)
	assert_vector(player.global_position).is_equal(Vector2.ZERO)


func _remove_test_saves() -> void:
	for path in test_save_paths:
		var absolute_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute_path)


func _record_spawn_diagnostic(severity: String, marker_name: String, scene_path: String) -> void:
	diagnostics.append(
		{
			"severity": severity,
			"marker_name": marker_name,
			"scene_path": scene_path,
		}
	)
