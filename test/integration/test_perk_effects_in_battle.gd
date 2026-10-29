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


func _battle(party: Array[BattleActor]) -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
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
