extends GdUnitTestSuite
## F0 ruling 4 (2026-09-06): where the party stands when an ambient fight opens.
##
## The rule under test: every member keeps its own cell when that cell is free; only
## overlapping members move; the player is the anchor and never moves; a relocated member goes
## to the nearest *reachable* free cell, found breadth-first over passable cells rather than by
## radius, with ties inside one ring broken by row then column; and if any member cannot be
## seated inside `PLACEMENT_SEARCH_RADIUS` the whole query refuses without seating anyone.
##
## The determinism assertions below are deliberately exact rather than "some free cell". A
## placement that is merely valid is not enough — it has to be the same placement on a reload,
## which is what a save round trip and a replay both depend on.


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.move_ct_cost = 20
	return rules


func _actor(id: String) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = id
	actor.combat_id = StringName(id)
	actor.hp = 10
	actor.max_hp = 10
	return actor


## Bare passable ground, no authored content: this suite exercises the mechanism only.
func _ground(width: int, height: int) -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i(0, 0))
	tile_set.add_source(source, 0)
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	for y in height:
		for x in width:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	return layer


func _model(width: int, height: int) -> GridBattlefieldModel:
	var model := GridBattlefieldModel.new()
	model.configure(_rules())
	model.build_grid(_ground(width, height))
	return model


## The eight cells around (4, 4), so a test can seal the anchor and then reopen exactly the
## exits it wants to reason about.
func _seal_around(model: GridBattlefieldModel, centre: Vector2i, open: Array) -> void:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var cell := centre + Vector2i(dx, dy)
			if cell == centre or open.has(cell):
				continue
			model.set_cliff(cell, true)


func test_party_on_distinct_free_cells_keeps_every_authored_cell() -> void:
	var model := _model(8, 8)
	var result := model.resolve_placement(
		[Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)] as Array[Vector2i]
	)
	assert_bool(result["allowed"]).is_true()
	assert_array(result["cells"]).is_equal([Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)])


## Arrival and teleport reset both stack the companions on the player's cell — exactly what
## `test_party_followers.gd` locks in — so this is the ordinary ambient-entry case, not an edge.
func test_stacked_party_keeps_the_anchor_and_spreads_by_row_then_column() -> void:
	var model := _model(8, 8)
	var result := model.resolve_placement(
		[Vector2i(2, 2), Vector2i(2, 2), Vector2i(2, 2)] as Array[Vector2i]
	)
	assert_bool(result["allowed"]).is_true()
	var cells: Array = result["cells"]
	assert_that(cells[0]).is_equal(Vector2i(2, 2))
	assert_that(cells[1]).is_equal(Vector2i(1, 1))
	assert_that(cells[2]).is_equal(Vector2i(2, 1))


## The load-bearing half of the ruling. (4, 4) is sealed except for (5, 4), so everything the
## party can actually stand on lies east. A radius search would offer (4, 2) or (2, 4) first —
## they are nearer by distance and sort earlier by row — and both are on the far side of a wall.
func test_relocation_follows_reachability_not_distance() -> void:
	var model := _model(9, 9)
	_seal_around(model, Vector2i(4, 4), [Vector2i(5, 4)])
	var result := model.resolve_placement(
		[Vector2i(4, 4), Vector2i(4, 4), Vector2i(4, 4)] as Array[Vector2i]
	)
	assert_bool(result["allowed"]).is_true()
	var cells: Array = result["cells"]
	assert_that(cells[0]).is_equal(Vector2i(4, 4))
	assert_that(cells[1]).is_equal(Vector2i(5, 4))
	# Ring two is reached only through (5, 4); (6, 3) is its lowest row, then column.
	assert_that(cells[2]).is_equal(Vector2i(6, 3))


func test_pocket_with_no_room_refuses_without_seating_anyone() -> void:
	var model := _model(9, 9)
	_seal_around(model, Vector2i(4, 4), [])
	var result := model.resolve_placement(
		[Vector2i(4, 4), Vector2i(4, 4)] as Array[Vector2i]
	)
	assert_bool(result["allowed"]).is_false()
	assert_str(str(result["nearest_unblock"]["type"])).is_equal("cell_free")
	# Atomic: a refused query is a query, not a half-applied placement.
	assert_object(model.occupant_of(StringName("c:4,4,0"))).is_null()


func test_anchor_on_an_impassable_cell_refuses_the_whole_session() -> void:
	var model := _model(8, 8)
	model.set_cliff(Vector2i(4, 4), true)
	var result := model.resolve_placement(
		[Vector2i(4, 4), Vector2i(5, 4)] as Array[Vector2i]
	)
	assert_bool(result["allowed"]).is_false()
	assert_str(str(result["nearest_unblock"]["type"])).is_equal("anchor_placeable")


## A save records the party's cells, not the resolved seats, so the same field state has to
## resolve to the same seats every time it is asked.
func test_placement_is_identical_across_repeated_queries() -> void:
	var model := _model(9, 9)
	_seal_around(model, Vector2i(4, 4), [Vector2i(5, 4), Vector2i(4, 5)])
	var desired: Array[Vector2i] = [Vector2i(4, 4), Vector2i(4, 4), Vector2i(4, 4)]
	var first := model.resolve_placement(desired)
	var second := model.resolve_placement(desired)
	assert_bool(first["allowed"]).is_true()
	assert_array(second["cells"]).is_equal(first["cells"])


## Hostile occupancy is authored by the scene, and the ruling preserves it: a companion is
## never seated on a cell something already holds.
func test_existing_occupancy_is_never_handed_to_a_companion() -> void:
	var model := _model(8, 8)
	var foe := _actor("foe")
	var seated := model.configure_initial_cells({foe: Vector2i(1, 1)})
	assert_bool(seated["allowed"]).is_true()
	model.setup([] as Array[BattleActor], [foe] as Array[BattleActor])
	assert_str(str(model.position_of(foe))).is_equal("c:1,1,0")

	var result := model.resolve_placement(
		[Vector2i(2, 2), Vector2i(2, 2)] as Array[Vector2i]
	)
	assert_bool(result["allowed"]).is_true()
	var cells: Array = result["cells"]
	assert_that(cells[0]).is_equal(Vector2i(2, 2))
	# (1, 1) would have been the row-then-column winner; the foe holds it, so (2, 1) wins.
	assert_that(cells[1]).is_equal(Vector2i(2, 1))
