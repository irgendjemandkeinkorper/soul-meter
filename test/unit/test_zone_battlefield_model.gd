extends GdUnitTestSuite

func _actor(id: String, hp: int = 10) -> BattleActor:
	var actor := BattleActor.new()
	actor.combat_id = StringName(id)
	actor.display_name = id
	actor.hp = hp
	actor.max_hp = 10
	return actor

func test_setup_assigns_sides_and_front_positions() -> void:
	var model: BattlefieldModel = preload("res://globals/combat/zone_battlefield_model.gd").new()
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	model.setup([ally], [enemy])
	assert_bool(model.has_combatant(ally)).is_true()
	assert_str(String(model.side_of(ally))).is_equal("ally")
	assert_str(String(model.position_of(enemy))).is_equal("front")
	assert_int(model.combatants_on_side(&"ally").size()).is_equal(1)

func test_move_transfer_and_unknown_requests_return_refusal_shapes() -> void:
	var model: BattlefieldModel = preload("res://globals/combat/zone_battlefield_model.gd").new()
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	model.setup([ally], [enemy])
	assert_bool(model.move_query(ally, &"sideways")["allowed"]).is_false()
	assert_bool(model.move(ally, &"back")["allowed"]).is_true()
	assert_str(String(model.position_of(ally))).is_equal("back")
	assert_bool(model.transfer_combatant(ally, &"unknown")["allowed"]).is_false()
	assert_bool(model.transfer_combatant(ally, &"enemy")["allowed"]).is_true()
	assert_str(String(model.side_of(ally))).is_equal("enemy")

func test_target_rules_cover_melee_backline_and_dead_targets() -> void:
	var model: BattlefieldModel = preload("res://globals/combat/zone_battlefield_model.gd").new()
	var ally := _actor("ally")
	var front := _actor("front")
	var back := _actor("back")
	model.setup([ally], [front, back])
	model.move(ally, &"back")
	assert_str(String(model.target_query(ally, front, &"melee")["blocked_by"])).is_equal("position")
	model.move(ally, &"front")
	model.move(back, &"back")
	assert_str(String(model.target_query(ally, back, &"melee")["blocked_by"])).is_equal("cover")
	front.hp = 0
	assert_bool(model.target_query(ally, back, &"melee")["allowed"]).is_true()

func test_bonuses_targets_and_removal_follow_current_composition() -> void:
	var model: BattlefieldModel = preload("res://globals/combat/zone_battlefield_model.gd").new()
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	model.setup([ally], [enemy])
	model.move(ally, &"flank")
	model.move(enemy, &"back")
	assert_int(model.flank_bonus(ally, enemy)).is_equal(2)
	assert_int(model.cover_bonus(ally, enemy)).is_equal(0)
	assert_int(model.targets_for(ally, enemy, &"single").size()).is_equal(1)
	assert_bool(model.remove_combatant(enemy)["allowed"]).is_true()
	assert_bool(model.has_combatant(enemy)).is_false()
