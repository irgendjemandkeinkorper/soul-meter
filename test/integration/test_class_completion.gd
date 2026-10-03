extends GdUnitTestSuite

var _controllers: Array[CombatController] = []
var _soul_before: float
var _flags_before: Dictionary


func before_test() -> void:
	_soul_before = GameState.soul_meter
	_flags_before = GameState.flags.duplicate(true)
	GameState.flags.erase(GameState.HUSKED_FLAG)
	GameState.flags.erase(GameState.HUSKED_RECOVERY_CEILING_FLAG)
	GameState.set_soul_meter(50.0)


func after_test() -> void:
	for controller: CombatController in _controllers:
		for actor: BattleActor in controller.allies + controller.enemies:
			actor.class_resource.host = null
	_controllers.clear()
	GameState.flags = _flags_before
	GameState.soul_meter = _soul_before


func test_empty_class_resources_refuse_without_spending_in_ap_and_charge_time() -> void:
	for use_charge_time: bool in [false, true]:
		for row: Array in [["Kero", &"spend-scars"], ["Vicoar", &"spend-token"], ["Stuid", &"spend-clarity"]]:
			var controller := _battle(row[0], use_charge_time)
			var resource := controller.allies[0].class_resource
			if resource is StuidClarity:
				resource.clarity = 0
			var before := resource.to_dict()
			var ap := controller.allies[0].action_points
			var active := controller.active_actor()
			var query := controller.query_action(controller.action_by_id(row[1]))
			assert_bool(query.allowed).is_false()
			assert_str(str(query.blocked_by)).is_equal("class_resource_empty")
			assert_bool(controller.submit_action(row[1]).allowed).is_false()
			assert_dict(resource.to_dict()).is_equal(before)
			assert_int(controller.allies[0].action_points).is_equal(ap)
			assert_object(controller.active_actor()).is_same(active)
			assert_float(GameState.soul_meter).is_equal(50.0)


func test_armed_class_resources_refuse_a_second_spend_and_keep_the_window() -> void:
	for row: Array in [["Kero", &"spend-scars"], ["Vicoar", &"spend-token"], ["Stuid", &"spend-clarity"]]:
		var controller := _battle(row[0])
		var resource := controller.allies[0].class_resource
		if resource is IronbrandScars:
			resource.scars = 2
		elif resource is VicoarInstructiveFailure:
			resource.tokens = 2
		assert_bool(controller.submit_action(row[1]).allowed).is_true()
		var before := resource.to_dict()
		var query := controller.query_action(controller.action_by_id(row[1]))
		assert_bool(query.allowed).is_false()
		assert_str(str(query.blocked_by)).is_equal("class_resource_armed")
		assert_bool(controller.submit_action(row[1]).allowed).is_false()
		assert_dict(resource.to_dict()).is_equal(before)


func test_record_name_refuses_duplicates_before_spending_another_turn() -> void:
	var controller := _battle("Haeren")
	var ally := controller.allies[0]
	assert_bool(controller.submit_action(&"record-name", ally).allowed).is_true()
	var before := ally.class_resource.to_dict()
	var ap := ally.action_points
	var query := controller.query_action(controller.action_by_id(&"record-name"), ally)
	assert_bool(query.allowed).is_false()
	assert_str(str(query.blocked_by)).is_equal("class_resource_duplicate")
	assert_bool(controller.submit_action(&"record-name", ally).allowed).is_false()
	assert_int(ally.action_points).is_equal(ap)
	assert_dict(ally.class_resource.to_dict()).is_equal(before)


func test_every_active_class_loop_has_an_authored_command_and_correct_patron() -> void:
	for row: Array in [
		["Kero", &"spend-scars"], ["Stuid", &"spend-clarity"], ["Vicoar", &"spend-token"],
		["Haeren", &"record-name"], ["Pazzah", &"file-sentence"],
		["Fickah", &"jam-the-gears"], ["Izhakel", &"bind-hostility"],
	]:
		var action := CombatActionCatalog.by_id(row[1])
		assert_object(action).is_not_null()
		if action == null:
			continue
		assert_bool(ClassResourceRegistry.for_patron(row[0]).accepts_command(action.class_resource_action)).is_true()
		assert_int(action.kind).is_equal(CombatAction.Kind.PASS)
		assert_bool(action.player_available).is_true()


func test_oathclock_authored_sentence_round_trips_and_fires_once_in_both_clocks() -> void:
	for use_charge_time: bool in [false, true]:
		var controller := _battle("Pazzah", use_charge_time)
		var enemy := controller.enemies[0]
		var hp := enemy.hp
		assert_bool(controller.submit_action(&"file-sentence", enemy).allowed).is_true()
		assert_int(enemy.hp).is_equal(hp)
		var saved := controller.class_resources_to_dict()
		controller.restore_class_resources(saved)
		var resource := controller.allies[0].class_resource as PazzahLedger
		assert_int(resource.entries.size()).is_equal(1)
		_advance_rounds(controller, 4)
		assert_int(enemy.hp).is_equal(hp - 6)
		assert_array(resource.entries).is_empty()


func test_thread_survives_binding_and_unrelated_actions_then_collects_once() -> void:
	var controller := _battle("Izhakel")
	var owner := controller.allies[0]
	var enemy := controller.enemies[0]
	assert_bool(controller.submit_action(&"bind-hostility", enemy).allowed).is_true()
	var resource := owner.class_resource as IzhakelThreads
	assert_int(resource.threads.size()).is_equal(1)
	assert_str(str(controller.query_action(controller.action_by_id(&"bind-hostility"), enemy).blocked_by)).is_equal("class_resource_duplicate")
	var saved := controller.class_resources_to_dict()
	controller.restore_class_resources(saved)
	resource = owner.class_resource as IzhakelThreads
	var hp := enemy.hp
	_advance_rounds(controller, 3)
	assert_int(enemy.hp).is_equal(hp - 6)
	assert_array(resource.threads).is_empty()


func test_locksmirk_cancels_an_enemy_queue_and_cannot_stack_armed_retries() -> void:
	var controller := _battle("Fickah")
	var enemy := controller.enemies[0]
	var owner := controller.allies[0]
	controller.enqueue_deferred({
		"source_id": String(enemy.combat_id), "delay_rounds": 5,
		"effect": {"writes": [{"kind": "hp", "target_id": String(owner.combat_id), "amount": 4}]},
	})
	assert_bool(controller.submit_action(&"jam-the-gears", enemy).allowed).is_true()
	assert_array(controller.snapshot().deferred).is_empty()
	assert_bool(controller.submit_action(&"jam-the-gears", enemy).allowed).is_true()
	var resource := owner.class_resource as FickahRuleBreaker
	assert_str(String(resource.jam_target_id)).is_equal(String(enemy.combat_id))
	assert_str(str(controller.query_action(controller.action_by_id(&"jam-the-gears"), enemy).blocked_by)).is_equal("class_resource_armed")
	enemy.hp = 0
	resource.on_turn_start()
	assert_str(String(resource.jam_target_id)).is_empty()


func test_enemy_class_actions_refuse_allies_and_bad_payloads_before_spending() -> void:
	for row: Array in [["Pazzah", &"file-sentence"], ["Fickah", &"jam-the-gears"], ["Izhakel", &"bind-hostility"]]:
		var controller := _battle(row[0])
		var owner := controller.allies[0]
		var action := controller.action_by_id(row[1])
		var ap := owner.action_points
		assert_str(str(controller.submit_action(row[1], owner).blocked_by)).is_equal("no_target")
		assert_int(owner.action_points).is_equal(ap)
		if row[0] != "Fickah":
			action.class_resource_payload = {"amount": -6, "delay_rounds": 0}
			assert_str(str(controller.submit_action(row[1], controller.enemies[0]).blocked_by)).is_equal("class_resource_payload")
			assert_int(owner.action_points).is_equal(ap)


func test_river_mother_settles_survivor_refund_before_nonviolent_victory_is_reported() -> void:
	var controller := _battle("Haeren")
	var owner := controller.allies[0]
	owner.breath = 0
	assert_bool(controller.submit_action(&"record-name", owner).allowed).is_true()
	var reported_breath: Array[int] = []
	controller.battle_finished.connect(func(_result: int, _outcome: StringName): reported_breath.append(owner.breath))
	controller._finish(CombatController.ResultState.VICTORY, &"peace")
	assert_int(owner.breath).is_equal(HaerenNameLedger.BREATH_REFUND)
	assert_array(reported_breath).contains_exactly([HaerenNameLedger.BREATH_REFUND])
	assert_float(GameState.soul_meter).is_equal(50.0)


func test_husk_bearer_receives_breath_from_the_last_enemy_dot_kill() -> void:
	var controller := _battle("Vhorr")
	var owner := controller.allies[0]
	var enemy := controller.enemies[0]
	owner.breath = 0
	enemy.hp = 1
	owner.class_resource.enqueue_deferred({
		"writes": [{"kind": "dot", "target_id": String(enemy.combat_id), "amount": 1}],
	}, {"delay_rounds": 0}, &"hunger_dot")
	controller._fire_due_deferred()
	assert_int(controller.state).is_equal(CombatController.State.FINISHED)
	assert_int(owner.breath).is_equal(VhorrHunger.BREATH_REFUND)
	assert_float(GameState.soul_meter).is_equal(50.0)


func test_hunger_ticks_grow_and_cancelled_dots_can_be_reapplied() -> void:
	var controller := _battle("Vhorr")
	var owner := controller.allies[0]
	var enemy := controller.enemies[0]
	var resource := owner.class_resource as VhorrHunger
	assert_bool(controller.submit_action(&"strike", enemy).allowed).is_true()
	assert_int(resource.hunger).is_equal(1)
	var entries := controller.deferred_entries()
	assert_int(entries.size()).is_equal(1)
	entries[0]["due_round"] = controller.round_number
	controller._deferred = entries
	controller._fire_due_deferred()
	assert_int(resource.hunger).is_equal(2)
	assert_int(controller.deferred_entries()[0].effect.writes[0].amount).is_equal(2)
	assert_bool(controller.request_cancel(enemy.combat_id, owner.combat_id, &"deferred").allowed).is_true()
	assert_array(resource.pending_dot_targets).is_empty()
	assert_bool(controller.submit_action(&"strike", enemy).allowed).is_true()
	assert_int(controller.deferred_entries().size()).is_equal(1)


func test_river_mother_observes_deferred_ally_falls_once() -> void:
	var controller := _battle("Haeren", false, true)
	var owner := controller.allies[0]
	var ally := controller.allies[1]
	owner.breath = 0
	assert_bool(controller.submit_action(&"record-name", ally).allowed).is_true()
	controller.enqueue_deferred({
		"source_id": String(controller.enemies[0].combat_id), "delay_rounds": 0,
		"effect": {"writes": [{"kind": "dot", "target_id": String(ally.combat_id), "amount": 100}]},
	})
	controller._fire_due_deferred()
	controller._fire_due_deferred()
	assert_int(owner.breath).is_equal(1)
	controller._finish(CombatController.ResultState.VICTORY, &"peace")
	assert_int(owner.breath).is_equal(1)


func test_finish_settles_only_due_refunds_and_never_advances_offensive_effects() -> void:
	var controller := _battle("Haeren")
	var owner := controller.allies[0]
	var enemy := controller.enemies[0]
	owner.breath = 0
	assert_bool(controller.submit_action(&"record-name", owner).allowed).is_true()
	owner.class_resource.enqueue_deferred({"writes": [{"kind": "hp", "target_id": String(enemy.combat_id), "amount": 90}]}, {"delay_rounds": 0})
	owner.class_resource.enqueue_deferred({"writes": [{"kind": "breath", "target_id": String(owner.combat_id), "amount": 90}]}, {"delay_rounds": 5})
	var round_before := controller.round_number
	controller._finish(CombatController.ResultState.VICTORY, &"peace")
	controller._finish(CombatController.ResultState.VICTORY, &"peace")
	assert_int(owner.breath).is_equal(1)
	assert_int(enemy.hp).is_equal(100)
	assert_int(controller.round_number).is_equal(round_before)
	assert_float((owner.class_resource as HaerenNameLedger).pending_breath_refunds).is_equal(0.0)


func test_class_soul_cost_is_checked_and_spent_once_by_the_controller() -> void:
	var controller := _battle("Fickah")
	var owner := controller.allies[0]
	var enemy := controller.enemies[0]
	GameState.set_soul_meter(0.0)
	var ap := owner.action_points
	assert_str(str(controller.submit_action(&"jam-the-gears", enemy).blocked_by)).is_equal("soul")
	assert_int(owner.action_points).is_equal(ap)
	GameState.set_soul_meter(1.0)
	assert_bool(controller.submit_action(&"jam-the-gears", enemy).allowed).is_true()
	assert_float(GameState.soul_meter).is_equal(0.0)
	assert_bool(controller.submit_action(&"jam-the-gears", enemy).allowed).is_false()
	assert_float(GameState.soul_meter).is_equal(0.0)


func test_real_cast_actions_drive_hunger_clarity_failure_and_attribution() -> void:
	for patron: String in ["Vhorr", "Stuid", "Vicoar", "Ofshutje"]:
		var controller := _spell_battle(patron)
		var owner := controller.allies[0]
		var enemy := controller.enemies[0]
		var resource := owner.class_resource
		if resource is StuidClarity:
			assert_bool(controller.submit_action(&"spend-clarity").allowed).is_true()
		elif resource is VicoarInstructiveFailure:
			controller.configure_agreement_integrity(0.0)
			owner.attributes[&"pitch"] = 0
			var fizzle_options := _cast_options(controller, true)
			var failed := controller.submit_action(&"cast-seam", enemy, fizzle_options)
			assert_bool(failed.resolution.fizzled).is_true()
			assert_int(resource.tokens).is_equal(1)
			assert_bool(controller.submit_action(&"spend-token").allowed).is_true()
		var options := _cast_options(controller, false)
		var before := resource.to_dict()
		var forecast := controller.forecast_action(controller.action_by_id(&"cast-seam"), enemy, options)
		assert_dict(resource.to_dict()).is_equal(before)
		var result := controller.submit_action(&"cast-seam", enemy, options)
		assert_bool(result.allowed).is_true()
		assert_dict(result.resolution).is_equal(forecast.resolution)
		if resource is VhorrHunger:
			assert_int(resource.hunger).is_equal(1)
			assert_array(resource.pending_dot_targets).contains([String(enemy.combat_id)])
		elif resource is StuidClarity:
			assert_bool(forecast.resolution.has("revealed")).is_true()
			assert_bool(resource.reveal_armed).is_false()
		elif resource is VicoarInstructiveFailure:
			assert_float(float(result.resolution.fizzle_percent)).is_equal(0.0)
			assert_bool(resource.guaranteed_cast_armed).is_false()
		else:
			assert_bool(result.resolution.has("hidden_draw")).is_true()
			assert_str(String(resource.last_effect_id)).is_not_empty()


func test_battle_facade_routes_ally_and_enemy_commands_and_charges_jam_once() -> void:
	for row: Array in [["Haeren", &"record-name"], ["Pazzah", &"file-sentence"], ["Fickah", &"jam-the-gears"], ["Izhakel", &"bind-hostility"]]:
		var controller := _battle(row[0])
		# A separate instance exercises the public facade without changing the live autoload.
		var facade := auto_free(load("res://globals/battle.gd").new()) as Node
		facade.controller = controller
		facade.allies = controller.allies
		facade.enemies = controller.enemies
		facade.ended = false
		var action := controller.action_by_id(row[1])
		assert_bool(facade.action_refusal(action).allowed).is_true()
		var before := GameState.soul_meter
		assert_bool(facade.use_action(row[1])).is_true()
		assert_float(GameState.soul_meter).is_equal(before - action.soul_cost)
		if row[0] == "Haeren":
			assert_array((controller.allies[0].class_resource as HaerenNameLedger).recorded_actor_ids).contains([String(controller.allies[0].combat_id)])
		else:
			assert_bool(action.requires_enemy_target()).is_true()


func test_thread_touch_range_and_full_resource_queues_refuse_before_costs() -> void:
	var controller := _battle("Izhakel")
	var grid := GridBattlefieldModel.new()
	grid.configure(controller.rules)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tile_set
	for y in 5:
		for x in 5:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	grid.build_grid(ground)
	grid.setup(controller.allies, controller.enemies)
	controller.battlefield = grid
	var owner := controller.allies[0]
	var enemy := controller.enemies[0]
	grid.move(owner, grid._handle_for_cell(Vector2i.ZERO))
	grid.move(enemy, grid._handle_for_cell(Vector2i(4, 4)))
	var ap := owner.action_points
	assert_bool(controller.submit_action(&"bind-hostility", enemy).allowed).is_false()
	assert_int(owner.action_points).is_equal(ap)
	assert_bool(grid.move(enemy, grid._handle_for_cell(Vector2i(1, 0))).allowed).is_true()
	assert_bool(controller.query_action(controller.action_by_id(&"bind-hostility"), enemy).allowed).is_true()
	var threads := owner.class_resource as IzhakelThreads
	for i in IzhakelThreads.MAX_THREADS:
		threads.bind_thread(StringName("other-%d" % i), {"verb": CombatAction.Verb.ATTACK}, {})
	assert_str(str(controller.submit_action(&"bind-hostility", enemy).blocked_by)).is_equal("class_resource_full")
	assert_int(owner.action_points).is_equal(ap)
	var oath := _battle("Pazzah")
	var ledger := oath.allies[0].class_resource as PazzahLedger
	for i in PazzahLedger.MAX_ENTRIES:
		ledger.queue_effect(&"test", 5, {"writes": [{"kind": "hp", "target_id": String(oath.enemies[0].combat_id), "amount": 1}]})
	assert_str(str(oath.submit_action(&"file-sentence", oath.enemies[0]).blocked_by)).is_equal("class_resource_full")


func test_class_command_forecasts_describe_the_command_without_resolving_an_attack() -> void:
	for row: Array in [["Pazzah", &"file-sentence"], ["Fickah", &"jam-the-gears"], ["Izhakel", &"bind-hostility"]]:
		var controller := _battle(row[0])
		var action := controller.action_by_id(row[1])
		var owner := controller.allies[0]
		var enemy := controller.enemies[0]
		var before := controller.class_resources_to_dict()
		var forecast := controller.forecast_action(action, enemy, {"class_resource_payload": {"amount": 999}})
		assert_bool(forecast.get("class_command", false)).is_true()
		assert_int(int(forecast.get("damage", -1))).is_equal(0)
		assert_bool(forecast.has("resolution")).is_false()
		assert_str(str(forecast.get("description", ""))).is_equal(action.description)
		assert_dict(controller.class_resources_to_dict()).is_equal(before)
		assert_bool(controller.submit_action(row[1], enemy, {"class_resource_payload": {"amount": 999}}).allowed).is_true()
		if row[0] == "Pazzah":
			assert_int(controller.deferred_entries()[0].effect.writes[0].amount).is_equal(6)
		elif row[0] == "Izhakel":
			assert_int((owner.class_resource as IzhakelThreads).threads[0].payoff.writes[0].amount).is_equal(6)


func test_class_forecast_panel_keeps_delayed_effect_copy_during_wheel_selection() -> void:
	var runner := scene_runner("res://ui/hud/regions/forecast_panel/forecast_panel_region.tscn")
	var panel := runner.scene() as ForecastPanelRegion
	var action := CombatActionCatalog.by_id(&"file-sentence")
	panel.show_action_forecast({"allowed": true, "class_command": true, "description": action.description, "damage": 0})
	assert_str(panel.forecast.text).is_equal(action.description)
	panel.select_element(&"khash")
	assert_str(panel.forecast.text).is_equal(action.description)


func test_dead_thread_targets_release_their_contract_slot() -> void:
	var controller := _battle("Izhakel")
	var owner := controller.allies[0]
	var enemy := controller.enemies[0]
	assert_bool(controller.submit_action(&"bind-hostility", enemy).allowed).is_true()
	controller._apply_resolution_writes(owner, enemy, {"writes": [{"kind": "hp", "after": 0}]})
	assert_array((owner.class_resource as IzhakelThreads).threads).is_empty()


func test_mirrorblade_and_ironbrand_loops_follow_real_combat_actions() -> void:
	var mirror := _battle("Maiiam")
	var balance := mirror.allies[0].class_resource as MaiiamBalance
	assert_bool(mirror.submit_action(&"guard").allowed).is_true()
	assert_bool(balance.unbalanced).is_false()
	assert_bool(mirror.submit_action(&"guard").allowed).is_true()
	assert_bool(balance.unbalanced).is_true()
	assert_bool(mirror.submit_action(&"strike", mirror.enemies[0]).allowed).is_true()
	assert_bool(balance.unbalanced).is_false()
	var iron := _battle("Kero")
	var owner := iron.allies[0]
	var enemy := iron.enemies[0]
	var scars := owner.class_resource as IronbrandScars
	_advance_rounds(iron, 1)
	assert_int(scars.scars).is_greater(0)
	assert_bool(iron.submit_action(&"spend-scars").allowed).is_true()
	var forecast := iron.forecast_action(iron.action_by_id(&"strike"), enemy)
	assert_bool(scars.guaranteed_hit_armed).is_true()
	var result := iron.submit_action(&"strike", enemy)
	assert_bool(result.resolution.hit).is_true()
	assert_dict(result.resolution).is_equal(forecast.resolution)
	assert_bool(scars.guaranteed_hit_armed).is_false()


func _spell_battle(patron: String) -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var owner := _actor("Caster")
	owner.class_resource = ClassResourceRegistry.for_patron(patron)
	owner.attributes[&"pitch"] = 20
	owner.breath = 100
	owner.source_member = PartyMember.new()
	owner.source_member.id = "class-caster"
	owner.source_member.patron = patron
	var ability := AbilityDefinition.new()
	ability.id = "class-note"
	ability.element_id = &"zhur"
	ability.elements = [&"zhur"]
	ability.magnitude = &"note"
	ability.power = 6
	ability.breath_cost = 1
	var tables := TacticalTables.new()
	tables.abilities[ability.id] = ability
	var loadout := UnitLoadout.create(owner.source_member.id)
	loadout.action_ability_ids.append(ability.id)
	tables.loadouts[owner.source_member.id] = loadout
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), BattlefieldModel.create_default(rules), rules, null, [ability], tables)
	controller.start([owner], [_actor("Target")], &"class-spells")
	_controllers.append(controller)
	return controller


func _cast_options(controller: CombatController, fizzled: bool) -> Dictionary:
	for seed_value in 100:
		var options := {"ability_id": "class-note", "seed": seed_value}
		var forecast := controller.forecast_action(controller.action_by_id(&"cast-seam"), controller.enemies[0], options)
		if bool(forecast.get("allowed", false)) and bool(forecast.resolution.get("fizzled", false)) == fizzled:
			return options
	assert_bool(false).override_failure_message("No deterministic cast with the required outcome found.").is_true()
	return {}


func _advance_rounds(controller: CombatController, count: int) -> void:
	var goal := controller.round_number + count
	for step in 80:
		if controller.round_number >= goal or controller.state == CombatController.State.FINISHED:
			break
		assert_bool(controller.submit_action(&"guard").allowed).is_true()
	assert_int(controller.round_number).is_greater_equal(goal)


func _battle(patron: String, use_charge_time: bool = false, with_companion: bool = false) -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = use_charge_time
	var ally := _actor("Class tester")
	ally.class_resource = ClassResourceRegistry.for_patron(patron)
	var enemy := _actor("Target")
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), BattlefieldModel.create_default(rules), rules)
	var party: Array[BattleActor] = [ally]
	if with_companion:
		party.append(_actor("Companion"))
	controller.start(party, [enemy], &"class-completion")
	_controllers.append(controller)
	return controller


func _actor(display_name: String) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = display_name
	actor.hp = 100
	actor.max_hp = 100
	actor.attack = 5
	actor.defense = 1
	return actor
