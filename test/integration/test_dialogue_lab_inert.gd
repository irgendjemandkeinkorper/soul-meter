extends GdUnitTestSuite
## Release inertness for the dialogue lab after E2.5b (#337): the legacy autoload and its F5
## overlay are gone; the replay sandbox lives only in the export-excluded Weftlumin model and
## stays undrivable until a panel hosts it.

const DialogueLabScript := preload("res://weftlumin/panels/models/dialogue_lab.gd")
const Release := preload("res://test/helpers/weftlumin_tool_release.gd")

var _incoming_paused: bool = false


func before_test() -> void:
	_incoming_paused = get_tree().paused


func after_test() -> void:
	get_tree().paused = _incoming_paused


func test_release_build_has_no_dialogue_lab_autoload_or_shipped_model() -> void:
	assert_bool(Release.autoload_absent(get_tree(), "DialogueLab")).is_true()
	assert_bool(
		Release.model_only_in_excluded_home("dialogue_lab.gd", "res://globals/dialogue_lab.gd")
	).is_true()
	assert_str(Release.shipped_reference("weftlumin/panels/models/dialogue_lab.gd")).is_empty()
	for connection: Dictionary in DialogueManager.dialogue_started.get_connections():
		var target: Object = (connection["callable"] as Callable).get_object()
		assert_bool(target == null or target.get_script() != DialogueLabScript).is_true()


func test_unhosted_model_has_no_children_connections_input_or_files() -> void:
	var lab: Node = auto_free(DialogueLabScript.new()) as Node
	add_child(lab)
	var files_before := PackedStringArray(DirAccess.get_files_at("user://"))
	var setup := {
		"dialogue_path": "res://dialogue/council_elder.dialogue",
		"title": "start",
	}

	lab.call("start_replay", setup)
	lab.call("start_test_session", setup)
	lab.call("replay_same_state")
	lab.call("reload_and_replay")

	assert_bool(bool(lab.call("is_enabled"))).is_false()
	assert_int(lab.get_child_count()).is_equal(0)
	assert_bool(lab.is_processing_unhandled_key_input()).is_false()
	assert_bool(
		DialogueManager.dialogue_started.is_connected(
			Callable(lab, "_on_dialogue_started")
		)
	).is_false()
	assert_bool(
		DialogueManager.dialogue_ended.is_connected(
			Callable(lab, "_on_dialogue_ended")
		)
	).is_false()
	assert_array(PackedStringArray(DirAccess.get_files_at("user://"))).is_equal(files_before)
