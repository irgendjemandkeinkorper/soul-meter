extends GdUnitTestSuite


func test_current_locations_are_registered_as_gameplay_only() -> void:
	assert_int(LocationRegistry.ALL.size()).is_equal(24)
	for location in LocationRegistry.ALL:
		assert_bool(location.allowed_gameplay).is_true()
		assert_bool(LocationRegistry.is_gameplay_scene(location.scene_path)).is_true()
	assert_array(GameFlow.GAMEPLAY_SCENES).contains_exactly(LocationRegistry.gameplay_scenes())


func test_named_arrivals_resolve_to_valid_spawn_markers() -> void:
	assert_str(LocationRegistry.by_id(&"dom").resolve_spawn(&"from_dorthkor")).is_equal(
		"from_dorthkor"
	)
	assert_str(LocationRegistry.by_scene(GameFlow.DORTHKOR_SCENE).resolve_spawn(&"from_dom")).is_equal(
		"from_dom"
	)
	assert_str(LocationRegistry.by_scene(GameFlow.WILDS_SCENE).resolve_spawn(&"unknown")).is_equal(
		"default"
	)


func test_unregistered_scene_is_not_a_valid_travel_target() -> void:
	assert_object(LocationRegistry.by_scene("res://ui/screens/main_menu.tscn")).is_null()
	assert_bool(LocationRegistry.is_gameplay_scene("res://ui/screens/main_menu.tscn")).is_false()
