extends GdUnitTestSuite
## Rendered evidence for the combat hotbar (owner 2026-11-01: eight slots, auto-filled,
## keys 1–8, the rest behind MORE) in the Lower Trial Hall warden fight, as the player sees
## it: the player's turn, MORE open, a command chosen from MORE taking a slot, and 1366 x 768.
## Run explicitly under Xvfb at 1920x1080:
##   scripts/test.sh -a test/manual/combat_hotbar_capture.gd
## Frames land in user://qa/combat-hotbar/*.png.

const OUT_DIR := "user://qa/combat-hotbar"

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


## The harness leaves the boot menu (and whatever else it mounted) in the tree; production
## frees it on travel. Hide every root canvas item that is not the field scene.
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


func test_combat_hotbar_as_the_player_sees_it() -> void:
	GameState.flags.clear()
	if GameState.party.is_empty():
		GameState._seed_demo_data()
	var runner := scene_runner(GameFlow.TRIAL_SCENE)
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	_hide_other_root_canvas_items(root)
	var field := root.find_child("FieldMap", true, false) as FieldMap
	var player := field.player()
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
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
	await _capture("01-hotbar-player-turn")
	print("HOTBAR ", _hotbar_line(bar))
	print("MORE text=", (bar.find_child("MoreButton", true, false) as Button).text)

	var more := bar.find_child("MoreButton", true, false) as Button
	more.button_pressed = true
	await runner.simulate_frames(3)
	await _capture("02-more-open")

	# Choose the first usable command off the bar: it takes the least-used slot (slot 8).
	var spare := bar.find_child("Spare", true, false) as Container
	if spare.get_child_count() > 0:
		var chosen := spare.get_child(0) as Button
		print("CHOSEN from MORE: ", chosen.text)
		chosen.pressed.emit()
		interface._on_pointer_cleared()
	more.button_pressed = false
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
	await _capture("03-promoted-from-more")
	print("HOTBAR after promotion ", _hotbar_line(bar))

	get_tree().root.size = Vector2i(1366, 768)
	await runner.simulate_frames(6, 16)
	await _capture("04-1366x768")
	get_tree().root.size = Vector2i(1920, 1080)
	await runner.simulate_frames(6, 16)
	GameFlow._on_battle_exited()
	await runner.simulate_frames(30, 16)
