extends GdUnitTestSuite
## #285 slice 4 seams in isolation: Resolution's Second Casting conversion and the flat
## Debt of Arms bonus, and the Vicoar resource that offers and pays for Second Casting.


func test_second_casting_turns_a_fizzle_into_a_success() -> void:
	var context := _spell_context()
	context["fizzle_percent_override"] = 100.0
	assert_bool(bool(Resolution.resolve(context)["fizzled"])).is_true()
	context["second_casting"] = true
	var saved := Resolution.resolve(context)
	assert_bool(bool(saved["fizzled"])).is_false()
	assert_bool(bool(saved["second_cast"])).is_true()
	assert_int(int(saved["damage"])).is_greater(0)
	# No fizzle, nothing to convert: the offer is not spent.
	context["fizzle_percent_override"] = 0.0
	assert_bool(bool(Resolution.resolve(context)["second_cast"])).is_false()


func test_bonus_damage_adds_to_a_landed_attack_only() -> void:
	var context := _spell_context()
	context["fizzle_percent_override"] = 0.0
	var plain := int(Resolution.resolve(context)["damage"])
	context["bonus_damage"] = 6
	var paid := Resolution.resolve(context)
	assert_int(int(paid["damage"])).is_equal(plain + 6)
	context["fizzle_percent_override"] = 100.0
	assert_int(int(Resolution.resolve(context)["damage"])).override_failure_message("a fizzle lands nothing").is_equal(0)


func test_vicoar_offers_second_casting_with_two_tokens_once_per_battle() -> void:
	var plain := ClassResourceRegistry.for_patron("Vicoar") as VicoarInstructiveFailure
	plain.tokens = 2
	assert_dict(plain.on_cast_forecast({})).is_empty()
	var vicoar := ClassResourceRegistry.for_patron("Vicoar") as VicoarInstructiveFailure
	vicoar.apply_perks(PackedStringArray(["flamebinder-second-casting"]))
	vicoar.tokens = 1
	assert_dict(vicoar.on_cast_forecast({})).is_empty()
	vicoar.tokens = 2
	assert_bool(bool(vicoar.on_cast_forecast({}).get("second_casting", false))).is_true()
	var event := CombatEvent.new()
	event.data = {"action_id": "cast-seam", "verb": CombatAction.Verb.CAST, "resolution": {"fizzled": false, "second_cast": true}}
	vicoar.on_action(event)
	assert_int(vicoar.tokens).is_equal(0)
	assert_bool(vicoar.second_casting_used).is_true()
	vicoar.tokens = 3
	assert_dict(vicoar.on_cast_forecast({})).override_failure_message("once per battle").is_empty()
	var restored := ClassResourceRegistry.from_dict(vicoar.to_dict()) as VicoarInstructiveFailure
	assert_bool(restored.second_casting_used).is_true()


func test_carries_are_capped_and_empty_without_the_perk() -> void:
	var lens := ClassResourceRegistry.for_patron("Stuid") as StuidClarity
	assert_dict(lens.carry_out()).is_empty()
	lens.apply_perks(PackedStringArray(["lensbearer-kept-focus"]))
	lens.clarity = 0
	assert_dict(lens.carry_out()).override_failure_message("nothing unspent, nothing kept").is_empty()
	lens.clarity = 2
	assert_dict(lens.carry_out()).is_equal({"clarity": 1})
	var flame := ClassResourceRegistry.for_patron("Vicoar") as VicoarInstructiveFailure
	flame.apply_perks(PackedStringArray(["flamebinder-carried-lesson"]))
	flame.tokens = 3
	assert_dict(flame.carry_out()).is_equal({"tokens": 1})
	var fresh := ClassResourceRegistry.for_patron("Vicoar") as VicoarInstructiveFailure
	fresh.receive_carry({"tokens": 99})
	assert_int(fresh.tokens).is_equal(fresh.max_tokens())


func _spell_context() -> Dictionary:
	return {
		"battle_id": "perk-signatures",
		"tick": 3,
		"seed": 11,
		"unit": {"id": "ally-0", "attack_scale": 1.0, "edge": 0, "breath": 20, "harmony": 0},
		"ability": {"id": "note-khash", "element_id": "khash", "elements": ["khash"], "magnitude": "note", "power": 6, "is_spell": true, "breath_cost": 3},
		"target": {"id": "enemy-0", "hp": 30, "element_id": "luth", "edge": 0, "height": 0, "attunements": {}},
		"soul_meter": 50.0,
		"fizzle": {"agreement_integrity": 80.0, "pitch": 3},
		"caster_context": {},
	}
