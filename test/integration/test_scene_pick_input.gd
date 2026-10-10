extends "res://test/helpers/scene_pick_fixture.gd"
## Real GUI routing, with a fresh synthetic event for both edges of every button/key.


func test_ctrl_and_shift_toggle_membership_and_empty_click_clears() -> void:
	var first: Sprite2D = add_sprite("First", solid.global_position - Vector2(180, 0))
	var second: Sprite2D = add_sprite("Second", solid.global_position + Vector2(180, 0))
	click(screen_at(first.global_position))
	click(screen_at(second.global_position), false, true)
	assert_array(model.selection()).contains_exactly([first, second])
	assert_object(model.primary()).is_same(second)
	click(screen_at(second.global_position), true)
	assert_array(model.selection()).contains_exactly([first])
	# Removing the primary falls back to the most recent remaining member.
	assert_object(model.primary()).is_same(first)
	click(screen_at(second.global_position), true)
	assert_array(model.selection()).contains_exactly([first, second])
	# A plain click on a non-member collapses the group to that one node.
	click(screen_at(solid.global_position))
	assert_array(model.selection()).contains_exactly([solid])
	assert_object(model.primary()).is_same(solid)
	click(screen_at(world_at(Vector2(30, shell.viewport_surface.size.y - 30))))
	assert_array(model.selection()).is_empty()
	assert_array(panel.selection_rects()).is_empty()


func test_grid_group_drag_is_rigid_and_one_undo_step_after_release_over_dock() -> void:
	var first: Sprite2D = add_sprite("First", solid.global_position - Vector2(180, 0))
	var second: Sprite2D = add_sprite("Second", first.global_position + Vector2(77, 19))
	var first_start: Vector2 = first.global_position
	var second_start: Vector2 = second.global_position
	click(screen_at(first_start))
	click(screen_at(second_start), true)
	edge(screen_at(second_start), true)
	motion(screen_at(second_start + Vector2(38, 21)), true)
	motion(screen_at(second_start + Vector2(70, 37)), true)
	var landed: Vector2 = model.snap(second_start + Vector2(70, 37))
	assert_vector(second.global_position).is_equal(landed)
	assert_vector(second.global_position - first.global_position).is_equal(second_start - first_start)
	var dock: Vector2 = panel.tree.get_global_rect().get_center()
	motion(dock, true)
	edge(dock, false)
	assert_vector(second.global_position).is_equal(landed)
	assert_bool(model.undo()["allowed"]).is_true()
	assert_vector(first.global_position).is_equal(first_start)
	assert_vector(second.global_position).is_equal(second_start)
	assert_bool(model.undo()["allowed"]).is_false()
	assert_bool(model.redo()["allowed"]).is_true()
	assert_vector(second.global_position).is_equal(landed)


func test_pick_and_outline_follow_pan_zoom_and_parent_transform() -> void:
	var layer := world.get_node("GroundDetails") as Node2D
	layer.position = Vector2(50, 70)
	layer.rotation = 0.2
	layer.scale = Vector2(1.2, 0.8)
	shell.camera.position = Vector2(130, -60)
	shell.camera.zoom = Vector2(1.5, 1.5)
	shell.camera.force_update_scroll()
	var sprite: Sprite2D = add_sprite("Transformed", world_at(shell.viewport_surface.size / 2.0))
	click(screen_at(sprite.global_position))
	assert_object(model.primary()).is_same(sprite)
	var outlines: Array[Rect2] = panel.selection_rects()
	assert_int(outlines.size()).is_equal(1)
	assert_bool(outlines[0].has_point(shell.viewport_surface.size / 2.0)).is_true()
	var destination: Vector2 = sprite.global_position + Vector2(32, 24)
	edge(screen_at(sprite.global_position), true)
	motion(screen_at(destination), true, true)
	edge(screen_at(destination), false)
	assert_vector(sprite.global_position).is_equal_approx(destination, Vector2(0.001, 0.001))
	assert_bool(panel.selection_rects()[0].has_point(shell.viewport_surface.get_global_transform_with_canvas().affine_inverse() * screen_at(destination))).is_true()


func test_cell_snap_and_alt_free_drag_through_viewport() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = Vector2i(64, 32)
	var source := TileSetAtlasSource.new()
	source.texture = load("res://icon.svg")
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := TileMapLayer.new()
	ground.tile_set = tile_set
	ground.set_cell(Vector2i.ZERO, 0, Vector2i.ZERO)
	world.add_child(ground)
	model.grid = IsoGrid.new()
	model.grid.build(ground)
	panel.set_snap_mode(WeftluminSceneModel.Snap.CELL)
	var start: Vector2 = solid.global_position
	var destination: Vector2 = start + Vector2(39, 17)
	click(screen_at(start))
	edge(screen_at(start), true)
	motion(screen_at(destination), true)
	edge(screen_at(destination), false)
	assert_vector(solid.global_position).is_equal(model.grid.cell_to_world(model.grid.world_to_cell(destination)))
	start = solid.global_position
	destination = start + Vector2(13, 11)
	edge(screen_at(start), true)
	motion(screen_at(destination), true, true)
	edge(screen_at(destination), false)
	assert_vector(solid.global_position).is_equal(destination)


func test_click_without_motion_does_not_snap_or_create_history() -> void:
	solid.position += Vector2(0.25, 0.75)
	var before: Vector2 = solid.position
	click(screen_at(solid.global_position))
	assert_vector(solid.position).is_equal(before)
	assert_bool(model.undo()["allowed"]).is_false()


func test_clicking_world_after_typing_restores_nudge_and_undo() -> void:
	var field: LineEdit = panel._fields["rotation"].get_line_edit()
	field.grab_focus()
	field.text = "10"
	key(KEY_ENTER)
	await get_tree().process_frame
	assert_float(solid.rotation_degrees).is_equal_approx(10, 0.001)
	var before: Vector2 = solid.position
	click(screen_at(solid.global_position))
	key(KEY_RIGHT)
	assert_vector(solid.position).is_equal(before + Vector2.RIGHT)
	key(KEY_Z, true)
	assert_vector(solid.position).is_equal(before)
	assert_float(solid.rotation_degrees).is_equal_approx(10, 0.001)


func test_typing_dock_controls_does_not_move_selection_or_open_gameplay_menus() -> void:
	var before: Vector2 = solid.position
	(shell.root.find_child("TreePalette", true, false) as TabContainer).current_tab = 1
	panel._palette_search.grab_focus()
	key(KEY_RIGHT)
	key(KEY_DELETE)
	assert_vector(solid.position).is_equal(before)
	assert_object(solid.get_parent()).is_not_null()
	click(screen_at(solid.global_position))
	for code: Key in [KEY_I, KEY_P, KEY_J, KEY_Q]:
		key(code)
		assert_array(UIManager._stack).is_empty()
		assert_bool(get_tree().paused).is_true()


func test_wheel_and_middle_pan_do_not_edit_the_selection() -> void:
	var at: Vector2 = screen_at(solid.global_position)
	var before: Vector2 = solid.position
	for pressed: bool in [true, false]:
		edge(at, pressed, false, false, false, MOUSE_BUTTON_WHEEL_UP)
	assert_float(shell.camera.zoom.x).is_greater(1.0)
	edge(at, true, false, false, false, MOUSE_BUTTON_MIDDLE)
	var pan := InputEventMouseMotion.new()
	pan.relative = Vector2(24, 16)
	pan.position = at + pan.relative
	pan.global_position = pan.position
	pan.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	var camera_before: Vector2 = shell.camera.position
	get_viewport().push_input(pan, true)
	edge(pan.position, false, false, false, false, MOUSE_BUTTON_MIDDLE)
	assert_vector(shell.camera.position).is_not_equal(camera_before)
	assert_vector(solid.position).is_equal(before)
	assert_bool(model.undo()["allowed"]).is_false()


func test_rendered_pick_drag_capture() -> void:
	var directory := OS.get_environment("SOUL_METER_SCENE_PICK_CAPTURE_DIR")
	if directory.is_empty():
		return
	assert_str(DisplayServer.get_name()).is_not_equal("headless")
	if DisplayServer.get_name() == "headless":
		return
	assert_int(DirAccess.make_dir_recursive_absolute(directory)).is_equal(OK)
	model.clear_selection()
	var start: Vector2 = solid.global_position
	var destination: Vector2 = start + Vector2(96, 48)
	click(screen_at(start))
	assert_object(model.primary()).is_same(solid)
	await _capture_with_outline(directory.path_join("01-picked.png"))
	edge(screen_at(start), true)
	motion(screen_at(start + Vector2(48, 24)), true)
	# Mid-drag, before release: the preview moves and the outline follows it.
	await _capture_with_outline(directory.path_join("02-dragging.png"))
	motion(screen_at(destination), true)
	edge(screen_at(destination), false)
	assert_vector(solid.global_position).is_equal(model.snap(destination))
	await _capture_with_outline(directory.path_join("03-dropped.png"))


## Render a frame, assert the primary outline colour is on the projected top edge, and save it.
func _capture_with_outline(path: String) -> void:
	assert_int(panel.selection_rects().size()).is_equal(1)
	await get_tree().process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var capture: Image = get_viewport().get_texture().get_image()
	var rectangle: Rect2 = panel.selection_rects()[0]
	var transform: Transform2D = shell.viewport_surface.get_global_transform_with_canvas()
	var border: Vector2 = transform * Vector2(rectangle.get_center().x, rectangle.position.y)
	var found := false
	for dx: int in range(-3, 4):
		for dy: int in range(-3, 4):
			var pixel: Color = capture.get_pixelv(Vector2i(border) + Vector2i(dx, dy))
			if absf(pixel.r - DS.BRONZE_4.r) + absf(pixel.g - DS.BRONZE_4.g) + absf(pixel.b - DS.BRONZE_4.b) < 0.15:
				found = true
	assert_bool(found).override_failure_message("The selection outline was absent from rendered pixels").is_true()
	assert_int(capture.save_png(path)).is_equal(OK)
