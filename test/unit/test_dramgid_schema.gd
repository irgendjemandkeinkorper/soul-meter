extends GdUnitTestSuite

const DramgidSchemaScript := preload("res://globals/stats/dramgid_schema.gd")
const DramgidDerivedScript := preload("res://globals/stats/dramgid_derived.gd")
const SkillCheckScript := preload("res://globals/skill_check.gd")


func test_schema_contains_seven_attributes_and_thirty_seven_skills() -> void:
	assert_int(DramgidSchemaScript.ATTRIBUTE_IDS.size()).is_equal(7)
	assert_int(DramgidSchemaScript.ATTRIBUTES.size()).is_equal(7)
	assert_int(DramgidSchemaScript.FIELD_SKILL_IDS.size()).is_equal(22)
	assert_int(DramgidSchemaScript.ARMS_SKILL_IDS.size()).is_equal(5)
	assert_int(DramgidSchemaScript.TONE_SKILL_IDS.size()).is_equal(10)
	assert_int(DramgidSchemaScript.SKILL_IDS.size()).is_equal(37)
	assert_int(DramgidSchemaScript.SKILLS.size()).is_equal(37)


func test_groups_partition_every_skill_in_schema_order() -> void:
	var seen: Dictionary = {}
	var total := 0
	for group: String in DramgidSchemaScript.SKILL_GROUPS:
		var members := DramgidSchemaScript.skills_in_group(group)
		assert_bool(members.size() > 0).is_true()
		for skill_id: String in members:
			assert_bool(seen.has(skill_id)).is_false()
			seen[skill_id] = true
			assert_str(DramgidSchemaScript.skill_group(skill_id)).is_equal(group)
		total += members.size()
	assert_int(total).is_equal(DramgidSchemaScript.SKILL_IDS.size())
	for skill_id: String in DramgidSchemaScript.SKILL_IDS:
		assert_bool(DramgidSchemaScript.is_skill(skill_id)).is_true()
		assert_bool(DramgidSchemaScript.SKILL_GROUPS.has(DramgidSchemaScript.skill_group(skill_id))).is_true()
	for skill_id: String in DramgidSchemaScript.FIELD_SKILL_IDS:
		assert_bool(DramgidSchemaScript.FIELD_GROUPS.has(DramgidSchemaScript.skill_group(skill_id))).is_true()


func test_arms_skills_are_muster_or_alacrity_and_ignore_the_loom() -> void:
	var service: SkillCheckService = auto_free(SkillCheckScript.new())
	for skill_id: String in DramgidSchemaScript.ARMS_SKILL_IDS:
		assert_bool(DramgidSchemaScript.is_arms_skill(skill_id)).is_true()
		assert_bool(DramgidSchemaScript.governing_attribute(skill_id) in ["muster", "alacrity"]).is_true()
		assert_int(int(DramgidSchemaScript.SKILLS[skill_id]["loom"])).is_equal(DramgidSchemaScript.LoomSensitivity.NONE)
		assert_int(service.loom_penalty(skill_id, null)).is_equal(0)
		assert_str(str(DramgidSchemaScript.SKILLS[skill_id]["source"])).is_equal("sm-chargen-proposal")


func test_one_intuition_tone_per_wheel_element_with_opposites() -> void:
	for element: StringName in ElementWheel.ORDER:
		var skill_id := DramgidSchemaScript.tone_skill_for(element)
		assert_str(skill_id).is_equal("tone_%s" % element)
		assert_bool(DramgidSchemaScript.is_tone_skill(skill_id)).is_true()
		assert_str(DramgidSchemaScript.governing_attribute(skill_id)).is_equal("intuition")
		assert_int(int(DramgidSchemaScript.SKILLS[skill_id]["loom"])).is_equal(DramgidSchemaScript.LoomSensitivity.NONE)
		assert_str(DramgidSchemaScript.element_for_tone(skill_id)).is_equal(String(element))
		assert_str(DramgidSchemaScript.opposed_tone(skill_id)).is_equal(
			DramgidSchemaScript.tone_skill_for(ElementWheel.opposite(element)))
	assert_str(DramgidSchemaScript.opposed_tone("tone_khash")).is_equal("tone_luth")
	assert_str(DramgidSchemaScript.tone_skill_for("")).is_equal("")
	assert_str(DramgidSchemaScript.tone_skill_for("Khash")).is_equal("tone_khash")
	assert_str(DramgidSchemaScript.opposed_tone("recall")).is_equal("")


func test_creation_pool_and_attribute_aliases() -> void:
	assert_int(DramgidSchemaScript.creation_skill_pool(DramgidSchemaScript.default_attributes())).is_equal(
		DramgidSchemaScript.CREATION_POOL_BASE + 4)
	assert_int(DramgidSchemaScript.creation_skill_pool({"reason": 5, "decorum": 3}, 1)).is_equal(
		DramgidSchemaScript.CREATION_POOL_BASE + 9)
	assert_str(DramgidSchemaScript.canonical_attribute_id("forge")).is_equal("muster")
	assert_str(DramgidSchemaScript.canonical_attribute_id("muster")).is_equal("muster")
	assert_str(DramgidSchemaScript.canonical_attribute_id("nope")).is_equal("")
	assert_str(DramgidSchemaScript.legacy_attribute_id("muster")).is_equal("forge")
	assert_str(DramgidSchemaScript.legacy_attribute_id("doctrine")).is_equal("")


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
