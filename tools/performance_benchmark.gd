extends SceneTree
## FR-904 measurement-only benchmark for the starting-town runtime path.
##
## Canonical invocation:
##   godot --headless --path . --script res://tools/performance_benchmark.gd

const BENCHMARK_ID := "FR-904"
const TARGET_SCENE := "res://world/starting_town.tscn"
const PRIMING_SCENE := "res://world/test_room.tscn"
const MAIN_MENU_SCENE := "res://ui/screens/main_menu.tscn"
const LOADING_SCREEN := (
	"res://addons/maaacks_game_template/base/nodes/loading_screen/loading_screen.tscn"
)
const BATTLE_SCREEN := "res://ui/screens/battle.tscn"
const TOWN_SPAWNER_SCRIPT := "res://world/town_npc_spawner.gd"
const BATTLE_ACTOR_SCRIPT := "res://globals/battle_actor.gd"
const DEPLOYMENT_EVENTS := [
	&"enter_battle",
	&"deployment_next",
	&"deployment_next",
	&"deployment_next",
	&"accept_slate",
]
const WARMUP_FRAMES := 120
const SAMPLE_COUNT := 600
const STAGE_TIMEOUT_FRAMES := 1800
const AUTHORED_NODE_BASELINE := 269
const AUTHORED_SPRITE_2D_BASELINE := 105

var _errors: Array[String] = []
var _game_flow: Node
var _scene_loader: Node
var _battle: Node
var _travel_milestones_usec: Dictionary = {}
var _battle_event_usec := -1
var _battle_hud_interactive_usec := -1
var _observe_travel := false
var _observe_battle := false
var _town_root: Node
var _town_spawner: Node
var _battle_overlay: Control
var _spawned_npcs := 0
var _idle_sprites := 0
var _spawner_process_active := false


func _initialize() -> void:
	node_added.connect(_on_node_added)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_game_flow = root.get_node("GameFlow")
	_scene_loader = root.get_node("SceneLoader")
	_battle = root.get_node("Battle")
	if not await _prime_game_flow():
		_finish_with_error()
		return
	if not await _measure_travel_transition():
		_finish_with_error()
		return

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

	if not await _measure_battle_entry():
		_finish_with_error()
		return

	var samples: Dictionary = {
		"frame_time_ms": frame_times_ms,
		"draw_calls": draw_calls,
		"node_count": node_counts,
	}
	var report := create_report(
		{"warmup_frames": WARMUP_FRAMES, "sample_count": SAMPLE_COUNT},
		samples,
		_build_span_report(),
		_build_spawner_report(),
		_environment_report(),
	)
	if not _errors.is_empty():
		report["status"] = "error"
		report["errors"] = _errors.duplicate()
	print(JSON.stringify(report))
	quit(0 if _errors.is_empty() else 1)


func _prime_game_flow() -> bool:
	var title_ready := await _wait_until(
		func() -> bool:
			return (
				current_scene != null
				and current_scene.scene_file_path == MAIN_MENU_SCENE
			),
		STAGE_TIMEOUT_FRAMES,
	)
	if not title_ready:
		_add_error("Timed out waiting for GameFlow to enter the title state.")
		return false

	# Enter Active through the production chart without caching the benchmark target.
	# The actual measured request below still goes through GameFlow.travel().
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


func _measure_travel_transition() -> bool:
	_observe_travel = true
	_scene_loader.connect(&"scene_loaded", _on_target_resource_ready, CONNECT_ONE_SHOT)
	_travel_milestones_usec["travel_request"] = Time.get_ticks_usec()
	_game_flow.call("travel", TARGET_SCENE)
	var completed := await _wait_until(
		func() -> bool:
			return _travel_milestones_usec.has("first_interactive_frame"),
		STAGE_TIMEOUT_FRAMES,
	)
	_observe_travel = false
	if not completed:
		_add_error("Timed out measuring the starting-town travel transition.")
	return completed


func _measure_battle_entry() -> bool:
	_observe_battle = true
	_battle.connect(&"battle_started", _on_battle_event_fired, CONNECT_ONE_SHOT)
	var battle_actor_script := load(BATTLE_ACTOR_SCRIPT) as Script
	if battle_actor_script == null:
		_add_error("Could not load the benchmark BattleActor script.")
		return false
	var enemy := battle_actor_script.new() as Resource
	enemy.set("display_name", "Benchmark Enemy")
	enemy.set("hp", 30)
	enemy.set("max_hp", 30)
	enemy.set("attack", 5)
	enemy.set("defense", 2)
	_battle.call("start", enemy)
	if bool(_battle.get("ended")):
		_add_error("Benchmark battle ended before the overlay could be opened.")
		return false
	# Mirrors actors/enemy/enemy.gd, then traverses the mandatory deployment
	# substates before waiting for the battle overlay.
	await _advance_deployment_to_battle()
	var completed := await _wait_until(
		func() -> bool:
			return _battle_hud_interactive_usec >= 0,
		STAGE_TIMEOUT_FRAMES,
	)
	_observe_battle = false
	if not completed:
		_add_error("Timed out waiting for the battle overlay to accept input.")
	return completed


func _advance_deployment_to_battle() -> void:
	for event: StringName in DEPLOYMENT_EVENTS:
		_game_flow.call("send_event", event)
		await process_frame


func _on_node_added(node: Node) -> void:
	if _observe_travel and node.scene_file_path == LOADING_SCREEN:
		if node.is_node_ready():
			_on_loading_screen_ready(node)
		else:
			node.ready.connect(_on_loading_screen_ready.bind(node), CONNECT_ONE_SHOT)
	elif _observe_travel and node.scene_file_path == TARGET_SCENE:
		_town_root = node
		_record_travel_milestone("scene_attached")
		node.child_entered_tree.connect(_on_town_child_entered)
	elif _observe_battle and node.scene_file_path == BATTLE_SCREEN:
		_battle_overlay = node as Control
		if node.is_node_ready():
			_on_battle_overlay_ready()
		else:
			node.ready.connect(_on_battle_overlay_ready, CONNECT_ONE_SHOT)


func _on_loading_screen_ready(loading_screen: Node) -> void:
	if loading_screen is CanvasLayer and (loading_screen as CanvasLayer).visible:
		_record_travel_milestone("loading_screen_visible")
	else:
		_add_error("The loading-screen scene became ready without being visible.")


func _on_target_resource_ready() -> void:
	if _observe_travel:
		_record_travel_milestone("resource_ready")


func _on_town_child_entered(child: Node) -> void:
	var child_script := child.get_script() as Script
	if child_script != null and child_script.resource_path == TOWN_SPAWNER_SCRIPT:
		_town_spawner = child
		return
	if is_instance_valid(_town_spawner):
		_check_npc_population_complete.call_deferred()


func _check_npc_population_complete() -> void:
	if not _observe_travel or _travel_milestones_usec.has("npc_population_complete"):
		return
	if not is_instance_valid(_town_spawner):
		return
	var spawned_value: Variant = _town_spawner.call("spawned_npcs")
	if not spawned_value is Array:
		return
	var spawned := spawned_value as Array
	if spawned.is_empty():
		return
	_spawned_npcs = spawned.size()
	var idle_sprites_value: Variant = _town_spawner.get("_idle_sprites")
	_idle_sprites = (idle_sprites_value as Array).size() if idle_sprites_value is Array else 0
	_spawner_process_active = _town_spawner.is_processing()
	_record_travel_milestone("npc_population_complete")
	process_frame.connect(_on_first_interactive_frame, CONNECT_ONE_SHOT)


func _on_first_interactive_frame() -> void:
	if not is_instance_valid(_town_root):
		_add_error("Starting town was freed before its first interactive frame.")
		return
	var player := _town_root.find_child("Player", true, false)
	if player == null or paused:
		_add_error("Starting town's first post-population frame was not interactive.")
		return
	_record_travel_milestone("first_interactive_frame")


func _on_battle_event_fired() -> void:
	_battle_event_usec = Time.get_ticks_usec()


func _on_battle_overlay_ready() -> void:
	process_frame.connect(_on_battle_interactive_frame, CONNECT_ONE_SHOT)


func _on_battle_interactive_frame() -> void:
	if not is_instance_valid(_battle_overlay) or not _battle_overlay.is_visible_in_tree():
		_add_error("Battle overlay was not visible on its first post-ready frame.")
		return
	if not _has_enabled_visible_button(_battle_overlay):
		_add_error("Battle overlay had no visible enabled input control.")
		return
	_battle_hud_interactive_usec = Time.get_ticks_usec()


func _has_enabled_visible_button(node: Node) -> bool:
	if node is BaseButton:
		var button := node as BaseButton
		if button.is_visible_in_tree() and not button.disabled:
			return true
	for child: Node in node.get_children():
		if _has_enabled_visible_button(child):
			return true
	return false


func _record_travel_milestone(name: String) -> void:
	if not _travel_milestones_usec.has(name):
		_travel_milestones_usec[name] = Time.get_ticks_usec()


func _wait_until(predicate: Callable, maximum_frames: int) -> bool:
	for _frame: int in maximum_frames:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _build_span_report() -> Dictionary:
	var travel_spans := {
		"travel_request_to_loading_screen_visible": _elapsed_ms(
			"travel_request", "loading_screen_visible"
		),
		"loading_screen_visible_to_resource_ready": _elapsed_ms(
			"loading_screen_visible", "resource_ready"
		),
		"resource_ready_to_scene_attached": _elapsed_ms("resource_ready", "scene_attached"),
		"scene_attached_to_npc_population_complete": _elapsed_ms(
			"scene_attached", "npc_population_complete"
		),
		"npc_population_complete_to_first_interactive_frame": _elapsed_ms(
			"npc_population_complete", "first_interactive_frame"
		),
		"travel_request_to_first_interactive_frame": _elapsed_ms(
			"travel_request", "first_interactive_frame"
		),
	}
	return {
		"travel_transition": {
			"request_api": "GameFlow.travel",
			"target_scene": TARGET_SCENE,
			"spans_ms": travel_spans,
		},
		"battle_entry": {
			"boundary": "Battle.battle_started to visible Battle overlay with enabled input",
			"battle_event_to_hud_interactive": _duration_ms(
				_battle_event_usec, _battle_hud_interactive_usec
			),
		},
	}


func _elapsed_ms(from_name: String, to_name: String) -> float:
	if not _travel_milestones_usec.has(from_name) or not _travel_milestones_usec.has(to_name):
		return -1.0
	return _duration_ms(
		int(_travel_milestones_usec[from_name]), int(_travel_milestones_usec[to_name])
	)


func _build_spawner_report() -> Dictionary:
	var runtime_nodes := -1
	var runtime_sprite_2d_nodes := -1
	if is_instance_valid(_town_root):
		runtime_nodes = _count_nodes(_town_root)
		runtime_sprite_2d_nodes = _count_sprite_2d_nodes(_town_root)
	return {
		"spawned_npcs": _spawned_npcs,
		"idle_sprites": _idle_sprites,
		"process_active": _spawner_process_active,
		"runtime_scene_nodes": runtime_nodes,
		"runtime_scene_sprite_2d_nodes": runtime_sprite_2d_nodes,
		"observed_work_per_idle_sprite_per_frame": [
			"sin",
			"position_write",
			"rotation_write",
		],
		"viewport_culling_present": true,
	}


func _count_nodes(node: Node) -> int:
	var count := 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count


func _count_sprite_2d_nodes(node: Node) -> int:
	var count := 1 if node is Sprite2D else 0
	for child: Node in node.get_children():
		count += _count_sprite_2d_nodes(child)
	return count


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


func _finish_with_error() -> void:
	var report := create_report(
		{"warmup_frames": WARMUP_FRAMES, "sample_count": SAMPLE_COUNT},
		{"frame_time_ms": [], "draw_calls": [], "node_count": []},
		_build_span_report(),
		_build_spawner_report(),
		_environment_report(),
	)
	report["status"] = "error"
	report["errors"] = _errors.duplicate()
	print(JSON.stringify(report))
	quit(1)


func _add_error(message: String) -> void:
	if not _errors.has(message):
		_errors.append(message)
		push_error(message)


static func create_report(
	config: Dictionary,
	samples: Dictionary,
	spans: Dictionary,
	spawner: Dictionary,
	environment: Dictionary,
) -> Dictionary:
	var warmup_frames := int(config.get("warmup_frames", -1))
	var sample_count := int(config.get("sample_count", -1))
	var errors: Array[String] = []
	for sample_name: String in ["frame_time_ms", "draw_calls", "node_count"]:
		var values_value: Variant = samples.get(sample_name, [])
		if not values_value is Array:
			errors.append("%s samples must be an Array." % sample_name)
			continue
		var values := values_value as Array
		if values.size() != sample_count:
			errors.append(
				"%s sample count was %d, expected %d."
				% [sample_name, values.size(), sample_count]
			)

	var report := {
		"schema_version": "1.0",
		"benchmark_id": BENCHMARK_ID,
		"status": "ok" if errors.is_empty() else "error",
		"errors": errors,
		"target_scene": TARGET_SCENE,
		"scene_baseline": {
			"authored_nodes": AUTHORED_NODE_BASELINE,
			"authored_sprite_2d_nodes": AUTHORED_SPRITE_2D_BASELINE,
		},
		"measurement": {
			"warmup_frames": warmup_frames,
			"sample_count": sample_count,
			"frame_boundary": "one Performance.TIME_PROCESS reading after each process_frame",
		},
		"frame_time_ms": _summarize(samples.get("frame_time_ms", [])),
		"monitors": {
			"draw_calls": _summarize(samples.get("draw_calls", [])),
			"node_count": _summarize(samples.get("node_count", [])),
		},
		"spans": spans.duplicate(true),
		"town_npc_spawner": spawner.duplicate(true),
		"environment": environment.duplicate(true),
	}
	report["frame_time_ms"]["monitor"] = "Performance.TIME_PROCESS"
	report["frame_time_ms"]["unit"] = "ms"
	report["monitors"]["draw_calls"]["monitor"] = (
		"Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME"
	)
	report["monitors"]["node_count"]["monitor"] = "Performance.OBJECT_NODE_COUNT"
	return report


static func _summarize(values_value: Variant) -> Dictionary:
	if not values_value is Array:
		return {"sample_count": 0, "p50": 0.0, "p95": 0.0, "p99": 0.0}
	var values := values_value as Array
	return {
		"sample_count": values.size(),
		"p50": _percentile(values, 0.50),
		"p95": _percentile(values, 0.95),
		"p99": _percentile(values, 0.99),
	}


static func _percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array[float] = []
	for value: Variant in values:
		sorted_values.append(float(value))
	sorted_values.sort()
	var rank := maxi(0, ceili(percentile * float(sorted_values.size())) - 1)
	return sorted_values[mini(rank, sorted_values.size() - 1)]


static func _duration_ms(from_usec: int, to_usec: int) -> float:
	if from_usec < 0 or to_usec < from_usec:
		return -1.0
	return float(to_usec - from_usec) / 1000.0
