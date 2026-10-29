extends GdUnitTestSuite
## #285 slice 3: the level-6 capstones that work without a live battle. Rulings 2026-10-26:
## Even Hand rebalances on the first fizzle; Pocketed Gear banks a free Jam (never a Soul refund).


func test_first_blood_banks_a_scar_before_any_damage() -> void:
	var scars := _resource("Kero", "ironbrand-first-blood") as IronbrandScars
	assert_int(scars.scars).is_equal(1)
	assert_int((ClassResourceRegistry.for_patron("Kero") as IronbrandScars).scars).is_zero()


func test_debt_collected_returns_the_scar_only_when_the_hit_downs_its_target() -> void:
	for downs: bool in [false, true]:
		var scars := _resource("Kero", "ironbrand-debt-collected") as IronbrandScars
		scars.scars = 1
		assert_bool(scars.spend_scar()).is_true()
		var event := CombatEvent.new()
		event.target_id = &"enemy"
		event.data = {"action_id": "strike", "resolution": {"writes": [
			{"kind": "hp", "target_id": "enemy", "before": 6, "after": 0 if downs else 2},
		]}}
		scars.on_action(event)
		assert_bool(scars.guaranteed_hit_armed).is_false()
		assert_int(scars.scars).override_failure_message("downs=%s" % downs).is_equal(1 if downs else 0)


func test_feed_the_husk_adds_hunger_on_a_killing_tick() -> void:
	var plain := ClassResourceRegistry.for_patron("Vhorr") as VhorrHunger
	var husk := _resource("Vhorr", "husk-bearer-feed-the-husk") as VhorrHunger
	for resource: VhorrHunger in [plain, husk]:
		resource.on_kill(&"enemy", &"dot")
		resource.on_kill(&"enemy", &"hp")
	assert_int(plain.hunger).is_zero()
	assert_int(husk.hunger).is_equal(1)


func test_even_hand_rebalances_on_the_first_fizzle_only() -> void:
	var balance := _resource("Maiiam", "mirrorblade-even-hand") as MaiiamBalance
	balance.on_action(_event("strike"))
	balance.on_action(_event("strike"))
	assert_bool(balance.unbalanced).is_true()
	balance.on_fizzle({})
	assert_bool(balance.unbalanced).is_false()
	assert_int(balance.side_streak).is_zero()
	balance.on_action(_event("guard"))
	balance.on_action(_event("guard"))
	balance.on_fizzle({})
	assert_bool(balance.unbalanced).override_failure_message("spent for the battle").is_true()
	var restored := ClassResourceRegistry.from_dict(balance.to_dict()) as MaiiamBalance
	assert_bool(restored.even_hand_spent).is_true()


func test_pocketed_gear_waives_the_next_jam_and_never_refunds() -> void:
	var jam := _resource("Fickah", "locksmirk-pocketed-gear") as FickahRuleBreaker
	assert_bool(jam.waives_soul_cost(&"jam_the_gears")).is_false()
	jam._on_cancelled(true)
	assert_bool(jam.waives_soul_cost(&"jam_the_gears")).is_true()
	assert_bool(jam.waives_soul_cost(&"other")).is_false()
	var restored := ClassResourceRegistry.from_dict(jam.to_dict()) as FickahRuleBreaker
	assert_bool(restored.free_jam_banked).is_true()
	var plain := ClassResourceRegistry.for_patron("Fickah") as FickahRuleBreaker
	plain._on_cancelled(true)
	assert_bool(plain.waives_soul_cost(&"jam_the_gears")).is_false()


func test_every_perk_is_in_play() -> void:
	var planned: Array[String] = []
	for row: Dictionary in PerkCatalog.all():
		if not PerkCatalog.is_in_play(str(row["id"])):
			planned.append(str(row["id"]))
	# Read Aloud and Sacred Clarity closed the list (#285 slice 5, ruled 2026-10-29).
	assert_array(planned).is_empty()


func _resource(patron: String, perk_id: String) -> ClassResource:
	var resource: ClassResource = ClassResourceRegistry.for_patron(patron)
	resource.apply_perks(PackedStringArray([perk_id]))
	return resource


func _event(action_id: String) -> CombatEvent:
	var event := CombatEvent.new()
	event.data = {"action_id": action_id, "resolution": {}}
	return event
