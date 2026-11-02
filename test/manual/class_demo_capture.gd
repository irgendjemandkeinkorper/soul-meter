extends GdUnitTestSuite
## Rendered evidence for the 5v5 class demo (combat polish, owner 2026-11-02): the opening
## with all ten seated in the arena, a walk-in quote on a far enemy, the walk-in strike as one
## order, and the field after the AI five have acted with their kits. Run explicitly under Xvfb:
##   CAPTURE_OUT=<dir> scripts/test.sh -a test/manual/class_demo_capture.gd
## Frames land in $CAPTURE_OUT (default user://qa/class-demo).

var _saved_state: Dictionary
var _out_dir := ""
var _log: PackedStringArray = []


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	get_tree().root.size = Vector2i(1920, 1080)
	_out_dir = OS.get_environment("CAPTURE_OUT")
	if _out_dir.is_empty():
		_out_dir = ProjectSettings.globalize_path("user://qa/class-demo")
	DirAccess.make_dir_recursive_absolute(_out_dir)


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	UIManager.close_all()
	EncounterCatalog.clear_debug_encounter(ClassDemo.ENCOUNTER_ID)
	GameState.from_dict(_saved_state)


func test_the_class_demo_as_the_player_sees_it() -> void:
	assert_bool(ClassDemo.prepare()).is_true()
	var runner := scene_runner(GameFlow.CLASS_DEMO_SCENE)
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	_hide_other_root_canvas_items(root)
	# Arrive where production puts the lead (GameFlow.CLASS_DEMO_SPAWN).
	SaveGame.pending_spawn_id = GameFlow.CLASS_DEMO_SPAWN
	SaveGame.has_pending_player_position = false
	SaveGame.apply_pending_location(root)
	await get_tree().process_frame
	var field := root.find_child("FieldMap", true, false) as FieldMap
	var camera := field.player().get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
	var opened := Battle.start_set_piece(field, ClassDemo.ENCOUNTER_ID)
	assert_bool(bool(opened.get("allowed", false))).override_failure_message(str(opened)).is_true()
	Battle.controller.event_emitted.connect(_on_event)
	UIManager.close_all()
	GameFlow._on_battle_entered()
	_hide_other_root_canvas_items(root)
	await runner.simulate_frames(60, 16)
	var hud := field.field_hud()
	var interface := hud.battle_interface
	var stage := interface.stage
	await _settle(runner, stage)
	await _to_ally_turn(runner, stage)
	await _capture("01-opening-ten-seated")

	# The farthest enemy the active ally could reach with a walk: the approach quote and path.
	var controller := Battle.controller
	var strike := controller.action_by_id(&"strike")
	interface.select_pointer_action(&"strike")
	await runner.simulate_frames(2)
	# The lines open five steps apart, so let the AI close in until a walk-in strike is affordable.
	var target := _approachable_enemy(controller, strike)
	for _turn: int in 20:
		if target != null or Battle.ended:
			break
		controller.end_turn()
		await runner.simulate_frames(20, 16)
		await _settle(runner, stage)
		await _to_ally_turn(runner, stage)
		interface.select_pointer_action(&"strike")
		target = _approachable_enemy(controller, strike)
	if target != null:
		var cell: Vector2i = controller.battlefield.cell_of(target)
		interface._on_tile_hovered({"x": cell.x, "y": cell.y})
		await runner.simulate_frames(3)
		await _capture("02-walk-in-quote")
		var quote := stage.target_preview.get_node_or_null("Column/Quote") as Label
		print("QUOTE ", quote.text if quote != null else "<none>")
		var result := controller.submit_approach(&"strike", target)
		print("APPROACH ", controller.active_actor().display_name if controller.active_actor() else "", " ", result.get("allowed", false), " ", result.get("message", ""))
		await runner.simulate_frames(18, 16)
		await _capture("03-walk-in-mid-order")
		await _settle(runner, stage)
	else:
		print("APPROACH none in reach this turn")

	for _turn: int in 40:
		if Battle.ended or _enemy_actions() >= 8:
			break
		controller.end_turn()
		await runner.simulate_frames(20, 16)
		await _settle(runner, stage)
		await _to_ally_turn(runner, stage)
	await _capture("04-after-the-ai-five-acted")
	print("LOG\n", "\n".join(_log))
	GameFlow._on_battle_exited()
	await runner.simulate_frames(10, 16)


func _enemy_actions() -> int:
	var count := 0
	for line: String in _log:
		if line.begins_with("enemy"):
			count += 1
	return count


func _approachable_enemy(controller: CombatController, strike: CombatAction) -> BattleActor:
	for enemy: BattleActor in controller.enemies:
		if enemy.hp <= 0:
			continue
		var plan := controller.approach_query(strike, enemy)
		if bool(plan.get("allowed", false)):
			return enemy
	return null


func _on_event(event: CombatEvent) -> void:
	if event.type == &"action_resolved":
		_log.append("%s %s" % [event.actor_id, event.data.get("action_id", "")])


func _settle(runner: GdUnitSceneRunner, stage: Node) -> void:
	for _guard: int in 600:
		if not stage.is_presenting_beats():
			return
		await runner.simulate_frames(1, 16)


func _to_ally_turn(runner: GdUnitSceneRunner, stage: Node) -> void:
	for _step: int in 30:
		if Battle.ended or Battle.controller.state == CombatController.State.ALLY_TURN:
			return
		await runner.simulate_frames(10, 16)
		await _settle(runner, stage)


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, name]
	assert_int(image.save_png(path)).is_equal(OK)
	print("SHOT ", path)


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
