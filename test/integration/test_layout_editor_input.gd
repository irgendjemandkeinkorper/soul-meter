extends GdUnitTestSuite
## Runtime routing regressions: events must traverse GUI before world commands.

const Recovery := preload("res://globals/layout_recovery.gd")

var _layout: Node
var _editor: Control
var _world: Node2D
var _previous_current_scene: Node
var _runner: GdUnitSceneRunner
var _hidden_root_controls: Array[Dictionary] = []


func before_test() -> void:
	_previous_current_scene = get_tree().current_scene
	_layout = get_node("/root/LayoutMode")
	_layout.call("exit_layout_mode")
	_layout.set("force_enabled_for_tests", false)
	await UIManager.close_all()
	UIManager.reset_reward_reveals()
	get_tree().paused = false
	_runner = scene_runner("res://world/test_room.tscn")
	await _runner.simulate_frames(3)
	_world = _runner.scene() as Node2D
	Recovery.clear(_world.scene_file_path)
	# Boot's MainMenu remains in the runner's tree; it is not part of this map.
	for child: Node in get_tree().root.get_children():
		if child is Control:
			_hidden_root_controls.append({"control": child, "visible": child.visible})
			child.hide()
	# Exercise UIManager's real gameplay guard, not a mocked input handler.
	get_tree().current_scene = _world
	# This suite tests input, never reads or writes an owner's scratch layout.
	_world.set_meta("layout_overrides_applied", true)
	_layout.set("force_enabled_for_tests", true)
	_push_key(KEY_F10)
	await get_tree().process_frame
	_editor = _layout.find_child("LayoutEditor", true, false) as Control
	assert_object(_editor).is_not_null()
	assert_bool(get_tree().paused).is_true()
	assert_int((_editor.get_parent() as CanvasLayer).layer).is_equal(1000)


func after_test() -> void:
	_layout.call("exit_layout_mode")
	_layout.set("force_enabled_for_tests", false)
	Recovery.clear(_world.scene_file_path)
	await UIManager.close_all()
	UIManager.reset_reward_reveals()
	get_tree().paused = false
	get_tree().current_scene = _previous_current_scene if is_instance_valid(_previous_current_scene) else null
	for entry: Dictionary in _hidden_root_controls:
		if is_instance_valid(entry["control"]):
			entry["control"].visible = entry["visible"]
	_hidden_root_controls.clear()
	_runner = null


func test_clicking_world_after_typing_restores_nudge_and_undo_shortcuts() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "LayoutInputTestProp"
	sprite.texture = load("res://icon.svg")
	sprite.scale = Vector2(0.125, 0.125)
	var dressing_layer: Node2D = _world.find_child("GroundDetails", true, false) as Node2D
	assert_object(dressing_layer).is_not_null()
	if dressing_layer == null:
		return
	dressing_layer.add_child(sprite)
	var world_point := Vector2(100, 180)
	sprite.global_position = _editor.get_viewport().get_canvas_transform().affine_inverse() * world_point
	_push_click(world_point)
	assert_object(_editor.get("_selected")).is_same(sprite)
	var fields: Dictionary = _editor.get_node("PalettePanel").get("_fields")
	var rotation_field: LineEdit = (fields["rotation"] as SpinBox).get_line_edit()
	_push_click(rotation_field.get_global_rect().get_center())
	assert_object(_editor.get_viewport().gui_get_focus_owner()).is_same(rotation_field)
	_push_key(KEY_A, true)
	_push_key(KEY_1, false, 49)
	_push_key(KEY_0, false, 48)
	_push_key(KEY_ENTER)
	await get_tree().process_frame
	assert_float(sprite.rotation_degrees).is_equal_approx(10.0, 0.001)
	var before_nudge: Vector2 = sprite.position
	# Clicking back onto the map must commit/leave the numeric field's focus.
	_push_click(world_point)
	_push_key(KEY_RIGHT)
	assert_vector(sprite.position).is_equal(before_nudge + Vector2.RIGHT)
	_push_key(KEY_Z, true)
	assert_vector(sprite.position).is_equal(before_nudge)
	assert_float(sprite.rotation_degrees).is_equal_approx(10.0, 0.001)


func test_gameplay_shortcuts_do_not_open_menus_under_layout_or_release_pause() -> void:
	assert_bool(UIManager.is_open()).is_false()
	# Q is the current journal binding; retain J as an unrelated-key regression.
	for key: Key in [KEY_I, KEY_P, KEY_J, KEY_Q]:
		var previous_stack_size: int = UIManager._stack.size()
		_push_key(key)
		await get_tree().process_frame
		assert_int(UIManager._stack.size()).is_equal(previous_stack_size)
		assert_bool(get_tree().paused).is_true()
		# Keep failures independent: an inventory leak must not mask party/journal.
		if UIManager.is_open():
			await UIManager.close_all()
			get_tree().paused = true
	assert_bool(UIManager.is_open()).is_false()
	assert_bool(get_tree().paused).is_true()


func _push_key(key: Key, control: bool = false, unicode_value: int = 0) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	event.physical_keycode = key
	event.ctrl_pressed = control
	event.unicode = unicode_value
	_layout.get_viewport().push_input(event, true)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	_layout.get_viewport().push_input(release, true)


func _push_click(point: Vector2) -> void:
	var viewport: Viewport = _layout.get_viewport()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = point
	press.global_position = point
	viewport.push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.button_mask = 0
	release.pressed = false
	viewport.push_input(release, true)
