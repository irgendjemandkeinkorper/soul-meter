extends GdUnitTestSuite
## Calling and measures S2: MeasureEffects says what each measure does, in the numbers the
## code that uses them in play produces — never a second copy of a formula.


func test_every_measure_says_something_at_every_value() -> void:
	for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
		for value in range(DramgidSchema.ATTRIBUTE_FLOOR, DramgidSchema.ATTRIBUTE_CAP + 1):
			assert_str(MeasureEffects.summary(attribute_id, value)).override_failure_message(
				"%s %d" % [attribute_id, value]).is_not_empty()


func test_the_numbers_are_the_ones_play_uses() -> void:
	var rules := load("res://data/combat/combat_rules.tres") as CombatRules
	for value in range(DramgidSchema.ATTRIBUTE_FLOOR, DramgidSchema.ATTRIBUTE_CAP + 1):
		var actor := BattleActor.new()
		actor.attributes = {"reason": value}
		assert_int(MeasureEffects.turn_speed(value)).is_equal(rules.charge_speed_for(actor))
		assert_str(MeasureEffects.summary("grit", value)).contains("HP %d" % DramgidDerived.max_hp(value))
		assert_str(MeasureEffects.summary("intuition", value)).contains("Breath %d" % DramgidDerived.breath_max(value))
		assert_str(MeasureEffects.summary("muster", value)).contains("Weapon attack %d" % DramgidDerived.attack(value))
		var member := PartyMember.new()
		member.attributes = {"reason": value}
		assert_int(MeasureEffects.skill_base(value)).is_equal(roundi(SkillCheck.preview("recall", member)))
	assert_str(MeasureEffects.summary("doctrine", 2)).contains("×0.4")
	assert_str(MeasureEffects.summary("doctrine", 5)).contains("×1.0")


func test_the_next_point_names_only_what_moves_and_stops_at_the_cap() -> void:
	assert_str(MeasureEffects.next_point("grit", 3)).contains("HP %d" % DramgidDerived.max_hp(4))
	assert_str(MeasureEffects.next_point("grit", 3)).not_contains("HP %d" % DramgidDerived.max_hp(3))
	assert_str(MeasureEffects.next_point("grit", DramgidSchema.ATTRIBUTE_CAP)).is_empty()
	# Doctrine has no skills, so a point moves only Karma.
	assert_str(MeasureEffects.next_point("doctrine", 2)).is_equal("Karma moves ×0.6")


func test_the_patron_line_rides_only_the_classes_own_measure() -> void:
	assert_str(MeasureEffects.summary("reason", 4, "lensbearer")).contains("Lensbearer: 4 Clarity each battle")
	assert_str(MeasureEffects.summary("decorum", 4, "lensbearer")).not_contains("Lensbearer")
	assert_str(MeasureEffects.next_point("reason", 3, "lensbearer")).contains("4 Clarity each battle")
	assert_str(MeasureEffects.next_point("reason", 2, "lensbearer")).override_failure_message(
		"2 → 3 changes no class loop").not_contains("Clarity")
	for row: Dictionary in ClassCatalog.ALL:
		var class_id := str(row["id"])
		var ladder := MeasureEffects.patron_ladder(class_id, 3)
		assert_str(ladder).override_failure_message(class_id).contains("At 4:")
		assert_str(ladder).override_failure_message(class_id).contains("At 5:")
		assert_str(MeasureEffects.patron_ladder(class_id, 5)).override_failure_message(class_id).not_contains("At ")
