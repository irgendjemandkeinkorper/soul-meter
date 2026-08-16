extends SceneTree
## FR-904 measurement-only benchmark for Gate T-9's populated-grid rendering load.
##
## This is provisional instrumentation. It exercises the production battle screen,
## GridBattlefieldModel, charge-time scheduler, BattleInterface tile renderer, and CT
## timeline, but it is not reference-hardware acceptance evidence.

const PerformanceBenchmark := preload("res://tools/performance_benchmark.gd")

const BENCHMARK_ID := "FR-904"
const SCENARIO_ID := "populated-grid-battle"
const ENCOUNTER_ID := &"dorthkor-vanguard"
const TARGET_SCENE := "res://ui/screens/battle.tscn"
const PRIMING_SCENE := "res://world/test_room.tscn"
const MAIN_MENU_SCENE := "res://ui/screens/main_menu.tscn"
const GRID_WIDTH := 8
const GRID_HEIGHT := 4
const FULL_DEPLOYMENT_SIZE := 3
const WARMUP_FRAMES := 120
const SAMPLE_COUNT := 600
const STAGE_TIMEOUT_FRAMES := 1800
const CHARGE_ELEMENT_ID := "strom"
const CHARGE_ELEMENT_COLOR := "#7BDFF2"

var _errors: Array[String] = []
var _game_flow: Node
var _game_state: Node
var _battle: Node
var _ground: TileMapLayer
var _battle_interface: Control
var _stage_region: Control
var _ct_timeline: Control
var _battle_event_usec := -1
var _battle_hud_interactive_usec := -1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_game_flow = root.get_node_or_null("GameFlow")
	_game_state = root.get_node_or_null("GameState")
	_battle = root.get_node_or_null("Battle")
	if _game_flow == null or _game_state == null or _battle == null:
		_add_error("Required GameFlow, GameState, or Battle autoload was unavailable.")
		_finish_with_error()
		return
	if not await _prime_game_flow():
		_finish_with_error()
		return
	if not _prepare_full_deployment():
		_finish_with_error()
		return

	_battle_event_usec = Time.get_ticks_usec()
	_battle.call("start", ENCOUNTER_ID)
	if bool(_battle.get("ended")):
		_add_error("The populated-grid encounter ended before the battle screen opened.")
		_finish_with_error()
		return
	if not _configure_populated_grid():
		_finish_with_error()
		return
	await _advance_deployment_to_battle()
	if not await _wait_for_battle_hud():
		_finish_with_error()
		return

	_emit_tile_state()
	var tiles_ready := await _wait_until(
		func() -> bool:
			return (
				is_instance_valid(_stage_region)
				and int(_stage_region.call("rendered_tile_count")) == GRID_WIDTH * GRID_HEIGHT
			),
		STAGE_TIMEOUT_FRAMES,
	)
	if not tiles_ready:
		_add_error("Timed out waiting for all populated-grid tiles to render.")
		_finish_with_error()
		return
	await process_frame
	_battle_hud_interactive_usec = Time.get_ticks_usec()

	for _frame: int in WARMUP_FRAMES:
		await process_frame

	var frame_times_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var node_counts: Array[float] = []
	for _sample: int in SAMPLE_COUNT:
		await process_frame
		frame_times_ms.append(
			float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		)
		draw_calls.append(
			float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		)
		node_counts.append(float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))

	var report := create_scenario_report(
		{
			"frame_time_ms": frame_times_ms,
			"draw_calls": draw_calls,
			"node_count": node_counts,
		},
		_environment_report(),
		_scenario_details(),
		SAMPLE_COUNT,
		WARMUP_FRAMES,
		_elapsed_ms(_battle_event_usec, _battle_hud_interactive_usec),
	)
	if not _errors.is_empty():
		report["status"] = "error"
		report["errors"] = _errors.duplicate()
	print(JSON.stringify(report))
	quit(0 if _errors.is_empty() else 1)


func _prime_game_flow() -> bool:
	var title_ready := await _wait_until(
		func() -> bool:
			return current_scene != null and current_scene.scene_file_path == MAIN_MENU_SCENE,
		STAGE_TIMEOUT_FRAMES,
	)
	if not title_ready:
		_add_error("Timed out waiting for GameFlow to enter the title state.")
		return false
	_game_flow.set("_target_scene", PRIMING_SCENE)
	_game_flow.call("send_event", &"new_game")
	var active_ready := await _wait_until(
		func() -> bool:
			return (
				current_scene != null
				and current_scene.scene_file_path == PRIMING_SCENE
				and not bool(_game_flow.get("_waiting_for_level"))
			),
		STAGE_TIMEOUT_FRAMES,
	)
	if not active_ready:
		_add_error("Timed out priming GameFlow's Active state.")
		return false
	await process_frame
	return true


func _advance_deployment_to_battle() -> void:
	_game_flow.call("send_event", &"enter_battle")
	await process_frame
	for _step: int in 3:
		_game_flow.call("send_event", &"deployment_next")
		await process_frame
	_game_flow.call("send_event", &"accept_slate")
	await process_frame


func _prepare_full_deployment() -> bool:
	var lead := _game_state.call("protagonist") as PartyMember
	if lead == null:
		_add_error("The benchmark could not find the existing protagonist party member.")
		return false
	var deployed: Array[PartyMember] = [lead]
	var candidates: Array[PartyMember] = []
	candidates.assign(_game_state.call("recruitable_candidates"))
	for candidate: PartyMember in candidates:
		if candidate.id == lead.id:
			continue
		deployed.append(candidate)
		if deployed.size() == FULL_DEPLOYMENT_SIZE:
			break
	if deployed.size() != FULL_DEPLOYMENT_SIZE:
		_add_error(
			"Full deployment requires %d existing party members, found %d."
			% [FULL_DEPLOYMENT_SIZE, deployed.size()]
		)
		return false
	_game_state.call("set_party", deployed)
	return true


func _configure_populated_grid() -> bool:
	var controller := _battle.get("controller") as CombatController
	if controller == null:
		_add_error("Battle did not create a CombatController for the benchmark encounter.")
		return false
	var rules := load("res://data/combat/combat_rules.tres").duplicate(true) as CombatRules
	if rules == null:
		_add_error("Could not load the production combat rules.")
		return false
	rules.use_grid_battlefield = true
	rules.use_charge_time = true
	var grid_model := GridBattlefieldModel.new()
	grid_model.configure(rules)
	_ground = _make_ground(GRID_WIDTH, GRID_HEIGHT)
	root.add_child(_ground)
	_ground.visible = false
	grid_model.build_grid(_ground)
	var actions: Array[CombatAction] = _battle.call("available_actions", true)
	controller.configure(actions, grid_model, rules)
	controller.start(_battle.get("allies"), _battle.get("enemies"), ENCOUNTER_ID)
	return (
		controller.battlefield is GridBattlefieldModel
		and _is_charge_time_scheduler(controller.scheduler)
	)


func _make_ground(width: int, height: int) -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i(0, 0))
	tile_set.add_source(source, 0)
	var layer := TileMapLayer.new()
	layer.name = "BenchmarkGridGround"
	layer.tile_set = tile_set
	for y: int in height:
		for x: int in width:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	return layer


func _wait_for_battle_hud() -> bool:
	var hud_ready := await _wait_until(
		func() -> bool:
			var ui_manager := root.get_node_or_null("UIManager")
			return (
				ui_manager != null
				and ui_manager.find_child("BattleInterface", true, false) != null
			),
		STAGE_TIMEOUT_FRAMES,
	)
	if not hud_ready:
		_add_error("Timed out waiting for the production battle HUD.")
		return false
	var ui_manager := root.get_node("UIManager")
	_battle_interface = ui_manager.find_child("BattleInterface", true, false) as Control
	if not is_instance_valid(_battle_interface):
		_add_error("The production BattleInterface was not present.")
		return false
	_stage_region = _battle_interface.find_child("Stage", true, false) as Control
	_ct_timeline = _battle_interface.find_child("TurnTimeline", true, false) as Control
	if not is_instance_valid(_stage_region) or not _stage_region.has_method("rendered_tile_count"):
		_add_error("The BattleInterface stage region was unavailable.")
		return false
	if not is_instance_valid(_ct_timeline):
		_add_error("The BattleInterface CT timeline was unavailable.")
		return false
	await process_frame
	if not _battle_interface.is_visible_in_tree() or not _ct_timeline.is_visible_in_tree():
		_add_error("The battle HUD or CT timeline was not visible.")
		return false
	return true


func _emit_tile_state() -> void:
	var event := CombatEvent.new()
	event.type = &"battlefield_updated"
	event.data = {
		"snapshot": (_battle.get("controller") as CombatController).snapshot(),
		"tiles": _tile_payload(),
	}
	_battle.call("_on_combat_event", event)


func _tile_payload() -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	for y: int in GRID_HEIGHT:
		for x: int in GRID_WIDTH:
			tiles.append(
				{
					"x": x,
					"y": y,
					"height_delta": 0,
					"charge_element_id": CHARGE_ELEMENT_ID,
					"charge_level": 1 + ((x + y) % 3),
					"element_color": CHARGE_ELEMENT_COLOR,
					"note": "benchmark fixture",
				}
			)
	return tiles


func _scenario_details() -> Dictionary:
	var controller := _battle.get("controller") as CombatController
	return {
		"ally_count": (_battle.get("allies") as Array).size(),
		"enemy_count": (_battle.get("enemies") as Array).size(),
		"tile_count": GRID_WIDTH * GRID_HEIGHT,
		"charged_tile_count": _tile_payload().size(),
		"battle_hud_visible": (
			is_instance_valid(_battle_interface) and _battle_interface.is_visible_in_tree()
		),
		"ct_timeline_visible": (
			is_instance_valid(_ct_timeline) and _ct_timeline.is_visible_in_tree()
		),
		"grid_battlefield_active": (
			controller != null and controller.battlefield is GridBattlefieldModel
		),
		"charge_time_active": (
			controller != null and _is_charge_time_scheduler(controller.scheduler)
		),
	}


func _is_charge_time_scheduler(scheduler: TurnScheduler) -> bool:
	if scheduler == null:
		return false
	var scheduler_script := scheduler.get_script() as Script
	return (
		scheduler_script != null
		and scheduler_script.resource_path
		== "res://globals/combat/charge_time_scheduler.gd"
	)


func _environment_report() -> Dictionary:
	return {
		"headless": DisplayServer.get_name() == "headless",
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"godot": Engine.get_version_info(),
	}


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in maximum_frames:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _finish_with_error() -> void:
	var report := create_scenario_report(
		{"frame_time_ms": [], "draw_calls": [], "node_count": []},
		_environment_report(),
		{
			"ally_count": 0,
			"enemy_count": 0,
			"tile_count": GRID_WIDTH * GRID_HEIGHT,
			"charged_tile_count": 0,
			"battle_hud_visible": false,
			"ct_timeline_visible": false,
		},
		SAMPLE_COUNT,
	)
	report["status"] = "error"
	report["errors"] = _errors.duplicate()
	print(JSON.stringify(report))
	quit(1)


func _add_error(message: String) -> void:
	if not _errors.has(message):
		_errors.append(message)
		push_error(message)


static func create_scenario_report(
	samples: Dictionary,
	environment: Dictionary,
	scenario_details: Dictionary,
	sample_count: int = SAMPLE_COUNT,
	warmup_frames: int = WARMUP_FRAMES,
	battle_entry_ms: float = -1.0,
) -> Dictionary:
	var report := PerformanceBenchmark.create_report(
		{"warmup_frames": warmup_frames, "sample_count": sample_count},
		samples,
		{
			"travel_transition": {
				"spans_ms": {
					"travel_request_to_loading_screen_visible": -1.0,
					"loading_screen_visible_to_resource_ready": -1.0,
					"resource_ready_to_scene_attached": -1.0,
					"scene_attached_to_npc_population_complete": -1.0,
					"npc_population_complete_to_first_interactive_frame": -1.0,
					"travel_request_to_first_interactive_frame": -1.0,
				},
			},
			"battle_entry": {"battle_event_to_hud_interactive": battle_entry_ms},
		},
		{
			"applicable": false,
			"spawned_npcs": 0,
			"idle_sprites": 0,
			"process_active": false,
			"runtime_scene_nodes": -1,
			"runtime_scene_sprite_2d_nodes": -1,
			"observed_work_per_idle_sprite_per_frame": [],
			"viewport_culling_present": false,
		},
		environment,
	)
	report["target_scene"] = TARGET_SCENE
	report["scene_baseline"] = {
		"authored_nodes": 1,
		"authored_sprite_2d_nodes": 0,
	}
	var scenario := {
		"id": SCENARIO_ID,
		"encounter_id": String(ENCOUNTER_ID),
		"grid_width": GRID_WIDTH,
		"grid_height": GRID_HEIGHT,
		"acceptance_evidence": false,
		"evidence_class": "provisional",
	}
	scenario.merge(scenario_details, true)
	report["scenario"] = scenario
	return report


static func _elapsed_ms(start_usec: int, finish_usec: int) -> float:
	if start_usec < 0 or finish_usec < 0:
		return -1.0
	return float(finish_usec - start_usec) / 1000.0
