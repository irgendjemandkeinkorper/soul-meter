extends GdUnitTestSuite
## Rendered evidence for the one-screen register (chargen overhaul, owner ruling 2026-11-02).
## Opens character creation through GameFlow (the production path) and captures every tab,
## an ability hover card, a locked signature card, BEGIN with a blank name, and the
## 1366x768 fit. Run explicitly under Xvfb:
##   scripts/test.sh -a test/manual/chargen_register_capture.gd
## Frames land in $CAPTURE_OUT (default user://qa/chargen-register).

const CHARGEN_STATE_PATH := "StateChart/Root/Menus/CharacterCreation"

var _saved_state: Dictionary
var _out_dir := ""


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	_out_dir = OS.get_environment("CAPTURE_OUT")
	if _out_dir.is_empty():
		_out_dir = ProjectSettings.globalize_path("user://qa/chargen-register")
	DirAccess.make_dir_recursive_absolute(_out_dir)


func after_test() -> void:
	UIManager.close_all()
	GameState.from_dict(_saved_state)
	get_tree().root.size = Vector2i(1920, 1080)


func test_the_register_as_the_player_sees_it() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	GameFlow.send_event("start_chargen")
	await _frames(12)
	assert_bool(_state_is_active(CHARGEN_STATE_PATH)).is_true()
	var screen := _find_chargen_screen()
	assert_object(screen).is_not_null()
	# A fixed roll so the frames are comparable between runs.
	screen._random_rng.seed = 7
	screen.randomize_character()
	screen.select_class("ironbrand")
	await _frames(6)
	await _capture("01-calling-opens-rolled")

	var tile := screen.find_child("Ability_crown_of_embers", true, false) as Control
	tile.mouse_entered.emit()
	await _frames(3)
	await _capture("02-calling-hover-card")
	print("CARD ", screen.ability_card_text())
	tile.mouse_exited.emit()
	var debt := screen.find_child("Ability_debt_of_arms", true, false) as Control
	debt.mouse_entered.emit()
	await _frames(3)
	await _capture("03-calling-locked-signature")
	print("CARD ", screen.ability_card_text())
	debt.mouse_exited.emit()

	screen.select_class("stormbearer")
	await _frames(3)
	await _capture("04-calling-stormbearer-gaps")

	screen.select_class("ironbrand")
	for tab_id: StringName in [&"origin", &"measures", &"name"]:
		screen.go_to_tab(tab_id)
		await _frames(4)
		await _capture("05-%s" % tab_id)

	screen.begin()
	await _frames(4)
	await _capture("06-begin-without-a-name")
	print("STATUS ", screen._status_lbl.text, " focus=", screen.get_viewport().gui_get_focus_owner())

	get_tree().root.size = Vector2i(1366, 768)
	screen.go_to_tab(&"calling")
	await _frames(8)
	await _capture("07-calling-1366x768")
	var visible_rect := get_tree().root.get_visible_rect()
	for name: String in ["BeginButton", "RandomizeButton", "RollTabButton", "CancelEntryButton"]:
		var button := screen.find_child(name, true, false) as Control
		print("FIT %s %s inside=%s" % [name, button.get_global_rect(), visible_rect.encloses(button.get_global_rect())])


func _frames(count: int) -> void:
	for _frame: int in count:
		await get_tree().process_frame


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, name]
	assert_int(image.save_png(path)).is_equal(OK)
	print("SHOT ", path)


func _find_chargen_screen() -> CharacterCreationScreen:
	for child: Node in UIManager.get_children():
		if child is CharacterCreationScreen:
			return child as CharacterCreationScreen
	return null


func _state_is_active(path: String) -> bool:
	var state := GameFlow.get_node_or_null(path)
	return state != null and bool(state.get("active"))
