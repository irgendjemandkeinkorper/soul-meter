extends GdUnitTestSuite
## Covers world/nav/iso_grid.gd — the shared AStarGrid2D substrate described in
## docs/architecture-tactical-and-navigation.md §2.2.

const IsoGridScript := preload("res://world/nav/iso_grid.gd")
const TILE_SIZE := Vector2i(64, 32)


func _make_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	var image := Image.create(TILE_SIZE.x, TILE_SIZE.y, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = TILE_SIZE
	atlas_source.create_tile(Vector2i(0, 0))
	tile_set.add_source(atlas_source, 0)
	return tile_set


## `size` cells filled square, starting at (0, 0).
func _make_ground(size: Vector2i) -> TileMapLayer:
	var ground: TileMapLayer = auto_free(TileMapLayer.new())
	ground.tile_set = _make_tile_set()
	for y in size.y:
		for x in size.x:
			ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	return ground


func _make_blocking(cells: Array[Vector2i], tile_set: TileSet) -> TileMapLayer:
	var blocking: TileMapLayer = auto_free(TileMapLayer.new())
	blocking.tile_set = tile_set
	for cell in cells:
		blocking.set_cell(cell, 0, Vector2i(0, 0))
	return blocking


func test_build_uses_octile_heuristic_and_no_corner_cutting_diagonal_mode() -> void:
	var ground := _make_ground(Vector2i(5, 5))
	var grid := IsoGridScript.new()
	grid.build(ground)

	assert_int(grid._astar.default_compute_heuristic).is_equal(AStarGrid2D.HEURISTIC_OCTILE)
	assert_int(grid._astar.default_estimate_heuristic).is_equal(AStarGrid2D.HEURISTIC_OCTILE)
	assert_int(grid._astar.diagonal_mode).is_equal(
		AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	)


func test_diagonal_move_refused_when_both_orthogonal_neighbors_are_solid() -> void:
	# (1, 0) and (0, 1) are both solid, so the corner between (0, 0) and (1, 1) is closed.
	# DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES must refuse to cut it.
	var ground := _make_ground(Vector2i(3, 3))
	var blocking := _make_blocking(
		[Vector2i(1, 0), Vector2i(0, 1)] as Array[Vector2i], ground.tile_set
	)
	var grid := IsoGridScript.new()
	grid.build(ground, blocking)

	var path := grid.path_cells(Vector2i(0, 0), Vector2i(1, 1))

	# No legal path exists once both orthogonal neighbors are solid: a straight diagonal step
	# would cut the corner, and every other route is blocked by the same two solid cells.
	assert_int(path.size()).is_equal(0)


func test_world_to_cell_and_cell_to_world_round_trip_across_the_map_rect() -> void:
	var size := Vector2i(9, 7)
	var ground := _make_ground(size)
	var grid := IsoGridScript.new()
	grid.build(ground)

	var checked := 0
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var world := grid.cell_to_world(cell)
			var round_tripped := grid.world_to_cell(world)
			assert_vector(round_tripped).is_equal(cell)
			checked += 1

	# Guard against a vacuous pass — the loop above must have actually run for every cell.
	assert_int(checked).is_equal(size.x * size.y)


func test_set_point_solid_is_reachable_through_the_public_api() -> void:
	var ground := _make_ground(Vector2i(4, 4))
	var grid := IsoGridScript.new()
	grid.build(ground)

	assert_bool(grid.is_point_solid(Vector2i(2, 2))).is_false()

	grid.set_point_solid(Vector2i(2, 2), true)
	assert_bool(grid.is_point_solid(Vector2i(2, 2))).is_true()

	grid.set_point_solid(Vector2i(2, 2), false)
	assert_bool(grid.is_point_solid(Vector2i(2, 2))).is_false()

	var path := grid.path_cells(Vector2i(0, 0), Vector2i(3, 3))
	assert_int(path.size()).is_greater(0)


func test_set_point_weight_scale_is_reachable_through_the_public_api() -> void:
	var ground := _make_ground(Vector2i(4, 4))
	var grid := IsoGridScript.new()
	grid.build(ground)

	assert_float(grid.get_point_weight_scale(Vector2i(2, 2))).is_equal_approx(1.0, 0.0001)

	grid.set_point_weight_scale(Vector2i(2, 2), 5.0)

	assert_float(grid.get_point_weight_scale(Vector2i(2, 2))).is_equal_approx(5.0, 0.0001)


func test_equal_cost_path_query_is_deterministic_across_repeated_calls() -> void:
	# An open field has many equal-cost routes between opposite corners. No RNG may enter path
	# selection: the same query must return the identical path every time (§1.8).
	var ground := _make_ground(Vector2i(8, 8))
	var grid := IsoGridScript.new()
	grid.build(ground)

	var from := Vector2i(0, 0)
	var to := Vector2i(7, 7)
	var first := grid.path_cells(from, to)
	assert_int(first.size()).is_greater(0)

	for i in 5:
		var again := grid.path_cells(from, to)
		assert_array(Array(again)).is_equal(Array(first))
