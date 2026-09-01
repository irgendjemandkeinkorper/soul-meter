extends GdUnitTestSuite

const TimelineScript := preload("res://globals/consequence_timeline.gd")

var _reputation_before: Dictionary
var _renown_before: Dictionary
var _output_root: String
## Captured, not assumed. Forcing the shared autoload to a hardcoded `false` on
## the way out leaves it disabled for whatever ran before us, which turns this
## suite into a run-order dependency for every later suite. Restore what we found.
var _timeline_enabled_before: bool = false


func before_test() -> void:
	_reputation_before = Reputation.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)
	_output_root = ProjectSettings.globalize_path("user://consequence_timeline")
	var singleton: Node = get_node_or_null("/root/ConsequenceTimeline")
	if singleton != null:
		_timeline_enabled_before = bool(singleton.get("force_enabled_for_tests"))
		singleton.set("force_enabled_for_tests", false)


func after_test() -> void:
	var singleton: Node = get_node_or_null("/root/ConsequenceTimeline")
	if singleton != null:
		singleton.set("force_enabled_for_tests", _timeline_enabled_before)
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)


func test_disabled_autoload_has_no_children_connections_input_or_files() -> void:
	var singleton: Node = get_node_or_null("/root/ConsequenceTimeline")
	assert_object(singleton).is_not_null()
	if singleton == null:
		return

	assert_int(singleton.get_child_count()).is_equal(0)
	assert_bool(singleton.is_processing_unhandled_key_input()).is_false()
	assert_bool(
		Reputation.reputation_changed.is_connected(
			Callable(singleton, "_on_reputation_changed")
		)
	).is_false()
	assert_bool(
		Renown.renown_changed.is_connected(Callable(singleton, "_on_renown_changed"))
	).is_false()
	assert_bool(DirAccess.dir_exists_absolute(_output_root)).is_false()


func test_disabled_instance_cannot_be_driven() -> void:
	var disabled: Node = auto_free(TimelineScript.new()) as Node
	add_child(disabled)
	disabled.set("force_enabled_for_tests", false)
	var reputation_event := ReputationEvent.new()
	reputation_event.faction = "mirror-choir"
	reputation_event.cause = "stray reputation callback"
	var renown_event := RenownEvent.new()
	renown_event.kind = &"infamy"
	renown_event.cause = "stray renown callback"
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.physical_keycode = TimelineScript.TOGGLE_HOTKEY

	disabled.call("open_overlay")
	disabled.call("_on_reputation_changed", "mirror-choir", 9.0, reputation_event)
	disabled.call("_on_renown_changed", &"infamy", 4.0, renown_event)
	disabled.call("_unhandled_key_input", key_event)

	var rows: Array[Dictionary] = disabled.call("rows")
	assert_int(disabled.get_child_count()).is_equal(0)
	assert_int(rows.size()).is_equal(0)
	assert_bool(disabled.is_processing_unhandled_key_input()).is_false()
	assert_bool(
		Reputation.reputation_changed.is_connected(
			Callable(disabled, "_on_reputation_changed")
		)
	).is_false()
	assert_bool(
		Renown.renown_changed.is_connected(Callable(disabled, "_on_renown_changed"))
	).is_false()
	assert_bool(DirAccess.dir_exists_absolute(_output_root)).is_false()
