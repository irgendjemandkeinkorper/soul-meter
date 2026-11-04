extends GdUnitTestSuite
## Rendered evidence for the icon command bar (owner 2026-11-02, item 33 follow-up: "the
## screen is very busy. We could have abilities behind icons with a hover tooltip"), in the
## Lower Trial Hall warden fight as the player sees it: the player's turn, a hover card, MORE
## open, a command armed against a foe out of reach with the walk-in quote, and 1366 x 768.
## Run explicitly under Xvfb at 1920x1080:
##   scripts/test.sh -a test/manual/combat_icon_bar_capture.gd
## Frames land in user://qa/combat-icon-bar/*.png.

const OUT_DIR := "user://qa/combat-icon-bar"

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	get_tree().root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	UIManager.close_all()
	GameState.from_dict(_saved_state)


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	assert_int(image.save_png(path)).is_equal(OK)
	print("SHOT ", ProjectSettings.globalize_path(path))


func _hide_other_root_canvas_items(field_root: Node) -> void:
	for child: Node in get_tree().root.get_children():
		if child == field_root or child.is_ancestor_of(field_root):
			continue
		if child is CanvasItem:
			(child as CanvasItem).hide()
	var current := get_tree().current_scene
	if current is CanvasItem and current != field_root and not current.is_ancestor_of(field_root):
		(current as CanvasItem).hide()


func _hotbar_line(bar: CombatBar) -> String:
	var labels := PackedStringArray()
	for button: Button in bar.hotbar_buttons():
		labels.append("%s %s%s" % [
			(button.get_node("SlotKey") as Label).text, button.text, " (dim)" if button.disabled else ""
		])
	return " | ".join(labels)


func _settle(runner: GdUnitSceneRunner, stage: BattleStageRegion) -> void:
	await runner.simulate_frames(6, 16)
	while stage.is_presenting_beats():
		await runner.simulate_frames(1, 16)
	for _step: int in 20:
		if Battle.ended or Battle.controller.state == CombatController.State.ALLY_TURN:
			break
		Battle.controller.end_turn()
		await runner.simulate_frames(30, 16)
		while stage.is_presenting_beats():
			await runner.simulate_frames(1, 16)
	await runner.simulate_frames(2)


func test_icon_bar_as_the_player_sees_it() -> void:
	GameState.flags.clear()
	if GameState.party.is_empty():
		GameState._seed_demo_data()
	var runner := scene_runner(GameFlow.TRIAL_SCENE)
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	_hide_other_root_canvas_items(root)
	var field := root.find_child("FieldMap", true, false) as FieldMap
	var camera := field.player().get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
	# Start the fight with the party a few cells from the warden, the situation the owner
	# reported: nothing in reach on the first turn.
	var grid := field.iso_grid()
	var start := grid.world_to_cell(field.player().global_position)
	for step: Vector2i in [Vector2i(-4, 0), Vector2i(0, -4), Vector2i(0, 4), Vector2i(-3, -3)]:
		if grid.is_in_bounds(start + step) and not grid.is_blocked_for(start + step, field.player()):
			field.player().global_position = grid.cell_to_world(start + step)
			break
	await runner.simulate_frames(2)
	root.call("request_warden_encounter")
	await runner.simulate_frames(2)
	UIManager.close_all()
	GameFlow._on_battle_entered()
	_hide_other_root_canvas_items(root)
	await runner.simulate_frames(60, 16)
	var hud := field.field_hud()
	var interface := hud.battle_interface
	var stage := interface.stage
	var bar := hud.combat_bar
	await _settle(runner, stage)
	await _capture("01-icon-bar-player-turn")
	print("HOTBAR ", _hotbar_line(bar))

	# The hover card over the first spell on the bar (else the third tile).
	var hovered: Button = null
	for button: Button in bar.hotbar_buttons():
		if button.icon != null and button.icon.resource_path.contains("/elements/"):
			hovered = button
			break
	if hovered == null:
		hovered = bar.hotbar_buttons()[mini(2, bar.hotbar_buttons().size() - 1)]
	hovered.mouse_entered.emit()
	await runner.simulate_frames(3)
	await _capture("02-hover-card")
	print("CARD ", bar.command_card_text())
	hovered.mouse_exited.emit()

	var more := bar.find_child("MoreButton", true, false) as Button
	more.button_pressed = true
	await runner.simulate_frames(3)
	await _capture("03-more-open")
	more.button_pressed = false
	await runner.simulate_frames(3)

	# The foe is out of reach: arm Strike from the bar, hover the foe for the walk-in quote.
	var model := Battle.controller.battlefield as GridBattlefieldModel
	var foe := Battle.living_enemies()[0] as BattleActor
	print("DISTANCE ", model.cell_of(Battle.controller.active_actor()), " -> ", model.cell_of(foe))
	for button: Button in bar.hotbar_buttons():
		if button.text == "STRIKE":
			print("STRIKE disabled=", button.disabled, " card=", bar.card_for_button(button))
			button.pressed.emit()
	await runner.simulate_frames(3)
	var foe_cell: Vector2i = model.cell_of(foe)
	interface._on_tile_hovered({"x": foe_cell.x, "y": foe_cell.y})
	await runner.simulate_frames(6, 16)
	await _capture("04-armed-walk-in")

	interface._on_pointer_cleared()
	get_tree().root.size = Vector2i(1366, 768)
	await runner.simulate_frames(6, 16)
	await _capture("05-1366x768")
	get_tree().root.size = Vector2i(1920, 1080)
	await runner.simulate_frames(6, 16)
	GameFlow._on_battle_exited()
	await runner.simulate_frames(30, 16)


## The 5v5 demo as the owner watches it (item 33: AI vs AI): ten units on the turn strip, the
## bar showing the acting unit's tiles, none of them pressable.
func test_the_watched_demo() -> void:
	if not GameFlow.get_node("StateChart/Root/Menus/Title").get("active"):
		GameFlow.send_event("to_main_menu")
		await get_tree().process_frame
	assert_bool(GameFlow.start_class_demo()).is_true()
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and not Battle.session_active:
		await get_tree().process_frame
	var hud: BattleInterface = null
	while Time.get_ticks_msec() < deadline and hud == null:
		hud = get_tree().root.find_child("BattleInterface", true, false) as BattleInterface
		await get_tree().process_frame
	for _frame: int in 240:
		await get_tree().process_frame
	await _capture("06-demo-watching")
	var strip := hud.turn_strip
	var hints := get_tree().root.find_child("Tutorial", true, false) as Control
	print("STRIP ", strip.get_global_rect(), " HINTS ", hints.get_global_rect() if hints != null else "none")
	GameFlow.send_event("pause")
	await get_tree().process_frame
	GameFlow.send_event("to_main_menu")
	await get_tree().process_frame
	if GameFlow.class_demo_active():
		GameFlow._end_class_demo()
