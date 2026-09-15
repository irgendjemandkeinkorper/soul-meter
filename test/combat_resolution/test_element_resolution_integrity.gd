extends GdUnitTestSuite


func test_utility_elements_have_no_direct_damage_even_with_power_and_attribution() -> void:
	for element: StringName in [&"khor", &"zhem"]:
		var context := _context(element)
		context["hidden_draw"] = {"table_id": "test", "seed_key": "test", "rows": [{"id": "bonus", "bonus_damage": 3}]}
		var before := context.duplicate(true)
		var result := Resolution.resolve(context)
		assert_bool(result.allowed).is_true()
		assert_int(result.damage).is_equal(0)
		assert_int(result.writes[0].after).is_equal(100)
		assert_dict(context).is_equal(before)
		assert_bool(result.get("direct_damage_enabled", true)).is_false()


func test_utility_compositions_keep_their_useful_effects_and_costs() -> void:
	var khor := _context(&"khor")
	khor.unit["aftertones"] = [{"element": "luth", "remaining_rounds": 2, "held": false, "anchored": false}]
	var held := Resolution.resolve(khor)
	assert_bool(_write(held, "aftertones", "caster").after[0].held).is_true()
	assert_int(_write(held, "breath", "caster").after).is_equal(7)
	var zhem := _context(&"zhem")
	zhem.target["aftertones"] = [{"element": "khash", "remaining_rounds": 2, "held": false, "anchored": false}]
	zhem.target["tempo"] = 3
	var muted := Resolution.resolve(zhem)
	assert_int(_write(muted, "tempo", "target").after).is_equal(0)
	var aftertones: Array = _write(muted, "aftertones", "target").after
	assert_bool(aftertones.any(func(a: Dictionary) -> bool: return a.element == "khash")).is_false()
	assert_int(_write(muted, "breath", "caster").after).is_equal(7)


func test_utility_center_triads_cannot_gain_direct_damage_from_a_khash_rule_bend() -> void:
	for elements: Array in [[&"luth", &"khor", &"tham"], [&"khash", &"zhem", &"zhur"]]:
		var context := _context(elements[1])
		context.ability["elements"] = elements
		context.ability["magnitude"] = &"song"
		context.unit["harmony"] = 10
		context.target["aftertones"] = [{"element": "vel", "remaining_rounds": 2, "anchored": false}]
		var result := Resolution.resolve(context)
		assert_bool(result.allowed).override_failure_message(str(result)).is_true()
		if bool(result.allowed):
			assert_int(result.damage).is_equal(0)


func test_mundane_attacks_and_damaging_compositions_keep_damage() -> void:
	var weapon := _context(&"zhem")
	weapon.ability["is_spell"] = false
	assert_int(Resolution.resolve(weapon).damage).is_greater(0)
	var chord := _context(&"khash")
	chord.ability["elements"] = [&"khash", &"zhem"]
	assert_int(Resolution.resolve(chord).damage).is_greater(0)


func test_hush_suppresses_tile_effects_without_refusing_spells_or_weapons() -> void:
	for scope: String in ["source", "target", "weather"]:
		for is_spell: bool in [false, true]:
			var context := _context(&"zhur")
			context.ability["is_spell"] = is_spell
			context.source_tile["charge_element_id"] = "zhur"
			context.source_tile["charge_level"] = 2
			context.target_tile["charge_element_id"] = "tham"
			context.target_tile["charge_level"] = 2
			if scope == "weather":
				context["weather"] = {"weather_hush": true}
			else:
				context[scope + "_tile"]["hush"] = true
			var before := context.duplicate(true)
			var result := Resolution.resolve(context)
			assert_bool(result.allowed).override_failure_message("Hush rejected the action: " + scope).is_true()
			if not bool(result.allowed):
				continue
			assert_int(result.damage).is_greater(0)
			assert_dict(context).is_equal(before)
			for write: Dictionary in result.writes:
				if write.kind != "tile_state":
					continue
				assert_bool(scope != "weather").is_true()
				assert_bool(int(write.x) != (0 if scope == "source" else 1)).is_true()
			if is_spell:
				assert_int(_write(result, "breath", "caster").after).is_equal(7)


func test_clash_detonation_remains_separate_environmental_damage_for_utility_cast() -> void:
	var context := _context(&"khor")
	context.target_tile["charge_element_id"] = "zhem"
	context.target_tile["charge_level"] = 2
	var result := Resolution.resolve(context)
	assert_int(result.damage).is_equal(2 * TileState.DETONATION_MULTIPLIER)
	context.target_tile["hush"] = true
	var suppressed := Resolution.resolve(context)
	assert_bool(suppressed.allowed).is_true()
	if bool(suppressed.allowed):
		assert_int(suppressed.damage).is_equal(0)


func _write(result: Dictionary, kind: String, target_id: String) -> Dictionary:
	for write: Dictionary in result.get("writes", []):
		if str(write.get("kind", "")) == kind and str(write.get("target_id", "")) == target_id:
			return write
	assert_bool(false).override_failure_message("Missing %s write for %s" % [kind, target_id]).is_true()
	return {}


func _context(element: StringName) -> Dictionary:
	return {
		"battle_id": "element-integrity", "tick": 1, "seed": 17,
		"unit": {"id": "caster", "attack_scale": 1.0, "breath": 10, "harmony": 0},
		"ability": {"id": "element-test", "is_spell": true, "element_id": element, "elements": [element], "magnitude": "note", "power": 20, "breath_cost": 3, "matrix_multiplier": 1.0},
		"target": {"id": "target", "hp": 100, "element_id": "sul", "attunements": {}},
		"fizzle_percent_override": 0.0, "soul_meter": 50.0,
		"source_tile": TileState.create(&"element-integrity", 0, 0).to_dict(),
		"target_tile": TileState.create(&"element-integrity", 1, 0).to_dict(),
	}
