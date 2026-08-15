extends GdUnitTestSuite

var _ng_plus_before: Dictionary


func before_test() -> void:
	_ng_plus_before = SaveGame.ng_plus.duplicate(true)


func after_test() -> void:
	SaveGame.ng_plus = _ng_plus_before


func test_echo_line_is_reachable_only_in_ng_plus() -> void:
	var resource: DialogueResource = load("res://dialogue/hadrik_vale.dialogue")
	SaveGame.ng_plus = NGPlus.default_block()
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, "hub")
	var response := _response_containing(line, "reflection")
	assert_object(response).is_not_null()
	assert_bool(response.is_allowed).is_false()

	SaveGame.ng_plus["completion_metadata"] = {"chapter_completions": 1}
	line = await DialogueManager.get_next_dialogue_line(resource, "hub")
	response = _response_containing(line, "reflection")
	assert_object(response).is_not_null()
	assert_bool(response.is_allowed).is_true()


func _response_containing(line: DialogueLine, phrase: String) -> DialogueResponse:
	for response: DialogueResponse in line.responses:
		if phrase.to_lower() in response.text.to_lower():
			return response
	return null
