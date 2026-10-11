extends GdUnitTestSuite
## E3.2 (#340): painted layers bake into `.tscn` text through `TscnDocument.set_packed_bytes()`
## (Blocking) and `set_property()` (Terrain's #281 cell lists), and `normalize_blocking_scale` is
## a bake-only op whose result navigates exactly like the scaled layer it replaces.

const GROUND_TILES := preload("res://assets/generated/sprites/ground/ground_tileset.tres")
const BLOCKING_TILES := preload("res://world/nav/blocking_tiles.tres")
const FIXTURE_DIR := "user://weftlumin_bake_fixture"
const ORIGIN := Vector2(64, 32)
const BLOCKED: Array = [0, 0, 0, 0]
const TERRAIN_STORE := {
	"kind": "lists", "source": 0,
	"lists": {"1,0": "cover_cells", "2,0": "elevation_one_cells", "3,0": "elevation_two_cells"},
}

var _live: Array[Node] = []


func after_test() -> void:
	for node: Node in _live:
		if is_instance_valid(node):
			node.free()
	_live.clear()
	for file: String in DirAccess.get_files_at(FIXTURE_DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_DIR.path_join(file)))


func test_painted_layers_bake_back_into_the_scene_text_and_round_trip() -> void:
	var path: String = _write_fixture("roundtrip", Vector2.ONE)
	var text: String = FileAccess.get_file_as_string(path)
	var live: Node2D = _instantiate(path)
	var session: Array = _painter(live)
	var model: WeftluminSceneModel = session[0]
	var painter: WeftluminTilePainter = session[1]
	painter.paint(&"Blocking", [Vector2i(5, 5), Vector2i(5, 6)] as Array[Vector2i], BLOCKED)
	painter.paint(&"Blocking", [Vector2i(2, 2)] as Array[Vector2i], [])
	painter.paint(&"Terrain", [Vector2i(4, 4)] as Array[Vector2i], [0, 1, 0, 0])
	painter.paint(&"Terrain", [Vector2i(1, 1)] as Array[Vector2i], [0, 2, 0, 0])
	var baked: Dictionary = WeftluminTileBake.bake(text, model.bus.log_entries(), path)
	assert_bool(baked["allowed"]).override_failure_message(str(baked.get("message", ""))).is_true()
	assert_array(baked["applied"]).has_size(4)
	var baked_text: String = baked["text"]
	# set_packed_bytes keeps the file's encoding style.
	assert_bool(text.contains('PackedByteArray("')).is_true()
	assert_bool(baked_text.contains('PackedByteArray("')).is_true()
	# Only the painted properties changed; every other line is byte-identical and in order.
	var painted_keys: Array[String] = ["tile_map_data", "cover_cells", "elevation_one_cells"]
	assert_array(_unpainted_lines(baked_text, painted_keys)).is_equal(_unpainted_lines(text, painted_keys))
	var reloaded: Node2D = _instantiate(_write_text("roundtrip_baked", baked_text))
	var live_blocking := live.get_node("Blocking") as TileMapLayer
	var baked_blocking := reloaded.get_node("Blocking") as TileMapLayer
	assert_array(_sorted(baked_blocking.get_used_cells())).is_equal(_sorted(live_blocking.get_used_cells()))
	assert_array(_sorted(baked_blocking.get_used_cells())).is_equal([Vector2i(3, 2), Vector2i(4, 5), Vector2i(5, 5), Vector2i(5, 6)])
	var live_terrain := live.get_node("Terrain") as CombatTerrainLayer
	var baked_terrain := reloaded.get_node("Terrain") as CombatTerrainLayer
	assert_array(baked_terrain.cover_cells).is_equal(live_terrain.cover_cells)
	assert_array(baked_terrain.cover_cells).contains_exactly([Vector2i(4, 4)])
	assert_array(baked_terrain.elevation_one_cells).contains_exactly([Vector2i(1, 1)])
	model.dispose()


func test_bake_applies_the_effective_stream_so_undone_strokes_stay_out() -> void:
	var path: String = _write_fixture("undo", Vector2.ONE)
	var live: Node2D = _instantiate(path)
	var session: Array = _painter(live)
	var model: WeftluminSceneModel = session[0]
	var painter: WeftluminTilePainter = session[1]
	painter.paint(&"Blocking", [Vector2i(7, 7)] as Array[Vector2i], BLOCKED)
	painter.paint(&"Blocking", [Vector2i(8, 8)] as Array[Vector2i], BLOCKED)
	model.undo()
	var entries: Array[Dictionary] = model.bus.log_entries()
	# A layout edit in the same log is not a tile op; the tile bake leaves it to its own baker.
	entries.append(WeftluminCommand.make("scene", "set_property", {"node": "Blocking"}, {"key": "position", "value": [0, 0]}).to_dict())
	var baked: Dictionary = WeftluminTileBake.bake(FileAccess.get_file_as_string(path), entries, path)
	assert_bool(baked["allowed"]).is_true()
	assert_int(baked["skipped_ops"]).is_equal(1)
	var reloaded: Node2D = _instantiate(_write_text("undo_baked", baked["text"]))
	var cells: Array[Vector2i] = (reloaded.get_node("Blocking") as TileMapLayer).get_used_cells()
	assert_bool(cells.has(Vector2i(7, 7))).is_true()
	assert_bool(cells.has(Vector2i(8, 8))).is_false()
	model.dispose()


func test_bake_refuses_a_log_recorded_against_a_differently_scaled_layer() -> void:
	var path: String = _write_fixture("drift", Vector2.ONE)
	var live: Node2D = _instantiate(path)
	var session: Array = _painter(live)
	var model: WeftluminSceneModel = session[0]
	(session[1] as WeftluminTilePainter).paint(&"Blocking", [Vector2i(6, 6)] as Array[Vector2i], BLOCKED)
	var scaled_text: String = FileAccess.get_file_as_string(_write_fixture("drift_scaled", Vector2(2.2, 2.2)))
	var baked: Dictionary = WeftluminTileBake.bake(scaled_text, model.bus.log_entries())
	assert_bool(baked["allowed"]).is_false()
	assert_str(String(baked["blocked_by"])).is_equal("pre_state_drift")
	assert_str(baked["text"]).is_equal(scaled_text)
	model.dispose()


func test_normalize_blocking_scale_is_bake_only_and_preserves_walkability() -> void:
	var path: String = _write_fixture("normalize", Vector2(2.2, 2.2))
	var text: String = FileAccess.get_file_as_string(path)
	var baker := WeftluminTileBake.open(text, path)
	var outcome: Dictionary = baker.execute(
		WeftluminTileBake.normalize_command(path, "Blocking", "IsometricGround", GROUND_TILES.resource_path)
	)
	assert_bool(outcome["allowed"]).override_failure_message(str(outcome.get("message", ""))).is_true()
	assert_bool(baker.flush()["allowed"]).is_true()
	var normalised: String = baker.text()
	var report: Dictionary = baker.reports[0]
	baker.close()
	assert_int(report["cells_after"]).is_greater(report["cells_before"])
	assert_bool(normalised.contains("scale = Vector2(1, 1)")).is_true()
	assert_bool(normalised.contains("scale = Vector2(2.2, 2.2)")).is_false()
	var before: Node2D = _instantiate(path)
	var after: Node2D = _instantiate(_write_text("normalize_baked", normalised))
	var normalised_blocking := after.get_node("Blocking") as TileMapLayer
	assert_bool(normalised_blocking.global_transform.is_equal_approx(
		(after.get_node("IsometricGround") as Node2D).global_transform
	)).is_true()
	for clearance: int in [0, 1]:
		_assert_same_walkability(
			before.get_node("IsometricGround"), before.get_node("Blocking"),
			after.get_node("IsometricGround"), normalised_blocking, clearance,
		)


func test_normalize_dry_run_on_dom_preserves_walkability_without_writing() -> void:
	# Ruling 9: Dom's Blocking is NOT re-authored here. This only proves the reviewed one-shot
	# would navigate identically; the committed scene stays byte-identical.
	var dom_path := "res://world/starting_town.tscn"
	var original: String = FileAccess.get_file_as_string(dom_path)
	var baker := WeftluminTileBake.open(original, dom_path)
	var outcome: Dictionary = baker.execute(
		WeftluminTileBake.normalize_command(dom_path, "Blocking", "IsometricGround", GROUND_TILES.resource_path)
	)
	assert_bool(outcome["allowed"]).override_failure_message(str(outcome.get("message", ""))).is_true()
	assert_bool(baker.flush()["allowed"]).is_true()
	var normalised := WeftluminTileBake.open(baker.text())
	var report: Dictionary = baker.reports[0]
	assert_int(report["cells_before"]).is_equal(221)
	var ground_node: Dictionary = baker._node("IsometricGround")
	var ground: IsometricBlockout = auto_free(IsometricBlockout.new())
	ground.position = WeftluminTileBake._vector(ground_node, "position", Vector2.ZERO)
	ground.map_size = WeftluminTileBake._value(ground_node, "map_size")
	add_child(ground)
	var old_blocking := _decoded(WeftluminTileBake.open(original)._node("Blocking"))
	var new_blocking := _decoded(normalised._node("Blocking"))
	assert_vector(new_blocking.scale).is_equal(Vector2.ONE)
	assert_vector(old_blocking.scale).is_equal_approx(Vector2(2.2, 2.2), Vector2(0.0001, 0.0001))
	_assert_same_walkability(ground, old_blocking, ground, new_blocking, 0)
	# The re-authored footprint keeps Dom's few wall cells that lie just past the ground lattice
	# (they still collide). The scaled layer's projection never saw them; at the player's
	# clearance they dilate into the lattice's edge row. That — and only that — may differ.
	_assert_same_walkability(ground, old_blocking, ground, new_blocking, 1, true)
	baker.close()
	normalised.close()
	assert_str(FileAccess.get_file_as_string(dom_path)).is_equal(original)


func _assert_same_walkability(
	ground_a: TileMapLayer, blocking_a: TileMapLayer, ground_b: TileMapLayer, blocking_b: TileMapLayer,
	clearance: int, allow_edge_dilation: bool = false,
) -> void:
	var grid_a := IsoGrid.new()
	grid_a.build(ground_a, blocking_a, clearance, true)
	var grid_b := IsoGrid.new()
	grid_b.build(ground_b, blocking_b, clearance, true)
	var region: Rect2i = grid_a.get_used_rect()
	assert_object(grid_b.get_used_rect()).is_equal(region)
	var blocked := 0
	var mismatched: Array[Vector2i] = []
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var cell := Vector2i(x, y)
			if grid_a.is_blocked_for(cell):
				blocked += 1
			if grid_a.is_blocked_for(cell) != grid_b.is_blocked_for(cell):
				if allow_edge_dilation and _edge_dilation(cell, region, blocking_b, clearance) and grid_b.is_blocked_for(cell):
					continue
				mismatched.append(cell)
	assert_int(blocked).is_greater(0)
	assert_array(mismatched).override_failure_message(
		"clearance %d: walkability differs at %s" % [clearance, mismatched]
	).is_empty()


## `cell` is on the lattice edge and within `clearance` of a blocking cell outside the lattice.
static func _edge_dilation(cell: Vector2i, region: Rect2i, blocking: TileMapLayer, clearance: int) -> bool:
	if region.grow(-clearance).has_point(cell):
		return false
	for dy: int in range(-clearance, clearance + 1):
		for dx: int in range(-clearance, clearance + 1):
			var near: Vector2i = cell + Vector2i(dx, dy)
			if not region.has_point(near) and blocking.get_cell_source_id(near) != -1:
				return true
	return false


func _decoded(node: Dictionary) -> TileMapLayer:
	var layer: TileMapLayer = auto_free(TileMapLayer.new())
	layer.tile_set = BLOCKING_TILES
	layer.position = WeftluminTileBake._vector(node, "position", Vector2.ZERO)
	layer.scale = WeftluminTileBake._vector(node, "scale", Vector2.ONE)
	layer.tile_map_data = WeftluminTileBake._value(node, "tile_map_data")
	add_child(layer)
	return layer


func _write_fixture(fixture_name: String, blocking_scale: Vector2) -> String:
	var root := Node2D.new()
	root.name = "BakeFixture"
	var ground := _layer(root, "IsometricGround", GROUND_TILES, ORIGIN, Vector2.ONE)
	for y: int in 30:
		for x: int in 30:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var blocking := _layer(root, "Blocking", BLOCKING_TILES, ORIGIN, blocking_scale)
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 5)]:
		blocking.set_cell(cell, 0, Vector2i.ZERO)
	var terrain := CombatTerrainLayer.new()
	terrain.name = "Terrain"
	terrain.visible = false
	terrain.cover_cells = [Vector2i(1, 1)] as Array[Vector2i]
	root.add_child(terrain)
	terrain.owner = root
	var packed := PackedScene.new()
	assert_int(packed.pack(root)).is_equal(OK)
	root.free()
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR)
	var path: String = FIXTURE_DIR.path_join("%s.tscn" % fixture_name)
	assert_int(ResourceSaver.save(packed, path)).is_equal(OK)
	return path


func _write_text(fixture_name: String, text: String) -> String:
	var path: String = FIXTURE_DIR.path_join("%s.tscn" % fixture_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


func _instantiate(path: String) -> Node2D:
	var packed := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var root := packed.instantiate() as Node2D
	add_child(root)
	_live.append(root)
	return root


func _painter(root: Node2D) -> Array:
	var model := WeftluminSceneModel.new()
	model.configure(root)
	var painter := WeftluminTilePainter.new()
	painter.attach(model)
	var ground := root.get_node("IsometricGround") as TileMapLayer
	var blocking := root.get_node("Blocking") as TileMapLayer
	painter.add_layer(&"Blocking", blocking, blocking, {"kind": "tiles"}, [{"label": "Blocked", "tile": BLOCKED}], ground)
	painter.add_layer(&"Terrain", root.get_node("Terrain") as TileMapLayer, ground, TERRAIN_STORE, [{"label": "Cover", "tile": [0, 1, 0, 0]}], ground)
	return [model, painter]


func _layer(root: Node2D, layer_name: String, tile_set: TileSet, at: Vector2, layer_scale: Vector2) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.position = at
	layer.scale = layer_scale
	root.add_child(layer)
	layer.owner = root
	return layer


static func _unpainted_lines(text: String, keys: Array[String]) -> Array[String]:
	var lines: Array[String] = []
	for line: String in text.split("\n"):
		var painted := false
		for key: String in keys:
			if line.begins_with(key + " = "):
				painted = true
		if not painted:
			lines.append(line)
	return lines


static func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var copy: Array[Vector2i] = cells.duplicate()
	copy.sort()
	return copy
