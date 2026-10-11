extends GdUnitTestSuite
## E3.2 (#340): brush geometry in a layer's own cell space (architecture §4.6.3).


func test_rect_is_inclusive_in_either_drag_direction() -> void:
	var forward: Array[Vector2i] = WeftluminBrushes.rect(Vector2i(1, 2), Vector2i(3, 3))
	assert_int(forward.size()).is_equal(6)
	assert_array(forward).contains_exactly_in_any_order(WeftluminBrushes.rect(Vector2i(3, 3), Vector2i(1, 2)))
	assert_array(forward).contains([Vector2i(1, 2), Vector2i(3, 3), Vector2i(2, 2)])
	assert_array(WeftluminBrushes.rect(Vector2i(4, 4), Vector2i(4, 4))).contains_exactly([Vector2i(4, 4)])


func test_line_includes_both_ends_and_leaves_no_gap() -> void:
	for end: Vector2i in [Vector2i(7, 3), Vector2i(-4, 6), Vector2i(0, -5), Vector2i(5, 5)]:
		var cells: Array[Vector2i] = WeftluminBrushes.line(Vector2i.ZERO, end)
		assert_object(cells.front()).is_equal(Vector2i.ZERO)
		assert_object(cells.back()).is_equal(end)
		assert_int(cells.size()).is_equal(maxi(absi(end.x), absi(end.y)) + 1)
		for index: int in range(1, cells.size()):
			var step: Vector2i = (cells[index] - cells[index - 1]).abs()
			assert_bool(step.x <= 1 and step.y <= 1).is_true()


func test_shape_cells_maps_each_brush() -> void:
	assert_array(WeftluminBrushes.shape_cells(WeftluminBrushes.Shape.CELL, Vector2i.ZERO, Vector2i(2, 1))).contains_exactly([Vector2i(2, 1)])
	assert_int(WeftluminBrushes.shape_cells(WeftluminBrushes.Shape.RECT, Vector2i.ZERO, Vector2i(2, 1)).size()).is_equal(6)
	assert_int(WeftluminBrushes.shape_cells(WeftluminBrushes.Shape.LINE, Vector2i.ZERO, Vector2i(2, 1)).size()).is_equal(3)


func test_fill_stays_inside_a_painted_boundary_and_the_bounds() -> void:
	# A wall along x == 3 splits a 6x4 region; filling from the left stops at the wall.
	var wall: Dictionary = {}
	for y: int in 4:
		wall[Vector2i(3, y)] = true
	var tile_at := func(cell: Vector2i) -> Array: return [0, 0, 0, 0] if wall.has(cell) else []
	var result: Dictionary = WeftluminBrushes.fill(Vector2i(0, 0), tile_at, Rect2i(0, 0, 6, 4))
	assert_bool(result["truncated"]).is_false()
	var cells: Array = result["cells"]
	assert_int(cells.size()).is_equal(12)
	for cell: Vector2i in cells:
		assert_int(cell.x).is_less(3)
	# Filling the wall itself replaces exactly the wall.
	assert_int((WeftluminBrushes.fill(Vector2i(3, 1), tile_at, Rect2i(0, 0, 6, 4))["cells"] as Array).size()).is_equal(4)
	# Outside the bounds there is nothing to fill.
	assert_array(WeftluminBrushes.fill(Vector2i(9, 9), tile_at, Rect2i(0, 0, 6, 4))["cells"]).is_empty()


func test_fill_past_the_limit_is_truncated_not_partial() -> void:
	var empty := func(_cell: Vector2i) -> Array: return []
	var result: Dictionary = WeftluminBrushes.fill(Vector2i.ZERO, empty, Rect2i(-50, -50, 100, 100), 100)
	assert_bool(result["truncated"]).is_true()
	assert_array(result["cells"]).is_empty()
