extends GdUnitTestSuite


func before_test() -> void:
	var singleton: Node = get_node_or_null("/root/LayoutMode")
	if singleton != null:
		singleton.set("force_enabled_for_tests", false)
		singleton.call("exit_layout_mode")
	get_tree().paused = false


func after_test() -> void:
	var singleton: Node = get_node_or_null("/root/LayoutMode")
	if singleton != null:
		singleton.call("exit_layout_mode")
		singleton.set("force_enabled_for_tests", false)
	get_tree().paused = false


func test_without_enablement_the_autoload_and_gameplay_scene_gain_no_layout_nodes() -> void:
	var singleton: Node = get_node_or_null("/root/LayoutMode")
	assert_object(singleton).is_not_null()
	if singleton == null:
		return
	assert_int(singleton.get_child_count()).is_equal(0)

	var runner = scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(3)

	assert_int(singleton.get_child_count()).is_equal(0)
	assert_object(runner.scene().find_child("LayoutEditor", true, false)).is_null()


func test_forced_enablement_f10_pauses_and_spawns_then_removes_the_overlay() -> void:
	var singleton: Node = get_node_or_null("/root/LayoutMode")
	assert_object(singleton).is_not_null()
	if singleton == null:
		return
	var runner = scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(3)
	singleton.set("force_enabled_for_tests", true)
	await runner.simulate_frames(2)

	_push_f10(singleton.get_viewport())
	await get_tree().process_frame

	assert_bool(get_tree().paused).is_true()
	assert_int(singleton.get_child_count()).is_equal(1)
	assert_object(singleton.find_child("LayoutEditor", true, false)).is_not_null()

	_push_f10(singleton.get_viewport())
	await get_tree().process_frame

	assert_bool(get_tree().paused).is_false()
	assert_int(singleton.get_child_count()).is_equal(0)


func _push_f10(viewport: Viewport) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F10
	viewport.push_input(event, true)
