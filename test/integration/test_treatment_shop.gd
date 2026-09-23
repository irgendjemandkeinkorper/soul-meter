extends GdUnitTestSuite
## Task 10B: healer treatment through the real shop screen, plus the recovery loop
## (injury in a real battle → flee → provider → cure → save/reload).

const ShopScene := preload("res://ui/screens/shop.tscn")
const BattleScript := preload("res://globals/battle.gd")
const HERBALIST := "root-and-reed"
const SHRINE := "held-flame-shrine"

var _state_before: Dictionary
var _reputation_before: Dictionary


func before_test() -> void:
	_state_before = GameState.to_dict().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	Reputation.from_dict({})
	GameState.flags.clear()
	GameState.party.clear()
	var vex := PartyMember.new()
	vex.id = "vex"
	vex.display_name = "Vex"
	vex.hp = 20
	vex.max_hp = 20
	GameState.party.append(vex)
	GameState.set_gp(20)
	GameState.soul_meter = 50.0
	Battle.controller = null
	Battle.ended = true


func after_test() -> void:
	Reputation.from_dict(_reputation_before)
	GameState.from_dict(_state_before)


func test_player_sees_the_exact_quote_treats_and_regains_the_voice() -> void:
	_wound(GameState.party[0], "throat", "k1")
	var shop := await _shop(HERBALIST)
	var button := shop.find_child("Treat_vex_throat_herbalist-service", true, false) as Button
	assert_object(button).is_not_null()
	assert_str(button.text).is_equal("TREAT  ·  20 SILVER")
	assert_bool(button.disabled).is_false()
	var notice: PanelContainer = shop.get("_treatment_notice")
	assert_bool(notice.visible).is_false()
	assert_str((shop.find_child("Treatment_vex_throat_herbalist-service", true, false).get_child(1) as Label).text).contains("LIFTS VOICE")
	assert_bool(CombatInjury.voice_block(BattleActor.from_party_member(GameState.party[0], 0)).is_empty()).is_false()
	button.pressed.emit()
	await get_tree().process_frame
	assert_int(GameState.gp).is_equal(0)
	assert_dict(GameState.party[0].injuries).is_empty()
	assert_float(GameState.soul_meter).is_equal_approx(50.0, 0.001)
	assert_str((shop.get("_status_label") as Label).text).is_equal("TREATED  ·  VEX THROAT  ·  -20 SILVER")
	assert_bool(CombatInjury.voice_block(BattleActor.from_party_member(GameState.party[0], 0)).is_empty()).is_true()
	assert_object(shop.find_child("Treat_vex_throat_herbalist-service", true, false)).is_null()
	assert_bool(notice.visible).is_true()
	assert_str((notice.get_node("Column/Top/Heading") as Label).text).is_equal("VEX — THROAT INJURY CLEARED")
	assert_str((notice.get_node("Column/Penalties") as Label).text).is_equal("Removed from this injury: voice block.")
	assert_str((notice.get_node("Column/Payment") as Label).text).is_equal("Paid 20 silver")
	assert_bool((notice.get_node("Column/Top/Dismiss") as Button).has_focus()).is_true()
	shop.call("_render_catalog")
	assert_bool(notice.visible).is_true()
	shop.configure_vendor(SHRINE)
	assert_bool(notice.visible).is_false()


func test_no_cash_and_hostile_standing_show_why_and_the_shrine_takes_one_wound() -> void:
	_wound(GameState.party[0], "throat", "k1")
	_wound(GameState.party[0], "arm", "k2")
	GameState.set_gp(5)
	var shop := await _shop(HERBALIST)
	var button := shop.find_child("Treat_vex_throat_herbalist-service", true, false) as Button
	assert_bool(button.disabled).is_true()
	var box: Node = shop.find_child("Treatment_vex_throat_herbalist-service", true, false)
	assert_str((box.get_child(2) as Label).text).contains("NEED 20 GP")
	# A hostile standing locks the herbalist and names the alternative.
	Reputation.record("player", "iron-companies", -100.0, "test", "field")
	shop.configure_vendor(HERBALIST)
	box = shop.find_child("Treatment_vex_throat_herbalist-service", true, false)
	assert_bool((box.get_child(0).get_child(1) as Button).disabled).is_true()
	assert_str((box.get_child(2) as Label).text).contains("SHRINE OF THE HELD FLAME")
	# The shrine ignores standing and purse, once.
	shop.configure_vendor(SHRINE)
	var succor := shop.find_child("Treat_vex_throat_shrine-succor", true, false) as Button
	assert_str(succor.text).is_equal("TREAT  ·  0 SILVER")
	assert_bool(succor.disabled).is_false()
	succor.pressed.emit()
	await get_tree().process_frame
	assert_int(GameState.gp).is_equal(5)
	assert_array(GameState.party[0].injuries.keys()).is_equal(["arm"])
	assert_bool(GameState.flag_is_true("dom_shrine_succor_spent")).is_true()
	var notice: PanelContainer = shop.get("_treatment_notice")
	assert_bool(notice.visible).is_true()
	assert_str((notice.get_node("Column/Payment") as Label).text).is_equal("No silver spent")
	var second := shop.find_child("Treat_vex_arm_shrine-succor", true, false) as Button
	assert_bool(second.disabled).is_true()
	assert_str((shop.find_child("Treatment_vex_arm_shrine-succor", true, false).get_child(2) as Label).text).contains("ALREADY BEEN GIVEN")
	# Reload keeps the spent succor and the remaining wound.
	GameState.from_dict(GameState.to_dict())
	assert_bool(GameState.flag_is_true("dom_shrine_succor_spent")).is_true()
	assert_array(GameState.party[0].injuries.keys()).is_equal(["arm"])


func test_treatment_is_refused_while_a_battle_is_live_and_a_stale_quote_never_charges() -> void:
	_wound(GameState.party[0], "throat", "k1")
	Battle.controller = CombatController.new()
	Battle.ended = false
	var shop := await _shop(HERBALIST)
	var button := shop.find_child("Treat_vex_throat_herbalist-service", true, false) as Button
	assert_bool(button.disabled).is_true()
	Battle.controller = null
	Battle.ended = true
	shop.configure_vendor(HERBALIST)
	# The wound is refreshed between quote and press: the old quote must not charge.
	(GameState.party[0].injuries["throat"] as Dictionary)["applications"] = 2
	button = shop.find_child("Treat_vex_throat_herbalist-service", true, false) as Button
	button.pressed.emit()
	await get_tree().process_frame
	assert_int(GameState.gp).is_equal(20)
	assert_bool(GameState.party[0].injuries.has("throat")).is_true()
	assert_str((shop.get("_status_label") as Label).text).contains("INJURY CHANGED")
	assert_bool((shop.get("_treatment_notice") as PanelContainer).visible).is_false()


func test_each_cure_reports_its_own_removed_penalties_and_keeps_other_wounds() -> void:
	var patient: PartyMember = GameState.party[0]
	_wound(patient, "arm", "arm")
	_wound(patient, "leg", "leg")
	_wound(patient, "head", "head")
	patient.injuries["leg"]["effects"] = {"move_cost_percent": 50}
	patient.injuries["head"]["effects"] = {"sight_accuracy_pp": -20, "vocal_accuracy_pp": -15}
	GameState.set_gp(60)
	var shop := await _shop(HERBALIST)
	var expected := {
		"arm": "attack accuracy -10 percentage points",
		"leg": "movement cost +50%",
		"head": "vocal accuracy -15 percentage points; ranged / aimed accuracy -20 percentage points",
	}
	var remaining := 3
	for location: String in expected:
		var button := shop.find_child("Treat_vex_%s_herbalist-service" % location, true, false) as Button
		button.pressed.emit()
		await get_tree().process_frame
		remaining -= 1
		assert_int(patient.injuries.size()).is_equal(remaining)
		assert_int(GameState.gp).is_equal(remaining * 20)
		var notice: PanelContainer = shop.get("_treatment_notice")
		assert_bool(notice.visible).is_true()
		assert_str((notice.get_node("Column/Top/Heading") as Label).text).contains(location.to_upper() + " INJURY CLEARED")
		assert_str((notice.get_node("Column/Penalties") as Label).text).is_equal("Removed from this injury: %s." % expected[location])
	# A refused follow-up must not leave the previous success visible.
	shop.call("_treat", {"card_id": "herbalist-service", "patient_id": "vex", "instance_id": "missing", "provider_id": HERBALIST}, {"gp": 20})
	assert_bool((shop.get("_treatment_notice") as PanelContainer).visible).is_false()
	assert_int(GameState.gp).is_equal(0)


func test_recovery_loop_from_a_real_battle_to_a_saved_cure() -> void:
	var battle := auto_free(BattleScript.new()) as Node
	add_child(battle)
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	battle.combat_event.connect(interface.consume_event)
	var enemy := BattleActor.new()
	enemy.display_name = "Wight"
	enemy.hp = 40
	enemy.max_hp = 40
	battle.start(enemy)
	var ally: BattleActor = battle.allies[0]
	CombatInjury.apply(ally, {"id": "throat-crushed", "location_id": "throat", "severity": "serious",
		"effects": {"voice_blocked": true}}, "loop|1|a|x", 1)
	var injured_snapshot := CombatEvent.new()
	injured_snapshot.data = {"snapshot": battle.controller.snapshot()}
	interface.consume_event(injured_snapshot)
	assert_object(interface.active_unit_plate.injury_button("throat")).is_not_null()
	interface.active_unit_plate.injury_button("throat").pressed.emit()
	assert_bool(interface.injury_inspector.visible).is_true()
	battle.flee()
	assert_bool(GameState.party[0].injuries.has("throat")).is_true()
	GameState.from_dict(GameState.to_dict())
	assert_bool(GameState.party[0].injuries.has("throat")).is_true()
	var shop := await _shop(HERBALIST)
	(shop.find_child("Treat_vex_throat_herbalist-service", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	assert_dict(GameState.party[0].injuries).is_empty()
	assert_int(GameState.gp).is_equal(0)
	GameState.from_dict(GameState.to_dict())
	assert_dict(GameState.party[0].injuries).is_empty()
	# A new combat publishes the cured party state to the existing HUD too.
	battle.start(enemy)
	assert_object(interface.active_unit_plate.injury_button("throat")).is_null()
	assert_bool(interface.injury_inspector.visible).is_false()
	assert_bool(CombatInjury.voice_block(battle.allies[0]).is_empty()).is_true()
	battle.flee()


func _shop(vendor_id: String) -> ShopScreen:
	var shop := ShopScene.instantiate() as ShopScreen
	add_child(shop)
	auto_free(shop)
	await get_tree().process_frame
	shop.configure_vendor(vendor_id)
	return shop


static func _wound(member: PartyMember, location: String, key: String) -> void:
	var injury_id := "throat-crushed" if location == "throat" else "arm-severed"
	member.injuries[location] = {
		"injury_id": injury_id, "instance_id": "%s@%s|%s" % [injury_id, location, key],
		"location_id": location, "severity": "serious", "applications": 1,
		"effects": {"voice_blocked": true} if location == "throat" else {"attack_accuracy_pp": -10},
		"recovery": "untreated",
	}
