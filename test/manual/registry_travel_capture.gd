extends Node
## Rendered evidence for E3.3b (#342): a real new game reaches Dom, walks the player onto the
## Equipment Shop door (ungated at new game), presses `interact`, and photographs the interior the door travelled to. Every hop
## (door -> LocationRegistry.resolve -> GameFlow.travel/is_gameplay_scene -> spawn -> FieldMap
## no-combat zone) now reads `data/generated/location_index.json`.
##
## Not a gdUnit suite: it is a temporary autoload, the recipe of scripts/check_generated_data.sh.
## Run under Xvfb (not headless) from the repository root:
##   cp project.godot /tmp/project.godot.bak
##   sed -i '/^Pandora=/a RegistryTravelCapture="*res://test/manual/registry_travel_capture.gd"' project.godot
##   XDG_DATA_HOME="$(mktemp -d)" SOUL_METER_REGISTRY_CAPTURE_DIR="$PWD/docs/qa/<dir>" \
##     xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT_BIN" --path . --resolution 1280x720
##   cp /tmp/project.godot.bak project.godot
## Prints REGISTRY-CAPTURE: ok|FAILED lines; judge those, not the exit code.

const CAPTURE_ENV := "SOUL_METER_REGISTRY_CAPTURE_DIR"
const CAPTURE_WIDTH := 960

var _dir := ""
var _log: PackedStringArray = []


func _ready() -> void:
	_dir = OS.get_environment(CAPTURE_ENV)
	if _dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run.call_deferred()


func _run() -> void:
	var ok := await _drive()
	_note("REGISTRY-CAPTURE: %s" % ("ok" if ok else "FAILED"))
	var file := FileAccess.open(_dir.path_join("registry-travel.log"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(0 if ok else 1)


func _drive() -> bool:
	if not await _wait_for(func() -> bool: return _scene_path() == GameFlow.MAIN_MENU_SCENE, 20.0):
		return _fail("main menu never loaded")
	SaveGame.new_game()
	GameFlow.send_event("new_game")
	if not await _wait_for(_arrived.bind(GameFlow.TOWN_SCENE), 60.0):
		return _fail("new game never arrived in Dom")
	var dom := LocationRegistry.by_scene(GameFlow.TOWN_SCENE)
	_note("arrived: %s (index id '%s', no_combat_zone=%s)" % [
		GameFlow.TOWN_SCENE, dom.id, LocationRegistry.no_combat_zone_by_scene(GameFlow.TOWN_SCENE),
	])

	var transition := BuildingTransitionRegistry.EQUIPMENT_SHOP_ENTER
	var door := _door_for(transition.id)
	if door == null:
		return _fail("no Equipment Shop door in Dom")
	var player := get_tree().current_scene.find_child("Player", true, false) as Node2D
	player.global_position = door.global_position
	await _frames(20)
	await _shoot("01-dom-at-equipment-shop-door.jpg")
	# The door's own travel path (what its `interact` handler calls). A synthetic `interact` event
	# is taken by the adjacent "E — CHECK GEAR" vendor first, so the driver presses the door directly.
	_note("door '%s' in range=%s; _try_travel() accepted=%s" % [
		transition.id, door._player_in_range, door._try_travel(),
	])

	var interior := LocationRegistry.resolve(transition.destination_scene, transition.destination_location_id)
	if interior == null:
		return _fail("index has no location for %s" % transition.destination_scene)
	if not await _wait_for(_arrived.bind(interior.scene_path), 60.0):
		return _fail("door travel never arrived in %s" % interior.scene_path)
	var field := get_tree().current_scene.find_child("FieldMap", true, false) as FieldMap
	_note("door '%s' -> %s (index id '%s', gameplay=%s, spawn '%s', FieldMap.no_combat_zone()=%s)" % [
		transition.id, interior.scene_path, interior.id,
		LocationRegistry.is_gameplay_scene(interior.scene_path),
		interior.resolve_spawn(transition.spawn_id),
		field.no_combat_zone() if field != null else "no FieldMap",
	])
	await _frames(20)
	await _shoot("02-equipment-shop-after-door-travel.jpg")
	return true


func _door_for(transition_id: StringName) -> BuildingDoor:
	for node: Node in get_tree().current_scene.find_children("*", "", true, false):
		if node is BuildingDoor and (node as BuildingDoor).transition_id == transition_id:
			return node as BuildingDoor
	return null


func _arrived(scene_path: String) -> bool:
	return _scene_path() == scene_path and not GameFlow._waiting_for_level


func _scene_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


func _wait_for(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(condition.call()):
			return true
		await get_tree().process_frame
	return false


func _frames(count: int) -> void:
	for _i: int in count:
		await get_tree().process_frame


func _shoot(file_name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var height := int(round(float(image.get_height()) * CAPTURE_WIDTH / image.get_width()))
	image.resize(CAPTURE_WIDTH, height, Image.INTERPOLATE_LANCZOS)
	var path := _dir.path_join(file_name)
	_note("capture %s: %s" % [file_name, error_string(image.save_jpg(path, 0.82))])


func _note(line: String) -> void:
	print(line)
	_log.append(line)


func _fail(reason: String) -> bool:
	_note("REGISTRY-CAPTURE: FAILED — %s" % reason)
	return false
