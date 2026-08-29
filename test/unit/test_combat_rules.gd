extends GdUnitTestSuite

func _actor(edge: int, maximum: int = 99) -> BattleActor:
	var actor := BattleActor.new()
	actor.attributes = {&"edge": edge}
	actor.max_action_points = maximum
	return actor

func test_action_points_are_derived_and_clamped() -> void:
	var rules := CombatRules.new()
	rules.base_action_points = 4
	rules.attribute_points_per_ap = 2
	assert_int(rules.action_points_for(_actor(4))).is_equal(6)
	rules.minimum_action_points = 3
	rules.maximum_action_points = 5
	assert_int(rules.action_points_for(_actor(-20))).is_equal(3)
	assert_int(rules.action_points_for(_actor(20))).is_equal(5)

func test_charge_speed_uses_floor_and_ceiling() -> void:
	var rules := CombatRules.new()
	rules.base_charge_speed = 6
	rules.attribute_points_per_speed = 2
	rules.minimum_charge_speed = 4
	rules.maximum_charge_speed = 8
	assert_int(rules.charge_speed_for(_actor(-20))).is_equal(4)
	assert_int(rules.charge_speed_for(_actor(4))).is_equal(8)

func test_charge_cost_handles_null_move_authored_and_ap_fallback() -> void:
	var rules := CombatRules.new()
	rules.minimum_action_ct_cost = 30
	rules.maximum_action_ct_cost = 60
	rules.move_ct_cost = 20
	rules.ct_per_ap = 15
	assert_int(rules.charge_cost_for(null)).is_equal(30)
	var move := CombatAction.new()
	move.verb = CombatAction.Verb.MOVE
	assert_int(rules.charge_cost_for(move)).is_equal(20)
	var authored := CombatAction.new()
	authored.ct_cost = 42
	assert_int(rules.charge_cost_for(authored)).is_equal(42)
	var fallback := CombatAction.new()
	fallback.ap_cost = 5
	assert_int(rules.charge_cost_for(fallback)).is_equal(60)


func test_wave1_enemy_and_unused_ap_defaults_are_conservative_and_capped() -> void:
	var rules := CombatRules.new()
	assert_bool(rules.enemy_full_ap_turns).is_false()
	assert_int(rules.unused_ap_defense_per_ap).is_greater_equal(0)
	assert_int(rules.unused_ap_defense_cap).is_greater_equal(0)
	assert_int(rules.unused_ap_defense_per_ap).is_less_equal(rules.unused_ap_defense_cap)
