extends GdUnitTestSuite
## #285 slice 2 in a live controller: perks attach from the PartyMember, survive a restore,
## and Second Pick's ally-turn retry is dispatched by the controller.

var _controllers: Array[CombatController] = []
var _soul_before: float


func before_test() -> void:
	_soul_before = GameState.soul_meter
	GameState.set_soul_meter(50.0)


func after_test() -> void:
	for controller: CombatController in _controllers:
		for actor: BattleActor in controller.allies + controller.enemies:
			actor.class_resource.host = null
	_controllers.clear()
	GameState.soul_meter = _soul_before


func test_the_controller_attaches_the_members_perks() -> void:
	var controller := _battle([_member_actor("Kero", ["ironbrand-thick-hide"]), _member_actor("Stuid", ["lensbearer-wider-lens"])])
	var scars := controller.allies[0].class_resource as IronbrandScars
	var clarity := controller.allies[1].class_resource as StuidClarity
	assert_int(scars.max_scars()).is_equal(IronbrandScars.MAX_SCARS + 1)
	assert_int(clarity.clarity).is_equal(StuidClarity.MAX_CLARITY + 1)


func test_a_restore_keeps_perks_and_reads_them_off_the_member_for_an_older_save() -> void:
	var controller := _battle([_member_actor("Kero", ["ironbrand-thick-hide"])])
	var owner := controller.allies[0]
	var legacy: Dictionary = (owner.class_resource as IronbrandScars).to_dict()
	legacy.erase("perk_ids")
	controller.restore_class_resources({String(owner.combat_id): legacy})
	assert_int((owner.class_resource as IronbrandScars).max_scars()).is_equal(IronbrandScars.MAX_SCARS + 1)


func test_second_pick_retries_an_armed_jam_on_an_ally_turn() -> void:
	for with_perk: bool in [false, true]:
		var perks: Array = ["locksmirk-second-pick"] if with_perk else []
		var controller := _battle([_member_actor("Fickah", perks), _member_actor("", [])])
		var owner := controller.allies[0]
		var companion := controller.allies[1]
		var enemy := controller.enemies[0]
		var jam := owner.class_resource as FickahRuleBreaker
		assert_bool(jam.jam_the_gears(enemy.combat_id)).is_false()
		assert_str(String(jam.jam_target_id)).override_failure_message("nothing pending arms the Jam").is_equal(String(enemy.combat_id))
		controller.enqueue_deferred({
			"source_id": String(enemy.combat_id), "delay_rounds": 5,
			"effect": {"writes": [{"kind": "hp", "target_id": String(owner.combat_id), "amount": 4}]},
		})
		jam.on_ally_turn_start(companion.combat_id)
		if with_perk:
			assert_str(String(jam.jam_target_id)).is_empty()
			assert_array(controller.snapshot().deferred).is_empty()
		else:
			assert_str(String(jam.jam_target_id)).is_equal(String(enemy.combat_id))
			assert_array(controller.snapshot().deferred).is_not_empty()


func test_the_controller_dispatches_ally_turn_starts_to_the_other_allies() -> void:
	var controller := _battle([_member_actor("Fickah", ["locksmirk-second-pick"]), _member_actor("", [])])
	var owner := controller.allies[0]
	var enemy := controller.enemies[0]
	var jam := owner.class_resource as FickahRuleBreaker
	jam.jam_the_gears(enemy.combat_id)
	controller.enqueue_deferred({
		"source_id": String(enemy.combat_id), "delay_rounds": 5,
		"effect": {"writes": [{"kind": "hp", "target_id": String(owner.combat_id), "amount": 4}]},
	})
	# Pass turns until the Jam fires, and record whose turn had just started when it did. The
	# Locksmirk's own turn retries without the perk, so only the companion's turn proves the
	# controller dispatched `on_ally_turn_start()`.
	var cleared_on: BattleActor = null
	for step in 40:
		if controller.state == CombatController.State.FINISHED:
			break
		assert_bool(controller.submit_action(&"guard").allowed).is_true()
		if jam.jam_target_id.is_empty():
			cleared_on = controller.allies[controller.active_ally_index]
			break
	assert_object(cleared_on).is_same(controller.allies[1])
	assert_array(controller.snapshot().deferred).is_empty()


func test_steadier_hand_redraws_a_lowest_result_and_forecast_still_equals_commit() -> void:
	var controller := _spell_battle("Ofshutje")
	var owner := controller.allies[0]
	var enemy := controller.enemies[0]
	var storm := owner.class_resource as OfshutjeAttribution
	var lowest := ""
	var options := {}
	for seed_value in 200:
		var candidate := {"ability_id": "perk-note", "seed": seed_value}
		var plain := controller.forecast_action(controller.action_by_id(&"cast-seam"), enemy, candidate)
		var draw: Dictionary = plain.get("resolution", {}).get("hidden_draw", {})
		if bool(plain.get("allowed", false)) and str(draw.get("row_id", "")) == "surge":
			lowest = "surge"
			options = candidate
			break
	assert_str(lowest).override_failure_message("no seed lands the lowest row").is_equal("surge")

	storm.apply_perks(PackedStringArray(["stormbearer-steadier-hand"]))
	var forecast := controller.forecast_action(controller.action_by_id(&"cast-seam"), enemy, options)
	var redrawn: Dictionary = forecast.resolution.hidden_draw
	assert_bool(bool(redrawn.get("redrawn", false))).is_true()
	assert_str(str(redrawn["first_row_id"])).is_equal("surge")
	assert_bool(storm.redraw_spent).override_failure_message("a forecast spends nothing").is_false()
	var result := controller.submit_action(&"cast-seam", enemy, options)
	assert_dict(result.resolution).is_equal(forecast.resolution)
	assert_bool(storm.redraw_spent).is_true()


func _spell_battle(patron: String) -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var owner := _actor("Caster")
	owner.class_resource = ClassResourceRegistry.for_patron(patron)
	owner.attributes[&"pitch"] = 20
	owner.breath = 100
	owner.source_member = PartyMember.new()
	owner.source_member.id = "perk-caster"
	owner.source_member.patron = patron
	var ability := AbilityDefinition.new()
	ability.id = "perk-note"
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
	controller.start([owner], [_actor("Target")], &"perk-spells")
	_controllers.append(controller)
	return controller


func test_ct_capstones_make_their_target_late_once() -> void:
	# Known Edge: the first enemy to act against the Mirrorblade.
	var edge := _battle([_member_actor("Maiiam", ["mirrorblade-known-edge"])], true)
	var mirror := edge.allies[0]
	var foe := edge.enemies[0]
	var before := edge.scheduler.charge_of(foe)
	mirror.class_resource.on_any_action(foe.combat_id, &"strike", mirror.combat_id, {})
	assert_int(edge.scheduler.charge_of(foe)).is_equal(before - 20)
	mirror.class_resource.on_any_action(foe.combat_id, &"strike", mirror.combat_id, {})
	assert_int(edge.scheduler.charge_of(foe)).override_failure_message("once per battle").is_equal(before - 20)

	# Known Contract: binding delays the bound enemy.
	var knot := _battle([_member_actor("Izhakel", ["threadwalker-known-contract"])], true)
	var bound := knot.enemies[0]
	before = knot.scheduler.charge_of(bound)
	knot.allies[0].class_resource.execute_command(&"bind_hostility", bound.combat_id, {"amount": 3})
	assert_int(knot.scheduler.charge_of(bound)).is_equal(before - 20)

	# Jammed Twice: a Jam that finds nothing pending.
	var gears := _battle([_member_actor("Fickah", ["locksmirk-jammed-twice"])], true)
	var jammed := gears.enemies[0]
	before = gears.scheduler.charge_of(jammed)
	assert_bool((gears.allies[0].class_resource as FickahRuleBreaker).jam_the_gears(jammed.combat_id)).is_false()
	assert_int(gears.scheduler.charge_of(jammed)).is_equal(before - 20)


func test_doubled_knot_allows_a_second_contract_and_no_third() -> void:
	var controller := _battle([_member_actor("Izhakel", ["threadwalker-doubled-knot", "threadwalker-fourth-thread"])])
	var threads := controller.allies[0].class_resource as IzhakelThreads
	var enemy := controller.enemies[0]
	for i in 2:
		assert_bool(bool(threads.query_command(&"bind_hostility", enemy.combat_id, {"amount": 2}).allowed)).is_true()
		threads.execute_command(&"bind_hostility", enemy.combat_id, {"amount": 2})
	assert_int(threads.contract_count(enemy.combat_id, IzhakelThreads.KIND_HOSTILITY)).is_equal(2)
	assert_str(str(threads.query_command(&"bind_hostility", enemy.combat_id, {"amount": 2}).blocked_by)).is_equal("class_resource_duplicate")


func test_prompt_court_files_one_round_sooner_and_public_verdict_resists_the_jam() -> void:
	var controller := _battle([_member_actor("Pazzah", ["oathclock-prompt-court", "oathclock-public-verdict"]), _member_actor("", [])])
	var ledger := controller.allies[0].class_resource as PazzahLedger
	var enemy := controller.enemies[0]
	assert_int(controller.allies_within(controller.allies[0].combat_id, 1)).is_greater(0)
	assert_bool(ledger.queue_effect(&"file_sentence", 3, {"writes": [{"kind": "hp", "target_id": String(enemy.combat_id), "amount": 2}]})).is_true()
	var entry: Dictionary = controller.deferred_entries()[0]
	assert_int(int(entry["due_round"])).is_equal(controller.round_number + 2)
	assert_bool(bool(entry.get("unjammable", false))).is_true()
	var refusal := controller.request_cancel(enemy.combat_id, controller.allies[0].combat_id, &"deferred")
	assert_str(str(refusal.blocked_by)).is_equal("verdict_public")
	assert_int(controller.deferred_entries().size()).is_equal(1)
	# A one-round Sentence does not fall due this round.
	ledger.queue_effect(&"file_sentence", 1, {"writes": [{"kind": "hp", "target_id": String(enemy.combat_id), "amount": 2}]})
	assert_int(int(controller.deferred_entries()[1]["due_round"])).is_equal(controller.round_number + 1)


func test_slow_rot_lands_a_jammed_tick_one_round_later_once() -> void:
	for with_perk: bool in [false, true]:
		var controller := _battle([_member_actor("Vhorr", ["husk-bearer-slow-rot"] if with_perk else [])])
		var husk := controller.allies[0]
		var enemy := controller.enemies[0]
		var hunger := husk.class_resource as VhorrHunger
		hunger.hunger = 2
		hunger._queue_hunger_dot(enemy.combat_id)
		assert_bool(bool(controller.request_cancel(enemy.combat_id, husk.combat_id, &"deferred").allowed)).is_true()
		var left := controller.deferred_entries()
		if not with_perk:
			assert_array(left).is_empty()
			continue
		assert_int(left.size()).is_equal(1)
		assert_str(str(left[0]["label"])).is_equal("hunger_dot_lingering")
		assert_int(int(left[0]["due_round"])).is_equal(controller.round_number + 1)
		controller.request_cancel(enemy.combat_id, husk.combat_id, &"deferred")
		assert_array(controller.deferred_entries()).override_failure_message("a lingering tick does not linger again").is_empty()


func test_haeren_capstones_record_her_own_name_twice_and_carry_a_fall_to_every_recorded_ally() -> void:
	var controller := _battle([
		_member_actor("Haeren", ["river-mother-own-name-twice", "river-mother-names-carried"]),
		_member_actor("", []), _member_actor("", []),
	])
	var mother := controller.allies[0]
	var first := controller.allies[1]
	var second := controller.allies[2]
	second.display_name = "Second companion"
	var ledger := mother.class_resource as HaerenNameLedger
	for target: BattleActor in [mother, mother, first, second]:
		assert_bool(bool(ledger.query_command(&"record_name", target.combat_id).allowed)).is_true()
		ledger.on_command(&"record_name", target.combat_id)
	assert_str(str(ledger.query_command(&"record_name", mother.combat_id).blocked_by)).is_equal("class_resource_duplicate")
	assert_int(ledger.recorded_actor_ids.count(String(mother.combat_id))).is_equal(2)

	first.hp = 0
	ledger.on_combatant_fell(first.combat_id)
	var writes: Array = controller.deferred_entries()[-1]["effect"]["writes"]
	assert_str(str(writes[0]["target_id"])).is_equal(String(mother.combat_id))
	var carried: Array[String] = []
	for write: Dictionary in writes.slice(1):
		carried.append(str(write["target_id"]))
	assert_array(carried).override_failure_message("every other living recorded ally, once").is_equal([String(second.combat_id)])

	# Her own name pays once per recording.
	var before := ledger.pending_breath_refunds
	ledger._refund_actor(mother.combat_id)
	assert_float(ledger.pending_breath_refunds - before).is_equal(float(HaerenNameLedger.BREATH_REFUND * 2))


func test_spectacular_failure_needs_a_witness() -> void:
	var alone := _battle([_member_actor("Vicoar", ["flamebinder-spectacular-failure"])])
	var seen := _battle([_member_actor("Vicoar", ["flamebinder-spectacular-failure"]), _member_actor("", [])])
	for controller: CombatController in [alone, seen]:
		(controller.allies[0].class_resource as VicoarInstructiveFailure).on_fizzle({})
	assert_int((alone.allies[0].class_resource as VicoarInstructiveFailure).tokens).is_equal(1)
	assert_int((seen.allies[0].class_resource as VicoarInstructiveFailure).tokens).is_equal(2)


func test_pocketed_gear_makes_the_next_jam_free_in_a_live_battle() -> void:
	var controller := _battle([_member_actor("Fickah", ["locksmirk-pocketed-gear"])])
	var owner := controller.allies[0]
	var enemy := controller.enemies[0]
	controller.enqueue_deferred({
		"source_id": String(enemy.combat_id), "delay_rounds": 5,
		"effect": {"writes": [{"kind": "hp", "target_id": String(owner.combat_id), "amount": 4}]},
	})
	var soul := GameState.soul_meter
	assert_bool(controller.submit_action(&"jam-the-gears", enemy).allowed).is_true()
	assert_float(GameState.soul_meter).is_less(soul)
	var after_paid := GameState.soul_meter
	assert_bool((owner.class_resource as FickahRuleBreaker).free_jam_banked).is_true()
	controller.enqueue_deferred({
		"source_id": String(enemy.combat_id), "delay_rounds": 5,
		"effect": {"writes": [{"kind": "hp", "target_id": String(owner.combat_id), "amount": 4}]},
	})
	_advance_to(controller, owner)
	assert_bool(controller.submit_action(&"jam-the-gears", enemy).allowed).is_true()
	assert_float(GameState.soul_meter).override_failure_message("the banked Jam is free").is_equal(after_paid)
	assert_float(GameState.soul_meter).override_failure_message("and nothing was refunded").is_less_equal(after_paid)


func test_named_storm_keeps_the_higher_draw_and_grounded_lifts_the_lowest() -> void:
	var plain := _spell_battle("Ofshutje")
	var storm := _spell_battle("Ofshutje")
	storm.allies[0].class_resource.apply_perks(PackedStringArray(["stormbearer-named-storm"]))
	var grounded := _spell_battle("Ofshutje")
	grounded.allies[0].class_resource.apply_perks(PackedStringArray(["stormbearer-grounded"]))
	var lifted := false
	var stormed := false
	for seed_value in 120:
		var options := {"ability_id": "perk-note", "seed": seed_value}
		var base := _draw(plain, options)
		if base.is_empty():
			continue
		var kept := _draw(storm, options)
		assert_int(int(kept["row"]["bonus_damage"])).is_greater_equal(int(base["row"]["bonus_damage"]))
		if int(kept["row"]["bonus_damage"]) > int(base["row"]["bonus_damage"]):
			stormed = true
		var floor := _draw(grounded, options)
		assert_str(str(floor["row_id"])).is_not_equal("surge")
		if str(base["row_id"]) == "surge":
			assert_str(str(floor.get("grounded_from", ""))).is_equal("surge")
			lifted = true
	assert_bool(stormed).override_failure_message("no seed where the second draw was higher").is_true()
	assert_bool(lifted).override_failure_message("no seed landed the lowest row").is_true()


func _draw(controller: CombatController, options: Dictionary) -> Dictionary:
	var forecast := controller.forecast_action(controller.action_by_id(&"cast-seam"), controller.enemies[0], options)
	if not bool(forecast.get("allowed", false)):
		return {}
	return forecast.get("resolution", {}).get("hidden_draw", {})


func _advance_to(controller: CombatController, actor: BattleActor) -> void:
	for step in 40:
		if controller.state == CombatController.State.ALLY_TURN and controller.allies[controller.active_ally_index] == actor \
				and bool(controller.query_action(controller.action_by_id(&"jam-the-gears"), controller.enemies[0]).get("allowed", false)):
			return
		controller.submit_action(&"guard")


func _battle(party: Array[BattleActor], use_charge_time: bool = false) -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = use_charge_time
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), BattlefieldModel.create_default(rules), rules)
	controller.start(party, [_actor("Target")], &"perk-effects")
	_controllers.append(controller)
	return controller


func _member_actor(patron: String, perk_ids: Array) -> BattleActor:
	var actor := _actor("%s tester" % patron if not patron.is_empty() else "Companion")
	actor.source_member = PartyMember.new()
	actor.source_member.id = "perk-%s" % patron.to_lower()
	actor.source_member.patron = patron
	actor.source_member.perk_ids = PackedStringArray(perk_ids)
	return actor


func _actor(display_name: String) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = display_name
	actor.hp = 100
	actor.max_hp = 100
	actor.attack = 5
	actor.defense = 1
	return actor
