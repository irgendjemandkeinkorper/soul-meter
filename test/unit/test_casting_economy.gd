extends GdUnitTestSuite

const SKILL_CHECK_SCRIPT := preload("res://globals/skill_check.gd")
const FIZZLE_TABLE_PATH := "res://globals/default_fizzle_table.tres"


func _make_skill_check() -> SkillCheckService:
	var skill_check: SkillCheckService = auto_free(SKILL_CHECK_SCRIPT.new()) as SkillCheckService
	skill_check.fizzle_table = load(FIZZLE_TABLE_PATH)
	return skill_check


func test_vervulling_core_integrity_92_sanity_readings() -> void:
	var skill_check: SkillCheckService = _make_skill_check()
	assert_float(skill_check.fizzle_percent(92.0, "tone", 0, "note", 2, false, "")).is_equal(4.0)
	assert_float(skill_check.fizzle_percent(92.0, "chord", 0, "phrase", 2, false, "")).is_equal(13.0)
	assert_float(skill_check.fizzle_percent(92.0, "triad", 0, "song", 2, false, "")).is_equal(35.0)


func test_dom_integrity_85_sanity_readings() -> void:
	var skill_check: SkillCheckService = _make_skill_check()
	assert_float(skill_check.fizzle_percent(85.0, "tone", 0, "note", 2, false, "")).is_equal(8.0)  # raw 7.5 rounds up (Note tier), matching test/unit/test_skill_check.gd
	assert_float(skill_check.fizzle_percent(85.0, "chord", 0, "phrase", 2, false, "")).is_equal(20.0)
	assert_float(skill_check.fizzle_percent(85.0, "triad", 0, "song", 2, false, "")).is_equal(47.0)


func test_thinning_wilds_integrity_70_sanity_readings() -> void:
	var skill_check: SkillCheckService = _make_skill_check()
	assert_float(skill_check.fizzle_percent(70.0, "tone", 0, "note", 2, false, "")).is_equal(15.0)
	assert_float(skill_check.fizzle_percent(70.0, "chord", 0, "phrase", 2, false, "")).is_equal(35.0)
	assert_float(skill_check.fizzle_percent(70.0, "triad", 0, "song", 2, false, "")).is_equal(73.0)


func test_the_hush_integrity_40_sanity_readings() -> void:
	var skill_check: SkillCheckService = _make_skill_check()
	assert_float(skill_check.fizzle_percent(40.0, "tone", 0, "note", 2, false, "")).is_equal(30.0)
	assert_float(skill_check.fizzle_percent(40.0, "chord", 0, "phrase", 2, false, "")).is_equal(65.0)
	# Raw arithmetic is (60 + 12) * 1.75 = 126, which exceeds the 95 ceiling
	# and is clamped to 95. The assertion below verifies the clamp, not 126.
	assert_float(skill_check.fizzle_percent(40.0, "triad", 0, "song", 2, false, "")).is_equal(95.0)
