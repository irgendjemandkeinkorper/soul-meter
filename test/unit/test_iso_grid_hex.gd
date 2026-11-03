extends GdUnitTestSuite
## Covers IsoGrid's hex mode (owner item 34, slice H1 of
## docs/design/hex-grid-plan-2026-11-03.md): the same public calls over Fallout-scale hexes
## derived from the square layers, which stay the authoring source.

const TILE_SIZE := Vector2i(64, 32)


## A ground (and optional blocking) layer projected like the shipped maps: isometric, diamond down.
func _make_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = TILE_SIZE
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = ImageTexture.create_from_image(
		Image.create(TILE_SIZE.x, TILE_SIZE.y, false, Image.FORMAT_RGBA8)
	)
	atlas_source.texture_region_size = TILE_SIZE
	atlas_source.create_tile(Vector2i(0, 0))
	tile_set.add_source(atlas_source, 0)
	return tile_set


func _make_layer(cells: Array[Vector2i], tile_set: TileSet) -> TileMapLayer:
	var layer: TileMapLayer = auto_free(TileMapLayer.new())
	layer.tile_set = tile_set
	for cell: Vector2i in cells:
		layer.set_cell(cell, 0, Vector2i(0, 0))
	return layer


func _square(size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			cells.append(Vector2i(x, y))
	return cells


func _hex_grid(size: Vector2i, walls: Array[Vector2i] = []) -> IsoGrid:
	var tile_set := _make_tile_set()
	var ground := _make_layer(_square(size), tile_set)
	var blocking: TileMapLayer = null
	if not walls.is_empty():
		blocking = _make_layer(walls, tile_set)
	var grid := IsoGrid.new()
	grid.hex_mode = true
	grid.build(ground, blocking)
	return grid


func test_hex_mode_is_off_unless_the_project_turns_it_on() -> void:
	assert_bool(IsoGrid.hex_enabled()).is_false()
	assert_bool(IsoGrid.new().hex_mode).is_false()


func test_world_positions_round_trip_through_hexes_on_the_painted_ground() -> void:
	var grid := _hex_grid(Vector2i(8, 8))
	var rect := grid.get_used_rect()
	var on_grid := 0
	for r in range(rect.position.y, rect.end.y):
		for q in range(rect.position.x, rect.end.x):
			var hex := Vector2i(q, r)
			if not grid.is_in_bounds(hex):
				continue
			on_grid += 1
			assert_that(grid.world_to_cell(grid.cell_to_world(hex))).is_equal(hex)
	# About 4.6 hexes to a cell (ruling H-a, "Fallout scale").
	assert_int(on_grid).is_between(64 * 4, 64 * 5)
	# A hex whose centre is off the painted ground is off the grid.
	assert_bool(grid.is_in_bounds(grid.world_to_cell(grid.world_bounds().position - Vector2(80, 80)))).is_false()


func test_the_world_bounds_match_the_square_grid() -> void:
	var tile_set := _make_tile_set()
	var ground := _make_layer(_square(Vector2i(6, 9)), tile_set)
	var square := IsoGrid.new()
	square.build(ground)
	var hex := IsoGrid.new()
	hex.hex_mode = true
	hex.build(ground)
	assert_that(hex.world_bounds()).is_equal(square.world_bounds())


func test_a_painted_wall_makes_the_hexes_on_it_solid() -> void:
	var wall := Vector2i(4, 4)
	var grid := _hex_grid(Vector2i(9, 9), [wall])
	var tile_set := _make_tile_set()
	var probe := _make_layer([], tile_set)
	var on_wall := 0
	var rect := grid.get_used_rect()
	for r in range(rect.position.y, rect.end.y):
		for q in range(rect.position.x, rect.end.x):
			var hex := Vector2i(q, r)
			if not grid.is_in_bounds(hex):
				continue
			var cell := probe.local_to_map(probe.to_local(grid.cell_to_world(hex)))
			if cell == wall:
				on_wall += 1
				assert_bool(grid.is_point_solid(hex)).is_true()
				assert_bool(grid.is_blocked_for(hex)).is_true()
			elif maxi(absi(cell.x - wall.x), absi(cell.y - wall.y)) >= 2:
				assert_bool(grid.is_point_solid(hex)).override_failure_message("%s far from the wall" % hex).is_false()
	assert_int(on_wall).is_greater_equal(3)


func test_no_path_leaks_through_a_wall_one_cell_thick() -> void:
	# Walls across a 12x12 map, at several positions so the hex rows cross them at different
	# phases: along a cell axis (a screen diagonal), and of cells that touch only at their
	# corners (a vertical line on screen). The square grid seals every one of them.
	var size := Vector2i(12, 12)
	var walls_to_try: Array = []
	for shift in range(-2, 3):
		walls_to_try.append(_diagonal(size, shift))
		walls_to_try.append(_line(size, 6 + shift))
	var tile_set := _make_tile_set()
	var probe := _make_layer([], tile_set)
	for walls: Array[Vector2i] in walls_to_try:
		var grid := _hex_grid(size, walls)
		var start := grid.world_to_cell(probe.map_to_local(Vector2i(10, 1)))
		var goal := grid.world_to_cell(probe.map_to_local(Vector2i(1, 10)))
		assert_bool(grid.is_blocked_for(start)).is_false()
		assert_bool(grid.is_blocked_for(goal)).is_false()
		assert_int(grid.path_cells(start, goal).size()).override_failure_message(
			"a path leaked through %s" % [walls.slice(0, 3)]
		).is_equal(0)
	# Without a wall the same two points connect.
	var open := _hex_grid(size)
	var a := open.world_to_cell(probe.map_to_local(Vector2i(10, 1)))
	var b := open.world_to_cell(probe.map_to_local(Vector2i(1, 10)))
	assert_int(open.path_cells(a, b).size()).is_greater(0)


func test_a_keyboard_step_never_crosses_a_corner_touching_wall() -> void:
	var size := Vector2i(12, 12)
	var tile_set := _make_tile_set()
	var probe := _make_layer([], tile_set)
	for shift in range(-2, 3):
		var walls := _diagonal(size, shift)
		var grid := _hex_grid(size, walls)
		var crossings := 0
		var rect := grid.get_used_rect()
		for r in range(rect.position.y, rect.end.y):
			for q in range(rect.position.x, rect.end.x):
				var hex := Vector2i(q, r)
				if not grid.is_in_bounds(hex) or grid.is_blocked_for(hex):
					continue
				for direction in HexMath.DIRECTION_COUNT:
					var screen := grid.cell_to_world(HexMath.neighbor(hex, direction)) - grid.cell_to_world(hex)
					var step: Variant = grid.resolve_step_cell(hex, screen)
					# Off the painted ground the lattice is open (Wave Q), in square mode too: a
					# step there can go round the wall's end. Count steps inside the map only.
					if step == null or _near_edge(probe, grid, hex, size) or _near_edge(probe, grid, step as Vector2i, size):
						continue
					if _side(probe, grid, hex, shift) != _side(probe, grid, step as Vector2i, shift):
						crossings += 1
		assert_int(crossings).override_failure_message("steps crossed the wall at shift %d" % shift).is_equal(0)


func _near_edge(probe: TileMapLayer, grid: IsoGrid, hex: Vector2i, size: Vector2i) -> bool:
	var cell := probe.local_to_map(probe.to_local(grid.cell_to_world(hex)))
	return cell.x <= 0 or cell.y <= 0 or cell.x >= size.x - 1 or cell.y >= size.y - 1


## Which side of the diagonal wall x - y = shift a hex's centre cell lies on.
func _side(probe: TileMapLayer, grid: IsoGrid, hex: Vector2i, shift: int) -> int:
	var cell := probe.local_to_map(probe.to_local(grid.cell_to_world(hex)))
	return signi(cell.x - cell.y - shift)


func _line(size: Vector2i, row: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in size.x:
		cells.append(Vector2i(i, row))
	return cells


func _diagonal(size: Vector2i, shift: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in size.x:
		if i + shift >= 0 and i + shift < size.y:
			cells.append(Vector2i(i + shift, i))
	return cells


func test_paths_step_hex_to_hex_and_take_the_short_way_on_open_ground() -> void:
	var grid := _hex_grid(Vector2i(10, 10))
	var tile_set := _make_tile_set()
	var probe := _make_layer([], tile_set)
	var from := grid.world_to_cell(probe.map_to_local(Vector2i(2, 2)))
	var to := grid.world_to_cell(probe.map_to_local(Vector2i(7, 6)))
	var path := grid.path_cells(from, to)
	assert_that(Vector2i(path[0])).is_equal(from)
	assert_that(Vector2i(path[path.size() - 1])).is_equal(to)
	assert_int(path.size()).is_equal(HexMath.distance(from, to) + 1)
	for i in range(1, path.size()):
		assert_int(HexMath.distance(Vector2i(path[i - 1]), Vector2i(path[i]))).is_equal(1)
	# path_world lands on hex centres.
	var world := grid.path_world(grid.cell_to_world(from), grid.cell_to_world(to))
	assert_that(world[world.size() - 1]).is_equal(grid.cell_to_world(to))


func test_a_standing_actor_blocks_others_but_never_its_own_path() -> void:
	var grid := _hex_grid(Vector2i(8, 8))
	var tile_set := _make_tile_set()
	var probe := _make_layer([], tile_set)
	var here := grid.world_to_cell(probe.map_to_local(Vector2i(3, 3)))
	var there := grid.world_to_cell(probe.map_to_local(Vector2i(5, 5)))
	var keeper: RefCounted = RefCounted.new()
	var walker: RefCounted = RefCounted.new()
	grid.set_occupant(keeper, here)
	assert_bool(grid.is_blocked_for(here, walker)).is_true()
	assert_bool(grid.is_blocked_for(here, keeper)).is_false()
	assert_int(grid.path_cells(here, there, keeper).size()).is_greater(0)
	assert_int(grid.path_cells(there, here, walker).size()).is_equal(0)
	# Paths route around the standing actor.
	var west := HexMath.neighbor(here, 3)
	var east := HexMath.neighbor(here, 0)
	var around := grid.path_cells(west, east, walker)
	assert_bool(Array(around).has(Vector2(here))).is_false()
	assert_int(around.size()).is_equal(4)
	grid.clear_occupant(keeper)
	assert_bool(grid.is_blocked_for(here, walker)).is_false()
	assert_int(grid.path_cells(west, east, walker).size()).is_equal(3)
	assert_that(grid.cell_of_occupant(keeper)).is_null()


func test_keyboard_steps_pick_among_six_hex_neighbours() -> void:
	var grid := _hex_grid(Vector2i(8, 8))
	var tile_set := _make_tile_set()
	var probe := _make_layer([], tile_set)
	var here := grid.world_to_cell(probe.map_to_local(Vector2i(4, 4)))
	var ranked := grid.neighbors_by_screen_direction(here, Vector2.RIGHT)
	assert_int(ranked.size()).is_equal(6)
	assert_that(ranked[0]).is_equal(HexMath.neighbor(here, 0))
	assert_that(grid.screen_direction_to_neighbor(here, Vector2.LEFT)).is_equal(HexMath.neighbor(here, 3))
	var up: Vector2i = grid.screen_direction_to_neighbor(here, Vector2.UP)
	assert_bool(up == HexMath.neighbor(here, 1) or up == HexMath.neighbor(here, 2)).is_true()
	# A blocked step glides to the next-best open neighbour.
	grid.set_point_solid(HexMath.neighbor(here, 0))
	var glide: Variant = grid.resolve_step_cell(here, Vector2.RIGHT)
	assert_that(glide).is_not_null()
	assert_int(HexMath.distance(here, glide as Vector2i)).is_equal(1)
	assert_that(glide).is_not_equal(HexMath.neighbor(here, 0))


func test_weights_and_caller_solids_reach_the_hex_paths() -> void:
	var grid := _hex_grid(Vector2i(8, 8))
	var tile_set := _make_tile_set()
	var probe := _make_layer([], tile_set)
	var here := grid.world_to_cell(probe.map_to_local(Vector2i(4, 4)))
	grid.set_point_weight_scale(here, 3.0)
	assert_float(grid.get_point_weight_scale(here)).is_equal(3.0)
	assert_float(grid.get_point_weight_scale(Vector2i(9999, 9999))).is_equal(1.0)
	var west := HexMath.neighbor(here, 3)
	var east := HexMath.neighbor(here, 0)
	# Crossing the heavy hex costs more than going round it, so the path goes round.
	assert_bool(Array(grid.path_cells(west, east)).has(Vector2(here))).is_false()
	grid.set_point_weight_scale(here, 1.0)
	assert_bool(Array(grid.path_cells(west, east)).has(Vector2(here))).is_true()
	grid.set_point_solid(here, true)
	assert_bool(grid.is_point_solid(here)).is_true()
	assert_bool(Array(grid.path_cells(west, east)).has(Vector2(here))).is_false()
	grid.set_point_solid(here, false)
	assert_bool(grid.is_point_solid(here)).is_false()


func test_placement_snaps_onto_a_hex_centre_near_the_authored_spot() -> void:
	var tile_set := _make_tile_set()
	var root: Node2D = auto_free(Node2D.new())
	add_child(root)
	var ground := _make_layer(_square(Vector2i(8, 8)), tile_set)
	root.add_child(ground)
	var actor: Node2D = auto_free(Node2D.new())
	root.add_child(actor)
	var grid := IsoGrid.new()
	grid.hex_mode = true
	grid.build(ground)
	var authored := ground.map_to_local(Vector2i(3, 4)) + Vector2(5.0, 3.0)
	var snapped: Variant = GridPlacement._nearby_open_cell_center(grid, root, actor, authored)
	assert_that(snapped).is_not_null()
	var spot := snapped as Vector2
	assert_that(grid.cell_to_world(grid.world_to_cell(spot))).is_equal(spot)
	assert_float(spot.distance_to(authored)).is_less(HexLayout.DEFAULT_STEP)


func test_a_live_wall_edit_patches_the_built_hex_graph() -> void:
	var tile_set := _make_tile_set()
	var ground := _make_layer(_square(Vector2i(10, 10)), tile_set)
	var blocking: BlockingLayer = auto_free(BlockingLayer.new())
	blocking.tile_set = tile_set
	var grid := IsoGrid.new()
	grid.hex_mode = true
	grid.build(ground, blocking)
	grid.prepare_paths()
	var graph: AStar2D = grid._hex_astar
	assert_object(graph).is_not_null()
	var probe := _make_layer([], tile_set)
	var start := grid.world_to_cell(probe.map_to_local(Vector2i(8, 1)))
	var goal := grid.world_to_cell(probe.map_to_local(Vector2i(1, 8)))
	assert_int(grid.path_cells(start, goal).size()).is_greater(0)
	# Wall off the map along the cells x - y = 0, which touch only at their corners.
	var tiles := {}
	for i in 10:
		tiles[Vector2i(i, i)] = [0, Vector2i.ZERO, 0]
	blocking.set_structure_footprint(tiles, true)
	assert_object(grid._hex_astar).is_same(graph)
	assert_int(grid.path_cells(start, goal).size()).override_failure_message("a path leaked after the edit").is_equal(0)
	blocking.set_structure_footprint(tiles, false)
	assert_int(grid.path_cells(start, goal).size()).is_greater(0)


func test_a_rebuild_over_the_same_ground_keeps_the_hex_graph_and_forgets_marks() -> void:
	var tile_set := _make_tile_set()
	var ground := _make_layer(_square(Vector2i(8, 8)), tile_set)
	var grid := IsoGrid.new()
	grid.hex_mode = true
	grid.build(ground)
	grid.prepare_paths()
	var graph: AStar2D = grid._hex_astar
	var probe := _make_layer([], tile_set)
	var here := grid.world_to_cell(probe.map_to_local(Vector2i(4, 4)))
	var west := HexMath.neighbor(here, 3)
	var east := HexMath.neighbor(here, 0)
	var keeper: RefCounted = RefCounted.new()
	grid.set_occupant(keeper, here)
	grid.set_point_weight_scale(west, 4.0)
	grid.set_point_solid(east, true)
	grid.build(ground)
	assert_object(grid._hex_astar).is_same(graph)
	# The standing actor is still there; the weight and the caller's solid are forgotten.
	assert_bool(grid.is_blocked_for(here, RefCounted.new())).is_true()
	assert_float(grid.get_point_weight_scale(west)).is_equal(1.0)
	assert_bool(grid.is_point_solid(east)).is_false()
	assert_int(grid.path_cells(west, east).size()).is_equal(4)
	grid.clear_occupant(keeper)
	assert_int(grid.path_cells(west, east).size()).is_equal(3)
	# Different ground: a fresh graph.
	var other := _make_layer(_square(Vector2i(6, 6)), tile_set)
	grid.build(other)
	assert_object(grid._hex_astar).is_null()


## Harness boards (Gate T-1, Gate T-2) use plain 64x32 rectangles. Hexes are sized from the
## tile's real shape, so they hold about 4.6 hexes to a cell there too (H2, item 34).
func test_a_rectangular_board_keeps_about_four_hexes_to_a_cell() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = ImageTexture.create_from_image(
		Image.create(TILE_SIZE.x, TILE_SIZE.y, false, Image.FORMAT_RGBA8)
	)
	atlas_source.texture_region_size = TILE_SIZE
	atlas_source.create_tile(Vector2i(0, 0))
	tile_set.add_source(atlas_source, 0)
	var grid := IsoGrid.new()
	grid.hex_mode = true
	grid.build(_make_layer(_square(Vector2i(8, 8)), tile_set))
	assert_int(grid.region_cells().size()).is_between(64 * 4, 64 * 5)
	# Two hex steps still cover one cell step (64 px across on this board).
	var a := grid.cell_at_square(Vector2i(3, 3))
	var hex_step := grid.cell_to_world(a + HexMath.DIRECTIONS[0]) - grid.cell_to_world(a)
	assert_float(hex_step.x * 2.0).is_equal_approx(float(TILE_SIZE.x), 0.01)
