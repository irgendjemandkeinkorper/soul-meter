extends Node
## P1.5 (#534) rendered evidence for the region-map journey. A real new game starts. The party is
## then placed at the route's origin, the player presses Esc and opens the region map from the
## pause menu. They press the destination's marker, read the route's steps, phases and risk, press
## BEGIN JOURNEY and let the map's own step timer carry the journey. Every ambush prompt is
## answered with AVOID. When the avoid roll fails, the ambush is fought on the field under
## autoplay, then the player presses Esc, reopens the region map and presses CONTINUE. The run
## passes only when the party arrives in the destination scene, the plan reads ARRIVED and the
## clock has advanced by the route's phases (fight time excluded). Any stall is a dead end and
## fails. A stranded ambush also captures what the player is left with.
##
## Setup, not under test: the destination is marked discovered first, standing in for one earlier
## walk there (arrival-time discovery is `GameFlow`'s `level_ready` path). For an origin other
## than Dom, the party reaches it with `GameFlow.travel`, the call a door or exit makes.
##
## Not a gdUnit suite: it is a temporary autoload, the recipe of registry_travel_capture.gd.
## Run under Xvfb (not headless) from the repository root:
##   cp project.godot /tmp/project.godot.bak
##   sed -i '/^Pandora=/a RegionMapJourneyCapture="*res://test/manual/region_map_journey_capture.gd"' project.godot
##   XDG_DATA_HOME="$(mktemp -d)" SOUL_METER_JOURNEY_CAPTURE_DIR="$PWD/docs/qa/<dir>" \
##     SOUL_METER_JOURNEY_ROUTE=dom:dorthkor_road \
##     xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT_BIN" --path . --resolution 1280x720
##   cp /tmp/project.godot.bak project.godot
## Prints JOURNEY-CAPTURE: ok|FAILED lines; judge those, not the exit code.

const CAPTURE_ENV := "SOUL_METER_JOURNEY_CAPTURE_DIR"
const ROUTE_ENV := "SOUL_METER_JOURNEY_ROUTE"
const DEFAULT_ROUTE := "dom:dorthkor_road"
const CAPTURE_WIDTH := 960
const REGION_MAP_SCENE := "res://ui/screens/region_map.tscn"
const PAUSE_MENU_SCENE := "res://ui/screens/pause_menu.tscn"
## Up to sixteen 0.5 s steps plus fights; anything past this is a stall.
const JOURNEY_SECONDS := 240.0

var _dir := ""
var _origin := &""
var _destination := &""
var _log: PackedStringArray = []
var _shots := 0
var _fight_phases := 0


func _ready() -> void:
	_dir = OS.get_environment(CAPTURE_ENV)
	if _dir.is_empty():
		return
	var route := OS.get_environment(ROUTE_ENV)
	var ends := (route if not route.is_empty() else DEFAULT_ROUTE).split(":")
	_origin = StringName(ends[0])
	_destination = StringName(ends[1])
	DirAccess.make_dir_recursive_absolute(_dir)
	_run.call_deferred()


func _run() -> void:
	var ok := await _drive()
	_note("JOURNEY-CAPTURE: %s" % ("ok" if ok else "FAILED"))
	var file := FileAccess.open(_dir.path_join("journey.log"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(0 if ok else 1)


func _drive() -> bool:
	_note("route under test: %s -> %s" % [_origin, _destination])
	if not await _wait_for(func() -> bool: return _scene_path() == GameFlow.MAIN_MENU_SCENE, 20.0):
		return _fail("main menu never loaded")
	SaveGame.new_game()
	GameFlow.send_event("new_game")
	if not await _wait_for(_arrived.bind(GameFlow.TOWN_SCENE), 60.0):
		return _fail("new game never arrived in Dom")
	var origin_scene := str(WorldMapRegistry.location(_origin)["scene_path"])
	if origin_scene != GameFlow.TOWN_SCENE:
		GameState.discover_world_location(_origin)
		if not GameFlow.travel(origin_scene):
			return _fail("GameFlow.travel refused the origin %s" % origin_scene)
		if not await _wait_for(_arrived.bind(origin_scene), 60.0):
			return _fail("never arrived at the origin %s" % origin_scene)
	GameState.discover_world_location(_destination)
	_note("setup: at %s, %s discovered=%s (stands in for one earlier walk there)" % [
		_scene_path().get_file(), _destination, GameState.is_world_location_discovered(_destination),
	])
	_note_party_cell("origin")
	await _frames(20)
	await _shoot("origin")

	var map := await _open_region_map()
	if map == null:
		return false
	var marker := map.find_child("Location_%s" % _destination, true, false) as Button
	if marker == null or marker.disabled:
		return _fail("no pressable %s marker on the region map" % _destination)
	marker.pressed.emit()
	await _frames(5)
	var route := WorldMapRegistry.route_between(_origin, _destination)
	var travel_button := map.find_child("TravelButton", true, false) as Button
	_note("selected %s: button '%s' disabled=%s | %s | %s | %s" % [
		_destination, travel_button.text, travel_button.disabled,
		_text(map, "RouteSteps"), _text(map, "RouteTime"), _text(map, "RouteRisk"),
	])
	_note("registry route %s: steps=%d phases_cost=%d risk=%s encounters=%d-%d" % [
		route["id"], int(route["steps"]), int(route["phases_cost"]), route["risk_tier"],
		int(route["min_encounters"]), int(route["max_encounters"]),
	])
	await _shoot("route-selected")
	if travel_button.disabled:
		return _fail("BEGIN JOURNEY is disabled for a discovered connected destination")

	var phases_before := WorldClock.phase_count
	travel_button.pressed.emit()
	await _frames(2)
	var plan := GameFlow.travel_plan
	if plan == null or plan.state != TravelPlan.State.EN_ROUTE:
		return _fail("BEGIN JOURNEY did not leave an EN_ROUTE plan")
	_note("journey committed: %s -> %s, %d steps, %d scheduled encounter(s) at steps %s" % [
		plan.origin_id, plan.destination_id, plan.total_steps, plan.encounter_schedule.size(),
		str(plan.encounter_schedule.map(func(slot: Dictionary) -> int: return int(slot["at_step"]))),
	])
	await _wait_seconds(1.2)
	await _shoot("journey-underway")

	var destination_scene := str(WorldMapRegistry.location(_destination)["scene_path"])
	var deadline := Time.get_ticks_msec() + int(JOURNEY_SECONDS * 1000.0)
	var arrival_noted := false
	while Time.get_ticks_msec() < deadline:
		if _arrived(destination_scene):
			break
		plan = GameFlow.travel_plan
		if plan == null:
			return _fail("the plan vanished before arrival")
		if plan.state == TravelPlan.State.AVOID_PROMPT:
			if not await _answer_prompt():
				return false
		elif plan.state == TravelPlan.State.EN_ROUTE and not _region_map_open() and not Battle.session_active:
			# The fight is over and the field is back: the player reopens the map to go on.
			if not await _continue_from_field():
				return false
		elif plan.state == TravelPlan.State.ARRIVED and not arrival_noted:
			arrival_noted = true
			await _frames(30)
			_note("plan ARRIVED: scene still %s, chart %s, top screen '%s', clock phase %d" % [
				_scene_path().get_file(), _chart_state(), _top_screen().get_file(), WorldClock.phase_count,
			])
			await _shoot("plan-arrived")
			if _top_screen() == PAUSE_MENU_SCENE:
				# The map closed itself onto the pause menu; a player resumes.
				_press_action(&"ui_cancel")
				await _frames(60)
				_note("resumed after arrival: scene %s, chart %s, top screen '%s'" % [
					_scene_path().get_file(), _chart_state(), _top_screen().get_file(),
				])
				await _shoot("resumed-after-arrival")
			# A scene load starts within a second or two; twenty more is ample.
			deadline = mini(deadline, Time.get_ticks_msec() + 20000)
		await get_tree().process_frame
	if not _arrived(destination_scene):
		return _fail("no arrival within %.0f s (plan state %s, step %d/%d) — a dead end" % [
			JOURNEY_SECONDS, TravelPlan.State.keys()[GameFlow.travel_plan.state],
			GameFlow.travel_plan.progress_step, GameFlow.travel_plan.total_steps,
		])

	await _frames(30)
	var spent := WorldClock.phase_count - phases_before - _fight_phases
	plan = GameFlow.travel_plan
	_note("arrived: scene %s, plan %s at %d/%d, discovered=%s, journey phases %d (route %d), fight phases %d" % [
		_scene_path().get_file(), TravelPlan.State.keys()[plan.state], plan.progress_step, plan.total_steps,
		GameState.is_world_location_discovered(_destination), spent, int(route["phases_cost"]), _fight_phases,
	])
	_note_party_cell("destination")
	await _shoot("arrived")
	if plan.state != TravelPlan.State.ARRIVED:
		return _fail("arrived in the scene but the plan is %s" % TravelPlan.State.keys()[plan.state])
	if spent != int(route["phases_cost"]):
		return _fail("the journey cost %d phases, the route says %d" % [spent, int(route["phases_cost"])])
	return true


## Esc, then the pause menu's REGION MAP button: the player's way to the map.
func _open_region_map() -> Control:
	if _top_screen() != PAUSE_MENU_SCENE:
		_press_action(&"ui_cancel")
	if not await _wait_for(func() -> bool: return _top_screen() == PAUSE_MENU_SCENE, 10.0):
		_fail("Esc did not open the pause menu (top: '%s')" % _top_screen())
		return null
	await _frames(5)
	await _shoot("pause-menu")
	var pause := UIManager._stack.back() as Control
	var button := pause.find_child("RegionMapButton", true, false) as Button
	if button == null:
		_fail("pause menu has no RegionMapButton")
		return null
	button.pressed.emit()
	if not await _wait_for(func() -> bool: return _top_screen() == REGION_MAP_SCENE, 10.0):
		_fail("REGION MAP did not open the region map (top: '%s')" % _top_screen())
		return null
	await _frames(10)
	await _shoot("region-map")
	return UIManager._stack.back() as Control


func _answer_prompt() -> bool:
	var map := _region_map()
	if map == null:
		# A saved prompt with the map closed: reopening the map shows it again.
		map = await _open_region_map()
		if map == null:
			return false
	var prompt := map.find_child("EncounterPrompt", true, false) as Control
	if not await _wait_for(func() -> bool: return prompt.visible, 5.0):
		return _fail("plan is at AVOID_PROMPT but the map shows no prompt")
	await _shoot("ambush-prompt")
	var plan := GameFlow.travel_plan
	var slot := plan.next_unresolved_reached_index()
	(map.find_child("AvoidEncounterButton", true, false) as Button).pressed.emit()
	await _frames(5)
	_note("AVOID at step %d (slot %d, %s): plan now %s" % [
		plan.progress_step, slot, plan.encounter_schedule[slot]["encounter_id"],
		TravelPlan.State.keys()[GameFlow.travel_plan.state],
	])
	if GameFlow.travel_plan.state == TravelPlan.State.IN_BATTLE:
		return await _fight_ambush()
	return true


## A failed avoid opens the ambush where the party stands. KitAI plays the party, the way the
## class demo's autoplay does; this run checks the journey, not the fight.
func _fight_ambush() -> bool:
	if not await _wait_for(func() -> bool: return Battle.session_active and Battle.controller != null, 10.0):
		return await _record_stranded_ambush()
	var phases_at_fight := WorldClock.phase_count
	await _frames(20)
	_note("fight opened: chart %s, battle HUD open=%s, tree paused=%s, top screen '%s'" % [
		_chart_state(), _battle_hud_open(), get_tree().paused, _top_screen().get_file(),
	])
	await _shoot("ambush-opened")
	# What a player does to reach the fight: BACK off the map, then Esc to resume play.
	var map := _region_map()
	if map != null:
		(map.find_child("BackButton", true, false) as Button).pressed.emit()
		await _wait_for(func() -> bool: return not _region_map_open(), 5.0)
		await _frames(10)
		_note("BACK pressed: chart %s, top screen '%s'" % [_chart_state(), _top_screen().get_file()])
	if UIManager.is_open() and not _battle_hud_open():
		_press_action(&"ui_cancel")
		await _frames(30)
	_note("resumed: chart %s, battle HUD open=%s, tree paused=%s, top screen '%s'" % [
		_chart_state(), _battle_hud_open(), get_tree().paused, _top_screen().get_file(),
	])
	await _shoot("ambush-fight")
	Battle.controller.autoplay_allies = true
	var steps := 0
	while not Battle.ended and steps < 4000:
		if not Battle.controller.autoplay_step():
			await get_tree().process_frame
		steps += 1
		if steps % 20 == 0:
			await get_tree().process_frame
	if not Battle.ended:
		return _fail("the ambush never ended")
	_note("ambush ended: %s after %d autoplay steps" % [
		BattleResult.State.keys()[Battle.last_result.state], steps,
	])
	await _frames(30)
	await _shoot("ambush-ended")
	# The spoils reveal holds input until it is dismissed, like a player's Enter.
	for _press: int in 4:
		if UIManager._reward_reveal == null or not UIManager._reward_reveal.visible:
			break
		_press_action(&"ui_accept")
		await _frames(10)
	if not await _wait_for(func() -> bool: return not Battle.session_active, 20.0):
		return _fail("the fight ended but its session never closed")
	_fight_phases += WorldClock.phase_count - phases_at_fight
	_note("after the fight: plan %s, field %s, chart %s, top screen '%s'" % [
		TravelPlan.State.keys()[GameFlow.travel_plan.state], _scene_path().get_file(), _chart_state(),
		_top_screen().get_file(),
	])
	# Anything still stacked (a battle HUD left behind) is closed the way a player would.
	for _press: int in 3:
		if not UIManager.is_open():
			break
		_press_action(&"ui_cancel")
		await _frames(15)
	await _shoot("after-fight-field")
	if not Battle.last_result.succeeded():
		return _fail("the party lost the ambush; the journey path past a defeat is out of this run")
	return true


## The plan says IN_BATTLE but no fight opened. Record what the player is left with: the map as it
## stands, whether CANCEL is offered and works, and what a closed-and-reopened map offers.
func _record_stranded_ambush() -> bool:
	_note_party_cell("ambush")
	var map := _region_map()
	await _frames(10)
	await _shoot("stranded-map")
	if map != null:
		_note("stranded, map open: prompt visible=%s, CONTINUE visible=%s, CANCEL visible=%s" % [
			_visible(map, "EncounterPrompt"), _visible(map, "ContinueJourneyButton"),
			_visible(map, "CancelJourneyButton"),
		])
		GameFlow.cancel_journey()
		_note("GameFlow.cancel_journey() on the stranded plan: plan %s" % _plan_state())
		_press_action(&"ui_cancel")
		await _wait_for(func() -> bool: return not _region_map_open(), 5.0)
		await _frames(10)
	_note("map closed: top screen '%s', plan %s, battle session %s" % [
		_top_screen(), _plan_state(), Battle.session_active,
	])
	await _shoot("stranded-field")
	var reopened := await _open_region_map()
	if reopened != null:
		_note("map reopened: prompt visible=%s, CONTINUE visible=%s, CANCEL visible=%s, BEGIN disabled=%s" % [
			_visible(reopened, "EncounterPrompt"), _visible(reopened, "ContinueJourneyButton"),
			_visible(reopened, "CancelJourneyButton"),
			(reopened.find_child("TravelButton", true, false) as Button).disabled,
		])
	return _fail("the failed avoid set the plan IN_BATTLE but no fight opened — a dead end")


func _continue_from_field() -> bool:
	var map := await _open_region_map()
	if map == null:
		return false
	var button := map.find_child("ContinueJourneyButton", true, false) as Button
	if button == null or not button.visible:
		return _fail("the reopened map offers no CONTINUE for an EN_ROUTE plan")
	await _shoot("continue-offered")
	button.pressed.emit()
	_note("CONTINUE pressed at step %d/%d" % [GameFlow.travel_plan.progress_step, GameFlow.travel_plan.total_steps])
	return true


func _note_party_cell(where: String) -> void:
	var field := Battle._current_field_map()
	if field == null or field.iso_grid() == null:
		_note("party cell at %s: no field grid" % where)
		return
	var grid := field.iso_grid()
	var cell := grid.world_to_cell(field.player().global_position)
	_note("party cell at %s: %s in walking grid=%s blocked=%s" % [
		where, cell, grid.is_in_bounds(cell), grid.is_point_solid(cell),
	])


func _region_map() -> Control:
	for screen: Control in UIManager._stack:
		if screen.scene_file_path == REGION_MAP_SCENE:
			return screen
	return null


func _region_map_open() -> bool:
	return _region_map() != null


func _top_screen() -> String:
	return UIManager._stack.back().scene_file_path if UIManager.is_open() else ""


func _chart_state() -> String:
	var states: PackedStringArray = []
	for state_name: String in ["Active", "Paused", "Battle"]:
		var state := GameFlow.get_node_or_null("StateChart/Root/Playing/%s" % state_name)
		if state != null and bool(state.get("active")):
			states.append(state_name)
	return "/".join(states) if not states.is_empty() else "none"


func _battle_hud_open() -> bool:
	for screen: Control in UIManager._stack:
		if screen.scene_file_path == "res://ui/screens/battle.tscn":
			return true
	return false


func _plan_state() -> String:
	var plan := GameFlow.travel_plan
	return TravelPlan.State.keys()[plan.state] if plan != null else "none"


func _visible(root: Node, node_name: String) -> bool:
	var node := root.find_child(node_name, true, false) as CanvasItem
	return node != null and node.is_visible_in_tree()


func _text(root: Node, node_name: String) -> String:
	var label := root.find_child(node_name, true, false) as Label
	return label.text if label != null else "<no %s>" % node_name


func _press_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


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


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _frames(count: int) -> void:
	for _i: int in count:
		await get_tree().process_frame


func _shoot(label: String) -> void:
	_shots += 1
	var file_name := "%02d-%s.jpg" % [_shots, label]
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
	_note("JOURNEY-CAPTURE: FAILED — %s" % reason)
	return false
