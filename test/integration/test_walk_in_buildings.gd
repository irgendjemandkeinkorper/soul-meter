extends GdUnitTestSuite
## The walk-in buildings on the Kesselford map (owner list item 35: "One prototype", "One-cell wall
## line", "Retire, redirect saves", 2026-11-03; layouts "All four", "Your room opens" and "Cottage +
## warehouse south", 2026-11-04): the Ferry Bell Wayhouse (tavern), the Ford Chandlery (shop), a
## cottage and a warehouse. Their walls stand in the scene as `WallBody` shapes and on the painted
## grid, a walk from the street reaches every room through a doorway, walls stop a line of fire and
## windows let it through, the Wayhouse pair stand on its floor, the chandler trades across the
## counter, the roof lifts room by room, and saves made in the retired rooms load inside.

const KESSELFORD := "res://world/kesselford.tscn"
const RETIRED_WAYHOUSE := "res://world/interiors/kesselford_wayhouse.tscn"
const RETIRED_CHANDLERY := "res://world/interiors/kesselford_chandlery.tscn"
const PAINT_TOOL := "res://tools/paint_blocking.gd"
const SOLID_PROPS := "KesselfordDressing/SolidProps/"
const BUILDINGS: Array[String] = ["Wayhouse", "Chandlery", "Cottage", "Warehouse"]
const WAYHOUSE_IDS: Array[String] = ["kesselford-wayhouse-keeper", "kesselford-grain-factor"]

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)


func after_test() -> void:
	GameState.from_dict(_saved_state)


func test_the_map_holds_the_four_layouts() -> void:
	var root: Node = auto_free((load(KESSELFORD) as PackedScene).instantiate())
	var expected := {
		"Wayhouse": ["tavern", 0], "Chandlery": ["shop", 0], "Cottage": ["cottage", 1], "Warehouse": ["warehouse", 1],
	}
	var found: Array[String] = []
	for node: Node in root.find_children("*", "Node2D", true, false):
		if node is WalkInBuilding:
			found.append(String(node.name))
	assert_array(found).contains_exactly_in_any_order(BUILDINGS)
	for building_name: String in expected:
		var building := root.get_node(SOLID_PROPS + building_name) as WalkInBuilding
		var row: Array = expected[building_name]
		assert_str(building.layout.resource_path.get_file().get_basename()).is_equal(row[0])
		assert_int(building.quarter_turns).is_equal(row[1])


## paint_blocking.gd writes each building's solid cells into the scene; this fails when a building
## changed (layout, turn, place) and the tool was not run again.
func test_each_wall_body_holds_its_building_s_solid_cells() -> void:
	var root: Node = auto_free((load(KESSELFORD) as PackedScene).instantiate())
	var blocking := root.get_node("Blocking") as TileMapLayer
	assert_int(load(PAINT_TOOL).get_script_constant_map()["THIN_TILE"]).is_equal(BlockingLayer.THIN_TILE)
	var footprints := {}
	for building_name: String in BUILDINGS:
		var building := _bound(root, building_name)
		var expected := building.solid_polygons()
		var body := building.get_node_or_null(WalkInBuilding.WALL_BODY) as StaticBody2D
		assert_object(body).override_failure_message("Run tools/paint_blocking.gd.").is_not_null()
		if body == null:
			continue
		var shapes: Array[ConvexPolygonShape2D] = []
		for child: Node in body.get_children():
			var shape_node := child as CollisionShape2D
			assert_object(shape_node).is_not_null()
			if shape_node != null:
				assert_vector(shape_node.position).is_equal(Vector2.ZERO)
				shapes.append(shape_node.shape as ConvexPolygonShape2D)
		assert_int(shapes.size()).override_failure_message("%s: run tools/paint_blocking.gd." % building_name) \
			.is_equal(expected.size())
		for index in mini(shapes.size(), expected.size()):
			assert_int(shapes[index].points.size()).is_equal(expected[index].size())
			for point in mini(shapes[index].points.size(), expected[index].size()):
				assert_vector(shapes[index].points[point]).is_equal_approx(expected[index][point], Vector2.ONE * 0.02)
		# Solid cells are painted thin; floor and doorways stay open.
		var solid := building.solid_cells()
		for cell: Vector2i in building.footprint_cells():
			footprints[cell] = true
			var painted := blocking.get_cell_source_id(cell) != -1
			assert_bool(painted).override_failure_message("%s cell %s" % [building_name, cell]).is_equal(cell in solid)
			if painted:
				assert_int(blocking.get_cell_alternative_tile(cell)).is_equal(BlockingLayer.THIN_TILE)
	# Off the footprints, painted cells keep their clearance ring.
	for cell: Vector2i in blocking.get_used_cells():
		if not footprints.has(cell):
			assert_int(blocking.get_cell_alternative_tile(cell)).override_failure_message("painted cell %s" % cell).is_equal(0)


## The player's walk grid keeps a body's width clear of solid cells, but not of the thin cells
## inside a walk-in building, so doorways and rooms stay open. From the street, the walk reaches
## every room of every building, the tucked-away ones too, through a doorway and never a wall.
func test_the_walk_reaches_every_room_through_a_doorway() -> void:
	var town := await _load_town()
	var grid := (town.find_child("FieldMap", true, false) as FieldMap).iso_grid()
	var ground := SolidFootprints.find_ground(town)
	var street := grid.world_to_cell((town.get_node("SpawnDefault") as Node2D).global_position)
	var all_solid := {}
	for building_name: String in BUILDINGS:
		for cell: Vector2i in (town.get_node(SOLID_PROPS + building_name) as WalkInBuilding).solid_cells():
			all_solid[cell] = true
	for building_name: String in BUILDINGS:
		var building := town.get_node(SOLID_PROPS + building_name) as WalkInBuilding
		var plan := building.plan()
		for cell: Vector2i in building.wall_cells():
			var centre := ground.to_global(ground.map_to_local(cell))
			assert_bool(grid.is_wall(grid.world_to_cell(centre))).override_failure_message("%s wall %s" % [building_name, cell]).is_true()
		for room in range(1, plan.room_count + 1):
			var target := _open_floor_cell(building, grid, ground, room)
			assert_bool(target != Vector2i(-1, -1)).override_failure_message("%s room %d" % [building_name, room]).is_true()
			var path := grid.path_cells(street, grid.world_to_cell(ground.to_global(ground.map_to_local(target))))
			assert_int(path.size()).override_failure_message("%s: no walk to room %d" % [building_name, room]).is_greater(0)
			var crossed := false
			for point: Vector2 in path:
				var square := ground.local_to_map(ground.to_local(grid.cell_to_world(Vector2i(point))))
				crossed = crossed or plan.at(square - building.origin_cell) == BuildingPlan.DOOR
				assert_bool(all_solid.has(square)).override_failure_message("%s room %d: the walk crosses %s" % [
					building_name, room, square,
				]).is_false()
			assert_bool(crossed).override_failure_message("%s room %d: the walk misses every doorway" % [building_name, room]).is_true()
	await _unload(town)


## Fights can happen inside (owner list item 35, 2026-11-03), so walls stop a line of fire as they
## stop a walk. paint_blocking.gd writes every building's walls, less windows ("Shots pass
## windows", 2026-11-03), into the map's combat terrain.
func test_the_walls_stop_a_line_of_fire_and_doorways_and_windows_let_it_through() -> void:
	var town := await _load_town()
	var terrain := town.get_node("Terrain") as CombatTerrainLayer
	var expected := {}
	for building_name: String in BUILDINGS:
		for cell: Vector2i in (town.get_node(SOLID_PROPS + building_name) as WalkInBuilding).blocks_fire_cells():
			expected[cell] = true
	var written := {}
	for cell: Vector2i in terrain.blocks_fire_cells:
		written[cell] = true
		assert_int(terrain.get_cell_alternative_tile(cell)).is_equal(CombatTerrainLayer.WALL_ALTERNATIVE)
	assert_array(written.keys()).override_failure_message("Run tools/paint_blocking.gd.") \
		.contains_exactly_in_any_order(expected.keys())
	var tavern := town.get_node(SOLID_PROPS + "Wayhouse") as WalkInBuilding
	var ground := SolidFootprints.find_ground(town)
	var model := GridBattlefieldModel.new()
	model.build_grid(ground, town.get_node("Blocking") as TileMapLayer)
	var grid := (town.find_child("FieldMap", true, false) as FieldMap).iso_grid()
	var origin := tavern.origin_cell
	# The front wall is row 12: the doorway is cells 5 and 6, a window is cell 2, cell 3 is wall.
	assert_str(tavern.plan().at(Vector2i(2, 12))).is_equal(BuildingPlan.WINDOW)
	var allowed := {"doorway": [Vector2(5.5, 15), Vector2(5.5, 9)], "window": [Vector2(2, 15), Vector2(2, 10)]}
	for gap: String in allowed:
		var ends: Array = allowed[gap]
		var shot := model.line_of_sight_between_cells(_fight_cell(grid, ground, origin, ends[0]), _fight_cell(grid, ground, origin, ends[1]))
		assert_bool(shot["allowed"]).override_failure_message("%s shot: %s" % [gap, shot]).is_true()
	var blocked := {"front wall": [Vector2(3, 15), Vector2(3, 9)], "back wall": [Vector2(8, -3), Vector2(8, 3)]}
	for wall: String in blocked:
		var ends: Array = blocked[wall]
		var shot := model.line_of_sight_between_cells(_fight_cell(grid, ground, origin, ends[0]), _fight_cell(grid, ground, origin, ends[1]))
		assert_str(String(shot["blocked_by"])).override_failure_message("%s shot: %s" % [wall, shot]).is_equal("blocked_by_obstacle")
	await _unload(town)


## Every building on the map finds its roof, wall pieces and furniture in the kit.
func test_every_building_finds_its_kit_pieces() -> void:
	var town := await _load_town()
	for building_name: String in BUILDINGS:
		var building := town.get_node(SOLID_PROPS + building_name) as WalkInBuilding
		var plan := building.plan()
		assert_object(building.get_node_or_null("Roof")).override_failure_message("%s roof" % building_name).is_not_null()
		var walls := building.get_node("Walls").get_children()
		assert_int(walls.size()).is_equal(plan.pieces.size())
		for sprite: Node in walls:
			assert_object((sprite as Sprite2D).texture).override_failure_message("%s %s" % [building_name, sprite.name]).is_not_null()
		assert_int(building.get_node("Furniture").get_child_count()).override_failure_message("%s furniture" % building_name) \
			.is_equal(plan.furniture.size())
		assert_int(building.get_node("Floor").get_child_count()).is_equal(plan.footprint_cells().size())
	await _unload(town)


func test_the_keeper_and_the_grain_factor_stand_on_the_wayhouse_floor() -> void:
	var runner := scene_runner(KESSELFORD)
	await runner.simulate_frames(5)
	var town: Node2D = runner.scene()
	var building := town.get_node(SOLID_PROPS + "Wayhouse") as WalkInBuilding
	var found: Array[String] = []
	for node: Node in town.get_tree().get_nodes_in_group(&"generated_townsfolk"):
		var npc := node as NPC
		if npc == null or not town.is_ancestor_of(npc):
			continue
		var npc_id := str(npc.get_meta(&"npc_id", ""))
		if not npc_id in WAYHOUSE_IDS:
			continue
		found.append(npc_id)
		var cell := building.layout_cell_at(npc.global_position)
		assert_str(building.plan().at(cell)).override_failure_message("%s stands on %s" % [npc_id, cell]).is_equal(BuildingPlan.FLOOR)
	assert_array(found).contains_exactly_in_any_order(WAYHOUSE_IDS)
	# The keeper stands behind the bar (row 7), in the common room.
	var keeper_cell := building.layout_cell_at((town.get_node("WayhouseKeeperSpot") as Node2D).global_position)
	assert_vector(Vector2(keeper_cell)).is_equal(Vector2(2, 6))
	assert_str(building.plan().at(keeper_cell + Vector2i(0, 1))).is_equal("B")


## The Ford Chandlery's vendor keeps shop on the map now: behind the counter, in reach of a customer
## on the other side of it.
func test_the_chandler_trades_across_the_counter() -> void:
	var runner := scene_runner(KESSELFORD)
	await runner.simulate_frames(5)
	var town: Node2D = runner.scene()
	var shop := town.get_node(SOLID_PROPS + "Chandlery") as WalkInBuilding
	var vendors: Array[NPC] = []
	for node: Node in town.find_children("*", "NPC", true, false):
		var npc := node as NPC
		if npc != null and not npc.vendor_id.is_empty():
			vendors.append(npc)
	assert_int(vendors.size()).is_equal(1)
	var chandler := vendors[0]
	assert_str(chandler.vendor_id).is_equal("ford-chandlery")
	assert_vector(Vector2(shop.layout_cell_at(chandler.global_position))).is_equal(Vector2(2, 2))
	assert_str(shop.plan().at(Vector2i(2, 3))).is_equal("B")
	var player := town.get_node("Player") as Node2D
	player.global_position = shop.to_global(shop.corner(2.5, 4.5))
	for _frame: int in 6:
		await get_tree().physics_frame
	assert_bool(bool(chandler.get("_player_in_range"))).override_failure_message("the counter is out of reach").is_true()


func test_the_roof_lifts_room_by_room_when_the_player_walks_in() -> void:
	var runner := scene_runner(KESSELFORD)
	await runner.simulate_frames(3)
	var town: Node2D = runner.scene()
	for pair: Array in [["Wayhouse", "SpawnInKesselfordWayhouse", "SpawnFromKesselfordWayhouse"],
			["Chandlery", "SpawnInKesselfordChandlery", "SpawnFromKesselfordChandlery"]]:
		var building := town.get_node(SOLID_PROPS + pair[0]) as WalkInBuilding
		assert_int(building.current_look()).is_equal(WalkInBuilding.Look.OUTSIDE)
		var inside := (town.get_node(pair[1]) as Node2D).global_position
		_move_party(town, inside)
		await runner.simulate_frames(3)
		assert_int(building.current_look()).override_failure_message(pair[0]).is_equal(WalkInBuilding.Look.INSIDE)
		assert_array(building.open_rooms()).is_equal(building.plan().rooms_of(building.layout_cell_at(inside)))
		_move_party(town, (town.get_node(pair[2]) as Node2D).global_position)
		await runner.simulate_frames(3)
		assert_int(building.current_look()).override_failure_message(pair[0]).is_equal(WalkInBuilding.Look.OUTSIDE)


func test_saves_made_in_the_retired_rooms_load_inside_the_buildings() -> void:
	var rooms := {
		"kesselford_wayhouse": [RETIRED_WAYHOUSE, "in_kesselford_wayhouse", "Wayhouse", "SpawnInKesselfordWayhouse"],
		"kesselford_chandlery": [RETIRED_CHANDLERY, "in_kesselford_chandlery", "Chandlery", "SpawnInKesselfordChandlery"],
	}
	var root: Node = auto_free((load(KESSELFORD) as PackedScene).instantiate())
	for location_id: String in rooms:
		var row: Array = rooms[location_id]
		assert_bool(ResourceLoader.exists(row[0])).is_false()
		var by_scene := SaveGame._destination_from_payload({
			"scene": row[0], "spawn_id": "entry", "player_position": Vector2(960, 800),
		})
		var by_id := SaveGame._destination_from_payload({
			"scene": row[0], "location_id": location_id, "spawn_id": "entry", "player_position": Vector2(960, 800),
		})
		for destination: LoadDestination in [by_scene, by_id]:
			assert_object(destination).is_not_null()
			if destination == null:
				continue
			assert_str(String(destination.location_id)).is_equal("kesselford")
			assert_str(String(destination.spawn_id)).is_equal(row[1])
			# The old room's coordinates mean nothing on the map: the load uses the spawn marker.
			assert_bool(destination.has_position).is_false()
		# The spawn marker stands on the building's floor.
		var building := _bound(root, row[2])
		var marker := root.get_node(String(row[3])) as Node2D
		var cell := building.layout_cell_at(SolidFootprints.transform_in(marker, root).origin)
		assert_str(building.plan().at(cell)).override_failure_message("%s spawn on %s" % [location_id, cell]).is_equal(BuildingPlan.FLOOR)
	# A save on the Kesselford street keeps its own place.
	var street := SaveGame._destination_from_payload({
		"scene": KESSELFORD, "location_id": "kesselford", "spawn_id": "from_dom", "player_position": Vector2(1500, 900),
	})
	assert_object(street).is_not_null()
	if street != null:
		assert_str(String(street.spawn_id)).is_equal("from_dom")
		assert_bool(street.has_position).is_true()


## A building of a scene that is not in the tree, bound to its ground as the paint tool binds it.
func _bound(root: Node, building_name: String) -> WalkInBuilding:
	var building := root.get_node(SOLID_PROPS + building_name) as WalkInBuilding
	var ground := SolidFootprints.find_ground(root)
	var to_building := SolidFootprints.transform_in(building, root).affine_inverse()
	building.bind(ground, to_building * SolidFootprints.transform_in(ground, root))
	return building


## A plain floor cell of `room` that nobody stands on, in map cells; (-1, -1) for none.
func _open_floor_cell(building: WalkInBuilding, grid: IsoGrid, ground: TileMapLayer, room: int) -> Vector2i:
	var plan := building.plan()
	for j in plan.size.y:
		for i in plan.size.x:
			var cell := Vector2i(i, j)
			if plan.at(cell) != BuildingPlan.FLOOR or plan.rooms_of(cell) != [room]:
				continue
			var map_cell := building.origin_cell + cell
			if not grid.is_blocked_for(grid.world_to_cell(ground.to_global(ground.map_to_local(map_cell)))):
				return map_cell
	return Vector2i(-1, -1)


func _move_party(town: Node, at: Vector2) -> void:
	for group: StringName in WalkInBuilding.PARTY_GROUPS:
		for node: Node in town.get_tree().get_nodes_in_group(group):
			if node is Node2D:
				(node as Node2D).global_position = at


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
