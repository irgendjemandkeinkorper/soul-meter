extends GdUnitTestSuite
## Acceptance coverage for GH #191.
##
## Unlike test/integration/test_click_to_move.gd, this suite never calls
## ClickMoveController._unhandled_input() directly. A real mouse-button event is
## pushed into an isolated viewport, and Godot must dispatch it to the real
## controller in the real starting-town scene.

const TOWN_SCENE_PATH := "res://world/starting_town.tscn"
const VIEWPORT_SIZE := Vector2i(1152, 648)
const BLOCKED_CELL := Vector2i(29, 33)


func test_viewport_left_click_reaches_click_move_controller() -> void:
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.name = "NavigationAcceptanceViewport"
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var town: Node = (load(TOWN_SCENE_PATH) as PackedScene).instantiate()
	viewport.add_child(town)
	var runner: GdUnitSceneRunner = scene_runner(viewport)
	await runner.simulate_frames(10)

	var player := town.find_child("Player", true, false) as Player
	var blocking := town.find_child("Blocking", true, false) as TileMapLayer
	var controller := player.find_child("ClickMoveController", true, false) as ClickMoveController
	assert_object(player).is_not_null()
	assert_object(blocking).is_not_null()
	assert_object(controller).is_not_null()
	assert_int(blocking.get_cell_source_id(BLOCKED_CELL)).is_not_equal(-1)

	var blocked_world: Vector2 = blocking.to_global(blocking.map_to_local(BLOCKED_CELL))
	var screen_position: Vector2 = player.get_canvas_transform() * blocked_world
	assert_bool(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)).has_point(screen_position)) \
		.override_failure_message(
			"blocked acceptance target %s is outside viewport %s" % [screen_position, VIEWPORT_SIZE]
		) \
		.is_true()

	var captured: Dictionary = {"controller": {}, "player": {}}
	controller.move_refused.connect(
		func(refusal: Dictionary) -> void: captured["controller"] = refusal
	)
	player.move_refused.connect(
		func(refusal: Dictionary) -> void: captured["player"] = refusal
	)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen_position
	click.global_position = screen_position
	viewport.push_input(click, true)
	await runner.simulate_frames(2)

	var controller_refusal: Dictionary = captured["controller"] as Dictionary
	var player_refusal: Dictionary = captured["player"] as Dictionary
	assert_bool(controller_refusal.is_empty()) \
		.override_failure_message(
			"Viewport.push_input() did not reach ClickMoveController._unhandled_input()."
		) \
		.is_false()
	for key: String in ["allowed", "blocked_by", "nearest_unblock", "message"]:
		assert_bool(controller_refusal.has(key)) \
			.override_failure_message("refusal is missing required key '%s'" % key) \
			.is_true()
	assert_bool(controller_refusal.get("allowed", true)).is_false()
	assert_that(controller_refusal.get("blocked_by")).is_equal(&"blocked_by_obstacle")
	assert_int(typeof(controller_refusal.get("nearest_unblock"))).is_equal(TYPE_VECTOR2)
	assert_str(String(controller_refusal.get("message", ""))).is_not_empty()
	assert_that(player_refusal).is_equal(controller_refusal)
