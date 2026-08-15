extends GdUnitTestSuite

const ClickMoveControllerScript := preload("res://actors/player/click_move_controller.gd")


func test_pressed_left_click_translates_from_screen_to_world_position() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(132.0, 74.0)
	var canvas_transform := Transform2D(0.0, Vector2(100.0, 50.0))

	var translated: Dictionary = ClickMoveControllerScript.translate_pointer_event(
		click,
		canvas_transform
	)

	assert_bool(translated["accepted"]).is_true()
	assert_that(translated["world_position"]).is_equal(Vector2(32.0, 24.0))


func test_released_left_click_is_rejected() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false

	var translated: Dictionary = ClickMoveControllerScript.translate_pointer_event(
		click,
		Transform2D.IDENTITY
	)

	assert_bool(translated["accepted"]).is_false()


func test_pressed_non_left_click_is_rejected() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true

	var translated: Dictionary = ClickMoveControllerScript.translate_pointer_event(
		click,
		Transform2D.IDENTITY
	)

	assert_bool(translated["accepted"]).is_false()


func test_non_mouse_button_event_is_rejected() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(12.0, 8.0)

	var translated: Dictionary = ClickMoveControllerScript.translate_pointer_event(
		motion,
		Transform2D.IDENTITY
	)

	assert_bool(translated["accepted"]).is_false()
