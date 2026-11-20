extends Node

class Overlay extends Node2D:
	var grid: IsoGrid
	func _draw() -> void:
		for y: int in range(1450, 1850, 16):
			for x: int in range(850, 1375, 16):
				var c := grid.world_to_cell(Vector2(x, y))
				var ok := grid.is_in_bounds(c) and not grid.is_point_solid(c)
				draw_circle(Vector2(x, y), 3.0, Color(0, 1, 0, 0.8) if ok else Color(1, 0, 0, 0.8))
		draw_circle(Vector2(1100, 1685), 7.0, Color(0, 0.6, 1, 1))  # door
		draw_circle(Vector2(1100, 1705), 7.0, Color(1, 1, 0, 1))  # current spawn

func _ready() -> void:
	if OS.get_environment("SM_SHRINE_VIEW").is_empty():
		return
	_run.call_deferred()

func _run() -> void:
	var root := (load("res://world/starting_town.tscn") as PackedScene).instantiate() as Node2D
	get_tree().root.add_child(root)
	for _i: int in 5:
		await get_tree().process_frame
	var grid := IsoGrid.new()
	grid.build(root.get_node("IsometricGround"), root.get_node("Blocking"), ClickMoveController.STATIC_CLEARANCE_CELLS, true)
	var overlay := Overlay.new()
	overlay.grid = grid
	overlay.z_index = 4000
	root.add_child(overlay)
	var cam := Camera2D.new()
	cam.position = Vector2(1100, 1620)
	root.add_child(cam)
	cam.make_current()
	for _i: int in 20:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_jpg(OS.get_environment("SM_SHRINE_VIEW"), 0.85)
	print("SHRINEVIEW saved")
	get_tree().quit()
