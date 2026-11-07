extends GdUnitTestSuite
## Covers world/nav/hex_math.gd: the hex grid wave's pure maths (owner item 34, slice H0;
## docs/design/hex-grid-plan-2026-11-03.md).

const SAMPLES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(3, -1), Vector2i(-4, 2), Vector2i(7, 5), Vector2i(-6, -3),
	Vector2i(250, 180), Vector2i(-301, 222), Vector2i(1, -8),
]


func test_distance_counts_steps_and_is_a_metric() -> void:
	assert_int(HexMath.distance(Vector2i(0, 0), Vector2i(0, 0))).is_equal(0)
	assert_int(HexMath.distance(Vector2i(0, 0), Vector2i(3, -1))).is_equal(3)
	assert_int(HexMath.distance(Vector2i(0, 0), Vector2i(-2, -2))).is_equal(4)
	assert_int(HexMath.distance(Vector2i(2, -5), Vector2i(-1, 1))).is_equal(6)
	for a: Vector2i in SAMPLES:
		for direction in HexMath.DIRECTION_COUNT:
			assert_int(HexMath.distance(a, HexMath.neighbor(a, direction))).is_equal(1)
		for b: Vector2i in SAMPLES:
			assert_int(HexMath.distance(a, b)).is_equal(HexMath.distance(b, a))
			for c: Vector2i in SAMPLES:
				assert_bool(HexMath.distance(a, c) <= HexMath.distance(a, b) + HexMath.distance(b, c)).is_true()


func test_six_neighbours_in_screen_order_with_opposites() -> void:
	var around := HexMath.neighbors(Vector2i(2, 3))
	assert_int(around.size()).is_equal(6)
	assert_that(around[0]).is_equal(Vector2i(3, 3))  # east, same row
	assert_that(around[3]).is_equal(Vector2i(1, 3))  # west, same row
	for direction in HexMath.DIRECTION_COUNT:
		var there := HexMath.neighbor(Vector2i(2, 3), direction)
		assert_int(HexMath.direction_to_neighbor(Vector2i(2, 3), there)).is_equal(direction)
		var back := HexMath.neighbor(there, HexMath.opposite(direction))
		assert_that(back).is_equal(Vector2i(2, 3))
	assert_int(HexMath.direction_to_neighbor(Vector2i(0, 0), Vector2i(2, 0))).is_equal(-1)
	assert_that(HexMath.neighbor(Vector2i.ZERO, 7)).is_equal(HexMath.neighbor(Vector2i.ZERO, 1))


func test_rings_hold_six_n_hexes_all_at_distance_n() -> void:
	var center := Vector2i(-3, 4)
	assert_array(HexMath.ring(center, 0)).contains_exactly([center])
	assert_bool(HexMath.ring(center, -1).is_empty()).is_true()
	for radius in range(1, 7):
		var hexes := HexMath.ring(center, radius)
		assert_int(hexes.size()).is_equal(6 * radius)
		var seen := {}
		for i in hexes.size():
			assert_int(HexMath.distance(center, hexes[i])).is_equal(radius)
			seen[hexes[i]] = true
			# A ring is a closed walk: each hex touches the next.
			assert_int(HexMath.distance(hexes[i], hexes[(i + 1) % hexes.size()])).is_equal(1)
		assert_int(seen.size()).is_equal(6 * radius)


func test_within_holds_every_hex_up_to_the_radius_once() -> void:
	var center := Vector2i(5, -2)
	for radius in range(0, 6):
		var hexes := HexMath.within(center, radius)
		assert_int(hexes.size()).is_equal(3 * radius * (radius + 1) + 1)
		assert_that(hexes[0]).is_equal(center)
		var seen := {}
		for hex: Vector2i in hexes:
			assert_bool(HexMath.distance(center, hex) <= radius).is_true()
			seen[hex] = true
		assert_int(seen.size()).is_equal(hexes.size())


func test_lines_step_neighbour_to_neighbour_between_their_ends() -> void:
	assert_array(HexMath.line(Vector2i(0, 0), Vector2i(3, 0))).contains_exactly(
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	)
	assert_array(HexMath.line(Vector2i(0, 0), Vector2i(0, 3))).contains_exactly(
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]
	)
	assert_array(HexMath.line(Vector2i(4, 4), Vector2i(4, 4))).contains_exactly([Vector2i(4, 4)])
	for a: Vector2i in SAMPLES:
		for b: Vector2i in SAMPLES:
			var path := HexMath.line(a, b)
			assert_int(path.size()).is_equal(HexMath.distance(a, b) + 1)
			assert_that(path[0]).is_equal(a)
			assert_that(path[path.size() - 1]).is_equal(b)
			for i in range(1, path.size()):
				assert_int(HexMath.distance(path[i - 1], path[i])).is_equal(1)


func test_lines_break_edge_ties_the_same_way_every_time() -> void:
	# (0,0) to (2,-1) runs exactly along a hex edge at its midpoint; the fixed nudge decides.
	var first := HexMath.line(Vector2i(0, 0), Vector2i(2, -1))
	for _i in 5:
		assert_array(HexMath.line(Vector2i(0, 0), Vector2i(2, -1))).contains_exactly(first)
	# Far from the origin the nudge must survive: the same shape, shifted.
	var far := Vector2i(400, -350)
	var shifted: Array[Vector2i] = []
	for hex: Vector2i in first:
		shifted.append(hex + far)
	assert_array(HexMath.line(far, far + Vector2i(2, -1))).contains_exactly(shifted)


func test_direction_toward_points_along_the_first_step() -> void:
	assert_int(HexMath.direction_toward(Vector2i(0, 0), Vector2i(0, 0))).is_equal(-1)
	assert_int(HexMath.direction_toward(Vector2i(0, 0), Vector2i(5, 0))).is_equal(0)
	assert_int(HexMath.direction_toward(Vector2i(0, 0), Vector2i(-5, 0))).is_equal(3)
	assert_int(HexMath.direction_toward(Vector2i(0, 0), Vector2i(0, 4))).is_equal(5)
	for direction in HexMath.DIRECTION_COUNT:
		var far := Vector2i(3, 3) + HexMath.DIRECTIONS[direction] * 6
		assert_int(HexMath.direction_toward(Vector2i(3, 3), far)).is_equal(direction)


func test_rounding_picks_the_containing_hex() -> void:
	assert_that(HexMath.round_axial(Vector2(0.1, 0.1))).is_equal(Vector2i(0, 0))
	assert_that(HexMath.round_axial(Vector2(0.9, -0.1))).is_equal(Vector2i(1, 0))
	assert_that(HexMath.round_axial(Vector2(-0.6, 0.55))).is_equal(Vector2i(-1, 1))
	for hex: Vector2i in SAMPLES:
		assert_that(HexMath.round_qr(hex.x + 0.2, hex.y - 0.2)).is_equal(hex)


func test_odd_r_offset_round_trips_and_shifts_odd_rows_right() -> void:
	assert_that(HexMath.axial_to_offset(Vector2i(0, 0))).is_equal(Vector2i(0, 0))
	assert_that(HexMath.axial_to_offset(Vector2i(0, 1))).is_equal(Vector2i(0, 1))
	assert_that(HexMath.axial_to_offset(Vector2i(-1, 2))).is_equal(Vector2i(0, 2))
	assert_that(HexMath.axial_to_offset(Vector2i(0, -1))).is_equal(Vector2i(-1, -1))
	for row in range(-7, 8):
		for column in range(-7, 8):
			var offset := Vector2i(column, row)
			assert_that(HexMath.axial_to_offset(HexMath.offset_to_axial(offset))).is_equal(offset)
