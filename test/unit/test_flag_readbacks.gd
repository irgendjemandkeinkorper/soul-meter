extends GdUnitTestSuite
## Quest-trigger read-backs (#246 rule): a flag a check or a question writes is
## heard back somewhere in the world. These three were written into silence
## until 2026-10-19; `tools/quest_audit.gd` lists them under orphaned_flags
## again the day one of these routes is removed.

const COUNCIL_ELDER := "res://dialogue/council_elder.dialogue"
const TOMA := "res://dialogue/toma_reedhand.dialogue"
const MARSHAL := "res://dialogue/marshal_coiljaw.dialogue"
const IRIS := "res://dialogue/iris_illepah.dialogue"

var _flags_before: Dictionary


func before_test() -> void:
	_flags_before = GameState.flags.duplicate(true)
	GameState.flags.clear()
	QuestRegistry.reset()


func after_test() -> void:
	GameState.flags = _flags_before
	QuestRegistry.reset()


func test_gaath_hears_back_whether_the_charge_was_understood() -> void:
	QuestSystem.completed.add_quest(QuestRegistry.DORTHKOR_ROAD)
	var resource := load(COUNCIL_ELDER) as DialogueResource

	GameState.set_flag("chapter_council_charge_understood", true)
	var understood := await _line_after(resource, "charge", "The Dorthkor charge is finished.")
	assert_str(understood.text).contains("You asked what truth mattered")

	GameState.set_flag("chapter_council_charge_understood", false)
	var plain := await _line_after(resource, "charge", "The Dorthkor charge is finished.")
	assert_str(plain.text).contains("the benches will argue")
	assert_str(plain.text).not_contains("You asked what truth mattered")


func test_toma_hears_back_whether_the_shrine_was_asked_about() -> void:
	var resource := load(TOMA) as DialogueResource
	GameState.set_flag("dom_shrine_visited", true)

	GameState.set_flag("dom_shrine_asked", true)
	var asked := await _line_after(resource, "hub", "I left a word at the shrine.")
	assert_str(asked.text).contains("You asked what it remembers first")

	GameState.set_flag("dom_shrine_asked", false)
	var unasked := await _line_after(resource, "hub", "I left a word at the shrine.")
	assert_str(unasked.text).contains("Without asking what it remembers?")


func test_marshal_reads_the_muster_cause_back_from_the_roll() -> void:
	var resource := load(MARSHAL) as DialogueResource
	var before_report := await _allowed_response(resource, "hub", "How will the roll record")
	assert_object(before_report).is_null()

	GameState.set_flag("reported_bloodbellow", true)
	GameState.set_flag("dorthkor_muster_cause", "Destroyed the Bloodbellow by force")
	var line := await _line_after(resource, "hub", "How will the roll record")
	assert_str(line.text).contains("Destroyed the Bloodbellow by force")
	assert_str(line.text).not_contains("{{")


func test_marshal_reads_the_field_debt_reward_back() -> void:
	var resource := load(MARSHAL) as DialogueResource
	var before_done := await _allowed_response(resource, "hub", "What did the field proof buy")
	assert_object(before_done).is_null()

	# Done implies the flag: resolve_field_debt / FetchQuest.complete write it in the
	# same call, so "done, no flag" is not a state the game produces and is not probed.
	QuestSystem.completed.add_quest(QuestRegistry.FIELD_DEBT)

	var expected := {
		"companies": "road roster",
		"seeders": "night in the grove",
		"registry": "numbered drawer",
		"balance": "same small entry",
	}
	for reward_id: String in expected:
		GameState.set_flag("field_debt_reward", reward_id)
		var line := await _line_after(resource, "hub", "What did the field proof buy")
		assert_str(line.text).override_failure_message(
			"field_debt_reward=%s heard back the wrong ledger" % reward_id
		).contains(expected[reward_id])


func test_iris_reads_the_loamroot_resolution_back() -> void:
	var resource := load(IRIS) as DialogueResource
	var before_done := await _allowed_response(resource, "hub", "How are the sprigs?")
	assert_object(before_done).is_null()

	# Done implies the flag: resolve_field_debt / FetchQuest.complete write it in the
	# same call, so "done, no flag" is not a state the game produces and is not probed.
	QuestSystem.completed.add_quest(QuestRegistry.LOAMROOT_SPRIGS)

	var expected := {
		"returned": "Rooted where they were meant to be",
		"communion": "a beat after the others",
		"registry": "three holes past the treeline",
	}
	for resolution: String in expected:
		GameState.set_flag("quest_1_resolution", resolution)
		var line := await _line_after(resource, "hub", "How are the sprigs?")
		assert_str(line.text).override_failure_message(
			"quest_1_resolution=%s heard back the wrong grove" % resolution
		).contains(expected[resolution])


func _line_after(resource: DialogueResource, title: String, response_text: String) -> DialogueLine:
	var response := await _allowed_response(resource, title, response_text)
	assert_object(response).override_failure_message(
		"No allowed response containing '%s' at '%s'." % [response_text, title]
	).is_not_null()
	if response == null:
		return null
	return await DialogueManager.get_next_dialogue_line(resource, response.next_id)


func _allowed_response(
	resource: DialogueResource, title: String, response_text: String
) -> DialogueResponse:
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, title)
	while line != null and line.responses.is_empty():
		line = await DialogueManager.get_next_dialogue_line(resource, line.next_id)
	if line == null:
		return null
	for response: DialogueResponse in line.responses:
		if response.is_allowed and response.text.contains(response_text):
			return response
	return null
