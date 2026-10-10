extends "res://test/helpers/scene_pick_fixture.gd"


func test_closed_shell_keeps_history_without_production_signal_connections() -> void:
	model.set_primary_properties({"rotation": 0.5})
	shell.close()
	await get_tree().process_frame
	for signal_name: StringName in [&"tree_exiting", &"tree_exited"]:
		assert_array(world.get_signal_connection_list(signal_name)).is_empty()
	assert_bool(model.bus.has_undo()).is_true()
	await open_shell()
	assert_bool(model.undo()["allowed"]).is_true()
	assert_float(solid.rotation).is_equal_approx(0, 0.0001)


func test_scene_exit_closes_shell_restores_pause_and_checkpoints() -> void:
	await _assert_scene_exit_closes_shell(false)


func test_scene_exit_preserves_existing_pause() -> void:
	await _assert_scene_exit_closes_shell(true)


func _assert_scene_exit_closes_shell(initially_paused: bool) -> void:
	if initially_paused:
		shell.close()
		await get_tree().process_frame
		get_tree().paused = true
		await open_shell()
		model.select_only(solid)
	assert_bool(get_tree().paused).is_true()
	model.set_primary_properties({"rotation": 0.5})
	var start: Vector2 = solid.position
	var at: Vector2 = screen_at(solid.global_position)
	motion(at)
	edge(at, true)
	motion(at + Vector2(16, 24), true, true)
	var destination: Vector2 = solid.position
	assert_vector(destination).is_not_equal(start)
	# No release before teardown: the scene's exit must finish the active gesture itself.
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# Even a gesture interrupted by teardown gets a fresh release edge.
	edge(at + Vector2(16, 24), false)
	assert_bool(is_instance_valid(world)).is_false()
	assert_bool(is_instance_valid(shell)).is_false()
	assert_bool(get_tree().paused).is_equal(initially_paused)
	var restored: Dictionary = Recovery.load_scene(_scene_path)
	assert_bool(restored["recovered"]).is_true()
	assert_int(restored["working"]["edits"].size()).is_equal(1)
	if restored["working"]["edits"].is_empty():
		return
	assert_float(restored["working"]["edits"][0]["rotation"]).is_equal_approx(0.5, 0.0001)
	assert_array(restored["working"]["edits"][0]["position"]).contains_exactly([destination.x, destination.y])


func test_undo_after_target_freed_restores_document_and_recovery() -> void:
	model.set_primary_properties({"rotation": 0.5})
	shell.close()
	await get_tree().process_frame
	solid.free()
	await open_shell()
	assert_bool(model.undo()["allowed"]).is_true()
	assert_array(model.document["edits"]).is_empty()
	assert_bool(model.is_dirty()).is_false()
	assert_bool(Recovery.load_scene(_scene_path)["recovered"]).is_false()
	assert_bool(model.redo()["allowed"]).is_true()
	assert_int(model.document["edits"].size()).is_equal(1)
	assert_float(model.document["edits"][0]["rotation"]).is_equal_approx(0.5, 0.0001)
	assert_bool(Recovery.load_scene(_scene_path)["recovered"]).is_true()


func test_save_and_close_commit_pending_numeric_text_without_enter() -> void:
	var field: LineEdit = panel._fields["rotation"].get_line_edit()
	field.grab_focus()
	field.text = "25"
	assert_float(solid.rotation_degrees).is_equal_approx(0, 0.001)
	key(KEY_S, true)
	var saved: Dictionary = Recovery.load_scene(_scene_path)["saved"]
	assert_int(saved["edits"].size()).is_equal(1)
	if not saved["edits"].is_empty():
		assert_float(saved["edits"][0]["rotation"]).is_equal_approx(deg_to_rad(25), 0.001)
	field.text = "40"
	shell.close()
	await get_tree().process_frame
	assert_float(solid.rotation_degrees).is_equal_approx(40, 0.001)
	assert_bool(Recovery.load_scene(_scene_path)["recovered"]).is_true()
