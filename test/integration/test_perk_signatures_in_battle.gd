extends GdUnitTestSuite
## #285 slice 4 in a live controller: the level-4 signatures and the two carry capstones
## (rulings 2026-10-26). Sacred Clarity and Read Aloud: test_enemy_intents.gd (slice 5).

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


func test_reflection_is_armed_by_command_and_splits_the_next_enemy_attack() -> void:
	var bare := _battle([_member_actor("Maiiam", [])])
	assert_str(str(bare.query_action(bare.action_by_id(&"reflection"), null).get("blocked_by", ""))).is_equal("perk_missing")

	var controller := _battle([_member_actor("Maiiam", ["mirrorblade-reflection"])])
	var mirror := controller.allies[0]
	var enemy := controller.enemies[0]
	var balance := mirror.class_resource as MaiiamBalance
	assert_bool(controller.submit_action(&"reflection").allowed).is_true()
	assert_bool(balance.reflection_armed).is_true()
	# An ally's or her own HP loss does not spend it; only an enemy's attack does.
	assert_int(balance.adjust_incoming_hp(mirror.combat_id, mirror.combat_id, 100, 90)).is_equal(90)
	assert_bool(balance.reflection_armed).is_true()

	var hit := controller._materialize_write({"kind": "hp", "amount": 10}, mirror)
	controller._apply_resolution_writes(enemy, mirror, {"writes": [hit]}, false, &"strike")
	assert_int(mirror.hp).override_failure_message("she keeps half").is_equal(95)
	assert_bool(balance.reflection_used).is_true()
	assert_bool(balance.reflection_armed).is_false()
	var reflected: Array = controller.deferred_entries()
	assert_int(reflected.size()).is_equal(1)
	assert_str(str(reflected[0]["effect"]["writes"][0]["target_id"])).is_equal(String(enemy.combat_id))
	assert_int(int(reflected[0]["effect"]["writes"][0]["amount"])).is_equal(5)
	# Spent for the battle: the next hit lands whole and the command is refused.
	controller._apply_resolution_writes(enemy, mirror, {"writes": [controller._materialize_write({"kind": "hp", "amount": 10}, mirror)]}, false, &"strike")
	assert_int(mirror.hp).is_equal(85)
	assert_str(str(balance.query_command(&"reflection", mirror.combat_id).blocked_by)).is_equal("class_resource_spent")
	var restored := ClassResourceRegistry.from_dict(balance.to_dict()) as MaiiamBalance
	assert_bool(restored.reflection_used).is_true()


func test_reflection_sends_the_half_back_from_a_resolved_enemy_strike() -> void:
	var controller := _battle([_member_actor("Maiiam", ["mirrorblade-reflection"])])
	var mirror := controller.allies[0]
	var enemy := controller.enemies[0]
	var balance := mirror.class_resource as MaiiamBalance
	assert_bool(controller.submit_action(&"reflection").allowed).is_true()
	var strike := controller.action_by_id(&"enemy-strike")
	var landed := 0
	for attempt in 20:
		var outcome := controller._apply_action(enemy, mirror, strike, {})
		landed = int(outcome.get("resolution", {}).get("damage", 0))
		if landed > 0:
			break
	assert_int(landed).override_failure_message("the enemy never landed a hit").is_greater(1)
	assert_bool(balance.reflection_used).is_true()
	assert_int(100 - mirror.hp).is_equal(landed - landed / 2)
	# The reflected half rides the deferred queue and lands at the next turn boundary.
	for step in 6:
		if controller.deferred_entries().is_empty():
			break
		controller.submit_action(&"guard")
	assert_int(100 - enemy.hp).override_failure_message("the attacker took the reflected half").is_greater_equal(landed / 2)


func test_last_washing_keeps_a_recorded_ally_at_one_hp_and_strikes_the_name() -> void:
	for with_perk: bool in [false, true]:
		var controller := _battle([_member_actor("Haeren", ["river-mother-last-washing"] if with_perk else []), _member_actor("", [])])
		var mother := controller.allies[0]
		var ally := controller.allies[1]
		var enemy := controller.enemies[0]
		var ledger := mother.class_resource as HaerenNameLedger
		ledger.on_command(&"record_name", ally.combat_id)
		var breath_before := ledger.pending_breath_refunds
		controller._apply_resolution_writes(enemy, ally, {"writes": [controller._materialize_write({"kind": "hp", "amount": 500}, ally)]}, false, &"strike")
		if not with_perk:
			assert_int(ally.hp).is_equal(0)
			continue
		assert_int(ally.hp).is_equal(1)
		assert_bool(String(ally.combat_id) in ledger.recorded_actor_ids).is_false()
		assert_bool(String(ally.combat_id) in ledger.struck_actor_ids).is_true()
		assert_float(ledger.pending_breath_refunds).override_failure_message("a struck name pays no Breath").is_equal(breath_before)
		assert_str(str(ledger.query_command(&"record_name", ally.combat_id).blocked_by)).is_equal("class_resource_struck")
		# Once per name: the next fall is a fall.
		controller._apply_resolution_writes(enemy, ally, {"writes": [controller._materialize_write({"kind": "hp", "amount": 5}, ally)]}, false, &"strike")
		assert_int(ally.hp).is_equal(0)
		var restored := ClassResourceRegistry.from_dict(ledger.to_dict()) as HaerenNameLedger
		assert_array(restored.struck_actor_ids).contains([String(ally.combat_id)])


func test_debt_of_arms_pays_hp_for_a_scar_and_adds_damage_to_an_allys_next_attack() -> void:
	var bare := _battle([_member_actor("Kero", []), _member_actor("", [])])
	assert_str(str(bare.query_action(bare.action_by_id(&"debt-of-arms"), bare.allies[1]).get("blocked_by", ""))).is_equal("perk_missing")

	var controller := _battle([_member_actor("Kero", ["ironbrand-debt-of-arms"]), _member_actor("", [])])
	var kero := controller.allies[0]
	var companion := controller.allies[1]
	var enemy := controller.enemies[0]
	var scars := kero.class_resource as IronbrandScars
	var scars_before := scars.scars
	assert_bool(controller.submit_action(&"debt-of-arms", companion).allowed).is_true()
	assert_str(String(scars.debt_target_id)).is_equal(String(companion.combat_id))
	_advance_to_turn(controller, companion)
	assert_int(kero.hp).override_failure_message("the debt is paid in HP").is_less_equal(100 - IronbrandScars.DEBT_HP)
	assert_int(scars.scars).override_failure_message("the loss banks a Scar").is_greater(scars_before)
	var forecast := controller.forecast_action(controller.action_by_id(&"strike"), enemy)
	assert_bool(_has_step(forecast.get("resolution", {}), "bonus_damage", 6.0)).is_true()
	var result := controller.submit_action(&"strike", enemy)
	assert_bool(result.allowed).is_true()
	assert_str(String(scars.debt_target_id)).override_failure_message("the debt is settled").is_empty()


func test_debt_of_arms_never_drops_the_payer_below_one_hp() -> void:
	var controller := _battle([_member_actor("Kero", ["ironbrand-debt-of-arms"])])
	var kero := controller.allies[0]
	var scars := kero.class_resource as IronbrandScars
	kero.hp = 1
	assert_str(str(scars.query_command(&"debt_of_arms", kero.combat_id).blocked_by)).is_equal("class_resource_empty")
	kero.hp = 4
	scars.on_command(&"debt_of_arms", kero.combat_id)
	assert_int(int(controller.deferred_entries()[-1]["effect"]["writes"][0]["amount"])).is_equal(3)
	# Her own debt: the owner's channel carries the bonus too.
	assert_int(int(scars.on_cast_forecast({}).get("bonus_damage", 0))).is_equal(6)


func test_tuned_thunder_chains_a_second_draw_on_the_top_row() -> void:
	var plain := _spell_battle("Ofshutje")
	var tuned := _spell_battle("Ofshutje")
	var storm := tuned.allies[0].class_resource as OfshutjeAttribution
	storm.apply_perks(PackedStringArray(["stormbearer-tuned-thunder"]))
	var chained := false
	for seed_value in 200:
		var options := {"ability_id": "perk-note", "seed": seed_value}
		var base := _draw(plain, options)
		if base.is_empty():
			continue
		var thunder := _draw(tuned, options)
		if not thunder.has("chained_row_id"):
			assert_str(str(thunder["row_id"])).is_equal(str(base["row_id"]))
			continue
		chained = true
		var forecast: Dictionary = tuned.forecast_action(tuned.action_by_id(&"cast-seam"), tuned.enemies[0], options).resolution
		var plain_forecast: Dictionary = plain.forecast_action(plain.action_by_id(&"cast-seam"), plain.enemies[0], options).resolution
		assert_int(int(forecast.damage)).is_greater(int(plain_forecast.damage))
		var result := tuned.submit_action(&"cast-seam", tuned.enemies[0], options)
		assert_dict(result.resolution).override_failure_message("forecast equals commit").is_equal(forecast)
		break
	assert_bool(chained).override_failure_message("no seed drew the top row").is_true()


func test_sequenced_verdict_files_eighteen_in_three_rounds_once_and_can_be_jammed() -> void:
	var bare := _battle([_member_actor("Pazzah", [])])
	assert_str(str(bare.query_action(bare.action_by_id(&"sequenced-verdict"), bare.enemies[0]).get("blocked_by", ""))).is_equal("perk_missing")

	var controller := _battle([_member_actor("Pazzah", ["oathclock-sequenced-verdict"])])
	var ledger := controller.allies[0].class_resource as PazzahLedger
	var enemy := controller.enemies[0]
	var round_now := controller.round_number
	assert_bool(controller.submit_action(&"sequenced-verdict", enemy).allowed).is_true()
	var entry: Dictionary = controller.deferred_entries()[0]
	assert_int(int(entry["due_round"])).is_equal(round_now + 3)
	assert_int(int(entry["effect"]["writes"][0]["amount"])).is_equal(18)
	assert_int(ledger.entries.size()).override_failure_message("it takes a Ledger slot").is_equal(1)
	assert_str(str(ledger.query_command(&"sequenced_verdict", enemy.combat_id, {"amount": 18, "delay_rounds": 3}).blocked_by)).is_equal("class_resource_spent")
	assert_bool(bool(controller.request_cancel(enemy.combat_id, controller.allies[0].combat_id, &"deferred").allowed)).is_true()
	assert_array(controller.deferred_entries()).is_empty()


func test_the_unspoken_term_binds_a_cast_and_cashes_a_contract_in() -> void:
	var bare := _battle([_member_actor("Izhakel", [])])
	assert_str(str(bare.query_action(bare.action_by_id(&"bind-cast"), bare.enemies[0]).get("blocked_by", ""))).is_equal("perk_missing")

	var controller := _battle([_member_actor("Izhakel", ["threadwalker-the-unspoken-term"])])
	var threads := controller.allies[0].class_resource as IzhakelThreads
	var enemy := controller.enemies[0]
	assert_str(str(threads.query_command(&"cash_in", enemy.combat_id).blocked_by)).is_equal("no_contract")
	threads.execute_command(&"bind_cast", enemy.combat_id, {"amount": 6})
	assert_int(threads.contract_count(enemy.combat_id, IzhakelThreads.KIND_HOSTILITY_CAST)).is_equal(1)
	assert_int(int(threads.threads[0]["condition"]["verb"])).is_equal(CombatAction.Verb.CAST)
	threads.execute_command(&"bind_hostility", enemy.combat_id, {"amount": 4})
	assert_bool(bool(threads.query_command(&"cash_in", enemy.combat_id).allowed)).is_true()
	threads.execute_command(&"cash_in", enemy.combat_id)
	assert_int(threads.threads.size()).override_failure_message("the slot is freed").is_equal(1)
	var fired: Dictionary = controller.deferred_entries()[-1]
	assert_int(int(fired["due_round"])).is_equal(controller.round_number)
	assert_int(int(fired["effect"]["writes"][0]["amount"])).is_equal(6)


func test_kept_focus_and_carried_lesson_cross_into_the_next_battle() -> void:
	var lens := _member_actor("Stuid", ["lensbearer-kept-focus"])
	var flame := _member_actor("Vicoar", ["flamebinder-carried-lesson"])
	var plain := _member_actor("Vicoar", [])
	var first := _battle([lens, flame, plain])
	(flame.class_resource as VicoarInstructiveFailure).tokens = 2
	(plain.class_resource as VicoarInstructiveFailure).tokens = 2
	first._finish(CombatController.ResultState.VICTORY, &"test")
	assert_dict(lens.source_member.carried_resource).is_equal({"clarity": 1})
	assert_dict(flame.source_member.carried_resource).is_equal({"tokens": 1})
	assert_dict(plain.source_member.carried_resource).is_empty()

	var second := _battle([_again(lens), _again(flame)])
	var clarity := second.allies[0].class_resource as StuidClarity
	assert_int(clarity.clarity).override_failure_message("held above the cap").is_equal(StuidClarity.MAX_CLARITY + 1)
	assert_int((second.allies[1].class_resource as VicoarInstructiveFailure).tokens).is_equal(1)
	assert_dict(lens.source_member.carried_resource).override_failure_message("a carry is spent on arrival").is_empty()
	var restored := ClassResourceRegistry.from_dict(clarity.to_dict()) as StuidClarity
	assert_int(restored.clarity).is_equal(StuidClarity.MAX_CLARITY + 1)


func _again(actor: BattleActor) -> BattleActor:
	var fresh := _actor(actor.display_name)
	fresh.source_member = actor.source_member
	return fresh


func _has_step(resolution: Dictionary, id: String, value: float) -> bool:
	for step: Dictionary in resolution.get("breakdown", []):
		if str(step.get("id", "")) == id and is_equal_approx(float(step.get("value", 0.0)), value):
			return true
	return false


func _draw(controller: CombatController, options: Dictionary) -> Dictionary:
	var forecast := controller.forecast_action(controller.action_by_id(&"cast-seam"), controller.enemies[0], options)
	if not bool(forecast.get("allowed", false)):
		return {}
	return forecast.get("resolution", {}).get("hidden_draw", {})


func _advance_to_turn(controller: CombatController, actor: BattleActor) -> void:
	for step in 40:
		if controller.state == CombatController.State.ALLY_TURN and controller.allies[controller.active_ally_index] == actor:
			return
		if not controller.submit_action(&"guard").allowed:
			controller.end_turn()


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
