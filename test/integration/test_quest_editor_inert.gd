extends GdUnitTestSuite

const CAMPAIGN_ID: String = "gdunit-inert-quest-editor"
const PACKAGE_PATH: String = "user://campaigns/%s" % CAMPAIGN_ID

var _incoming_force_enabled_for_tests: bool = false


func before_test() -> void:
	_incoming_force_enabled_for_tests = QuestEditor.force_enabled_for_tests
	QuestEditor.force_enabled_for_tests = false
	_remove_tree(PACKAGE_PATH)


func after_test() -> void:
	QuestEditor.force_enabled_for_tests = _incoming_force_enabled_for_tests
	_remove_tree(PACKAGE_PATH)


func test_disabled_autoload_has_no_children_connections_input_or_files() -> void:
	var files_before: PackedStringArray = _package_files()
	var campaign: Dictionary = {
		"id": CAMPAIGN_ID,
		"title": "Inert Editor",
		"entry_location": "dom",
		"locations": ["dom"],
	}
	var quests: Array[Dictionary] = []
	var key_event: InputEventKey = InputEventKey.new()
	key_event.pressed = true
	key_event.physical_keycode = KEY_F6

	QuestEditor.open_overlay()
	QuestEditor.validate_draft(campaign, quests)
	QuestEditor.save_campaign(campaign, quests)
	QuestEditor.reload_campaign(CAMPAIGN_ID)
	QuestEditor.campaign_draft(CAMPAIGN_ID)
	QuestEditor.campaign_ids()
	QuestEditor.campaign_summaries()
	QuestEditor.location_ids()
	QuestEditor.giver_actor_ids()
	QuestEditor.dialogue_titles()
	QuestEditor.faction_ids()
	QuestEditor._unhandled_key_input(key_event)

	assert_bool(QuestEditor.is_enabled()).is_false()
	assert_int(QuestEditor.get_child_count()).is_equal(0)
	assert_bool(QuestEditor.is_processing_unhandled_key_input()).is_false()
	assert_array(QuestEditor.get_incoming_connections()).is_empty()
	assert_array(_package_files()).is_equal(files_before)
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(PACKAGE_PATH))).is_false()


func _package_files() -> PackedStringArray:
	var files: PackedStringArray = []
	var absolute_root: String = ProjectSettings.globalize_path("user://campaigns")
	if not DirAccess.dir_exists_absolute(absolute_root):
		return files
	_collect_files(absolute_root, absolute_root, files)
	files.sort()
	return files


func _collect_files(root: String, path: String, files: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var child: String = path.path_join(entry)
		if directory.current_is_dir():
			_collect_files(root, child, files)
		else:
			files.append(child.trim_prefix(root + "/"))
		entry = directory.get_next()
	directory.list_dir_end()


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
