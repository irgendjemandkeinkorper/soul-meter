extends GdUnitTestSuite
## Unit coverage for globals/chargen_data.gd — the ratified #98 chargen tables and the
## point-buy / element-pair validators the screen (#129) is built on.


func test_default_attributes_are_all_at_floor() -> void:
	var attributes := ChargenData.default_attributes()
	for id in ChargenData.ATTRIBUTE_IDS:
		assert_int(attributes[id]).is_equal(ChargenData.ATTRIBUTE_FLOOR)


func test_valid_point_buy_accepts_a_budget_exact_spread() -> void:
	# 2,2,2,2,5,7 sums to 20 but 7 exceeds the creation cap — must fail.
	var over_cap := {"forge": 2, "edge": 2, "anchor": 2, "spark": 2, "pitch": 5, "voice": 7}
	assert_bool(ChargenData.is_valid_point_buy(over_cap)).is_false()

	# A legal spread: floor(2) x4 + 5 + 5 = 8+5+5 = 18, short of budget — must fail too.
	var under_budget := {"forge": 2, "edge": 2, "anchor": 2, "spark": 2, "pitch": 5, "voice": 5}
	assert_bool(ChargenData.is_valid_point_buy(under_budget)).is_false()

	# 2+2+2+4+5+5 = 20, every value in [2,5] — must pass.
	var legal := {"forge": 2, "edge": 2, "anchor": 2, "spark": 4, "pitch": 5, "voice": 5}
	assert_bool(ChargenData.is_valid_point_buy(legal)).is_true()


func test_valid_point_buy_rejects_missing_attribute() -> void:
	var incomplete := {"forge": 4, "edge": 4, "anchor": 4, "spark": 4, "pitch": 4}
	assert_bool(ChargenData.is_valid_point_buy(incomplete)).is_false()


func test_valid_point_buy_rejects_below_floor() -> void:
	var below_floor := {"forge": 1, "edge": 5, "anchor": 5, "spark": 3, "pitch": 3, "voice": 3}
	assert_bool(ChargenData.is_valid_point_buy(below_floor)).is_false()


func test_remaining_points_counts_down_to_zero() -> void:
	var attributes := ChargenData.default_attributes()  # sums to 12
	assert_int(ChargenData.remaining_points(attributes)).is_equal(8)
	attributes["forge"] = 5
	attributes["edge"] = 5
	attributes["anchor"] = 5
	attributes["spark"] = 5
	# 5+5+5+5+2+2 = 24, past budget: remaining goes negative rather than clamping,
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
	for skill_id in ChargenData.SKILL_IDS:
		var expected: Dictionary = SkillCheckService.SKILL_DEFINITIONS[skill_id]
		assert_str(ChargenData.governing_attribute(skill_id)).is_equal(str(expected.attribute))


func test_preview_skill_percentages_matches_the_ratified_formula() -> void:
	var attributes := ChargenData.default_attributes()
	attributes["forge"] = 5
	var percentages := ChargenData.preview_skill_percentages(attributes, [])
	# Untrained: attribute x 8 + 0. Forge governs athletics and beast_handling.
	assert_float(percentages["athletics"]).is_equal(40.0)
	assert_float(percentages["beast_handling"]).is_equal(40.0)

	var trained := ChargenData.preview_skill_percentages(attributes, ["athletics"])
	# Trained adds the ratified +20 tier bonus (SkillCheckService.TIER_BONUS.trained).
	assert_float(trained["athletics"]).is_equal(60.0)


func test_five_chapter_one_ancestries_and_five_backgrounds_are_ratified() -> void:
	assert_int(ChargenData.ANCESTRIES.size()).is_equal(5)
	assert_int(ChargenData.BACKGROUNDS.size()).is_equal(5)
	assert_int(ChargenData.DISCIPLINES.size()).is_equal(3)
	assert_int(ChargenData.PATRONS.size()).is_equal(10)


func test_background_by_id_returns_its_skill_package() -> void:
	var background := ChargenData.background_by_id("sarkhollow-scavenger")
	assert_array(background["skills"]).contains(["lore", "investigation"])
