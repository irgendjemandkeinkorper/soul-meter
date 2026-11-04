extends GdUnitTestSuite
## The Ferry Bell Wayhouse as a walk-in building on the Kesselford map (owner list item 35,
## 2026-11-03: "One prototype", "One-cell wall line", "Grow to 12 × 9", "Retire, redirect saves").
## Its wall line stands in the scene as `WallBody` shapes and on the painted grid, the walk goes
## in through the doorway to the keeper, its walls stop a line of fire, its two people stand on its
## floor, the roof lifts when the player walks in, and a save made in the retired Wayhouse room
## loads inside the building.

const KESSELFORD := "res://world/kesselford.tscn"
const RETIRED_ROOM := "res://world/interiors/kesselford_wayhouse.tscn"
const PAINT_TOOL := "res://tools/paint_blocking.gd"
const WAYHOUSE_PATH := "KesselfordDressing/SolidProps/Wayhouse"
const WAYHOUSE_IDS: Array[String] = ["kesselford-wayhouse-keeper", "kesselford-grain-factor"]
const WAYHOUSE_FURNITURE := {
	"WayhouseCounter": "counter-4x1", "WayhouseTable": "table-3x2", "WayhouseBench": "bench-3x1",
	"WayhouseStool": "stool-1x1", "WayhouseChest": "chest-1x1",
}

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


## Fights can happen inside (owner list item 35, 2026-11-03: "yeah fights can happen there"), so
## the walls stop a line of fire as they stop a walk. paint_blocking.gd writes the wall line, less
## its windows, into the map's combat terrain (`blocks_fire_cells`): "Shots pass windows" (2026-11-03).
func test_the_walls_stop_a_line_of_fire_and_the_doorway_and_windows_let_it_through() -> void:
	var town := await _load_town()
	var building := town.get_node(WAYHOUSE_PATH) as WalkInBuilding
	var terrain := town.get_node("Terrain") as CombatTerrainLayer
	assert_array(terrain.blocks_fire_cells).override_failure_message("Run tools/paint_blocking.gd.") \
		.is_equal(building.blocks_fire_cells())
	for cell: Vector2i in building.blocks_fire_cells():
		assert_int(terrain.get_cell_alternative_tile(cell)).is_equal(CombatTerrainLayer.WALL_ALTERNATIVE)
	# The Wayhouse has windows, and none of them is in the terrain.
	assert_int(building.blocks_fire_cells().size()).is_less(building.wall_cells().size())
	var ground := SolidFootprints.find_ground(town)
	var model := GridBattlefieldModel.new()
	model.build_grid(ground, town.get_node("Blocking") as TileMapLayer)
	var grid := (town.find_child("FieldMap", true, false) as FieldMap).iso_grid()
	var origin := building.origin_cell
	# Down the middle of the two-cell doorway (cells 9 and 10 of the front wall, row 8).
	var through_door := model.line_of_sight_between_cells(
		_fight_cell(grid, ground, origin, Vector2(9.5, 11)), _fight_cell(grid, ground, origin, Vector2(9.5, 5))
	)
	assert_bool(through_door["allowed"]).override_failure_message("doorway shot: %s" % str(through_door)).is_true()
	# Through the window at cell 5 of the front wall (row 8): walls stand on either side of it.
	assert_bool(5 in building.windows.get(WalkInBuilding.Side.FRONT_LEFT, [])).is_true()
	var through_window := model.line_of_sight_between_cells(
		_fight_cell(grid, ground, origin, Vector2(5, 11)), _fight_cell(grid, ground, origin, Vector2(5, 5))
	)
	assert_bool(through_window["allowed"]).override_failure_message("window shot: %s" % str(through_window)).is_true()
	# Through the front wall at cell 6, and through the back wall from behind the building.
	var through_walls := {
		"front wall": [Vector2(6, 11), Vector2(6, 5)],
		"back wall": [Vector2(5, -3), Vector2(5, 3)],
	}
	for wall: String in through_walls:
		var ends: Array = through_walls[wall]
		var shot := model.line_of_sight_between_cells(
			_fight_cell(grid, ground, origin, ends[0]), _fight_cell(grid, ground, origin, ends[1])
		)
		assert_str(String(shot["blocked_by"])).override_failure_message("%s shot: %s" % [wall, str(shot)]) \
			.is_equal("blocked_by_obstacle")
	await _unload(town)


## Item 35 polish (2026-11-04): the Wayhouse furniture is kit art drawn at the map's camera, not
## the old room's painted props. Each sprite stands on its piece's pivot, the centre of the
## footprint its body blocks, and the body's shape spans the piece's cells.
func test_the_furniture_is_kit_art_on_its_footprint() -> void:
	var root: Node = auto_free((load(KESSELFORD) as PackedScene).instantiate())
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WalkInBuilding.KIT_MANIFEST))
	var pieces: Dictionary = manifest["pieces"]
	for node_name: String in WAYHOUSE_FURNITURE:
		var piece: String = WAYHOUSE_FURNITURE[node_name]
		var body := root.get_node("KesselfordDressing/SolidProps/" + node_name) as StaticBody2D
		var sprite := body.get_node("Sprite2D") as Sprite2D
		var entry: Dictionary = pieces[piece]
		var pivot: Array = entry["pivot"]
		assert_str(sprite.texture.resource_path).is_equal(WalkInBuilding.KIT_DIR + str(entry["file"]))
		assert_bool(sprite.centered).is_false()
		assert_vector(sprite.scale).is_equal(Vector2.ONE)
		assert_vector(sprite.offset).override_failure_message("%s offset" % node_name) \
			.is_equal_approx(-Vector2(float(pivot[0]), float(pivot[1])), Vector2.ONE * 0.01)
		# A footprint of a x b cells is 32 (a + b) px wide on the 64 x 32 grid. The shape stands
		# 3 px in from each edge, which pulls each side corner in by 3 / sin(26.57°), about 6.7 px.
		var size := piece.get_slice("-", 1).split("x")
		var span := 32.0 * (float(size[0]) + float(size[1]))
		var polygon := ((body.get_node("CollisionShape2D") as CollisionShape2D).shape as ConvexPolygonShape2D).points
		var low := polygon[0]
		var high := polygon[0]
		for point: Vector2 in polygon:
			low = low.min(point)
			high = high.max(point)
		assert_float(high.x - low.x).override_failure_message("%s shape width" % node_name).is_between(span - 16.0, span)
		assert_vector((low + high) * 0.5).is_equal_approx(Vector2.ZERO, Vector2.ONE * 0.5)


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


## The fight grid's cell under a point given in the building's own cells, counted from its back
## corner cell (`origin`); fractions fall between cells.
func _fight_cell(grid: IsoGrid, ground: TileMapLayer, origin: Vector2i, at: Vector2) -> Vector2i:
	var base := ground.map_to_local(origin)
	var along_i := ground.map_to_local(origin + Vector2i(1, 0)) - base
	var along_j := ground.map_to_local(origin + Vector2i(0, 1)) - base
	return grid.world_to_cell(ground.to_global(base + along_i * at.x + along_j * at.y))


func _unload(scene: Node) -> void:
	scene.queue_free()
	await get_tree().process_frame
