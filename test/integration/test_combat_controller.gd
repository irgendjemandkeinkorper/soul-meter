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


func test_third_charge_time_wait_is_refused_before_turn_ends_or_scheduler_advances() -> void:
	var scheduler_script := load("res://globals/combat/charge_time_scheduler.gd") as GDScript
	controller.scheduler = scheduler_script.new() as TurnScheduler
	controller.start([ally], [enemy])
	var scheduler_state := controller.scheduler.to_dict()
	scheduler_state["consecutive_waits"][ally.combat_id] = 2
	controller.scheduler.from_dict(scheduler_state)
	var event_count_before_refusal := events.size()
	var active_before_refusal := controller.active_actor()

	assert_bool(controller.end_turn()).is_false()

	assert_object(controller.active_actor()).is_same(active_before_refusal)
	assert_str(String(controller.last_refusal.get("blocked_by", &""))).is_equal(
		"consecutive_wait_cap"
	)
	assert_int(events.size()).is_equal(event_count_before_refusal + 1)
	assert_str(String(events[-1].type)).is_equal("action_refused")
	var emitted_reason: Dictionary = events[-1].data.get("reason", {})
	assert_str(String(emitted_reason.get("blocked_by", &""))).is_equal("consecutive_wait_cap")


func test_data_only_focus_action_uses_existing_pipeline() -> void:
	controller.start([ally], [enemy])
	controller.shift_balance(10)

	var result := controller.submit_action(&"focus")
	assert_bool(result["allowed"]).is_true()
	assert_int(controller.balance).is_equal(5)
	assert_int(ally.action_points).is_equal(3)


func test_extreme_band_flips_runtime_state_for_both_sides() -> void:
	controller.start([ally], [enemy])
	var extreme := _extreme_band()
	controller.shift_balance(int(extreme["minimum"]))

	assert_str(ally.balance_band_id).is_equal(str(extreme["id"]))
	assert_str(enemy.balance_band_id).is_equal(str(extreme["id"]))
	assert_int(int(ally.balance_effects["damage_bonus"])).is_equal(
		int(extreme["effects"]["damage_bonus"])
	)
	assert_int(int(enemy.balance_effects["damage_bonus"])).is_equal(
		int(extreme["effects"]["damage_bonus"])
	)
	var snapshot := controller.snapshot()
	assert_bool(
		snapshot["allies"][0]["balance_effects"] == snapshot["enemies"][0]["balance_effects"]
	).is_true()


func test_stillpoint_center_lock_produces_better_outcome_than_ignoring_extreme() -> void:
	var ignored := _enemy_attack_outcome(false)
	var stabilized := _enemy_attack_outcome(true)

	assert_int(stabilized["damage_taken"]).is_less(ignored["damage_taken"])
	assert_int(stabilized["balance"]).is_equal(0)
	assert_bool(stabilized["locked"]).is_true()
	assert_bool(stabilized["suppressed"]).is_true()


func test_defining_strike_uses_skill_check_and_applies_authored_effect() -> void:
	var weakness_id := &"loam-maddened-boar/knee"
	ally.source_member = _skilled_member()
	enemy.archetype_id = &"loam-maddened-boar"
	enemy.discovered_weakness_ids = [weakness_id]
	controller.start([ally], [enemy])
	var definition := CombatActionCatalog.by_id(&"definition")
	var strike := CombatActionCatalog.by_id(&"strike")
	var ap_before := ally.action_points
	var hp_before := ally.hp

	var result := controller.submit_action(
		definition.id, enemy, {"weakness_id": weakness_id, "forced_rolls": [1]}
	)

	assert_bool(result["allowed"]).is_true()
	assert_bool(result["check"]["success"]).is_true()
	assert_int(result["check"]["roll"]).is_equal(1)
	assert_float(result["check"]["effective_percent"]).is_equal(
		SkillCheck.preview("lore", ally.source_member)
	)
	assert_bool(result["effect_applied"]).is_true()
	assert_bool(enemy.defining_effects["crippled"]).is_true()
	assert_int(ally.action_points).is_equal(ap_before - definition.ap_cost)
	assert_int(definition.ap_cost).is_greater(strike.ap_cost)
	assert_int(enemy.action_points).is_less(
		CombatActionCatalog.by_id(&"enemy-strike").ap_cost
	)
	controller.end_turn()
	assert_int(ally.hp).is_equal(hp_before)
	var controller_source := FileAccess.get_file_as_string(
		"res://globals/combat/combat_controller.gd"
	)
	assert_str(controller_source).contains("skill_check_service.resolve")
	assert_bool(controller_source.contains("randi_range(")).is_false()


func test_failed_defining_check_still_consumes_extra_ap() -> void:
	var weakness_id := &"loam-maddened-boar/knee"
	ally.source_member = _skilled_member()
	enemy.archetype_id = &"loam-maddened-boar"
	enemy.discovered_weakness_ids = [weakness_id]
	controller.start([ally], [enemy])
	var definition := CombatActionCatalog.by_id(&"definition")
	var hp_before := enemy.hp
	var ap_before := ally.action_points

	var result := controller.submit_action(
		definition.id, enemy, {"weakness_id": weakness_id, "forced_rolls": [100]}
	)

	assert_bool(result["allowed"]).is_true()
	assert_bool(result["check"]["success"]).is_false()
	assert_int(ally.action_points).is_equal(ap_before - definition.ap_cost)
	assert_int(enemy.hp).is_equal(hp_before)
	assert_bool(enemy.defining_effects.is_empty()).is_true()


func test_successful_defining_check_can_be_resisted_without_second_roll() -> void:
	var weakness_id := &"gnaal-rift-scavenger/disarm"
	var weakness := CombatIdentityCatalog.weakness(&"gnaal-rift-scavenger", weakness_id)
	ally.source_member = _skilled_member()
	enemy.archetype_id = &"gnaal-rift-scavenger"
	enemy.defense = int(weakness["resistance"]["threshold"])
	enemy.discovered_weakness_ids = [weakness_id]
	controller.start([ally], [enemy])

	var result := controller.submit_action(
		&"definition", enemy, {"weakness_id": weakness_id, "forced_rolls": [1]}
	)

	assert_bool(result["check"]["success"]).is_true()
	assert_bool(result["resisted"]).is_true()
	assert_bool(result["effect_applied"]).is_false()
	assert_bool(enemy.defining_effects.has("disarmed")).is_false()


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


func test_grid_attacks_route_ratified_height_and_facing_through_resolution() -> void:
	assert_int(_grid_attack_damage(0, &"w")).is_equal(100)  # FRONT x1.00
	assert_int(_grid_attack_damage(0, &"n")).is_equal(110)  # SIDE x1.10
	assert_int(_grid_attack_damage(0, &"e")).is_equal(125)  # BACK x1.25
	assert_int(_grid_attack_damage(2, &"w")).is_equal(120)  # +10% per favorable step


func _actor(name: String, hp: int, attack: int, defense: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	return actor


func _grid_attack_damage(attacker_height: int, target_facing: StringName) -> int:
	var local_rules := load("res://data/combat/combat_rules.tres") as CombatRules
	var grid := GridBattlefieldModel.new()
	grid.configure(local_rules)
	grid.build_grid(_grid_ground())
	grid.set_elevation(Vector2i(0, 0), attacker_height)
	var attacker := _actor("Grid Ally", 200, 100, 0)
	attacker.attributes[&"jump"] = attacker_height
	var target := _actor("Grid Enemy", 200, 1, 0)
	var local_controller := CombatController.new()
	local_controller.configure(CombatActionCatalog.all(), grid, local_rules)
	local_controller.start([attacker], [target])
	grid.set_facing(target, target_facing)

	var before := target.hp
	var outcome := local_controller.submit_action(&"strike", target)
	assert_bool(outcome.get("allowed", false)).is_true()
	return before - target.hp


func _grid_ground() -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	layer.set_cell(Vector2i(0, 0), 0, Vector2i.ZERO)
	layer.set_cell(Vector2i(1, 0), 0, Vector2i.ZERO)
	return layer


func _extreme_band() -> Dictionary:
	for band: Dictionary in CombatIdentityCatalog.balance_bands():
		var effects: Variant = band.get("effects", {})
		if (
			int(band.get("minimum", 0)) > 0
			and effects is Dictionary
			and int(effects.get("damage_bonus", 0)) > 0
		):
			return band
	return {}


func _enemy_attack_outcome(use_stillpoint: bool) -> Dictionary:
	var local_ally := _actor("Ally", 30, 7, 2)
	var local_enemy := _actor("Enemy", 30, 5, 1)
	var local_rules := load("res://data/combat/combat_rules.tres") as CombatRules
	var local_controller := CombatController.new()
	local_controller.configure(
		CombatActionCatalog.all(), BattlefieldModel.create_default(local_rules), local_rules
	)
	local_controller.start([local_ally], [local_enemy])
	var extreme := _extreme_band()
	local_controller.shift_balance(int(extreme["minimum"]))
	if use_stillpoint:
		var stillpoint := ElementsData.triad(&"stillpoint")
		local_controller.apply_balance_effect(stillpoint.unique_effect_parameters, local_ally)
		var before_shift := local_controller.balance
		local_controller.shift_balance(int(extreme["minimum"]))
		assert_int(local_controller.balance).is_equal(before_shift)
	local_controller.end_turn()
	return {
		"damage_taken": local_ally.max_hp - local_ally.hp,
		"balance": local_controller.balance,
		"locked": local_controller.balance_lock_until_round > 0,
		"suppressed": local_controller.threshold_effects_suppressed,
	}


func _skilled_member() -> PartyMember:
	var member := PartyMember.new()
	member.id = "test-definer"
	member.attributes = {"spark": 5, "pitch": 5}
	member.skill_tiers = {"lore": "untrained", "insight": "untrained"}
	return member
