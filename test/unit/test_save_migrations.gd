extends GdUnitTestSuite

const SCHEMA_SIX_FIXTURE_PATH := "res://test/fixtures/save_game_schema_6.json"
const SCHEMA_SEVEN_FIXTURE_PATH := "res://test/fixtures/save_game_schema_7.json"


func test_schema_five_defaults_expert_rerolls_to_zero_used() -> void:
	var payload := _schema_five_payload()
	var prepared: Dictionary = SaveMigrations.prepare(payload)

	assert_bool(prepared["ok"]).is_true()
	assert_int(prepared["payload"]["schema_version"]).is_equal(8)
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


func test_schema_six_fixture_gains_the_default_world_clock() -> void:
	# FR-504a §5 criterion 1: a save written before the clock existed loads
	# and receives the default phase.
	var file := FileAccess.open(SCHEMA_SIX_FIXTURE_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var payload: Dictionary = parsed
	payload["schema_version"] = int(payload["schema_version"])
	payload["version"] = int(payload["version"])

	var prepared: Dictionary = SaveMigrations.prepare(payload)
	assert_bool(prepared["ok"]).is_true()
	assert_int(prepared["payload"]["schema_version"]).is_equal(8)
	assert_str(str(prepared["payload"]["world_clock"]["phase"])).is_equal("morning")


func test_schema_six_fixture_defaults_party_breath_to_full() -> void:
	var payload := _fixture(SCHEMA_SIX_FIXTURE_PATH)

	var prepared: Dictionary = SaveMigrations.prepare(payload)

	assert_bool(prepared["ok"]).is_true()
	var member: Dictionary = prepared["payload"]["game_state"]["party"][0]
	assert_int(member["breath_max"]).is_equal(15)
	assert_int(member["breath"]).is_equal(member["breath_max"])


func test_schema_seven_fixture_preserves_spent_breath() -> void:
	var payload := _fixture(SCHEMA_SEVEN_FIXTURE_PATH)

	var prepared: Dictionary = SaveMigrations.prepare(payload)

	assert_bool(prepared["ok"]).is_true()
	var member: Dictionary = prepared["payload"]["game_state"]["party"][0]
	assert_int(int(member["breath_max"])).is_equal(15)
	assert_int(int(member["breath"])).is_equal(6)


func test_schema_five_payload_also_gains_the_default_world_clock() -> void:
	var prepared: Dictionary = SaveMigrations.prepare(_schema_five_payload())
	assert_bool(prepared["ok"]).is_true()
	assert_str(str(prepared["payload"]["world_clock"]["phase"])).is_equal("morning")


func test_migration_preserves_an_existing_world_clock_phase() -> void:
	var payload := _schema_five_payload()
	payload["schema_version"] = 7
	payload["world_clock"] = {"phase": "night"}
	var prepared: Dictionary = SaveMigrations.prepare(payload)
	assert_bool(prepared["ok"]).is_true()
	assert_str(str(prepared["payload"]["world_clock"]["phase"])).is_equal("night")


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


func _fixture(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_object(file).is_not_null()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_bool(parsed is Dictionary).is_true()
	var payload: Dictionary = parsed
	payload["schema_version"] = int(payload["schema_version"])
	payload["version"] = int(payload["version"])
	return payload


## The schema-8 element rename. The schema-7 fixture is a historical artifact and
## deliberately still carries the pre-rename ids — it is the evidence that the
## migration does its job, so it must never be find-and-replaced along with the
## source.
func test_schema_seven_fixture_renames_every_element_id_except_khor() -> void:
	var payload := _fixture(SCHEMA_SEVEN_FIXTURE_PATH)
	var prepared: Dictionary = SaveMigrations.prepare(payload)

	assert_bool(prepared["ok"]).is_true()
	assert_int(prepared["payload"]["schema_version"]).is_equal(8)

	var attunements: Dictionary = prepared["payload"]["tactical"]["unit_attunement"]
	assert_bool(attunements.is_empty()).is_false()
	for unit_id: Variant in attunements.keys():
		var values: Dictionary = (attunements[unit_id] as Dictionary)["values"]
		for element: StringName in ElementWheel.ORDER:
			assert_bool(values.has(String(element))).is_true()
		for old_id: String in SaveMigrations.ELEMENT_RENAMES_V8.keys():
			assert_bool(values.has(old_id)).is_false()


func test_element_rename_preserves_attunement_values_across_the_slate() -> void:
	var payload := _fixture(SCHEMA_SEVEN_FIXTURE_PATH)
	var before: Dictionary = payload["tactical"]["unit_attunement"]
	var unit_id: String = str(before.keys()[0])
	var original: Dictionary = (before[unit_id] as Dictionary)["values"].duplicate(true)

	var prepared: Dictionary = SaveMigrations.prepare(payload)
	var after: Dictionary = (
		(prepared["payload"]["tactical"]["unit_attunement"][unit_id] as Dictionary)["values"]
	)

	for old_id: Variant in original.keys():
		var new_id: String = SaveMigrations._rename_element(str(old_id))
		assert_int(int(after[new_id])).is_equal(int(original[old_id]))
	# khor is the one element whose id did not change.
	assert_bool(after.has("khor")).is_true()


func test_party_element_fields_and_tone_skill_ids_are_renamed() -> void:
	var payload := _schema_five_payload()
	payload["schema_version"] = 7
	payload["game_state"] = {
		"party": [{
			"id": "pc",
			"major_element": "scor",
			"minor_element": "khor",
			"mastery_element": "nul",
			"skill_percentages": {"tone_scor": 45, "tone_khor": 30, "athletics": 20},
			"skill_tiers": {"tone_strom": "trained"},
		}],
	}
	var prepared: Dictionary = SaveMigrations.prepare(payload)
	var member: Dictionary = prepared["payload"]["game_state"]["party"][0]

	assert_str(str(member["major_element"])).is_equal("khash")
	assert_str(str(member["minor_element"])).is_equal("khor")
	assert_str(str(member["mastery_element"])).is_equal("zhem")
	assert_bool((member["skill_percentages"] as Dictionary).has("tone_khash")).is_true()
	assert_int(int(member["skill_percentages"]["tone_khash"])).is_equal(45)
	assert_int(int(member["skill_percentages"]["tone_khor"])).is_equal(30)
	assert_int(int(member["skill_percentages"]["athletics"])).is_equal(20)
	assert_bool((member["skill_tiers"] as Dictionary).has("tone_zhur")).is_true()


## Running the rename over already-current ids must be a no-op, so a schema-8
## save that is re-prepared (or a partially migrated one) is not corrupted.
func test_element_rename_is_idempotent() -> void:
	assert_str(SaveMigrations._rename_element("khash")).is_equal("khash")
	assert_str(SaveMigrations._rename_element("khor")).is_equal("khor")
	assert_str(SaveMigrations._rename_element("")).is_equal("")
