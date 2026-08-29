extends GdUnitTestSuite

const TITLE_STATE_PATH := "StateChart/Root/Menus/Title"
const CHARGEN_STATE_PATH := "StateChart/Root/Menus/CharacterCreation"
const INTRO_STATE_PATH := "StateChart/Root/Menus/IntroNarration"
const LOADING_STATE_PATH := "StateChart/Root/Playing/Loading"
const ACTIVE_STATE_PATH := "StateChart/Root/Playing/Active"
const PAUSED_STATE_PATH := "StateChart/Root/Playing/Paused"

var _loading_handler_was_connected := false
var _target_scene_before := ""
var _target_spawn_before: StringName = &"default"


func before_test() -> void:
	_target_scene_before = GameFlow._target_scene
	_target_spawn_before = GameFlow._target_spawn_id
	await _return_to_title()
	var loading_state := GameFlow.get_node(LOADING_STATE_PATH)
	_loading_handler_was_connected = loading_state.state_entered.is_connected(
		GameFlow._on_loading_entered
	)
	if _loading_handler_was_connected:
		loading_state.state_entered.disconnect(GameFlow._on_loading_entered)
	UIManager.close_all()


func after_test() -> void:
	await _return_to_title()
	var loading_state := GameFlow.get_node(LOADING_STATE_PATH)
	if (
		_loading_handler_was_connected
		and not loading_state.state_entered.is_connected(GameFlow._on_loading_entered)
	):
		loading_state.state_entered.connect(GameFlow._on_loading_entered)
	GameFlow._target_scene = _target_scene_before
	GameFlow._target_spawn_id = _target_spawn_before
	UIManager.close_all()


func test_chargen_new_game_enters_intro_then_loads_lower_trial_hall() -> void:
	GameFlow.send_event("start_chargen")
	await get_tree().process_frame
	assert_bool(_state_is_active(CHARGEN_STATE_PATH)).is_true()

	GameFlow.send_event("new_game")
	await get_tree().process_frame
	assert_bool(_state_is_active(INTRO_STATE_PATH)).is_true()

	GameFlow.send_event("intro_done")
	await get_tree().process_frame
	assert_bool(_state_is_active(LOADING_STATE_PATH)).is_true()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TRIAL_SCENE)
	assert_str(String(GameFlow._target_spawn_id)).is_equal("entry")


func test_skip_button_completes_intro_flow() -> void:
	GameFlow.send_event("start_chargen")
	await get_tree().process_frame
	GameFlow.send_event("new_game")
	await get_tree().process_frame

	var intro_screen := _find_intro_screen()
	assert_object(intro_screen).is_not_null()
	var skip_button := _find_button_with_text(intro_screen, "Skip")
	assert_object(skip_button).is_not_null()
	skip_button.pressed.emit()
	await get_tree().process_frame

	assert_bool(_state_is_active(LOADING_STATE_PATH)).is_true()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TRIAL_SCENE)


func test_save_load_destination_bypasses_intro() -> void:
	var destination := LoadDestination.new(&"dom", &"default")
	SaveGame.load_requested.emit(destination)
	GameFlow.send_event("new_game")
	await get_tree().process_frame

	assert_bool(_state_is_active(INTRO_STATE_PATH)).is_false()
	assert_bool(_state_is_active(LOADING_STATE_PATH)).is_true()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TOWN_SCENE)


func _find_intro_screen() -> Control:
	for child: Node in UIManager.get_children():
		if child.scene_file_path == "res://ui/screens/intro_narration.tscn":
			return child as Control
	return null


func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null


func _state_is_active(path: String) -> bool:
	var state := GameFlow.get_node_or_null(path)
	return state != null and bool(state.get("active"))


func _return_to_title() -> void:
	if _state_is_active(TITLE_STATE_PATH):
		return
	if _state_is_active(CHARGEN_STATE_PATH):
		GameFlow.send_event("new_game")
		await get_tree().process_frame
	if _state_is_active(INTRO_STATE_PATH):
		GameFlow.send_event("intro_done")
		await get_tree().process_frame
	if _state_is_active(LOADING_STATE_PATH):
		GameFlow.send_event("level_ready")
		await get_tree().process_frame
	if _state_is_active(ACTIVE_STATE_PATH):
		GameFlow.send_event("pause")
		await get_tree().process_frame
	if _state_is_active(PAUSED_STATE_PATH):
		GameFlow.send_event("to_main_menu")
		await get_tree().process_frame
