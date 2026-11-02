extends GdUnitTestSuite
## QUICK START: the debug-build playtest path in the register's header, on every tab of the
## player's own entry. One press rolls every leaf, names an unnamed hero, accepts, and
## GameFlow begins the game.
## The flow tests enter chargen through the real chart and stop at the intro, with the
## loading handler unhooked so no level loads (as in test_intro_narration_flow).

const TITLE_STATE_PATH := "StateChart/Root/Menus/Title"
const CHARGEN_STATE_PATH := "StateChart/Root/Menus/CharacterCreation"
const INTRO_STATE_PATH := "StateChart/Root/Menus/IntroNarration"
const LOADING_STATE_PATH := "StateChart/Root/Playing/Loading"
const ACTIVE_STATE_PATH := "StateChart/Root/Playing/Active"
const PAUSED_STATE_PATH := "StateChart/Root/Playing/Paused"

var _original_party: Array[PartyMember]
var _original_flags: Dictionary
var _original_custom_recruits: Array[PartyMember]
var _original_skills: Dictionary
var _loading_handler_was_connected := false
var _target_scene_before := ""
var _target_spawn_before: StringName = &"default"


func before_test() -> void:
	_original_party = GameState.party.duplicate()
	_original_flags = GameState.flags.duplicate(true)
	_original_custom_recruits = GameState.custom_recruits.duplicate()
	_original_skills = GameState.skills.duplicate(true)
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
	GameState.party = _original_party
	GameState.flags = _original_flags
	GameState.custom_recruits = _original_custom_recruits
	GameState.skills = _original_skills
	UIManager.close_all()


func test_quick_start_rolls_every_leaf_names_the_hero_and_begins_the_game() -> void:
	var screen := await _open_player_chargen()
	var quick := _quick_start_button(screen)
	assert_object(quick).is_not_null()
	assert_str(quick.text).is_equal("QUICK START")
	assert_bool(quick.is_visible_in_tree()).is_true()
	assert_bool(quick.disabled).is_false()
	assert_str(screen.build.display_name).is_empty()

	quick.pressed.emit()
	assert_bool(quick.disabled).override_failure_message("a second press must not accept twice").is_true()
	await _await_state(INTRO_STATE_PATH)

	assert_bool(_state_is_active(INTRO_STATE_PATH)).is_true()
	assert_bool(GameState.has_created_character()).is_true()
	var member: PartyMember = GameState.party[0]
	assert_str(member.id).is_equal(GameState.PROTAGONIST_ID)
	assert_str(member.display_name).is_equal(CharacterCreationScreen.QUICK_START_NAME)
	for field: String in ["race", "discipline", "patron", "class_id", "kit_weapon_skill",
		"background", "major_element", "minor_element", "mastery_element"]:
		assert_str(str(member.get(field))).override_failure_message(
			"quick start must roll %s" % field).is_not_empty()
	assert_int(Advancement.total_points_spent(member)).is_greater(0)
	assert_object(member.portrait).is_not_null()


func test_quick_start_keeps_a_name_the_player_typed() -> void:
	var screen := await _open_player_chargen()
	screen.set_display_name("Sera")
	screen.quick_start()
	await _await_state(INTRO_STATE_PATH)

	assert_bool(_state_is_active(INTRO_STATE_PATH)).is_true()
	assert_str(GameState.party[0].display_name).is_equal("Sera")


func test_quick_start_shows_on_every_tab_of_the_players_own_entry_only() -> void:
	var screen := await _open_player_chargen()
	var quick := _quick_start_button(screen)
	for tab_id: StringName in ChargenSteps.tab_ids():
		screen.go_to_tab(tab_id)
		assert_bool(quick.is_visible_in_tree()).override_failure_message(String(tab_id)).is_true()

	# The tavern switches the screen to RECRUIT after it opens; the button leaves with it.
	screen.mode = CharacterCreationScreen.Mode.RECRUIT
	assert_bool(quick.visible).is_false()
	var party_before := GameState.party.duplicate()
	screen.quick_start()
	assert_bool(GameState.party == party_before).override_failure_message(
		"quick start must not run for a recruit").is_true()
	assert_bool(_state_is_active(CHARGEN_STATE_PATH)).is_true()


# --- helpers --------------------------------------------------------------------------------

func _open_player_chargen() -> CharacterCreationScreen:
	GameFlow.send_event("start_chargen")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_state_is_active(CHARGEN_STATE_PATH)).is_true()
	var screen := _find_chargen_screen()
	assert_object(screen).is_not_null()
	assert_bool(screen.flow_owned).is_true()
	assert_str(screen.current_tab_id()).is_equal("calling")
	return screen


func _quick_start_button(screen: CharacterCreationScreen) -> Button:
	return screen.find_child("QuickStartButton", true, false) as Button


## ACCEPT waits out its stamp (0.35 s) before sending new_game. Headless frames can run far
## faster than that, so the budget is wall time, not a frame count.
func _await_state(path: String) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		if _state_is_active(path):
			return
		await get_tree().process_frame


func _find_chargen_screen() -> CharacterCreationScreen:
	for child: Node in UIManager.get_children():
		if child is CharacterCreationScreen:
			return child as CharacterCreationScreen
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
