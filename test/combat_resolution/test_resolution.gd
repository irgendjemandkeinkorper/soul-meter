extends GdUnitTestSuite

const ResolutionScript := preload("res://globals/combat/resolution.gd")


func test_worked_zhur_strike_resolves_to_106_and_describes_writes() -> void:
	var result: Dictionary = ResolutionScript.resolve(_walkthrough_context())

	assert_bool(result["allowed"]).is_true()
	assert_int(result["damage"]).is_equal(106)
	assert_array(result["breakdown"].map(func(step: Dictionary) -> String: return step["id"])).contains_exactly([
		"power", "attack_scale", "element_matrix", "height", "facing", "tile_charge"
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


func test_height_advantage_adds_exactly_ten_percent_damage_per_step() -> void:
	var context := _walkthrough_context()
	context["ability"]["power"] = 100
	context["ability"]["matrix_multiplier"] = 1.0
	context["unit"]["attack_scale"] = 1.0
	context["source_tile"] = {}
	context["target_tile"] = {}
	context["facing"] = {"id": &"front"}
	context["height_advantage_steps"] = 3

	var result: Dictionary = ResolutionScript.resolve(context)

	assert_int(result["damage"]).is_equal(130)
	assert_float(result["positioning"]["height_multiplier"]).is_equal_approx(1.30, 0.0001)


func test_side_and_back_facing_use_ratified_damage_and_hit_bonuses() -> void:
	var context := _walkthrough_context()
	context["ability"]["power"] = 100
	context["ability"]["matrix_multiplier"] = 1.0
	context["unit"]["attack_scale"] = 1.0
	context["source_tile"] = {}
	context["target_tile"] = {}

	context["facing"] = {"id": &"side"}
	var side: Dictionary = ResolutionScript.resolve(context)
	assert_int(side["damage"]).is_equal(110)
	assert_int(side["hit_bonus"]).is_equal(8)

	context["facing"] = {"id": &"back"}
	var back: Dictionary = ResolutionScript.resolve(context)
	assert_int(back["damage"]).is_equal(125)
	assert_int(back["hit_bonus"]).is_equal(15)


func test_to_hit_disabled_by_default_and_always_hits() -> void:
	var result: Dictionary = ResolutionScript.resolve(_walkthrough_context())
	assert_bool(result["hit"]).is_true()
	assert_int(result["hit_chance"]).is_equal(100)
	assert_int(result["hit_roll"]).is_equal(0)


func test_to_hit_chance_uses_ratified_curve_and_clamps() -> void:
	# base 70 + back 15 + 4*2 = 93
	var context := _walkthrough_context()
	context["to_hit_enabled"] = true
	context["facing"] = {"id": &"back"}
	context["height_advantage_steps"] = 2
	var result: Dictionary = ResolutionScript.resolve(context)
	assert_int(result["hit_chance"]).is_equal(93)

	# base 70 + front 0 - 4*20 clamps to the 5 floor
	context["facing"] = {"id": &"front"}
	context["height_advantage_steps"] = -20
	result = ResolutionScript.resolve(context)
	assert_int(result["hit_chance"]).is_equal(5)

	# base 70 + back 15 + 4*10 clamps to the 95 cap
	context["facing"] = {"id": &"back"}
	context["height_advantage_steps"] = 10
	result = ResolutionScript.resolve(context)
	assert_int(result["hit_chance"]).is_equal(95)


func test_to_hit_roll_is_deterministic_and_a_miss_deals_zero_without_detonation() -> void:
	var context := _walkthrough_context()
	context["to_hit_enabled"] = true
	context["facing"] = {"id": &"front"}
	context["height_advantage_steps"] = -20  # 5% chance: find a missing seed fast
	var missing_seed := -1
	for candidate in range(1, 400):
		context["seed"] = candidate
		var probe: Dictionary = ResolutionScript.resolve(context)
		if not bool(probe["hit"]):
			missing_seed = candidate
			break
	assert_int(missing_seed).is_greater(0)

	context["seed"] = missing_seed
	var miss: Dictionary = ResolutionScript.resolve(context)
	var repeat: Dictionary = ResolutionScript.resolve(context)
	assert_bool(miss == repeat).is_true()
	assert_bool(miss["hit"]).is_false()
	assert_int(miss["damage"]).is_equal(0)
	assert_int(miss["writes"][0]["delta"]).is_equal(0)
	for write: Dictionary in miss["writes"]:
		if write.get("kind", "") == "tile_state":
			assert_str(str(write.get("operation", ""))).is_not_equal("detonation")


func test_cast_fizzle_is_deterministic_and_still_pays_cost_and_leaves_residue() -> void:
	var context := _walkthrough_context()
	context["ability"]["is_spell"] = true
	context["ability"]["breath_cost"] = 3
	context["unit"]["breath"] = 1
	context["soul_meter"] = 10.0
	context["fizzle"] = {
		"agreement_integrity": 0.0,
		"pitch": 2,
		"mastery": false,
		"patron": "",
	}
	var fizzling_seed := -1
	for candidate in range(1, 400):
		context["seed"] = candidate
		if bool(ResolutionScript.resolve(context).get("fizzled", false)):
			fizzling_seed = candidate
			break
	assert_int(fizzling_seed).is_greater(0)

	context["seed"] = fizzling_seed
	var first: Dictionary = ResolutionScript.resolve(context)
	var repeated: Dictionary = ResolutionScript.resolve(context)

	assert_bool(first == repeated).is_true()
	assert_bool(first["fizzled"]).is_true()
	assert_int(first["damage"]).is_equal(0)
	assert_int(first["fizzle_roll"]).is_equal(repeated["fizzle_roll"])
	assert_array(first["writes"].map(func(write: Dictionary) -> String: return str(write["kind"]))).contains([
		"breath", "soul_meter", "tile_state",
	])
	var residue_write: Dictionary = first["writes"].filter(
		func(write: Dictionary) -> bool: return write.get("operation", "") == "residue"
	)[0]
	assert_str(residue_write["after"]["charge_element_id"]).is_equal(
		String(ElementWheel.opposite(&"zhur"))
	)


func test_khash_clean_target_does_not_burst_its_fresh_aftertone() -> void:
	var context := _walkthrough_context()
	context["ability"]["element_id"] = &"khash"
	context["ability"]["elements"] = [&"khash"]
	context["ability"]["is_spell"] = true
	var result: Dictionary = ResolutionScript.resolve(context)
	assert_bool(result["fizzled"]).is_false()
	assert_bool(result["writes"].any(func(write: Dictionary) -> bool: return write.get("kind", "") == "aftertone_spent")).is_false()
	var aftertone_write: Dictionary = result["writes"].filter(func(write: Dictionary) -> bool: return write.get("kind", "") == "aftertones")[0]
	assert_int((aftertone_write["after"] as Array).size()).is_equal(1)


func test_fizzled_khash_does_not_consume_existing_aftertone() -> void:
	var context := _walkthrough_context()
	context["ability"]["element_id"] = &"khash"
	context["ability"]["elements"] = [&"khash"]
	context["ability"]["is_spell"] = true
	context["fizzle"] = {"agreement_integrity": 0.0, "mastery": false}
	context["target"]["aftertones"] = [{"element": &"sul", "remaining_rounds": 2}]
	var result: Dictionary = ResolutionScript.resolve(context)
	assert_bool(result["fizzled"]).is_true()
	assert_bool(result["writes"].any(func(write: Dictionary) -> bool: return write.get("kind", "") == "aftertone_spent")).is_false()
	assert_bool(result["writes"].any(func(write: Dictionary) -> bool: return write.get("kind", "") == "aftertones")).is_false()


func test_cast_cost_spends_breath_then_soul_and_refuses_insufficient_soul_without_writes() -> void:
	var context := _walkthrough_context()
	context["ability"]["is_spell"] = true
	context["ability"]["breath_cost"] = 4
	context["unit"]["breath"] = 1
	context["soul_meter"] = 5.0
	context["fizzle"] = {"agreement_integrity": 100.0, "pitch": 2}

	var accepted: Dictionary = ResolutionScript.resolve(context)
	var breath_write: Dictionary = accepted["writes"].filter(
		func(write: Dictionary) -> bool: return write.get("kind", "") == "breath"
	)[0]
	var soul_write: Dictionary = accepted["writes"].filter(
		func(write: Dictionary) -> bool: return write.get("kind", "") == "soul_meter"
	)[0]
	assert_int(breath_write["after"]).is_equal(0)
	assert_float(soul_write["after"]).is_equal(2.0)

	context["soul_meter"] = 2.0
	var refused: Dictionary = ResolutionScript.resolve(context)
	assert_bool(refused["allowed"]).is_false()
	assert_str(refused["blocked_by"]).is_equal("soul")
	assert_bool(refused.has("writes")).is_false()


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
			"id": "zhur_strike",
			"power": 42,
			"element_id": &"zhur",
			"elements": [&"zhur"],
			"magnitude": &"note",
			"matrix_multiplier": 1.50,
			"ct_cost": 30,
		},
		"target": {"id": "defender", "hp": 131, "element_id": &"tham"},
		"facing": {"id": &"side", "multiplier": 1.10},
		"source_tile": {
			"battle_id": "walkthrough",
			"x": 6,
			"y": 4,
			"charge_element_id": "zhur",
			"charge_level": 2,
			"height_delta": 0,
			"cover": false,
			"hush": false,
		},
		"target_tile": {
			"battle_id": "walkthrough",
			"x": 7,
			"y": 4,
			"charge_element_id": "",
			"charge_level": 0,
			"height_delta": 0,
			"cover": false,
			"hush": false,
		},
		"weather": {
			"element_id": "zhur",
			"weather_hush": false,
			"ticks_since_application": 3,
			"total_ticks": 19,
			"measures_applied": 1,
		},
	}


func test_harmonic_accord_key_drives_the_fizzle_and_the_legacy_alias_still_does() -> void:
	# #329 renames Agreement Integrity to Harmonic Accord. A rename is only safe if it moves
	# no numbers, so this pins both halves: the new key has to actually be read (not silently
	# fall through to the neutral 100), and the old spelling has to keep working for one wave.
	var discriminating_seed := -1
	for candidate in range(1, 400):
		if _fizzles_at(candidate, "harmonic_accord", 0.0) and not _fizzles_at(candidate, "harmonic_accord", 100.0):
			discriminating_seed = candidate
			break
	assert_int(discriminating_seed).override_failure_message(
		"no seed separates accord 0 from accord 100, so this test could not tell a read key from an ignored one"
	).is_greater(0)

	assert_bool(_fizzles_at(discriminating_seed, "harmonic_accord", 0.0)).override_failure_message(
		"the harmonic_accord key must reach the fizzle formula"
	).is_true()
	assert_bool(_fizzles_at(discriminating_seed, "agreement_integrity", 0.0)).override_failure_message(
		"the agreement_integrity alias must stay readable for one wave"
	).is_true()
	# And the alias must not be a floor: a high accord under either spelling still holds.
	assert_bool(_fizzles_at(discriminating_seed, "agreement_integrity", 100.0)).is_false()


func _fizzles_at(seed_value: int, accord_key: String, accord: float) -> bool:
	var context := _walkthrough_context()
	context["ability"]["is_spell"] = true
	context["seed"] = seed_value
	context["fizzle"] = {accord_key: accord, "pitch": 2, "mastery": false, "patron": ""}
	return bool(ResolutionScript.resolve(context).get("fizzled", false))
