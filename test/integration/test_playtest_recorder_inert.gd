extends GdUnitTestSuite

var _test_root: String


func before_test() -> void:
	_test_root = _unique_test_root()
	var singleton: Node = get_node_or_null("/root/PlaytestRecorder")
	if singleton != null:
		singleton.set("force_enabled_for_tests", false)
		singleton.set("session_root_override", _test_root)
	get_tree().paused = false


func after_test() -> void:
	var singleton: Node = get_node_or_null("/root/PlaytestRecorder")
	if singleton != null:
		singleton.set("force_enabled_for_tests", false)
		singleton.set("session_root_override", "")
	get_tree().paused = false


func test_disabled_recorder_has_no_children_connections_processing_or_files() -> void:
	var singleton: Node = get_node_or_null("/root/PlaytestRecorder")
	assert_object(singleton).is_not_null()
	if singleton == null:
		return

	assert_int(singleton.get_child_count()).is_equal(0)
	assert_bool(singleton.is_processing_unhandled_key_input()).is_false()
	assert_bool(
		get_tree().node_added.is_connected(Callable(singleton, "_on_tree_node_added"))
	).is_false()
	assert_bool(
		DialogueManager.dialogue_started.is_connected(
			Callable(singleton, "_on_dialogue_started")
		)
	).is_false()
	assert_bool(DirAccess.dir_exists_absolute(_test_root)).is_false()


func test_forced_enablement_f8_pauses_and_saved_note_is_flushed_to_jsonl() -> void:
	var singleton: Node = get_node_or_null("/root/PlaytestRecorder")
	assert_object(singleton).is_not_null()
	if singleton == null:
		return
	
	singleton.set("force_enabled_for_tests", true)
	await get_tree().process_frame
	_push_f8(singleton.get_viewport())
	await get_tree().process_frame

	assert_bool(get_tree().paused).is_true()
	var dialog: ConfirmationDialog = singleton.find_child(
		"ObservationNoteDialog", true, false
	) as ConfirmationDialog
	assert_object(dialog).is_not_null()
	if dialog == null:
		return
	var line_edit: LineEdit = dialog.find_child("NoteLineEdit", true, false) as LineEdit
	assert_object(line_edit).is_not_null()
	line_edit.text = "Tester could not predict the next actor."
	dialog.confirmed.emit()
	await get_tree().process_frame

	assert_bool(get_tree().paused).is_false()
	assert_int(singleton.get_child_count()).is_equal(0)
	var events_path: String = str(singleton.call("get_events_path"))
	var lines: PackedStringArray = FileAccess.get_file_as_string(events_path).split("\n")
	var found_note := false
	for line: String in lines:
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary and str((parsed as Dictionary).get("type", "")) == "note":
			found_note = (
				str((parsed as Dictionary).get("text", ""))
				== "Tester could not predict the next actor."
			)
	assert_bool(found_note).is_true()


func test_mock_ng_plus_coverage_records_only_the_application_signal() -> void:
	var singleton: Node = get_node_or_null("/root/PlaytestRecorder")
	assert_object(singleton).is_not_null()
	if singleton == null:
		return
	singleton.set("force_enabled_for_tests", true)
	var block: Dictionary = NGPlus.default_block()
	block["completion_metadata"] = {"chapter_completions": 1}
	var _applied: Dictionary = SaveGame.apply_ng_plus_to_new_game({}, block)

	var content: String = FileAccess.get_file_as_string(str(singleton.call("get_events_path")))
	var found_mock_event := false
	for line: String in content.split("\n"):
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if (
			parsed is Dictionary
			and str((parsed as Dictionary).get("type", "")) == "mock_ng_plus_observed"
		):
			found_mock_event = true
	assert_bool(found_mock_event).is_true()


func _push_f8(viewport: Viewport) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F8
	viewport.push_input(event, true)


func _unique_test_root() -> String:
	var base: String = OS.get_environment("SOUL_METER_TEST_DATA_DIR")
	if base.is_empty():
		base = OS.get_temp_dir()
	return base.path_join("playtest-recorder-integration-%d" % Time.get_ticks_usec())
