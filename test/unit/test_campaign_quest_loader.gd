extends GdUnitTestSuite

const CampaignQuestLoaderScript := preload("res://globals/campaign_quest_loader.gd")
const CAMPAIGN_ID := "gdunit-campaign-loader"
const PACKAGE_PATH := "user://campaigns/%s" % CAMPAIGN_ID


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


func test_quest_with_unknown_routed_dialogue_title_is_rejected_at_load() -> void:
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
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	file.store_string(JSON.stringify(value, "  "))
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
