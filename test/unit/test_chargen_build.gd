extends GdUnitTestSuite
## ChargenBuild — the pure creation model (docs/architecture-chargen-dramgid.md §5, §7.2).

var _saved_skills: Dictionary = {}


func before_test() -> void:
	_saved_skills = GameState.skills.duplicate(true)
	GameState.skills = {}


func after_test() -> void:
	GameState.skills = _saved_skills


func _ironbrand_build() -> ChargenBuild:
	var build := ChargenBuild.new()
	build.select_ancestry("kaan")
	build.select_discipline("terrashaper")
	build.select_class("ironbrand")
	build.select_background("verlossen-miner")
	build.display_name = "Sera"
	return build


func _place_all_points(build: ChargenBuild) -> void:
	# 2/2/2/2/2/2/2 = 14; +8 → 22. muster 5, grit 5, reason 4.
	assert_bool(build.set_attribute("muster", 5)).is_true()
	assert_bool(build.set_attribute("grit", 5)).is_true()
	assert_bool(build.set_attribute("reason", 4)).is_true()
	assert_int(build.remaining_attribute_points()).is_equal(0)


func test_attribute_budget_floor_and_cap_are_enforced() -> void:
	var build := ChargenBuild.new()
	assert_int(build.remaining_attribute_points()).is_equal(8)
	assert_bool(build.set_attribute("muster", 6)).is_false()
	assert_bool(build.set_attribute("muster", 1)).is_false()
	assert_bool(build.set_attribute("nope", 3)).is_false()
	_place_all_points(build)
	assert_bool(build.step_attribute("alacrity", 1)).is_false()
	assert_bool(build.step_attribute("muster", -1)).is_true()
	assert_bool(build.step_attribute("alacrity", 1)).is_true()
	assert_bool(build.attributes_valid()).is_true()
	assert_bool(build.validate(&"attributes")["valid"]).is_true()


func test_creation_pool_scales_with_reason_and_decorum_and_vael_bonus() -> void:
	var build := ChargenBuild.new()
	assert_int(build.creation_pool()).is_equal(DramgidSchema.CREATION_POOL_BASE + 4)
	build.set_attribute("reason", 5)
	build.set_attribute("decorum", 5)
	assert_int(build.creation_pool()).is_equal(DramgidSchema.CREATION_POOL_BASE + 10)
	build.select_ancestry("vael")
	assert_int(build.creation_pool()).is_equal(DramgidSchema.CREATION_POOL_BASE + 11)


func test_class_choice_grants_kit_tag_and_prefills_suggested_elements() -> void:
	var build := _ironbrand_build()
	assert_str(build.kit_skill).is_equal("heft")
	assert_str(build.major_element).is_equal("scor")
	assert_str(build.minor_element).is_equal("molm")
	assert_str(build.mastery_element).is_equal("scor")
	var tiers := build.granted_tiers()
	assert_str(str(tiers.get("heft", ""))).is_equal("trained")
	assert_str(str(tiers.get("tone_scor", ""))).is_equal("trained")
	assert_str(str(tiers.get("tone_molm", ""))).is_equal("trained")
	assert_str(str(tiers.get("strain", ""))).is_equal("trained")
	assert_str(str(tiers.get("wayfinding", ""))).is_equal("trained")
	assert_bool(tiers.has("grip")).is_false()

	assert_bool(build.select_kit("grip")).is_true()
	assert_bool(build.select_kit("keen")).is_false()
	assert_bool(build.granted_tiers().has("grip")).is_true()
	assert_bool(build.granted_tiers().has("heft")).is_false()


func test_weftkin_innate_training_is_a_tag() -> void:
	var build := ChargenBuild.new()
	build.select_ancestry("weftkin")
	assert_str(str(build.granted_tiers().get("sounding", ""))).is_equal("trained")


func test_only_held_tones_are_purchasable() -> void:
	var build := _ironbrand_build()
	var purchasable := build.purchasable_skills()
	assert_bool(purchasable.has("tone_scor")).is_true()
	assert_bool(purchasable.has("tone_molm")).is_true()
	assert_bool(purchasable.has("tone_aqua")).is_false()
	assert_bool(purchasable.has("keen")).is_true()
	assert_bool(purchasable.has("recall")).is_true()
	assert_int(purchasable.size()).is_equal(22 + 5 + 2)
	assert_str(str(build.can_buy("tone_aqua")["blocked_by"])).is_equal("unheld_tone")


func test_buy_and_refund_use_the_ratified_bands_and_stay_exact() -> void:
	var build := _ironbrand_build()
	_place_all_points(build)
	var pool := build.creation_pool()
	# heft: muster 5 × 8 + Trained 20 = 60 → next step lands at 65 → 2 points.
	assert_float(build.preview_percent("heft")).is_equal(60.0)
	var gate := build.buy("heft")
	assert_bool(gate["allowed"]).is_true()
	assert_int(gate["cost"]).is_equal(2)
	assert_float(build.preview_percent("heft")).is_equal(65.0)
	# recall: reason 4 × 8 = 32 → 37 → 1 point.
	assert_int(build.buy("recall")["cost"]).is_equal(1)
	assert_int(build.points_spent()).is_equal(3)
	assert_int(build.points_remaining()).is_equal(pool - 3)

	var refund := build.refund("heft")
	assert_bool(refund["allowed"]).is_true()
	assert_int(refund["cost"]).is_equal(2)
	assert_float(build.preview_percent("heft")).is_equal(60.0)
	assert_int(build.points_spent()).is_equal(1)
	assert_str(str(build.refund("heft")["blocked_by"])).is_equal("nothing_to_refund")


func test_pool_cannot_be_overspent_and_cap_blocks() -> void:
	var build := _ironbrand_build()
	_place_all_points(build)
	var bought := 0
	while build.can_buy("recall")["allowed"]:
		build.buy("recall")
		bought += 1
	assert_bool(bought > 0).is_true()
	assert_bool(build.points_remaining() >= 0).is_true()
	var gate := build.can_buy("recall")
	assert_bool(str(gate["blocked_by"]) in ["points", "effective_cap"]).is_true()
	assert_bool(build.validate(&"skills")["valid"]).is_true()


func test_changing_a_base_resets_creation_buys() -> void:
	var build := _ironbrand_build()
	_place_all_points(build)
	build.buy("recall")
	assert_int(build.points_spent()).is_equal(1)
	build.step_attribute("reason", -1)
	assert_int(build.points_spent()).is_equal(0)
	build.buy("recall")
	build.select_background("dom-storm-coast")
	assert_int(build.points_spent()).is_equal(0)


func test_preview_matches_skill_check_on_the_built_member() -> void:
	var build := _ironbrand_build()
	_place_all_points(build)
	build.buy("heft")
	build.buy("tone_scor")
	var member := build.to_party_member()
	for skill_id: String in build.purchasable_skills():
		assert_float(build.preview_percent(skill_id)).is_equal(SkillCheck.preview(skill_id, member, 0.0))


func test_validation_gates_follow_canon_order() -> void:
	var build := ChargenBuild.new()
	assert_bool(build.validate(&"ancestry")["valid"]).is_false()
	build.select_ancestry("vael")
	assert_bool(build.validate(&"ancestry")["valid"]).is_true()
	assert_bool(build.validate(&"discipline")["valid"]).is_false()
	build.select_discipline("chordblade")
	build.select_class("threadwalker")
	assert_bool(build.validate(&"patron")["valid"]).is_false()
	assert_str(str(build.validate(&"patron")["message"])).contains("retired")
	build.select_discipline("hushwarden")
	assert_bool(build.validate(&"patron")["valid"]).is_true()
	build.set_elements("suul", "daar")
	assert_bool(build.validate(&"elements")["valid"]).is_false()
	build.set_elements("suul", "bloei")
	assert_bool(build.validate(&"elements")["valid"]).is_true()
	assert_bool(build.validate(&"attributes")["valid"]).is_false()
	_place_all_points(build)
	assert_bool(build.validate(&"background")["valid"]).is_false()
	build.select_background("sarkhollow-scavenger")
	assert_bool(build.validate(&"identity")["valid"]).is_false()
	build.display_name = "  Sera "
	assert_bool(build.validate(&"identity")["valid"]).is_true()
	assert_bool(build.is_complete()).is_true()


func test_locksmirk_suggests_nothing_and_elements_stay_open() -> void:
	var build := ChargenBuild.new()
	build.select_class("locksmirk")
	assert_str(build.major_element).is_equal("")
	assert_bool(build.validate(&"elements")["valid"]).is_false()
	build.set_elements("khor", "")
	assert_bool(build.validate(&"elements")["valid"]).is_true()
	assert_int(build.held_tones().size()).is_equal(1)


func test_mastery_element_must_be_held() -> void:
	var build := _ironbrand_build()
	assert_bool(build.select_mastery("aqua")).is_false()
	assert_bool(build.select_mastery("molm")).is_true()
	build.set_elements("scor", "terra")
	assert_str(build.mastery_element).is_equal("scor")


func test_to_party_member_writes_every_field_in_the_roster_vocabulary() -> void:
	var build := _ironbrand_build()
	_place_all_points(build)
	build.epithet = "of the Deep Forge"
	build.flaw = "Counts every debt"
	build.buy("heft")
	build.buy("recall")
	var member := build.to_party_member()
	assert_str(member.display_name).is_equal("Sera")
	assert_str(member.patron).is_equal("Kero")
	assert_str(member.class_id).is_equal("ironbrand")
	assert_str(member.char_class).is_equal("Ironbrand (Kero)")
	assert_str(member.kit_weapon_skill).is_equal("heft")
	assert_str(member.discipline).is_equal("terrashaper")
	assert_str(member.background).is_equal("verlossen-miner")
	assert_str(member.race).is_equal("Kaan")
	assert_str(member.major_element).is_equal("scor")
	assert_str(member.mastery_element).is_equal("scor")
	assert_int(member.attribute_value(&"muster")).is_equal(5)
	assert_int(member.max_hp).is_equal(40)
	assert_int(member.hp).is_equal(40)
	assert_int(member.attack).is_equal(5)
	assert_int(member.level).is_equal(1)
	assert_str(str(member.skill_tiers.get("heft", ""))).is_equal("trained")
	assert_float(float(member.skill_percentages.get("heft", 0.0))).is_equal(5.0)
	assert_float(float(member.skill_percentages.get("recall", 0.0))).is_equal(5.0)
	assert_int(member.advancement_points).is_equal(build.creation_pool() - 3)
	assert_bool(ClassResourceRegistry.for_patron(member.patron).patron_id == &"kero").is_true()

	var rows := build.creation_ledger_rows()
	assert_int(rows.size()).is_equal(2)
	assert_int(int(rows["heft"]["advancement_points_spent"])).is_equal(2)
	assert_str(str(rows["heft"]["tier"])).is_equal("trained")
	assert_float(float(rows["recall"]["percentage"])).is_equal(5.0)


func test_ledger_seed_and_mirror_refund_round_trip() -> void:
	var build := _ironbrand_build()
	_place_all_points(build)
	build.buy("heft")
	build.buy("recall")
	var member := build.to_party_member()
	member.id = "chargen-probe"
	Advancement.seed_creation_ledger(member, build.creation_ledger_rows())
	assert_int(Advancement.total_points_spent(member)).is_equal(3)
	for skill_id: String in GameState.skills["chargen-probe"].keys():
		var row: Dictionary = GameState.skills["chargen-probe"][skill_id]
		assert_str(str(row["tier"])).is_equal(str(row["tier"]).to_lower())
		assert_bool(GameState._is_known_skill_tier(str(row["tier"]))).is_true()

	var result := Advancement.mirror_rewriting(member)
	assert_int(result["refunded_points"]).is_equal(3)
	assert_float(float(member.skill_percentages.get("heft", 0.0))).is_equal(0.0)
	assert_int(member.advancement_points).is_equal(build.creation_pool())
