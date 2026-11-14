extends GdUnitTestSuite
## BuildingPlan (owner list item 35, layouts ruled 2026-11-04): reading a walk-in building's text
## grid into walls, rooms, furniture, kit pieces, the per-room cutaway ("Your room opens") and the
## roof computed from the outline.

const LAYOUTS := {
	"tavern": "res://world/buildings/layouts/tavern.tres",
	"shop": "res://world/buildings/layouts/shop.tres",
	"cottage": "res://world/buildings/layouts/cottage.tres",
	"warehouse": "res://world/buildings/layouts/warehouse.tres",
}
const Kind := BuildingPlan.Kind
const State := BuildingPlan.State


func _plan(layout_name: String, turns := 0) -> BuildingPlan:
	return (load(LAYOUTS[layout_name]) as BuildingLayout).plan(turns)


func test_the_four_layouts_are_sound() -> void:
	var expected := {
		"tavern": [Vector2i(16, 13), 5], "shop": [Vector2i(10, 8), 2],
		"cottage": [Vector2i(9, 9), 2], "warehouse": [Vector2i(14, 6), 1],
	}
	for layout_name: String in expected:
		var plan := _plan(layout_name)
		assert_array(Array(plan.problems())).override_failure_message(layout_name).is_empty()
		assert_vector(plan.size).override_failure_message(layout_name).is_equal(expected[layout_name][0])
		assert_int(plan.room_count).override_failure_message(layout_name).is_equal(expected[layout_name][1])


func test_a_turn_puts_the_front_row_on_the_right() -> void:
	var plan := _plan("warehouse")
	var turned := _plan("warehouse", 1)
	assert_vector(turned.size).is_equal(Vector2i(6, 14))
	assert_array(Array(turned.problems())).is_empty()
	assert_int(turned.room_count).is_equal(1)
	# The front doorway, cells 4 and 5 of the front row, now stands in the right column.
	for i in plan.size.x:
		assert_str(turned.at(Vector2i(plan.size.y - 1, plan.size.x - 1 - i))).is_equal(plan.at(Vector2i(i, plan.size.y - 1)))
	assert_array(Array(BuildingPlan.turned(plan.rows, 4))).is_equal(Array(plan.rows))


func test_problems_name_what_is_wrong() -> void:
	var open := BuildingPlan.from_rows(PackedStringArray(["####", "#..#", "#.. ", "##D#"]))
	assert_str(" ".join(open.problems())).contains("open to the outside")
	var shut := BuildingPlan.from_rows(PackedStringArray(["####", "#..#", "####"]))
	assert_str(" ".join(shut.problems())).contains("no doorway reaches")
	var bent := BuildingPlan.from_rows(PackedStringArray(["#####", "#TT.#", "#T..#", "###D#"]))
	assert_str(" ".join(bent.problems())).contains("not a rectangle")
	var corner := BuildingPlan.from_rows(PackedStringArray(["D###", "#..#", "#..#", "#D##"]))
	assert_str(" ".join(corner.problems())).contains("not in a straight wall")


func test_walls_stand_as_full_pieces_halves_posts_and_pillars() -> void:
	var plan := _plan("warehouse")
	var by_cell := {}
	for piece: Dictionary in plan.pieces:
		var cell: Vector2i = piece["cell"]
		if not by_cell.has(cell):
			by_cell[cell] = []
		(by_cell[cell] as Array).append(piece)
	# A straight run: one whole piece.
	var straight: Array = by_cell[Vector2i(3, 0)]
	assert_int(straight.size()).is_equal(1)
	assert_int(int(straight[0]["kind"])).is_equal(Kind.WALL)
	assert_int(int(straight[0]["half"])).is_equal(0)
	# The back corner: a half towards each wall it meets, and a post.
	var corner: Array = by_cell[Vector2i(0, 0)]
	var kinds := corner.map(func(piece: Dictionary) -> int: return int(piece["kind"]))
	assert_array(kinds).contains_exactly_in_any_order([Kind.WALL, Kind.WALL, Kind.POST])
	# A free-standing pillar in the hall, a window and a doorway.
	assert_int(int((by_cell[Vector2i(5, 2)] as Array)[0]["kind"])).is_equal(Kind.PILLAR)
	assert_int(int((by_cell[Vector2i(13, 2)] as Array)[0]["kind"])).is_equal(Kind.WINDOW)
	assert_int(int((by_cell[Vector2i(4, 5)] as Array)[0]["kind"])).is_equal(Kind.LINTEL)


func test_shots_stop_at_walls_but_pass_windows_and_doorways() -> void:
	var plan := _plan("shop")
	var fire := plan.blocks_fire_cells()
	var solid := plan.solid_cells()
	for cell: Vector2i in [Vector2i(0, 5), Vector2i(9, 5), Vector2i(7, 7)]:
		assert_bool(cell in solid).override_failure_message("window %s walks" % cell).is_true()
		assert_bool(cell in fire).override_failure_message("window %s shoots" % cell).is_false()
	for cell: Vector2i in [Vector2i(5, 2), Vector2i(9, 2), Vector2i(3, 7)]:
		assert_bool(cell in solid or cell in fire).override_failure_message("doorway %s" % cell).is_false()
	assert_bool(Vector2i(0, 0) in fire).is_true()
	# Furniture stops a walk, not a shot.
	assert_bool(Vector2i(1, 3) in solid).is_true()
	assert_bool(Vector2i(1, 3) in fire).is_false()


func test_the_solid_rects_cover_exactly_the_solid_cells() -> void:
	for layout_name: String in LAYOUTS:
		var plan := _plan(layout_name)
		var covered := {}
		for rect: Rect2i in plan.solid_rects():
			for j in range(rect.position.y, rect.end.y):
				for i in range(rect.position.x, rect.end.x):
					assert_bool(covered.has(Vector2i(i, j))).override_failure_message("%s %s twice" % [layout_name, Vector2i(i, j)]).is_false()
					covered[Vector2i(i, j)] = true
		var expected := plan.solid_cells()
		assert_int(covered.size()).override_failure_message(layout_name).is_equal(expected.size())
		for cell: Vector2i in expected:
			assert_bool(covered.has(cell)).override_failure_message("%s %s" % [layout_name, cell]).is_true()


func test_furniture_runs_are_single_pieces() -> void:
	var plan := _plan("tavern")
	var found := {}
	for item: Dictionary in plan.furniture:
		var rect: Rect2i = item["rect"]
		found["%s %s" % [item["kind"], rect]] = true
	assert_bool(found.has("counter %s" % Rect2i(1, 7, 4, 1))).is_true()
	assert_bool(found.has("table %s" % Rect2i(2, 9, 2, 2))).is_true()
	assert_bool(found.has("bed %s" % Rect2i(14, 2, 1, 2))).is_true()
	assert_bool(found.has("hearth %s" % Rect2i(7, 2, 2, 1))).is_true()


## "Your room opens" (owner ruling 2026-11-04): in the shop's front room, the front walls drop and
## the doorway to the storeroom loses its lintel; the storeroom's front wall, which would hide part
## of the shop floor, fades; the back wall stays whole.
func test_the_party_s_room_opens_and_other_rooms_stay_tucked_away() -> void:
	var plan := _plan("shop")
	var shop: Array[int] = []
	shop.assign(plan.rooms_of(Vector2i(3, 5)))
	var store: Array[int] = []
	store.assign(plan.rooms_of(Vector2i(7, 2)))
	assert_int(shop.size()).is_equal(1)
	assert_bool(shop == store).is_false()
	var states := {}
	for index in plan.pieces.size():
		var cell: Vector2i = plan.pieces[index]["cell"]
		if not states.has(cell):
			states[cell] = []
		(states[cell] as Array).append(plan.state_of(index, shop))
	for i in range(1, 9):
		assert_array(states[Vector2i(i, 7)]).override_failure_message("front %d" % i).contains_exactly_in_any_order(_all(states[Vector2i(i, 7)], State.LOW))
	# The back wall's own pieces stay whole (the half at (5, 0) that turns down into the inner
	# wall is that wall's, and drops with it).
	for index in plan.pieces.size():
		var piece := plan.pieces[index]
		if piece["cell"].y == 0 and piece["run"] == "x":
			assert_int(plan.state_of(index, shop)).override_failure_message("back %s" % piece["cell"]).is_equal(State.FULL)
	assert_array(states[Vector2i(5, 2)]).is_equal([State.LOW])
	var store_front: Array = []
	for i in range(6, 9):
		store_front.append_array(states[Vector2i(i, 4)])
	assert_array(store_front).not_contains([State.LOW])
	assert_array(store_front).contains([State.FADED])
	# In the storeroom instead, its own front wall drops.
	for i in range(6, 9):
		var index := _piece_at(plan, Vector2i(i, 4))
		assert_int(plan.state_of(index, store)).is_equal(State.LOW)
	# Outside (no open room), everything is whole.
	for index in plan.pieces.size():
		assert_int(plan.state_of(index, [] as Array[int])).is_equal(State.FULL)


## The roof clears every wall top, post and lintel: at each corner of a piece's box it stands at
## least ROOF_SEAT above the wall tops.
func test_the_roof_covers_every_wall_and_post() -> void:
	for layout_name: String in LAYOUTS:
		for turns in 2:
			var plan := _plan(layout_name, turns)
			for piece: Dictionary in plan.pieces:
				var hull: PackedVector2Array = piece["hull"]
				var cell: Vector2i = piece["cell"]
				var radius := 0.5 * (BuildingPlan.POST_SIZE if piece["kind"] == Kind.POST else BuildingPlan.WALL_THICKNESS)
				for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var at := Vector2(cell.x + 0.5, cell.y + 0.5) + corner * radius
					assert_float(plan.roof_height(at.x, at.y)).override_failure_message("%s %s" % [layout_name, cell]) \
						.is_greater_equal(BuildingPlan.WALL_HEIGHT + BuildingPlan.ROOF_SEAT - 0.001)
				assert_int(hull.size()).is_greater(3)


func test_the_roof_rises_to_a_ridge_and_dips_into_valleys() -> void:
	var plan := _plan("warehouse")
	# Six cells deep: the ridge runs along the middle, three cells in from either long wall.
	var rise := tan(deg_to_rad(BuildingPlan.ROOF_PITCH_DEGREES))
	assert_float(plan.roof_height(7.0, 3.0) - plan.roof_height(7.0, 1.0)).is_equal_approx(2.0 * rise, 0.001)
	assert_float(plan.roof_height(7.0, 3.0)).is_greater(plan.roof_height(7.0, 2.5))
	# The tavern's kitchen wing joins the main hall in a valley: lower than either ridge.
	var tavern := _plan("tavern")
	assert_float(tavern.outline_distance(6.0, 1.0)).is_equal_approx(0.0, 0.001)
	assert_int(tavern.roof_triangles().size()).is_equal(tavern.footprint_cells().size() * 16)


func _all(states: Array, state: int) -> Array:
	return states.map(func(_s: int) -> int: return state)


func _piece_at(plan: BuildingPlan, cell: Vector2i) -> int:
	for index in plan.pieces.size():
		if plan.pieces[index]["cell"] == cell:
			return index
	return -1
