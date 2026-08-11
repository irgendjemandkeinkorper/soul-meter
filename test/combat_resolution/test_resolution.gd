extends GdUnitTestSuite

const ResolutionScript := preload("res://globals/combat/resolution.gd")


func test_worked_strom_strike_resolves_to_106_and_describes_writes() -> void:
	var result: Dictionary = ResolutionScript.resolve(_walkthrough_context())

	assert_bool(result["allowed"]).is_true()
	assert_int(result["damage"]).is_equal(106)
	assert_array(result["breakdown"].map(func(step: Dictionary) -> String: return step["id"])).contains_exactly([
		"power", "attack_scale", "element_matrix", "facing", "tile_charge"
	])
	assert_int(result["writes"][0]["before"]).is_equal(131)
	assert_int(result["writes"][0]["after"]).is_equal(25)
	assert_int(result["writes"][1]["before"]["charge_level"]).is_equal(2)
	assert_int(result["writes"][1]["after"]["charge_level"]).is_equal(3)
	assert_int(result["writes"][2]["before"]).is_equal(100)
	assert_int(result["writes"][2]["after"]).is_equal(70)


func test_identical_input_is_deterministic_across_many_resolutions() -> void:
	var context := _walkthrough_context()
	var expected: Dictionary = ResolutionScript.resolve(context)
	for iteration in range(64):
		var actual: Dictionary = ResolutionScript.resolve(context)
		assert_bool(actual == expected).override_failure_message(
			"Resolution differed on deterministic iteration %d." % iteration
		).is_true()


func test_forecast_and_resolution_modes_are_the_same_code_path() -> void:
	var forecast_context := _walkthrough_context()
	forecast_context["mode"] = &"forecast"
	var resolution_context := _walkthrough_context()
	resolution_context["mode"] = &"resolution"

	var forecast: Dictionary = ResolutionScript.resolve(forecast_context)
	var resolution: Dictionary = ResolutionScript.resolve(resolution_context)
	assert_bool(forecast == resolution).is_true()
	assert_array(var_to_bytes(forecast)).contains_exactly(var_to_bytes(resolution))


func test_refusal_uses_the_shared_gate_shape() -> void:
	var refusal: Dictionary = ResolutionScript.resolve({"unit": {}, "target": {}, "seed": 1})

	assert_bool(refusal["allowed"]).is_false()
	assert_str(refusal["blocked_by"]).is_equal("ability")
	assert_bool(refusal["nearest_unblock"] == {"type": "known_ability"}).is_true()
	assert_str(refusal["message"]).is_not_empty()
	for field in ["allowed", "blocked_by", "nearest_unblock", "message"]:
		assert_bool(refusal.has(field)).is_true()


func test_element_relationship_is_derived_from_element_wheel() -> void:
	var attack_element := ElementWheel.ORDER[0]
	var defend_element := ElementWheel.ORDER[ElementWheel.ORDER.size() / 2]
	var context := _walkthrough_context()
	context["ability"]["element_id"] = attack_element
	context["ability"]["elements"] = [attack_element]
	context["target"]["element_id"] = defend_element
	context["source_tile"]["charge_element_id"] = String(attack_element)

	var result: Dictionary = ResolutionScript.resolve(context)
	assert_int(result["element_relationship"]["distance"]).is_equal(
		ElementWheel.distance(attack_element, defend_element)
	)
	assert_str(result["element_relationship"]["relation"]).is_equal(
		ElementMatrix.relation(attack_element, defend_element)
	)


func test_resolution_does_not_mutate_any_input_dictionary() -> void:
	var context := _walkthrough_context()
	var before := context.duplicate(true)
	ResolutionScript.resolve(context)
	assert_bool(context == before).is_true()


func _walkthrough_context() -> Dictionary:
	return {
		"battle_id": "walkthrough",
		"tick": 12,
		"seed": 8675309,
		"unit": {
			"id": "caster",
			"attack_scale": 1.28,
			"ct": 100,
			"harmony": 0,
		},
		"ability": {
			"id": "strom_strike",
			"power": 42,
			"element_id": &"strom",
			"elements": [&"strom"],
			"magnitude": &"note",
			"matrix_multiplier": 1.50,
			"ct_cost": 30,
		},
		"target": {"id": "defender", "hp": 131, "element_id": &"terra"},
		"facing": {"id": &"side", "multiplier": 1.10},
		"source_tile": {
			"battle_id": "walkthrough",
			"x": 6,
			"y": 4,
			"charge_element_id": "strom",
			"charge_level": 2,
			"height_delta": 0,
			"hush": false,
		},
		"target_tile": {
			"battle_id": "walkthrough",
			"x": 7,
			"y": 4,
			"charge_element_id": "",
			"charge_level": 0,
			"height_delta": 0,
			"hush": false,
		},
		"weather": {
			"element_id": "strom",
			"weather_hush": false,
			"ticks_since_application": 3,
			"total_ticks": 19,
			"measures_applied": 1,
		},
	}
