extends GdUnitTestSuite
## #285 slice 2: the level-2 resource perks change the class resource they name. Numbers ruled
## 2026-10-25 (owner item 24, flag B); the op and value live in canon, read through PerkCatalog.

const CAP_PERKS: Array[Array] = [
	["Kero", "ironbrand-thick-hide", "max_scars", IronbrandScars.MAX_SCARS],
	["Vhorr", "husk-bearer-patient-hunger", "max_hunger", VhorrHunger.MAX_HUNGER],
	["Vicoar", "flamebinder-third-lesson", "max_tokens", VicoarInstructiveFailure.MAX_TOKENS],
	["Pazzah", "oathclock-longer-docket", "max_entries", PazzahLedger.MAX_ENTRIES],
	["Izhakel", "threadwalker-fourth-thread", "max_threads", IzhakelThreads.MAX_THREADS],
	["Stuid", "lensbearer-wider-lens", "max_clarity", StuidClarity.MAX_CLARITY],
]


func test_each_cap_perk_raises_its_resource_cap_by_one() -> void:
	for row: Array in CAP_PERKS:
		var resource: ClassResource = ClassResourceRegistry.for_patron(row[0])
		assert_int(int(resource.call(row[2]))).override_failure_message("%s without perk" % row[0]).is_equal(int(row[3]))
		resource.apply_perks(PackedStringArray([row[1]]))
		assert_int(int(resource.call(row[2]))).override_failure_message("%s with %s" % [row[0], row[1]]).is_equal(int(row[3]) + 1)
		assert_int(int(resource.snapshot()["max"])).is_equal(int(row[3]) + 1)


func test_a_perk_for_another_class_moves_nothing() -> void:
	var scars := ClassResourceRegistry.for_patron("Kero") as IronbrandScars
	scars.apply_perks(PackedStringArray(["river-mother-longer-ledger", "no-such-perk"]))
	assert_int(scars.max_scars()).is_equal(IronbrandScars.MAX_SCARS)


func test_thick_hide_banks_one_more_scar_and_keeps_it_through_a_save() -> void:
	var scars := ClassResourceRegistry.for_patron("Kero") as IronbrandScars
	scars.apply_perks(PackedStringArray(["ironbrand-thick-hide"]))
	for i in 10:
		scars.on_damage_taken(3, &"enemy")
	assert_int(scars.scars).is_equal(IronbrandScars.MAX_SCARS + 1)
	var restored := ClassResourceRegistry.from_dict(scars.to_dict()) as IronbrandScars
	assert_int(restored.scars).is_equal(IronbrandScars.MAX_SCARS + 1)
	assert_array(Array(restored.perk_ids)).contains(["ironbrand-thick-hide"])


func test_wider_lens_raises_the_start_with_the_cap() -> void:
	var clarity := ClassResourceRegistry.for_patron("Stuid") as StuidClarity
	assert_int(clarity.clarity).is_equal(StuidClarity.MAX_CLARITY)
	clarity.apply_perks(PackedStringArray(["lensbearer-wider-lens"]))
	assert_int(clarity.clarity).is_equal(StuidClarity.MAX_CLARITY + 1)


func test_longer_ledger_pays_the_first_name_twice_and_only_the_first() -> void:
	var plain := ClassResourceRegistry.for_patron("Haeren") as HaerenNameLedger
	var ledger := ClassResourceRegistry.for_patron("Haeren") as HaerenNameLedger
	ledger.apply_perks(PackedStringArray(["river-mother-longer-ledger"]))
	for resource: HaerenNameLedger in [plain, ledger]:
		resource.recorded_actor_ids.append_array(["ally-a", "ally-b"])
		resource.on_combatant_fell(&"ally-a")
	assert_float(plain.pending_breath_refunds).is_equal(float(HaerenNameLedger.BREATH_REFUND))
	assert_float(ledger.pending_breath_refunds).is_equal(float(HaerenNameLedger.BREATH_REFUND * 2))
	ledger.on_combatant_fell(&"ally-b")
	assert_float(ledger.pending_breath_refunds).is_equal(float(HaerenNameLedger.BREATH_REFUND * 3))
	# The fired entry settles exactly what it carried.
	ledger.on_deferred_fired({
		"label": "name_ledger_refund",
		"effect": {"writes": [{"kind": "breath", "amount": HaerenNameLedger.BREATH_REFUND * 2}]},
	})
	assert_float(ledger.pending_breath_refunds).is_equal(float(HaerenNameLedger.BREATH_REFUND))


func test_wired_perks_are_in_play_and_the_rest_stay_planned() -> void:
	for perk_id: String in [
		"ironbrand-thick-hide", "husk-bearer-patient-hunger", "flamebinder-third-lesson",
		"oathclock-longer-docket", "threadwalker-fourth-thread", "lensbearer-wider-lens",
		"river-mother-longer-ledger", "locksmirk-second-pick",
		"locksmirk-jam-the-gears", "husk-bearer-nothing-wasted",
	]:
		assert_bool(PerkCatalog.is_in_play(perk_id)).override_failure_message(perk_id).is_true()
	assert_bool(PerkCatalog.is_in_play("mirrorblade-second-footing")).is_true()
	assert_bool(PerkCatalog.is_in_play("stormbearer-steadier-hand")).is_true()
	assert_bool(PerkCatalog.is_in_play("mirrorblade-reflection")).is_true()
	assert_bool(PerkCatalog.is_in_play("lensbearer-sacred-clarity")).is_true()


func test_second_footing_forgives_one_unbalancing_repeat_per_battle() -> void:
	var plain := ClassResourceRegistry.for_patron("Maiiam") as MaiiamBalance
	var footing := ClassResourceRegistry.for_patron("Maiiam") as MaiiamBalance
	footing.apply_perks(PackedStringArray(["mirrorblade-second-footing"]))
	for resource: MaiiamBalance in [plain, footing]:
		resource.on_action(_event("strike"))
		resource.on_action(_event("strike"))
	assert_bool(plain.unbalanced).is_true()
	assert_bool(footing.unbalanced).override_failure_message("the first unbalancing repeat is forgiven").is_false()
	footing.on_action(_event("strike"))
	assert_bool(footing.unbalanced).override_failure_message("the next repeat unbalances").is_true()
	# Spent for the battle, and a save keeps it spent.
	var restored := ClassResourceRegistry.from_dict(footing.to_dict()) as MaiiamBalance
	restored.on_action(_event("guard"))
	restored.on_action(_event("guard"))
	assert_bool(restored.unbalanced).is_true()


func test_steadier_hand_offers_one_redraw_until_a_redraw_happens() -> void:
	var storm := ClassResourceRegistry.for_patron("Ofshutje") as OfshutjeAttribution
	var spell := {"ability": {"is_spell": true}}
	assert_bool(bool(storm.on_cast_forecast(spell)["hidden_draw"]["redraw_lowest"])).is_false()
	storm.apply_perks(PackedStringArray(["stormbearer-steadier-hand"]))
	assert_bool(bool(storm.on_cast_forecast(spell)["hidden_draw"]["redraw_lowest"])).is_true()
	storm.owner_id = &"storm"
	var event := _event("cast-seam")
	event.actor_id = &"storm"
	event.data["resolution"] = {"hidden_draw": {"row_id": "fork", "row": {"id": "fork"}, "redrawn": true}}
	storm.on_action(event)
	assert_bool(storm.redraw_spent).is_true()
	assert_bool(bool(storm.on_cast_forecast(spell)["hidden_draw"]["redraw_lowest"])).is_false()
	var restored := ClassResourceRegistry.from_dict(storm.to_dict()) as OfshutjeAttribution
	assert_bool(restored.redraw_spent).is_true()


func _event(action_id: String) -> CombatEvent:
	var event := CombatEvent.new()
	event.data = {"action_id": action_id, "resolution": {}}
	return event
