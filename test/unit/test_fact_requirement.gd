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


func test_an_invalid_requirement_is_never_met_regardless_of_type() -> void:
	var quest_active_req := FactRequirement.new()
	quest_active_req.type = FactRequirement.Type.QUEST_ACTIVE
	assert_bool(quest_active_req.is_met()).is_false()

	var flag_req := FactRequirement.new()
	flag_req.type = FactRequirement.Type.FLAG_TRUE
	assert_bool(flag_req.is_met()).is_false()
