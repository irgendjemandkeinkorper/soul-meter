extends GdUnitTestSuite
## Rendered evidence for the one-bar combat presentation (owner 2026-11-01) in the Lower
## Trial Hall warden fight, as the player sees it: the exploration bar, combat start on the
## player's turn, the enemy hover tooltip, the breakdown popover, and an enemy turn.
## Run explicitly under Xvfb at 1920x1080:
##   scripts/test.sh -a test/manual/combat_one_bar_capture.gd
## Frames land in user://qa/combat-one-bar/*.png.

const OUT_DIR := "user://qa/combat-one-bar"

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


func test_combat_one_bar_as_the_player_sees_it() -> void:
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
	await runner.simulate_frames(3)
	await _capture("01-exploration-bar")

	root.call("request_warden_encounter")
	await runner.simulate_frames(2)
	UIManager.close_all()
	GameFlow._on_battle_entered()
	_hide_other_root_canvas_items(root)
	await runner.simulate_frames(60, 16)
	var hud := field.field_hud()
	var interface := hud.battle_interface
	var stage := interface.stage
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
	await _capture("02-combat-start-player-turn")
	print("BAR height=", hud.bar().size.y, " strip=", interface.turn_strip.size, " window=", stage.open_window())
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := layer as CanvasLayer
		print("LAYER ", cl.get_path(), " layer=", cl.layer, " visible=", cl.visible)

	# An enemy turn: end the player's turn and catch the warden's presented turn mid-beat.
	var foe := Battle.current_target()
	Battle.end_turn()
	var enemy_frame_captured := false
	for _frame: int in 120:
		await runner.simulate_frames(1, 16)
		var presented := stage.presented_event()
		if presented == null:
			continue
		var active := str((presented.data.get("snapshot", {}) as Dictionary).get("active_actor_id", ""))
		if foe != null and active == String(foe.combat_id):
			await runner.simulate_frames(6, 16)
			await _capture("03-enemy-turn")
			enemy_frame_captured = true
			break
	if not enemy_frame_captured:
		await _capture("03-enemy-turn")
	print("ENEMY TURN captured mid-beat=", enemy_frame_captured)
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

	# Hover the warden with STRIKE armed: the small tooltip beside the creature.
	foe = Battle.current_target()
	if foe != null:
		var cell: Vector2i = Battle.controller.battlefield.cell_of(foe)
		interface.select_pointer_action(&"strike")
		stage.select_tile(cell)
		interface._on_tile_hovered({"x": cell.x, "y": cell.y})
		await runner.simulate_frames(3)
		print("TOOLTIP visible=", stage.target_preview.visible, " at=", stage.target_preview.global_position,
			" quote=", (stage.target_preview.get_node("Column/Quote") as Label).text.replace("\n", " | "))
		await _capture("04-enemy-hover-tooltip")

	# The breakdown popover from the bar button, with the hovered forecast in it.
	(hud.combat_bar.get("_breakdown_button") as Button).pressed.emit()
	await runner.simulate_frames(3)
	print("POPOVER rect=", interface.tactical_popover.get_global_rect())
	await _capture("05-breakdown-open")
	(hud.combat_bar.get("_breakdown_button") as Button).pressed.emit()
	interface._on_pointer_cleared()
	print("LOG\n  ", "\n  ".join(hud.combat_bar.log_lines()))

	# MORE: every command, the locked ones with their lock reasons.
	var more := hud.combat_bar.find_child("MoreButton", true, false) as Button
	more.button_pressed = true
	await runner.simulate_frames(3)
	print("MORE ready=", hud.combat_bar.ready_buttons().size(), " shown=", hud.combat_bar.visible_action_buttons().size())
	await _capture("07-more-open")
	more.button_pressed = false
	await runner.simulate_frames(2)

	# The owner's minimum: the same bar at 1366 x 768, compact columns, nothing clipped.
	get_tree().root.size = Vector2i(1366, 768)
	await runner.simulate_frames(6, 16)
	print("BAR 1366 window=", get_tree().root.size, " logical bar=", hud.combat_bar.get_global_rect(),
		" open=", stage.open_window())
	await _capture("08-1366x768-player-turn")
	get_tree().root.size = Vector2i(1920, 1080)
	await runner.simulate_frames(6, 16)

	GameFlow._on_battle_exited()
	await runner.simulate_frames(30, 16)
	await _capture("06-after-combat-bar-retracted")
	print("BAR after=", hud.bar().size.y, " combat_active=", hud.combat_active())
