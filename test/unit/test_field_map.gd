extends GdUnitTestSuite


func test_every_gameplay_scene_exposes_field_layers_and_shared_iso_grid() -> void:
	for scene_path: String in GameFlow.GAMEPLAY_SCENES:
		var packed_scene: PackedScene = load(scene_path) as PackedScene
		assert_object(packed_scene).override_failure_message(scene_path).is_not_null()
		if packed_scene == null:
			continue
		var scene: Node = packed_scene.instantiate()
		add_child(scene)
		await get_tree().process_frame

		var field: FieldMap = _find_field_map(scene)
		assert_object(field).override_failure_message(scene_path).is_not_null()
		if field != null:
			assert_object(field.ground()).override_failure_message(scene_path).is_not_null()
			assert_object(field.blocking()).override_failure_message(scene_path).is_not_null()
			var controller: ClickMoveController = (
				scene.find_child("ClickMoveController", true, false) as ClickMoveController
			)
			assert_object(controller).override_failure_message(scene_path).is_not_null()
			if controller != null:
				assert_object(field.iso_grid()).is_same(controller.get_iso_grid())

		scene.queue_free()
		await get_tree().process_frame


func test_dom_interiors_are_no_combat_zones_and_streets_and_wilds_are_not() -> void:
	for scene_path: String in GameFlow.GAMEPLAY_SCENES:
		var packed_scene: PackedScene = load(scene_path) as PackedScene
		if packed_scene == null:
			continue
		var scene: Node = packed_scene.instantiate()
		var field: FieldMap = _find_field_map(scene)
		assert_object(field).override_failure_message(scene_path).is_not_null()
		if field != null:
			var expected_no_combat: bool = scene_path.begins_with("res://world/interiors/")
			assert_bool(field.no_combat_zone()).override_failure_message(scene_path).is_equal(
				expected_no_combat
			)
		scene.free()


func _find_field_map(scene: Node) -> FieldMap:
	return scene.find_child("FieldMap", true, false) as FieldMap
