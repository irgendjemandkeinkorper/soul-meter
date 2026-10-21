extends Node
## Rendered evidence for C3 / #240 (The Long Verge): a real new game reaches Dom, finds the Moor
## Road exit locked behind the field commission, opens the gate, walks onto the exit and
## photographs the Verge it travels to (arrival, the Company camp, the cairn and the grave), then
## walks the Verge's west exit down into Kesselford. Every hop goes through the baked exits and
## `GameFlow.travel()`, the way a player would move.
##
## Not a gdUnit suite: it is a temporary autoload, the recipe of scripts/check_generated_data.sh.
## Run under Xvfb (not headless) from the repository root:
##   cp project.godot /tmp/project.godot.bak
##   sed -i '/^Pandora=/a LongVergeCapture="*res://test/manual/long_verge_capture.gd"' project.godot
##   XDG_DATA_HOME="$(mktemp -d)" SOUL_METER_LONG_VERGE_CAPTURE_DIR="$PWD/docs/qa/<dir>" \
##     xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT_BIN" --path . --resolution 1280x720
##   cp /tmp/project.godot.bak project.godot
## Prints LONG-VERGE-CAPTURE: ok|FAILED lines; judge those, not the exit code.

const CAPTURE_ENV := "SOUL_METER_LONG_VERGE_CAPTURE_DIR"
const CAPTURE_WIDTH := 960
## The flag the Moor Road accepts; any one of the exit's `required_flags` opens it.
const FREE_ROAM_FLAG := "chapter_one_free_roam"
## Where the camera stands for the camp and the cairn shots (scene coordinates of the baked
## `world/long_verge.tscn`); the cairn stop stays outside the grave watch's 320px alert radius.
const CAMP_STOP := Vector2(2150, 700)
const CAIRN_STOP := Vector2(1180, 1080)

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
	_note("LONG-VERGE-CAPTURE: %s" % ("ok" if ok else "FAILED"))
	var file := FileAccess.open(_dir.path_join("long-verge.log"), FileAccess.WRITE)
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

	var moor_road := _exit("MoorRoad")
	if moor_road == null:
		return _fail("Dom has no MoorRoad exit")
	var player := _player()
	player.global_position = moor_road.global_position
	await _frames(20)
	_note("Dom MoorRoad at new game: unlocked=%s label='%s'" % [
		moor_road._is_unlocked(), moor_road._label.text,
	])
	await _shoot("01-dom-moor-road-locked.jpg")
	if moor_road._is_unlocked():
		return _fail("MoorRoad should be locked at new game")

	GameState.set_flag(FREE_ROAM_FLAG, true)
	# Step off and back on: the exit only travels on `body_entered`.
	player.global_position = moor_road.global_position + Vector2(160, 0)
	await _frames(10)
	_note("after %s: unlocked=%s label='%s'" % [
		FREE_ROAM_FLAG, moor_road._is_unlocked(), moor_road._label.text,
	])
	player.global_position = moor_road.global_position
	var verge := LocationRegistry.LONG_VERGE
	if not await _wait_for(_arrived.bind(verge.scene_path), 60.0):
		return _fail("MoorRoad never arrived on the Long Verge")
	player = _player()
	await _frames(20)
	_note("arrived: %s (index id '%s', tier %d, phase %s) player at %s, SpawnFromDom at %s" % [
		verge.scene_path, verge.id, verge.thinning_tier, WorldClock.phase(),
		player.global_position, _marker("SpawnFromDom"),
	])
	await _shoot("02-verge-arrival-from-dom.jpg")

	player.global_position = CAMP_STOP
	await _frames(20)
	_note("camp: %s" % ", ".join(_townsfolk()))
	await _shoot("03-verge-company-camp.jpg")

	player.global_position = CAIRN_STOP
	await _frames(20)
	var watch := get_tree().current_scene.get_node_or_null("GraveWatch") as Node2D
	_note("cairn stop: grave watch at %s, player %.0fpx away, alert cooldown=%s" % [
		watch.global_position if watch != null else Vector2.INF,
		watch.global_position.distance_to(player.global_position) if watch != null else -1.0,
		watch.alert_cooldown_active() if watch != null else "missing",
	])
	await _shoot("04-verge-cairn-and-grave.jpg")

	var to_kesselford := _exit("RoadToKesselford")
	if to_kesselford == null:
		return _fail("the Verge has no RoadToKesselford exit")
	_note("RoadToKesselford: unlocked=%s label='%s'" % [
		to_kesselford._is_unlocked(), to_kesselford._label.text,
	])
	player.global_position = to_kesselford.global_position
	var kesselford := LocationRegistry.KESSELFORD
	if not await _wait_for(_arrived.bind(kesselford.scene_path), 60.0):
		return _fail("RoadToKesselford never arrived in Kesselford")
	player = _player()
	await _frames(20)
	_note("arrived: %s (phase %s) player at %s, SpawnFromLongVerge at %s" % [
		kesselford.scene_path, WorldClock.phase(), player.global_position,
		_marker("SpawnFromLongVerge"),
	])
	await _shoot("05-kesselford-arrival-from-verge.jpg")
	return true


func _exit(node_name: String) -> TravelExit:
	return get_tree().current_scene.get_node_or_null(node_name) as TravelExit


func _player() -> Node2D:
	return get_tree().current_scene.find_child("Player", true, false) as Node2D


func _marker(node_name: String) -> String:
	var marker := get_tree().current_scene.get_node_or_null(node_name) as Node2D
	return str(marker.global_position) if marker != null else "missing"


## The roster NPCs TownNpcSpawner added to the scene root (group `generated_townsfolk`).
func _townsfolk() -> PackedStringArray:
	var lines: PackedStringArray = []
	for node: Node in get_tree().get_nodes_in_group(&"generated_townsfolk"):
		if node is Node2D:
			lines.append("%s@%s" % [node.name, (node as Node2D).global_position])
	return lines


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
	_note("LONG-VERGE-CAPTURE: FAILED — %s" % reason)
	return false
