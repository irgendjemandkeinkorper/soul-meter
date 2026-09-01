extends GdUnitTestSuite

var _original_game_state: Dictionary


func before_test() -> void:
	_original_game_state = GameState.to_dict().duplicate(true)
	var singleton: Node = get_node_or_null("/root/DevConsole")
	if singleton != null:
		singleton.call("close_console")
		singleton.set("force_enabled_for_tests", false)
	var restored: bool = GameState.from_dict(_original_game_state)
	assert_bool(restored).is_true()
	get_tree().paused = false


func after_test() -> void:
	var singleton: Node = get_node_or_null("/root/DevConsole")
	if singleton != null:
		singleton.call("close_console")
		singleton.set("force_enabled_for_tests", false)
	# Restore, or this suite leaks `dev_console_used = true` (set by the
	# console's first command) into every suite that runs after it.
	var restored: bool = GameState.from_dict(_original_game_state)
	assert_bool(restored).is_true()
	get_tree().paused = false


func test_disabled_autoload_is_inert() -> void:
	var singleton: Node = get_node_or_null("/root/DevConsole")
	assert_object(singleton).is_not_null()
	if singleton == null:
		return

	assert_int(singleton.get_child_count()).is_equal(0)
	assert_bool(singleton.is_processing_unhandled_key_input()).is_false()
	assert_bool(
		get_tree().node_added.is_connected(Callable(singleton, "_on_tree_node_added"))
	).is_false()


func test_forced_enablement_f1_toggles_overlay_and_restores_pause_state() -> void:
	var singleton: Node = get_node_or_null("/root/DevConsole")
	assert_object(singleton).is_not_null()
	if singleton == null:
		return
	singleton.set("force_enabled_for_tests", true)
	await get_tree().process_frame

	_push_f1(singleton.get_viewport())
	await get_tree().process_frame

	assert_bool(get_tree().paused).is_true()
	assert_int(singleton.get_child_count()).is_equal(1)
	assert_object(singleton.find_child("DevConsoleOverlay", true, false)).is_not_null()

	_push_f1(singleton.get_viewport())
	await get_tree().process_frame

	assert_bool(get_tree().paused).is_false()
	assert_int(singleton.get_child_count()).is_equal(0)


func test_unknown_command_adds_error_line_without_crashing() -> void:
	var singleton: Node = get_node_or_null("/root/DevConsole")
	assert_object(singleton).is_not_null()
	if singleton == null:
		return
	singleton.set("force_enabled_for_tests", true)
	await get_tree().process_frame

	var succeeded: bool = bool(singleton.call("execute_command", "definitely-not-a-command"))
	var entry_value: Variant = singleton.call("last_log_entry")
	var entry: Dictionary = entry_value as Dictionary

	assert_bool(succeeded).is_false()
	assert_bool(bool(entry.get("error", false))).is_true()
	assert_str(str(entry.get("text", ""))).contains("Unknown command")


func _push_f1(viewport: Viewport) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F1
	viewport.push_input(event, true)
