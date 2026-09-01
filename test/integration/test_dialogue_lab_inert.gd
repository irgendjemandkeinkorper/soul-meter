extends GdUnitTestSuite

var _incoming_force_enabled_for_tests: bool = false
var _incoming_paused: bool = false


func before_test() -> void:
	_incoming_force_enabled_for_tests = DialogueLab.force_enabled_for_tests
	_incoming_paused = get_tree().paused
	DialogueLab.force_enabled_for_tests = false


func after_test() -> void:
	DialogueLab.force_enabled_for_tests = _incoming_force_enabled_for_tests
	get_tree().paused = _incoming_paused


func test_disabled_autoload_has_no_children_connections_input_or_files() -> void:
	var files_before := PackedStringArray(DirAccess.get_files_at("user://"))
	var setup := {
		"dialogue_path": "res://dialogue/council_elder.dialogue",
		"title": "start",
	}

	DialogueLab.open_setup()
	DialogueLab.start_replay(setup)
	DialogueLab.start_test_session(setup)
	DialogueLab.replay_same_state()
	DialogueLab.reload_and_replay()

	assert_bool(DialogueLab.is_enabled()).is_false()
	assert_int(DialogueLab.get_child_count()).is_equal(0)
	assert_bool(DialogueLab.is_processing_unhandled_key_input()).is_false()
	assert_bool(
		DialogueManager.dialogue_started.is_connected(
			Callable(DialogueLab, "_on_dialogue_started")
		)
	).is_false()
	assert_bool(
		DialogueManager.dialogue_ended.is_connected(
			Callable(DialogueLab, "_on_dialogue_ended")
		)
	).is_false()
	assert_array(PackedStringArray(DirAccess.get_files_at("user://"))).is_equal(files_before)
