extends GdUnitTestSuite
## Release inertness for the quest editor after E2.5b (#337): the legacy autoload and its F6
## overlay are gone; the authoring model lives only in the export-excluded Weftlumin model and
## refuses every authoring entry point until a panel hosts it.

const QuestEditorScript := preload("res://weftlumin/panels/models/quest_editor.gd")
const Release := preload("res://test/helpers/weftlumin_tool_release.gd")
const CAMPAIGN_ID: String = "gdunit-inert-quest-editor"
const PACKAGE_PATH: String = "user://campaigns/%s" % CAMPAIGN_ID

func before_test() -> void:
	_remove_tree(PACKAGE_PATH)


func after_test() -> void:
	_remove_tree(PACKAGE_PATH)


func test_release_build_has_no_quest_editor_autoload_or_shipped_model() -> void:
	assert_bool(Release.autoload_absent(get_tree(), "QuestEditor")).is_true()
	assert_bool(
		Release.model_only_in_excluded_home("quest_editor.gd", "res://globals/quest_editor.gd")
	).is_true()
	assert_str(Release.shipped_reference("weftlumin/panels/models/quest_editor.gd")).is_empty()


func test_unhosted_model_has_no_children_connections_input_or_files() -> void:
	var editor: Node = auto_free(QuestEditorScript.new()) as Node
	add_child(editor)
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

	editor.call("validate_draft", campaign, quests)
	editor.call("save_campaign", campaign, quests)
	editor.call("reload_campaign", CAMPAIGN_ID)
	editor.call("campaign_draft", CAMPAIGN_ID)
	editor.call("campaign_ids")
	editor.call("campaign_summaries")
	editor.call("location_ids")
	editor.call("giver_actor_ids")
	editor.call("dialogue_titles")
	editor.call("faction_ids")
	get_viewport().push_input(key_event, true)

	assert_bool(bool(editor.call("is_enabled"))).is_false()
	assert_int(editor.get_child_count()).is_equal(0)
	assert_bool(editor.is_processing_unhandled_key_input()).is_false()
	assert_array(editor.get_incoming_connections()).is_empty()
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
