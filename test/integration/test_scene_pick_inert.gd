extends GdUnitTestSuite
## F12 is the only editor host. The retired F10 shortcut cannot activate anything, and an
## unhosted gameplay scene gains no scene-model session (the old "no layout nodes" pin).


func test_f10_is_inert_with_bootstrap_disabled() -> void:
	var before: bool = WeftluminBootstrap.force_enabled_for_tests
	var previous_scene: Node = get_tree().current_scene
	WeftluminBootstrap.force_enabled_for_tests = false
	WeftluminBootstrap.close()
	var world := Node2D.new()
	world.name = "InertFixture"
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	var paused: bool = get_tree().paused
	var children: int = get_tree().root.get_child_count()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F10
		event.keycode = KEY_F10
		event.pressed = pressed
		get_viewport().push_input(event, true)
	await get_tree().process_frame
	assert_int(WeftluminBootstrap.get_child_count()).is_equal(0)
	assert_int(get_tree().root.get_child_count()).is_equal(children)
	assert_bool(get_tree().paused).is_equal(paused)
	assert_int(world.get_child_count()).is_equal(0)
	assert_bool(world.has_meta(WeftluminSceneModel.SESSION_META)).is_false()
	get_tree().current_scene = previous_scene if is_instance_valid(previous_scene) else null
	world.free()
	WeftluminBootstrap.force_enabled_for_tests = before
