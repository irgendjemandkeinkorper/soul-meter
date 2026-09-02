extends GdUnitTestSuite


class CelllessBattlefieldSpy:
	extends BattlefieldModel

	var describe_calls := 0
	var reachable_calls := 0

	func capabilities() -> Dictionary:
		return {"cells": false}

	func describe_position(_position: StringName) -> Dictionary:
		describe_calls += 1
		return {}

	func reachable_positions(_actor: BattleActor, _ct_budget: int) -> Array[StringName]:
		reachable_calls += 1
		return []

var events: Array[CombatEvent] = []
var controller: CombatController
var rules: CombatRules
var battlefield: BattlefieldModel
var ally: BattleActor
var enemy: BattleActor
var previous_soul_meter := 50.0


func before_test() -> void:
	events.clear()
	var authored_rules := load("res://data/combat/combat_rules.tres") as CombatRules
	rules = authored_rules.duplicate(true) as CombatRules
	battlefield = BattlefieldModel.create_default(rules)
	ally = _actor("Ally", 30, 7, 2)
	enemy = _actor("Enemy", 30, 5, 1)
	controller = CombatController.new()
	controller.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event))
	controller.configure(CombatActionCatalog.all(), battlefield, rules)
	previous_soul_meter = GameState.soul_meter


func after_test() -> void:
	GameState.set_soul_meter(previous_soul_meter)


func test_cast_forecast_is_committed_once_with_matching_damage_cost_and_residue() -> void:
	var cast := CombatActionCatalog.by_id(&"cast-seam")
	var ability := AbilityDefinition.new()
	ability.id = "test-strom-cast"
	ability.display_name = "Test Strom Cast"
	ability.element_id = &"strom"
	ability.elements = [&"strom"]
	ability.magnitude = &"note"
	ability.power = 12
	ability.breath_cost = 3
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_grid_ground())
	controller = CombatController.new()
	controller.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event))
	var tables := _cast_tables_for_actor(ally, [ability], "cast-integration-caster")
	controller.configure([cast], grid, rules, null, [ability], tables)
	ally.breath = 1
	GameState.set_soul_meter(10.0)
	controller.start([ally], [enemy], &"cast-integration")

	var forecast := controller.forecast_action(cast, enemy, {"ability_id": ability.id})
	var expected_resolution: Dictionary = forecast["resolution"]
	var expected_hp := int((expected_resolution["writes"] as Array)[0]["after"])
	var result := controller.submit_action(&"cast-seam", enemy, {"ability_id": ability.id})

	assert_bool(result["allowed"]).is_true()
	assert_int(enemy.hp).is_equal(expected_hp)
	assert_int(ally.breath).is_equal(0)
	assert_float(GameState.soul_meter).is_equal(8.0)
	var source_cell: Vector2i = grid.describe_position(grid.position_of(ally))["cell"]
	assert_int(controller.tile_state_at(source_cell).charge_level).is_equal(1)
	assert_bool(result["resolution"] == expected_resolution).is_true()


func test_aoe_cast_resolves_a_distinct_hp_write_for_each_target() -> void:
	var cast := CombatActionCatalog.by_id(&"cast-seam").duplicate(true) as CombatAction
	cast.aoe_shape = &"side"
	var ability := AbilityDefinition.new()
	ability.id = "test-side-cast"
	ability.element_id = &"strom"
	ability.elements = [&"strom"]
	ability.power = 12
	ability.breath_cost = 1
	var second_enemy := _actor("Second Enemy", 47, 5, 4)
	var tables := _cast_tables_for_actor(ally, [ability], "aoe-caster")
	controller.configure([cast], battlefield, rules, null, [ability], tables)
	ally.breath = 1
	controller.start([ally], [enemy, second_enemy], &"aoe-resolution")
	var primary_before := enemy.hp
	var secondary_before := second_enemy.hp

	var result := controller.submit_action(
		cast.id, enemy, {"ability_id": ability.id}
	)

	assert_bool(bool(result.get("allowed", false))).is_true()
	assert_int(ally.breath).is_equal(0)
	assert_int(enemy.hp).is_less(primary_before)
	assert_int(second_enemy.hp).is_less(secondary_before)
	var final_writes: Array = result["resolution"]["writes"]
	var hp_write: Dictionary = final_writes.filter(
		func(write: Dictionary) -> bool: return write.get("kind", "") == "hp"
	)[0]
	assert_str(String(hp_write["target_id"])).is_equal(String(second_enemy.combat_id))
	assert_int(int(hp_write["before"])).is_equal(secondary_before)
	assert_int(int(hp_write["after"])).is_equal(second_enemy.hp)


func test_refused_cast_changes_no_combat_or_resource_state() -> void:
	var cast := CombatActionCatalog.by_id(&"cast-seam")
	var ability := AbilityDefinition.new()
	ability.id = "too-costly"
	ability.element_id = &"strom"
	ability.elements = [&"strom"]
	ability.power = 12
	ability.breath_cost = 4
	var tables := _cast_tables_for_actor(ally, [ability], "refusal-caster")
	controller.configure([cast], battlefield, rules, null, [ability], tables)
	ally.breath = 1
	GameState.set_soul_meter(2.0)
	controller.start([ally], [enemy], &"cast-refusal")
	var before_ap := ally.action_points
	var before_hp := enemy.hp

	var result := controller.submit_action(&"cast-seam", enemy, {"ability_id": ability.id})

	assert_bool(result["allowed"]).is_false()
	assert_str(result["blocked_by"]).is_equal("soul")
	assert_int(ally.action_points).is_equal(before_ap)
	assert_int(ally.breath).is_equal(1)
	assert_float(GameState.soul_meter).is_equal(2.0)
	assert_int(enemy.hp).is_equal(before_hp)


func test_cast_abilities_are_filtered_by_actor_loadout_and_require_selection() -> void:
	var cast := CombatActionCatalog.by_id(&"cast-seam")
	var owned := AbilityDefinition.from_dict({
		"id": "owned-note", "element_id": "strom", "power": 8, "slot": "action"
	})
	var other := AbilityDefinition.from_dict({
		"id": "other-note", "element_id": "aqua", "power": 8, "slot": "action"
	})
	var tables := TacticalTables.new()
	tables.abilities = {owned.id: owned, other.id: other}
	var loadout := UnitLoadout.create("loadout-caster")
	loadout.action_ability_ids = PackedStringArray([owned.id])
	tables.loadouts = {loadout.unit_id: loadout}
	ally.source_member = PartyMember.new()
	ally.source_member.id = loadout.unit_id
	controller.configure([cast], battlefield, rules, null, [owned, other], tables)
	controller.start([ally], [enemy], &"actor-ability-filter")

	var unselected := controller.query_action(cast, enemy)
	var unowned := controller.query_action(cast, enemy, {"ability_id": other.id})
	var selected := controller.query_action(cast, enemy, {"ability_id": owned.id})

	assert_bool(bool(unselected.get("allowed", true))).is_false()
	assert_str(String(unselected.get("blocked_by", &""))).is_equal("ability")
	assert_str(String(unselected.get("message", ""))).contains("Select")
	assert_str(String(unselected.get("message", ""))).contains("loadout")
	assert_bool(bool(unowned.get("allowed", true))).is_false()
	assert_str(String(unowned.get("blocked_by", &""))).is_equal("ability")
	assert_bool(bool(selected.get("allowed", false))).is_true()


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


func test_ending_ap_turn_grants_data_driven_hard_capped_defense_until_refresh() -> void:
	rules.unused_ap_defense_per_ap = 2
	rules.unused_ap_defense_cap = 3
	controller.start([ally], [enemy])
	var forfeited := ally.action_points

	assert_bool(controller.end_turn()).is_true()

	var ended_event: CombatEvent = null
	for event: CombatEvent in events:
		if event.type == &"turn_ended" and event.actor_id == ally.combat_id:
			ended_event = event
			break
	assert_object(ended_event).is_not_null()
	assert_int(ended_event.data["forfeited_ap"]).is_equal(forfeited)
	assert_int(ended_event.data["unused_ap_defense_bonus"]).is_equal(3)
	assert_int(ended_event.data["snapshot"]["allies"][0]["unused_ap_defense_bonus"]).is_equal(3)
	assert_int(ally.unused_ap_defense_bonus).is_equal(0)


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


func test_defining_strike_requires_selection_and_forecast_matches_resolution_context() -> void:
	var weakness_id := &"loam-maddened-boar/knee"
	ally.source_member = _skilled_member()
	enemy.archetype_id = &"loam-maddened-boar"
	enemy.discovered_weakness_ids = [weakness_id]
	controller.start([ally], [enemy])
	var definition := CombatActionCatalog.by_id(&"definition")

	var refused: Dictionary = controller.submit_action(definition.id, enemy)
	assert_bool(refused["allowed"]).is_false()
	assert_str(String(refused["blocked_by"])).is_equal("weakness")

	var forecast: Dictionary = controller.forecast_defining_strike(enemy, weakness_id)
	var resolved: Dictionary = controller.submit_action(
		definition.id, enemy, {"weakness_id": weakness_id, "forced_rolls": [1]}
	)
	assert_bool(forecast["allowed"]).is_true()
	var pure_forecast: Dictionary = forecast["resolution"]
	assert_int(forecast["ap_cost"]).is_equal(definition.ap_cost)
	assert_float(forecast["chance"]).is_equal(SkillCheck.preview("lore", ally.source_member))
	assert_str(String(pure_forecast["weakness_id"])).is_equal(String(weakness_id))
	# The landed number is the TOP-LEVEL forecast damage (post-mitigation, computed
	# through the same calculate_damage pipeline resolution uses). The nested
	# `resolution` dict stays the pure pre-mitigation Resolution contract.
	assert_int(forecast["damage"]).is_equal(resolved["damage"])
	assert_int(int(pure_forecast["damage"])).is_greater_equal(int(forecast["damage"]))


func test_defining_strike_resolution_forecast_matches_forced_roll_commit() -> void:
	var weakness_id := &"loam-maddened-boar/knee"
	ally.source_member = _skilled_member()
	enemy.archetype_id = &"loam-maddened-boar"
	enemy.discovered_weakness_ids = [weakness_id]
	controller.start([ally], [enemy], &"defining-forecast-parity")
	var definition := CombatActionCatalog.by_id(&"definition")
	var hp_before := enemy.hp

	var forecast := controller.forecast_defining_strike(enemy, weakness_id)
	var committed := controller.submit_action(
		definition.id, enemy, {"weakness_id": weakness_id, "forced_rolls": [1]}
	)

	assert_bool(bool(forecast.get("allowed", false))).is_true()
	assert_bool(bool(committed.get("allowed", false))).is_true()
	assert_int(int(committed["check"]["roll"])).is_equal(1)
	assert_str(String(forecast["resolution"]["ability_id"])).is_equal(String(definition.id))
	assert_int(int(forecast["damage"])).is_equal(int(committed["damage"]))
	assert_int(int(forecast["damage"])).is_equal(hp_before - enemy.hp)


func test_snapshot_turn_order_keeps_spent_actors_visible() -> void:
	# Region E contract (spec Wave 0 item 6): the round order shows EVERY living
	# participant, acted included. peek_order() filters to who can still act, so the
	# snapshot must come from round_overview() — a spent ally may not vanish.
	ally.attributes = {"edge": 0}
	var second := _actor("Second", 30, 6, 1)
	controller.start([ally, second], [enemy])
	controller.submit_action(&"strike", enemy)
	controller.submit_action(&"strike", enemy)
	assert_int(ally.action_points).is_equal(0)

	var order: Array = controller.snapshot()["turn_order"]
	var rows_by_id: Dictionary = {}
	for row: Variant in order:
		rows_by_id[String((row as Dictionary)["actor_id"])] = row
	for expected: BattleActor in [ally, second, enemy]:
		assert_bool(rows_by_id.has(String(expected.combat_id)))\
			.override_failure_message("%s missing from turn_order" % expected.display_name).is_true()
	var spent: Dictionary = rows_by_id[String(ally.combat_id)]
	assert_bool(spent["acted"]).is_true()
	assert_bool(spent["pending"]).is_false()


func test_ct_scheduler_end_turn_never_grants_unused_ap_defense() -> void:
	var ct_rules: CombatRules = rules.duplicate(true)
	ct_rules.use_charge_time = true
	var ct_controller := CombatController.new()
	ct_controller.configure(
		CombatActionCatalog.all(), BattlefieldModel.create_default(ct_rules), ct_rules
	)
	ct_controller.start([ally], [enemy])
	var guard := 0
	while ct_controller.state != CombatController.State.ALLY_TURN and guard < 200:
		guard += 1
		ct_controller.advance()
	assert_int(ct_controller.state).is_equal(CombatController.State.ALLY_TURN)

	ct_controller.end_turn()

	assert_int(ally.unused_ap_defense_bonus).is_equal(0)


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


func test_weather_shares_the_scheduler_clock_and_feeds_matching_tiles() -> void:
	var local_controller := _grid_controller(true)
	assert_bool(bool(local_controller.configure_weather(&"strom").get("allowed", false))).is_true()
	# Weather ticks ride the scheduler's advance() results — the two clocks agree
	# after start() has driven the scheduler to the first ready ally.
	assert_int(local_controller.weather.total_ticks())\
		.is_equal(local_controller.scheduler.tick_count())

	# Measure application (issue #140 rules): a tile already charged in the weather's
	# element gains charge; a clash-charged tile drains. Pre-charge both shapes.
	var fed: TileState = local_controller.tile_state_at(Vector2i(0, 0))
	fed.apply_residue(&"strom")
	var starved: TileState = local_controller.tile_state_at(Vector2i(1, 0))
	starved.apply_residue(CombatController._clash_of(&"strom"))
	var events: Array[CombatEvent] = []
	local_controller.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event))
	local_controller._advance_weather(TurnScheduler.TICKS_PER_MEASURE)
	assert_int(fed.charge_level).is_greater(1)
	assert_int(starved.charge_level).is_equal(0)
	var applied := events.filter(func(e: CombatEvent) -> bool: return e.type == &"weather_applied")
	assert_int(applied.size()).is_equal(1)


func test_snapshot_reports_live_weather_and_charged_tiles() -> void:
	var local_controller := _grid_controller(true)
	local_controller.configure_weather(&"strom")
	(local_controller.tile_state_at(Vector2i(0, 0)) as TileState).apply_residue(&"strom")
	var snapshot := local_controller.snapshot()
	var weather: Dictionary = snapshot["weather"]
	assert_str(str(weather["element_id"])).is_equal("strom")
	assert_str(str(weather["gains"])).is_equal("strom")
	assert_str(str(weather["drains"])).is_equal(String(CombatController._clash_of(&"strom")))
	var charged: Array = (snapshot["tiles"] as Array).filter(
		func(t: Variant) -> bool: return int((t as Dictionary).get("charge_level", 0)) > 0
	)
	assert_int(charged.size()).is_equal(1)
	assert_str(str((charged[0] as Dictionary)["charge_element_id"])).is_equal("strom")


func test_snapshot_preserves_encounter_identity_for_environment_presentation() -> void:
	controller.start([ally], [enemy], &"dorthkor-vanguard")

	assert_str(str(controller.snapshot().get("encounter_id", ""))).is_equal(
		"dorthkor-vanguard"
	)


func test_charged_source_tile_raises_the_forecast_and_matches_resolution_terms() -> void:
	var local_controller := _grid_controller(true)
	var actor := local_controller.allies[0]
	var target := local_controller.enemies[0]
	var strike := local_controller.action_by_id(&"strike")
	var baseline := Resolution.resolve(local_controller.forecast_context(actor, target, strike))
	assert_bool(bool(baseline.get("allowed", false))).is_true()

	# Charge the attacker's own tile with the strike's (fallback) element: the
	# forecast must rise by the tile-charge multiplier, through the same context
	# terms live resolution uses (source_tile from the actor's cell).
	var actor_cell: Vector2i = (
		local_controller.battlefield.describe_position(
			local_controller.battlefield.position_of(actor)
		)["cell"]
	)
	var source_tile: TileState = local_controller.tile_state_at(actor_cell)
	source_tile.apply_residue(&"suul")
	source_tile.apply_residue(&"suul")
	var context := local_controller.forecast_context(actor, target, strike)
	assert_dict(context["source_tile"] as Dictionary).is_equal(source_tile.to_dict())
	assert_dict(context["weather"] as Dictionary).is_equal(local_controller.weather.to_dict())
	var charged := Resolution.resolve(context)
	assert_int(int(charged["damage"])).is_greater(int(baseline["damage"]))


func _grid_controller(use_charge_time: bool) -> CombatController:
	var local_rules := (
		load("res://data/combat/combat_rules.tres") as CombatRules
	).duplicate(true) as CombatRules
	local_rules.use_charge_time = use_charge_time
	var grid := GridBattlefieldModel.new()
	grid.configure(local_rules)
	grid.build_grid(_grid_ground())
	var local_controller := CombatController.new()
	local_controller.configure(CombatActionCatalog.all(), grid, local_rules)
	local_controller.start(
		[_actor("Grid Ally", 200, 20, 0)], [_actor("Grid Enemy", 200, 1, 0)], &"weather-test"
	)
	return local_controller


func test_snapshot_carries_terrain_tiles_and_weather_cadence() -> void:
	var local_rules := load("res://data/combat/combat_rules.tres") as CombatRules
	var grid := GridBattlefieldModel.new()
	grid.configure(local_rules)
	grid.build_grid(_grid_ground())
	grid.set_elevation(Vector2i(0, 0), 2)
	var local_controller := CombatController.new()
	local_controller.configure(CombatActionCatalog.all(), grid, local_rules)
	local_controller.start([_actor("Grid Ally", 20, 5, 0)], [_actor("Grid Enemy", 20, 5, 0)])

	var snapshot := local_controller.snapshot()
	var tiles: Array = snapshot.get("tiles", [])
	assert_int(tiles.size()).is_equal(2)  # _grid_ground() authors two cells
	assert_int(int((tiles[0] as Dictionary).get("height_delta", -1))).is_equal(2)
	assert_int(int((tiles[1] as Dictionary).get("height_delta", -1))).is_equal(0)
	var weather: Dictionary = snapshot.get("weather", {})
	assert_str(str(weather.get("element_id", "missing"))).is_equal("")
	assert_int(int(weather.get("tick", -1))).is_equal(local_controller.scheduler.tick_count())


func test_grid_cover_changes_forecast_and_resolution_by_the_same_amount() -> void:
	var uncovered := _positional_controller(5, 2)
	var uncovered_actor := uncovered.allies[0]
	var uncovered_target := uncovered.enemies[0]
	var shot := uncovered.action_by_id(&"test-shot")
	var uncovered_forecast := uncovered.forecast_action(shot, uncovered_target)

	var covered := _positional_controller(5, 2)
	var covered_actor := covered.allies[0]
	var covered_target := covered.enemies[0]
	# Defender-anchored directional rule: the cover cell hugs the target on the
	# shooter's side (enemy deploys at (4,0); attacker at (0,0)).
	(covered.battlefield as GridBattlefieldModel).set_cover(Vector2i(3, 0), true)
	var covered_forecast := covered.forecast_action(covered.action_by_id(&"test-shot"), covered_target)
	var hp_before := covered_target.hp
	var resolved := covered.submit_action(&"test-shot", covered_target)

	assert_bool(bool(uncovered_forecast.get("allowed", false))).is_true()
	assert_bool(bool(covered_forecast.get("allowed", false))).is_true()
	assert_int(int(covered_forecast["damage"])).is_less(int(uncovered_forecast["damage"]))
	assert_int(int(covered_forecast["damage"])).is_equal(hp_before - covered_target.hp)
	assert_int(int(resolved["damage"])).is_equal(int(covered_forecast["damage"]))
	assert_int(int((covered_forecast["positioning"] as Dictionary)["cover_bonus"])).is_equal(
		covered.rules.cover_defense_bonus
	)
	assert_object(uncovered_actor).is_not_null()
	assert_object(covered_actor).is_not_null()


## Gate Wave P finding 1: forecast_action once fetched its own flat flank_bonus
## without the positional-context guard, so a side/back forecast exceeded the
## committed damage. Forecast, commit, and the flat-term zeroing must agree.
func test_grid_flank_forecast_matches_commit_for_side_and_back_facings() -> void:
	for facing: StringName in [&"e", &"n"]:
		var flanked := _positional_controller(5, 2)
		var flanked_target := flanked.enemies[0]
		var grid := flanked.battlefield as GridBattlefieldModel
		assert_bool(grid.set_facing(flanked_target, facing).get("allowed", false)).is_true()
		var shot := flanked.action_by_id(&"test-shot")

		var forecast := flanked.forecast_action(shot, flanked_target)
		var hp_before := flanked_target.hp
		var resolved := flanked.submit_action(&"test-shot", flanked_target)

		assert_bool(bool(forecast.get("allowed", false))).is_true()
		assert_int(int(forecast["damage"])) \
			.override_failure_message("facing %s: forecast != commit" % facing) \
			.is_equal(int(resolved["damage"]))
		assert_int(int(forecast["damage"])).is_equal(hp_before - flanked_target.hp)
		# The flat flank term stays zero on grid battles — the ratified facing
		# multipliers inside the positional context are the only flank payment.
		assert_int(int((forecast["positioning"] as Dictionary).get("flank_bonus", -1))) \
			.is_equal(0)

	var front := _positional_controller(5, 2)
	var front_forecast := front.forecast_action(front.action_by_id(&"test-shot"), front.enemies[0])
	var back := _positional_controller(5, 2)
	(back.battlefield as GridBattlefieldModel).set_facing(back.enemies[0], &"e")
	var back_forecast := back.forecast_action(back.action_by_id(&"test-shot"), back.enemies[0])
	assert_int(int(back_forecast["damage"])).is_greater(int(front_forecast["damage"]))


func test_ranged_los_refusal_matches_at_forecast_and_commit() -> void:
	var local_controller := _positional_controller(5, 1)
	var actor := local_controller.allies[0]
	var target := local_controller.enemies[0]
	var shot := local_controller.action_by_id(&"test-shot")
	(local_controller.battlefield as GridBattlefieldModel).set_elevation(Vector2i(2, 0), 10)
	var ap_before := actor.action_points

	var forecast := local_controller.forecast_action(shot, target)
	var committed := local_controller.submit_action(shot.id, target)

	assert_bool(bool(forecast.get("allowed", true))).is_false()
	assert_bool(bool(committed.get("allowed", true))).is_false()
	assert_str(String(forecast.get("blocked_by", &""))).is_equal("blocked_by_elevation")
	assert_str(String(committed.get("blocked_by", &""))).is_equal("blocked_by_elevation")
	assert_dict(forecast).is_equal(committed)
	assert_int(actor.action_points).is_equal(ap_before)


func test_player_move_spends_path_ap_and_updates_snapshot_position() -> void:
	var local_controller := _positional_controller(5, 1)
	var actor := local_controller.allies[0]
	var ap_before := actor.action_points
	var destination := &"c:2,0,0"
	var query := local_controller.move_query(destination)

	var result := local_controller.submit_action(&"move", null, {"destination": destination})

	assert_bool(bool(query.get("allowed", false))).is_true()
	assert_int(int(query.get("ap_cost", 0))).is_equal(2)
	assert_bool(bool(result.get("allowed", false))).is_true()
	assert_int(int(result.get("ap_cost", 0))).is_equal(2)
	assert_int(actor.action_points).is_equal(ap_before - 2)
	var ally_snapshot: Dictionary = (local_controller.snapshot()["allies"] as Array)[0]
	# snapshot position is the opaque battlefield handle, not a raw cell
	assert_str(String(ally_snapshot.get("position", &""))).is_equal("c:2,0,0")


func test_player_move_refuses_occupied_destination_without_spending_ap() -> void:
	var local_controller := _positional_controller(5, 1)
	var actor := local_controller.allies[0]
	var target := local_controller.enemies[0]
	var destination := local_controller.battlefield.position_of(target)
	var ap_before := actor.action_points

	var result := local_controller.submit_action(&"move", null, {"destination": destination})

	assert_bool(bool(result.get("allowed", true))).is_false()
	assert_str(String(result.get("blocked_by", &""))).is_equal("position")
	assert_str(String((result.get("nearest_unblock", {}) as Dictionary).get("type", &""))).is_equal(
		"cell_free"
	)
	assert_int(actor.action_points).is_equal(ap_before)


func test_snapshot_exposes_move_range_and_path_costs_additively() -> void:
	var local_controller := _positional_controller(5, 1)
	var movement: Dictionary = local_controller.snapshot().get("movement", {})

	assert_str(String(movement.get("action_id", &""))).is_equal("move")
	assert_int(int(movement.get("per_cell_ap_cost", 0))).is_equal(1)
	assert_bool((movement.get("reachable", []) as Array).is_empty()).is_false()
	var first: Dictionary = (movement.get("reachable", []) as Array)[0]
	assert_bool(first.has("destination")).is_true()
	assert_bool(first.has("ap_cost")).is_true()
	assert_bool(first.has("path")).is_true()


func test_enemy_prefers_cover_over_an_equal_distance_open_cell() -> void:
	var local_controller := _enemy_position_controller(&"e")
	var grid := local_controller.battlefield as GridBattlefieldModel
	grid.set_cover(Vector2i(3, 2), true)

	var destination := local_controller._best_enemy_position(
		local_controller.enemies[0], local_controller.allies[0]
	)

	# c:2,4,0 is an equally distant open cell and wins the lexical tie without cover.
	assert_str(String(destination)).is_equal("c:4,2,0")


func test_enemy_prefers_rear_flank_over_cover_when_both_are_reachable() -> void:
	var local_controller := _enemy_position_controller(&"n")
	var grid := local_controller.battlefield as GridBattlefieldModel
	grid.set_cover(Vector2i(3, 2), true)

	var destination := local_controller._best_enemy_position(
		local_controller.enemies[0], local_controller.allies[0]
	)

	assert_str(String(destination)).is_equal("c:2,3,0")


func test_enemy_position_scoring_bypasses_cellless_zone_battlefields() -> void:
	var spy := CelllessBattlefieldSpy.new()
	var local_controller := CombatController.new()
	local_controller.battlefield = spy
	local_controller.rules = rules

	assert_str(String(local_controller._best_enemy_position(enemy, ally))).is_empty()
	assert_int(spy.describe_calls).is_equal(0)
	assert_int(spy.reachable_calls).is_equal(0)


func test_enemy_position_choice_is_deterministic_across_identical_runs() -> void:
	var first := _enemy_position_controller(&"e")
	var second := _enemy_position_controller(&"e")
	(first.battlefield as GridBattlefieldModel).set_cover(Vector2i(3, 2), true)
	(second.battlefield as GridBattlefieldModel).set_cover(Vector2i(3, 2), true)

	var first_choice := first._best_enemy_position(first.enemies[0], first.allies[0])
	var second_choice := second._best_enemy_position(second.enemies[0], second.allies[0])

	assert_str(String(first_choice)).is_equal(String(second_choice))
	assert_str(String(first_choice)).is_equal("c:4,2,0")


func test_melee_enemy_routes_around_an_occupied_elevated_line() -> void:
	var local_rules := _positional_rules()
	var grid := GridBattlefieldModel.new()
	grid.configure(local_rules)
	grid.build_grid(_sized_grid_ground(5, 2))
	grid.set_elevation(Vector2i(3, 1), 1)
	var target := _actor("Route Target", 200, 1, 0)
	var blocker := _actor("Route Blocker", 200, 1, 0)
	var foe := _actor("Routing Enemy", 200, 1, 0)
	var local_events: Array[CombatEvent] = []
	var local_controller := CombatController.new()
	local_controller.event_emitted.connect(
		func(event: CombatEvent) -> void: local_events.append(event)
	)
	local_controller.configure(CombatActionCatalog.all(), grid, local_rules)
	local_controller.start([target, blocker], [foe], &"enemy-route-test")
	assert_bool(grid.move(blocker, &"c:2,0,0").get("allowed", false)).is_true()

	assert_bool(local_controller.end_turn()).is_true()
	assert_bool(local_controller.end_turn()).is_true()

	assert_str(String(grid.position_of(foe))).is_equal("c:3,1,1")
	var moves := local_events.filter(
		func(event: CombatEvent) -> bool:
			return event.actor_id == foe.combat_id \
				and StringName(event.data.get("action_id", &"")) == &"__enemy_grid_move__"
	)
	assert_int(moves.size()).is_equal(1)
	assert_array(moves[0].data.get("path_cells", [])).contains(Vector2i(3, 1))


func test_unreachable_enemy_emits_the_model_los_refusal_taxonomy() -> void:
	var local_rules := _positional_rules()
	var grid := GridBattlefieldModel.new()
	grid.configure(local_rules)
	grid.build_grid(_sized_grid_ground(5, 1))
	grid.set_cliff(Vector2i(3, 0), true)
	grid.set_elevation(Vector2i(2, 0), 10)
	var target := _actor("LOS Target", 200, 1, 0)
	var foe := _actor("Blocked Enemy", 200, 1, 0)
	var ranged_enemy := CombatAction.make(
		&"enemy-strike", "Enemy Shot", CombatAction.Kind.ATTACK, 0, 0, 0.0, 4
	)
	ranged_enemy.target_profile = &"ranged"
	ranged_enemy.player_available = false
	var actions: Array[CombatAction] = []
	for action: CombatAction in CombatActionCatalog.all():
		if action.id != &"enemy-strike":
			actions.append(action)
	actions.append(ranged_enemy)
	var local_events: Array[CombatEvent] = []
	var local_controller := CombatController.new()
	local_controller.event_emitted.connect(
		func(event: CombatEvent) -> void: local_events.append(event)
	)
	local_controller.configure(actions, grid, local_rules)
	local_controller.start([target], [foe], &"enemy-los-refusal-test")

	assert_bool(local_controller.end_turn()).is_true()

	var refusals := local_events.filter(
		func(event: CombatEvent) -> bool:
			return event.type == &"action_refused" and event.actor_id == foe.combat_id
	)
	assert_int(refusals.size()).is_equal(1)
	var reason: Dictionary = refusals[0].data.get("reason", {})
	assert_str(String(reason.get("blocked_by", &""))).is_equal("blocked_by_elevation")


func _actor(name: String, hp: int, attack: int, defense: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	return actor


func _positional_rules() -> CombatRules:
	var local_rules := (
		load("res://data/combat/combat_rules.tres") as CombatRules
	).duplicate(true) as CombatRules
	local_rules.use_charge_time = false
	return local_rules


func _enemy_position_controller(target_facing: StringName) -> CombatController:
	var local_rules := _positional_rules()
	local_rules.maximum_action_ct_cost = 40
	var grid := GridBattlefieldModel.new()
	grid.configure(local_rules)
	grid.build_grid(_sized_grid_ground(5, 5))
	var target := _actor("Position Target", 200, 1, 0)
	var foe := _actor("Position Enemy", 200, 1, 0)
	var local_controller := CombatController.new()
	local_controller.configure(CombatActionCatalog.all(), grid, local_rules)
	local_controller.start([target], [foe], &"enemy-position-test")
	assert_bool(grid.move(target, &"c:2,2,0").get("allowed", false)).is_true()
	assert_bool(grid.move(foe, &"c:4,4,0").get("allowed", false)).is_true()
	assert_bool(grid.set_facing(target, target_facing).get("allowed", false)).is_true()
	return local_controller


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


func _positional_controller(width: int, height: int) -> CombatController:
	var local_rules := (
		load("res://data/combat/combat_rules.tres") as CombatRules
	).duplicate(true) as CombatRules
	local_rules.use_charge_time = false
	var grid := GridBattlefieldModel.new()
	grid.configure(local_rules)
	grid.build_grid(_sized_grid_ground(width, height))
	var shot := CombatAction.make(&"test-shot", "Test Shot", CombatAction.Kind.ATTACK, 0, 0, 0.0, 2)
	shot.target_profile = &"ranged"
	var actions := CombatActionCatalog.all()
	actions.append(shot)
	var local_controller := CombatController.new()
	local_controller.configure(actions, grid, local_rules)
	local_controller.start(
		[_actor("Grid Ally", 200, 20, 0)], [_actor("Grid Enemy", 200, 1, 0)], &"position-test"
	)
	return local_controller


func _sized_grid_ground(width: int, height: int) -> TileMapLayer:
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
	for y in height:
		for x in width:
			layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
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


func _cast_tables_for_actor(
	actor: BattleActor, abilities: Array[AbilityDefinition], unit_id: String
) -> TacticalTables:
	actor.source_member = PartyMember.new()
	actor.source_member.id = unit_id
	var tables := TacticalTables.new()
	var loadout := UnitLoadout.create(unit_id)
	for ability: AbilityDefinition in abilities:
		tables.abilities[ability.id] = ability
		loadout.action_ability_ids.append(ability.id)
	tables.loadouts[unit_id] = loadout
	return tables
