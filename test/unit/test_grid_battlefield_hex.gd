extends GdUnitTestSuite
## Hex grid H2 (owner item 34; docs/design/hex-grid-plan-2026-11-03.md, "How the rules carry
## over"): the battlefield model fights on hexes when `soul_meter/grid/hex` is on. Distances count
## hex steps, a move costs half a cell's price per hex (an odd count rounds up), melee is touching,
## reaches and radii double, facing has six directions, sight walks hex lines, and terrain comes
## from the square cell under each hex. The setting is restored after every test.

const TILE_SIZE := Vector2i(64, 32)
const MOVE_COST := 20

var _setting_before: Variant


func before_test() -> void:
	_setting_before = ProjectSettings.get_setting(IsoGrid.HEX_SETTING, false)
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, true)


func after_test() -> void:
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, _setting_before)


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
	# The custom data the model reads from a Terrain layer.
	var layers := {"cover": TYPE_BOOL, "blocks_fire": TYPE_BOOL, "visibility": TYPE_STRING, "elevation": TYPE_INT}
	for layer_name: String in layers:
		var index := tile_set.get_custom_data_layers_count()
		tile_set.add_custom_data_layer()
		tile_set.set_custom_data_layer_name(index, layer_name)
		tile_set.set_custom_data_layer_type(index, int(layers[layer_name]))
	return tile_set


func _make_layer(cells: Array[Vector2i], tile_set: TileSet, parent: Node = null, layer_name := "") -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	if not layer_name.is_empty():
		layer.name = layer_name
	for cell: Vector2i in cells:
		layer.set_cell(cell, 0, Vector2i(0, 0))
	if parent != null:
		parent.add_child(layer)
	else:
		auto_free(layer)
	return layer


func _square(size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			cells.append(Vector2i(x, y))
	return cells


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.move_ct_cost = MOVE_COST
	return rules


## A model over an open `size` field (and optional walls and cover cells), with the given actors
## seated on the hexes under the given square cells' centres.
func _model(size: Vector2i, walls: Array[Vector2i] = [], cover: Array[Vector2i] = []) -> GridBattlefieldModel:
	var root: Node2D = auto_free(Node2D.new())
	var tile_set := _make_tile_set()
	var ground := _make_layer(_square(size), tile_set, root, "Ground")
	var blocking: TileMapLayer = _make_layer(walls, tile_set, root, "Blocking") if not walls.is_empty() else null
	if not cover.is_empty():
		var terrain := _make_layer(cover, tile_set, root, "Terrain")
		for cell: Vector2i in cover:
			terrain.get_cell_tile_data(cell).set_custom_data(&"cover", true)
	var model := GridBattlefieldModel.new()
	model.configure(_rules())
	model.build_grid(ground, blocking)
	return model


func _actor(id: String) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = id
	actor.combat_id = StringName(id)
	actor.max_hp = 10
	actor.hp = 10
	return actor


func _seat(model: GridBattlefieldModel, cells: Dictionary, allies: Array[BattleActor], enemies: Array[BattleActor]) -> void:
	assert_bool(bool(model.configure_initial_cells(cells).get("allowed", false))).is_true()
	model.setup(allies, enemies)


func _grid(model: GridBattlefieldModel) -> IsoGrid:
	return model._grid


func _handle(model: GridBattlefieldModel, hex: Vector2i) -> StringName:
	return model._handle_for_cell(hex)


func test_the_metric_counts_hex_steps_and_converts_authored_numbers() -> void:
	assert_bool(GridMetric.hex()).is_true()
	assert_int(GridMetric.distance(Vector2i.ZERO, Vector2i(3, -1))).is_equal(3)
	assert_int(GridMetric.reach(1)).override_failure_message("melee stays touching").is_equal(1)
	assert_int(GridMetric.reach(4)).is_equal(8)
	assert_int(GridMetric.radius(1)).is_equal(2)
	assert_int(GridMetric.ring(Vector2i(2, 2), 3).size()).is_equal(18)
	assert_that(GridMetric.straight_step(Vector2i.ZERO, Vector2i(0, 4))).is_equal(Vector2i(0, 1))
	assert_that(GridMetric.straight_step(Vector2i.ZERO, Vector2i(1, 2))).is_equal(Vector2i.ZERO)
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, false)
	assert_int(GridMetric.distance(Vector2i.ZERO, Vector2i(3, -1))).is_equal(3)
	assert_int(GridMetric.distance(Vector2i.ZERO, Vector2i(2, 2))).is_equal(2)
	assert_int(GridMetric.reach(4)).is_equal(4)
	assert_int(GridMetric.radius(1)).is_equal(1)
	assert_that(GridMetric.straight_step(Vector2i.ZERO, Vector2i(0, 2))).is_equal(Vector2i(0, 1))


func test_the_model_fights_on_the_shared_hex_grid() -> void:
	var model := _model(Vector2i(10, 10))
	assert_bool(_grid(model).hex_mode).is_true()
	var hero := _actor("hero")
	var foe := _actor("foe")
	model.setup([hero], [foe])
	# The default columns are authored on cells; on hexes each seat is the hex under its centre.
	for actor: BattleActor in [hero, foe]:
		var at: Vector2i = model.cell_of(actor)
		assert_bool(_grid(model).is_in_bounds(at)).is_true()
	assert_that(model.facing_of(hero)).is_equal(&"hex_e")
	assert_that(model.facing_of(foe)).is_equal(&"hex_w")


## The model prices each hex at half a cell; the AP economy charges whole cells
## (`CombatController._priced_move_action`), so an odd count rounds up: 3 hexes = 2 AP.
func test_a_move_costs_half_a_cell_per_hex_and_an_odd_count_rounds_up() -> void:
	var model := _model(Vector2i(10, 10))
	var hero := _actor("hero")
	var start := _grid(model).cell_at_square(Vector2i(5, 5))
	_seat(model, {hero: start}, [hero], [])
	for hexes: int in [1, 2, 3, 4, 7]:
		var to := start + HexMath.DIRECTIONS[0] * hexes
		var query := model.path_query(hero, _handle(model, to))
		assert_bool(bool(query.get("allowed", false))).override_failure_message(str(query)).is_true()
		assert_int((query["path"] as Array).size() - 1).is_equal(hexes)
		assert_int(int(query["ct_cost"])).override_failure_message("%d hexes" % hexes).is_equal(hexes * MOVE_COST / 2)
		var ap_units := ceili(float(query["ct_cost"]) / float(MOVE_COST))
		assert_int(ap_units).override_failure_message("%d hexes" % hexes).is_equal(ceili(hexes / 2.0))


func test_a_move_budget_reaches_twice_as_many_hexes_as_cells() -> void:
	var model := _model(Vector2i(14, 14))
	var hero := _actor("hero")
	var start := _grid(model).cell_at_square(Vector2i(7, 7))
	_seat(model, {hero: start}, [hero], [])
	var reachable := model.reachable_positions(hero, 2 * MOVE_COST)
	var farthest := 0
	for handle: StringName in reachable:
		farthest = maxi(farthest, HexMath.distance(start, model.describe_position(handle)["cell"]))
	# Two cells' budget walks four hexes, and every hex within four is open ground here.
	assert_int(farthest).is_equal(4)
	assert_int(reachable.size()).is_equal(HexMath.within(start, 4).size() - 1)


func test_melee_needs_touching_hexes() -> void:
	var model := _model(Vector2i(10, 10))
	var hero := _actor("hero")
	var near := _actor("near")
	var far := _actor("far")
	var start := _grid(model).cell_at_square(Vector2i(5, 5))
	_seat(model, {hero: start, near: start + HexMath.DIRECTIONS[1], far: start + HexMath.DIRECTIONS[3] * 2}, [hero], [near, far])
	assert_bool(bool(model.target_query(hero, near, &"melee").get("allowed", false))).is_true()
	var refused := model.target_query(hero, far, &"melee")
	assert_that(refused.get("blocked_by")).is_equal(&"position")


func test_six_facings_give_one_front_four_sides_and_one_back() -> void:
	var model := _model(Vector2i(10, 10))
	var foe := _actor("foe")
	var center := _grid(model).cell_at_square(Vector2i(5, 5))
	var attackers: Array[BattleActor] = []
	var cells := {foe: center}
	for direction in HexMath.DIRECTION_COUNT:
		var attacker := _actor("a%d" % direction)
		attackers.append(attacker)
		cells[attacker] = center + HexMath.DIRECTIONS[direction]
	_seat(model, cells, attackers, [foe])
	assert_bool(bool(model.set_facing(foe, &"hex_e").get("allowed", false))).is_true()
	assert_bool(bool(model.set_facing(foe, &"se").get("allowed", false))).override_failure_message("square names are not hex facings").is_false()
	var front := 0
	var back := 0
	var flanked := 0
	for attacker: BattleActor in attackers:
		var toward := GridBattlefieldModel.facing_for_delta(model.cell_of(attacker) - center)
		if toward == model.facing_of(foe):
			front += 1
		elif toward == GridBattlefieldModel.opposite_facing(model.facing_of(foe)):
			back += 1
		if model.flank_bonus(attacker, foe) > 0:
			flanked += 1
	assert_int(front).is_equal(1)
	assert_int(back).is_equal(1)
	assert_int(flanked).override_failure_message("side and back flank").is_equal(5)


func test_sight_reaches_twice_the_cells_in_hexes_and_a_body_blocks_it() -> void:
	var model := _model(Vector2i(16, 16))
	var hero := _actor("hero")
	var in_range := _actor("in_range")
	var out_of_range := _actor("out_of_range")
	# From the field's left corner east along its widest line (about 42 hexes across).
	var start := _grid(model).cell_at_square(Vector2i(1, 14))
	var line := HexMath.DIRECTIONS[0]
	var cells := {hero: start, in_range: start + line * 24, out_of_range: start + line * 25}
	for hex: Vector2i in cells.values():
		assert_bool(_grid(model).is_in_bounds(hex)).override_failure_message("fixture hex %s off the field" % hex).is_true()
	_seat(model, cells, [hero], [in_range, out_of_range])
	assert_bool(bool(model.line_of_sight(hero, in_range).get("allowed", false))).is_true()
	assert_that(model.line_of_sight(hero, out_of_range).get("blocked_by")).is_equal(&"blocked_by_range")
	var blocker := _actor("blocker")
	model.admit_combatant(blocker, _handle(model, start + line * 5), &"ally")
	assert_that(model.line_of_sight(hero, in_range).get("blocked_by")).is_equal(&"blocked_by_occupancy")


func test_a_painted_wall_stops_a_path_on_hexes() -> void:
	# A wall one cell thick across the whole field, on the iso diagonal: the leak case.
	var walls: Array[Vector2i] = []
	for i in 10:
		walls.append(Vector2i(i, 9 - i))
	var model := _model(Vector2i(10, 10), walls)
	var hero := _actor("hero")
	var start := _grid(model).cell_at_square(Vector2i(1, 1))
	var other_side := _grid(model).cell_at_square(Vector2i(8, 8))
	_seat(model, {hero: start}, [hero], [])
	var query := model.path_query(hero, _handle(model, other_side))
	assert_that(query.get("blocked_by")).is_equal(&"position")
	for handle: StringName in model.reachable_positions(hero, 40 * MOVE_COST):
		var hex: Vector2i = model.describe_position(handle)["cell"]
		assert_bool(walls.has(_grid(model).square_cell_of(hex))).is_false()
		assert_bool(_grid(model).square_cell_of(hex).x + _grid(model).square_cell_of(hex).y < 9).override_failure_message(
			"reached %s past the wall" % hex
		).is_true()


func test_cover_authored_on_a_cell_covers_its_hexes() -> void:
	var model := _model(Vector2i(12, 12), [], [Vector2i(6, 6)])
	var covered := _grid(model).cells_on_square(Vector2i(6, 6))
	# 4.6 on average; one cell holds 4 to 6 depending on where the lattice falls.
	assert_int(covered.size()).is_between(4, 6)
	for hex: Vector2i in covered:
		assert_bool(bool(model._cover.get(hex, false))).is_true()
	# A target hugging the cover against a shot from across it gets the bonus.
	var hero := _actor("hero")
	var foe := _actor("foe")
	var cover_hex: Vector2i = covered[0]
	var behind := cover_hex + HexMath.DIRECTIONS[0]
	while covered.has(behind):
		behind += HexMath.DIRECTIONS[0]
	_seat(model, {hero: cover_hex + HexMath.DIRECTIONS[3] * 6, foe: behind}, [hero], [foe])
	assert_int(model.cover_bonus(hero, foe)).is_greater(0)


func test_overlapping_party_seats_spread_to_free_hexes() -> void:
	var model := _model(Vector2i(10, 10))
	var anchor := _grid(model).cell_at_square(Vector2i(5, 5))
	var desired: Array[Vector2i] = [anchor, anchor, anchor, anchor, anchor]
	var placement := model.resolve_placement(desired)
	assert_bool(bool(placement.get("allowed", false))).is_true()
	var seats: Array = placement["cells"]
	var distinct := {}
	for seat: Vector2i in seats:
		distinct[seat] = true
		assert_bool(_grid(model).is_in_bounds(seat)).is_true()
		assert_int(HexMath.distance(seat, anchor)).is_less_equal(2)
	assert_int(distinct.size()).is_equal(5)
