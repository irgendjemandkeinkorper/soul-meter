extends GdUnitTestSuite
## Dedicated coverage for globals/fact_requirement.gd (issue #70).

var original_flags: Dictionary
var original_quests: Dictionary
var original_party: Array[PartyMember]


func before_test() -> void:
	original_flags = GameState.flags.duplicate(true)
	original_quests = QuestRegistry.to_dict().duplicate(true)
	original_party = GameState.party.duplicate()
	GameState.flags.clear()
	QuestRegistry.reset()


func after_test() -> void:
	QuestRegistry.reset()
	QuestRegistry.from_dict(original_quests)
	GameState.flags = original_flags
	GameState.party = original_party


func test_default_type_is_companions_selected_and_always_valid() -> void:
	var req := FactRequirement.new()
	assert_int(req.type).is_equal(FactRequirement.Type.COMPANIONS_SELECTED)
	assert_bool(req.is_valid()).is_true()


func test_companions_selected_tracks_game_state() -> void:
	var req := FactRequirement.new()
	req.type = FactRequirement.Type.COMPANIONS_SELECTED
	GameState.party.clear()
	assert_bool(req.is_met()).is_false()

	var candidates := GameState.recruitable_candidates()
	GameState.set_companions([candidates[0], candidates[1]])
	assert_bool(req.is_met()).is_true()


func test_quest_active_requires_a_target_quest_and_tracks_the_active_pool() -> void:
	var req := FactRequirement.new()
	req.type = FactRequirement.Type.QUEST_ACTIVE
	req.target_quest = null
	assert_bool(req.is_valid()).is_false()
	assert_bool(req.is_met()).is_false()

	req.target_quest = QuestRegistry.FIELD_DEBT
	assert_bool(req.is_valid()).is_true()
	assert_bool(req.is_met()).is_false()

	QuestRegistry.offer(QuestRegistry.FIELD_DEBT)
	assert_bool(req.is_met()).is_true()


func test_quest_done_requires_a_target_quest_and_tracks_completion() -> void:
	var req := FactRequirement.new()
	req.type = FactRequirement.Type.QUEST_DONE
	req.target_quest = QuestRegistry.FIELD_DEBT
	assert_bool(req.is_met()).is_false()

	QuestRegistry.offer(QuestRegistry.FIELD_DEBT)
	for flag in QuestRegistry.FIELD_DEBT.required_flags:
		GameState.set_flag(flag, true)
	QuestRegistry.turn_in(QuestRegistry.FIELD_DEBT)

	assert_bool(req.is_met()).is_true()


func test_quest_flags_met_tracks_the_quests_own_required_flags() -> void:
	var req := FactRequirement.new()
	req.type = FactRequirement.Type.QUEST_FLAGS_MET
	req.target_quest = QuestRegistry.FIELD_DEBT
	assert_bool(req.is_met()).is_false()

	for flag in QuestRegistry.FIELD_DEBT.required_flags:
		GameState.set_flag(flag, true)
	assert_bool(req.is_met()).is_true()


func test_flag_true_requires_a_non_empty_target_flag_and_reads_it_as_a_bool() -> void:
	var req := FactRequirement.new()
	req.type = FactRequirement.Type.FLAG_TRUE
	req.target_flag = ""
	assert_bool(req.is_valid()).is_false()
	assert_bool(req.is_met()).is_false()

	req.target_flag = "some_test_flag"
	assert_bool(req.is_valid()).is_true()
	assert_bool(req.is_met()).is_false()

	GameState.set_flag("some_test_flag", true)
	assert_bool(req.is_met()).is_true()

	GameState.set_flag("some_test_flag", false)
	assert_bool(req.is_met()).is_false()


func test_flag_non_empty_treats_the_unset_default_and_empty_string_as_unmet() -> void:
	var req := FactRequirement.new()
	req.type = FactRequirement.Type.FLAG_NON_EMPTY
	req.target_flag = "some_string_flag"
	assert_bool(req.is_met()).is_false()

	GameState.set_flag("some_string_flag", "")
	assert_bool(req.is_met()).is_false()

	GameState.set_flag("some_string_flag", "named")
	assert_bool(req.is_met()).is_true()


func test_an_out_of_range_type_is_invalid_and_never_met() -> void:
	# The `match` in is_valid()/is_met() has no default branch, so a type value
	# outside the enum must fall through to the trailing `return false` rather
	# than silently behaving like COMPANIONS_SELECTED (enum value 0).
	var req := FactRequirement.new()
	req.type = 99
	assert_bool(req.is_valid()).is_false()
	assert_bool(req.is_met()).is_false()


func test_every_quest_backed_type_refuses_a_null_target_quest() -> void:
	for quest_type: int in [
		FactRequirement.Type.QUEST_ACTIVE,
		FactRequirement.Type.QUEST_DONE,
		FactRequirement.Type.QUEST_FLAGS_MET,
	]:
		var req := FactRequirement.new()
		req.type = quest_type
		req.target_quest = null
		assert_bool(req.is_valid()).is_false()
		assert_bool(req.is_met()).is_false()


func test_every_flag_backed_type_refuses_an_empty_target_flag() -> void:
	for flag_type: int in [
		FactRequirement.Type.FLAG_TRUE,
		FactRequirement.Type.FLAG_NON_EMPTY,
	]:
		var req := FactRequirement.new()
		req.type = flag_type
		req.target_flag = ""
		assert_bool(req.is_valid()).is_false()
		assert_bool(req.is_met()).is_false()


func test_companions_selected_ignores_target_fields_entirely() -> void:
	# COMPANIONS_SELECTED is unconditionally valid: a stale target_quest or
	# target_flag left over from an edited resource must not gate it.
	var req := FactRequirement.new()
	req.type = FactRequirement.Type.COMPANIONS_SELECTED
	req.target_quest = null
	req.target_flag = ""
	assert_bool(req.is_valid()).is_true()

	GameState.party.clear()
	assert_bool(req.is_met()).is_false()


func test_flag_true_coerces_numeric_flag_values() -> void:
	# Flags are Variant, so FLAG_TRUE is a truthiness test, not a type check.
	#
	# ⚠ NOT COVERED, DELIBERATELY: a String-valued flag. is_met() calls
	# bool(...) on the flag, and Godot 4 has no bool(String) constructor — a
	# FLAG_TRUE requirement pointed at a string-valued flag raises
	# "Nonexistent 'bool' constructor" at runtime instead of returning a value.
	# Reported for a decision rather than encoded here as expected behaviour.
	var req := FactRequirement.new()
	req.type = FactRequirement.Type.FLAG_TRUE
	req.target_flag = "coerced_flag"

	GameState.set_flag("coerced_flag", 0)
	assert_bool(req.is_met()).is_false()

	GameState.set_flag("coerced_flag", 3)
	assert_bool(req.is_met()).is_true()

	GameState.set_flag("coerced_flag", 0.0)
	assert_bool(req.is_met()).is_false()


func test_flag_non_empty_is_satisfied_by_an_explicitly_false_flag() -> void:
	# ⚠ DOCUMENTS CURRENT BEHAVIOUR, NOT AN ENDORSEMENT.
	# is_met() stringifies the flag: str(false) == "false", which is not empty,
	# so a flag deliberately set to false satisfies FLAG_NON_EMPTY. Only the
	# never-set case (default "") and the empty string are treated as unmet.
	# Reported as a design question rather than fixed — narrowing this would
	# change gating behaviour for any authored content relying on it.
	var req := FactRequirement.new()
	req.type = FactRequirement.Type.FLAG_NON_EMPTY
	req.target_flag = "tri_state_flag"

	assert_bool(req.is_met()).is_false()

	GameState.set_flag("tri_state_flag", false)
	assert_bool(req.is_met()).is_true()


func test_an_invalid_requirement_is_never_met_regardless_of_type() -> void:
	var quest_active_req := FactRequirement.new()
	quest_active_req.type = FactRequirement.Type.QUEST_ACTIVE
	assert_bool(quest_active_req.is_met()).is_false()

	var flag_req := FactRequirement.new()
	flag_req.type = FactRequirement.Type.FLAG_TRUE
	assert_bool(flag_req.is_met()).is_false()
