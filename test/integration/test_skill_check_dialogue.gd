extends GdUnitTestSuite


var original_party: Array[PartyMember]


func before_test() -> void:
	original_party = GameState.party.duplicate()


func after_test() -> void:
	GameState.party = original_party


func test_dialogue_condition_uses_skill_check_autoload() -> void:
	var member := PartyMember.new()
	member.id = GameState.PROTAGONIST_ID
	member.attributes["spark"] = 6
	GameState.party = [member]

	var resource: DialogueResource = load("res://test/integration/skill_check_condition.dialogue")
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, "start")

	assert_int(line.responses.size()).is_equal(2)
	assert_bool(line.responses[0].is_allowed).is_true()

	member.attributes["spark"] = 4
	line = await DialogueManager.get_next_dialogue_line(resource, "start")

	assert_bool(line.responses[0].is_allowed).is_false()
	assert_bool(line.responses[1].is_allowed).is_true()
