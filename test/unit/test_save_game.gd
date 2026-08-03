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


func test_validation_rejects_malicious_or_invalid_payload_fields() -> void:
	var base_payload := {
		"version": SaveGameScript.FORMAT_VERSION,
		"scene": GameFlow.TOWN_SCENE,
		"game_state": {},
		"reputation": {},
		"renown": {},
		"quests": {},
	}

	# Test with too long spawn_id
	var payload_long_spawn := base_payload.duplicate()
	payload_long_spawn["spawn_id"] = "a".repeat(100)
	assert_bool(saves.validate_payload(payload_long_spawn)).is_false()

	# Test with non-string spawn_id
	var payload_invalid_spawn := base_payload.duplicate()
	payload_invalid_spawn["spawn_id"] = 123
	assert_bool(saves.validate_payload(payload_invalid_spawn)).is_false()

	# Test with non-numeric elapsed_seconds
	var payload_invalid_elapsed := base_payload.duplicate()
	payload_invalid_elapsed["elapsed_seconds"] = "not a number"
	assert_bool(saves.validate_payload(payload_invalid_elapsed)).is_false()


func test_flags_validation_and_coercion() -> void:
	# Test that game state successfully filters malicious or overly long flags
	var raw_data := {
		"inventory": {},
		"flags": {
			"safe_flag": true,
			"a".repeat(200): true, # overly long key
			"123": "number_as_key" # non-string key (integer) if parsed/deserialized
		},
		"soul_meter": 50.0,
		"gp": 100
	}
	# Set non-string key inside raw flags
	raw_data["flags"][123] = "invalid_key_type"

	assert_bool(GameState.from_dict(raw_data)).is_true()
	assert_bool(GameState.get_flag("safe_flag", false)).is_true()
	assert_bool(GameState.get_flag("a".repeat(200), false)).is_false()
	assert_bool(GameState.get_flag("123", false)).is_false()


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
