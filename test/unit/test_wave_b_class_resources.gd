extends GdUnitTestSuite
## Wave B resources #224–#228: registry lookup, used hooks, snapshots, and save round-trips.

func test_registry_resolves_wave_b_patron_resources() -> void:
	assert_bool(ClassResourceRegistry.for_patron("Maiiam") is MaiiamBalance).is_true()
	assert_bool(ClassResourceRegistry.for_patron("Vicoar") is VicoarInstructiveFailure).is_true()
	assert_bool(ClassResourceRegistry.for_patron("Vhorr") is VhorrHunger).is_true()
	assert_bool(ClassResourceRegistry.for_patron("Haeren") is HaerenNameLedger).is_true()
	assert_bool(ClassResourceRegistry.for_patron("Kero") is IronbrandScars).is_true()


func test_mirrorblade_balance_alternation_and_forecast_hooks() -> void:
	var resource := MaiiamBalance.new()
	resource.patron_id = &"maiiam"
	resource.on_action(_event({"action_id": "strike", "resolution": {}}))
	assert_bool(resource.unbalanced).is_false()
	resource.on_action(_event({"action_id": "guard", "resolution": {}}))
	assert_bool(resource.unbalanced).is_false()
	resource.on_action(_event({"action_id": "guard", "resolution": {}}))
	assert_bool(resource.unbalanced).is_true()
	assert_bool(resource.snapshot().has("max")).is_false()
	var overrides: Dictionary = resource.on_cast_forecast({"fizzle": {"agreement_integrity": 90.0}})
	assert_float(float((overrides["unit"] as Dictionary)["attack_scale"])).is_equal(1.25)
	assert_float(float((overrides["fizzle"] as Dictionary)["agreement_integrity"])).is_equal(75.0)


func test_flamebinder_fizzle_spend_and_action_hooks() -> void:
	var resource := VicoarInstructiveFailure.new()
	for _i in VicoarInstructiveFailure.MAX_TOKENS + 2:
		resource.on_fizzle({"fizzled": true})
	assert_int(resource.tokens).is_equal(VicoarInstructiveFailure.MAX_TOKENS)
	assert_bool(resource.spend_token()).is_true()
	assert_bool(resource.spend_token()).is_false()
	var overrides: Dictionary = resource.on_cast_forecast({"fizzle": {"pitch": 2}})
	assert_float(float(overrides["fizzle_percent_override"])).is_equal(0.0)
	resource.on_action(_event({"action_id": "move", "verb": CombatAction.Verb.MOVE, "resolution": {}}))
	assert_bool(resource.guaranteed_cast_armed).is_true()
	resource.on_action(_event({"action_id": "cast", "verb": CombatAction.Verb.CAST, "resolution": {"fizzled": true}}))
	assert_bool(resource.guaranteed_cast_armed).is_false()
	assert_int(resource.tokens).is_equal(VicoarInstructiveFailure.MAX_TOKENS)


func test_ironbrand_scars_damage_forecast_action_and_save_hooks() -> void:
	var resource := IronbrandScars.new()
	resource.patron_id = &"kero"
	resource.on_damage_taken(4, &"enemy-0")
	assert_int(resource.scars).is_equal(1)
	assert_bool(resource.spend_scar()).is_true()
	assert_bool((resource.on_cast_forecast({})["to_hit_enabled"] as bool)).is_false()
	resource.on_action(_event({"action_id": "cast", "resolution": {"hit": true}}))
	var restored: IronbrandScars = ClassResourceRegistry.from_dict(resource.to_dict()) as IronbrandScars
	assert_int(restored.scars).is_equal(0)
	assert_bool(restored.guaranteed_hit_armed).is_false()


func test_husk_bearer_dot_write_and_kill_hooks() -> void:
	var resource := VhorrHunger.new()
	resource.patron_id = &"vhorr"
	resource.on_action(_event({
		"action_id": "strike",
		"target_id": "enemy-0",
		"resolution": {"hit": true, "writes": [{"kind": "hp"}]},
	}))
	assert_int(resource.hunger).is_equal(1)
	assert_array(resource.pending_dot_targets).contains(["enemy-0"])
	resource.on_action(_event({
		"action_id": "strike",
		"target_id": "enemy-0",
		"resolution": {"hit": true, "writes": [{"kind": "hp"}]},
	}))
	assert_int(resource.hunger).is_equal(2)
	resource.on_kill(&"enemy-0", &"dot")
	assert_float(resource.pending_breath_refunds).is_equal(float(VhorrHunger.BREATH_REFUND))
	var restored: VhorrHunger = ClassResourceRegistry.from_dict(resource.to_dict()) as VhorrHunger
	assert_int(restored.hunger).is_equal(2)
	assert_float(restored.pending_breath_refunds).is_equal(float(VhorrHunger.BREATH_REFUND))
	assert_array(restored.pending_dot_targets).contains(["enemy-0"])


func test_husk_bearer_ignores_non_strike_targeted_actions() -> void:
	var resource := VhorrHunger.new()
	resource.on_action(_event({
		"action_id": "enemy-strike",
		"target_id": "enemy-0",
		"resolution": {"hit": true, "writes": [{"kind": "hp"}]},
	}))
	assert_int(resource.hunger).is_equal(0)


func test_river_mother_records_each_name_once_and_round_trips() -> void:
	var resource := HaerenNameLedger.new()
	resource.patron_id = &"haeren"
	assert_bool(resource.record_name("  Aster  ", true)).is_true()
	assert_bool(resource.record_name("Aster", false)).is_false()
	assert_bool(resource.record_name("Belen", false)).is_true()
	assert_int(resource.recorded_names.size()).is_equal(2)
	var action := load("res://data/combat/actions/11_record_name.tres") as CombatAction
	assert_int(action.kind).is_equal(CombatAction.Kind.PASS)
	assert_int(action.ap_cost).is_equal(2)
	var restored: HaerenNameLedger = ClassResourceRegistry.from_dict(resource.to_dict()) as HaerenNameLedger
	assert_array(restored.recorded_names).contains_exactly(["Aster", "Belen"])
	assert_float(restored.pending_breath_refunds).is_equal(0.0)
	assert_bool(resource.snapshot().has("max")).is_false()


func test_river_mother_only_refunds_recorded_actor_hp_or_dot_writes() -> void:
	var resource := HaerenNameLedger.new()
	resource.recorded_actor_ids = ["ally-0"]
	resource.on_any_action(&"enemy-0", &"strike", &"ally-0", {
		"resolution": {"writes": [
			{"kind": "hp", "target_id": "enemy-0", "after": 0},
			{"kind": "breath", "target_id": "ally-0", "after": 0},
			{"kind": "hp", "target_id": "ally-0", "after": 0},
		]},
	})
	assert_float(resource.pending_breath_refunds).is_equal(float(HaerenNameLedger.BREATH_REFUND))
	assert_array(resource.refunded_actor_ids).contains(["ally-0"])


func test_unit_plate_resource_snapshot_is_renderable() -> void:
	var scene := load("res://ui/hud/regions/unit_plate/unit_plate_region.tscn") as PackedScene
	assert_object(scene).is_not_null()
	var snapshot := (ClassResourceRegistry.for_patron("Vhorr") as VhorrHunger).snapshot()
	assert_bool(bool(snapshot["hidden_on_plate"])).is_true()


func _event(data: Dictionary) -> CombatEvent:
	var event := CombatEvent.new()
	event.data = data
	event.target_id = StringName(str(data.get("target_id", "")))
	return event


func test_a_pre_ruling_save_restores_its_in_flight_refund_under_the_new_key() -> void:
	# The Soul->Breath swap renamed the persisted key. A battle saved mid-refund must not
	# lose it just because the save predates the ruling.
	var hunger := VhorrHunger.new()
	hunger.patron_id = &"vhorr"
	var legacy: Dictionary = hunger.to_dict()
	legacy.erase("pending_breath_refunds")
	legacy["pending_soul_refunds"] = 1.0
	var restored: VhorrHunger = ClassResourceRegistry.from_dict(legacy) as VhorrHunger
	assert_float(restored.pending_breath_refunds).is_equal(1.0)

	var ledger := HaerenNameLedger.new()
	ledger.patron_id = &"haeren"
	var legacy_ledger: Dictionary = ledger.to_dict()
	legacy_ledger.erase("pending_breath_refunds")
	legacy_ledger["pending_soul_refunds"] = 1.0
	var restored_ledger: HaerenNameLedger = (
		ClassResourceRegistry.from_dict(legacy_ledger) as HaerenNameLedger
	)
	assert_float(restored_ledger.pending_breath_refunds).is_equal(1.0)


func test_neither_refund_class_writes_to_the_soul_gauge() -> void:
	# Owner ruling 3 (#286): the Soul Gauge rises only through an act of Agreement, which is
	# a tagged quest outcome. No class resource may mint one.
	var hunger := VhorrHunger.new()
	hunger.on_kill(&"enemy-0", &"dot")
	var name_ledger := HaerenNameLedger.new()
	name_ledger.recorded_actor_ids = ["ally-0"]
	name_ledger.on_any_action(&"enemy-0", &"strike", &"ally-0", {
		"resolution": {"writes": [{"kind": "hp", "target_id": "ally-0", "after": 0}]},
	})
	for resource: ClassResource in [hunger, name_ledger]:
		for entry: Variant in resource.snapshot().get("deferred", []):
			for write: Variant in (entry as Dictionary).get("writes", []):
				assert_str(str((write as Dictionary).get("kind", ""))).is_not_equal("soul_refund")
				assert_str(str((write as Dictionary).get("kind", ""))).is_not_equal("soul_meter")
