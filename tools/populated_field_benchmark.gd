extends SceneTree
## #282 F2 measurement-only benchmark for the D9 scale budget: a populated field.
##
## Mirrors `populated_grid_benchmark.gd`. It loads a production field through GameFlow, adds
## 100 synthesized `Hostile` instances registered through `FieldMap.register_hostile`, measures
## the idle field (no session: Area2D sensors only), then opens an ambient session through the
## production alert path, admits every synthesized hostile, and measures in-session frame time
## plus per-decision enemy AI wall-clock time while the party only yields or guards.
##
## This is provisional instrumentation. It does not optimize anything (AI batching, off-screen
## skipping and per-tick budgets are later #282 slices) and it is not reference-hardware
## acceptance evidence.
##
## Canonical invocation:
##   godot --headless --path . --script res://tools/populated_field_benchmark.gd -- --settle-ms 2000
## `--raw-samples` after the `--` adds every raw sample array under `measurement.raw_samples`;
## `--decision-target N` shortens (or lengthens) the decision window from its one-round default.

const PerformanceBenchmark := preload("res://tools/performance_benchmark.gd")
## Loaded at runtime, never preloaded: it names `Hostile`, `FieldMap` and `Battle`, whose
## scripts reference autoloads that do not exist yet when a `--script` harness is compiled.
const SYNTHESIZER_SCRIPT := "res://tools/populated_field_synthesizer.gd"

const BENCHMARK_ID := "FR-904"
const SCENARIO_ID := "populated-field"
const TARGET_SCENE := "res://world/test_room.tscn"
const MAIN_MENU_SCENE := "res://ui/screens/main_menu.tscn"
## D9: "100 hostiles on a map is a presence budget".
const HOSTILE_COUNT := 100
const PARTY_SIZE := 3
## D9: "enemy AI decision <= 2 ms averaged over a round on the FR-904 hardware". Reported as
## the reference line next to the measured mean; never a gate in this harness.
const D9_DECISION_BUDGET_MS := 2.0
const D9_SOURCE := "docs/architecture-same-map-combat.md D9"
## Benchmark fixture: keeps the party standing through every decision pass so the session
## cannot end in a defeat mid-measurement. Not a balance value.
const FIXTURE_ALLY_HP := 1_000_000
const WARMUP_FRAMES := 120
const SAMPLE_COUNT := 600
const DEFAULT_SETTLE_DURATION_MS := 2000
const STAGE_TIMEOUT_FRAMES := 1800
## The decision window drives ally turns (yield, or guard once the charge-time scheduler
## refuses a third consecutive wait) until this many enemy decisions were timed: one per
## admitted hostile, which is the "round" D9 words its budget over. Admission delays mean the
## first few ally turns usually resolve no enemy at all; those turns are kept and reported as
## the pure event/presentation overhead of a turn with no decision.
const DECISION_TARGET := HOSTILE_COUNT
## Bound on ally turns driven while chasing the target, so a session whose enemies never
## become ready cannot run the harness forever.
const ALLY_TURN_CAP := 60
const DECISION_EVENT_TYPES: Array[StringName] = [&"action_resolved", &"action_refused"]

var _errors: Array[String] = []
var _game_flow: Node
var _game_state: Node
var _battle: Node
var _synthesizer: Script
var _field: Node
var _synthesized: Array = []
var _planned_cells: Array[Vector2i] = []
var _enemy_ids: Dictionary = {}
var _pass_marks: Array[int] = []
var _first_alert_usec := -1
var _session_active_usec := -1
var _hud_visible_usec := -1
var _synthesis_ms := -1.0
var _setup_frame_times_ms: Array[float] = []
var _settle_gate: Dictionary = {}
var _idle_settle_gate: Dictionary = {}
var _admission: Dictionary = {}
var _nodes_before_synthesis := -1
var _nodes_after_synthesis := -1
var _off_plan_count := -1
var _off_plan_examples: Array[Dictionary] = []


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
	_prepare_party()
	_synthesizer = load(SYNTHESIZER_SCRIPT) as Script
	if _synthesizer == null:
		_add_error("Could not load the populated-field synthesizer.")
		_finish_with_error()
		return
	_field = _battle.call("_current_field_map") as Node
	if _field == null:
		_add_error("The primed field scene exposes no FieldMap.")
		_finish_with_error()
		return
	# Let arrival hooks, follower spawning and the authored hostiles' initial overlap checks
	# run before anything is measured; a spontaneous session here would poison the idle window.
	for _frame: int in 10:
		await process_frame
	if bool(_battle.get("session_active")):
		_add_error("A session opened on arrival; the idle window needs an unalerted field.")
		_finish_with_error()
		return

	_nodes_before_synthesis = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var synthesis_started := Time.get_ticks_usec()
	_planned_cells = _synthesizer.call("plan_for_field", _field, HOSTILE_COUNT)
	if _planned_cells.size() != HOSTILE_COUNT:
		_add_error(
			"Planned %d placement cells, needed %d." % [_planned_cells.size(), HOSTILE_COUNT]
		)
		_finish_with_error()
		return
	_synthesized = _synthesizer.call("synthesize_on_field", _field, _planned_cells)
	_synthesis_ms = _elapsed_ms(synthesis_started, Time.get_ticks_usec())
	if _synthesized.size() != HOSTILE_COUNT:
		_add_error("Synthesized %d hostiles, needed %d." % [_synthesized.size(), HOSTILE_COUNT])
		_finish_with_error()
		return
	await process_frame
	_nodes_after_synthesis = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if not bool(_synthesizer.call("hostiles_are_distinct", _synthesized)):
		_add_error("Two synthesized hostiles share one field cell.")
	# Read placement now: once the session runs, CombatOverlay moves the field nodes of every
	# hostile the scheduler moved, and that is combat, not a placement defect.
	_off_plan_count = int(_synthesizer.call("hostiles_off_plan", _synthesized, _planned_cells))
	_off_plan_examples = _synthesizer.call("off_plan_examples", _synthesized, _planned_cells, 3)
	# The sensors' deferred initial-overlap checks run on physics frames; wait for them.
	for _frame: int in 10:
		await process_frame
	if bool(_battle.get("session_active")):
		_add_error("Synthesis alerted a hostile; the keep-clear zones did not hold.")
		_finish_with_error()
		return

	# Window 1: the populated field with no session. This is the FR-904 field metric. The
	# TIME_PROCESS monitor publishes the worst frame of the last second, so the same fixed
	# settle discard the grid benchmark uses keeps synthesis out of the idle window.
	_idle_settle_gate = await _discard_post_setup_warmup("synthesis_complete")
	for _frame: int in WARMUP_FRAMES:
		await process_frame
	var idle_samples := await _sample_window(SAMPLE_COUNT)

	# Window 2: open the session through the production alert path and admit the rest.
	_start_setup_phase_sampling()
	if not await _open_session():
		_stop_setup_phase_sampling()
		_finish_with_error()
		return
	_admit_remaining()
	_apply_ally_hp_fixture()
	_settle_gate = await _discard_post_setup_warmup("all_hostiles_admitted")
	_stop_setup_phase_sampling()
	for _frame: int in WARMUP_FRAMES:
		await process_frame
	var session_samples := await _sample_window(SAMPLE_COUNT)

	# Window 3: enemy AI decisions.
	var ally_turns := await _run_decision_window()

	var report := create_scenario_report(
		idle_samples,
		session_samples,
		ally_turns,
		_admission,
		_environment_report(),
		_scenario_details(),
		SAMPLE_COUNT,
		WARMUP_FRAMES,
		_elapsed_ms(_first_alert_usec, _session_active_usec),
		_setup_frame_times_ms,
		_settle_gate,
		_elapsed_ms(_first_alert_usec, _hud_visible_usec),
		_requested_decision_target(),
		_idle_settle_gate,
	)
	if OS.get_cmdline_user_args().has("--raw-samples"):
		var decision_ms: Array[float] = []
		for turn: Dictionary in ally_turns:
			decision_ms.append_array(turn.get("decision_ms", []))
		var measurement := report.get("measurement", {}) as Dictionary
		measurement["raw_samples"] = {
			"idle_field": idle_samples.duplicate(true),
			"session": session_samples.duplicate(true),
			"setup_frame_time_ms": _setup_frame_times_ms.duplicate(),
			"admission_per_hostile_ms": (_admission.get("per_hostile_ms", []) as Array).duplicate(),
			"decision_ms": decision_ms,
		}
		report["measurement"] = measurement
	if not _errors.is_empty():
		report["status"] = "error"
		report["errors"] = _errors.duplicate()
	print(JSON.stringify(report))
	quit(0 if _errors.is_empty() else 1)


# --- session phase ---


## Opens the session the way play does: the first synthesized hostile accepts an alert, the
## field re-emits it, and GameFlow (watching the field since arrival) starts the session and
## enters the Battle state.
func _open_session() -> bool:
	var first := _synthesized[0] as Node
	_first_alert_usec = Time.get_ticks_usec()
	if not bool(first.call("request_alert")):
		_add_error("The first synthesized hostile refused its alert.")
		return false
	var opened := await _wait_until(
		func() -> bool:
			return bool(_battle.get("session_active")),
		STAGE_TIMEOUT_FRAMES,
	)
	if not opened:
		_add_error("GameFlow did not open a session from the first field alert.")
		return false
	_session_active_usec = Time.get_ticks_usec()
	var hud_ready := await _wait_until(
		func() -> bool:
			return _battle_hud() != null,
		STAGE_TIMEOUT_FRAMES,
	)
	if hud_ready:
		_hud_visible_usec = Time.get_ticks_usec()
	else:
		_add_error("The battle HUD did not appear after the session opened.")
	return true


## Every remaining synthesized hostile alerts through the production path and Battle admits it
## into the live session. Per-hostile wall-clock covers alert, field re-emit, admission (grid
## seat plus the A1 admission guarantee) and the hostile's state change.
func _admit_remaining() -> void:
	var per_hostile_ms: Array[float] = []
	var refusals: Array[Dictionary] = []
	var admitted := 1
	var started := Time.get_ticks_usec()
	for index: int in range(1, _synthesized.size()):
		var hostile := _synthesized[index] as Node
		var alert_started := Time.get_ticks_usec()
		var accepted := bool(hostile.call("request_alert"))
		per_hostile_ms.append(_elapsed_ms(alert_started, Time.get_ticks_usec()))
		if accepted and bool(_synthesizer.call("is_in_combat", hostile)):
			admitted += 1
		else:
			var refusal: Dictionary = (_battle.get("controller") as CombatController).last_refusal
			refusals.append(
				{
					"hostile": hostile.name,
					"alert_accepted": accepted,
					"state": int(_synthesizer.call("hostile_state", hostile)),
					"message": str(refusal.get("message", "")),
					"blocked_by": str(refusal.get("blocked_by", "")),
				}
			)
	_admission = {
		"admitted": admitted,
		"refused": refusals.size(),
		"refusals": refusals,
		"per_hostile_ms": per_hostile_ms,
		"total_ms": _elapsed_ms(started, Time.get_ticks_usec()),
	}
	if admitted != _synthesized.size():
		_add_error(
			"Admitted %d of %d synthesized hostiles." % [admitted, _synthesized.size()]
		)
	for actor: BattleActor in (_battle.get("enemies") as Array):
		_enemy_ids[actor.combat_id] = true


func _apply_ally_hp_fixture() -> void:
	for actor: BattleActor in (_battle.get("allies") as Array):
		actor.max_hp = FIXTURE_ALLY_HP
		actor.hp = FIXTURE_ALLY_HP


## Drives ally turns until DECISION_TARGET enemy decisions were timed or ALLY_TURN_CAP turns
## were spent. The controller drives synchronously, so an enemy decision is the wall-clock
## between consecutive enemy outcome events after the ally's call (the first one is measured
## from the call itself); a forced pass with no event folds into the next decision. A turn
## that resolves no enemy still costs its `turn_ended`/`turn_started` events and every
## listener on them, which is why zero-decision turns are recorded rather than discarded.
func _run_decision_window() -> Array[Dictionary]:
	var turns: Array[Dictionary] = []
	var controller := _battle.get("controller") as CombatController
	if controller == null:
		_add_error("The session has no CombatController to drive.")
		return turns
	controller.event_emitted.connect(_on_controller_event)
	var decisions_timed := 0
	var target := _requested_decision_target()
	for turn_index: int in ALLY_TURN_CAP:
		if decisions_timed >= target:
			break
		if int(controller.get("state")) != CombatController.State.ALLY_TURN:
			_add_error("Ally turn %d did not start on an ally turn." % turn_index)
			break
		_pass_marks.clear()
		var ticks_before := _tick_count(controller)
		var started := Time.get_ticks_usec()
		var ally_action := _drive_ally_turn()
		var finished := Time.get_ticks_usec()
		if ally_action == &"":
			_add_error("Ally turn %d could not yield or guard." % turn_index)
			break
		var decision_ms: Array[float] = []
		var previous := started
		for mark: int in _pass_marks:
			decision_ms.append(_elapsed_ms(previous, mark))
			previous = mark
		decisions_timed += decision_ms.size()
		turns.append(
			{
				"decisions": decision_ms.size(),
				"total_ms": _elapsed_ms(started, finished),
				"decision_ms": decision_ms,
				"ticks_elapsed": _tick_count(controller) - ticks_before,
				"ally_action": String(ally_action),
				"living_enemies": (_battle.call("living_enemies") as Array).size(),
			}
		)
		if bool(_battle.get("ended")):
			_add_error("The session ended during ally turn %d." % turn_index)
			break
		await process_frame
	if controller.event_emitted.is_connected(_on_controller_event):
		controller.event_emitted.disconnect(_on_controller_event)
	if decisions_timed < target:
		_add_error(
			"Timed %d enemy decisions in %d ally turns; the target was %d."
			% [decisions_timed, turns.size(), target]
		)
	return turns


func _requested_decision_target() -> int:
	var arguments := OS.get_cmdline_user_args()
	var argument_index := arguments.find("--decision-target")
	if argument_index < 0:
		return DECISION_TARGET
	if argument_index + 1 >= arguments.size():
		_add_error("--decision-target requires a positive integer count.")
		return DECISION_TARGET
	var raw_target := String(arguments[argument_index + 1])
	if not raw_target.is_valid_int() or int(raw_target) <= 0:
		_add_error("--decision-target requires a positive integer count.")
		return DECISION_TARGET
	return int(raw_target)


func _drive_ally_turn() -> StringName:
	var controller := _battle.get("controller") as CombatController
	if controller.end_turn():
		return &"yield"
	var guard: StringName = _synthesizer.call("guard_action_id")
	if bool(_battle.call("use_action", guard)):
		return guard
	return &""


func _on_controller_event(event: CombatEvent) -> void:
	if DECISION_EVENT_TYPES.has(event.type) and _enemy_ids.has(event.actor_id):
		_pass_marks.append(Time.get_ticks_usec())


func _tick_count(controller: CombatController) -> int:
	var scheduler := controller.scheduler
	if scheduler != null and scheduler.has_method("tick_count"):
		return int(scheduler.call("tick_count"))
	return 0


# --- sampling ---


## One reading per `process_frame`. `frame_time_ms` is the FR-904 `TIME_PROCESS` monitor, which
## the engine publishes as the worst process time of the last second; `frame_interval_ms` is
## the independent wall-clock between consecutive frames, per frame, kept alongside it.
func _sample_window(sample_count: int) -> Dictionary:
	var frame_times_ms: Array[float] = []
	var frame_intervals_ms: Array[float] = []
	var physics_times_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var node_counts: Array[float] = []
	for _sample: int in sample_count:
		var frame_start_usec := Time.get_ticks_usec()
		await process_frame
		frame_intervals_ms.append(_elapsed_ms(frame_start_usec, Time.get_ticks_usec()))
		frame_times_ms.append(
			float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		)
		physics_times_ms.append(
			float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		)
		draw_calls.append(
			float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		)
		node_counts.append(float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	return {
		"frame_time_ms": frame_times_ms,
		"frame_interval_ms": frame_intervals_ms,
		"physics_time_ms": physics_times_ms,
		"draw_calls": draw_calls,
		"node_count": node_counts,
	}


func _start_setup_phase_sampling() -> void:
	_setup_frame_times_ms.clear()
	if not process_frame.is_connected(_record_setup_frame_time):
		process_frame.connect(_record_setup_frame_time)


func _stop_setup_phase_sampling() -> void:
	if process_frame.is_connected(_record_setup_frame_time):
		process_frame.disconnect(_record_setup_frame_time)


func _record_setup_frame_time() -> void:
	_setup_frame_times_ms.append(
		float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	)


func _discard_post_setup_warmup(starts_after: String) -> Dictionary:
	var target_duration_ms := _requested_settle_duration_ms()
	var started_usec := Time.get_ticks_usec()
	var discarded_frames := 0
	while _elapsed_ms(started_usec, Time.get_ticks_usec()) < float(target_duration_ms):
		await process_frame
		discarded_frames += 1
	return {
		"method": "fixed_post_setup_warmup",
		"starts_after": starts_after,
		"target_duration_ms": target_duration_ms,
		"actual_duration_ms": _elapsed_ms(started_usec, Time.get_ticks_usec()),
		"discarded_frames": discarded_frames,
	}


func _requested_settle_duration_ms() -> int:
	var arguments := OS.get_cmdline_user_args()
	var argument_index := arguments.find("--settle-ms")
	if argument_index < 0:
		return DEFAULT_SETTLE_DURATION_MS
	if argument_index + 1 >= arguments.size():
		_add_error("--settle-ms requires a positive integer duration.")
		return DEFAULT_SETTLE_DURATION_MS
	var raw_duration := String(arguments[argument_index + 1])
	if not raw_duration.is_valid_int() or int(raw_duration) <= 0:
		_add_error("--settle-ms requires a positive integer duration.")
		return DEFAULT_SETTLE_DURATION_MS
	return int(raw_duration)


# --- flow priming ---


func _prime_game_flow() -> bool:
	var title_ready := await _wait_until(
		func() -> bool:
			return current_scene != null and current_scene.scene_file_path == MAIN_MENU_SCENE,
		STAGE_TIMEOUT_FRAMES,
	)
	if not title_ready:
		_add_error("Timed out waiting for GameFlow to enter the title state.")
		return false
	_game_flow.set("_target_scene", TARGET_SCENE)
	_game_flow.call("send_event", &"new_game")
	var active_ready := await _wait_until(
		func() -> bool:
			return (
				current_scene != null
				and current_scene.scene_file_path == TARGET_SCENE
				and not bool(_game_flow.get("_waiting_for_level"))
			),
		STAGE_TIMEOUT_FRAMES,
	)
	if not active_ready:
		_add_error("Timed out priming GameFlow's Active state.")
		return false
	await process_frame
	return true


## Grows the party toward PARTY_SIZE from existing recruit candidates, the same way the grid
## benchmark fills its deployment. Fewer is recorded, not refused: D9 is about hostiles.
func _prepare_party() -> void:
	var lead := _game_state.call("protagonist") as PartyMember
	if lead == null:
		return
	var party: Array[PartyMember] = [lead]
	var candidates: Array[PartyMember] = []
	candidates.assign(_game_state.call("recruitable_candidates"))
	for candidate: PartyMember in candidates:
		if candidate.id == lead.id:
			continue
		party.append(candidate)
		if party.size() == PARTY_SIZE:
			break
	_game_state.call("set_party", party)


func _battle_hud() -> Control:
	var ui_manager := root.get_node_or_null("UIManager")
	if ui_manager == null:
		return null
	var hud := ui_manager.find_child("BattleInterface", true, false) as Control
	return hud if hud != null and hud.is_visible_in_tree() else null


func _scenario_details() -> Dictionary:
	var authored := 0
	var field_total := 0
	if is_instance_valid(_field) and _synthesizer != null:
		field_total = int(_synthesizer.call("field_hostile_count", _field))
		authored = field_total - _synthesized.size()
	var planned: Array[Dictionary] = []
	for cell: Vector2i in _planned_cells:
		planned.append({"x": cell.x, "y": cell.y})
	return {
		"synthesized_hostile_count": _synthesized.size(),
		"authored_hostile_count": authored,
		"field_hostile_count": field_total,
		"party_size": (_game_state.get("party") as Array).size(),
		"ally_count": (_battle.get("allies") as Array).size(),
		"enemy_count": (_battle.get("enemies") as Array).size(),
		"fixture_unit_id": String(_synthesizer_constant("FIXTURE_UNIT_ID", &"")),
		"fixture_ally_hp": FIXTURE_ALLY_HP,
		"placement": {
			"method": "row_major_used_rect",
			"stride": _stride_report(),
			"clear_margin_px": float(_synthesizer_constant("PLACEMENT_CLEAR_MARGIN", -1.0)),
			"off_plan_count": _off_plan_count,
			"off_plan_examples": _off_plan_examples.duplicate(true),
			"cells": planned,
		},
		"synthesis_ms": _synthesis_ms,
		"runtime_nodes_before_synthesis": _nodes_before_synthesis,
		"runtime_nodes_after_synthesis": _nodes_after_synthesis,
		"battle_hud_visible": _battle_hud() != null,
		"session_active": bool(_battle.get("session_active")),
	}


func _stride_report() -> Dictionary:
	var stride: Vector2i = _synthesizer_constant("PLACEMENT_STRIDE", Vector2i(-1, -1))
	return {"x": stride.x, "y": stride.y}


func _synthesizer_constant(name: String, fallback: Variant) -> Variant:
	if _synthesizer == null:
		return fallback
	return _synthesizer.get_script_constant_map().get(name, fallback)


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
	_stop_setup_phase_sampling()
	var empty := {
		"frame_time_ms": [],
		"frame_interval_ms": [],
		"physics_time_ms": [],
		"draw_calls": [],
		"node_count": [],
	}
	var report := create_scenario_report(
		empty,
		empty,
		[],
		_admission,
		_environment_report(),
		_scenario_details() if _game_state != null and _battle != null else {},
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


# --- report ---


## Same top-level shape as the other FR-904 reports (`PerformanceBenchmark.create_report`):
## `frame_time_ms` is the idle populated field with no session, the FR-904 field metric. The
## session window and the enemy-decision timings live under `session`.
static func create_scenario_report(
	idle_samples: Dictionary,
	session_samples: Dictionary,
	ally_turns: Array[Dictionary],
	admission: Dictionary,
	environment: Dictionary,
	scenario_details: Dictionary,
	sample_count: int = SAMPLE_COUNT,
	warmup_frames: int = WARMUP_FRAMES,
	setup_duration_ms: float = -1.0,
	setup_frame_times_ms: Array[float] = [],
	settle_gate: Dictionary = {},
	hud_interactive_ms: float = -1.0,
	decision_target: int = DECISION_TARGET,
	idle_settle_gate: Dictionary = {},
) -> Dictionary:
	var report := PerformanceBenchmark.create_report(
		{"warmup_frames": warmup_frames, "sample_count": sample_count},
		idle_samples,
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
			"battle_entry": {
				"boundary": "first field alert to visible BattleInterface",
				"battle_event_to_hud_interactive": hud_interactive_ms,
			},
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
	var monitors := report.get("monitors", {}) as Dictionary
	monitors["physics_time_ms"] = PerformanceBenchmark._summarize(
		idle_samples.get("physics_time_ms", [])
	)
	monitors["physics_time_ms"]["monitor"] = "Performance.TIME_PHYSICS_PROCESS"
	monitors["physics_time_ms"]["unit"] = "ms"
	monitors["frame_interval_ms"] = PerformanceBenchmark._summarize(
		idle_samples.get("frame_interval_ms", [])
	)
	monitors["frame_interval_ms"]["monitor"] = "Time.get_ticks_usec between process_frame"
	monitors["frame_interval_ms"]["unit"] = "ms"
	report["monitors"] = monitors
	report["frame_time_ms"]["window"] = "idle_field_no_session"

	var setup_frame_time := PerformanceBenchmark._summarize(setup_frame_times_ms)
	setup_frame_time["monitor"] = "Performance.TIME_PROCESS"
	setup_frame_time["unit"] = "ms"
	report["setup_phase"] = {
		"duration_ms": setup_duration_ms,
		"window": "first_alert_to_session_active",
		"frame_time_ms": setup_frame_time,
	}
	var measurement := report.get("measurement", {}) as Dictionary
	measurement["settle_gate"] = settle_gate.duplicate(true)
	measurement["idle_settle_gate"] = idle_settle_gate.duplicate(true)
	report["measurement"] = measurement
	report["target_scene"] = TARGET_SCENE
	report["scene_baseline"] = {
		"authored_nodes": -1,
		"authored_sprite_2d_nodes": -1,
	}

	var session_frame_time := PerformanceBenchmark._summarize(
		session_samples.get("frame_time_ms", [])
	)
	session_frame_time["monitor"] = "Performance.TIME_PROCESS"
	session_frame_time["unit"] = "ms"
	session_frame_time["window"] = "session_all_admitted_ally_turn_pending"
	var session_physics := PerformanceBenchmark._summarize(
		session_samples.get("physics_time_ms", [])
	)
	session_physics["monitor"] = "Performance.TIME_PHYSICS_PROCESS"
	session_physics["unit"] = "ms"
	var session_draw_calls := PerformanceBenchmark._summarize(
		session_samples.get("draw_calls", [])
	)
	session_draw_calls["monitor"] = "Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME"
	var session_node_count := PerformanceBenchmark._summarize(
		session_samples.get("node_count", [])
	)
	session_node_count["monitor"] = "Performance.OBJECT_NODE_COUNT"
	var session_interval := PerformanceBenchmark._summarize(
		session_samples.get("frame_interval_ms", [])
	)
	session_interval["monitor"] = "Time.get_ticks_usec between process_frame"
	session_interval["unit"] = "ms"
	report["session"] = {
		"frame_time_ms": session_frame_time,
		"monitors": {
			"frame_interval_ms": session_interval,
			"physics_time_ms": session_physics,
			"draw_calls": session_draw_calls,
			"node_count": session_node_count,
		},
		"admission": create_admission_report(admission),
		"ai_decisions": create_decision_report(ally_turns, decision_target),
	}

	var scenario := {
		"id": SCENARIO_ID,
		"hostile_budget": HOSTILE_COUNT,
		"decision_target_default": DECISION_TARGET,
		"ally_turn_cap": ALLY_TURN_CAP,
		"acceptance_evidence": false,
		"evidence_class": "provisional",
	}
	scenario.merge(scenario_details, true)
	report["scenario"] = scenario
	return report


static func create_admission_report(admission: Dictionary) -> Dictionary:
	var per_hostile := summarize_timings(admission.get("per_hostile_ms", []))
	return {
		"path": "Hostile.request_alert -> FieldMap.hostile_alerted -> Battle.admit",
		"admitted": int(admission.get("admitted", 0)),
		"refused": int(admission.get("refused", 0)),
		"refusals": (admission.get("refusals", []) as Array).duplicate(true),
		"total_ms": float(admission.get("total_ms", -1.0)),
		"per_hostile_ms": per_hostile,
	}


## Flattens the per-turn decision timings into one distribution and keeps each ally turn's
## totals. `mean_ms` is the number D9 words its budget in; it is reported next to the budget,
## never gated, because this harness runs wherever it is invoked, not on the FR-904 hardware.
## `zero_decision_turn_ms` is the cost of an ally turn that resolved no enemy: two turn events
## and every synchronous listener on them, a directional read on per-event overhead.
static func create_decision_report(
	ally_turns: Array[Dictionary], decision_target: int = DECISION_TARGET
) -> Dictionary:
	var all_decisions: Array[float] = []
	var zero_decision_turns: Array[float] = []
	var per_turn: Array[Dictionary] = []
	var ticks_total := 0
	for turn: Dictionary in ally_turns:
		var decision_ms: Array = turn.get("decision_ms", [])
		var turn_total := 0.0
		for value: Variant in decision_ms:
			all_decisions.append(float(value))
			turn_total += float(value)
		var total_ms := float(turn.get("total_ms", turn_total))
		if decision_ms.is_empty():
			zero_decision_turns.append(total_ms)
		ticks_total += int(turn.get("ticks_elapsed", 0))
		per_turn.append(
			{
				"decisions": decision_ms.size(),
				"total_ms": total_ms,
				"mean_ms_per_decision": (
					turn_total / float(decision_ms.size()) if not decision_ms.is_empty() else 0.0
				),
				"ticks_elapsed": int(turn.get("ticks_elapsed", 0)),
				"ally_action": str(turn.get("ally_action", "")),
				"living_enemies": int(turn.get("living_enemies", 0)),
			}
		)
	var summary := summarize_timings(all_decisions)
	return {
		"method": (
			"Wall-clock between consecutive enemy action_resolved/action_refused events while "
			+ "the controller drives synchronously after an ally yield or guard; includes event "
			+ "emission, snapshot and synchronous listeners. Silent forced passes fold into the "
			+ "next decision."
		),
		"ally_turns": per_turn.size(),
		"decision_target": decision_target,
		"reached_target": all_decisions.size() >= decision_target,
		"decision_count": all_decisions.size(),
		"ticks_elapsed": ticks_total,
		"per_decision_ms": summary,
		"mean_ms": float(summary.get("mean", 0.0)),
		"d9_budget_ms": D9_DECISION_BUDGET_MS,
		"d9_budget_source": D9_SOURCE,
		"mean_within_d9_budget": (
			not all_decisions.is_empty() and float(summary.get("mean", 0.0)) <= D9_DECISION_BUDGET_MS
		),
		"zero_decision_turns": zero_decision_turns.size(),
		"zero_decision_turn_ms": summarize_timings(zero_decision_turns),
		"per_turn": per_turn,
	}


static func summarize_timings(values_value: Variant) -> Dictionary:
	var summary := PerformanceBenchmark._summarize(values_value)
	var total := 0.0
	var maximum := 0.0
	var count := 0
	if values_value is Array:
		for value: Variant in (values_value as Array):
			total += float(value)
			maximum = maxf(maximum, float(value))
			count += 1
	summary["mean"] = total / float(count) if count > 0 else 0.0
	summary["max"] = maximum
	summary["unit"] = "ms"
	return summary


static func _elapsed_ms(start_usec: int, finish_usec: int) -> float:
	if start_usec < 0 or finish_usec < 0:
		return -1.0
	return float(finish_usec - start_usec) / 1000.0
