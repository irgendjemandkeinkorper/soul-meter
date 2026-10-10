extends GdUnitTestSuite
## Release inertness for the dev console after E2.5b (#337): the legacy autoload, its F1 overlay
## and its environment gate are gone; the interpreter lives only in the export-excluded Weftlumin
## model and stays inert until a panel hosts it.

const ConsoleScript := preload("res://weftlumin/panels/models/dev_console.gd")
const Release := preload("res://test/helpers/weftlumin_tool_release.gd")

var _original_game_state: Dictionary


func before_test() -> void:
	_original_game_state = GameState.to_dict().duplicate(true)
	get_tree().paused = false


func after_test() -> void:
	# Restore, or this suite leaks `dev_console_used = true` (set by the
	# console's first command) into every suite that runs after it.
	var restored: bool = GameState.from_dict(_original_game_state)
	assert_bool(restored).is_true()
	get_tree().paused = false


func test_release_build_has_no_dev_console_autoload_or_shipped_model() -> void:
	assert_bool(Release.autoload_absent(get_tree(), "DevConsole")).is_true()
	assert_bool(
		Release.model_only_in_excluded_home("dev_console.gd", "res://globals/dev_console.gd")
	).is_true()
	assert_str(Release.shipped_reference("weftlumin/panels/models/dev_console.gd")).is_empty()


func test_hosted_console_binds_no_hotkey_and_never_pauses() -> void:
	var console: Node = auto_free(ConsoleScript.new()) as Node
	add_child(console)
	assert_bool(bool(console.call("host_in_panel"))).is_true()
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F1
	event.keycode = KEY_F1
	get_viewport().push_input(event, true)
	await get_tree().process_frame

	assert_bool(get_tree().paused).is_false()
	assert_int(console.get_child_count()).is_equal(0)
	assert_bool(console.is_processing_unhandled_key_input()).is_false()
	assert_bool("TOGGLE_HOTKEY" in (ConsoleScript as Script).get_script_constant_map()).is_false()


func test_unknown_command_adds_error_line_without_crashing() -> void:
	var console: Node = auto_free(ConsoleScript.new()) as Node
	add_child(console)
	assert_bool(bool(console.call("host_in_panel"))).is_true()

	var succeeded: bool = bool(console.call("execute_command", "definitely-not-a-command"))
	var entry_value: Variant = console.call("last_log_entry")
	var entry: Dictionary = entry_value as Dictionary

	assert_bool(succeeded).is_false()
	assert_bool(bool(entry.get("error", false))).is_true()
	assert_str(str(entry.get("text", ""))).contains("Unknown command")


func test_unhosted_model_refuses_commands_and_leaves_no_marker() -> void:
	var console: Node = auto_free(ConsoleScript.new()) as Node
	add_child(console)
	var used_before: bool = bool(GameState.get_flag(ConsoleScript.USED_FLAG, false))

	assert_bool(bool(console.call("execute_command", "soul 99"))).is_false()
	assert_int(console.get_child_count()).is_equal(0)
	assert_bool(console.is_processing_unhandled_key_input()).is_false()
	assert_bool(bool(GameState.get_flag(ConsoleScript.USED_FLAG, false))).is_equal(used_before)
