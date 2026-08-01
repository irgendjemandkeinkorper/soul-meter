extends GdUnitTestSuite

const SaveGameScript := preload("res://globals/save_game.gd")
var saves


func before_test() -> void:
	saves = auto_free(SaveGameScript.new())


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
