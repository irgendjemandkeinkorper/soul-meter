extends GdUnitTestSuite
## Kesselford dressed densely (lived-in maps, owner 2026-11-02). The generated dressing loads
## with the map; its solid pieces block the grid that walking and combat share; spawns and
## exits stay clear; standing props cast contact shadows and buildings do not.

const SCENE := "res://world/kesselford.tscn"

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	if GameState.party.is_empty():
		GameState._seed_demo_data()


func after_test() -> void:
	UIManager.close_all()
	GameState.from_dict(_saved_state)


func test_the_dressing_loads_and_its_solid_pieces_block_the_shared_grid() -> void:
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(6)
	var lived_in := root.find_child("LivedIn", true, false) as LivedIn
	assert_object(lived_in).is_not_null()
	assert_int(lived_in.get_node("Props").get_child_count()).is_greater(80)
	assert_int(lived_in.get_node("GroundDetails").get_child_count()).is_greater(150)
	assert_int(lived_in.blocked_cells.size()).is_greater(0)
	var blocking := root.find_child("Blocking", true, false) as TileMapLayer
	var grid := (root.find_child("FieldMap", true, false) as FieldMap).iso_grid()
	assert_object(grid).is_not_null()
	for cell: Vector2i in lived_in.blocked_cells:
		assert_int(blocking.get_cell_source_id(cell)).override_failure_message("painted %s" % cell).is_equal(0)
		assert_bool(grid.is_point_solid(cell)).override_failure_message("solid for paths %s" % cell).is_true()
	var terrain := root.find_child("Terrain", true, false) as TileMapLayer
	for cell: Vector2i in lived_in.cover_cells:
		assert_vector(Vector2(terrain.get_cell_atlas_coords(cell))).is_equal(Vector2(1, 0))


func test_spawns_and_exits_stay_clear() -> void:
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(6)
	var lived_in := root.find_child("LivedIn", true, false) as LivedIn
	var grid := (root.find_child("FieldMap", true, false) as FieldMap).iso_grid()
	var points: Array[Vector2] = []
	for marker: Node in root.find_children("*", "Marker2D", true, false):
		points.append((marker as Node2D).global_position)
	for area: Node in root.find_children("*", "Area2D", true, false):
		if not lived_in.is_ancestor_of(area):
			points.append((area as Node2D).global_position)
	assert_int(points.size()).is_greater(3)
	for point: Vector2 in points:
		var cell := grid.world_to_cell(point)
		assert_bool(lived_in.blocked_cells.has(cell)).override_failure_message("blocked at %s" % point).is_false()
	for sprite: Node in lived_in.get_node("Props").get_children():
		for point: Vector2 in points:
			assert_float((sprite as Node2D).global_position.distance_to(point)).override_failure_message(
				"%s crowds %s" % [sprite.name, point]).is_greater(40.0)


## Owner 2026-11-02, "calm the ground first": the painted ground is calmed so props read on it.
func test_the_painted_ground_is_calmed() -> void:
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(2)
	var backdrop := root.get_node("TerrainBackdrop") as Sprite2D
	var material := backdrop.material as ShaderMaterial
	assert_object(material).is_not_null()
	assert_str(material.shader.resource_path).is_equal("res://world/dressing/ground_calm.gdshader")


func test_standing_props_cast_contact_shadows_and_buildings_do_not() -> void:
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(6)
	var shadows := root.find_child("DressingShadows", true, false) as DressingShadows
	assert_object(shadows).is_not_null()
	var props := root.find_child("LivedIn", true, false).get_node("Props").get_child_count()
	assert_int(shadows.shadow_count()).is_greater_equal(props)
	for rect: Rect2 in shadows.shadow_rects():
		assert_float(rect.size.x).override_failure_message("a facade cast a shadow").is_less(DressingShadows.MAX_HEIGHT_PX * 1.2)
