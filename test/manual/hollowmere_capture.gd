extends Node
## Rendered evidence for C4 / #241 (Hollowmere): a real new game reaches Dom, opens the field
## commission flag, walks Dom's north road onto the Dorthkor Road, crosses the road to the new reed track and
## photographs the mere it travels to (arrival, the watch post, the drowned camp), then walks
## the reed track back onto the Dorthkor Road. Every hop goes through the baked exits and
## `GameFlow.travel()`, the way a player would move.
##
## Not a gdUnit suite: it is a temporary autoload, the recipe of scripts/check_generated_data.sh.
## Run under Xvfb (not headless) from the repository root:
##   cp project.godot /tmp/project.godot.bak
##   sed -i '/^Pandora=/a HollowmereCapture="*res://test/manual/hollowmere_capture.gd"' project.godot
##   XDG_DATA_HOME="$(mktemp -d)" SOUL_METER_HOLLOWMERE_CAPTURE_DIR="$PWD/docs/qa/<dir>" \
##     xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT_BIN" --path . --resolution 1280x720
##   cp /tmp/project.godot.bak project.godot
## Prints HOLLOWMERE-CAPTURE: ok|FAILED lines; judge those, not the exit code.

const CAPTURE_ENV := "SOUL_METER_HOLLOWMERE_CAPTURE_DIR"
const CAPTURE_WIDTH := 960
## The flag the Marshal's road commission writes; Dom's NorthRoad exit is locked until it is set.
## The capture sets it directly instead of playing the commission dialogue.
const COMMISSION_FLAG := "chapter_dorthkor_commissioned"
## Where the camera stands for the watch-post and drowned-camp shots (scene coordinates of the
## baked `world/hollowmere.tscn`); the camp stop stays outside the drowned watch's alert radius.
const WATCH_STOP := Vector2(1320, 700)
const CAMP_STOP := Vector2(2000, 900)

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
	_note("HOLLOWMERE-CAPTURE: %s" % ("ok" if ok else "FAILED"))
	var file := FileAccess.open(_dir.path_join("hollowmere.log"), FileAccess.WRITE)
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

	var breach_road := _exit("NorthRoad")
	if breach_road == null:
		return _fail("Dom has no NorthRoad exit to the Dorthkor Road")
	GameState.set_flag(COMMISSION_FLAG, true)
	var player := _player()
	player.global_position = breach_road.global_position + Vector2(160, 0)
	await _frames(10)
	_note("Dom NorthRoad after %s: unlocked=%s label='%s'" % [
		COMMISSION_FLAG, breach_road._is_unlocked(), breach_road._label.text,
	])
	player.global_position = breach_road.global_position
	var road := LocationRegistry.DORTHKOR
	if not await _wait_for(_arrived.bind(road.scene_path), 60.0):
		return _fail("NorthRoad never arrived on the Dorthkor Road")
	player = _player()
	await _frames(20)
	var reed_track := _exit("ReedTrack")
	if reed_track == null:
		return _fail("the Dorthkor Road has no ReedTrack exit")
	player.global_position = reed_track.global_position + Vector2(-140, 0)
	await _frames(20)
	_note("Dorthkor Road ReedTrack: unlocked=%s label='%s' at %s" % [
		reed_track._is_unlocked(), reed_track._label.text, reed_track.global_position,
	])
	await _shoot("01-dorthkor-road-reed-track.jpg")

	player.global_position = reed_track.global_position
	var mere := LocationRegistry.HOLLOWMERE
	if not await _wait_for(_arrived.bind(mere.scene_path), 60.0):
		return _fail("ReedTrack never arrived at Hollowmere")
	player = _player()
	await _frames(20)
	_note("arrived: %s (index id '%s', tier %d, accord %.0f, phase %s) player at %s, SpawnFromDorthkorRoad at %s" % [
		mere.scene_path, mere.id, mere.thinning_tier, mere.harmonic_accord, WorldClock.phase(),
		player.global_position, _marker("SpawnFromDorthkorRoad"),
	])
	await _shoot("02-hollowmere-arrival.jpg")

	player.global_position = WATCH_STOP
	await _frames(20)
	_note("watch post: %s" % ", ".join(_townsfolk()))
	await _shoot("03-hollowmere-watch-post.jpg")

	player.global_position = CAMP_STOP
	await _frames(20)
	var watch := get_tree().current_scene.get_node_or_null("DrownedWatch") as Node2D
	_note("drowned camp: watch at %s, player %.0fpx away, alert cooldown=%s" % [
		watch.global_position if watch != null else Vector2.INF,
		watch.global_position.distance_to(player.global_position) if watch != null else -1.0,
		watch.alert_cooldown_active() if watch != null else "missing",
	])
	await _shoot("04-hollowmere-drowned-camp.jpg")

	var back := _exit("ReedTrackToDorthkor")
	if back == null:
		return _fail("Hollowmere has no ReedTrackToDorthkor exit")
	_note("ReedTrackToDorthkor: unlocked=%s label='%s'" % [back._is_unlocked(), back._label.text])
	player.global_position = back.global_position
	if not await _wait_for(_arrived.bind(road.scene_path), 60.0):
		return _fail("ReedTrackToDorthkor never arrived on the Dorthkor Road")
	player = _player()
	await _frames(20)
	_note("arrived: %s (phase %s) player at %s, SpawnFromHollowmere at %s" % [
		road.scene_path, WorldClock.phase(), player.global_position, _marker("SpawnFromHollowmere"),
	])
	await _shoot("05-dorthkor-road-arrival-from-mere.jpg")

	# C25 (#262): over the track once more, then open the Mender's talk, which must come from the
	# authored dialogue/locations/hollowmere.dialogue rather than the generated placeholder.
	var track_again := _exit("ReedTrack")
	if track_again == null:
		return _fail("the Dorthkor Road lost its ReedTrack exit on the way back")
	player.global_position = track_again.global_position
	if not await _wait_for(_arrived.bind(mere.scene_path), 60.0):
		return _fail("ReedTrack never arrived at Hollowmere a second time")
	player = _player()
	await _frames(20)
	var mender := get_tree().current_scene.find_child("HollowmereMender", true, false) as NPC
	if mender == null:
		return _fail("HollowmereMender did not spawn")
	_note("mender route: %s > %s" % [mender.dialogue_path, mender.dialogue_start])
	player.global_position = mender.global_position + Vector2(0, 48)
	await _frames(20)
	var started: Array[String] = []
	DialogueManager.dialogue_started.connect(
		func(resource: DialogueResource) -> void: started.append(resource.resource_path)
	)
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(40)
	_note("dialogue started from: %s" % ", ".join(started))
	await _shoot("06-hollowmere-mender-talk.jpg")
	if started.is_empty() or not started[0].ends_with("dialogue/locations/hollowmere.dialogue"):
		return _fail("the Mender did not open the authored location dialogue")
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
	_note("HOLLOWMERE-CAPTURE: FAILED — %s" % reason)
	return false
