extends GdUnitTestSuite

const ResolutionScript := preload("res://globals/combat/resolution.gd")


func test_aftertones_tick_and_anchoring() -> void:
	var actor := BattleActor.new()
	actor.aftertones = [{"element": &"suul", "remaining_rounds": 2, "anchored": false}]
	actor.tick_aftertones()
	assert_int(actor.aftertones[0]["remaining_rounds"]).is_equal(1)
	actor.aftertones[0]["anchored"] = true
	actor.tick_aftertones()
	assert_int(actor.aftertones[0]["remaining_rounds"]).is_equal(1)


func test_rule_bends_anchor_consume_clear_and_hold_notes() -> void:
	var terra := _resolve(&"terra", [], [{"element": &"suul", "remaining_rounds": 2}])
	assert_bool(_has_aftertone(terra, true)).is_true()
	var scor := _resolve(&"scor", [], [{"element": &"suul", "remaining_rounds": 2}])
	assert_int(scor["damage"]).is_equal(2)
	assert_bool(_has_aftertone(scor, false)).is_true()
	var nul := _resolve(&"nul", [], [{"element": &"suul", "remaining_rounds": 2}], 3)
	assert_bool(_has_write(nul, "tempo")).is_true()
	assert_bool(_aftertone_write_is_empty(nul)).is_true()
	var khor := _resolve(&"khor", [{"element": &"suul", "remaining_rounds": 2}], [])
	assert_bool(_has_held_aftertone(khor)).is_true()


func test_every_pandora_triad_emits_its_declarative_effect() -> void:
	for triad: TriadDefinition in ElementsData.all_triads():
		var result: Dictionary = ResolutionScript.resolve({
			"unit": {"id": "caster", "harmony": 10},
			"ability": {"id": "triad", "element_id": triad.center_element, "elements": triad.elements, "magnitude": "song", "power": 1},
			"target": {"id": "target", "hp": 10, "element_id": "suul"},
		})
		assert_bool(result["allowed"]).is_true()
		assert_str(str(result["composition"]["triad_effect_id"])).is_equal(str(triad.unique_effect_id))
		assert_bool(_has_write(result, "triad_effect")).is_true()


func test_stillpoint_applies_balance_consumer() -> void:
	var controller := _controller()
	controller.balance = 3
	controller._apply_triad_effect(controller.allies[0], controller.enemies[0], {"effect_id": "the_held_silence", "parameters": {"balance_gauge": "exact_center", "lock_until": "end_of_next_round"}})
	assert_int(controller.balance).is_equal(0)


func test_founding_anchors_everyone_and_freezes_duration() -> void:
	var controller := _controller()
	controller.allies[0].aftertones = [{"remaining_rounds": 2}]
	controller._apply_triad_effect(controller.allies[0], controller.enemies[0], {"effect_id": "cornerstone"})
	assert_bool(controller.allies[0].aftertones[0]["anchored"]).is_true()
	assert_int(controller.duration_freeze_until_round).is_equal(1)


func test_vault_caster_aftertones_are_anchored() -> void:
	var controller := _controller()
	controller.allies[0].aftertones = [{"remaining_rounds": 2}]
	controller._apply_triad_effect(controller.allies[0], controller.enemies[0], {"effect_id": "sealed_ground"})
	assert_bool(controller.allies[0].aftertones[0]["anchored"]).is_true()


func test_pyre_converts_dead_enemies_and_spent_aftertones_to_breath() -> void:
	var controller := _controller()
	controller.enemies[0].hp = 0
	controller.spent_aftertones = 1
	controller._apply_triad_effect(controller.allies[0], controller.enemies[0], {"effect_id": "the_rendering"})
	assert_int(controller.allies[0].breath).is_equal(2)


func test_cinderfall_clears_both_sides_and_records_burst() -> void:
	var controller := _controller()
	controller.allies[0].aftertones = [{"remaining_rounds": 2}]
	controller.enemies[0].aftertones = [{"remaining_rounds": 2}, {"remaining_rounds": 2}]
	controller._apply_triad_effect(controller.allies[0], controller.enemies[0], {"effect_id": "everything_burns_at_once"})
	assert_int(controller.allies[0].aftertones.size()).is_equal(0)
	assert_int(controller.allies[0].defining_effects["burst_bonus"]).is_equal(3)


func test_thunderhead_marks_allies_as_hit() -> void:
	var controller := _controller()
	controller._apply_triad_effect(controller.allies[0], controller.enemies[0], {"effect_id": "nothing_is_uncertain"})
	assert_bool(controller.allies[0].defining_effects["hit"]).is_true()


func test_dayspring_reveals_the_caster_side() -> void:
	var controller := _controller()
	controller._apply_triad_effect(controller.allies[0], controller.enemies[0], {"effect_id": "first_light"})
	assert_int(controller.revealed_until_round).is_equal(0)


func test_barrow_conceals_the_caster_side() -> void:
	var controller := _controller()
	controller._apply_triad_effect(controller.allies[0], controller.enemies[0], {"effect_id": "unlisted"})
	assert_int(controller.concealed_until_round).is_equal(0)


func test_rivermouth_opens_zone_boundaries_for_the_side() -> void:
	var controller := _controller()
	controller._apply_triad_effect(controller.allies[0], controller.enemies[0], {"effect_id": "the_mouth_opens"})
	assert_int(controller.allies[0].defining_effects["range_bonus"]).is_equal(1)


func test_fruiting_extends_friendly_aftertones() -> void:
	var controller := _controller()
	controller.allies[0].aftertones = [{"remaining_rounds": 2, "held": true}]
	controller._apply_triad_effect(controller.allies[0], controller.enemies[0], {"effect_id": "second_season"})
	assert_int(controller.allies[0].aftertones[0]["remaining_rounds"]).is_equal(3)


func _controller() -> CombatController:
	var controller := CombatController.new()
	var ally := BattleActor.new()
	ally.combat_id = &"ally-0"
	ally.side = &"ally"
	var enemy := BattleActor.new()
	enemy.combat_id = &"enemy-0"
	enemy.side = &"enemy"
	controller.allies = [ally]
	controller.enemies = [enemy]
	return controller


func _resolve(element: StringName, aftertones: Array, target_aftertones: Array = [], tempo: int = 0) -> Dictionary:
	return ResolutionScript.resolve({
		"unit": {"id": "caster", "harmony": 10, "aftertones": aftertones, "tempo": tempo},
		"ability": {"id": "bend", "element_id": element, "magnitude": "note", "power": 1, "is_spell": true},
		"target": {"id": "target", "hp": 10, "element_id": "suul", "aftertones": target_aftertones, "tempo": tempo},
	})


func _has_write(result: Dictionary, kind: String) -> bool:
	for write: Dictionary in result.get("writes", []):
		if str(write.get("kind", "")) == kind:
			return true
	return false


func _has_aftertone(result: Dictionary, anchored: bool) -> bool:
	for write: Dictionary in result.get("writes", []):
		if write.get("kind", "") == "aftertones":
			for aftertone: Dictionary in write.get("after", []):
				if bool(aftertone.get("anchored", false)) == anchored:
					return true
	return false


func _aftertone_write_is_empty(result: Dictionary) -> bool:
	for write: Dictionary in result.get("writes", []):
		if write.get("kind", "") == "aftertones":
			return (write.get("after", []) as Array).is_empty()
	return false


func _has_held_aftertone(result: Dictionary) -> bool:
	for write: Dictionary in result.get("writes", []):
		if write.get("kind", "") == "aftertones":
			for aftertone: Dictionary in write.get("after", []):
				if bool(aftertone.get("held", false)):
					return true
	return false
