extends "res://test/helpers/scene_pick_fixture.gd"
## E3.2 (#340): Blocking / Terrain painters through the real shell GUI, a fresh synthetic event
## for each button edge. The live grid is the `ClickMoveController`'s own `IsoGrid` (reached
## through `FieldMap.iso_grid()`), so a painted stroke must change where the player can walk.

const GROUND_TILES := preload("res://assets/generated/sprites/ground/ground_tileset.tres")
const BLOCKING_TILES := preload("res://world/nav/blocking_tiles.tres")
const LATTICE := Vector2i(16, 16)
const PLAYER_CAPTION := "Walkability: player path, clearance 1 cell"
const PLACEMENT_CAPTION := "Walkability: placement, clearance 0 cells"

var ground: TileMapLayer
var blocking: TileMapLayer
var terrain: CombatTerrainLayer
var controller: ClickMoveController
var tools: WeftluminPaintTools


func before_test() -> void:
	await super.before_test()
	ground = _layer("IsometricGround", GROUND_TILES)
	for y: int in LATTICE.y:
		for x: int in LATTICE.x:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	# Centre the lattice on the viewport.
	ground.position = solid.global_position - ground.map_to_local(LATTICE / 2)
	blocking = _layer("Blocking", BLOCKING_TILES)
	blocking.position = ground.position
	terrain = CombatTerrainLayer.new()
	terrain.name = "Terrain"
	terrain.visible = false
	world.add_child(terrain)
	terrain.owner = world
	var field := FieldMap.new()
	field.name = "FieldMap"
	world.add_child(field)
	var player := Node2D.new()
	player.name = "Player"
	player.position = ground.to_global(ground.map_to_local(Vector2i(1, 1)))
	world.add_child(player)
	controller = ClickMoveController.new()
	controller.name = "ClickMoveController"
	player.add_child(controller)
	# The scene panel re-reads the field when its scene changes; this fixture grew one in place.
	model.grid = WeftluminScenePanel._grid_for(world)
	panel._attach_painter(world)
	tools = panel.paint_tools
	panel._rebuild()


func test_painted_blocking_changes_click_to_move_walkability_live() -> void:
	var grid: IsoGrid = controller.get_iso_grid()
	assert_object(model.grid).is_same(grid)
	var selected: Array[Node2D] = model.selection()
	tools.set_painting(true)
	tools.select_layer(&"Blocking")
	tools.select_value("Blocked")
	tools.select_brush(WeftluminBrushes.Shape.LINE)
	var from := Vector2i(3, 8)
	var to := Vector2i(12, 8)
	assert_bool(grid.is_blocked_for(Vector2i(8, 8))).is_false()
	_stroke(from, to)
	for x: int in range(3, 13):
		assert_int(blocking.get_cell_source_id(Vector2i(x, 8))).is_equal(0)
	assert_int(blocking.get_used_cells().size()).is_equal(10)
	assert_int(model.bus.log_entries().size()).is_equal(1)
	assert_int(tools.painter.rebuild_count).is_equal(1)
	# The player's own grid: the wall and, at clearance 1, the cells beside it.
	assert_bool(grid.is_blocked_for(Vector2i(8, 8))).is_true()
	assert_bool(grid.is_blocked_for(Vector2i(8, 7))).is_true()
	assert_bool(grid.is_blocked_for(Vector2i(8, 5))).is_false()
	var path: PackedVector2Array = grid.path_cells(Vector2i(8, 5), Vector2i(8, 11))
	assert_int(path.size()).is_greater(7)
	for cell: Vector2 in path:
		assert_bool(grid.is_blocked_for(Vector2i(cell))).is_false()
	# Painting is not picking.
	assert_array(model.selection()).is_equal(selected)
	key(KEY_Z, true)
	assert_int(blocking.get_used_cells().size()).is_equal(0)
	assert_bool(grid.is_blocked_for(Vector2i(8, 8))).is_false()
	assert_int(tools.painter.rebuild_count).is_equal(2)
	key(KEY_Z, true, true)
	assert_bool(grid.is_blocked_for(Vector2i(8, 8))).is_true()


func test_overlay_states_the_clearance_it_shows() -> void:
	assert_str(tools.overlay_caption()).is_empty()
	tools.set_painting(true)
	assert_str(tools.overlay_caption()).is_equal(PLAYER_CAPTION)
	assert_str(tools.caption.text).is_equal(PLAYER_CAPTION)
	tools.select_overlay(2)
	assert_str(tools.overlay_caption()).is_equal(PLACEMENT_CAPTION)
	assert_str(tools.caption.text).is_equal(PLACEMENT_CAPTION)
	# The two grids disagree beside a painted cell, which is why the caption matters.
	tools.select_layer(&"Blocking")
	_stroke(Vector2i(8, 8), Vector2i(8, 8))
	var grids: Array[Dictionary] = tools.painter.grids()
	assert_bool((grids[0]["grid"] as IsoGrid).is_blocked_for(Vector2i(9, 8))).is_true()
	assert_bool((grids[1]["grid"] as IsoGrid).is_blocked_for(Vector2i(9, 8))).is_false()
	tools.select_overlay(0)
	assert_str(tools.caption.text).is_empty()
	assert_bool(tools.caption.visible).is_false()


func test_terrain_paints_cover_in_ground_cells_through_the_viewport() -> void:
	tools.set_painting(true)
	tools.select_layer(&"Terrain")
	tools.select_value("Cover")
	tools.select_brush(WeftluminBrushes.Shape.RECT)
	_stroke(Vector2i(5, 5), Vector2i(6, 6))
	assert_array(terrain.cover_cells).contains_exactly_in_any_order(
		[Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6), Vector2i(6, 6)]
	)
	var battlefield := GridBattlefieldModel.new()
	battlefield.build_grid(ground, blocking)
	assert_int(battlefield.tiles_snapshot().filter(func(row: Dictionary) -> bool: return bool(row.get("cover", false))).size()).is_equal(4)


func test_a_stroke_released_over_the_dock_still_commits_once() -> void:
	tools.set_painting(true)
	tools.select_brush(WeftluminBrushes.Shape.CELL)
	edge(_screen(Vector2i(4, 4)), true)
	motion(_screen(Vector2i(4, 6)), true)
	var dock: Vector2 = panel.tree.get_global_rect().get_center()
	motion(dock, true)
	edge(dock, false)
	assert_int(model.bus.log_entries().size()).is_equal(1)
	assert_bool(tools.painter.stroke_active()).is_false()
	for y: int in range(4, 7):
		assert_int(blocking.get_cell_source_id(Vector2i(4, y))).is_equal(0)


func test_paint_off_leaves_pick_and_drag_to_the_scene_model() -> void:
	tools.set_painting(false)
	model.clear_selection()
	click(screen_at(solid.global_position))
	assert_object(model.primary()).is_same(solid)
	assert_int(blocking.get_used_cells().size()).is_equal(0)


func test_rendered_painted_stroke_with_walkability_overlay_capture() -> void:
	var directory := OS.get_environment("SOUL_METER_PAINTER_CAPTURE_DIR")
	if directory.is_empty():
		return
	assert_str(DisplayServer.get_name()).is_not_equal("headless")
	if DisplayServer.get_name() == "headless":
		return
	assert_int(DirAccess.make_dir_recursive_absolute(directory)).is_equal(OK)
	model.clear_selection()
	tools.set_painting(true)
	tools.select_layer(&"Blocking")
	tools.select_brush(WeftluminBrushes.Shape.LINE)
	edge(_screen(Vector2i(3, 6)), true)
	motion(_screen(Vector2i(12, 9)), true)
	# Mid-stroke: the preview shows, nothing is painted yet.
	assert_int(blocking.get_used_cells().size()).is_equal(0)
	await _capture(directory.path_join("01-stroke-preview.png"), [], [Vector2i(7, 7)])
	edge(_screen(Vector2i(12, 9)), false)
	assert_int(blocking.get_used_cells().size()).is_greater(0)
	# (7, 7) is painted; (8, 7) is only blocked by the player's one-cell clearance.
	await _capture(directory.path_join("02-painted-player-path.png"), [Vector2i(7, 7), Vector2i(8, 7)], [Vector2i(1, 1)])
	tools.select_overlay(2)
	await _capture(directory.path_join("03-painted-placement.png"), [Vector2i(7, 7)], [Vector2i(8, 7)])


## Render, check which cell centres carry the blocked fill, then save at half size.
func _capture(path: String, blocked: Array[Vector2i], open: Array[Vector2i]) -> void:
	panel._redraw()
	await get_tree().process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	for cell: Vector2i in blocked + open:
		var pixel: Color = image.get_pixelv(Vector2i(_screen(cell)))
		var red: bool = pixel.r > pixel.g + 0.08 and pixel.r > pixel.b + 0.08
		assert_bool(red).override_failure_message(
			"%s: cell %s shows %s" % [path.get_file(), cell, pixel]
		).is_equal(blocked.has(cell))
	image.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	assert_int(image.save_png(path)).is_equal(OK)


func _stroke(from: Vector2i, to: Vector2i) -> void:
	edge(_screen(from), true)
	motion(_screen(to), true)
	edge(_screen(to), false)


## A Blocking cell centre in screen space (Blocking shares the ground's lattice here).
func _screen(cell: Vector2i) -> Vector2:
	return screen_at(blocking.to_global(blocking.map_to_local(cell)))


func _layer(layer_name: String, tile_set: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	world.add_child(layer)
	layer.owner = world
	return layer
