extends GdUnitTestSuite

const BakeCampaignScript := preload("res://tools/bake_campaign.gd")
const CAMPAIGN_ID := "gdunit-bake-campaign"
const PACKAGE_PATH := "user://campaigns/%s" % CAMPAIGN_ID
const TARGET_PATH := "user://gdunit-baked-quests"


func before_test() -> void:
	QuestRegistry.clear_runtime_quests()
	_remove_tree(PACKAGE_PATH)
	_remove_tree(TARGET_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PACKAGE_PATH + "/quests"))
	_write_json(PACKAGE_PATH + "/campaign.json", {
		"id": CAMPAIGN_ID,
		"title": "Bake Campaign",
		"entry_location": "start",
		"locations": ["start"],
	})
	_write_json(PACKAGE_PATH + "/quests/quest.json", _quest())


func after_test() -> void:
	QuestRegistry.clear_runtime_quests()
	_remove_tree(PACKAGE_PATH)
	_remove_tree(TARGET_PATH)


func test_bake_is_reporting_only_by_default() -> void:
	var report: Dictionary = BakeCampaignScript.bake_package(PACKAGE_PATH, TARGET_PATH)

	assert_str(report["mode"]).is_equal("reporting")
	assert_int(report["summary"]["planned"]).is_equal(1)
	assert_int(report["summary"]["written"]).is_equal(0)
	assert_bool(FileAccess.file_exists(TARGET_PATH + "/side/baked-quest.tres")).is_false()


func test_write_bakes_tres_and_refuses_an_existing_target_without_force() -> void:
	var first: Dictionary = BakeCampaignScript.bake_package(PACKAGE_PATH, TARGET_PATH, true)
	assert_array(first["errors"]).is_empty()
	assert_int(first["summary"]["written"]).is_equal(1)
	assert_bool(FileAccess.file_exists(TARGET_PATH + "/side/baked-quest.tres")).is_true()

	var second: Dictionary = BakeCampaignScript.bake_package(PACKAGE_PATH, TARGET_PATH, true)
	assert_int(second["summary"]["written"]).is_equal(0)
	assert_bool(_has_code(second["errors"], "target_exists")).is_true()


func test_written_resource_is_unassigned_and_report_requires_manual_canonization() -> void:
	var report: Dictionary = BakeCampaignScript.bake_package(
		PACKAGE_PATH, TARGET_PATH, true
	)
	var output_path := TARGET_PATH + "/side/baked-quest.tres"
	var baked_quest := ResourceLoader.load(
		output_path, "DomSideQuest", ResourceLoader.CACHE_MODE_IGNORE
	) as DomSideQuest

	assert_array(report["errors"]).is_empty()
	assert_str(str(report.get("canonization_required", ""))).contains("NOT CANON")
	assert_str(str(report.get("canonization_required", ""))).contains(
		"assign a committed id"
	)
	assert_str(str(report.get("canonization_required", ""))).contains(
		"QuestRegistry.ALL_QUESTS"
	)
	assert_object(baked_quest).is_not_null()
	if baked_quest != null:
		assert_int(baked_quest.id).is_equal(0)


func test_force_explicitly_allows_overwriting_an_existing_tres() -> void:
	BakeCampaignScript.bake_package(PACKAGE_PATH, TARGET_PATH, true)
	var forced: Dictionary = BakeCampaignScript.bake_package(PACKAGE_PATH, TARGET_PATH, true, true)

	assert_array(forced["errors"]).is_empty()
	assert_int(forced["summary"]["written"]).is_equal(1)


func _quest() -> Dictionary:
	return {
		"schema": 1,
		"quest_id": "side/baked-quest",
		"kind": "side_quest",
		"name": "Baked Quest",
		"giver_actor_id": "baker",
		"dialogue_title": "dom_side_dishonest_casks",
		"decision_prompt": "Choose.",
		"resolution_flag": "baked_quest_resolution",
		"outcomes": [
			{"id": "first", "label": "First", "faction_id": "a", "reputation_delta": 1.0, "cause": "First", "readback": "First"},
			{"id": "second", "label": "Second", "faction_id": "b", "reputation_delta": -1.0, "cause": "Second", "readback": "Second"},
		],
	}


func _has_code(errors: Array, code: String) -> bool:
	for error: Dictionary in errors:
		if error.get("code", "") == code:
			return true
	return false


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
	for entry: String in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(entry))
	for entry: String in directory.get_directories():
		_remove_tree(absolute.path_join(entry))
	DirAccess.remove_absolute(absolute)
