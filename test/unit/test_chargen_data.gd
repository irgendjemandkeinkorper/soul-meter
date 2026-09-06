extends GdUnitTestSuite
## Unit coverage for globals/chargen_data.gd — the chargen tables on DRAMGID
## (docs/architecture-chargen-dramgid.md) and the validators the wizard is built on.


func test_default_attributes_are_all_at_floor() -> void:
	var attributes := ChargenData.default_attributes()
	for id in ChargenData.ATTRIBUTE_IDS:
		assert_int(attributes[id]).is_equal(ChargenData.ATTRIBUTE_FLOOR)


func test_valid_point_buy_accepts_a_budget_exact_spread() -> void:
	# Seven measures, floor 2, cap 5, sum 22 (DramgidSchema).
	var over_cap := {"doctrine": 2, "reason": 2, "alacrity": 2, "muster": 2, "grit": 2, "intuition": 5, "decorum": 7}
	assert_bool(ChargenData.is_valid_point_buy(over_cap)).is_false()

	# 2×5 + 5 + 5 = 20, short of the budget — must fail too.
	var under_budget := {"doctrine": 2, "reason": 2, "alacrity": 2, "muster": 2, "grit": 2, "intuition": 5, "decorum": 5}
	assert_bool(ChargenData.is_valid_point_buy(under_budget)).is_false()

	# 2+2+2+2+4+5+5 = 22, every value in [2,5] — must pass.
	var legal := {"doctrine": 2, "reason": 2, "alacrity": 2, "muster": 2, "grit": 4, "intuition": 5, "decorum": 5}
	assert_bool(ChargenData.is_valid_point_buy(legal)).is_true()

	# Legacy six-stat keys are not a point-buy any more.
	var legacy := {"forge": 2, "edge": 2, "anchor": 2, "spark": 4, "pitch": 5, "voice": 5}
	assert_bool(ChargenData.is_valid_point_buy(legacy)).is_false()


func test_valid_point_buy_rejects_missing_attribute() -> void:
	var incomplete := {"doctrine": 4, "reason": 4, "alacrity": 4, "muster": 4, "grit": 4, "intuition": 2}
	assert_bool(ChargenData.is_valid_point_buy(incomplete)).is_false()


func test_valid_point_buy_rejects_below_floor() -> void:
	var below_floor := {"doctrine": 1, "reason": 5, "alacrity": 5, "muster": 5, "grit": 2, "intuition": 2, "decorum": 2}
	assert_bool(ChargenData.is_valid_point_buy(below_floor)).is_false()


func test_remaining_points_counts_down_to_zero() -> void:
	var attributes := ChargenData.default_attributes()  # sums to 14
	assert_int(ChargenData.remaining_points(attributes)).is_equal(8)
	attributes["muster"] = 5
	attributes["grit"] = 5
	attributes["reason"] = 5
	attributes["decorum"] = 5
	# 5+5+5+5+2+2+2 = 26, past budget: remaining goes negative rather than clamping,
	# so an over-spend is visibly wrong instead of silently hidden.
	assert_int(ChargenData.remaining_points(attributes)).is_equal(-4)


func test_element_pair_rejects_a_clash_but_allows_everything_else() -> void:
	assert_bool(ChargenData.is_valid_element_pair("suul", "daar")).is_false()
	assert_bool(ChargenData.is_valid_element_pair("daar", "suul")).is_false()
	assert_bool(ChargenData.is_valid_element_pair("khor", "nul")).is_false()
	assert_bool(ChargenData.is_valid_element_pair("suul", "khor")).is_true()
	assert_bool(ChargenData.is_valid_element_pair("suul", "suul")).is_false()
	assert_bool(ChargenData.is_valid_element_pair("", "")).is_true()


func test_governing_attribute_matches_skill_check_service() -> void:
	for skill_id in DramgidSchema.SKILL_IDS:
		var expected: Dictionary = SkillCheckService.SKILL_DEFINITIONS[skill_id]
		assert_str(ChargenData.governing_attribute(skill_id)).is_equal(str(expected.attribute))
	# The transitional legacy ids (sheet) still answer through the service definitions.
	assert_str(ChargenData.governing_attribute("lore")).is_equal("spark")


func test_backgrounds_and_ancestry_traits_use_schema_skill_ids() -> void:
	for background: Dictionary in ChargenData.BACKGROUNDS:
		var skills: Array = background["skills"]
		assert_int(skills.size()).is_equal(2)
		for skill_id in skills:
			assert_bool(DramgidSchema.is_skill(str(skill_id))).is_true()
	for ancestry: Dictionary in ChargenData.ANCESTRIES:
		for skill_id in ancestry.get("trained_skills", []):
			assert_bool(DramgidSchema.is_skill(str(skill_id))).is_true()
		for attribute_id in ancestry.get("lean_ids", []):
			assert_bool(DramgidSchema.ATTRIBUTES.has(str(attribute_id))).is_true()
	assert_int(int(ChargenData.ancestry_by_id("vael")["creation_bonus_points"])).is_equal(1)
	assert_bool("sounding" in (ChargenData.ancestry_by_id("weftkin")["trained_skills"] as Array)).is_true()


func test_patrons_are_a_view_over_the_class_catalog() -> void:
	assert_int(ChargenData.PATRONS.size()).is_equal(10)
	assert_str(str(ChargenData.patron_by_id("ironbrand")["patron"])).is_equal("Kero")
	assert_str(ChargenData.skill_label("recall")).is_equal("Recall")
	assert_str(ChargenData.skill_label("lore")).is_equal("Lore")
	assert_str(ChargenData.attribute_label("muster")).is_equal("Muster")
	assert_int(ChargenData.DISCIPLINES.size()).is_equal(3)
	assert_str(str(ChargenData.discipline_by_id("hushwarden")["favours"])).is_equal("nul")


func test_five_chapter_one_ancestries_and_five_backgrounds_are_ratified() -> void:
	assert_int(ChargenData.ANCESTRIES.size()).is_equal(5)
	assert_int(ChargenData.BACKGROUNDS.size()).is_equal(5)
	assert_int(ChargenData.DISCIPLINES.size()).is_equal(3)
	assert_int(ChargenData.PATRONS.size()).is_equal(10)


func test_background_by_id_returns_its_skill_package() -> void:
	var background := ChargenData.background_by_id("sarkhollow-scavenger")
	assert_array(background["skills"]).contains(["recall", "unweave"])
