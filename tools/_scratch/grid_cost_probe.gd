extends Node

func _ready() -> void:
	if OS.get_environment("SM_GRID_COST").is_empty():
		return
	_run.call_deferred()

func _time(path: String, origin: Variant, size: Variant) -> void:
	var root := (load(path) as PackedScene).instantiate() as Node2D
	var ground := root.get_node("IsometricGround") as IsometricBlockout
	if origin != null:
		ground.cell_origin = origin
		ground.map_size = size
	get_tree().root.add_child(root)
	for _i: int in 3:
		await get_tree().process_frame
	var blocking := root.get_node("Blocking") as TileMapLayer
	var best := INF
	for _run_index: int in 3:
		var start := Time.get_ticks_usec()
		var grid := IsoGrid.new()
		grid.build(ground, blocking, ClickMoveController.STATIC_CLEARANCE_CELLS, true)
		grid.prepare_paths()
		best = minf(best, (Time.get_ticks_usec() - start) / 1000.0)
	print("COST %s cells=%d used=%s hex=%s best_build_ms=%.1f" % [path.get_file(), ground.get_used_cells().size(), ground.get_used_rect(), IsoGrid.new().hex_mode, best])
	root.queue_free()
	await get_tree().process_frame

func _run() -> void:
	await _time("res://world/starting_town.tscn", null, null)
	await _time("res://world/starting_town.tscn", Vector2i(-7, -59), Vector2i(134, 133))
	await _time("res://world/kesselford.tscn", null, null)
	get_tree().quit()
