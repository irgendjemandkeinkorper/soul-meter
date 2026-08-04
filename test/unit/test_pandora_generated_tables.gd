extends GdUnitTestSuite


func test_elements_artifact_contains_the_ratified_pandora_tables() -> void:
	var data := _json("res://data/generated/elements.json")
	assert_int(data["elements"].size()).is_equal(10)
	assert_int(data["triads"].size()).is_equal(10)
	assert_int(data["impositions"].size()).is_equal(8)
	assert_int(data["rule_bends"].size()).is_equal(10)
	assert_int(data["breadths"].size()).is_equal(3)
	assert_int(data["magnitudes"].size()).is_equal(4)
	assert_str(data["elements"][0]["vault_id"]).is_equal("elements-and-music")
	assert_str(data["triads"][0]["unique_effect"]["id"]).is_equal("first_light")


func test_fizzle_artifact_has_formula_inputs_and_vault_bridge() -> void:
	var data := _json("res://data/generated/fizzle_table.json")
	assert_str(data["vault_id"]).is_equal("magic-system")
	assert_float(data["breadth_add"]["triad"]).is_equal(12.0)
	assert_float(data["strain_add"]["4"]).is_equal(18.0)
	assert_float(data["magnitude_multiplier"]["refrain"]).is_equal(2.75)


func test_encounter_artifact_exposes_schema_and_authored_phase_two_content() -> void:
	var data := _json("res://data/generated/encounters.json")
	for encounter_id: String in data:
		var row: Dictionary = data[encounter_id]
		assert_bool(row.has("composition")).is_true()
		assert_bool(row.has("zone_layout")).is_true()
		assert_bool(row.has("balance_bias")).is_true()
		assert_bool(row.has("speech_hooks")).is_true()

	var gate_ids: Array[String] = [
		"phase2-demon",
		"phase2-undead",
		"phase2-mixed-whipsaw",
		"phase2-speech-winnable",
		"phase2-stabilizer-showcase",
	]
	for encounter_id: String in gate_ids:
		assert_bool(data.has(encounter_id)).is_true()
		var row: Dictionary = data[encounter_id]
		assert_bool(row["composition"].is_empty()).is_false()
		assert_bool(row["zone_layout"].is_empty()).is_false()


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_bool(parsed is Dictionary).is_true()
	return parsed
