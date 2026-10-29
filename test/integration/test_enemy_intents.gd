extends GdUnitTestSuite
## #285 slice 5 in a live controller: enemy intents, Sacred Clarity and Read Aloud (rulings
## 2026-10-29, docs/enemy-intents-draft.md).

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


func test_an_unread_enemy_plans_the_chapter_one_strike_and_shows_nothing() -> void:
	var controller := _battle([_member_actor("Stuid", []), _member_actor("", [])])
	var enemy := controller.enemies[0]
	var plan := controller.plan_enemy_turn(enemy)
	assert_str(str(plan["kind"])).is_equal("strike")
	assert_str(str(plan["target_id"])).is_equal(String(controller.allies[0].combat_id))
	assert_dict(controller.shown_intent(enemy)).is_empty()
	assert_dict(controller.snapshot()["enemies"][0]["intent"]).is_empty()


func test_sacred_clarity_needs_the_perk_and_a_clarity() -> void:
	var bare := _battle([_member_actor("Stuid", [])])
	var refused := bare.query_action(bare.action_by_id(&"sacred-clarity"), bare.enemies[0])
	assert_str(str(refused.get("blocked_by", ""))).is_equal("perk_missing")

	var controller := _battle([_member_actor("Stuid", ["lensbearer-sacred-clarity"])])
	var clarity := controller.allies[0].class_resource as StuidClarity
	clarity.clarity = 0
	var empty := controller.query_action(controller.action_by_id(&"sacred-clarity"), controller.enemies[0])
	assert_str(str(empty.get("blocked_by", ""))).is_equal("class_resource_empty")


func test_a_read_spends_one_clarity_and_shows_target_aim_and_odds() -> void:
	var controller := _battle([_member_actor("Stuid", ["lensbearer-sacred-clarity"])])
	var stuid := controller.allies[0]
	var enemy := controller.enemies[0]
	var clarity := stuid.class_resource as StuidClarity
	assert_bool(controller.submit_action(&"sacred-clarity", enemy).allowed).is_true()
	assert_int(clarity.clarity).is_equal(StuidClarity.MAX_CLARITY - 1)
	assert_bool(clarity.reveal_armed).override_failure_message("a read never arms the cast reveal").is_false()
	assert_bool(controller.is_intent_locked(enemy.combat_id)).is_true()

	var shown: Dictionary = controller.snapshot()["enemies"][0]["intent"]
	assert_str(str(shown["target_name"])).is_equal(stuid.display_name)
	assert_str(str(shown["kind"])).is_equal("strike")
	assert_bool(shown.has("hit_chance") and shown.has("damage_on_hit")).is_true()
	var line := CTTimelineRegion.intent_line(shown)
	assert_str(line).starts_with("→ %s" % stuid.display_name)
	assert_str(line).contains("%d%%" % int(shown["hit_chance"]))

	var again := controller.query_action(controller.action_by_id(&"sacred-clarity"), enemy)
	assert_str(str(again.get("blocked_by", ""))).is_equal("intent_read")


func test_a_read_enemy_keeps_its_target_when_another_ally_is_first_in_line() -> void:
	var controller := _battle([_member_actor("Stuid", ["lensbearer-sacred-clarity"]), _member_actor("", [])])
	var stuid := controller.allies[0]
	var enemy := controller.enemies[0]
	assert_bool(controller.lock_enemy_intent(enemy.combat_id, stuid.combat_id).allowed).is_true()
	controller.allies.reverse()
	assert_str(str(controller.plan_enemy_turn(enemy)["target_id"])).is_equal(String(stuid.combat_id))
	controller.allies.reverse()


func test_a_read_enemy_replans_when_its_target_falls() -> void:
	var controller := _battle([_member_actor("Stuid", ["lensbearer-sacred-clarity"]), _member_actor("", [])])
	var stuid := controller.allies[0]
	var companion := controller.allies[1]
	var enemy := controller.enemies[0]
	controller.lock_enemy_intent(enemy.combat_id, stuid.combat_id)
	stuid.hp = 0
	assert_str(str(controller.plan_enemy_turn(enemy)["target_id"])).is_equal(String(companion.combat_id))
	assert_str(str(controller.shown_intent(enemy)["target_name"])).is_equal(companion.display_name)


func test_the_enemy_acts_on_the_read_and_the_lock_is_spent() -> void:
	var controller := _battle([_member_actor("Stuid", ["lensbearer-sacred-clarity"]), _member_actor("", [])])
	var stuid := controller.allies[0]
	var enemy := controller.enemies[0]
	var struck: Array[StringName] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void:
		if event.type == &"action_resolved" and event.actor_id == enemy.combat_id:
			struck.append(event.target_id)
	)
	assert_bool(controller.submit_action(&"sacred-clarity", enemy).allowed).is_true()
	for step in 20:
		if not struck.is_empty():
			break
		if not controller.submit_action(&"guard").allowed:
			controller.end_turn()
	assert_array(struck).is_not_empty()
	assert_str(String(struck[0])).is_equal(String(stuid.combat_id))
	assert_bool(controller.is_intent_locked(enemy.combat_id)).override_failure_message("one turn only").is_false()


func test_read_aloud_shares_an_armed_reveal_with_allies_spells_for_that_round_only() -> void:
	var controller := _battle([_member_actor("Stuid", ["lensbearer-read-aloud"]), _member_actor("", [])])
	var clarity := controller.allies[0].class_resource as StuidClarity
	var companion := controller.allies[1]
	var spell := {"ability": {"is_spell": true}}
	assert_dict(clarity.on_ally_cast_forecast(companion.combat_id, spell)).is_empty()
	assert_bool(clarity.spend_clarity()).is_true()
	assert_dict(clarity.on_ally_cast_forecast(companion.combat_id, spell)).is_equal({"reveal": true})
	assert_dict(clarity.on_ally_cast_forecast(companion.combat_id, {"ability": {"is_spell": false}})).is_empty()
	assert_bool(clarity.reveal_armed).override_failure_message("an ally reads it without spending it").is_true()
	var restored := ClassResourceRegistry.from_dict(clarity.to_dict()) as StuidClarity
	assert_int(restored.armed_round).is_equal(clarity.armed_round)
	controller.round_number += 1
	assert_dict(clarity.on_ally_cast_forecast(companion.combat_id, spell)).is_empty()
	assert_bool(clarity.reveal_armed).override_failure_message("still hers until she casts").is_true()

	var plain := _battle([_member_actor("Stuid", []), _member_actor("", [])])
	var plain_clarity := plain.allies[0].class_resource as StuidClarity
	plain_clarity.spend_clarity()
	assert_dict(plain_clarity.on_ally_cast_forecast(plain.allies[1].combat_id, spell)).is_empty()


func _battle(party: Array[BattleActor], use_charge_time: bool = false) -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = use_charge_time
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), BattlefieldModel.create_default(rules), rules)
	controller.start(party, [_actor("Target")], &"enemy-intents")
	_controllers.append(controller)
	return controller


func _member_actor(patron: String, perk_ids: Array) -> BattleActor:
	var actor := _actor("%s tester" % patron if not patron.is_empty() else "Companion")
	actor.source_member = PartyMember.new()
	actor.source_member.id = "intent-%s" % (patron.to_lower() if not patron.is_empty() else "companion")
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
