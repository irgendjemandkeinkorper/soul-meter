extends GdUnitTestSuite
## E3.2 (#340): `paint_cells` on the scene bus — one stroke, one command, one undo step — with
## `IsoGrid.build()` re-run after every stroke, undo and redo (architecture §4.6.3).

const GROUND_TILES := preload("res://assets/generated/sprites/ground/ground_tileset.tres")
const BLOCKING_TILES := preload("res://world/nav/blocking_tiles.tres")
const ORIGIN := Vector2(100, 50)
const BLOCKED: Array = [0, 0, 0, 0]

var world: Node2D
var ground: TileMapLayer
var blocking: TileMapLayer
var terrain: CombatTerrainLayer
var model: WeftluminSceneModel
var painter: WeftluminTilePainter
var player_grid: IsoGrid
var placement_grid: IsoGrid


func before_test() -> void:
	world = Node2D.new()
	world.name = "PainterFixture"
	world.scene_file_path = "res://world/painter_fixture.tscn"
	ground = _layer("IsometricGround", GROUND_TILES, ORIGIN)
	for y: int in 12:
		for x: int in 12:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	blocking = _layer("Blocking", BLOCKING_TILES, ORIGIN)
	terrain = CombatTerrainLayer.new()
	terrain.name = "Terrain"
	world.add_child(terrain)
	terrain.owner = world
	add_child(world)
	model = WeftluminSceneModel.new()
	model.configure(world)
	painter = WeftluminTilePainter.new()
	painter.attach(model)
	painter.add_layer(&"Blocking", blocking, blocking, {"kind": WeftluminTilePainter.STORE_TILES}, [
		{"label": "Blocked", "tile": BLOCKED}, {"label": "Erase", "tile": []},
	], ground)
	painter.add_layer(&"Terrain", terrain, ground, {
		"kind": WeftluminTilePainter.STORE_LISTS, "source": 0,
		"lists": {"1,0": "cover_cells", "2,0": "elevation_one_cells", "3,0": "elevation_two_cells"},
	}, [{"label": "Cover", "tile": [0, 1, 0, 0]}, {"label": "Elevation 1", "tile": [0, 2, 0, 0]}], ground)
	player_grid = IsoGrid.new()
	player_grid.build(ground, blocking, 1, true)
	placement_grid = IsoGrid.new()
	placement_grid.build(ground, blocking, 0, true)
	painter.add_grid(player_grid, ground, blocking, 1, true, "player path, clearance 1 cell")
	painter.add_grid(placement_grid, ground, blocking, 0, true, "placement, clearance 0 cells")


func after_test() -> void:
	model.dispose()
	world.free()


func test_one_stroke_is_one_command_and_one_undo_step_that_rebuilds_walkability() -> void:
	var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5)]
	assert_bool(placement_grid.is_blocked_for(Vector2i(5, 5))).is_false()
	var outcome: Dictionary = painter.paint(&"Blocking", cells, BLOCKED)
	assert_bool(outcome["allowed"]).is_true()
	assert_int(model.bus.log_entries().size()).is_equal(1)
	var entry: Dictionary = model.bus.log_entries()[0]
	assert_str(entry["op"]).is_equal("paint_cells")
	assert_str(entry["target"]["node"]).is_equal("Blocking")
	# pre_state is the bus's own capture: both cells were empty, and the layer's transform.
	assert_array(entry["pre_state"]["cells"]).is_equal([[5, 5], [6, 5]])
	assert_array(entry["pre_state"]["transform"]).is_equal([ORIGIN.x, ORIGIN.y, 1.0, 1.0])
	assert_int(painter.rebuild_count).is_equal(1)
	# Placement uses the raw painted cells; the player's path dilates them by one cell.
	assert_bool(placement_grid.is_blocked_for(Vector2i(5, 5))).is_true()
	assert_bool(placement_grid.is_blocked_for(Vector2i(4, 5))).is_false()
	assert_bool(player_grid.is_blocked_for(Vector2i(4, 5))).is_true()
	assert_bool(model.undo()["allowed"]).is_true()
	assert_int(painter.rebuild_count).is_equal(2)
	assert_int(blocking.get_cell_source_id(Vector2i(5, 5))).is_equal(-1)
	assert_bool(placement_grid.is_blocked_for(Vector2i(5, 5))).is_false()
	assert_bool(player_grid.is_blocked_for(Vector2i(4, 5))).is_false()
	assert_bool(model.undo()["allowed"]).is_false()
	assert_bool(model.redo()["allowed"]).is_true()
	assert_int(painter.rebuild_count).is_equal(3)
	assert_bool(placement_grid.is_blocked_for(Vector2i(6, 5))).is_true()


func test_cell_brush_drag_is_a_gap_free_single_stroke() -> void:
	painter.press(_world(Vector2i(2, 2)))
	painter.drag(_world(Vector2i(6, 2)))
	painter.drag(_world(Vector2i(6, 5)))
	assert_bool(painter.stroke_active()).is_true()
	assert_int(model.bus.log_entries().size()).is_equal(0)
	assert_bool(painter.release()["allowed"]).is_true()
	assert_int(model.bus.log_entries().size()).is_equal(1)
	for x: int in range(2, 7):
		assert_int(blocking.get_cell_source_id(Vector2i(x, 2))).is_equal(0)
	for y: int in range(2, 6):
		assert_int(blocking.get_cell_source_id(Vector2i(6, y))).is_equal(0)
	assert_int(blocking.get_used_cells().size()).is_equal(8)
	assert_int(painter.rebuild_count).is_equal(1)


func test_rect_line_and_fill_brushes_paint_in_the_layer_cell_space() -> void:
	painter.shape = WeftluminBrushes.Shape.RECT
	painter.press(_world(Vector2i(1, 1)))
	painter.drag(_world(Vector2i(3, 2)))
	assert_int(painter.preview_cells().size()).is_equal(6)
	painter.release()
	assert_int(blocking.get_used_cells().size()).is_equal(6)
	painter.shape = WeftluminBrushes.Shape.LINE
	painter.press(_world(Vector2i(0, 8)))
	painter.drag(_world(Vector2i(4, 8)))
	painter.release()
	assert_int(blocking.get_used_cells().size()).is_equal(11)
	# Erase with a fill: the connected blocked region from (1, 1) is the rectangle only.
	painter.shape = WeftluminBrushes.Shape.FILL
	painter.tile = []
	assert_bool(painter.press(_world(Vector2i(2, 1)))["allowed"]).is_true()
	assert_int(blocking.get_used_cells().size()).is_equal(5)
	assert_int(model.bus.log_entries().size()).is_equal(3)


func test_a_scaled_blocking_layer_is_painted_in_its_own_cells() -> void:
	blocking.scale = Vector2(2, 2)
	var world_position: Vector2 = blocking.to_global(blocking.map_to_local(Vector2i(2, 3)))
	assert_object(painter.cell_at(world_position, &"Blocking")).is_equal(Vector2i(2, 3))
	painter.press(world_position)
	painter.release()
	assert_int(blocking.get_cell_source_id(Vector2i(2, 3))).is_equal(0)
	var entry: Dictionary = model.bus.log_entries()[0]
	assert_array(entry["pre_state"]["transform"]).is_equal([ORIGIN.x, ORIGIN.y, 2.0, 2.0])


func test_a_stroke_that_changes_nothing_writes_no_command() -> void:
	painter.paint(&"Blocking", [Vector2i(3, 3)] as Array[Vector2i], BLOCKED)
	var outcome: Dictionary = painter.paint(&"Blocking", [Vector2i(3, 3)] as Array[Vector2i], BLOCKED)
	assert_bool(outcome["allowed"]).is_true()
	assert_int(model.bus.log_entries().size()).is_equal(1)
	assert_int(painter.rebuild_count).is_equal(1)


func test_terrain_paints_in_ground_cells_and_keeps_its_authored_lists_in_step() -> void:
	# #281 step 2: GridBattlefieldModel reads Terrain cells as ground cells.
	var cell := Vector2i(4, 7)
	assert_object(painter.cell_at(ground.to_global(ground.map_to_local(cell)), &"Terrain")).is_equal(cell)
	painter.paint(&"Terrain", [cell] as Array[Vector2i], [0, 1, 0, 0])
	assert_array(terrain.cover_cells).contains_exactly([cell])
	painter.paint(&"Terrain", [cell] as Array[Vector2i], [0, 2, 0, 0])
	assert_array(terrain.cover_cells).is_empty()
	assert_array(terrain.elevation_one_cells).contains_exactly([cell])
	var battlefield := GridBattlefieldModel.new()
	battlefield.build_grid(ground, blocking)
	assert_int(battlefield.elevation_at(cell)).is_equal(1)
	assert_bool(model.undo()["allowed"]).is_true()
	assert_array(terrain.cover_cells).contains_exactly([cell])
	assert_array(terrain.elevation_one_cells).is_empty()
	assert_object(terrain.get_cell_atlas_coords(cell)).is_equal(CombatTerrainLayer.COVER_TILE)


func test_the_painter_registers_paint_cells_but_never_the_bake_only_normalize() -> void:
	assert_bool(model.bus.has_handler("scene", "paint_cells")).is_true()
	assert_bool(model.bus.has_handler("scene", WeftluminTileBake.OP_NORMALIZE)).is_false()


func test_session_painter_survives_on_the_scene_root_for_its_undo_history() -> void:
	var first: WeftluminTilePainter = WeftluminTilePainter.session_for(model)
	assert_object(WeftluminTilePainter.session_for(model)).is_same(first)
	world.remove_meta(WeftluminTilePainter.SESSION_META)


func _layer(layer_name: String, tile_set: TileSet, at: Vector2) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.position = at
	world.add_child(layer)
	layer.owner = world
	return layer


func _world(cell: Vector2i) -> Vector2:
	return blocking.to_global(blocking.map_to_local(cell))


func test_painting_refuses_while_production_owns_the_grid() -> void:
	painter.production_live = func() -> bool: return true
	var outcome: Dictionary = painter.paint(&"Blocking", [Vector2i(2, 2)] as Array[Vector2i], BLOCKED)
	assert_bool(outcome["allowed"]).is_false()
	assert_str(String(outcome["blocked_by"])).is_equal("production_owner")
	assert_int(blocking.get_cell_source_id(Vector2i(2, 2))).is_equal(-1)
	assert_int(painter.rebuild_count).is_equal(0)
