extends GdUnitTestSuite
## Canon-review gate coverage for the companion-quest resolver contract.
## Dialogue chooses authored outcome data; QuestRegistry owns every mutation.

var _original_party: Array[PartyMember]
var _original_flags: Dictionary
var _original_renown: Dictionary
var _original_quests: Dictionary


func before_test() -> void:
	_original_party = GameState.party.duplicate()
	_original_flags = GameState.flags.duplicate(true)
	_original_renown = Renown.to_dict().duplicate(true)
	_original_quests = QuestRegistry.to_dict().duplicate(true)
	_reset_case()


func after_test() -> void:
	GameState.party = _original_party
	GameState.flags = _original_flags
	Renown.from_dict(_original_renown)
	QuestRegistry.reset()
	QuestRegistry.from_dict(_original_quests)


func test_all_authored_dialogue_branches_resolve_with_exactly_one_consequence() -> void:
	for branch_case: Dictionary in _branch_cases():
		_reset_case()
		var quest: FlagQuest = branch_case["quest"] as FlagQuest
		QuestRegistry.offer(quest)

		var resource: DialogueResource = load(String(branch_case["path"])) as DialogueResource
		assert_object(resource).is_not_null()
		if resource == null:
			continue
		await _execute_branch(
			resource,
			String(branch_case["prompt"]),
			String(branch_case["choice"])
		)

		var label: String = String(branch_case["label"])
		assert_bool(GameState.flag_is_true(String(branch_case["flag"]))).override_failure_message(
			"%s did not set its completion flag" % label
		).is_true()
		assert_bool(QuestRegistry.is_done(quest)).override_failure_message(
			"%s did not complete its quest" % label
		).is_true()
		var completed: Array = QuestRegistry.to_dict().get("completed", []) as Array
		assert_int(completed.size()).override_failure_message(
			"%s completed an unexpected number of quests" % label
		).is_equal(1)

		var events: Array[RenownEvent] = Renown.why(&"reputation", 20)
		assert_int(events.size()).override_failure_message(
			"%s wrote an unexpected number of Renown entries" % label
		).is_equal(1)
		if events.size() != 1:
			continue
		assert_float(events[0].delta).override_failure_message(
			"%s wrote the wrong Renown delta" % label
		).is_equal_approx(float(branch_case["delta"]), 0.001)
		assert_str(events[0].cause).override_failure_message(
			"%s wrote the wrong Renown cause" % label
		).is_equal(String(branch_case["cause"]))
		assert_str(events[0].actor).is_equal("player")
		assert_str(events[0].scene).is_equal("party")


func test_rejections_leave_flags_quest_state_and_append_only_ledger_untouched() -> void:
	var cases: Array[Dictionary] = [
		{
			"label": "wrong companion id",
			"setup": "active",
			"companion_id": "old-grumbrand",
			"delta": 6.0,
			"cause": "Told Serai-Lun the line matters with or without a witness",
		},
		{
			"label": "inactive quest",
			"setup": "inactive",
			"companion_id": "serai-lun",
			"delta": 6.0,
			"cause": "Told Serai-Lun the line matters with or without a witness",
		},
		{
			"label": "completed quest",
			"setup": "done",
			"companion_id": "serai-lun",
			"delta": 6.0,
			"cause": "Told Serai-Lun the line matters with or without a witness",
		},
		{
			"label": "invalid outcome contract",
			"setup": "active",
			"companion_id": "serai-lun",
			"delta": 0.0,
			"cause": "",
		},
	]

	for rejection_case: Dictionary in cases:
		_reset_case()
		_setup_rejection_state(String(rejection_case["setup"]))
		var flags_before: Dictionary = GameState.flags.duplicate(true)
		var quests_before: Dictionary = QuestRegistry.to_dict().duplicate(true)
		var renown_before: Dictionary = Renown.to_dict().duplicate(true)

		var accepted: bool = QuestRegistry.resolve_companion_quest(
			String(rejection_case["companion_id"]),
			QuestRegistry.SERAI_LUN_QUEST,
			float(rejection_case["delta"]),
			String(rejection_case["cause"])
		)
		var label: String = String(rejection_case["label"])
		assert_bool(accepted).override_failure_message("%s was accepted" % label).is_false()
		assert_dict(GameState.flags).override_failure_message(
			"%s mutated completion flags" % label
		).is_equal(flags_before)
		assert_dict(QuestRegistry.to_dict()).override_failure_message(
			"%s mutated quest state" % label
		).is_equal(quests_before)
		assert_dict(Renown.to_dict()).override_failure_message(
			"%s rewrote or appended to the Renown ledger" % label
		).is_equal(renown_before)


func test_valid_resolution_can_retry_after_contract_rejection() -> void:
	QuestRegistry.offer(QuestRegistry.SERAI_LUN_QUEST)
	var rejected: bool = QuestRegistry.resolve_companion_quest(
		"serai-lun", QuestRegistry.SERAI_LUN_QUEST, 0.0, ""
	)
	assert_bool(rejected).is_false()
	assert_bool(GameState.flag_is_true("party_serai_lun_resolved")).is_false()
	assert_bool(QuestRegistry.is_active(QuestRegistry.SERAI_LUN_QUEST)).is_true()
	assert_array(Renown.why(&"reputation", 20)).is_empty()

	var accepted: bool = QuestRegistry.resolve_companion_quest(
		"serai-lun",
		QuestRegistry.SERAI_LUN_QUEST,
		6.0,
		"Told Serai-Lun the line matters with or without a witness"
	)
	assert_bool(accepted).is_true()
	assert_bool(GameState.flag_is_true("party_serai_lun_resolved")).is_true()
	assert_bool(QuestRegistry.is_done(QuestRegistry.SERAI_LUN_QUEST)).is_true()
	assert_int(Renown.why(&"reputation", 20).size()).is_equal(1)


func test_dialogue_reentry_after_resolution_is_idempotent() -> void:
	QuestRegistry.offer(QuestRegistry.SERAI_LUN_QUEST)
	var resource: DialogueResource = load(
		"res://dialogue/companions/serai_lun.dialogue"
	) as DialogueResource
	assert_object(resource).is_not_null()
	if resource == null:
		return
	await _execute_branch(
		resource,
		"What line are you watching?",
		"I hold it because it's right"
	)
	var flags_before: Dictionary = GameState.flags.duplicate(true)
	var quests_before: Dictionary = QuestRegistry.to_dict().duplicate(true)
	var renown_before: Dictionary = Renown.to_dict().duplicate(true)

	var hub: DialogueLine = await _line_with_responses(resource, "hub")
	var acknowledgement: DialogueResponse = _find_allowed_response(
		hub, "Thank you for telling me that."
	)
	assert_object(acknowledgement).is_not_null()
	if acknowledgement != null:
		var reentry_line: DialogueLine = await DialogueManager.get_next_dialogue_line(
			resource, acknowledgement.next_id
		)
		assert_object(reentry_line).is_not_null()

	assert_dict(GameState.flags).is_equal(flags_before)
	assert_dict(QuestRegistry.to_dict()).is_equal(quests_before)
	assert_dict(Renown.to_dict()).is_equal(renown_before)


func test_dialogues_do_not_write_completion_flags_directly() -> void:
	var checked_paths: Dictionary = {}
	for branch_case: Dictionary in _branch_cases():
		var path: String = String(branch_case["path"])
		if checked_paths.has(path):
			continue
		checked_paths[path] = true
		var source: String = FileAccess.get_file_as_string(path)
		assert_str(source).override_failure_message(path).not_contains(
			"GameState.set_flag(\"%s\", true)" % String(branch_case["flag"])
		)
		assert_int(source.count("QuestRegistry.resolve_companion_quest(")).is_equal(2)


func _reset_case() -> void:
	GameState.flags.clear()
	Renown.from_dict({})
	QuestRegistry.reset()


func _setup_rejection_state(state: String) -> void:
	if state == "inactive":
		return
	QuestRegistry.offer(QuestRegistry.SERAI_LUN_QUEST)
	if state == "done":
		var completed: bool = QuestRegistry.resolve_companion_quest(
			"serai-lun",
			QuestRegistry.SERAI_LUN_QUEST,
			6.0,
			"Told Serai-Lun the line matters with or without a witness"
		)
		assert_bool(completed).is_true()


func _execute_branch(
	resource: DialogueResource, prompt_text: String, choice_text: String
) -> void:
	var hub: DialogueLine = await _line_with_responses(resource, "hub")
	var prompt: DialogueResponse = _find_allowed_response(hub, prompt_text)
	assert_object(prompt).is_not_null()
	if prompt == null:
		return
	var choices: DialogueLine = await _line_with_responses(resource, prompt.next_id)
	var choice: DialogueResponse = _find_allowed_response(choices, choice_text)
	assert_object(choice).is_not_null()
	if choice == null:
		return
	var terminal: DialogueLine = await DialogueManager.get_next_dialogue_line(
		resource, choice.next_id
	)
	assert_object(terminal).is_not_null()


func _line_with_responses(resource: DialogueResource, title: String) -> DialogueLine:
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, title)
	var steps: int = 0
	while line != null and line.responses.is_empty() and steps < 20:
		if line.next_id.is_empty() or line.next_id.contains("end"):
			break
		line = await DialogueManager.get_next_dialogue_line(resource, line.next_id)
		steps += 1
	assert_object(line).is_not_null()
	if line != null:
		assert_array(line.responses).is_not_empty()
	return line


func _find_allowed_response(line: DialogueLine, text: String) -> DialogueResponse:
	if line == null:
		return null
	for response: DialogueResponse in line.responses:
		if response.is_allowed and response.text.contains(text):
			return response
	fail("No allowed response containing '%s'." % text)
	return null


func _branch_cases() -> Array[Dictionary]:
	return [
		{
			"label": "Serai-Lun / principle",
			"path": "res://dialogue/companions/serai_lun.dialogue",
			"quest": QuestRegistry.SERAI_LUN_QUEST,
			"flag": "party_serai_lun_resolved",
			"prompt": "What line are you watching?",
			"choice": "I hold it because it's right",
			"delta": 6.0,
			"cause": "Told Serai-Lun the line matters with or without a witness",
		},
		{
			"label": "Serai-Lun / witness",
			"path": "res://dialogue/companions/serai_lun.dialogue",
			"quest": QuestRegistry.SERAI_LUN_QUEST,
			"flag": "party_serai_lun_resolved",
			"prompt": "What line are you watching?",
			"choice": "I hold it because someone has to keep score.",
			"delta": 3.0,
			"cause": "Told Serai-Lun she keeps you honest",
		},
		{
			"label": "Wyneth / public roll",
			"path": "res://dialogue/companions/wyneth_hallow_tide.dialogue",
			"quest": QuestRegistry.WYNETH_QUEST,
			"flag": "party_wyneth_resolved",
			"prompt": "Whose name is it?",
			"choice": "Put him on the wall.",
			"delta": 6.0,
			"cause": "Told Wyneth to give the muster-roll her kept name",
		},
		{
			"label": "Wyneth / private ledger",
			"path": "res://dialogue/companions/wyneth_hallow_tide.dialogue",
			"quest": QuestRegistry.WYNETH_QUEST,
			"flag": "party_wyneth_resolved",
			"prompt": "Whose name is it?",
			"choice": "Keep him in your ledger.",
			"delta": 6.0,
			"cause": "Told Wyneth her private ledger was enough",
		},
		{
			"label": "Grumbrand / true reading",
			"path": "res://dialogue/companions/old_grumbrand.dialogue",
			"quest": QuestRegistry.GRUMBRAND_QUEST,
			"flag": "party_grumbrand_resolved",
			"prompt": "What does it mean?",
			"choice": "Let them read you.",
			"delta": 6.0,
			"cause": "Told Grumbrand to let the Lensbearer College read him true",
		},
		{
			"label": "Grumbrand / silence",
			"path": "res://dialogue/companions/old_grumbrand.dialogue",
			"quest": QuestRegistry.GRUMBRAND_QUEST,
			"flag": "party_grumbrand_resolved",
			"prompt": "What does it mean?",
			"choice": "Keep it yours.",
			"delta": 6.0,
			"cause": "Told Grumbrand his silence was mercy enough",
		},
		{
			"label": "Ressa / opening",
			"path": "res://dialogue/companions/ressa_quickfingers.dialogue",
			"quest": QuestRegistry.RESSA_QUEST,
			"flag": "party_ressa_quickfingers_resolved",
			"prompt": "How should you judge an opening?",
			"choice": "Take the opening while it exists.",
			"delta": 6.0,
			"cause": "Told Ressa to take the opening before it closes",
		},
		{
			"label": "Ressa / protect party",
			"path": "res://dialogue/companions/ressa_quickfingers.dialogue",
			"quest": QuestRegistry.RESSA_QUEST,
			"flag": "party_ressa_quickfingers_resolved",
			"prompt": "How should you judge an opening?",
			"choice": "Close it when the party would pay.",
			"delta": 6.0,
			"cause": "Told Ressa to protect the party before taking an opening",
		},
		{
			"label": "Korrath / challenge first",
			"path": "res://dialogue/companions/korrath_ninefold.dialogue",
			"quest": QuestRegistry.KORRATH_QUEST,
			"flag": "party_korrath_ninefold_resolved",
			"prompt": "What should happen when you dispute an order?",
			"choice": "Challenge me before we move.",
			"delta": 6.0,
			"cause": "Told Korrath to challenge a disputed command before acting",
		},
		{
			"label": "Korrath / carry first",
			"path": "res://dialogue/companions/korrath_ninefold.dialogue",
			"quest": QuestRegistry.KORRATH_QUEST,
			"flag": "party_korrath_ninefold_resolved",
			"prompt": "What should happen when you dispute an order?",
			"choice": "Carry it first and challenge me after.",
			"delta": 6.0,
			"cause": "Told Korrath to carry the command and demand an accounting after",
		},
		{
			"label": "Maura / present conduct",
			"path": "res://dialogue/companions/maura_greyfen.dialogue",
			"quest": QuestRegistry.MAURA_QUEST,
			"flag": "party_maura_greyfen_resolved",
			"prompt": "What should decide your trust now?",
			"choice": "Judge what I do now.",
			"delta": 6.0,
			"cause": "Told Maura to judge trust by present conduct",
		},
		{
			"label": "Maura / reputation",
			"path": "res://dialogue/companions/maura_greyfen.dialogue",
			"quest": QuestRegistry.MAURA_QUEST,
			"flag": "party_maura_greyfen_resolved",
			"prompt": "What should decide your trust now?",
			"choice": "Keep the name as a warning.",
			"delta": 6.0,
			"cause": "Told Maura to keep reputation in her judgment",
		},
	]
