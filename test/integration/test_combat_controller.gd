extends GdUnitTestSuite

var events: Array[CombatEvent] = []
var controller: CombatController
var rules: CombatRules
var battlefield: BattlefieldModel
var ally: BattleActor
var enemy: BattleActor


func before_test() -> void:
	events.clear()
	rules = load("res://data/combat/combat_rules.tres") as CombatRules
	battlefield = BattlefieldModel.create_default(rules)
	ally = _actor("Ally", 30, 7, 2)
	enemy = _actor("Enemy", 30, 5, 1)
	controller = CombatController.new()
	controller.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event))
	controller.configure(CombatActionCatalog.all(), battlefield, rules)


func test_full_round_emits_ordered_presentation_event_stream() -> void:
	controller.start([ally], [enemy])
	controller.submit_action(&"strike", enemy)
	controller.end_turn()

	var event_types: Array[StringName] = []
	for event in events:
		event_types.append(event.type)
	assert_array(event_types.slice(0, 10)).contains_exactly([
		&"battle_started",
		&"round_started",
		&"ap_refreshed",
		&"ap_refreshed",
		&"turn_started",
		&"action_resolved",
		&"turn_ended",
		&"enemy_turn_started",
		&"action_resolved",
		&"round_ended",
	])
	assert_bool(event_types.has(&"round_started")).is_true()
	assert_int(controller.round_number).is_equal(2)

	# A presentation projector can use only the latest event snapshot.
	var projected: Dictionary = events[-1].data["snapshot"]
	assert_int(projected["round"]).is_equal(2)
	assert_int(projected["allies"][0]["hp"]).is_less(30)
	assert_int(projected["enemies"][0]["hp"]).is_less(30)


func test_ap_refresh_derives_from_attributes_and_costs_are_deducted() -> void:
	ally.attributes = {"edge": 4}
	controller.start([ally], [enemy])

	assert_int(ally.max_action_points).is_equal(6)
	assert_int(ally.action_points).is_equal(6)
	controller.submit_action(&"strike", enemy)
	assert_int(ally.action_points).is_equal(4)


func test_insufficient_ap_refusal_matches_structured_gate_shape() -> void:
	controller.start([ally], [enemy])
	ally.action_points = 1

	var refusal := controller.submit_action(&"strike", enemy)
	assert_bool(refusal["allowed"]).is_false()
	assert_str(refusal["blocked_by"]).is_equal("action_points")
	assert_str(refusal["nearest_unblock"]["type"]).is_equal("action_points")
	assert_int(refusal["nearest_unblock"]["minimum"]).is_equal(2)
	assert_int(refusal["nearest_unblock"]["delta"]).is_equal(1)
	assert_int(ally.action_points).is_equal(1)
	assert_str(events[-1].type).is_equal("action_refused")


func test_data_only_focus_action_uses_existing_pipeline() -> void:
	controller.start([ally], [enemy])
	controller.shift_balance(10)

	var result := controller.submit_action(&"focus")
	assert_bool(result["allowed"]).is_true()
	assert_int(controller.balance).is_equal(5)
	assert_int(ally.action_points).is_equal(3)


func test_all_six_verbs_declare_positive_ap_costs_in_data() -> void:
	var verbs: Dictionary = {}
	for action in CombatActionCatalog.all():
		verbs[action.verb] = true
		assert_int(action.ap_cost).is_greater(0)
	for verb in CombatAction.Verb.values():
		assert_bool(verbs.has(verb)).is_true()


func test_zone_model_owns_legality_cover_flank_and_aoe_shapes() -> void:
	var rear_enemy := _actor("Rear", 20, 4, 1)
	battlefield.setup([ally], [enemy, rear_enemy])
	battlefield.move(rear_enemy, &"back")

	var blocked := battlefield.target_query(ally, rear_enemy, &"melee")
	assert_bool(blocked["allowed"]).is_false()
	assert_str(blocked["blocked_by"]).is_equal("cover")
	assert_bool(battlefield.target_query(ally, rear_enemy, &"ranged")["allowed"]).is_true()
	assert_int(battlefield.cover_bonus(ally, rear_enemy)).is_equal(2)

	battlefield.move(ally, &"flank")
	assert_int(battlefield.flank_bonus(ally, enemy)).is_equal(2)
	assert_int(battlefield.targets_for(ally, enemy, &"position").size()).is_equal(1)
	assert_int(battlefield.targets_for(ally, enemy, &"side").size()).is_equal(2)


func _actor(name: String, hp: int, attack: int, defense: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	return actor
