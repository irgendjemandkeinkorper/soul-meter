extends GdUnitTestSuite

const SCHEMA_SIX_FIXTURE_PATH := "res://test/fixtures/save_game_schema_6.json"


func test_schema_five_defaults_expert_rerolls_to_zero_used() -> void:
	var payload := _schema_five_payload()
	var prepared: Dictionary = SaveMigrations.prepare(payload)

	assert_bool(prepared["ok"]).is_true()
	assert_int(prepared["payload"]["schema_version"]).is_equal(6)
	assert_bool(
		(prepared["payload"]["skill_check"]["expert_rerolls_used"] as Dictionary).is_empty()
	).is_true()


func test_expert_reroll_usage_is_clamped_without_changing_other_save_fields() -> void:
	var payload := _schema_five_payload()
	payload["marker"] = {"must_survive": true}
	payload["skill_check"] = {
		"expert_rerolls_used": {
			"scene:member:lore": 8,
			"scene:member:insight": -3,
		}
	}
	var prepared: Dictionary = SaveMigrations.prepare(payload)

	assert_bool(prepared["ok"]).is_true()
	var used: Dictionary = prepared["payload"]["skill_check"]["expert_rerolls_used"]
	assert_int(used["scene:member:lore"]).is_equal(SkillCheckService.EXPERT_REROLL_CAP)
	assert_int(used["scene:member:insight"]).is_equal(0)
	assert_bool(prepared["payload"]["marker"]["must_survive"]).is_true()


func test_schema_six_fixture_preserves_spent_expert_rerolls() -> void:
	var file := FileAccess.open(SCHEMA_SIX_FIXTURE_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_bool(parsed is Dictionary).is_true()
	var payload: Dictionary = parsed
	payload["schema_version"] = int(payload["schema_version"])
	payload["version"] = int(payload["version"])

	var prepared: Dictionary = SaveMigrations.prepare(payload)
	assert_bool(prepared["ok"]).is_true()
	var used: Dictionary = prepared["payload"]["skill_check"]["expert_rerolls_used"]
	assert_int(used["fixture-scene:fixture-unit:lore"]).is_equal(1)
	assert_bool(prepared["payload"].has("tactical")).is_true()


func _schema_five_payload() -> Dictionary:
	return {
		"version": 2,
		"schema_version": 5,
		"scene": "res://world/test_room.tscn",
		"game_state": {},
		"reputation": {},
		"renown": {},
		"quests": {},
		"zhavar": {},
		"ng_plus": {},
	}
