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


# --- dynamic occupancy (GH #190) ---


func test_an_occupied_cell_blocks_another_actor_but_not_its_own_occupant() -> void:
	var ground := _make_ground(Vector2i(5, 5))
	var grid := IsoGridScript.new()
	grid.build(ground)

	var npc: Node = auto_free(Node.new())
	var player: Node = auto_free(Node.new())
	grid.set_occupant(npc, Vector2i(2, 2))

	assert_bool(grid.is_blocked_for(Vector2i(2, 2), player)).is_true()
	# The obvious-but-easy-to-break half: an actor's own cell never blocks itself.
	assert_bool(grid.is_blocked_for(Vector2i(2, 2), npc)).is_false()
	assert_object(grid.occupant_of(Vector2i(2, 2))).is_same(npc)


func test_a_path_routes_around_an_occupied_cell() -> void:
	# A 3-wide corridor with (1, 0) and (1, 2) painted solid: the ONLY way through column 1
	# is (1, 1). Put an actor there and the straight route must become impossible.
	var ground := _make_ground(Vector2i(3, 3))
	var blocking := _make_blocking(
		[Vector2i(1, 0), Vector2i(1, 2)] as Array[Vector2i], ground.tile_set
	)
	var grid := IsoGridScript.new()
	grid.build(ground, blocking)

	var player: Node = auto_free(Node.new())
	var npc: Node = auto_free(Node.new())

	var open_path := grid.path_cells(Vector2i(0, 1), Vector2i(2, 1), player)
	assert_int(open_path.size()).is_greater(0)
	assert_array(Array(open_path)).contains([Vector2(1, 1)])

	grid.set_occupant(npc, Vector2i(1, 1))
	var blocked_path := grid.path_cells(Vector2i(0, 1), Vector2i(2, 1), player)
	# The only gap is occupied, so there is no route at all — the path certainly does not
	# walk through the NPC.
	assert_int(blocked_path.size()).is_equal(0)

	# ...and the moment the NPC steps aside, the route is back.
	grid.set_occupant(npc, Vector2i(0, 0))
	var reopened := grid.path_cells(Vector2i(0, 1), Vector2i(2, 1), player)
	assert_array(Array(reopened)).contains([Vector2(1, 1)])


func test_a_path_detours_around_an_occupant_when_a_detour_exists() -> void:
	var ground := _make_ground(Vector2i(5, 5))
	var grid := IsoGridScript.new()
	grid.build(ground)

	var player: Node = auto_free(Node.new())
	var npc: Node = auto_free(Node.new())
	grid.set_occupant(npc, Vector2i(2, 2))

	var path := grid.path_cells(Vector2i(0, 2), Vector2i(4, 2), player)
	assert_int(path.size()).is_greater(0)
	assert_array(Array(path)).not_contains([Vector2(2, 2)])


func test_a_mover_standing_on_an_occupied_cell_can_still_leave_it() -> void:
	var ground := _make_ground(Vector2i(5, 5))
	var grid := IsoGridScript.new()
	grid.build(ground)

	var walker: Node = auto_free(Node.new())
	grid.set_occupant(walker, Vector2i(0, 0))

	var path := grid.path_cells(Vector2i(0, 0), Vector2i(4, 4), walker)
	assert_int(path.size()).is_greater(0)


func test_a_start_cell_occupied_by_someone_else_does_not_trap_the_mover() -> void:
	# Bodies overlap. If another actor's cell is where we are standing, we must still be able
	# to walk away — occupancy is lifted for the start cell, but a painted wall never is.
	var ground := _make_ground(Vector2i(5, 5))
	var grid := IsoGridScript.new()
	grid.build(ground)

	var player: Node = auto_free(Node.new())
	var npc: Node = auto_free(Node.new())
	grid.set_occupant(npc, Vector2i(0, 0))

	var path := grid.path_cells(Vector2i(0, 0), Vector2i(4, 4), player)
	assert_int(path.size()).is_greater(0)


func test_vacating_a_cell_restores_the_painted_map_rather_than_punching_a_hole() -> void:
	var ground := _make_ground(Vector2i(3, 3))
	var blocking := _make_blocking([Vector2i(1, 1)] as Array[Vector2i], ground.tile_set)
	var grid := IsoGridScript.new()
	grid.build(ground, blocking)

	var npc: Node = auto_free(Node.new())
	# An actor registered onto a painted wall cell (shouldn't happen, but must not corrupt
	# the map when it clears).
	grid.set_occupant(npc, Vector2i(1, 1))
	grid.clear_occupant(npc)
	assert_bool(grid.is_point_solid(Vector2i(1, 1))).is_true()
	assert_bool(grid.is_blocked_for(Vector2i(1, 1), npc)).is_true()

	# And a plain occupied cell clears back to walkable.
	grid.set_occupant(npc, Vector2i(0, 2))
	assert_bool(grid.is_blocked_for(Vector2i(0, 2), null)).is_true()
	grid.clear_occupant(npc)
	assert_bool(grid.is_blocked_for(Vector2i(0, 2), null)).is_false()


func test_occupancy_survives_a_rebuild_of_the_static_layer() -> void:
	# ClickMoveController re-bakes the grid every 0.35s. If build() silently dropped occupancy,
	# NPCs would blink out of the pathfinder's view between rebakes.
	var ground := _make_ground(Vector2i(5, 5))
	var grid := IsoGridScript.new()
	grid.build(ground)

	var npc: Node = auto_free(Node.new())
	grid.set_occupant(npc, Vector2i(2, 2))
	grid.build(ground)

	assert_bool(grid.is_blocked_for(Vector2i(2, 2), null)).is_true()
	assert_object(grid.occupant_of(Vector2i(2, 2))).is_same(npc)


func test_moving_an_occupant_vacates_the_cell_it_left() -> void:
	var ground := _make_ground(Vector2i(5, 5))
	var grid := IsoGridScript.new()
	grid.build(ground)

	var npc: Node = auto_free(Node.new())
	grid.set_occupant(npc, Vector2i(1, 1))
	grid.set_occupant(npc, Vector2i(3, 3))

	assert_bool(grid.is_blocked_for(Vector2i(1, 1), null)).is_false()
	assert_bool(grid.is_blocked_for(Vector2i(3, 3), null)).is_true()
	assert_object(grid.occupant_of(Vector2i(1, 1))).is_null()


func test_nav_occupancy_sync_reads_live_actor_positions_and_is_scoped_to_its_root() -> void:
	var ground := _make_ground(Vector2i(6, 6))
	var root: Node2D = auto_free(Node2D.new())
	add_child(root)

	var grid := IsoGridScript.new()
	grid.build(ground)

	var inside: Node2D = auto_free(Node2D.new())
	inside.global_position = grid.cell_to_world(Vector2i(2, 2))
	root.add_child(inside)
	NavOccupancy.register(inside)

	# A node in the group but OUTSIDE `root` — a leaked fixture from another suite. It must
	# not leak into this scene's passability.
	var outside: Node2D = auto_free(Node2D.new())
	add_child(outside)
	outside.global_position = grid.cell_to_world(Vector2i(4, 4))
	NavOccupancy.register(outside)

	NavOccupancy.sync(grid, root)
	assert_bool(grid.is_blocked_for(Vector2i(2, 2), null)).is_true()
	assert_bool(grid.is_blocked_for(Vector2i(4, 4), null)).is_false()

	# The actor walks. A resync must follow it, not remember where it was.
	inside.global_position = grid.cell_to_world(Vector2i(5, 1))
	NavOccupancy.sync(grid, root)
	assert_bool(grid.is_blocked_for(Vector2i(2, 2), null)).is_false()
	assert_bool(grid.is_blocked_for(Vector2i(5, 1), null)).is_true()

	# `exclude` keeps the asking actor out of the map entirely.
	NavOccupancy.sync(grid, root, inside)
	assert_bool(grid.is_blocked_for(Vector2i(5, 1), null)).is_false()
