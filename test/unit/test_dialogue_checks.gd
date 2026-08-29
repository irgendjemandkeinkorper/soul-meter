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


func test_ash_in_the_rain_check_route_contract() -> void:
	await _assert_quest_check_route(
		{
			"quest": QuestRegistry.ASH_IN_THE_RAIN,
			"title": "dom_side_ash_in_the_rain_hub",
			"response": "The ash and the ration counts point to one demand.",
			"skill": "investigation",
			"success_flag": "dom_ash_in_the_rain_traced",
			"failure_flag": "dom_ash_in_the_rain_check_failed",
			"fallback": "Return to Veyra's ash reading and both ration counts.",
			"original": "The ash source and both ration counts are verified.",
		}
	)


func test_cold_bowl_check_route_contract() -> void:
	await _assert_quest_check_route(
		{
			"quest": QuestRegistry.COLD_BOWL,
			"title": "dom_side_cold_bowl_hub",
			"response": "Let the hound lead me to the veteran.",
			"skill": "beast_handling",
			"success_flag": "dom_cold_bowl_veteran_found",
			"failure_flag": "dom_cold_bowl_check_failed",
			"fallback": "Return with Orenna's key and Kaelra's hound.",
			"original": "The hound found the veteran beyond the locked hall.",
		}
	)


func test_fifth_echo_check_route_contract() -> void:
	await _assert_quest_check_route(
		{
			"quest": QuestRegistry.FIFTH_ECHO,
			"title": "dom_side_fifth_echo_hub",
			"response": "Test the pattern against the four-beat cadence.",
			"skill": "performance",
			"success_flag": "dom_fifth_echo_tested",
			"failure_flag": "dom_fifth_echo_check_failed",
			"fallback": "Return to Nalla, Tern, and Sorek's tests.",
			"original": "The fifth beat survives every test.",
		}
	)


func test_last_safe_course_check_route_contract() -> void:
	await _assert_quest_check_route(
		{
			"quest": QuestRegistry.LAST_SAFE_COURSE,
			"title": "dom_side_last_safe_course_hub",
			"response": "The three reports describe one safe course.",
			"skill": "survival",
			"success_flag": "dom_last_safe_course_verified",
			"failure_flag": "dom_last_safe_course_check_failed",
			"fallback": "Return to Holst, Yssra, and Yara's reports.",
			"original": "The pilot line and outer-chain report agree.",
		}
	)


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
	var response := await _find_response(resource, title, response_text)
	if response != null:
		return response
	fail("No response containing '%s' at dialogue title '%s'." % [response_text, title])
	return null


func _find_response(
	resource: DialogueResource, title: String, response_text: String
) -> DialogueResponse:
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, title)
	assert_object(line).is_not_null()
	if line == null:
		return null
	for response: DialogueResponse in line.responses:
		if response.text.contains(response_text):
			return response
	return null


func _assert_quest_check_route(case: Dictionary) -> void:
	var quest: DomSideQuest = case["quest"] as DomSideQuest
	var title := str(case["title"])
	var response_text := str(case["response"])
	var skill := str(case["skill"])
	var success_flag := str(case["success_flag"])
	var failure_flag := str(case["failure_flag"])

	_reset_check_state(skill)
	var resource := load(DIALOGUE_PATH) as DialogueResource
	var inactive_response: DialogueResponse = await _find_response(resource, title, response_text)
	assert_bool(inactive_response == null or not inactive_response.is_allowed).is_true()

	QuestRegistry.offer_side_quest(quest)
	var success_response: DialogueResponse = await _response_containing(
		resource, title, response_text
	)
	assert_bool(success_response.is_allowed).is_true()
	var success_log_size := SkillCheck.recent_checks().size()
	SkillCheck.random_number_generator.seed = _successful_seed()
	await DialogueManager.get_next_dialogue_line(resource, success_response.next_id)
	assert_int(SkillCheck.recent_checks().size()).is_equal(success_log_size + 1)
	assert_str(str(SkillCheck.recent_checks().back().get("skill"))).is_equal(skill)
	assert_bool(GameState.flag_is_true(success_flag)).is_true()
	assert_bool(GameState.flag_is_true(failure_flag)).is_false()

	_reset_check_state(skill)
	QuestRegistry.offer_side_quest(quest)
	resource = load(DIALOGUE_PATH) as DialogueResource
	var failure_response: DialogueResponse = await _response_containing(
		resource, title, response_text
	)
	assert_bool(failure_response.is_allowed).is_true()
	_configure_skill(skill, 0.0)
	var failure_log_size := SkillCheck.recent_checks().size()
	await DialogueManager.get_next_dialogue_line(resource, failure_response.next_id)
	assert_int(SkillCheck.recent_checks().size()).is_equal(failure_log_size + 1)
	assert_bool(GameState.flag_is_true(success_flag)).is_false()
	assert_bool(GameState.flag_is_true(failure_flag)).is_true()

	var closed_response: DialogueResponse = await _find_response(resource, title, response_text)
	assert_bool(closed_response == null or not closed_response.is_allowed).is_true()
	var fallback: DialogueResponse = await _response_containing(
		resource, title, str(case["fallback"])
	)
	assert_bool(fallback.is_allowed).is_true()
	await DialogueManager.get_next_dialogue_line(resource, fallback.next_id)
	assert_bool(GameState.flag_is_true(success_flag)).is_false()

	var original_route: DialogueResponse = await _response_containing(
		resource, title, str(case["original"])
	)
	assert_bool(original_route.is_allowed).is_true()
	await DialogueManager.get_next_dialogue_line(resource, original_route.next_id)
	assert_bool(GameState.flag_is_true(success_flag)).is_true()


func _reset_check_state(skill: String) -> void:
	GameState.flags.clear()
	GameState.party.clear()
	GameState._seed_demo_data()
	QuestRegistry.reset()
	SkillCheck._check_log.clear()
	_configure_skill(skill, 95.0)


func _configure_skill(skill: String, advancement: float) -> void:
	var member := GameState.protagonist()
	assert_object(member).is_not_null()
	for attribute: String in member.attributes:
		member.attributes[attribute] = 0
	member.skill_tiers[skill] = "untrained"
	member.skill_percentages[skill] = advancement


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
