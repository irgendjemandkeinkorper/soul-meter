extends Node
## Rendered evidence for the walk-in Wayhouse (2026-11-03, owner list item 35,
## world/buildings/walk_in_building.gd): the Kesselford map framed on the building with the
## player outside its door, in the doorway, inside, and behind it, plus the painted blocking layer
## shown over the inside frame.
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
const WAYHOUSE_PATH := "KesselfordDressing/SolidProps/Wayhouse"
const ZOOM := 1.45
## Where the player stands for each frame, by marker name or scene point.
const SHOTS: Array[Dictionary] = [
	{"stem": "1-outside", "at": "SpawnFromKesselfordWayhouse", "look": WalkInBuilding.Look.OUTSIDE},
	{"stem": "2-doorway", "at": Vector2(1132, 668), "look": WalkInBuilding.Look.INSIDE},
	{"stem": "3-inside", "at": "SpawnInKesselfordWayhouse", "look": WalkInBuilding.Look.INSIDE},
	{"stem": "4-behind", "at": Vector2(1100, 330), "look": WalkInBuilding.Look.SEEN_THROUGH},
]

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
	var building := town.get_node(WAYHOUSE_PATH) as WalkInBuilding
	var player := town.get_node("Player") as Node2D
	var camera := Camera2D.new()
	town.add_child(camera)
	camera.zoom = Vector2(ZOOM, ZOOM)
	camera.global_position = building.to_global(building.corner(building.cells.x * 0.5, building.cells.y * 0.5)) \
		+ Vector2(0, -60)
	camera.make_current()
	var ok := true
	for shot: Dictionary in SHOTS:
		var at: Variant = shot["at"]
		var point: Vector2 = at if at is Vector2 else (town.get_node(String(at)) as Node2D).global_position
		_place_party(town, player, point)
		for i in 24:
			await get_tree().physics_frame
		var look := building.current_look()
		var saved := await _save(String(shot["stem"]))
		var right := look == int(shot["look"])
		ok = ok and saved and right
		_log.append("WALK-IN-CAPTURE: %s %s look=%s (expected %s)" % [
			"ok" if saved and right else "FAILED", shot["stem"],
			WalkInBuilding.Look.keys()[look], WalkInBuilding.Look.keys()[int(shot["look"])],
		])
	# The painted blocking layer over the inside frame: the wall line and the furniture.
	_place_party(town, player, (town.get_node("SpawnInKesselfordWayhouse") as Node2D).global_position)
	var blocking := town.get_node("Blocking") as TileMapLayer
	blocking.visible = true
	blocking.modulate = Color(1, 0.2, 0.2, 0.55)
	blocking.z_index = 50
	for i in 24:
		await get_tree().physics_frame
	var shown := await _save("5-blocking")
	ok = ok and shown
	_log.append("WALK-IN-CAPTURE: %s 5-blocking cells=%d" % [
		"ok" if shown else "FAILED", blocking.get_used_cells().size(),
	])
	_log.append("WALK-IN-CAPTURE: %s" % ("ok" if ok else "FAILED"))
	print("\n".join(_log))
	var file := FileAccess.open(_dir.path_join("walk-in-capture.log"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(0 if ok else 1)


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
