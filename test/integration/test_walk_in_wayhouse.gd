extends GdUnitTestSuite
## The Ferry Bell Wayhouse as a walk-in building on the Kesselford map (owner list item 35,
## 2026-11-03: "One prototype", "One-cell wall line", "Grow to 12 × 9", "Retire, redirect saves").
## Its wall line stands in the scene as `WallBody` shapes and on the painted grid, the walk goes
## in through the doorway to the keeper, its two people stand on its floor, the roof lifts when
## the player walks in, and a save made in the retired Wayhouse room loads inside the building.

const KESSELFORD := "res://world/kesselford.tscn"
const RETIRED_ROOM := "res://world/interiors/kesselford_wayhouse.tscn"
const PAINT_TOOL := "res://tools/paint_blocking.gd"
const WAYHOUSE_PATH := "KesselfordDressing/SolidProps/Wayhouse"
const WAYHOUSE_IDS: Array[String] = ["kesselford-wayhouse-keeper", "kesselford-grain-factor"]

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)


func after_test() -> void:
	GameState.from_dict(_saved_state)


## paint_blocking.gd writes the wall line into the scene; this fails when the building changed
## (size, door, place) and the tool was not run again.
func test_the_wall_body_holds_the_building_wall_line() -> void:
	var root: Node = auto_free((load(KESSELFORD) as PackedScene).instantiate())
	var building := root.get_node(WAYHOUSE_PATH) as WalkInBuilding
	assert_object(building).is_not_null()
	var ground := SolidFootprints.find_ground(root)
	var to_building := SolidFootprints.transform_in(building, root).affine_inverse()
	building.bind(ground, to_building * SolidFootprints.transform_in(ground, root))
	var expected := building.wall_polygons()
	var body := building.get_node_or_null(WalkInBuilding.WALL_BODY) as StaticBody2D
	assert_object(body).override_failure_message("Run tools/paint_blocking.gd.").is_not_null()
	if body == null:
		return
	var shapes: Array[ConvexPolygonShape2D] = []
	for child: Node in body.get_children():
		var shape_node := child as CollisionShape2D
		assert_object(shape_node).is_not_null()
		if shape_node != null:
			assert_vector(shape_node.position).is_equal(Vector2.ZERO)
			shapes.append(shape_node.shape as ConvexPolygonShape2D)
	assert_int(shapes.size()).override_failure_message("Run tools/paint_blocking.gd.").is_equal(expected.size())
	for index in mini(shapes.size(), expected.size()):
		assert_object(shapes[index]).is_not_null()
		if shapes[index] == null:
			continue
		assert_int(shapes[index].points.size()).is_equal(expected[index].size())
		for point in mini(shapes[index].points.size(), expected[index].size()):
			assert_vector(shapes[index].points[point]).is_equal_approx(expected[index][point], Vector2.ONE * 0.02)
	# The painted layer holds every wall cell as a thin solid, and the doorway stays open.
	var blocking := root.get_node("Blocking") as TileMapLayer
	assert_int(load(PAINT_TOOL).get_script_constant_map()["THIN_TILE"]).is_equal(BlockingLayer.THIN_TILE)
	for cell: Vector2i in building.wall_cells():
		assert_int(blocking.get_cell_source_id(cell)).override_failure_message("wall cell %s" % str(cell)).is_not_equal(-1)
		assert_int(blocking.get_cell_alternative_tile(cell)).override_failure_message("wall cell %s" % str(cell)) \
			.is_equal(BlockingLayer.THIN_TILE)
	var footprint := Rect2i(building.origin_cell, building.cells)
	for cell: Vector2i in blocking.get_used_cells():
		var tile := BlockingLayer.THIN_TILE if footprint.has_point(cell) else 0
		assert_int(blocking.get_cell_alternative_tile(cell)).override_failure_message("painted cell %s" % str(cell)) \
			.is_equal(tile)
	for index in building.door_width:
		var doorway := building.origin_cell + building.ring_cell(building.door_side, building.door_start + index)
		assert_int(blocking.get_cell_source_id(doorway)).override_failure_message("doorway %s" % str(doorway)).is_equal(-1)


## The player's walk grid keeps a body's width clear of solid cells, but not of the thin cells
## inside a walk-in building (BlockingLayer.THIN_TILE), so the two-cell doorway and the room stay
## open while every wall cell stays shut. The walk runs on hexes when `soul_meter/grid/hex` is on.
func test_the_walk_goes_in_through_the_doorway_to_the_keeper() -> void:
	var town := await _load_town()
	var grid := (town.find_child("FieldMap", true, false) as FieldMap).iso_grid()
	var ground := SolidFootprints.find_ground(town)
	var building := town.get_node(WAYHOUSE_PATH) as WalkInBuilding
	var walls := building.wall_cells()
	var doorway: Array[Vector2i] = []
	for index in building.door_width:
		doorway.append(building.origin_cell + building.ring_cell(building.door_side, building.door_start + index))
	for cell: Vector2i in walls:
		var centre := ground.to_global(ground.map_to_local(cell))
		assert_bool(grid.is_wall(grid.world_to_cell(centre))).override_failure_message("wall cell %s" % str(cell)).is_true()
	for cell: Vector2i in doorway:
		var centre := ground.to_global(ground.map_to_local(cell))
		assert_bool(grid.is_wall(grid.world_to_cell(centre))).override_failure_message("doorway %s" % str(cell)).is_false()
	var outside := grid.world_to_cell((town.get_node("SpawnFromKesselfordWayhouse") as Node2D).global_position)
	# Beside the keeper, behind the counter: the cell left of the keeper's spot.
	var keeper_spot := (town.get_node("WayhouseKeeperSpot") as Node2D).global_position
	var beside_keeper := grid.world_to_cell(keeper_spot + Vector2(-32, -16))
	var path := grid.path_cells(outside, beside_keeper)
	assert_int(path.size()).override_failure_message("no walk from the street to the keeper").is_greater(0)
	# The ring is closed except at the doorway, so the walk in must cross it there.
	var crossed := false
	for point: Vector2 in path:
		var square := ground.local_to_map(ground.to_local(grid.cell_to_world(Vector2i(point))))
		crossed = crossed or square in doorway
		assert_bool(square in walls).override_failure_message("the walk crosses wall cell %s" % str(square)).is_false()
	assert_bool(crossed).override_failure_message("the walk in misses the doorway %s" % str(doorway)).is_true()
	# Outside the building the clearance ring is unchanged: the open cell next to a solid prop's
	# painted cell is still shut to the walk.
	var blocking := town.get_node("Blocking") as TileMapLayer
	var footprint := Rect2i(building.origin_cell, building.cells)
	var ringed := Vector2i(-1, -1)
	for cell: Vector2i in blocking.get_used_cells():
		var next := cell + Vector2i(1, 0)
		if not footprint.has_point(cell) and blocking.get_cell_source_id(next) == -1:
			ringed = next
			break
	assert_bool(ringed != Vector2i(-1, -1)).is_true()
	var ringed_centre := ground.to_global(ground.map_to_local(ringed))
	assert_bool(grid.is_wall(grid.world_to_cell(ringed_centre))).override_failure_message(
		"no clearance ring at %s" % str(ringed)
	).is_true()
	await _unload(town)


func test_the_keeper_and_the_grain_factor_stand_on_the_wayhouse_floor() -> void:
	var runner := scene_runner(KESSELFORD)
	await runner.simulate_frames(5)
	var town: Node2D = runner.scene()
	var building := town.get_node(WAYHOUSE_PATH) as WalkInBuilding
	var found: Array[String] = []
	for node: Node in town.get_tree().get_nodes_in_group(&"generated_townsfolk"):
		var npc := node as NPC
		if npc == null or not town.is_ancestor_of(npc):
			continue
		var npc_id := str(npc.get_meta(&"npc_id", ""))
		if not npc_id in WAYHOUSE_IDS:
			continue
		found.append(npc_id)
		var feet := building.to_local(npc.global_position)
		assert_bool(Geometry2D.is_point_in_polygon(feet, building.footprint_polygon())) \
			.override_failure_message("%s stands at %s, off the Wayhouse floor" % [npc_id, npc.global_position]) \
			.is_true()
	assert_array(found).contains_exactly_in_any_order(WAYHOUSE_IDS)


func test_the_roof_lifts_when_the_player_walks_in() -> void:
	var runner := scene_runner(KESSELFORD)
	await runner.simulate_frames(3)
	var town: Node2D = runner.scene()
	var building := town.get_node(WAYHOUSE_PATH) as WalkInBuilding
	var player := town.get_node("Player") as Node2D
	assert_int(building.current_look()).is_equal(WalkInBuilding.Look.OUTSIDE)
	player.global_position = (town.get_node("SpawnInKesselfordWayhouse") as Node2D).global_position
	await runner.simulate_frames(3)
	assert_int(building.current_look()).is_equal(WalkInBuilding.Look.INSIDE)
	var outside := (town.get_node("SpawnFromKesselfordWayhouse") as Node2D).global_position
	for group: StringName in WalkInBuilding.PARTY_GROUPS:
		for node: Node in town.get_tree().get_nodes_in_group(group):
			if node is Node2D:
				(node as Node2D).global_position = outside
	await runner.simulate_frames(3)
	assert_int(building.current_look()).is_equal(WalkInBuilding.Look.OUTSIDE)


func test_a_save_made_in_the_retired_room_loads_inside_the_wayhouse() -> void:
	var by_scene := SaveGame._destination_from_payload({
		"scene": RETIRED_ROOM, "spawn_id": "entry", "player_position": Vector2(960, 800),
	})
	var by_id := SaveGame._destination_from_payload({
		"scene": RETIRED_ROOM, "location_id": "kesselford_wayhouse", "spawn_id": "entry",
		"player_position": Vector2(960, 800),
	})
	for destination: LoadDestination in [by_scene, by_id]:
		assert_object(destination).is_not_null()
		if destination == null:
			continue
		assert_str(String(destination.location_id)).is_equal("kesselford")
		assert_str(String(destination.spawn_id)).is_equal("in_kesselford_wayhouse")
		# The old room's coordinates mean nothing on the map: the load uses the spawn marker.
		assert_bool(destination.has_position).is_false()
	# A save on the Kesselford street keeps its own place.
	var street := SaveGame._destination_from_payload({
		"scene": KESSELFORD, "location_id": "kesselford", "spawn_id": "from_dom",
		"player_position": Vector2(1500, 900),
	})
	assert_object(street).is_not_null()
	if street != null:
		assert_str(String(street.spawn_id)).is_equal("from_dom")
		assert_bool(street.has_position).is_true()


func _load_town() -> Node:
	var scene := (load(KESSELFORD) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return scene


func _unload(scene: Node) -> void:
	scene.queue_free()
	await get_tree().process_frame
