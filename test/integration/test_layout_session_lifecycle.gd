extends GdUnitTestSuite
## Scene teardown and stale live objects must not break scratch/history ownership.

const Recovery := preload("res://globals/layout_recovery.gd")

var _layout: Node
var _world: Node2D
var _prop: Sprite2D
var _scene_path: String
var _previous_current_scene: Node
var _previous_paused: bool
var _previous_force_enabled: bool


func before_test() -> void:
	_layout = get_node("/root/LayoutMode")
	_previous_current_scene = get_tree().current_scene
	_previous_paused = get_tree().paused
	_previous_force_enabled = bool(_layout.get("force_enabled_for_tests"))
	_layout.call("exit_layout_mode")
	_layout.set("force_enabled_for_tests", false)
	get_tree().paused = false
	_world = Node2D.new()
	_world.name = "LayoutLifecycleWorld"
	_scene_path = "res://world/layout_lifecycle_fixture_%d.tscn" % Time.get_ticks_usec()
	_world.scene_file_path = _scene_path
	for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
		var layer := Node2D.new()
		layer.name = layer_name
		_world.add_child(layer)
	_prop = Sprite2D.new()
	_prop.name = "LifecycleProp"
	_prop.texture = load("res://icon.svg")
	_prop.position = Vector2(100, 100)
	_world.get_node("SoftDetails").add_child(_prop)
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	_layout.set("force_enabled_for_tests", true)


func after_test() -> void:
	_layout.call("exit_layout_mode")
	_layout.set("force_enabled_for_tests", false)
	if is_instance_valid(_world):
		# Free the session before orphan accounting; it owns detached undo targets.
		_world.free()
	assert_int(Recovery.clear(_scene_path)).is_equal(OK)
	var save_path: String = preload("res://globals/layout_overrides.gd").override_path_for_scene(_scene_path)
	if FileAccess.file_exists(save_path):
		assert_int(DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))).is_equal(OK)
	get_tree().current_scene = _previous_current_scene if is_instance_valid(_previous_current_scene) else null
	_layout.set("force_enabled_for_tests", _previous_force_enabled)
	get_tree().paused = _previous_paused


func test_scene_exit_closes_layout_and_restores_running_state() -> void:
	await _assert_scene_exit_closes_layout(false)


func test_scene_exit_closes_layout_and_preserves_existing_pause() -> void:
	await _assert_scene_exit_closes_layout(true)


func test_undo_after_target_is_freed_still_restores_document_and_recovery() -> void:
	var editor: Control = _open_editor(false)
	editor._apply_selected_properties({"rotation": 0.5})
	var session: Node = _world.get_node("_LayoutSession")
	assert_bool(session.history.has_undo()).is_true()
	_layout.call("exit_layout_mode")
	_prop.free()
	# Gameplay may retire an edited object while the map editor is closed.
	_layout.call("enter_layout_mode")
	editor = _layout.find_child("LayoutEditor", true, false) as Control
	assert_object(editor).is_not_null()
	editor._undo()
	assert_array(session.document["edits"]).is_empty()
	assert_bool(session.is_dirty()).is_false()
	assert_bool(Recovery.load_scene(_scene_path)["recovered"]).is_false()
	# Redo must also tolerate the absent live node, preserving next-load authoring.
	editor._redo()
	assert_int(session.document["edits"].size()).is_equal(1)
	assert_float(session.document["edits"][0]["rotation"]).is_equal_approx(0.5, 0.0001)
	assert_bool(Recovery.load_scene(_scene_path)["recovered"]).is_true()


func test_save_and_close_commit_pending_numeric_text_without_enter() -> void:
	var editor: Control = _open_editor(false)
	var field: LineEdit = editor.get_node("PalettePanel").get("_fields")["rotation"].get_line_edit()
	field.grab_focus()
	field.text = "25"
	assert_float(_prop.rotation_degrees).is_equal_approx(0, 0.001)
	var save := InputEventKey.new()
	save.pressed = true
	save.keycode = KEY_S
	save.physical_keycode = KEY_S
	save.ctrl_pressed = true
	_layout.get_viewport().push_input(save, true)
	var saved: Dictionary = Recovery.load_scene(_scene_path)["saved"]
	assert_int(saved["edits"].size()).is_equal(1)
	if not saved["edits"].is_empty():
		assert_float(saved["edits"][0]["rotation"]).is_equal_approx(deg_to_rad(25), 0.001)
	field.text = "40"
	_layout.call("exit_layout_mode")
	assert_float(_prop.rotation_degrees).is_equal_approx(40, 0.001)
	assert_bool(Recovery.load_scene(_scene_path)["recovered"]).is_true()


func _assert_scene_exit_closes_layout(initially_paused: bool) -> void:
	var editor: Control = _open_editor(initially_paused)
	editor._apply_selected_properties({"rotation": 0.5})
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = editor.get_viewport().get_canvas_transform() * _prop.global_position
	editor._handle_mouse_button(press)
	var destination := Vector2(116, 124)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.shift_pressed = true
	motion.position = editor.get_viewport().get_canvas_transform() * destination
	editor._handle_mouse_motion(motion)
	assert_vector(_prop.position).is_equal(destination)
	# No release event: teardown must safely finish the active editing gesture.
	_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(is_instance_valid(_world)).is_false()
	assert_object(_layout.find_child("LayoutEditor", true, false)).is_null()
	assert_bool(get_tree().paused).is_equal(initially_paused)
	var restored: Dictionary = Recovery.load_scene(_scene_path)
	assert_bool(restored["recovered"]).is_true()
	assert_int(restored["working"]["edits"].size()).is_equal(1)
	var edit: Dictionary = restored["working"]["edits"][0]
	assert_float(edit["rotation"]).is_equal_approx(0.5, 0.0001)
	assert_array(edit["position"]).contains_exactly([116.0, 124.0])


func _open_editor(initially_paused: bool) -> Control:
	get_tree().paused = initially_paused
	get_tree().current_scene = _world
	_layout.call("enter_layout_mode")
	var editor: Control = _layout.find_child("LayoutEditor", true, false) as Control
	assert_object(editor).is_not_null()
	assert_bool(get_tree().paused).is_true()
	editor.set("_selected", _prop)
	editor._refresh_status()
	return editor
