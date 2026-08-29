extends GdUnitTestSuite

const QuestAudit := preload("res://tools/quest_audit.gd")
const DIALOGUE_PATH := "res://dialogue/dom_side_quests.dialogue"
const DIALOGUE_TITLE := "dom_side_dishonest_casks_hub"
const CHECKED_RESPONSE_TEXT := "Three truths are enough to trace the casks."


func before_test() -> void:
	GameState.flags.clear()
	GameState.party.clear()
	GameState._seed_demo_data()
	QuestRegistry.reset()
	QuestRegistry.offer_side_quest(QuestRegistry.DISHONEST_CASKS)
	SkillCheck._check_log.clear()
	_configure_persuasion(95.0)


func test_building_checked_choice_consumes_no_rng_or_check_log_entry() -> void:
	var resource := load(DIALOGUE_PATH) as DialogueResource
	var rng_state_before: int = SkillCheck.random_number_generator.state
	var log_size_before := SkillCheck.recent_checks().size()

	var response: DialogueResponse = await _checked_response(resource)

	assert_object(response).is_not_null()
	assert_bool(response.is_allowed).is_true()
	assert_int(SkillCheck.random_number_generator.state).is_equal(rng_state_before)
	assert_int(SkillCheck.recent_checks().size()).is_equal(log_size_before)


func test_selecting_checked_response_commits_exactly_one_check() -> void:
	var resource := load(DIALOGUE_PATH) as DialogueResource
	var response: DialogueResponse = await _checked_response(resource)
	var log_size_before := SkillCheck.recent_checks().size()
	SkillCheck.random_number_generator.seed = _successful_seed()

	await DialogueManager.get_next_dialogue_line(resource, response.next_id)

	assert_int(SkillCheck.recent_checks().size()).is_equal(log_size_before + 1)
	var latest_check: Dictionary = SkillCheck.recent_checks().back()
	# The authored difficulty gates availability only; the committed roll is
	# against effective skill, so the log records skill + rolls, not difficulty.
	assert_str(str(latest_check.get("skill"))).is_equal("persuasion")


func test_checked_response_success_and_failure_keep_quest_completable() -> void:
	var resource := load(DIALOGUE_PATH) as DialogueResource
	var success_response: DialogueResponse = await _checked_response(resource)
	SkillCheck.random_number_generator.seed = _successful_seed()
	await DialogueManager.get_next_dialogue_line(resource, success_response.next_id)
	assert_bool(GameState.flag_is_true("dom_dishonest_casks_traced")).is_true()
	assert_bool(GameState.flag_is_true("dom_dishonest_casks_check_failed")).is_false()

	before_test()
	resource = load(DIALOGUE_PATH) as DialogueResource
	var failure_response: DialogueResponse = await _checked_response(resource)
	_configure_persuasion(0.0)
	await DialogueManager.get_next_dialogue_line(resource, failure_response.next_id)
	assert_bool(GameState.flag_is_true("dom_dishonest_casks_traced")).is_false()
	assert_bool(GameState.flag_is_true("dom_dishonest_casks_check_failed")).is_true()

	var fallback: DialogueResponse = await _response_containing(resource, DIALOGUE_TITLE, "Return to Arvek's mark")
	assert_object(fallback).is_not_null()
	assert_bool(fallback.is_allowed).is_true()
	await DialogueManager.get_next_dialogue_line(resource, fallback.next_id)
	assert_bool(GameState.flag_is_true("dom_dishonest_casks_traced")).is_false()

	var original_route: DialogueResponse = await _response_containing(
		resource, DIALOGUE_TITLE, "Arvek's mark and the forge tally agree"
	)
	assert_object(original_route).is_not_null()
	assert_bool(original_route.is_allowed).is_true()
	await DialogueManager.get_next_dialogue_line(resource, original_route.next_id)
	assert_bool(GameState.flag_is_true("dom_dishonest_casks_traced")).is_true()


func test_check_softlock_audit_rejects_violation_and_accepts_worked_example() -> void:
	var violating_source := """~ test_quest_hub
- \"Try the shortcut.\" [if check(\"persuasion\", 45) /]
	=> END
"""
	var violating_findings: Array[Dictionary] = QuestAudit.check_softlock_violations(
		{"res://synthetic/violating.dialogue": violating_source}
	)
	var codes := PackedStringArray()
	for finding: Dictionary in violating_findings:
		codes.append(str(finding.get("code", "")))
	assert_array(codes).contains(["checked_response_missing_resolve", "checked_response_missing_outcomes"])

	var ending_only_source := """~ test_quest_hub
- \"Try the shortcut.\" [if QuestRegistry.is_active(QuestRegistry.DISHONEST_CASKS) and check(\"persuasion\", 45) /]
	do SkillCheck.resolve(\"persuasion\", 45)
	if SkillCheck.last_check_succeeded()
		=> END
	else
		=> END
- \"Resolve the quest.\" [if QuestRegistry.is_active(QuestRegistry.DISHONEST_CASKS) and QuestRegistry.flags_met(QuestRegistry.DISHONEST_CASKS) /]
	do QuestRegistry.resolve_side_quest(QuestRegistry.DISHONEST_CASKS, \"done\")
	=> END
"""
	var ending_findings: Array[Dictionary] = QuestAudit.check_softlock_violations(
		{"res://synthetic/ending-only.dialogue": ending_only_source}
	)
	var ending_codes := PackedStringArray()
	for finding: Dictionary in ending_findings:
		ending_codes.append(str(finding.get("code", "")))
	assert_array(ending_codes).contains(
		["checked_response_missing_outcomes", "checked_response_may_be_only_acquisition_route"]
	)

	var worked_source := FileAccess.get_file_as_string(DIALOGUE_PATH)
	var worked_findings: Array[Dictionary] = QuestAudit.check_softlock_violations(
		{DIALOGUE_PATH: worked_source}
	)
	assert_array(worked_findings).is_empty()


func _checked_response(resource: DialogueResource) -> DialogueResponse:
	return await _response_containing(resource, DIALOGUE_TITLE, CHECKED_RESPONSE_TEXT)


func _response_containing(
	resource: DialogueResource, title: String, response_text: String
) -> DialogueResponse:
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, title)
	assert_object(line).is_not_null()
	if line == null:
		return null
	for response: DialogueResponse in line.responses:
		if response.text.contains(response_text):
			return response
	fail("No response containing '%s' at dialogue title '%s'." % [response_text, title])
	return null


func _configure_persuasion(advancement: float) -> void:
	var member := GameState.protagonist()
	assert_object(member).is_not_null()
	member.attributes["voice"] = 0
	member.skill_tiers["persuasion"] = "untrained"
	member.skill_percentages["persuasion"] = advancement


func _successful_seed() -> int:
	var probe := RandomNumberGenerator.new()
	for candidate in range(1, 1000):
		probe.seed = candidate
		if probe.randi_range(1, 100) <= 95:
			return candidate
	return 1
