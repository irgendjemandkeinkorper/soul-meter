extends Node
## Scratch: for each top-level field a journey can start or end in, is the party's arrival cell
## and each Spawn* marker inside the field's walking grid?

const SCENES := [
	"res://world/starting_town.tscn", "res://world/dorthkor_road.tscn", "res://world/kesselford.tscn",
	"res://world/ashlaren.tscn", "res://world/long_verge.tscn", "res://world/hollowmere.tscn",
	"res://world/wound_lip.tscn", "res://world/test_room.tscn",
]

func _ready() -> void:
	if OS.get_environment("SM_GRID_PROBE").is_empty():
		return
	_run.call_deferred()

func _settled(path: String) -> bool:
	var s := get_tree().current_scene
	return s != null and s.scene_file_path == path and not GameFlow._waiting_for_level

func _run() -> void:
	while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != GameFlow.MAIN_MENU_SCENE:
		await get_tree().process_frame
	SaveGame.new_game()
	GameFlow.send_event("new_game")
	while not _settled(GameFlow.TOWN_SCENE):
		await get_tree().process_frame
	for path: String in SCENES:
		if get_tree().current_scene.scene_file_path != path:
			if not GameFlow.travel(path):
				print("GRID ", path, " travel refused")
				continue
			var deadline := Time.get_ticks_msec() + 60000
			while not _settled(path) and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
		for _i: int in 20:
			await get_tree().process_frame
		var scene := get_tree().current_scene
		var field := scene.find_child("FieldMap", true, false) as FieldMap
		if field == null or field.iso_grid() == null:
			print("GRID ", path, " no field grid")
			continue
		var grid := field.iso_grid()
		var lead_cell := grid.world_to_cell(field.player().global_position)
		var on := 0
		var off: PackedStringArray = []
		for child: Node in scene.get_children():
			if child is Marker2D and String(child.name).begins_with("Spawn"):
				var c := grid.world_to_cell((child as Marker2D).global_position)
				if grid.is_in_bounds(c) and not grid.is_point_solid(c):
					on += 1
				else:
					off.append(String(child.name))
		print("GRID %s lead_in_grid=%s lead_solid=%s spawns_on=%d spawns_off=%d %s" % [
			path.get_file(), grid.is_in_bounds(lead_cell), grid.is_point_solid(lead_cell), on, off.size(), ",".join(off),
		])
	get_tree().quit()
