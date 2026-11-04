extends Node
## Rendered evidence for the walk-in buildings on the Kesselford map (owner list item 35; layouts
## ruled 2026-11-04, world/buildings/walk_in_building.gd): each building framed with the player
## outside a front door, in every room ("Your room opens"), and behind it; the Wayhouse again with
## the painted blocking layer shown; and the town with all four.
##
## Not a gdUnit suite: it is a temporary autoload, the recipe of the ground-blend capture.
## Run under Xvfb (not headless) from the repository root:
##   cp project.godot /tmp/project.godot.bak
##   sed -i '/^Pandora=/a WalkInCapture="*res://test/manual/walk_in_capture.gd"' project.godot
##   XDG_DATA_HOME="$(mktemp -d)" SOUL_METER_WALK_IN_CAPTURE_DIR="$PWD/docs/qa/<dir>" \
##     xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT_BIN" --path . --resolution 1920x1080
##   cp /tmp/project.godot.bak project.godot
## Prints WALK-IN-CAPTURE: ok|FAILED lines; judge those, not the exit code.

const CAPTURE_ENV := "SOUL_METER_WALK_IN_CAPTURE_DIR"
const KESSELFORD := "res://world/kesselford.tscn"
const SOLID_PROPS := "KesselfordDressing/SolidProps/"
const BUILDINGS: Array[String] = ["Wayhouse", "Chandlery", "Cottage", "Warehouse"]
const ZOOM := 1.3
const TOWN_ZOOM := 0.62

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
	var town := (load(KESSELFORD) as PackedScene).instantiate() as Node2D
	get_tree().root.add_child(town)
	for i in 5:
		await get_tree().process_frame
	for hud: Node in town.find_children("*", "CanvasLayer", true, false):
		(hud as CanvasLayer).visible = false
	var player := town.get_node("Player") as Node2D
	var camera := Camera2D.new()
	town.add_child(camera)
	camera.make_current()
	var ok := true
	for building_name: String in BUILDINGS:
		var building := town.get_node(SOLID_PROPS + building_name) as WalkInBuilding
		var plan := building.plan()
		camera.zoom = Vector2(ZOOM, ZOOM)
		camera.global_position = building.to_global(building.corner(plan.size.x * 0.5, plan.size.y * 0.5)) + Vector2(0, -70)
		var shots: Array[Array] = [["1-outside", _outside_door(building), WalkInBuilding.Look.OUTSIDE]]
		for room in range(1, plan.room_count + 1):
			var cell := _room_cell(plan, room)
			shots.append(["%d-room-%d" % [room + 1, room], building.to_global(building.corner(cell.x + 0.5, cell.y + 0.5)), WalkInBuilding.Look.INSIDE])
		var back := plan.footprint_cells()[0]
		for cell: Vector2i in plan.footprint_cells():
			if cell.x + cell.y < back.x + back.y:
				back = cell
		shots.append(["%d-behind" % (plan.room_count + 2), building.to_global(building.corner(back.x, back.y) - Vector2(0, 40)), WalkInBuilding.Look.SEEN_THROUGH])
		for shot: Array in shots:
			_place_party(town, player, shot[1])
			for i in 24:
				await get_tree().physics_frame
			var look := building.current_look()
			var stem := "%s-%s" % [building_name.to_lower(), shot[0]]
			var saved := await _save(stem)
			var right := look == int(shot[2])
			ok = ok and saved and right
			_log.append("WALK-IN-CAPTURE: %s %s look=%s (expected %s) rooms=%s" % [
				"ok" if saved and right else "FAILED", stem,
				WalkInBuilding.Look.keys()[look], WalkInBuilding.Look.keys()[int(shot[2])], building.open_rooms(),
			])
	# The painted blocking layer over the Wayhouse common room: walls, windows and furniture.
	var wayhouse := town.get_node(SOLID_PROPS + "Wayhouse") as WalkInBuilding
	camera.global_position = wayhouse.to_global(wayhouse.corner(8, 6.5)) + Vector2(0, -70)
	_place_party(town, player, (town.get_node("SpawnInKesselfordWayhouse") as Node2D).global_position)
	var blocking := town.get_node("Blocking") as TileMapLayer
	blocking.visible = true
	blocking.modulate = Color(1, 0.2, 0.2, 0.55)
	blocking.z_index = 50
	for i in 24:
		await get_tree().physics_frame
	var shown := await _save("wayhouse-blocking")
	ok = ok and shown
	_log.append("WALK-IN-CAPTURE: %s wayhouse-blocking cells=%d" % ["ok" if shown else "FAILED", blocking.get_used_cells().size()])
	blocking.visible = false
	# The town: all four buildings with their roofs on.
	_place_party(town, player, (town.get_node("SpawnDefault") as Node2D).global_position)
	camera.zoom = Vector2(TOWN_ZOOM, TOWN_ZOOM)
	camera.global_position = Vector2(1250, 900)
	for i in 24:
		await get_tree().physics_frame
	var town_shot := await _save("town")
	ok = ok and town_shot
	_log.append("WALK-IN-CAPTURE: %s town" % ("ok" if town_shot else "FAILED"))
	_log.append("WALK-IN-CAPTURE: %s" % ("ok" if ok else "FAILED"))
	print("\n".join(_log))
	var file := FileAccess.open(_dir.path_join("walk-in-capture.log"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(0 if ok else 1)


## Two cells out from a doorway in a front wall (the screen-bottom sides), on the map.
func _outside_door(building: WalkInBuilding) -> Vector2:
	var plan := building.plan()
	for j in plan.size.y:
		for i in plan.size.x:
			var cell := Vector2i(i, j)
			if plan.at(cell) != BuildingPlan.DOOR:
				continue
			for step: Vector2i in [Vector2i(0, 1), Vector2i(1, 0)]:
				if not plan.is_footprint(cell + step):
					var out := cell + step * 2
					return building.to_global(building.corner(out.x + 0.5, out.y + 0.5))
	return building.to_global(building.corner(plan.size.x + 2, plan.size.y + 2))


## A plain floor cell of `room` away from the walls where possible: the one nearest the room's middle.
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


## Stands the player at `point` and its followers in a short line behind it (screen down-left).
func _place_party(town: Node, player: Node2D, point: Vector2) -> void:
	player.global_position = point
	var index := 1
	for group: StringName in [&"party_follower", &"party_followers"]:
		for node: Node in town.get_tree().get_nodes_in_group(group):
			var follower := node as Node2D
			if follower != null and follower != player:
				follower.global_position = point + Vector2(-26, 14) * index
				index += 1


func _save(stem: String) -> bool:
	for i in 6:
		await get_tree().process_frame
	var out := _dir.path_join("%s.png" % stem)
	return get_viewport().get_texture().get_image().save_png(out) == OK
