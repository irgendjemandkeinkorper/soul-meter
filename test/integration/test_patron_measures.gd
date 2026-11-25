extends GdUnitTestSuite
## Calling and measures S1 (docs/design/calling-and-measures-2026-11-25.md §4): each class's
## patron measure strengthens its loop above 3 and changes nothing at or below it, so the B11
## numbers (docs/class-resources-numbers.md) still hold for a build that did not invest.

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


func test_every_class_names_a_measure_that_is_not_doctrine() -> void:
	for row: Dictionary in ClassCatalog.ALL:
		var measure := str(row.get("measure", ""))
		assert_bool(measure in DramgidSchema.ATTRIBUTE_IDS).override_failure_message(
			"%s names an unknown measure '%s'" % [row["id"], measure]).is_true()
		assert_str(measure).override_failure_message(
			"Doctrine has no class loop to strengthen (canon: Karma only)").is_not_equal("doctrine")
		assert_str(ClassCatalog.patron_measure(str(row["id"]))).is_equal(measure)


func test_the_bonus_is_nothing_through_three_then_one_a_point() -> void:
	var expected := [0, 0, 0, 0, 1, 2]
	for value in expected.size():
		assert_int(ClassCatalog.measure_bonus(value)).is_equal(expected[value])
	assert_int(ClassCatalog.measure_bonus(9)).override_failure_message(
		"a story boost past the creation cap must not run away").is_equal(2)


func test_each_loop_keeps_its_ratified_number_at_three_and_grows_at_five() -> void:
	# [patron, reader returning the loop's number] — read at 0, 3, 4 and 5.
	var cases := {
		"Kero": func(r: ClassResource) -> float: return (r as IronbrandScars).max_scars(),
		"Stuid": func(r: ClassResource) -> float: return (r as StuidClarity).clarity,
		"Vhorr": func(r: ClassResource) -> float: return (r as VhorrHunger).max_hunger(),
		"Vicoar": func(r: ClassResource) -> float: return (r as VicoarInstructiveFailure).max_tokens(),
		"Haeren": func(r: ClassResource) -> float: return (r as HaerenNameLedger).breath_refund(),
		"Maiiam": func(r: ClassResource) -> float: return (r as MaiiamBalance).unbalanced_multiplier(),
		"Ofshütje": func(r: ClassResource) -> float: return float(((r as OfshutjeAttribution).effect_rows()[0] as Dictionary)["bonus_damage"]),
		"Pazzah": func(r: ClassResource) -> float: return (r as PazzahLedger).sentence_damage(6),
		"Izhakel": func(r: ClassResource) -> float: return (r as IzhakelThreads).hostility_damage(6),
		"Fickah": func(r: ClassResource) -> float: return (r as FickahRuleBreaker).jam_delay(),
	}
	var ratified := {
		"Kero": 3.0, "Stuid": 3.0, "Vhorr": 3.0, "Vicoar": 3.0, "Haeren": 3.0, "Maiiam": 1.25,
		"Ofshütje": 1.0, "Pazzah": 6.0, "Izhakel": 6.0, "Fickah": 0.0,
	}
	var at_five := {
		"Kero": 5.0, "Stuid": 5.0, "Vhorr": 5.0, "Vicoar": 5.0, "Haeren": 5.0, "Maiiam": 1.45,
		"Ofshütje": 3.0, "Pazzah": 10.0, "Izhakel": 10.0, "Fickah": 20.0,
	}
	for patron: String in cases:
		var reader: Callable = cases[patron]
		for value: int in [0, 2, 3]:
			var resource := ClassResourceRegistry.for_patron(patron)
			resource.apply_measure(value)
			assert_float(float(reader.call(resource))).override_failure_message(
				"%s at measure %d must play the B11 number" % [patron, value]).is_equal_approx(ratified[patron], 0.001)
		var four := ClassResourceRegistry.for_patron(patron)
		four.apply_measure(4)
		var five := ClassResourceRegistry.for_patron(patron)
		five.apply_measure(5)
		var gain := float(reader.call(four)) - float(ratified[patron])
		assert_float(gain).override_failure_message("%s gains at 4" % patron).is_greater(0.0)
		assert_float(float(reader.call(five))).override_failure_message(
			"%s at 5" % patron).is_equal_approx(at_five[patron], 0.001)
		assert_str(five.measure_readout()).override_failure_message(
			"%s says what its measure buys" % patron).is_not_empty()


func test_perks_stack_on_the_measure() -> void:
	var scars := ClassResourceRegistry.for_patron("Kero") as IronbrandScars
	scars.apply_measure(5)
	scars.apply_perks(PackedStringArray(["ironbrand-thick-hide"]))
	assert_int(scars.max_scars()).is_equal(IronbrandScars.MAX_SCARS + 1 + 2)


func test_the_storm_table_keeps_its_order_when_it_grows() -> void:
	var storm := ClassResourceRegistry.for_patron("Ofshütje") as OfshutjeAttribution
	storm.apply_measure(5)
	var rows := storm.effect_rows()
	for index in rows.size():
		assert_int(int((rows[index] as Dictionary)["bonus_damage"])).is_equal(
			int((OfshutjeAttribution.EFFECT_TABLE[index] as Dictionary)["bonus_damage"]) + 2)
		assert_str(str((rows[index] as Dictionary)["id"])).is_equal(
			str((OfshutjeAttribution.EFFECT_TABLE[index] as Dictionary)["id"]))


func test_the_controller_reads_the_measure_off_the_member() -> void:
	var invested := _member_actor("lensbearer", {"reason": 5})
	var companion := _member_actor("lensbearer", {})
	var controller := _battle([invested, companion])
	assert_int((controller.allies[0].class_resource as StuidClarity).clarity).is_equal(5)
	assert_int((controller.allies[1].class_resource as StuidClarity).clarity).override_failure_message(
		"an authored companion has no attribute map and plays the ratified number").is_equal(3)


func test_a_restore_without_the_measure_reads_it_off_the_member() -> void:
	var controller := _battle([_member_actor("ironbrand", {"grit": 5})])
	var owner := controller.allies[0]
	var saved: Dictionary = (owner.class_resource as IronbrandScars).to_dict()
	assert_int(int(saved["measure_value"])).is_equal(5)
	saved.erase("measure_value")
	controller.restore_class_resources({String(owner.combat_id): saved})
	assert_int((owner.class_resource as IronbrandScars).max_scars()).is_equal(5)


func test_a_filed_sentence_carries_the_reason_share_and_the_forecast_says_so() -> void:
	var controller := _battle([_member_actor("oathclock", {"reason": 5})])
	var enemy := controller.enemies[0]
	var hp := enemy.hp
	var forecast := controller.forecast_action(controller.action_by_id(&"file-sentence"), enemy)
	assert_str(str(forecast.get("description", ""))).contains("deals 10")
	assert_bool(controller.submit_action(&"file-sentence", enemy).allowed).is_true()
	_advance_rounds(controller, 4)
	assert_int(enemy.hp).is_equal(hp - 10)


func test_a_bound_hostility_pays_the_decorum_share() -> void:
	var controller := _battle([_member_actor("threadwalker", {"decorum": 4})])
	var enemy := controller.enemies[0]
	assert_bool(controller.submit_action(&"bind-hostility", enemy).allowed).is_true()
	var hp := enemy.hp
	_advance_rounds(controller, 3)
	assert_int(enemy.hp).is_equal(hp - 8)


func test_a_name_pays_the_decorum_share_at_victory() -> void:
	var controller := _battle([_member_actor("river-mother", {"decorum": 5})])
	var owner := controller.allies[0]
	owner.breath = 0
	assert_bool(controller.submit_action(&"record-name", owner).allowed).is_true()
	var ledger := owner.class_resource as HaerenNameLedger
	ledger.on_battle_end(true)
	assert_float(ledger.pending_breath_refunds).is_equal_approx(5.0, 0.001)


func _advance_rounds(controller: CombatController, count: int) -> void:
	var goal := controller.round_number + count
	for step in 80:
		if controller.round_number >= goal or controller.state == CombatController.State.FINISHED:
			break
		assert_bool(controller.submit_action(&"guard").allowed).is_true()
	assert_int(controller.round_number).is_greater_equal(goal)


func _battle(party: Array[BattleActor]) -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), BattlefieldModel.create_default(rules), rules)
	controller.start(party, [_actor("Target")], &"patron-measures")
	_controllers.append(controller)
	return controller


func _member_actor(class_id: String, attributes: Dictionary) -> BattleActor:
	var actor := _actor("%s tester" % class_id)
	actor.source_member = PartyMember.new()
	actor.source_member.id = "measure-%s-%d" % [class_id, attributes.size()]
	actor.source_member.class_id = class_id
	actor.source_member.patron = ClassCatalog.patron_for(class_id)
	actor.source_member.attributes = attributes.duplicate()
	return actor


func _actor(display_name: String) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = display_name
	actor.hp = 100
	actor.max_hp = 100
	actor.attack = 5
	actor.defense = 1
	return actor
