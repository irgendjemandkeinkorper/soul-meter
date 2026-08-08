extends GdUnitTestSuite
## Integration tests for the `Blocking` TileMapLayer in world/starting_town.tscn
## (GH #161). docs/architecture-tactical-and-navigation.md §2.3 requires ONE
## source of truth for passability: the same set of painted cells must drive
## both the AStarGrid2D bake (world/nav/iso_grid.gd) and the physics collision
## a CharacterBody2D actually runs into. These two tests prove each half of
## that contract against the real scene, not a stand-in.

const TOWN_SCENE_PATH := "res://world/starting_town.tscn"


func test_pathfinding_cannot_cross_a_blocking_cell() -> void:
	var runner := scene_runner(TOWN_SCENE_PATH)
	await runner.simulate_frames(3)

	var ground := runner.find_child("IsometricGround", true, false) as TileMapLayer
	var blocking := runner.find_child("Blocking", true, false) as TileMapLayer
	assert_object(ground).is_not_null()
	assert_object(blocking).is_not_null()
	# Sanity check: the layer actually painted something before we trust it
	# as the source of truth for the bake below.
	assert_int(blocking.get_used_cells().size()).is_greater(0)

	var grid := IsoGrid.new()
	grid.build(ground, blocking)

	# TrialHall's footprint sits between these two cells (see the cells painted
	# into the Blocking layer's tile_map_data in starting_town.tscn) — a straight
	# line between them cuts straight through the building.
	var from_cell := Vector2i(18, 7)
	var to_cell := Vector2i(27, 7)
	assert_int(blocking.get_cell_source_id(from_cell)).is_equal(-1)
	assert_int(blocking.get_cell_source_id(to_cell)).is_equal(-1)
	assert_bool(grid.is_point_solid(from_cell)).is_false()
	assert_bool(grid.is_point_solid(to_cell)).is_false()

	var path: PackedVector2Array = grid.path_cells(from_cell, to_cell)
	# A route exists (it must detour around TrialHall, not fail outright).
	assert_int(path.size()).is_greater(0)

	# The load-bearing assertion: not one step of the returned path may land
	# on a cell the Blocking layer marked solid.
	for point in path:
		var cell := Vector2i(point)
		assert_int(blocking.get_cell_source_id(cell)).is_equal(-1)
		assert_bool(grid.is_point_solid(cell)).is_false()

	# A request straight INTO a blocking cell must refuse outright.
	var inside_trial_hall := Vector2i(21, 6)
	assert_int(blocking.get_cell_source_id(inside_trial_hall)).is_not_equal(-1)
	assert_bool(grid.is_point_solid(inside_trial_hall)).is_true()
	var refused: PackedVector2Array = grid.path_cells(from_cell, inside_trial_hall)
	assert_int(refused.size()).is_equal(0)


func test_physics_body_cannot_enter_a_blocking_cell() -> void:
	var runner := scene_runner(TOWN_SCENE_PATH)
	await runner.simulate_frames(3)

	var blocking := runner.find_child("Blocking", true, false) as TileMapLayer
	assert_object(blocking).is_not_null()

	# A cell inside PlayersHouse's footprint, close to the default player spawn.
	var blocked_cell := Vector2i(29, 33)
	assert_int(blocking.get_cell_source_id(blocked_cell)).is_not_equal(-1)
	var target: Vector2 = blocking.to_global(blocking.map_to_local(blocked_cell))

	var body := CharacterBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	collision.shape = shape
	body.add_child(collision)
	body.global_position = target + Vector2(0, -80)
	runner.scene().add_child(body)
	auto_free(body)
	await runner.simulate_frames(3)

	# Drive the body straight at the blocked cell's center for long enough
	# that, if nothing stopped it, it would arrive.
	for i in 90:
		body.velocity = body.global_position.direction_to(target) * 200.0
		body.move_and_slide()
		await runner.simulate_frames(1)

	# The load-bearing assertions: the Blocking layer's own physics stopped
	# it (a real collision was recorded) and it never reached the cell.
	assert_int(body.get_slide_collision_count()).is_greater(0)
	assert_float(body.global_position.distance_to(target)).is_greater(16.0)
