extends GdUnitTestSuite
## Rendered evidence for QUICK START (owner 2026-11-01: a debug-build button on page one
## that rolls every leaf, names the hero "Tester" and begins the game). Captures page one at
## 1920x1080 and 1366x768, the stamped summary, and the intro the press lands on.
## Run explicitly under Xvfb:
##   scripts/test.sh -a test/manual/chargen_quick_start_capture.gd
## Frames land in user://qa/chargen-quick-start/*.png.

const OUT_DIR := "user://qa/chargen-quick-start"
const CHARGEN_STATE_PATH := "StateChart/Root/Menus/CharacterCreation"
const INTRO_STATE_PATH := "StateChart/Root/Menus/IntroNarration"
const LOADING_STATE_PATH := "StateChart/Root/Playing/Loading"

var _saved_state: Dictionary
var _loading_handler_was_connected := false


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var loading_state := GameFlow.get_node(LOADING_STATE_PATH)
	_loading_handler_was_connected = loading_state.state_entered.is_connected(GameFlow._on_loading_entered)
	if _loading_handler_was_connected:
		loading_state.state_entered.disconnect(GameFlow._on_loading_entered)


func after_test() -> void:
	if _state_is_active(INTRO_STATE_PATH):
		GameFlow.send_event("intro_done")
		await get_tree().process_frame
	var loading_state := GameFlow.get_node(LOADING_STATE_PATH)
	if _loading_handler_was_connected and not loading_state.state_entered.is_connected(GameFlow._on_loading_entered):
		loading_state.state_entered.connect(GameFlow._on_loading_entered)
	UIManager.close_all()
	GameState.from_dict(_saved_state)
	get_tree().root.size = Vector2i(1920, 1080)


func test_quick_start_as_the_player_sees_it() -> void:
	get_tree().root.size = Vector2i(1366, 768)
	GameFlow.send_event("start_chargen")
	await _frames(12)
	assert_bool(_state_is_active(CHARGEN_STATE_PATH)).is_true()
	var screen := _find_chargen_screen()
	var quick := screen.find_child("QuickStartButton", true, false) as Button
	assert_bool(quick.is_visible_in_tree()).is_true()
	await _capture("01-page-one-1366x768")
	_print_nav_fit(screen)

	get_tree().root.size = Vector2i(1920, 1080)
	await _frames(6)
	await _capture("02-page-one-1920x1080")
	_print_nav_fit(screen)

	quick.pressed.emit()
	await _frames(4)
	await _capture("03-summary-stamped")
	for _frame: int in 240:
		if _state_is_active(INTRO_STATE_PATH):
			break
		await get_tree().process_frame
	assert_bool(_state_is_active(INTRO_STATE_PATH)).is_true()
	await _frames(20)
	await _capture("04-intro")
	var member: PartyMember = GameState.party[0]
	print("HERO %s · %s %s · %s / %s · %s" % [
		member.display_name, member.race, member.discipline, member.class_id,
		member.kit_weapon_skill, member.background,
	])


func _print_nav_fit(screen: CharacterCreationScreen) -> void:
	var visible_rect := get_tree().root.get_visible_rect()
	for name: String in ["RandomizeButton", "QuickStartButton"]:
		var button := screen.find_child(name, true, false) as Button
		print("NAV %s %s inside=%s" % [name, button.get_global_rect(), visible_rect.encloses(button.get_global_rect())])
	print("NAV begin %s inside=%s" % [screen._begin_btn.get_global_rect(), visible_rect.encloses(screen._begin_btn.get_global_rect())])


func _frames(count: int) -> void:
	for _frame: int in count:
		await get_tree().process_frame


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	assert_int(image.save_png(path)).is_equal(OK)
	print("SHOT ", ProjectSettings.globalize_path(path))


func _find_chargen_screen() -> CharacterCreationScreen:
	for child: Node in UIManager.get_children():
		if child is CharacterCreationScreen:
			return child as CharacterCreationScreen
	return null


func _state_is_active(path: String) -> bool:
	var state := GameFlow.get_node_or_null(path)
	return state != null and bool(state.get("active"))
