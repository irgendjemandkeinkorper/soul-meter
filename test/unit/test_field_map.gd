extends GdUnitTestSuite

const TEST_ROOM_SCENE := "res://world/test_room.tscn"
const TEST_ROOM_BLOCKED_CELL := Vector2i(23, 23)
const TEST_ROOM_OPEN_CELL := Vector2i(30, 30)

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


## test_room paints its Blocking layer over the four solid props under
## FieldRoomDressing/SolidProps; RootArchwayNorth covers (23, 23).
func test_test_room_blocking_layer_is_authored_and_solid_in_the_shared_grid() -> void:
	var scene: Node = (load(TEST_ROOM_SCENE) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame

	var field: FieldMap = _find_field_map(scene)
	var painted: Array[Vector2i] = field.blocking().get_used_cells()
	assert_array(painted).is_not_empty()
	assert_array(painted).contains([TEST_ROOM_BLOCKED_CELL])
	var grid: IsoGrid = field.iso_grid()
	for cell: Vector2i in painted:
		assert_bool(grid.is_point_solid(cell)).override_failure_message(str(cell)).is_true()
	assert_bool(grid.is_point_solid(TEST_ROOM_OPEN_CELL)).is_false()

	scene.queue_free()
	await get_tree().process_frame


func test_set_combat_mode_disables_free_movement_and_travel_and_restores_them() -> void:
	var scene: Node = (load(TEST_ROOM_SCENE) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame

	var field: FieldMap = _find_field_map(scene)
	var player: Player = scene.find_child("Player", true, false) as Player
	var controller: ClickMoveController = (
		scene.find_child("ClickMoveController", true, false) as ClickMoveController
	)
	var travel_exit: TravelExit = scene.find_child("ReturnToDom", true, false) as TravelExit
	var enemy: Enemy = scene.find_child("BogWight", true, false) as Enemy
	assert_bool(field.combat_mode_active()).is_false()
	assert_bool(player.is_physics_processing()).is_true()
	assert_bool(controller.enabled).is_true()
	assert_bool(travel_exit.monitoring).is_true()
	assert_bool(enemy.is_processing_unhandled_input()).is_true()

	field.set_combat_mode(true)
	assert_bool(field.combat_mode_active()).is_true()
	assert_bool(player.is_physics_processing()).is_false()
	assert_bool(controller.enabled).is_false()
	assert_bool(travel_exit.monitoring).is_false()
	assert_bool(enemy.is_processing_unhandled_input()).is_false()

	field.set_combat_mode(false)
	assert_bool(field.combat_mode_active()).is_false()
	assert_bool(player.is_physics_processing()).is_true()
	assert_bool(controller.enabled).is_true()
	assert_bool(travel_exit.monitoring).is_true()
	assert_bool(enemy.is_processing_unhandled_input()).is_true()

	scene.queue_free()
	await get_tree().process_frame


func _find_field_map(scene: Node) -> FieldMap:
	return scene.find_child("FieldMap", true, false) as FieldMap
