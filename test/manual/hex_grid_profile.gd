extends GdUnitTestSuite
## Hex grid H1 profile (owner item 34; docs/design/hex-grid-plan-2026-11-03.md): on Kesselford,
## the largest map (105 x 105 cells, about 51,000 hexes), how long the hex graph takes to build
## and how long a path query takes, next to the square grid. Measurement only, so it lives in
## test/manual and never gates CI on timing. Run:
##   scripts/test.sh -a test/manual/hex_grid_profile.gd
## The D9 budget it is read against: an enemy AI decision <= 2 ms averaged over a round.

const MAP := "res://world/kesselford.tscn"
const QUERIES := 200

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)


func after_test() -> void:
	GameState.from_dict(_saved_state)


func test_hex_paths_on_kesselford() -> void:
	var scene := (load(MAP) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var ground := scene.find_child("IsometricGround", true, false) as TileMapLayer
	var blocking := scene.find_child("Blocking", true, false) as TileMapLayer
	var report := {}
	for hex_mode: bool in [false, true]:
		var grid := IsoGrid.new()
		grid.hex_mode = hex_mode
		var started := Time.get_ticks_usec()
		grid.build(ground, blocking, ClickMoveController.STATIC_CLEARANCE_CELLS, true)
		var build_ms := (Time.get_ticks_usec() - started) / 1000.0
		# The same deterministic pairs of world points for both grids: centres of painted cells.
		var cells: Array[Vector2i] = ground.get_used_cells()
		var rng := RandomNumberGenerator.new()
		rng.seed = 282
		var points: Array[Vector2] = []
		for _i in QUERIES * 2:
			var cell := cells[rng.randi_range(0, cells.size() - 1)]
			points.append(ground.to_global(ground.map_to_local(cell)))
		# The first query builds the hex graph (lazily); time it on its own, corner to corner.
		var rect := ground.get_used_rect()
		var far_a := ground.to_global(ground.map_to_local(rect.position + Vector2i(2, 2)))
		var far_b := ground.to_global(ground.map_to_local(rect.end - Vector2i(3, 3)))
		started = Time.get_ticks_usec()
		var corner_path := grid.path_cells(grid.world_to_cell(far_a), grid.world_to_cell(far_b))
		var first_ms := (Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		grid.path_cells(grid.world_to_cell(far_a), grid.world_to_cell(far_b))
		var corner_ms := (Time.get_ticks_usec() - started) / 1000.0
		var found := 0
		var steps := 0
		started = Time.get_ticks_usec()
		for i in QUERIES:
			var path := grid.path_cells(grid.world_to_cell(points[i * 2]), grid.world_to_cell(points[i * 2 + 1]))
			if not path.is_empty():
				found += 1
				steps += path.size()
		var per_query_ms := (Time.get_ticks_usec() - started) / 1000.0 / QUERIES
		var label := "hex" if hex_mode else "square"
		report[label] = per_query_ms
		print("PROFILE %s build=%.1fms first_path=%.1fms corner_to_corner=%.2fms (%d steps) per_path=%.3fms found=%d/%d mean_steps=%.1f" % [
			label, build_ms, first_ms, corner_ms, corner_path.size(), per_query_ms, found, QUERIES,
			float(steps) / maxf(found, 1.0),
		])
	scene.queue_free()
	await get_tree().process_frame
	assert_bool(report.has("hex")).is_true()
