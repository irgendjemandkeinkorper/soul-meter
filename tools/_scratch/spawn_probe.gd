extends Node

func _ready() -> void:
	if OS.get_environment("SM_SPAWN_PROBE").is_empty():
		return
	_run.call_deferred()

func _run() -> void:
	while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != GameFlow.MAIN_MENU_SCENE:
		await get_tree().process_frame
	SaveGame.new_game()
	GameFlow.send_event("new_game")
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		var s := get_tree().current_scene
		if s != null and s.scene_file_path == GameFlow.TOWN_SCENE and not GameFlow._waiting_for_level:
			break
		await get_tree().process_frame
	for _i: int in 30:
		await get_tree().process_frame
	var field := get_tree().current_scene.find_child("FieldMap", true, false) as FieldMap
	var grid := field.iso_grid()
	var player := field.player()
	var cell := grid.world_to_cell(player.global_position)
	print("PROBE player pos=", player.global_position, " cell=", cell, " in_bounds=", grid.is_in_bounds(cell), " solid=", grid.is_point_solid(cell))
	print("PROBE party_cells=", field.party_cells(), " spawn_id=", GameFlow.get("_target_spawn") if "_target_spawn" in GameFlow else "?")
	var free := 0
	var near := []
	for dx: int in range(-3, 4):
		for dy: int in range(-3, 4):
			var c := cell + Vector2i(dx, dy)
			if grid.is_in_bounds(c) and not grid.is_point_solid(c):
				free += 1
				if near.size() < 6: near.append(c)
	print("PROBE free cells within 3: ", free, " e.g. ", near)
	print("PROBE can_fight_here(set_piece)=", Battle.can_fight_here(field, true))
	var ground := field.ground()
	var used := ground.get_used_rect()
	var sq := ground.local_to_map(ground.to_local(player.global_position))
	print("PROBE ground used_rect=", used, " player square cell=", sq, " square in used rect=", used.has_point(sq), " ground has tile there=", ground.get_cell_source_id(sq) != -1, " hex_mode=", grid.hex_mode)
	# nearest in-region, non-solid hex by world distance
	var best := Vector2i.ZERO
	var best_d := INF
	for dx: int in range(-30, 31):
		for dy: int in range(-30, 31):
			var c := cell + Vector2i(dx, dy)
			if grid.is_in_bounds(c) and not grid.is_point_solid(c):
				var d := grid.cell_to_world(c).distance_to(player.global_position)
				if d < best_d:
					best_d = d
					best = c
	print("PROBE nearest walkable hex=", best, " at ", best_d, " px; path from spawn cell: ", grid.path_cells(cell, best, player).size(), " points")
	# Does the click-move controller move the player? Ask for a path to a walkable cell 200px away.
	var cm: Node = null
	for n: Node in get_tree().current_scene.find_children("*", "", true, false):
		if n is ClickMoveController:
			cm = n
			break
	print("PROBE click-move controller=", cm)
	var start := player.global_position
	if cm != null:
		print("PROBE request_move_to(nearest walkable)=", cm.call("request_move_to", grid.cell_to_world(best)))
	for _i: int in 90:
		await get_tree().process_frame
	print("PROBE player moved by ", player.global_position.distance_to(start), " px; now cell ", grid.world_to_cell(player.global_position), " in_bounds=", grid.is_in_bounds(grid.world_to_cell(player.global_position)))
	get_tree().quit()
