extends GdUnitTestSuite
## Task 10A: atomic treatment of one serious injury. Fixture constants: 20 GP service, one
## supply unit. `state` is an isolated GameState instance, never the autoload.

const GameStateScript := preload("res://globals/game_state.gd")
const SUPPLY := "materials/loamroot_sprig"

var state: Node
var patient: PartyMember
var medic: PartyMember


func before_test() -> void:
	state = auto_free(GameStateScript.new())
	state.inventory = auto_free(Inventory.new())
	state.inventory.protoset = load("res://data/generated/gloot_prototree.json")
	patient = PartyMember.new()
	patient.id = "vex"
	patient.display_name = "Vex"
	patient.hp = 12
	medic = PartyMember.new()
	medic.id = "serai"
	medic.display_name = "Serai"
	medic.hp = 9
	medic.skill_tiers = {"mending": "trained"}
	state.party.clear()
	state.party.append(patient)
	state.party.append(medic)
	state.set_gp(20)
	state.soul_meter = 50.0
	_wound(patient, "throat", "throat-crushed", "k1")


func test_service_quote_is_exact_and_pure_and_commit_pays_and_cures_once() -> void:
	var intent := _intent("service-test")
	var quoted := InjuryTreatment.quote(intent, state, false)
	assert_bool(quoted["allowed"]).override_failure_message(str(quoted)).is_true()
	assert_dict(quoted["cost"]).is_equal({"gp": 20, "supply_item": "", "supply_quantity": 0})
	assert_array(quoted["lifts"]).contains(["voice"])
	assert_int(state.gp).is_equal(20)
	assert_bool(patient.injuries.has("throat")).is_true()
	intent["expected_cost"] = quoted["cost"]
	var notified := [0]
	state.party_changed.connect(func() -> void: notified[0] += 1)
	var result := InjuryTreatment.commit(intent, state, false)
	assert_bool(result["allowed"]).is_true()
	assert_int(state.gp).is_equal(0)
	assert_dict(patient.injuries).is_empty()
	assert_int(patient.hp).is_equal(12)
	assert_float(state.soul_meter).is_equal_approx(50.0, 0.001)
	assert_int(notified[0]).is_equal(1)
	# Duplicate intent: the instance is gone, so nothing is paid again.
	state.set_gp(20)
	var again := InjuryTreatment.commit(intent, state, false)
	assert_str(str(again["blocked_by"])).is_equal("injury_missing")
	assert_int(state.gp).is_equal(20)


func test_stale_quote_cannot_cure_a_replacement_or_worsened_injury() -> void:
	var intent := _intent("service-test")
	# Re-injury at the same location: new instance.
	patient.injuries.erase("throat")
	_wound(patient, "throat", "throat-crushed", "k2")
	assert_str(str(InjuryTreatment.commit(intent, state, false)["blocked_by"])).is_equal("injury_missing")
	assert_int(state.gp).is_equal(20)
	# Same instance refreshed by a second hit: revision moved.
	var fresh := _intent("service-test")
	(patient.injuries["throat"] as Dictionary)["applications"] = 2
	assert_str(str(InjuryTreatment.commit(fresh, state, false)["blocked_by"])).is_equal("injury_changed")
	assert_int(state.gp).is_equal(20)
	assert_bool(patient.injuries.has("throat")).is_true()


func test_refusals_never_pay() -> void:
	var intent := _intent("service-test")
	assert_str(str(InjuryTreatment.quote(intent, state, true)["blocked_by"])).is_equal("combat_active")
	var wrong_provider := intent.duplicate()
	wrong_provider["provider_id"] = "stranger"
	assert_str(str(InjuryTreatment.commit(wrong_provider, state, false)["blocked_by"])).is_equal("invalid_access")
	var stale_price := intent.duplicate()
	stale_price["expected_cost"] = {"gp": 5, "supply_item": "", "supply_quantity": 0}
	var changed := InjuryTreatment.commit(stale_price, state, false)
	assert_str(str(changed["blocked_by"])).is_equal("price_changed")
	assert_int(int(changed["cost"]["gp"])).is_equal(20)
	state.set_gp(19)
	assert_str(str(InjuryTreatment.commit(intent, state, false)["blocked_by"])).is_equal("insufficient_gp")
	assert_int(state.gp).is_equal(19)
	patient.hp = 0
	state.set_gp(20)
	assert_str(str(InjuryTreatment.commit(intent, state, false)["blocked_by"])).is_equal("patient_down")
	patient.hp = 12
	(patient.injuries["throat"] as Dictionary)["severity"] = "minor"
	assert_str(str(InjuryTreatment.commit(intent, state, false)["blocked_by"])).is_equal("not_treatable")
	assert_int(state.gp).is_equal(20)
	assert_bool(patient.injuries.has("throat")).is_true()


func test_field_card_consumes_the_last_supply_unit_and_checks_the_practitioner() -> void:
	var intent := _intent("field-test")
	intent["practitioner_id"] = "serai"
	assert_str(str(InjuryTreatment.quote(intent, state, false)["blocked_by"])).is_equal("insufficient_supply")
	state.inventory.create_and_add_item(SUPPLY)
	var quoted := InjuryTreatment.quote(intent, state, false)
	assert_bool(quoted["allowed"]).override_failure_message(str(quoted)).is_true()
	assert_dict(quoted["cost"]).is_equal({"gp": 0, "supply_item": SUPPLY, "supply_quantity": 1})
	# An unqualified or arm-injured practitioner is refused; a throat injury is irrelevant.
	medic.skill_tiers = {"mending": "untrained"}
	assert_str(str(InjuryTreatment.quote(intent, state, false)["blocked_by"])).is_equal("unqualified")
	medic.skill_tiers = {"mending": "Trained"}
	_wound(medic, "arm", "arm-severed", "m1")
	assert_str(str(InjuryTreatment.quote(intent, state, false)["blocked_by"])).is_equal("practitioner_injured")
	medic.injuries.erase("arm")
	_wound(medic, "throat", "throat-crushed", "m2")
	assert_bool(InjuryTreatment.quote(intent, state, false)["allowed"]).is_true()
	# Self-treatment is allowed when the card's requirements are met.
	var self_intent := _intent("field-test")
	self_intent["practitioner_id"] = "vex"
	assert_bool(InjuryTreatment.quote(self_intent, state, false)["allowed"]).is_false()  # Vex untrained
	var result := InjuryTreatment.commit(intent, state, false)
	assert_bool(result["allowed"]).is_true()
	assert_int(state.item_count(SUPPLY)).is_equal(0)
	assert_int(state.gp).is_equal(20)
	assert_dict(patient.injuries).is_empty()


func test_injected_application_failure_rolls_back_gp_and_supply() -> void:
	var service := _intent("service-test")
	var failed := InjuryTreatment.commit(service, state, false, true)
	assert_str(str(failed["blocked_by"])).is_equal("apply_failed")
	assert_int(state.gp).is_equal(20)
	assert_bool(patient.injuries.has("throat")).is_true()
	var field := _intent("field-test")
	field["practitioner_id"] = "serai"
	state.inventory.create_and_add_item(SUPPLY)
	assert_str(str(InjuryTreatment.commit(field, state, false, true)["blocked_by"])).is_equal("apply_failed")
	assert_int(state.item_count(SUPPLY)).is_equal(1)
	assert_bool(patient.injuries.has("throat")).is_true()


func test_completed_state_round_trips_and_hp_care_leaves_injuries_alone() -> void:
	var intent := _intent("service-test")
	# Untreated: identity survives serialization.
	var reloaded := PartyMember.from_dict(patient.to_dict())
	assert_dict(CombatInjury.record_identity(reloaded.injuries["throat"])).is_equal(CombatInjury.record_identity(patient.injuries["throat"]))
	# Ordinary HP care does not treat.
	patient.hp = patient.max_hp
	assert_bool(patient.injuries.has("throat")).is_true()
	assert_bool(InjuryTreatment.commit(intent, state, false)["allowed"]).is_true()
	var cured := PartyMember.from_dict(patient.to_dict())
	assert_dict(cured.injuries).is_empty()
	state.party.clear()
	state.party.append(cured)
	state.party.append(medic)
	assert_str(str(InjuryTreatment.commit(intent, state, false)["blocked_by"])).is_equal("injury_missing")


func test_a_real_aimed_hit_produces_a_treatable_instance() -> void:
	var controller := _controller_with_serious_throat()
	var target := controller.enemies[0]
	var action := controller.action_by_id(&"aim-test")
	var options := {"aim_location": "throat"}
	var hit_seed := -1
	for seed_value: int in 400:
		controller._sequence = seed_value
		var resolution: Dictionary = controller.forecast_action(action, target, options)["resolution"]
		if bool(resolution["hit"]) and bool(resolution["injury"]["rolled"]):
			hit_seed = seed_value
			break
	assert_int(hit_seed).is_greater_equal(0)
	controller._sequence = hit_seed
	assert_bool(controller.submit_action(action.id, target, options)["resolution"]["injury"]["applies"]).is_true()
	# Mirror the wounded combatant into a party member the way Battle does at finish.
	patient.injuries = CombatInjury.persistent_records(target.injuries)
	var identity := CombatInjury.record_identity(patient.injuries["throat"])
	assert_str(str(identity["instance_id"])).is_not_empty()
	var intent := _intent("service-test")
	var result := InjuryTreatment.commit(intent, state, false)
	assert_bool(result["allowed"]).override_failure_message(str(result)).is_true()
	assert_dict(patient.injuries).is_empty()
	assert_int(state.gp).is_equal(0)


func _intent(card_id: String) -> Dictionary:
	var identity := CombatInjury.record_identity(patient.injuries["throat"])
	return {
		"patient_id": "vex", "instance_id": identity["instance_id"], "revision": identity["revision"],
		"card_id": card_id, "provider_id": "test-healer",
	}


static func _wound(member: PartyMember, location: String, injury_id: String, key: String) -> void:
	member.injuries[location] = {
		"injury_id": injury_id, "instance_id": "%s@%s|%s" % [injury_id, location, key],
		"location_id": location, "severity": "serious", "applications": 1,
		"effects": {"voice_blocked": true} if location == "throat" else {"attack_accuracy_pp": -10},
		"recovery": "untreated",
	}


func _controller_with_serious_throat() -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var tile_set := TileSet.new()
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tile_set
	for x: int in 4:
		ground.set_cell(Vector2i(x, 0), 0, Vector2i.ZERO)
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(ground)
	var action := CombatAction.make(&"aim-test", "Aim test", CombatAction.Kind.ATTACK)
	action.ct_cost = 30
	action.target_profile = &"ranged"
	action.aim_profiles = {"throat": {"ap_surcharge": 1, "ct_surcharge": 15, "accuracy_penalty": 25,
		"injury": {"id": "throat-crushed", "chance_on_hit": 100, "min_damage": 1, "severity": "serious",
			"effects": {"voice_blocked": true}}}}
	var ally := BattleActor.new()
	ally.display_name = "Aim ally"
	ally.hp = 200
	ally.max_hp = 200
	ally.attack = 12
	var enemy := BattleActor.new()
	enemy.display_name = "Aim target"
	enemy.hp = 200
	enemy.max_hp = 200
	enemy.anatomy = {"throat": {"display_name": "Throat", "exposed": true}}
	var controller := CombatController.new()
	var actions := CombatActionCatalog.all()
	actions.append(action)
	controller.configure(actions, grid, rules)
	controller.start([ally], [enemy], &"treatment-test")
	return controller
