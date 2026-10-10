extends "res://test/helpers/scene_pick_fixture.gd"
## Pinned layout controls, now operating through the dock and scene model.


func test_footprint_updates_selection_and_records_edit() -> void:
	panel._fields["width"].value = 100
	panel._fields["height"].value = 40
	assert_vector(LayoutOverrides.find_collision(solid).shape.size).is_equal(Vector2(100, 40))
	assert_array(model.document["edits"][0]["collision"]).contains_exactly([100.0, 40.0])


func test_inspector_controls_transform_and_preserve_selection() -> void:
	panel._fields["scale_x"].value = 0.5
	panel._fields["rotation"].value = 45
	panel._fields["skew"].value = 10
	panel._toggles["flip_h"].button_pressed = true
	panel._toggles["grayscale"].button_pressed = true
	assert_float(solid.scale.x).is_equal_approx(0.5, 0.001)
	assert_float(solid.rotation_degrees).is_equal_approx(45, 0.001)
	assert_float(rad_to_deg(solid.skew)).is_equal_approx(10, 0.001)
	assert_bool(model.document["edits"][0]["flip_h"]).is_true()
	assert_bool(model.document["edits"][0]["grayscale"]).is_true()
	assert_object(model.primary()).is_same(solid)


func test_footprint_preserves_untouched_fractional_axis() -> void:
	var collision: CollisionShape2D = LayoutOverrides.find_collision(solid)
	collision.shape.size = Vector2(64.5, 24.75)
	panel._refresh_inspector()
	panel._fields["width"].value = 100
	assert_vector(collision.shape.size).is_equal(Vector2(100, 24.75))


func test_shift_repeats_placement_and_alt_bypasses_snap() -> void:
	model.choose_texture("res://icon.svg")
	var at: Vector2 = world_at(shell.viewport_surface.size / 2.0) + Vector2(3, 5)
	click(screen_at(at), true)
	click(screen_at(at + Vector2(80, 0)), true)
	assert_str(model.texture_path).is_equal("res://icon.svg")
	click(screen_at(at), false, false, true)
	assert_str(model.texture_path).is_empty()
	var additions: Array = model.document["additions"]
	assert_int(additions.size()).is_equal(3)
	var snapped: Vector2 = model.snap(at)
	assert_array(additions[0]["position"]).contains_exactly([snapped.x, snapped.y])
	assert_array(additions[2]["position"]).contains_exactly([at.x, at.y])


func test_editing_position_preserves_fractional_transform() -> void:
	solid.position = Vector2(1.25, 2.75)
	solid.scale = Vector2(0.373, 1.127)
	solid.rotation = 0.25
	panel._refresh_inspector()
	panel._fields["x"].value = 10
	assert_vector(solid.position).is_equal(Vector2(10, 2.75))
	assert_float(solid.scale.x).is_equal_approx(0.373, 0.00001)
	assert_float(solid.scale.y).is_equal_approx(1.127, 0.00001)
	assert_float(solid.rotation).is_equal_approx(0.25, 0.00001)


func test_controls_stay_in_existing_docks() -> void:
	assert_bool(shell.root.find_child("Inspector", true, false).is_ancestor_of(panel._fields["x"])).is_true()
	assert_bool(shell.root.find_child("Palette", true, false).is_ancestor_of(panel._palette)).is_true()
	assert_bool(panel._fields["x"].get_global_rect().end.x <= shell.root.size.x).is_true()


func test_close_reopen_preserves_unsaved_additions_and_history() -> void:
	panel.set_snap_mode(WeftluminSceneModel.Snap.OFF)
	model.placement_layer = &"SoftDetails"
	model.choose_texture("res://icon.svg")
	assert_bool(model.place_prop(solid.global_position)["allowed"]).is_true()
	assert_bool(model.set_primary_properties({"rotation": 0.5})["allowed"]).is_true()
	var previous: WeftluminSceneModel = model
	shell.close()
	await get_tree().process_frame
	await open_shell()
	assert_object(model).is_same(previous)
	assert_int(panel.snap_option.selected).is_equal(WeftluminSceneModel.Snap.OFF)
	assert_str(panel._layer_picker.get_item_text(panel._layer_picker.selected)).is_equal("SoftDetails")
	assert_int(model.document["additions"].size()).is_equal(1)
	assert_float(model.document["additions"][0]["rotation"]).is_equal_approx(0.5, 0.0001)
	assert_bool(model.undo()["allowed"]).is_true()
	assert_float(model.document["additions"][0].get("rotation", 0.0)).is_equal_approx(0, 0.0001)
	assert_bool(model.redo()["allowed"]).is_true()
	assert_float(model.document["additions"][0]["rotation"]).is_equal_approx(0.5, 0.0001)


func test_undo_redo_transform_and_deletion_restore_editability() -> void:
	model.set_primary_properties({"rotation": 0.5})
	model.undo()
	assert_float(solid.rotation).is_equal_approx(0, 0.0001)
	model.redo()
	assert_float(solid.rotation).is_equal_approx(0.5, 0.0001)
	model.delete_selection()
	assert_object(world.get_node_or_null("SolidProps/TestProp")).is_null()
	model.undo()
	assert_object(world.get_node_or_null("SolidProps/TestProp")).is_same(solid)
	assert_bool(model.is_editable(solid)).is_true()
	model.redo()
	assert_object(world.get_node_or_null("SolidProps/TestProp")).is_null()
	# Detached targets belong to undo history; scene teardown must release them.
	shell.close()
	await get_tree().process_frame
	world.free()
	assert_bool(is_instance_valid(solid)).is_false()


func test_undo_saved_edit_is_dirty_and_new_action_clears_redo() -> void:
	model.set_primary_properties({"rotation": 0.5})
	assert_bool(model.save()["allowed"]).is_true()
	assert_bool(model.is_dirty()).is_false()
	model.undo()
	assert_bool(model.is_dirty()).is_true()
	model.set_primary_properties({"rotation": 0.75})
	assert_bool(model.redo()["allowed"]).is_false()


func test_duplicate_restores_child_geometry_after_document_reload() -> void:
	var sprite := solid.get_child(0) as Sprite2D
	sprite.offset = Vector2(0, -115)
	model.duplicate_selection()
	assert_array(model.document["additions"][0]["sprite"]["offset"]).contains_exactly([0.0, -115.0])
	model.undo()
	assert_int(world.get_node("SolidProps").get_child_count()).is_equal(1)
	model.redo()
	assert_int(world.get_node("SolidProps").get_child_count()).is_equal(2)


func test_recovery_recreates_unsaved_work_on_a_fresh_scene() -> void:
	model.choose_texture("res://icon.svg")
	model.place_prop(solid.global_position)
	model.set_primary_properties({"rotation": 0.5, "grayscale": true})
	shell.close()
	await get_tree().process_frame
	world.free()
	world = Node2D.new()
	world.scene_file_path = _scene_path
	get_tree().root.add_child(world)
	for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
		var layer := Node2D.new()
		layer.name = layer_name
		world.add_child(layer)
		layer.owner = world
	get_tree().current_scene = world
	await open_shell()
	var recovered := world.get_node("GroundDetails").get_child(0) as Sprite2D
	assert_float(recovered.rotation).is_equal_approx(0.5, 0.0001)
	assert_bool(LayoutOverrides.is_grayscale(recovered)).is_true()
	assert_bool(model.is_dirty()).is_true()


func test_solid_placement_clamps_footprint_to_existing_contract() -> void:
	model.placement_layer = &"SolidProps"
	model.footprint = Vector2(500, 500)
	model.choose_texture("res://icon.svg")
	model.place_prop(solid.global_position)
	assert_vector(LayoutOverrides.find_collision(model.primary()).shape.size).is_equal(Vector2(120, 48))
