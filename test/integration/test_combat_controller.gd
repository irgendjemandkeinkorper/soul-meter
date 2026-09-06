extends GdUnitTestSuite

class CommandSpy:
	extends ClassResource
	var commands: Array[String] = []

	func on_command(action_id: StringName, target_id: StringName) -> void:
		commands.append("%s:%s" % [String(action_id), String(target_id)])

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

class CoverBattlefieldSpy:
	extends BattlefieldModel

	var cover_value := 0

	func configure(configured_rules: CombatRules) -> void:
		cover_value = configured_rules.cover_defense_bonus

	func setup(_allies: Array[BattleActor], _enemies: Array[BattleActor]) -> void:
		pass

	func target_query(
		_actor: BattleActor, _target: BattleActor, _profile: StringName
	) -> Dictionary:
		return {"allowed": true}

	func cover_bonus(_actor: BattleActor, _target: BattleActor) -> int:
		return cover_value

	func targets_for(
		_actor: BattleActor, primary: BattleActor, _shape: StringName
	) -> Array[BattleActor]:
		var targets: Array[BattleActor] = []
		targets.append(primary)
		return targets

class MissingCoverContextController:
	extends CombatController

	func forecast_context(
		actor: BattleActor,
		target: BattleActor,
		action: CombatAction,
		options: Dictionary = {},
	) -> Dictionary:
		var context: Dictionary = super.forecast_context(actor, target, action, options)
		var positioning: Dictionary = context.get("positioning", {}) as Dictionary
		positioning.erase("cover_bonus")
		context["positioning"] = positioning
		return context

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


func test_missing_cover_context_uses_same_default_in_forecast_and_submit() -> void:
	var cover_battlefield := CoverBattlefieldSpy.new()
	controller = MissingCoverContextController.new()
	controller.configure([CombatActionCatalog.by_id(&"strike")], cover_battlefield, rules)
	ally.attributes[&"edge"] = 2
	controller.start([ally], [enemy], &"missing-cover-context")
	var strike := controller.action_by_id(&"strike")

	var forecast: Dictionary = controller.forecast_action(strike, enemy)
	var hp_before := enemy.hp
	var result: Dictionary = controller.submit_action(&"strike", enemy)

	assert_bool(result.get("allowed", false)).is_true()
	assert_bool((forecast["context"]["positioning"] as Dictionary).has("cover_bonus")).is_false()
	assert_int(result["damage"]).is_equal(forecast["damage"])
	assert_int(hp_before - enemy.hp).is_equal(forecast["damage"])


func test_pass_class_resource_command_dispatches_to_owner_only() -> void:
	var owner_spy := CommandSpy.new()
	var other_spy := CommandSpy.new()
	ally.class_resource = owner_spy
	var other := _actor("Other Ally", 30, 7, 2)
	other.class_resource = other_spy
	controller.start([ally, other], [enemy], &"class-resource-command")
	var action := controller.action_by_id(&"record-name")

	var missing_target := controller.query_action(action)
	assert_bool(missing_target.get("allowed", false)).is_false()
	assert_str(String(missing_target.get("blocked_by", ""))).is_equal("no_target")
	var result := controller.submit_action(action.id, other)
	assert_bool(result.get("allowed", false)).is_true()
	assert_array(owner_spy.commands).contains(["record_name:%s" % String(other.combat_id)])
	assert_array(other_spy.commands).is_empty()


func test_maiiam_forecast_override_preserves_controller_context() -> void:
	var cast := CombatActionCatalog.by_id(&"cast-seam")
	ally.class_resource = MaiiamBalance.new()
	(ally.class_resource as MaiiamBalance).unbalanced = true
	var ability := AbilityDefinition.new()
	ability.id = "context-preserving-cast"
	ability.element_id = &"strom"
	ability.elements = [&"strom"]
	ability.magnitude = &"note"
	ability.power = 4
	var tables := _cast_tables_for_actor(ally, [ability], "context-preserving-caster")
	controller.configure([cast], battlefield, rules, null, [ability], tables)
	controller.start([ally], [enemy], &"context-preserving-battle")
	var context: Dictionary = controller.forecast_context(
		ally, enemy, cast, {"ability_id": ability.id}
	)
	var unit: Dictionary = context["unit"]
	var fizzle: Dictionary = context["fizzle"]
	assert_str(String(unit["id"])).is_equal(String(ally.combat_id))
	assert_int(int(unit["edge"])).is_equal(ally.attribute_value(&"edge"))
	assert_int(int(unit["breath"])).is_equal(ally.breath)
	assert_str(String(fizzle["patron"])).is_equal(ally.source_member.patron)


func test_scor_consumes_target_aftertone_in_live_resolution() -> void:
	var cast := CombatActionCatalog.by_id(&"cast-seam")
	var ability := AbilityDefinition.new()
	ability.id = "test-scor-cast"
	ability.element_id = &"scor"
	ability.elements = [&"scor"]
	ability.magnitude = &"note"
	ability.power = 1
	ability.breath_cost = 0
	var tables := _cast_tables_for_actor(ally, [ability], "scor-caster")
	controller.configure([cast], battlefield, rules, null, [ability], tables)
	enemy.aftertones = [{"element": &"suul", "remaining_rounds": 2, "anchored": false}]
	controller.start([ally], [enemy], &"scor-live")
	var forecast := controller.forecast_action(cast, enemy, {"ability_id": ability.id, "fizzle": {"agreement_integrity": 100.0, "mastery": true}})
	assert_bool(forecast["resolution"]["fizzled"]).is_false()
	assert_bool((forecast["resolution"]["breakdown"] as Array).any(func(step: Dictionary) -> bool: return step.get("id", "") == "aftertone_burst")).is_true()
	var result := controller.submit_action(cast.id, enemy, {"ability_id": ability.id, "fizzle": {"agreement_integrity": 100.0, "mastery": true}})
	assert_bool(result["allowed"]).is_true()
	assert_int(enemy.aftertones.size()).is_equal(1)
	assert_int(controller.spent_aftertones).is_equal(1)


func test_plain_suul_cast_lays_aftertone_and_fizzle_does_not() -> void:
	var cast := CombatActionCatalog.by_id(&"cast-seam")
	var ability := AbilityDefinition.new()
	ability.id = "test-suul-cast"
	ability.element_id = &"suul"
	ability.elements = [&"suul"]
	ability.magnitude = &"note"
	ability.power = 1
	var tables := _cast_tables_for_actor(ally, [ability], "suul-caster")
	controller.configure([cast], battlefield, rules, null, [ability], tables)
	controller.start([ally], [enemy], &"suul-live")
	var landed := controller.submit_action(cast.id, enemy, {"ability_id": ability.id, "fizzle": {"agreement_integrity": 100.0, "mastery": true}})
	assert_bool(bool(landed.get("allowed", false))).is_true()
	assert_int(enemy.aftertones.size()).is_equal(1)
	assert_int(int(enemy.aftertones[0].get("remaining_rounds", 0))).is_equal(2)
	assert_str(str(enemy.aftertones[0].get("element", ""))).is_equal("suul")

	var fizzle_controller := CombatController.new()
	var fizzle_ally := _actor("Fizzle Ally", 30, 7, 2)
	var fizzle_enemy := _actor("Fizzle Enemy", 30, 5, 1)
	var fizzle_tables := _cast_tables_for_actor(fizzle_ally, [ability], "fizzle-caster")
	fizzle_controller.configure([cast], battlefield, rules, null, [ability], fizzle_tables)
	fizzle_controller.start([fizzle_ally], [fizzle_enemy], &"suul-fizzle")
	var fizzled := fizzle_controller.submit_action(cast.id, fizzle_enemy, {"ability_id": ability.id, "fizzle": {"agreement_integrity": 0.0, "mastery": false}})
	assert_bool(bool(fizzled.get("resolution", {}).get("fizzled", false))).is_true()
	assert_int(fizzle_enemy.aftertones.size()).is_equal(0)


func test_dom_and_wound_lip_casts_use_different_matching_fizzle_percentages() -> void:
	var dom_integrity: float = Battle._agreement_integrity(LocationRegistry.DOM.scene_path)
	var wound_integrity: float = Battle._agreement_integrity(LocationRegistry.WOUND_LIP.scene_path)
	var dom: Dictionary = _cast_outcome_for_integrity(dom_integrity)
	var wound: Dictionary = _cast_outcome_for_integrity(wound_integrity)

	assert_float(wound_integrity).is_less(dom_integrity)
	assert_float(float(dom["forecast"]["context"]["fizzle"]["agreement_integrity"])) \
		.is_equal(dom_integrity)
	assert_float(float(wound["forecast"]["context"]["fizzle"]["agreement_integrity"])) \
		.is_equal(wound_integrity)
	assert_float(float(wound["forecast"]["fizzle_percent"])) \
		.is_greater(float(dom["forecast"]["fizzle_percent"]))
	for outcome: Dictionary in [dom, wound]:
		assert_float(float(outcome["forecast"]["fizzle_percent"])).is_equal(
			float(outcome["committed"]["resolution"]["fizzle_percent"])
		)


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


func test_resolution_refusal_happens_before_scheduler_commit() -> void:
	var invalid_attack := CombatActionCatalog.by_id(&"strike").duplicate(true) as CombatAction
	invalid_attack.id = &"invalid-element-strike"
	invalid_attack.element_id = &"not-on-the-wheel"
	controller.configure([invalid_attack], battlefield, rules)
	controller.start([ally], [enemy], &"resolution-refusal")
	var ap_before := ally.action_points
	var scheduler_before := controller.scheduler.to_dict()
	var event_count_before := events.size()

	var result := controller.submit_action(invalid_attack.id, enemy)

	assert_bool(bool(result.get("allowed", true))).is_false()
	assert_str(String(result.get("blocked_by", &""))).is_equal("unknown_element")
	assert_int(ally.action_points).is_equal(ap_before)
	assert_dict(controller.scheduler.to_dict()).is_equal(scheduler_before)
	assert_int(events.size()).is_equal(event_count_before + 1)
	assert_str(String(events[-1].type)).is_equal("action_refused")


func test_enemy_resolution_refusal_happens_before_scheduler_commit_spends_no_ct() -> void:
	var invalid_attack := CombatActionCatalog.by_id(&"enemy-strike").duplicate(true) as CombatAction
	invalid_attack.element_id = &"not-on-the-wheel"
	var ct_rules := rules.duplicate(true) as CombatRules
	ct_rules.use_charge_time = true
	var target := _actor("CT Refusal Target", 30, 7, 2)
	var foe := _actor("CT Refusal Enemy", 30, 5, 1)
	target.side = &"ally"
	target.combat_id = &"ct-refusal-ally"
	foe.side = &"enemy"
	foe.combat_id = &"ct-refusal-enemy"
	var local_events: Array[CombatEvent] = []
	var local_controller := CombatController.new()
	local_controller.event_emitted.connect(
		func(event: CombatEvent) -> void: local_events.append(event)
	)
	local_controller.configure(
		[invalid_attack], BattlefieldModel.create_default(ct_rules), ct_rules
	)
	local_controller.allies = [target]
	local_controller.enemies = [foe]
	local_controller.battlefield.setup([target], [foe])
	local_controller.scheduler.setup([foe, target])
	var advance := local_controller.scheduler.advance()
	assert_object(advance.get("actor") as BattleActor).is_same(foe)
	var charge_before := local_controller.scheduler.charge_of(foe)

	local_controller._resolve_enemy_actor(foe)

	assert_int(local_controller.scheduler.charge_of(foe)).is_equal(charge_before)
	var refusals := local_events.filter(
		func(event: CombatEvent) -> bool: return event.type == &"action_refused"
	)
	assert_int(refusals.size()).is_equal(1)
	assert_str(String(refusals[0].data.reason.blocked_by)).is_equal("unknown_element")
	assert_array(local_events.filter(
		func(event: CombatEvent) -> bool: return event.type == &"action_resolved"
	)).is_empty()


func test_enemy_attack_commits_the_precommit_resolution_payload() -> void:
	var enemy_attack := CombatActionCatalog.by_id(&"enemy-strike")
	ally.side = &"ally"
	ally.combat_id = &"payload-ally"
	enemy.side = &"enemy"
	enemy.combat_id = &"payload-enemy"
	battlefield.setup([ally], [enemy])
	var gate := controller._query_attack_resolution(enemy, ally, enemy_attack, {})
	assert_bool(bool(gate.get("allowed", false))).is_true()
	var expected_resolution: Dictionary = gate["resolution"].duplicate(true)
	enemy.attack += 100

	var outcome := controller._apply_action(enemy, ally, enemy_attack, {
		"_resolution": expected_resolution,
		"_resolution_context": gate["context"],
	})

	assert_dict(outcome["resolution"]).is_equal(expected_resolution)


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


func test_ap_round_boundary_expires_temporary_effects_before_next_actor() -> void:
	controller.start([ally], [enemy])
	ally.defining_effects["hit"] = true
	ally.defining_effects["range_bonus"] = 1
	ally.aftertones = [{"element": "suul", "remaining_rounds": 2, "anchored": true}]
	controller.thunderhead_hit_until_round = controller.round_number
	controller.range_bonus_until_round = controller.round_number
	controller.duration_freeze_until_round = controller.round_number
	controller.founding_anchor_restore[ally.combat_id] = {"suul:2:0": false}
	assert_bool(controller.end_turn()).is_true()

	assert_int(controller.round_number).is_equal(2)
	assert_object(controller.active_actor()).is_equal(ally)
	assert_bool(ally.defining_effects.has("hit")).is_false()
	assert_bool(ally.defining_effects.has("range_bonus")).is_false()
	assert_bool(bool(ally.aftertones[0].get("anchored", true))).is_false()
	assert_int(controller.range_bonus_until_round).is_equal(0)
	assert_bool(controller.founding_anchor_restore.is_empty()).is_true()


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


func test_tile_states_are_lazy_without_changing_neutral_snapshots() -> void:
	var local_controller := _grid_controller(true)
	assert_int(local_controller.tile_states.size()).is_equal(0)
	var before: Dictionary = local_controller.snapshot()
	assert_int(local_controller.tile_states.size()).is_equal(0)
	assert_array(before["tiles"]).is_not_empty()
	var tile: TileState = local_controller.tile_state_at(Vector2i(0, 0))
	assert_object(tile).is_not_null()
	assert_object(local_controller.tile_state_at(Vector2i(0, 0))).is_same(tile)
	assert_int(local_controller.tile_states.size()).is_equal(1)
	assert_dict(local_controller.snapshot()).is_equal(before)
	assert_object(local_controller.tile_state_at(Vector2i(-999, -999))).is_null()
	assert_int(local_controller.tile_states.size()).is_equal(1)


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


func test_dayspring_and_barrow_cover_windows_change_and_revert_resolution_terms() -> void:
	var revealed := _positional_controller(5, 2)
	var revealed_actor := revealed.allies[0]
	var revealed_target := revealed.enemies[0]
	(revealed.battlefield as GridBattlefieldModel).set_cover(Vector2i(3, 0), true)
	revealed.round_number = 3
	revealed.revealed_until_round = 3
	revealed.revealed_side = revealed_actor.side
	var revealed_forecast := revealed.forecast_action(revealed.action_by_id(&"test-shot"), revealed_target)
	assert_int(int(revealed_forecast["positioning"]["cover_bonus"])).is_equal(0)

	var concealed := _positional_controller(5, 2)
	var concealed_actor := concealed.allies[0]
	var concealed_target := concealed.enemies[0]
	concealed.round_number = 3
	concealed.concealed_until_round = 3
	concealed.concealed_side = concealed_target.side
	var concealed_forecast := concealed.forecast_action(concealed.action_by_id(&"test-shot"), concealed_target)
	assert_int(int(concealed_forecast["positioning"]["cover_bonus"])).is_equal(2)
	concealed.round_number = 4
	var expired_forecast := concealed.forecast_action(concealed.action_by_id(&"test-shot"), concealed_target)
	assert_int(int(expired_forecast["positioning"]["cover_bonus"])).is_equal(0)


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


func _cast_outcome_for_integrity(integrity: float) -> Dictionary:
	var cast := CombatActionCatalog.by_id(&"cast-seam")
	var ability := AbilityDefinition.new()
	ability.id = "location-integrity-cast"
	ability.element_id = &"strom"
	ability.elements = [&"strom"]
	ability.magnitude = &"note"
	ability.power = 6
	ability.breath_cost = 3
	var actor := _actor("Location Caster", 30, 7, 2)
	actor.attributes[&"pitch"] = 2
	actor.breath = 15
	var target := _actor("Location Target", 100, 1, 1)
	var local_rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(
		true
	) as CombatRules
	var local_controller := CombatController.new()
	var tables := _cast_tables_for_actor(actor, [ability], "location-integrity-caster")
	local_controller.configure(
		[cast], BattlefieldModel.create_default(local_rules), local_rules, null, [ability], tables
	)
	local_controller.configure_agreement_integrity(integrity)
	local_controller.start([actor], [target], &"location-integrity")
	var options := {"ability_id": ability.id, "seed": 73}
	var forecast := local_controller.forecast_action(cast, target, options)
	var committed := local_controller.submit_action(cast.id, target, options)
	return {"forecast": forecast, "committed": committed}


# ---- admission (same-map combat step 4): a mob joins a fight already running ----


## The migration table's proof for step 4, driven through the real submit_action path rather
## than through scheduler internals: a hostile admitted mid-session does not act before the
## party's next turn. Run against BOTH economies, because the shipped default is AP and a
## CT-only proof would pass while the game it ships in behaves differently.
##
## "Acts" is read off the event stream, not off active_actor(): enemy turns resolve INSIDE
## _drive_scheduler(), so a poll of active_actor() never sees them.
func test_a_hostile_admitted_mid_session_acts_after_the_partys_next_turn() -> void:
	for use_charge_time: bool in [false, true]:
		var label := "charge time" if use_charge_time else "AP rounds"
		var local_rules := (
			load("res://data/combat/combat_rules.tres") as CombatRules
		).duplicate(true) as CombatRules
		local_rules.use_charge_time = use_charge_time
		var grid := GridBattlefieldModel.new()
		grid.configure(local_rules)
		grid.build_grid(_sized_grid_ground(6, 4))
		var controller_under_test := CombatController.new()
		controller_under_test.configure(CombatActionCatalog.all(), grid, local_rules)
		var ally := _actor("Admission Ally", 400, 1, 0)
		var standing := _actor("Standing Foe", 400, 1, 0)
		var acted: Array[String] = []
		var acted_in_round: Array[int] = []
		controller_under_test.event_emitted.connect(
			func(event: CombatEvent) -> void:
				if event.type == &"action_resolved":
					acted.append(String(event.actor_id))
					acted_in_round.append(controller_under_test.round_number)
		)
		controller_under_test.start([ally], [standing], &"admission-test")

		# The party takes a turn first, so "the party's NEXT turn" is a real later event.
		assert_int(controller_under_test.state).override_failure_message(
			"%s: the ally opens the battle" % label
		).is_equal(CombatController.State.ALLY_TURN)
		var opening: Dictionary = controller_under_test.submit_action(&"guard")
		assert_bool(opening.get("allowed", false)).override_failure_message(
			"%s: the opening action must resolve: %s" % [label, opening.get("message", "")]
		).is_true()

		var newcomer := _actor("Late Arrival", 400, 1, 0)
		var admitted: Dictionary = controller_under_test.admit(newcomer, Vector2i(4, 2), &"enemy")
		assert_bool(admitted.get("allowed", false)).override_failure_message(
			"%s: admission must succeed: %s" % [label, admitted.get("message", "")]
		).is_true()
		assert_array(controller_under_test.enemies).contains([newcomer])
		assert_str(String(controller_under_test.battlefield.position_of(newcomer))).is_equal(
			"c:4,2,0"
		)
		assert_str(String(newcomer.side)).is_equal("enemy")
		assert_str(String(newcomer.combat_id)).is_not_empty()
		assert_str(String(newcomer.combat_id)).is_not_equal(String(standing.combat_id))
		var marker := acted.size()
		var admitted_in_round := controller_under_test.round_number
		if use_charge_time:
			assert_int(controller_under_test.scheduler.charge_of(newcomer)).override_failure_message(
				"%s: the controller must seat the newcomer at the AUTHORED admission_delay" % label
			).is_equal(-local_rules.admission_delay)

		var guard_count := 0
		while guard_count < 80 and not acted.has(String(newcomer.combat_id)):
			guard_count += 1
			if controller_under_test.state == CombatController.State.FINISHED:
				break
			if controller_under_test.state == CombatController.State.ALLY_TURN:
				var submitted: Dictionary = controller_under_test.submit_action(&"guard")
				if not bool(submitted.get("allowed", false)):
					controller_under_test.end_turn()
			else:
				controller_under_test.end_turn()

		var after: Array[String] = []
		for i in range(marker, acted.size()):
			after.append(acted[i])
		var newcomer_index := after.find(String(newcomer.combat_id))
		assert_int(newcomer_index).override_failure_message(
			"%s: the admitted hostile never acted (after admission: %s)" % [label, after]
		).is_greater_equal(0)
		var ally_index := after.find(String(ally.combat_id))
		assert_int(ally_index).override_failure_message(
			"%s: the party must act before a mob that joined mid-fight (after admission: %s)"
			% [label, after]
		).is_between(0, newcomer_index - 1)
		# The sharp edge of the claim: the newcomer does not act in the round it joined.
		# Under charge time that is admission_delay doing the work (the CT arm above pins the
		# authored number the controller forwards). Under AP rounds it is overdetermined — a
		# newcomer also arrives with no action points until the next refresh — so the marking
		# admit() writes is belt and braces there rather than the only guard.
		assert_int(acted_in_round[marker + newcomer_index]).override_failure_message(
			"%s: a mob admitted in round %d acted in that same round"
			% [label, admitted_in_round]
		).is_greater(admitted_in_round)


func test_admission_is_idempotent_and_refuses_a_battle_that_is_not_running() -> void:
	var idle := CombatController.new()
	var idle_rules := load("res://data/combat/combat_rules.tres") as CombatRules
	var idle_grid := GridBattlefieldModel.new()
	idle_grid.configure(idle_rules)
	idle_grid.build_grid(_sized_grid_ground(6, 4))
	idle.configure(CombatActionCatalog.all(), idle_grid, idle_rules)
	var early: Dictionary = idle.admit(_actor("Too Early", 10, 1, 0), Vector2i(3, 1), &"enemy")
	assert_bool(early.get("allowed", true)).is_false()
	assert_str(String(early.get("blocked_by", ""))).is_equal("battle_not_live")

	idle.start([_actor("Ally", 200, 1, 0)], [_actor("Foe", 200, 1, 0)], &"admission-test")
	var mob := _actor("Mob", 40, 1, 0)
	assert_bool(idle.admit(mob, Vector2i(4, 2), &"enemy").get("allowed", false)).is_true()
	var again: Dictionary = idle.admit(mob, Vector2i(4, 3), &"enemy")
	assert_bool(again.get("allowed", false)).override_failure_message(
		"a re-alerted hostile must be absorbed, not refused and not seated twice"
	).is_true()
	assert_bool(again.get("already_admitted", false)).is_true()
	assert_int(idle.enemies.size()).is_equal(2)
	var impostor := _actor("Different Mob", 40, 1, 0)
	impostor.combat_id = mob.combat_id
	var collision: Dictionary = idle.admit(impostor, Vector2i(5, 2), &"enemy")
	assert_bool(collision.get("allowed", true)).is_false()
	assert_str(String(collision.get("blocked_by", ""))).is_equal("composition")
	assert_object(idle.actor_by_id(mob.combat_id)).is_same(mob)
	assert_int(idle.enemies.size()).is_equal(2)


func test_release_takes_a_combatant_out_of_the_order_and_frees_its_cell() -> void:
	var local_rules := load("res://data/combat/combat_rules.tres") as CombatRules
	var grid := GridBattlefieldModel.new()
	grid.configure(local_rules)
	grid.build_grid(_sized_grid_ground(6, 4))
	var controller_under_test := CombatController.new()
	controller_under_test.configure(CombatActionCatalog.all(), grid, local_rules)
	var ally := _actor("Ally", 200, 1, 0)
	var standing := _actor("Standing Foe", 200, 1, 0)
	controller_under_test.start([ally], [standing], &"admission-test")
	var mob := _actor("Mob", 40, 1, 0)
	controller_under_test.admit(mob, Vector2i(4, 2), &"enemy")

	var released: Dictionary = controller_under_test.release(mob.combat_id)
	assert_bool(released.get("allowed", false)).is_true()
	assert_str(String(released.get("from_side", ""))).is_equal("enemy")
	assert_array(controller_under_test.enemies).not_contains([mob])
	assert_object(controller_under_test.actor_by_id(mob.combat_id)).is_null()
	assert_bool(controller_under_test.battlefield.has_combatant(mob)).is_false()
	assert_bool(controller_under_test.scheduler.can_act(mob).get("allowed", true)).is_false()
	assert_str(
		String(controller_under_test.scheduler.can_act(mob).get("blocked_by", ""))
	).is_equal("not_participating")
	# The battle it left is still live: releasing one mob is not a victory.
	assert_int(controller_under_test.state).is_not_equal(CombatController.State.FINISHED)

	# A combatant released and re-admitted must not inherit a stale id or a stale seat.
	var successor := _actor("Successor", 40, 1, 0)
	var readmitted: Dictionary = controller_under_test.admit(successor, Vector2i(4, 2), &"enemy")
	assert_bool(readmitted.get("allowed", false)).is_true()
	assert_str(String(successor.combat_id)).override_failure_message(
		"the next admission must not reuse the departed combatant's id"
	).is_not_equal(String(mob.combat_id))

	var missing: Dictionary = controller_under_test.release(&"no-such-combatant")
	assert_bool(missing.get("allowed", true)).is_false()
	assert_str(String(missing.get("blocked_by", ""))).is_equal("unknown_target")
