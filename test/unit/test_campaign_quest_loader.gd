extends GdUnitTestSuite

const CampaignQuestLoaderScript := preload("res://globals/campaign_quest_loader.gd")
const CAMPAIGN_ID := "gdunit-campaign-loader"
const PACKAGE_PATH := "user://campaigns/%s" % CAMPAIGN_ID
const SECOND_CAMPAIGN_ID := "gdunit-campaign-loader-second"
const SECOND_PACKAGE_PATH := "user://campaigns/%s" % SECOND_CAMPAIGN_ID


func before_test() -> void:
	QuestRegistry.clear_runtime_quests()
	_remove_tree(PACKAGE_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PACKAGE_PATH + "/quests"))
	_write_json(
		PACKAGE_PATH + "/campaign.json",
		{
			"id": CAMPAIGN_ID,
			"title": "Loader Test Campaign",
			"entry_location": "harbor",
			"locations": ["harbor", "archive"],
		}
	)


func after_test() -> void:
	QuestRegistry.clear_runtime_quests()
	_remove_tree(PACKAGE_PATH)
	_remove_tree(SECOND_PACKAGE_PATH)


func test_runtime_ids_are_deterministic_distinct_and_reserved() -> void:
	var first: int = CampaignQuestLoaderScript.runtime_id_for("campaign/quest-a")
	var repeated: int = CampaignQuestLoaderScript.runtime_id_for("campaign/quest-a")
	var different: int = CampaignQuestLoaderScript.runtime_id_for("campaign/quest-b")

	assert_int(first).is_equal(repeated)
	assert_int(first).is_not_equal(different)
	assert_int(first).is_greater_equal(1_000_000)
	assert_int(different).is_greater_equal(1_000_000)


func test_adding_removing_and_reordering_files_does_not_renumber_other_quests() -> void:
	_write_json(PACKAGE_PATH + "/quests/z-last.json", _quest("quest-a", "Quest A"))
	_write_json(PACKAGE_PATH + "/quests/a-first.json", _quest("quest-b", "Quest B"))
	var initial: Dictionary = _id_map(CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false))

	_write_json(PACKAGE_PATH + "/quests/m-middle.json", _quest("quest-c", "Quest C"))
	var added: Dictionary = _id_map(CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false))
	assert_int(added[CAMPAIGN_ID + "/quest-a"]).is_equal(initial[CAMPAIGN_ID + "/quest-a"])
	assert_int(added[CAMPAIGN_ID + "/quest-b"]).is_equal(initial[CAMPAIGN_ID + "/quest-b"])

	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(PACKAGE_PATH + "/quests/z-last.json"),
		ProjectSettings.globalize_path(PACKAGE_PATH + "/quests/00-reordered.json")
	)
	var reordered: Dictionary = _id_map(CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false))
	assert_int(reordered[CAMPAIGN_ID + "/quest-a"]).is_equal(initial[CAMPAIGN_ID + "/quest-a"])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PACKAGE_PATH + "/quests/a-first.json"))
	var removed: Dictionary = _id_map(CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false))
	assert_int(removed[CAMPAIGN_ID + "/quest-a"]).is_equal(initial[CAMPAIGN_ID + "/quest-a"])


func test_valid_package_loads_every_quest_and_registers_them_explicitly() -> void:
	_write_json(PACKAGE_PATH + "/quests/first.json", _quest("quest-a", "Quest A"))
	_write_json(PACKAGE_PATH + "/quests/second.json", _quest("quest-b", "Quest B"))

	assert_bool(QuestRegistry.runtime_quests().is_empty()).is_true()
	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH)

	assert_array(result["errors"]).is_empty()
	assert_int(result["quests"].size()).is_equal(2)
	assert_int(QuestRegistry.runtime_quests().size()).is_equal(2)
	assert_str(result["campaign"]["entry_location"]).is_equal("harbor")


func test_quest_title_absent_from_campaign_and_committed_dialogue_is_rejected() -> void:
	var quest_data: Dictionary = _quest("dead-dialogue", "Dead Dialogue")
	quest_data["dialogue_title"] = "campaign_title_that_is_not_authored"
	_write_json(PACKAGE_PATH + "/quests/dead-dialogue.json", quest_data)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)

	assert_array(result["quests"]).is_empty()
	assert_bool(
		_has_error_code(
			result["errors"], "quests/dead-dialogue.json", "dialogue_title",
			"unknown_dialogue_title"
		)
	).is_true()


func test_campaign_dialogue_title_compiles_registers_routes_and_plays() -> void:
	var dialogue_title: String = "campaign_authored_greeting"
	var dialogue_path: String = PACKAGE_PATH + "/dialogue/authored.dialogue"
	var quest_data: Dictionary = _quest("authored-dialogue", "Authored Dialogue")
	quest_data["dialogue_title"] = dialogue_title
	_write_json(PACKAGE_PATH + "/quests/authored-dialogue.json", quest_data)
	_write_text(
		dialogue_path,
		"~ %s\nCampaign Tester: These words came from the campaign.\n=> END\n"
		% dialogue_title
	)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH)
	var route: Dictionary = QuestRegistry.dialogue_route_for_actor(
		str(quest_data["giver_actor_id"]),
		QuestRegistry.DOM_SIDE_QUEST_DIALOGUE_PATH,
		"dom_side_dishonest_casks"
	)
	var resource: DialogueResource = route.get("resource") as DialogueResource
	assert_object(resource).is_not_null()
	if resource == null:
		return
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(
		resource, str(route.get("title", ""))
	)

	assert_array(result["errors"]).is_empty()
	assert_str(str(route.get("title", ""))).is_equal(dialogue_title)
	assert_str(str(route.get("source", ""))).is_equal(dialogue_path)
	assert_object(line).is_not_null()
	if line == null:
		return
	assert_str(line.text).is_equal("These words came from the campaign.")


func test_campaign_quest_without_own_title_routes_committed_dialogue_resource() -> void:
	var quest_data: Dictionary = _quest("committed-fallback", "Committed Fallback")
	_write_json(PACKAGE_PATH + "/quests/committed-fallback.json", quest_data)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH)
	var route: Dictionary = QuestRegistry.dialogue_route_for_actor(
		str(quest_data["giver_actor_id"]),
		QuestRegistry.COUNCIL_ELDER_DIALOGUE_PATH,
		"start"
	)
	var resource: DialogueResource = route.get("resource") as DialogueResource
	var committed_resource: DialogueResource = ResourceLoader.load(
		QuestRegistry.DOM_SIDE_QUEST_DIALOGUE_PATH
	) as DialogueResource

	assert_array(result["errors"]).is_empty()
	assert_bool(resource == committed_resource).is_true()
	assert_str(str(route.get("title", ""))).is_equal(
		str(quest_data["dialogue_title"])
	)


func test_campaign_dialogue_compile_error_is_attributed_to_source_line_without_registration() -> void:
	var dialogue_path: String = PACKAGE_PATH + "/dialogue/broken.dialogue"
	_write_json(PACKAGE_PATH + "/quests/broken.json", _quest("broken", "Broken Dialogue"))
	_write_text(
		dialogue_path,
		"~ valid_title\nif true\n"
	)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH)
	var compile_errors: Array[Dictionary] = _errors_with_code(
		result["errors"], "dialogue_compile_error"
	)

	assert_array(result["quests"]).is_empty()
	assert_array(QuestRegistry.runtime_quests()).is_empty()
	assert_int(compile_errors.size()).is_greater_equal(1)
	if compile_errors.is_empty():
		return
	assert_str(str(compile_errors[0].get("file", ""))).is_equal(dialogue_path)
	assert_str(str(compile_errors[0].get("field", ""))).is_equal("dialogue")
	assert_int(int(compile_errors[0].get("line", -1))).is_equal(2)
	assert_str(str(compile_errors[0].get("message", ""))).contains("line 2")


func test_import_compile_error_normalizes_zero_based_source_line() -> void:
	var dialogue_path: String = PACKAGE_PATH + "/dialogue/broken-import.dialogue"
	_write_text(
		dialogue_path,
		"~ valid_title\nCampaign Tester: This line is valid.\n"
		+ "import \"res://dialogue/not-a-real-campaign-import.dialogue\" as missing\n"
	)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)
	var compile_errors: Array[Dictionary] = _errors_with_code(
		result["errors"], "dialogue_compile_error"
	)
	var import_error: Dictionary = {}
	var import_error_message: String = DMConstants.get_error_message(
		DMConstants.ERR_ERRORS_IN_IMPORTED_FILE
	)
	for compile_error: Dictionary in compile_errors:
		if str(compile_error.get("message", "")).contains(import_error_message):
			import_error = compile_error
			break

	assert_bool(import_error.is_empty()).is_false()
	if import_error.is_empty():
		return
	assert_str(str(import_error.get("file", ""))).is_equal(dialogue_path)
	assert_int(int(import_error.get("line", -1))).is_equal(3)
	assert_str(str(import_error.get("message", ""))).contains("line 3")


func test_campaign_dialogue_title_shadowing_committed_title_is_rejected() -> void:
	var committed_title: String = CampaignQuestLoaderScript.routed_dialogue_titles()[0]
	var dialogue_path: String = PACKAGE_PATH + "/dialogue/shadow.dialogue"
	var quest_data: Dictionary = _quest("shadow", "Shadow Dialogue")
	quest_data["dialogue_title"] = committed_title
	_write_json(PACKAGE_PATH + "/quests/shadow.json", quest_data)
	_write_text(
		dialogue_path,
		"~ %s\nCampaign Tester: This must not replace canon.\n=> END\n" % committed_title
	)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)
	var shadow_errors: Array[Dictionary] = _errors_with_code(
		result["errors"], "campaign_dialogue_title_shadows_committed"
	)

	assert_array(result["quests"]).is_empty()
	assert_int(shadow_errors.size()).is_equal(1)
	assert_str(str(shadow_errors[0].get("file", ""))).is_equal(dialogue_path)
	assert_str(str(shadow_errors[0].get("field", ""))).is_equal("dialogue_title")
	assert_str(str(shadow_errors[0].get("message", ""))).contains(committed_title)


func test_duplicate_campaign_dialogue_title_rejects_every_owning_file() -> void:
	var duplicate_title: String = "duplicate_campaign_title"
	_write_text(
		PACKAGE_PATH + "/dialogue/first.dialogue",
		"~ %s\nCampaign Tester: First owner.\n=> END\n" % duplicate_title
	)
	_write_text(
		PACKAGE_PATH + "/dialogue/second.dialogue",
		"~ %s\nCampaign Tester: Second owner.\n=> END\n" % duplicate_title
	)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)
	var duplicate_errors: Array[Dictionary] = _errors_with_code(
		result["errors"], "duplicate_campaign_dialogue_title"
	)

	assert_int(duplicate_errors.size()).is_equal(2)
	assert_bool(
		_has_error_code(
			duplicate_errors, "dialogue/first.dialogue", "dialogue_title",
			"duplicate_campaign_dialogue_title"
		)
	).is_true()
	assert_bool(
		_has_error_code(
			duplicate_errors, "dialogue/second.dialogue", "dialogue_title",
			"duplicate_campaign_dialogue_title"
		)
	).is_true()


func test_campaign_dialogue_unsafe_relative_path_is_attributed() -> void:
	var unsafe_path: String = PACKAGE_PATH + "/dialogue/CON.dialogue"
	_write_text(unsafe_path, "~ safe_title\nCampaign Tester: Unreachable.\n=> END\n")

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)

	assert_bool(
		_has_error_code(
			result["errors"], "dialogue/CON.dialogue", "dialogue",
			"unsafe_dialogue_file_path"
		)
	).is_true()


func test_campaign_dialogue_discovery_depth_limit_is_attributed() -> void:
	var directory_path: String = PACKAGE_PATH + "/dialogue"
	for index: int in CampaignQuestLoaderScript.QUEST_DISCOVERY_MAX_DEPTH + 1:
		directory_path = directory_path.path_join("level-%d" % index)
	_write_text(
		directory_path.path_join("deep.dialogue"),
		"~ deep_title\nCampaign Tester: Too deep.\n=> END\n"
	)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)

	assert_bool(
		_has_error_code(
			result["errors"], "level-8", "dialogue",
			"dialogue_discovery_depth_exceeded"
		)
	).is_true()


func test_campaign_dialogue_discovery_file_limit_is_attributed() -> void:
	for index: int in CampaignQuestLoaderScript.QUEST_DISCOVERY_MAX_FILES + 1:
		_write_text(PACKAGE_PATH + "/dialogue/filler-%03d.txt" % index, "")

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)

	assert_bool(
		_has_error_code(
			result["errors"], "dialogue/filler-512.txt", "dialogue",
			"dialogue_discovery_file_limit_exceeded"
		)
	).is_true()


func test_registering_second_campaign_replaces_first_campaign_dialogue_routes() -> void:
	var first_title: String = "first_campaign_words"
	var first_quest: Dictionary = _quest("first-dialogue", "First Dialogue")
	first_quest["dialogue_title"] = first_title
	_write_json(PACKAGE_PATH + "/quests/first-dialogue.json", first_quest)
	_write_text(
		PACKAGE_PATH + "/dialogue/first.dialogue",
		"~ %s\nCampaign Tester: First campaign.\n=> END\n" % first_title
	)
	var first_result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH)
	var first_route: Dictionary = QuestRegistry.dialogue_route_for_actor(
		str(first_quest["giver_actor_id"]),
		QuestRegistry.DOM_SIDE_QUEST_DIALOGUE_PATH,
		"dom_side_dishonest_casks"
	)
	var first_resource: DialogueResource = first_route.get("resource") as DialogueResource
	assert_array(first_result["errors"]).is_empty()
	assert_object(first_resource).is_not_null()

	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(SECOND_PACKAGE_PATH + "/quests")
	)
	_write_json(
		SECOND_PACKAGE_PATH + "/campaign.json",
		{
			"id": SECOND_CAMPAIGN_ID,
			"title": "Second Loader Test Campaign",
			"entry_location": "harbor",
			"locations": ["harbor"],
		}
	)
	var second_title: String = "second_campaign_words"
	var second_quest: Dictionary = _quest("second-dialogue", "Second Dialogue")
	second_quest["giver_actor_id"] = "test-giver-second-campaign"
	second_quest["resolution_flag"] = "test_second_campaign_resolution"
	second_quest["dialogue_title"] = second_title
	_write_json(SECOND_PACKAGE_PATH + "/quests/second-dialogue.json", second_quest)
	_write_text(
		SECOND_PACKAGE_PATH + "/dialogue/second.dialogue",
		"~ %s\nCampaign Tester: Second campaign.\n=> END\n" % second_title
	)

	var second_result: Dictionary = CampaignQuestLoaderScript.load_package(SECOND_PACKAGE_PATH)
	var replaced_route: Dictionary = QuestRegistry.dialogue_route_for_actor(
		str(first_quest["giver_actor_id"]),
		QuestRegistry.DOM_SIDE_QUEST_DIALOGUE_PATH,
		"dom_side_dishonest_casks"
	)
	var second_route: Dictionary = QuestRegistry.dialogue_route_for_actor(
		str(second_quest["giver_actor_id"]),
		QuestRegistry.DOM_SIDE_QUEST_DIALOGUE_PATH,
		"dom_side_dishonest_casks"
	)
	var replaced_resource: DialogueResource = replaced_route.get("resource") as DialogueResource
	var second_resource: DialogueResource = second_route.get("resource") as DialogueResource

	assert_array(second_result["errors"]).is_empty()
	assert_str(str(replaced_route.get("title", ""))).is_equal("dom_side_dishonest_casks")
	assert_bool(replaced_resource == first_resource).is_false()
	assert_str(str(second_route.get("title", ""))).is_equal(second_title)
	assert_object(second_resource).is_not_null()
	assert_bool(second_resource == first_resource).is_false()


func test_duplicate_package_giver_rejects_both_quests_and_names_them() -> void:
	var first: Dictionary = _quest("giver-a", "Giver A")
	var second: Dictionary = _quest("giver-b", "Giver B")
	first["giver_actor_id"] = "shared-package-giver"
	second["giver_actor_id"] = "shared-package-giver"
	_write_json(PACKAGE_PATH + "/quests/first.json", first)
	_write_json(PACKAGE_PATH + "/quests/second.json", second)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)
	var conflicts: Array[Dictionary] = _errors_with_code(
		result["errors"], "duplicate_giver_actor_id"
	)

	assert_array(result["quests"]).is_empty()
	assert_int(conflicts.size()).is_equal(2)
	for error: Dictionary in conflicts:
		assert_str(str(error["message"])).contains(CAMPAIGN_ID + "/giver-a")
		assert_str(str(error["message"])).contains(CAMPAIGN_ID + "/giver-b")


func test_committed_giver_collision_rejects_package_quest_and_names_both() -> void:
	var quest_data: Dictionary = _quest("committed-giver", "Committed Giver")
	quest_data["giver_actor_id"] = QuestRegistry.DISHONEST_CASKS.giver_actor_id
	_write_json(PACKAGE_PATH + "/quests/committed-giver.json", quest_data)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)
	var conflicts: Array[Dictionary] = _errors_with_code(
		result["errors"], "committed_giver_actor_id_collision"
	)

	assert_array(result["quests"]).is_empty()
	assert_int(conflicts.size()).is_equal(1)
	assert_str(str(conflicts[0]["message"])).contains(CAMPAIGN_ID + "/committed-giver")
	assert_str(str(conflicts[0]["message"])).contains(
		QuestRegistry.DISHONEST_CASKS.stable_id
	)


func test_duplicate_package_resolution_flag_rejects_both_quests_and_names_them() -> void:
	var first: Dictionary = _quest("flag-a", "Flag A")
	var second: Dictionary = _quest("flag-b", "Flag B")
	first["resolution_flag"] = "shared_package_resolution"
	second["resolution_flag"] = "shared_package_resolution"
	_write_json(PACKAGE_PATH + "/quests/first.json", first)
	_write_json(PACKAGE_PATH + "/quests/second.json", second)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)
	var conflicts: Array[Dictionary] = _errors_with_code(
		result["errors"], "duplicate_resolution_flag"
	)

	assert_array(result["quests"]).is_empty()
	assert_int(conflicts.size()).is_equal(2)
	for error: Dictionary in conflicts:
		assert_str(str(error["message"])).contains(CAMPAIGN_ID + "/flag-a")
		assert_str(str(error["message"])).contains(CAMPAIGN_ID + "/flag-b")


func test_committed_resolution_flag_collision_rejects_package_quest_and_names_both() -> void:
	var quest_data: Dictionary = _quest("committed-flag", "Committed Flag")
	quest_data["resolution_flag"] = QuestRegistry.DISHONEST_CASKS.resolution_flag
	_write_json(PACKAGE_PATH + "/quests/committed-flag.json", quest_data)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)
	var conflicts: Array[Dictionary] = _errors_with_code(
		result["errors"], "committed_resolution_flag_collision"
	)

	assert_array(result["quests"]).is_empty()
	assert_int(conflicts.size()).is_equal(1)
	assert_str(str(conflicts[0]["message"])).contains(CAMPAIGN_ID + "/committed-flag")
	assert_str(str(conflicts[0]["message"])).contains(
		QuestRegistry.DISHONEST_CASKS.stable_id
	)


func test_one_malformed_quest_is_refused_without_blocking_valid_files() -> void:
	_write_json(PACKAGE_PATH + "/quests/good.json", _quest("good", "Good Quest"))
	var malformed: Dictionary = _quest("bad", "Bad Quest")
	(malformed["outcomes"][0] as Dictionary).erase("faction_id")
	_write_json(PACKAGE_PATH + "/quests/bad.json", malformed)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)

	assert_int(result["quests"].size()).is_equal(1)
	assert_str((result["quests"][0] as DomSideQuest).stable_id).is_equal(CAMPAIGN_ID + "/good")
	assert_bool(_has_error(result["errors"], "quests/bad.json", "outcomes[0].faction_id")).is_true()


func test_authored_outcome_objects_fan_out_into_all_six_runtime_arrays() -> void:
	_write_json(PACKAGE_PATH + "/quests/fanned.json", _quest("fanned", "Fanned Quest"))
	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)
	var quest: DomSideQuest = result["quests"][0] as DomSideQuest

	assert_bool(quest.has_complete_outcome_schema()).is_true()
	assert_array(quest.outcome_ids).contains_exactly(["first", "second"])
	assert_array(quest.outcome_labels).contains_exactly(["First choice", "Second choice"])
	assert_array(quest.outcome_faction_ids).contains_exactly(["faction-a", "faction-b"])
	assert_float(quest.outcome_reputation_deltas[0]).is_equal_approx(4.0, 0.001)
	assert_float(quest.outcome_reputation_deltas[1]).is_equal_approx(-3.0, 0.001)
	assert_array(quest.outcome_causes).contains_exactly(["First cause", "Second cause"])
	assert_array(quest.outcome_readbacks).contains_exactly(["First readback", "Second readback"])


func test_agreement_reward_metadata_fans_out_into_optional_runtime_arrays() -> void:
	var authored := _quest("agreement", "Agreement Quest")
	var first_outcome: Dictionary = authored["outcomes"][0]
	first_outcome["tags"] = [DomSideQuest.ACT_OF_AGREEMENT_TAG]
	first_outcome["soul_delta"] = 7.0
	_write_json(PACKAGE_PATH + "/quests/agreement.json", authored)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)
	var quest: DomSideQuest = result["quests"][0] as DomSideQuest

	assert_array(result["errors"]).is_empty()
	assert_array(quest.outcome_tags[0]).contains_exactly([DomSideQuest.ACT_OF_AGREEMENT_TAG])
	assert_array(quest.outcome_tags[1]).is_empty()
	assert_float(quest.outcome_soul_deltas[0]).is_equal(7.0)
	assert_float(quest.outcome_soul_deltas[1]).is_equal(0.0)


func test_positive_soul_reward_without_agreement_tag_is_rejected() -> void:
	var authored := _quest("invalid-reward", "Invalid Reward Quest")
	(authored["outcomes"][0] as Dictionary)["soul_delta"] = 7.0
	_write_json(PACKAGE_PATH + "/quests/invalid-reward.json", authored)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(PACKAGE_PATH, false)

	assert_array(result["quests"]).is_empty()
	assert_bool(
		_has_error_code(
			result["errors"],
			"quests/invalid-reward.json",
			"outcomes[0].soul_delta",
			"invalid_soul_reward_contract"
		)
	).is_true()


func test_creating_the_loader_does_not_scan_or_register_packages() -> void:
	_write_json(PACKAGE_PATH + "/quests/dormant.json", _quest("dormant", "Dormant Quest"))
	var loader: RefCounted = CampaignQuestLoaderScript.new()

	assert_object(loader).is_not_null()
	assert_bool(QuestRegistry.runtime_quests().is_empty()).is_true()


func _quest(quest_id: String, quest_name: String) -> Dictionary:
	var safe_quest_id: String = quest_id.replace("/", "-")
	return {
		"schema": 1,
		"quest_id": quest_id,
		"kind": "side_quest",
		"name": quest_name,
		"giver_actor_id": "test-giver-%s" % safe_quest_id,
		"dialogue_title": "dom_side_dishonest_casks",
		"decision_prompt": "Choose the test outcome.",
		"resolution_flag": "test_%s_resolution" % safe_quest_id,
		"outcomes": [
			{
				"id": "first",
				"label": "First choice",
				"faction_id": "faction-a",
				"reputation_delta": 4.0,
				"cause": "First cause",
				"readback": "First readback",
			},
			{
				"id": "second",
				"label": "Second choice",
				"faction_id": "faction-b",
				"reputation_delta": -3.0,
				"cause": "Second cause",
				"readback": "Second readback",
			},
		],
	}


func _id_map(result: Dictionary) -> Dictionary:
	assert_array(result["errors"]).is_empty()
	var ids: Dictionary = {}
	for quest: DomSideQuest in result["quests"]:
		ids[quest.stable_id] = quest.id
	return ids


func _has_error(errors: Array, file_suffix: String, field: String) -> bool:
	for error: Dictionary in errors:
		if str(error.get("file", "")).ends_with(file_suffix) and error.get("field", "") == field:
			return true
	return false


func _has_error_code(
	errors: Array, file_suffix: String, field: String, code: String
) -> bool:
	for error: Dictionary in errors:
		if (
			str(error.get("file", "")).ends_with(file_suffix)
			and error.get("field", "") == field
			and error.get("code", "") == code
		):
			return true
	return false


func _errors_with_code(errors: Array, code: String) -> Array[Dictionary]:
	var matching: Array[Dictionary] = []
	for error: Dictionary in errors:
		if error.get("code", "") == code:
			matching.append(error)
	return matching


func _write_json(path: String, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	file.store_string(JSON.stringify(value, "  "))
	file.close()


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	file.store_string(text)
	file.close()


func _remove_tree(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory: DirAccess = DirAccess.open(absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var child: String = absolute.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)
