extends Node

func _ready() -> void:
	if OS.get_environment("SM_SHRINE").is_empty():
		return
	_run.call_deferred()

func _run() -> void:
	var root := (load("res://world/starting_town.tscn") as PackedScene).instantiate() as Node2D
	get_tree().root.add_child(root)
	for _i: int in 3:
		await get_tree().process_frame
	var grid := IsoGrid.new()
	grid.build(root.get_node("IsometricGround"), root.get_node("Blocking"), ClickMoveController.STATIC_CLEARANCE_CELLS, true)
	print("SHRINE cols x=850..1350 step 25; door at (1100,1685), marker (1100,1705)")
	for y: int in range(1500, 1925, 25):
		var row := ""
		for x: int in range(850, 1375, 25):
			var c := grid.world_to_cell(Vector2(x, y))
			var ok := grid.is_in_bounds(c) and not grid.is_point_solid(c)
			var mark := "o" if ok else "#"
			if x == 1100 and y == 1700:
				mark = "D" if not ok else "d"
			row += mark
		print("SHRINE %4d %s" % [y, row])
	for name: String in ["SpawnFromItemShop", "SpawnFromChefsHouse", "SpawnFromTownHall", "SpawnFromTavern"]:
		var m := root.get_node(name) as Marker2D
		var c := grid.world_to_cell(m.global_position)
		print("SHRINE ref ", name, " ", m.global_position, " ok=", grid.is_in_bounds(c) and not grid.is_point_solid(c))
	get_tree().quit()
