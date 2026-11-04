extends GdUnitTestSuite
## Covers world/nav/hex_layout.gd: where hexes sit on the 64x32 iso view (owner item 34,
## rulings H-a "Fallout scale" and H-b "rows left to right"; slice H0 of
## docs/design/hex-grid-plan-2026-11-03.md).

const TILE_SIZE := Vector2i(64, 32)


## A ground layer projected like the shipped maps (world/nav/*.tres): isometric, diamond down.
func _make_ground(size: Vector2i) -> TileMapLayer:
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
	var ground: TileMapLayer = auto_free(TileMapLayer.new())
	ground.tile_set = tile_set
	for y in size.y:
		for x in size.x:
			ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	return ground


static func _flat(screen: Vector2) -> Vector2:
	return Vector2(screen.x, screen.y / HexLayout.SQUASH)


func test_rows_run_left_to_right_and_neighbours_sit_one_step_apart() -> void:
	var layout := HexLayout.new(Vector2(100.0, 40.0))
	var center := Vector2i(3, -2)
	var at := layout.hex_to_world(center)
	# East and west stay on the same screen row.
	assert_float(layout.hex_to_world(HexMath.neighbor(center, 0)).y).is_equal_approx(at.y, 0.0001)
	assert_float(layout.hex_to_world(HexMath.neighbor(center, 3)).y).is_equal_approx(at.y, 0.0001)
	for direction in HexMath.DIRECTION_COUNT:
		var there := layout.hex_to_world(HexMath.neighbor(center, direction))
		assert_float(_flat(there - at).length()).is_equal_approx(layout.step, 0.0001)
	# Each row down sits lower on screen, half a hex to the side.
	var below := layout.hex_to_world(HexMath.neighbor(center, 5))
	assert_float(below.y).is_greater(at.y)
	assert_float(below.x - at.x).is_equal_approx(layout.step * 0.5, 0.0001)


func test_two_hex_steps_cover_one_cell_step() -> void:
	# Ruling H-a2: "1 AP walks 2 hexes" covers today's ground, so a hex step is half a cell side.
	var ground := _make_ground(Vector2i(4, 4))
	var cell_step := ground.map_to_local(Vector2i(1, 0)) - ground.map_to_local(Vector2i(0, 0))
	var cell_side := _flat(cell_step).length()
	assert_float(cell_side).is_equal_approx(HexLayout.CELL_SIDE, 0.0001)
	assert_float(HexLayout.DEFAULT_STEP * 2.0).is_equal_approx(cell_side, 0.0001)
	var other_axis := ground.map_to_local(Vector2i(0, 1)) - ground.map_to_local(Vector2i(0, 0))
	assert_float(_flat(other_axis).length()).is_equal_approx(cell_side, 0.0001)


func test_about_four_and_a_half_hexes_fall_in_each_cell() -> void:
	# Ruling H-a, "Fallout scale": about four hexes per current cell.
	var size := Vector2i(12, 12)
	var ground := _make_ground(size)
	var layout := HexLayout.new(ground.map_to_local(Vector2i(0, 0)))
	var inner := Rect2i(Vector2i(2, 2), size - Vector2i(4, 4))
	var bounds := Rect2(ground.map_to_local(Vector2i.ZERO), Vector2.ZERO)
	for cell: Vector2i in ground.get_used_cells():
		bounds = bounds.expand(ground.map_to_local(cell))
	var counted := 0
	for hex: Vector2i in layout.hexes_in_rect(bounds.grow(64.0)):
		if inner.has_point(ground.local_to_map(layout.hex_to_world(hex))):
			counted += 1
	var per_cell := float(counted) / float(inner.get_area())
	assert_float(per_cell).is_between(4.3, 4.9)


func test_world_positions_round_trip_to_their_hex() -> void:
	var layout := HexLayout.new(Vector2(-37.5, 812.25))
	for r in range(-12, 13):
		for q in range(-12, 13):
			var hex := Vector2i(q, r)
			var at := layout.hex_to_world(hex)
			assert_that(layout.world_to_hex(at)).is_equal(hex)
			for point: Vector2 in layout.sample_points(hex):
				assert_that(layout.world_to_hex(point)).is_equal(hex)
	# Far from the origin (a large map) the rounding still holds.
	var far := Vector2i(310, 290)
	assert_that(layout.world_to_hex(layout.hex_to_world(far) + Vector2(1.5, -0.75))).is_equal(far)


func test_corners_are_pointy_top_and_clockwise() -> void:
	var layout := HexLayout.new()
	var hex := Vector2i(2, 1)
	var center := layout.hex_to_world(hex)
	var points := layout.corners(hex)
	assert_int(points.size()).is_equal(6)
	assert_float(points[0].x).is_equal_approx(center.x, 0.0001)
	assert_float(points[0].y).is_less(center.y)
	assert_float(points[3].y).is_greater(center.y)
	for point: Vector2 in points:
		assert_float(_flat(point - center).length()).is_equal_approx(layout.corner_radius(), 0.0001)
	# Clockwise on screen (y down): the signed area is positive.
	var area := 0.0
	for i in points.size():
		area += points[i].cross(points[(i + 1) % points.size()])
	assert_float(area).is_greater(0.0)
	# Neighbouring hexes share an edge: two corners in common.
	var east := layout.corners(HexMath.neighbor(hex, 0))
	var shared := 0
	for a: Vector2 in points:
		for b: Vector2 in east:
			if a.distance_to(b) < 0.001:
				shared += 1
	assert_int(shared).is_equal(2)


func test_on_screen_a_hex_is_about_23_px_wide_and_rows_step_about_10_px() -> void:
	var layout := HexLayout.new()
	var width := layout.hex_to_world(Vector2i(1, 0)).x - layout.hex_to_world(Vector2i(0, 0)).x
	var row := layout.hex_to_world(Vector2i(0, 1)).y - layout.hex_to_world(Vector2i(0, 0)).y
	assert_float(width).is_between(22.0, 24.0)
	assert_float(row).is_between(9.0, 11.0)


func test_hexes_in_rect_lists_every_centre_inside_once() -> void:
	var layout := HexLayout.new(Vector2(13.0, -7.0))
	var rect := Rect2(Vector2(-120.0, -60.0), Vector2(300.0, 140.0))
	var found := layout.hexes_in_rect(rect)
	var seen := {}
	for hex: Vector2i in found:
		assert_bool(rect.has_point(layout.hex_to_world(hex))).is_true()
		seen[hex] = true
	assert_int(seen.size()).is_equal(found.size())
	# Nothing inside was missed: check every hex in a generous box around the rect.
	var missed := 0
	for r in range(-40, 41):
		for q in range(-40, 41):
			var hex := Vector2i(q, r)
			if rect.has_point(layout.hex_to_world(hex)) and not seen.has(hex):
				missed += 1
	assert_int(missed).is_equal(0)
	assert_bool(found.size() > 100).is_true()
