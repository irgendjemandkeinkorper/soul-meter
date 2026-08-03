extends GdUnitTestSuite

const SkillCheckScript := preload("res://globals/skill_check.gd")

var service: SkillCheckService


func before_test() -> void:
	service = auto_free(SkillCheckScript.new())


func test_preview_applies_attribute_tier_advancement_and_cap() -> void:
	var member := _member()
	member.attributes["spark"] = 9
	member.skill_tiers["lore"] = "trained"
	member.skill_percentages["lore"] = 10.0

	assert_float(service.preview("lore", member)).is_equal(95.0)


func test_each_tier_bonus_is_applied() -> void:
	var member := _member()
	member.attributes["spark"] = 2

	member.skill_tiers["lore"] = "untrained"
	assert_float(service.preview("lore", member)).is_equal(16.0)
	member.skill_tiers["lore"] = "trained"
	assert_float(service.preview("lore", member)).is_equal(36.0)
	member.skill_tiers["lore"] = "expert"
	assert_float(service.preview("lore", member)).is_equal(51.0)


func test_boundary_rolls_use_one_to_one_hundred_and_effective_percent() -> void:
	var member := _member()
	member.attributes["spark"] = 5
	member.skill_tiers["lore"] = "untrained"

	assert_bool(service.resolve("lore", member, 0.0, "boundary", [1]).success).is_true()
	assert_bool(service.resolve("lore", member, 0.0, "boundary", [40]).success).is_true()
	assert_bool(service.resolve("lore", member, 0.0, "boundary", [41]).success).is_false()
	assert_bool(service.resolve("lore", member, 0.0, "boundary", [100]).success).is_false()


func test_expert_reroll_is_consumed_once_per_scene() -> void:
	var member := _member()
	member.attributes["spark"] = 5
	member.skill_tiers["lore"] = "expert"

	var first := service.resolve("lore", member, 0.0, "scene-a", [100, 1])
	var second := service.resolve("lore", member, 0.0, "scene-a", [100, 1])
	var next_scene := service.resolve("lore", member, 0.0, "scene-b", [100, 1])

	assert_bool(first.success).is_true()
	assert_bool(first.rerolled).is_true()
	assert_bool(second.success).is_false()
	assert_bool(second.rerolled).is_false()
	assert_bool(next_scene.success).is_true()
	assert_bool(next_scene.rerolled).is_true()


func test_fizzle_sanity_table_matches_ratified_readings() -> void:
	assert_float(service.fizzle_percent(92.0, "tone", 0, "note", 2)).is_equal(4.0)
	assert_float(service.fizzle_percent(92.0, "chord", 0, "phrase", 2)).is_equal(13.0)
	assert_float(service.fizzle_percent(92.0, "triad", 0, "song", 2)).is_equal(35.0)
	assert_float(service.fizzle_percent(85.0, "tone", 0, "note", 2)).is_equal(8.0)
	assert_float(service.fizzle_percent(85.0, "chord", 0, "phrase", 2)).is_equal(20.0)
	assert_float(service.fizzle_percent(85.0, "triad", 0, "song", 2)).is_equal(47.0)
	assert_float(service.fizzle_percent(70.0, "tone", 0, "note", 2)).is_equal(15.0)
	assert_float(service.fizzle_percent(70.0, "chord", 0, "phrase", 2)).is_equal(35.0)
	assert_float(service.fizzle_percent(70.0, "triad", 0, "song", 2)).is_equal(73.0)
	assert_float(service.fizzle_percent(40.0, "tone", 0, "note", 2)).is_equal(30.0)
	assert_float(service.fizzle_percent(40.0, "chord", 0, "phrase", 2)).is_equal(65.0)
	assert_float(service.fizzle_percent(40.0, "triad", 0, "song", 2)).is_equal(91.0)


func test_mastery_only_zeroes_note_and_phrase() -> void:
	assert_float(service.fizzle_percent(40.0, "tone", 0, "note", 2, true)).is_equal(0.0)
	assert_float(service.fizzle_percent(40.0, "tone", 0, "phrase", 2, true)).is_equal(0.0)
	assert_float(service.fizzle_percent(40.0, "triad", 0, "song", 2, true)).is_equal(91.0)
	assert_float(service.fizzle_percent(40.0, "triad", 0, "refrain", 2, true)).is_equal(95.0)


func test_fickah_and_locksmirk_keep_a_five_percent_floor() -> void:
	assert_float(service.fizzle_percent(100.0, "tone", 0, "note", 10, true, "Fickah")).is_equal(5.0)
	assert_float(service.fizzle_percent(100.0, "tone", 0, "note", 10, true, "Locksmirk")).is_equal(5.0)
	assert_float(service.fizzle_percent(100.0, "tone", 0, "note", 10, true, "Kero")).is_equal(0.0)


func _member() -> PartyMember:
	var member := PartyMember.new()
	member.id = "test-vex"
	return member
