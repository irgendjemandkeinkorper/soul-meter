extends Node

func _ready() -> void:
	if OS.get_environment("SM_DOM_EXTENT").is_empty():
		return
	_run.call_deferred()

func _grow(r: Rect2i, has: bool, c: Vector2i) -> Rect2i:
	return r.expand(c) if has else Rect2i(c, Vector2i.ZERO)

func _run() -> void:
	var packed := load("res://world/starting_town.tscn") as PackedScene
	var root := packed.instantiate() as Node2D
	get_tree().root.add_child(root)
	for _i: int in 5:
		await get_tree().process_frame
	var ground := root.get_node("IsometricGround") as TileMapLayer
	var blocking := root.get_node("Blocking") as TileMapLayer
	var content := Rect2i(); var has_c := false
	var names_out: PackedStringArray = []
	for node: Node in root.find_children("*", "Node2D", true, false):
		if node is Camera2D or node is Polygon2D or node.name in ["TerrainBackdrop", "IsometricGround", "Blocking", "Terrain"]:
			continue
		if node.get_parent() != root and not (node is Marker2D or node is CollisionObject2D):
			continue
		var c := ground.local_to_map(ground.to_local((node as Node2D).global_position))
		content = _grow(content, has_c, c); has_c = true
	var blk := Rect2i(); var has_b := false
	for cell: Vector2i in blocking.get_used_cells():
		var world := blocking.to_global(blocking.map_to_local(cell))
		var c := ground.local_to_map(ground.to_local(world))
		blk = _grow(blk, has_b, c); has_b = true
	var cam := Rect2i(); var has_m := false
	for corner: Vector2 in [Vector2(0, 0), Vector2(3600, 0), Vector2(0, 2400), Vector2(3600, 2400)]:
		var c := ground.local_to_map(ground.to_local(corner))
		cam = _grow(cam, has_m, c); has_m = true
	print("EXTENT ground used ", ground.get_used_rect())
	print("EXTENT content ", content, " end ", content.end)
	print("EXTENT blocking ", blk, " end ", blk.end, " cells ", blocking.get_used_cells().size())
	print("EXTENT camera ", cam, " end ", cam.end)
	var union := content.merge(blk)
	print("EXTENT content+blocking ", union, " end ", union.end, " area ", union.get_area())
	print("EXTENT camera area ", cam.get_area())
	get_tree().quit()
