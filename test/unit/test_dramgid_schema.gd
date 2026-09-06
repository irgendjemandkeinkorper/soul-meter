extends GdUnitTestSuite

const DramgidSchemaScript := preload("res://globals/stats/dramgid_schema.gd")
const DramgidDerivedScript := preload("res://globals/stats/dramgid_derived.gd")
const SkillCheckScript := preload("res://globals/skill_check.gd")


func test_schema_contains_seven_attributes_and_twenty_two_skills() -> void:
	assert_int(DramgidSchemaScript.ATTRIBUTE_IDS.size()).is_equal(7)
	assert_int(DramgidSchemaScript.ATTRIBUTES.size()).is_equal(7)
	assert_int(DramgidSchemaScript.SKILL_IDS.size()).is_equal(22)
	assert_int(DramgidSchemaScript.SKILLS.size()).is_equal(22)


func test_every_skill_has_a_governing_attribute_and_valid_loom_sensitivity() -> void:
	for skill_id: String in DramgidSchemaScript.SKILL_IDS:
		var definition: Dictionary = DramgidSchemaScript.SKILLS[skill_id]
		assert_bool(DramgidSchemaScript.ATTRIBUTES.has(definition.get("attribute", ""))).is_true()
		assert_bool(definition.get("loom", -1) in DramgidSchemaScript.LOOM_VALUES).is_true()


func test_point_buy_validation_requires_complete_bounded_sum_of_twenty_two() -> void:
	var allocation := DramgidSchemaScript.default_attributes()
	var ids := DramgidSchemaScript.ATTRIBUTE_IDS
	allocation[ids[0]] = 5
	allocation[ids[1]] = 5
	allocation[ids[2]] = 4

	assert_bool(DramgidSchemaScript.is_valid_attribute_allocation(allocation)).is_true()

	var missing: Dictionary = allocation.duplicate(true)
	missing.erase(ids[0])
	assert_bool(DramgidSchemaScript.is_valid_attribute_allocation(missing)).is_false()

	var over_cap: Dictionary = allocation.duplicate(true)
	over_cap[ids[0]] = DramgidSchemaScript.ATTRIBUTE_CAP + 1
	assert_bool(DramgidSchemaScript.is_valid_attribute_allocation(over_cap)).is_false()

	var under_budget := DramgidSchemaScript.default_attributes()
	assert_bool(DramgidSchemaScript.is_valid_attribute_allocation(under_budget)).is_false()


func test_skill_check_definitions_are_built_from_the_canonical_schema() -> void:
	var service: SkillCheckService = auto_free(SkillCheckScript.new())
	for skill_id: String in DramgidSchemaScript.SKILL_IDS:
		assert_bool(service.SKILL_DEFINITIONS.has(skill_id)).is_true()
		assert_str(str(service.SKILL_DEFINITIONS[skill_id].attribute)).is_equal(
			str(DramgidSchemaScript.SKILLS[skill_id].attribute)
		)


func test_unfrozen_karma_and_loom_hooks_are_neutral() -> void:
	var service: SkillCheckService = auto_free(SkillCheckScript.new())
	for skill_id: String in DramgidSchemaScript.SKILL_IDS:
		assert_float(service.karma_bonus(skill_id)).is_equal(0.0)
		assert_int(service.loom_penalty(skill_id, null)).is_equal(0)


func test_derived_stub_matches_current_formulas_and_recomputes_member() -> void:
	assert_int(DramgidDerivedScript.max_hp(4)).is_equal(32)
	assert_int(DramgidDerivedScript.attack(5)).is_equal(5)
	assert_int(DramgidDerivedScript.defense(3)).is_equal(3)
	assert_int(DramgidDerivedScript.breath_max(2)).is_equal(15)

	var member := PartyMember.new()
	member.attributes = {
		DramgidSchemaScript.ATTR_GRIT: 4,
		DramgidSchemaScript.ATTR_MUSTER: 5,
		DramgidSchemaScript.ATTR_ALACRITY: 3,
		DramgidSchemaScript.ATTR_INTUITION: 2,
	}
	member.hp = 99
	member.breath = 99
	DramgidDerivedScript.recompute(member)

	assert_int(member.max_hp).is_equal(32)
	assert_int(member.hp).is_equal(32)
	assert_int(member.attack).is_equal(5)
	assert_int(member.defense).is_equal(3)
	assert_int(member.breath_max).is_equal(15)
	assert_int(member.breath).is_equal(15)
