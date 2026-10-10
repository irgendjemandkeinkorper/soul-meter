extends GdUnitTestSuite
## Release inertness for the consequence timeline after E2.5b (#337): the legacy autoload and its
## F4 overlay are gone; the observer lives only in the export-excluded Weftlumin model.

const TimelineScript := preload("res://weftlumin/panels/models/consequence_timeline.gd")
const Release := preload("res://test/helpers/weftlumin_tool_release.gd")

var _reputation_before: Dictionary
var _renown_before: Dictionary
var _output_root: String


func before_test() -> void:
	_reputation_before = Reputation.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)
	_output_root = ProjectSettings.globalize_path("user://consequence_timeline")


func after_test() -> void:
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)


func test_release_build_has_no_timeline_autoload_connections_or_files() -> void:
	assert_bool(Release.autoload_absent(get_tree(), "ConsequenceTimeline")).is_true()
	assert_bool(
		Release.model_only_in_excluded_home(
			"consequence_timeline.gd", "res://globals/consequence_timeline.gd"
		)
	).is_true()
	assert_str(
		Release.shipped_reference("weftlumin/panels/models/consequence_timeline.gd")
	).is_empty()
	for connection: Dictionary in Reputation.reputation_changed.get_connections():
		var target: Object = (connection["callable"] as Callable).get_object()
		assert_bool(target == null or target.get_script() != TimelineScript).is_true()
	for connection: Dictionary in Renown.renown_changed.get_connections():
		var target: Object = (connection["callable"] as Callable).get_object()
		assert_bool(target == null or target.get_script() != TimelineScript).is_true()
	assert_bool(DirAccess.dir_exists_absolute(_output_root)).is_false()


func test_disabled_instance_cannot_be_driven() -> void:
	var disabled: Node = auto_free(TimelineScript.new()) as Node
	add_child(disabled)
	var reputation_event := ReputationEvent.new()
	reputation_event.faction = "mirror-choir"
	reputation_event.cause = "stray reputation callback"
	var renown_event := RenownEvent.new()
	renown_event.kind = &"infamy"
	renown_event.cause = "stray renown callback"

	disabled.call("_on_reputation_changed", "mirror-choir", 9.0, reputation_event)
	disabled.call("_on_renown_changed", &"infamy", 4.0, renown_event)

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
