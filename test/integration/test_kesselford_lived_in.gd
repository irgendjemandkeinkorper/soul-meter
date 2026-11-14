extends GdUnitTestSuite
## Kesselford dressed densely (lived-in maps, owner 2026-11-02). The generated dressing loads
## with the map; its solid pieces block the grid that walking and combat share; spawns and
## exits stay clear; standing props cast contact shadows and buildings do not.

const SCENE := "res://world/kesselford.tscn"
const DressLocation := preload("res://tools/dress_location.gd")

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
	var ground := root.find_child("IsometricGround", true, false) as TileMapLayer
	for cell: Vector2i in lived_in.blocked_cells:
		assert_int(blocking.get_cell_source_id(cell)).override_failure_message("painted %s" % cell).is_equal(0)
		# The walking grid answers in its own cells (hexes since H3b): the one over this square.
		var walk_cell := grid.world_to_cell(ground.to_global(ground.map_to_local(cell)))
		assert_bool(grid.is_point_solid(walk_cell)).override_failure_message("solid for paths %s" % cell).is_true()
	var terrain := root.find_child("Terrain", true, false) as TileMapLayer
	for cell: Vector2i in lived_in.cover_cells:
		assert_vector(Vector2(terrain.get_cell_atlas_coords(cell))).is_equal(Vector2(1, 0))


func test_spawns_and_exits_stay_clear() -> void:
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(6)
	var lived_in := root.find_child("LivedIn", true, false) as LivedIn
	var points: Array[Vector2] = []
	for marker: Node in root.find_children("*", "Marker2D", true, false):
		points.append((marker as Node2D).global_position)
	for area: Node in root.find_children("*", "Area2D", true, false):
		if not lived_in.is_ancestor_of(area):
			points.append((area as Node2D).global_position)
	assert_int(points.size()).is_greater(3)
	var ground := root.find_child("IsometricGround", true, false) as TileMapLayer
	for point: Vector2 in points:
		var cell := ground.local_to_map(ground.to_local(point))
		assert_bool(lived_in.blocked_cells.has(cell)).override_failure_message("blocked at %s" % point).is_false()
	for sprite: Node in lived_in.get_node("Props").get_children():
		for point: Vector2 in points:
			assert_float((sprite as Node2D).global_position.distance_to(point)).override_failure_message(
				"%s crowds %s" % [sprite.name, point]).is_greater(40.0)


## Walk-in buildings (item 35) furnish themselves: the dressing never lands on their floor, and
## no solid piece stands on a doorway's two-cell apron, inside or out.
func test_walk_in_floors_and_doorways_stay_clear() -> void:
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(6)
	var lived_in := root.find_child("LivedIn", true, false) as LivedIn
	var ground := root.find_child("IsometricGround", true, false) as TileMapLayer
	var buildings := DressLocation.walk_in_buildings(root)
	assert_int(buildings.size()).is_greater_equal(4)
	var floor: Dictionary = {}
	var aprons: Array[Rect2] = []
	for building: WalkInBuilding in buildings:
		for cell: Vector2i in building.footprint_cells():
			floor[cell] = building.name
		var plan := building.plan()
		for cell: Vector2i in plan.footprint_cells():
			if plan.at(cell) == DressLocation.DOORWAY:
				var at := ground.to_global(ground.map_to_local(building.origin_cell + cell))
				aprons.append(Rect2(at - DressLocation.DOORWAY_APRON, DressLocation.DOORWAY_APRON * 2.0))
	assert_int(aprons.size()).is_greater_equal(buildings.size())
	for layer: String in ["Props", "GroundDetails"]:
		for sprite: Node in lived_in.get_node(layer).get_children():
			var cell := ground.local_to_map(ground.to_local((sprite as Node2D).global_position))
			assert_bool(floor.has(cell)).override_failure_message(
				"%s dressed on %s's floor at %s" % [sprite.name, floor.get(cell, ""), cell]).is_false()
	for cell: Vector2i in lived_in.blocked_cells:
		var at := ground.to_global(ground.map_to_local(cell))
		for apron: Rect2 in aprons:
			assert_bool(apron.has_point(at)).override_failure_message(
				"a solid piece blocks a doorway apron at %s" % cell).is_false()


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


## A walk-in building (item 35) is built from wall, floor and furniture sprites under
## `SolidProps`; none of them is a prop standing on the ground, so none casts a contact shadow.
func test_walk_in_buildings_cast_no_contact_shadows() -> void:
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(6)
	var shadows := root.find_child("DressingShadows", true, false) as DressingShadows
	var ground := root.find_child("IsometricGround", true, false) as TileMapLayer
	var floor: Dictionary = {}
	for building: WalkInBuilding in DressLocation.walk_in_buildings(root):
		for cell: Vector2i in building.footprint_cells():
			floor[cell] = building.name
	assert_int(floor.size()).is_greater(0)
	var on_floor := 0
	for rect: Rect2 in shadows.shadow_rects():
		var cell := ground.local_to_map(ground.to_local(shadows.to_global(rect.get_center())))
		if floor.has(cell):
			on_floor += 1
	assert_int(on_floor).override_failure_message("%d shadows inside walk-in buildings" % on_floor).is_equal(0)
