extends GdUnitTestSuite

const EditorScene := preload("res://ui/debug/layout_editor.tscn")
var world: Node2D
var editor: Control
var solid: StaticBody2D


func before_test() -> void:
	world = Node2D.new()
	world.scene_file_path = "res://layout_controls_test_fixture.tscn"
	add_child(world)
	for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
		var layer := Node2D.new()
		layer.name = layer_name
		world.add_child(layer)
	solid = StaticBody2D.new()
	solid.name = "TestProp"
	world.get_node("SolidProps").add_child(solid)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://icon.svg")
	solid.add_child(sprite)
	var collision := CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	solid.add_child(collision)
	editor = EditorScene.instantiate()
	add_child(editor)
	editor.configure(world)
	editor.set("_selected", solid)
	editor._refresh_status()
	await get_tree().process_frame


func after_test() -> void:
	editor.free()
	assert_int(preload("res://globals/layout_recovery.gd").clear(world.scene_file_path)).is_equal(OK)
	world.free()


func test_footprint_updates_selection_and_records_edit() -> void:
	editor.get_node("%FootprintWidth").value = 100
	editor.get_node("%FootprintHeight").value = 40
	var collision: CollisionShape2D = editor._selected_solid_collision()
	assert_vector(collision.shape.size).is_equal(Vector2(100, 40))
	assert_array(editor.get("_document")["edits"][0]["collision"]).contains_exactly([100.0, 40.0])


func test_inspector_controls_transform_and_preserve_selection() -> void:
	var inspector: PanelContainer = editor.get_node("PalettePanel")
	inspector.get("_fields")["scale_x"].value = 0.5
	inspector.get("_fields")["rotation"].value = 45
	inspector.get("_fields")["skew"].value = 10
	inspector.get("_toggles")["flip_h"].button_pressed = true
	inspector.get("_toggles")["grayscale"].button_pressed = true
	assert_float(solid.scale.x).is_equal_approx(0.5, 0.001)
	assert_float(solid.rotation_degrees).is_equal_approx(45, 0.001)
	assert_float(rad_to_deg(solid.skew)).is_equal_approx(10, 0.001)
	var edit: Dictionary = editor.get("_document")["edits"][0]
	assert_bool(edit["flip_h"]).is_true()
	assert_bool(edit["grayscale"]).is_true()


func test_footprint_preserves_untouched_fractional_axis() -> void:
	var collision: CollisionShape2D = editor._selected_solid_collision()
	collision.shape.size = Vector2(64.5, 24.75)
	editor._refresh_status()
	editor.get_node("%FootprintWidth").value = 100
	assert_vector(collision.shape.size).is_equal(Vector2(100, 24.75))


func test_shift_repeats_placement_and_alt_bypasses_snap() -> void:
	editor.set("_selected_texture_path", "res://icon.svg")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.shift_pressed = true
	click.position = Vector2(101, 103)
	editor._handle_mouse_button(click)
	editor._handle_mouse_button(click)
	assert_str(editor.get("_selected_texture_path")).is_equal("res://icon.svg")
	click.shift_pressed = false
	click.alt_pressed = true
	editor._handle_mouse_button(click)
	assert_str(editor.get("_selected_texture_path")).is_empty()
	var additions: Array = editor.get("_document")["additions"]
	assert_int(additions.size()).is_equal(3)
	assert_array(additions[0]["position"]).contains_exactly([104.0, 104.0])
	assert_array(additions[2]["position"]).contains_exactly([101.0, 103.0])


func test_editing_position_preserves_fractional_transform() -> void:
	solid.position = Vector2(1.25, 2.75)
	solid.scale = Vector2(0.373, 1.127)
	solid.rotation = 0.25
	editor._refresh_status()
	editor.get_node("PalettePanel").get("_fields")["x"].value = 10
	assert_vector(solid.position).is_equal(Vector2(10, 2.75))
	assert_float(solid.scale.x).is_equal_approx(0.373, 0.00001)
	assert_float(solid.scale.y).is_equal_approx(1.127, 0.00001)
	assert_float(solid.rotation).is_equal_approx(0.25, 0.00001)


func test_panel_clamps_back_into_viewport() -> void:
	var panel: PanelContainer = editor.get_node("PalettePanel")
	panel.position = Vector2(-100, 10000)
	panel._clamp_position()
	assert_bool(panel.position.x >= 0).is_true()
	assert_bool(panel.position.y >= 0).is_true()
	assert_bool(panel.get_rect().end.y <= panel.get_viewport_rect().size.y).is_true()


func test_close_reopen_preserves_unsaved_additions_and_transforms() -> void:
	editor.set("_selected_texture_path", "res://icon.svg")
	editor._place_palette_prop(Vector2(100, 100), true)
	editor._apply_selected_properties({"rotation": 0.5})
	editor.free()
	editor = EditorScene.instantiate()
	add_child(editor)
	editor.configure(world)
	var additions: Array = editor.get("_document")["additions"]
	assert_int(additions.size()).is_equal(1)
	assert_float(additions[0]["rotation"]).is_equal_approx(0.5, 0.0001)
	editor._undo()
	assert_float(editor.get("_document")["additions"][0].get("rotation", 0.0)).is_equal_approx(0, 0.0001)
	editor._redo()
	assert_float(editor.get("_document")["additions"][0]["rotation"]).is_equal_approx(0.5, 0.0001)


func test_undo_redo_transform_then_placement_and_deletion() -> void:
	editor._apply_selected_properties({"rotation": 0.5})
	editor.call("_undo")
	assert_float(solid.rotation).is_equal_approx(0, 0.0001)
	editor.call("_redo")
	assert_float(solid.rotation).is_equal_approx(0.5, 0.0001)
	editor._delete_selected()
	assert_object(world.get_node_or_null("SolidProps/TestProp")).is_null()
	editor.call("_undo")
	assert_object(world.get_node_or_null("SolidProps/TestProp")).is_same(solid)
	editor.call("_redo")
	assert_object(world.get_node_or_null("SolidProps/TestProp")).is_null()
	# Deleted nodes are deliberately retained by UndoRedo until history is cleared.
	editor.get("_session").history.clear_history()
	assert_bool(is_instance_valid(solid)).is_false()


func test_drag_is_one_undo_step_even_when_mouse_releases_over_panel() -> void:
	var press := InputEventMouseButton.new()
	press.pressed = true
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = solid.global_position
	editor._handle_mouse_button(press)
	for destination: Vector2 in [Vector2(40, 40), Vector2(80, 80)]:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = destination
		editor._handle_mouse_motion(motion)
	var release_motion := InputEventMouseMotion.new()
	release_motion.position = Vector2(100, 100)
	editor._handle_mouse_motion(release_motion)
	assert_vector(solid.position).is_equal(Vector2(80, 80))
	editor._undo()
	assert_vector(solid.position).is_equal(Vector2.ZERO)
	assert_bool(editor.get("_session").history.has_undo()).is_false()


func test_undo_saved_edit_is_dirty_and_new_action_clears_redo() -> void:
	editor._apply_selected_properties({"rotation": 0.5})
	editor.get("_session").mark_saved()
	assert_bool(editor.get("_session").is_dirty()).is_false()
	editor._undo()
	assert_bool(editor.get("_session").is_dirty()).is_true()
	editor._apply_selected_properties({"rotation": 0.75})
	assert_bool(editor.get("_session").history.has_redo()).is_false()


func test_duplicate_restores_child_geometry_after_document_reload() -> void:
	var sprite := solid.get_child(0) as Sprite2D
	sprite.offset = Vector2(0, -115)
	editor._duplicate_selected()
	var addition: Dictionary = editor.get("_document")["additions"][0]
	assert_array(addition["sprite"]["offset"]).contains_exactly([0.0, -115.0])
	editor._undo()
	assert_int(world.get_node("SolidProps").get_child_count()).is_equal(1)
	editor._redo()
	assert_int(world.get_node("SolidProps").get_child_count()).is_equal(2)


func test_recovery_recreates_unsaved_work_on_a_fresh_scene() -> void:
	var fresh := Node2D.new()
	fresh.scene_file_path = world.scene_file_path
	for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
		fresh.add_child(world.get_node(layer_name).duplicate())
	editor.set("_selected_texture_path", "res://icon.svg")
	editor._place_palette_prop(Vector2(100, 100), true)
	editor._apply_selected_properties({"rotation": 0.5, "grayscale": true})
	editor.free()
	world.free()
	world = fresh
	add_child(world)
	var recovery: Dictionary = preload("res://globals/layout_recovery.gd").load_scene(world.scene_file_path)
	assert_bool(recovery["recovered"]).is_true()
	preload("res://globals/layout_overrides.gd").apply_to_scene(world, recovery["working"])
	editor = EditorScene.instantiate()
	add_child(editor)
	editor.configure(world)
	var recovered_prop := world.get_node("GroundDetails").get_child(0) as Sprite2D
	assert_float(recovered_prop.rotation).is_equal_approx(0.5, 0.0001)
	assert_bool(preload("res://globals/layout_overrides.gd").is_grayscale(recovered_prop)).is_true()
	assert_bool(editor.get("_session").is_dirty()).is_true()
