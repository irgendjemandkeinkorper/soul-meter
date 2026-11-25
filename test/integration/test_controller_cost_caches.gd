extends GdUnitTestSuite
## Controller cost caches (#642). What the controller priced or copied for a snapshot is kept
## while nothing it read has changed, and priced or copied again after a write to something it
## read. Each cache is checked both ways, and a rebuilt reach is checked against a pricing from
## scratch. On hexes, the grid the game runs on.

const GridMode := preload("res://test/helpers/grid_mode.gd")
const TILE_SIZE := Vector2i(64, 32)
const FIELD := Vector2i(40, 20)

var _grid_before: Variant


func before_test() -> void:
	_grid_before = GridMode.use_hexes()


func after_test() -> void:
	GridMode.restore(_grid_before)


func _ground(size: Vector2i) -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = TILE_SIZE
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(
		Image.create(TILE_SIZE.x, TILE_SIZE.y, false, Image.FORMAT_RGBA8)
	)
	source.texture_region_size = TILE_SIZE
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	for y in size.y:
		for x in size.x:
			layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	return layer


func _actor(display_name: String) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = display_name
	actor.hp = 200
	actor.max_hp = 200
	actor.attack = 1
	return actor


## An AP-economy fight: the ally on the west side, both foes parked on the far east side, well
## outside every hex the ally's reach search reads.
func _controller() -> CombatController:
	var rules := (
		load("res://data/combat/combat_rules.tres") as CombatRules
	).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_ground(FIELD))
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	controller.start(
		[_actor("Ally")], [_actor("Near Foe"), _actor("Far Foe")], &"cost-cache-test"
	)
	_place(controller, controller.enemies[0], Vector2i(36, 4))
	_place(controller, controller.enemies[1], Vector2i(36, 16))
	_place(controller, controller.allies[0], Vector2i(6, 10))
	return controller


func _grid(controller: CombatController) -> GridBattlefieldModel:
	return controller.battlefield as GridBattlefieldModel


func _hex(controller: CombatController, square: Vector2i) -> Vector2i:
	return _grid(controller)._grid.cell_at_square(square)


## Puts `actor` on the hex under the centre of the square cell `square`.
func _place(controller: CombatController, actor: BattleActor, square: Vector2i) -> void:
	var moved := _grid(controller).displace(actor, _hex(controller, square))
	assert_bool(bool(moved.get("allowed", false))).override_failure_message(str(moved)).is_true()


func _reach(controller: CombatController) -> Array:
	return (controller.snapshot()["movement"] as Dictionary)["reachable"]


func _destinations(rows: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for row: Dictionary in rows:
		result.append(row["destination"])
	return result


func _cell(controller: CombatController, handle: StringName) -> Vector2i:
	return _grid(controller).describe_position(handle)["cell"]


## `rows` equal a pricing from scratch.
func _assert_priced_as_new(controller: CombatController, rows: Array) -> void:
	controller._reach_cache.clear()
	var fresh := _reach(controller)
	assert_bool(is_same(fresh, rows)).is_false()
	assert_array(fresh).is_equal(rows)


func test_the_reach_is_kept_while_nothing_it_read_changes() -> void:
	var controller := _controller()
	var first := _reach(controller)
	assert_bool(first.is_empty()).is_false()
	assert_bool(first.is_read_only()).is_true()
	assert_bool(is_same(_reach(controller), first)).override_failure_message(
		"a second snapshot priced the reach again"
	).is_true()
	# A foe moving far outside every hex the reach search read leaves the reach as it was.
	_place(controller, controller.enemies[1], Vector2i(30, 18))
	assert_bool(is_same(_reach(controller), first)).override_failure_message(
		"a far move priced the reach again"
	).is_true()
	_assert_priced_as_new(controller, first)


func test_the_reach_is_priced_again_when_a_foe_steps_into_it() -> void:
	var controller := _controller()
	var first := _reach(controller)
	var stand: StringName = first[first.size() / 2]["destination"]
	var moved := _grid(controller).displace(controller.enemies[0], _cell(controller, stand))
	assert_bool(bool(moved.get("allowed", false))).is_true()
	var second := _reach(controller)
	assert_bool(is_same(second, first)).is_false()
	assert_bool(_destinations(second).has(stand)).override_failure_message(
		"an occupied hex is still offered"
	).is_false()
	_assert_priced_as_new(controller, second)


func test_the_reach_is_priced_again_when_a_foe_leaves_it() -> void:
	var controller := _controller()
	_place(controller, controller.enemies[0], Vector2i(8, 10))
	var held := _grid(controller).position_of(controller.enemies[0])
	var first := _reach(controller)
	assert_bool(_destinations(first).has(held)).is_false()
	_place(controller, controller.enemies[0], Vector2i(36, 4))
	var second := _reach(controller)
	assert_bool(is_same(second, first)).is_false()
	assert_bool(_destinations(second).has(held)).override_failure_message(
		"the hex the foe left is not offered"
	).is_true()
	_assert_priced_as_new(controller, second)


## A cliff makes its hex impassable (an obstacle only blocks sight and fire).
func test_the_reach_is_priced_again_when_a_cliff_rises_in_it() -> void:
	var controller := _controller()
	var first := _reach(controller)
	var stand: StringName = first[0]["destination"]
	_grid(controller).set_cliff(_cell(controller, stand))
	var second := _reach(controller)
	assert_bool(is_same(second, first)).is_false()
	assert_bool(_destinations(second).has(stand)).is_false()
	_assert_priced_as_new(controller, second)


func test_an_actor_row_is_built_again_after_a_write_to_that_actor() -> void:
	var controller := _controller()
	var foe := controller.enemies[0]
	var first := controller.snapshot()
	var foe_before: Dictionary = (first["enemies"] as Array)[0]
	var ally_before: Dictionary = (first["allies"] as Array)[0]
	assert_bool(foe_before.is_read_only()).is_true()
	foe.hp -= 7
	foe.discovered_weakness_ids.append(&"test-weakness")
	var second := controller.snapshot()
	var foe_after: Dictionary = (second["enemies"] as Array)[0]
	var ally_after: Dictionary = (second["allies"] as Array)[0]
	assert_int(int(foe_after["hp"])).is_equal(int(foe_before["hp"]) - 7)
	assert_array(foe_after["discovered_weakness_ids"]).contains([&"test-weakness"])
	assert_bool((foe_before["discovered_weakness_ids"] as Array).has(&"test-weakness")).override_failure_message(
		"the earlier snapshot's row changed with the actor"
	).is_false()
	# What the write did not touch is the frozen copy the last row carried.
	assert_bool(is_same(foe_after["anatomy"], foe_before["anatomy"])).is_true()
	assert_bool(is_same(ally_after["anatomy"], ally_before["anatomy"])).is_true()
	assert_dict(ally_after).is_equal(ally_before)


func test_a_tile_state_write_builds_the_tile_rows_again() -> void:
	var controller := _controller()
	var first: Array = controller.snapshot()["tiles"]
	assert_bool(first.is_empty()).is_false()
	assert_bool(is_same(controller.snapshot()["tiles"], first)).is_true()
	var picked: Dictionary = first[first.size() / 2]
	var cell := Vector2i(int(picked["x"]), int(picked["y"]))
	var tile := controller.tile_state_at(cell)
	for level: int in [2, 3]:
		tile.charge_level = level
		var rows: Array = controller.snapshot()["tiles"]
		assert_bool(is_same(rows, first)).is_false()
		var seen := false
		for row: Dictionary in rows:
			if Vector2i(int(row["x"]), int(row["y"])) == cell:
				assert_int(int(row["charge_level"])).is_equal(level)
				seen = true
		assert_bool(seen).is_true()
	assert_int(int(picked["charge_level"])).override_failure_message(
		"the earlier snapshot's row changed with the tile"
	).is_equal(0)


func test_a_board_write_ends_an_open_path_memo() -> void:
	var controller := _controller()
	var grid := _grid(controller)
	var ally := controller.allies[0]
	grid.begin_path_memo(ally, 40)
	var stand: StringName = grid.reachable_positions(ally, 40)[0]
	assert_bool(bool(grid.path_query(ally, stand).get("allowed", false))).is_true()
	grid.set_cliff(_cell(controller, stand))
	assert_bool(bool(grid.path_query(ally, stand).get("allowed", true))).override_failure_message(
		"the memo answered for a board that has changed"
	).is_false()
	grid.end_path_memo()


func test_memo_walk_cells_are_the_cells_of_each_answer() -> void:
	var controller := _controller()
	var grid := _grid(controller)
	var ally := controller.allies[0]
	grid.begin_path_memo(ally, 40)
	var path: Array = []
	for stand: StringName in grid.reachable_positions(ally, 40):
		path = grid.path_query(ally, stand)["path"]
		var cells: Array[Vector2i] = []
		for handle: StringName in path:
			cells.append(_cell(controller, handle))
		assert_array(grid.memo_walk_cells(path)).is_equal(cells)
	assert_bool(path.is_empty()).is_false()
	# Only the memo's own walk is answered: not a copy, and nothing once the memo is closed.
	assert_that(grid.memo_walk_cells(path.duplicate())).is_null()
	grid.end_path_memo()
	assert_that(grid.memo_walk_cells(path)).is_null()


## The hex steps a search takes are kept per hex: a weight change must reach the next search.
func test_a_hex_weight_change_reaches_the_next_search() -> void:
	var controller := _controller()
	var grid := _grid(controller)
	var ally := controller.allies[0]
	var step_cost := controller.rules.move_ct_cost / 2
	var start: Vector2i = grid.cell_of(ally)
	var heavy := start + HexMath.DIRECTIONS[0]
	var target := grid._handle_for_cell(start + HexMath.DIRECTIONS[0] * 2)
	var straight := grid.path_query(ally, target)
	assert_int(int(straight["ct_cost"])).is_equal(2 * step_cost)
	assert_array(straight["path"]).contains([grid._handle_for_cell(heavy)])
	grid._grid.set_point_weight_scale(heavy, 5.0)
	var around := grid.path_query(ally, target)
	assert_array(around["path"]).not_contains([grid._handle_for_cell(heavy)])
	assert_int(int(around["ct_cost"])).is_equal(3 * step_cost)


func test_a_reach_stamp_holds_for_far_writes_and_fails_for_near_ones() -> void:
	var controller := _controller()
	var grid := _grid(controller)
	var ally := controller.allies[0]
	grid.begin_path_memo(ally, 40)
	var stamp := grid.path_memo_stamp()
	grid.end_path_memo()
	assert_bool(grid.reach_stamp_current(stamp)).is_true()
	grid.set_cover(_hex(controller, Vector2i(36, 10)), true)
	assert_bool(grid.reach_stamp_current(stamp)).override_failure_message(
		"a far write failed the stamp"
	).is_true()
	grid.set_cover(grid.cell_of(ally) + HexMath.DIRECTIONS[0], true)
	assert_bool(grid.reach_stamp_current(stamp)).override_failure_message(
		"a write inside the search held the stamp"
	).is_false()


func test_probe_open_lifts_a_solid_without_a_revision() -> void:
	var controller := _controller()
	var iso := _grid(controller)._grid
	var cell := _hex(controller, Vector2i(12, 10))
	iso.set_point_solid(cell, true)
	var revision := iso.revision
	var was_solid := iso.probe_open(cell)
	assert_bool(was_solid).is_true()
	assert_bool(iso.is_point_solid(cell)).is_false()
	iso.probe_close(cell, was_solid)
	assert_bool(iso.is_point_solid(cell)).is_true()
	assert_int(iso.revision).is_equal(revision)


func test_the_frontier_pops_cheapest_first_and_breaks_near_ties_by_cell_index() -> void:
	var frontier := GridBattlefieldModel._Frontier.new()
	frontier.push(Vector2i(0, 0), 2.0, 5)
	frontier.push(Vector2i(1, 0), 1.0, 9)
	frontier.push(Vector2i(2, 0), 1.0 + 1e-7, 3)
	frontier.push(Vector2i(3, 0), 0.5, 7)
	frontier.push(Vector2i(4, 0), 1.0, 4)
	var order: Array[Vector2i] = []
	while not frontier.is_empty():
		order.append(frontier.top_cell())
		frontier.pop()
	assert_array(order).is_equal(
		[Vector2i(3, 0), Vector2i(2, 0), Vector2i(4, 0), Vector2i(1, 0), Vector2i(0, 0)]
	)


func test_hex_facing_by_offset_matches_the_hex_line() -> void:
	for delta: Vector2i in [Vector2i(3, -1), Vector2i(-2, 5), Vector2i(0, 1), Vector2i(4, 4)]:
		var expected: StringName = GridBattlefieldModel.HEX_ORDER[
			HexMath.direction_toward(Vector2i.ZERO, delta)
		]
		for ask in 2:
			assert_that(GridBattlefieldModel.facing_for_delta(delta)).is_equal(expected)


func test_walk_fed_reach_rows_match_a_query_per_stand_on_hexes() -> void:
	_assert_rows_match_queries(_controller())


func test_walk_fed_reach_rows_match_a_query_per_stand_on_squares() -> void:
	GridMode.use_squares()
	_assert_rows_match_queries(_controller())


## The reach a pricing builds from the memo search's walks (`memo_reach_walks()`) offers the
## stands, prices, paths and cells that a separate `query_action_for()` gives each stand from
## scratch, with a foe standing inside the reach.
func _assert_rows_match_queries(controller: CombatController) -> void:
	_place(controller, controller.enemies[0], Vector2i(8, 10))
	var actor := controller.allies[0]
	var rows := _reach(controller)
	assert_bool(rows.is_empty()).is_false()
	var move := controller.action_by_id(CombatController.ACTION_MOVE)
	var ct_budget := int(
		float(controller._move_budget(actor)) / CombatInjury.move_cost_multiplier(actor)
	)
	var expected: Array[StringName] = []
	for destination: StringName in _grid(controller).reachable_positions(actor, ct_budget):
		var query := controller.query_action_for(actor, move, null, {"destination": destination})
		if bool(query.get("allowed", false)):
			expected.append(destination)
	assert_array(_destinations(rows)).is_equal(expected)
	assert_bool(_destinations(rows).has(_grid(controller).position_of(controller.enemies[0]))).is_false()
	for row: Dictionary in rows:
		var query := controller.query_action_for(actor, move, null, {"destination": row["destination"]})
		assert_int(int(row["ap_cost"])).is_equal(int(query["ap_cost"]))
		assert_int(int(row["ct_cost"])).is_equal(int(query["ct_cost"]))
		assert_array(Array(row["path"])).is_equal(Array(query["path"]))
		assert_array(Array(row["path_cells"])).is_equal(
			Array(controller._describe_path_cells(query["path"]))
		)
