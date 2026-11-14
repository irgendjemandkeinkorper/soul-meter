extends Node
## Rendered evidence for the Lower Trial Hall's rooms (owner rulings of 2026-11-04: "Extend Lower
## Trial Hall", "Side-room fights, Blast door, Locked door, Final opponent", "Medium: ~10 rooms"):
## the whole hall from above, the party in each of its ten rooms ("Your room opens"), the painted
## blocking layer, and the hall again with every gate open.
##
## Not a gdUnit suite: it is a temporary autoload, the recipe of the walk-in capture.
## Run under Xvfb (not headless) from the repository root:
##   cp project.godot /tmp/project.godot.bak
##   sed -i '/^Pandora=/a TrialHallCapture="*res://test/manual/trial_hall_capture.gd"' project.godot
##   XDG_DATA_HOME="$(mktemp -d)" SOUL_METER_TRIAL_HALL_CAPTURE_DIR="$PWD/docs/qa/<dir>" \
##     xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT_BIN" --path . --resolution 1920x1080
##   cp /tmp/project.godot.bak project.godot
## Prints TRIAL-HALL-CAPTURE: ok|FAILED lines; judge those, not the exit code.

const CAPTURE_ENV := "SOUL_METER_TRIAL_HALL_CAPTURE_DIR"
const HALL := "res://world/interiors/lower_trial_hall.tscn"
const ROOM_ZOOM := 1.5
const HALL_ZOOM := 0.98
const HALL_CENTRE := Vector2(960, 600)

var _dir := ""
var _log: PackedStringArray = []


func _ready() -> void:
	_dir = OS.get_environment(CAPTURE_ENV)
	if _dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run.call_deferred()


func _run() -> void:
	for i in 30:
		await get_tree().process_frame
	var menu := get_tree().current_scene
	if menu != null:
		if menu is CanvasItem:
			(menu as CanvasItem).hide()
		for layer: Node in menu.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false
	GameState.flags.clear()
	var hall := (load(HALL) as PackedScene).instantiate() as Node2D
	get_tree().root.add_child(hall)
	for i in 5:
		await get_tree().process_frame
	for layer: Node in hall.find_children("*", "CanvasLayer", true, false):
		if layer.name != "Surround":
			(layer as CanvasLayer).visible = false
	var player := hall.get_node("Room/Player") as Node2D
	var rooms := hall.get_node("TrialRooms") as WalkInBuilding
	var plan := rooms.plan()
	var camera := Camera2D.new()
	hall.add_child(camera)
	camera.make_current()
	var ok := true

	camera.zoom = Vector2(HALL_ZOOM, HALL_ZOOM)
	camera.global_position = HALL_CENTRE
	ok = await _shot("01-hall-arrival", rooms, WalkInBuilding.Look.INSIDE) and ok

	for room in range(1, plan.room_count + 1):
		var cell := _room_cell(plan, room)
		player.global_position = rooms.to_global(rooms.corner(cell.x + 0.5, cell.y + 0.5))
		camera.zoom = Vector2(ROOM_ZOOM, ROOM_ZOOM)
		camera.global_position = player.global_position + Vector2(0, -60)
		var stem := "%02d-room-%d" % [room + 1, room]
		var saved := await _shot(stem, rooms, WalkInBuilding.Look.INSIDE)
		var right := rooms.open_rooms() == plan.rooms_of(cell)
		ok = ok and saved and right
		if not right:
			_log.append("TRIAL-HALL-CAPTURE: FAILED %s opens %s, not %s" % [stem, rooms.open_rooms(), plan.rooms_of(cell)])

	var spawn := hall.get_node("Room/SpawnEntry") as Node2D
	player.global_position = spawn.global_position
	var blocking := hall.get_node("Blocking") as TileMapLayer
	blocking.visible = true
	blocking.modulate = Color(1, 0.2, 0.2, 0.55)
	blocking.z_index = 50
	camera.zoom = Vector2(HALL_ZOOM, HALL_ZOOM)
	camera.global_position = HALL_CENTRE
	ok = await _shot("13-hall-blocking", rooms, WalkInBuilding.Look.INSIDE) and ok
	blocking.visible = false

	GameState.set_flag("tutorial_warden_cleared", true)
	GameState.set_flag("trial_store_door_open", true)
	GameState.set_flag("trial_blast_door_open", true)
	GameState.set_flag("tutorial_gauntlet_complete", true)
	ok = await _shot("14-hall-gates-open", rooms, WalkInBuilding.Look.INSIDE) and ok

	_log.append("TRIAL-HALL-CAPTURE: %s" % ("ok" if ok else "FAILED"))
	print("\n".join(_log))
	var file := FileAccess.open(_dir.path_join("trial-hall-capture.log"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(0 if ok else 1)


func _shot(stem: String, rooms: WalkInBuilding, expected_look: int) -> bool:
	for i in 24:
		await get_tree().physics_frame
	await get_tree().create_timer(WalkInBuilding.FADE_DURATION + 0.1).timeout
	for i in 6:
		await get_tree().process_frame
	var out := _dir.path_join("%s.png" % stem)
	var saved := get_viewport().get_texture().get_image().save_png(out) == OK
	var look := rooms.current_look()
	var right := look == expected_look
	_log.append("TRIAL-HALL-CAPTURE: %s %s look=%s rooms=%s" % [
		"ok" if saved and right else "FAILED", stem, WalkInBuilding.Look.keys()[look], rooms.open_rooms(),
	])
	return saved and right


## A plain floor cell of `room` nearest the room's middle.
func _room_cell(plan: BuildingPlan, room: int) -> Vector2i:
	var cells: Array[Vector2i] = []
	var middle := Vector2.ZERO
	for j in plan.size.y:
		for i in plan.size.x:
			var cell := Vector2i(i, j)
			if plan.at(cell) == BuildingPlan.FLOOR and plan.rooms_of(cell) == [room]:
				cells.append(cell)
				middle += Vector2(cell)
	middle /= maxf(1.0, cells.size())
	var best := cells[0]
	for cell: Vector2i in cells:
		if Vector2(cell).distance_to(middle) < Vector2(best).distance_to(middle):
			best = cell
	return best
