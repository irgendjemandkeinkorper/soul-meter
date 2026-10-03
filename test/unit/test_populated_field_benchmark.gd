extends GdUnitTestSuite
## #282 F2 slice 1: the populated-field benchmark's synthesizer and report shape.
##
## The synthesizer is what makes the measurement mean something: 100 hostiles, every one
## registered with the field, seated on distinct cells, placed the same way on every run, and
## none of them close enough to the party to open a session before the idle window.

const PopulatedFieldBenchmark := preload("res://tools/populated_field_benchmark.gd")
const Synthesizer := preload("res://tools/populated_field_synthesizer.gd")
const TEST_ROOM_SCENE := "res://world/test_room.tscn"

var _game_state_before: Dictionary
var _scene: Node


## Instantiating chapter scenes runs their arrival hooks (flags, checkpoint requests);
## restore GameState so no suite downstream inherits them.
func before_test() -> void:
	_game_state_before = GameState.to_dict().duplicate(true)


func after_test() -> void:
	if is_instance_valid(_scene):
		_scene.queue_free()
		await get_tree().process_frame
	_scene = null
	GameState.from_dict(_game_state_before)


func _field() -> FieldMap:
	_scene = (load(TEST_ROOM_SCENE) as PackedScene).instantiate()
	add_child(_scene)
	await get_tree().process_frame
	return _scene.find_child("FieldMap", true, false) as FieldMap


func test_plan_cells_is_deterministic_distinct_and_clear_of_the_party() -> void:
	var field := await _field()
	assert_object(field).is_not_null()
	var grid := field.iso_grid()
	assert_object(grid).is_not_null()
	var zones := Synthesizer.keep_clear_zones(field)
	assert_int(zones.size()).override_failure_message(
		"the player and the authored hostiles must each contribute a keep-clear zone"
	).is_greater_equal(1 + field.hostiles().size())

	var first := Synthesizer.plan_cells(grid, PopulatedFieldBenchmark.HOSTILE_COUNT, zones)
	var second := Synthesizer.plan_cells(grid, PopulatedFieldBenchmark.HOSTILE_COUNT, zones)
	assert_int(first.size()).is_equal(PopulatedFieldBenchmark.HOSTILE_COUNT)
	assert_array(second).override_failure_message("placement must not vary between calls").is_equal(first)

	var seen: Dictionary = {}
	for cell: Vector2i in first:
		assert_bool(seen.has(cell)).override_failure_message("cell %s planned twice" % cell).is_false()
		seen[cell] = true
		assert_bool(grid.is_blocked_for(cell)).override_failure_message(
			"cell %s is blocked on the shared grid" % cell
		).is_false()
		var center := grid.cell_to_world(cell)
		for zone: Dictionary in zones:
			assert_float(center.distance_to(zone["position"])).override_failure_message(
				"cell %s sits inside a keep-clear zone" % cell
			).is_greater(float(zone["radius"]))


func test_synthesizer_registers_one_hundred_idle_hostiles_on_distinct_cells() -> void:
	var field := await _field()
	var grid := field.iso_grid()
	var authored := field.hostiles().size()
	var cells := Synthesizer.plan_cells(
		grid, PopulatedFieldBenchmark.HOSTILE_COUNT, Synthesizer.keep_clear_zones(field)
	)
	var hostiles := Synthesizer.synthesize_hostiles(field, cells)
	assert_int(hostiles.size()).is_equal(PopulatedFieldBenchmark.HOSTILE_COUNT)
	# The sensors' deferred initial-overlap checks run on physics frames; let them fire so a
	# hostile that could see the party has had every chance to alert before we assert IDLE.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	assert_int(field.hostiles().size()).is_equal(authored + PopulatedFieldBenchmark.HOSTILE_COUNT)
	assert_int(Synthesizer.off_plan_count(hostiles, cells)).override_failure_message(
		"every hostile must stand on the cell it was planned for"
	).is_equal(0)
	var seen: Dictionary = {}
	for hostile: Hostile in hostiles:
		var cell := hostile.sync_cell()
		assert_bool(seen.has(cell)).override_failure_message(
			"two hostiles stand on %s" % cell
		).is_false()
		seen[cell] = true
		assert_bool(_is_registered_with(hostile, field)).override_failure_message(
			"%s was not registered through FieldMap.register_hostile" % hostile.name
		).is_true()
		assert_int(hostile.state).override_failure_message(
			"%s left IDLE during synthesis" % hostile.name
		).is_equal(Hostile.State.IDLE)
		assert_bool(hostile.is_processing()).is_false()
		assert_bool(hostile.is_physics_processing()).is_false()
		assert_str(String(hostile.group_id)).override_failure_message(
			"synthesized hostiles belong to no authored encounter group"
		).is_empty()
		assert_object(hostile.battle_actor()).is_not_null()


func test_report_keeps_the_fr904_shape_and_adds_session_and_decision_blocks() -> void:
	var idle := {
		"frame_time_ms": [1.0, 2.0, 3.0],
		"frame_interval_ms": [6.0, 7.0, 8.0],
		"physics_time_ms": [0.2, 0.3, 0.4],
		"draw_calls": [0.0, 0.0, 0.0],
		"node_count": [900.0, 900.0, 900.0],
	}
	var in_session := {
		"frame_time_ms": [4.0, 5.0, 6.0],
		"frame_interval_ms": [9.0, 10.0, 11.0],
		"physics_time_ms": [0.5, 0.6, 0.7],
		"draw_calls": [0.0, 0.0, 0.0],
		"node_count": [950.0, 950.0, 950.0],
	}
	var ally_turns: Array[Dictionary] = [
		{"decisions": 0, "total_ms": 7.0, "decision_ms": [], "ticks_elapsed": 0, "ally_action": "yield", "living_enemies": 100},
		{"decisions": 3, "total_ms": 9.0, "decision_ms": [1.0, 3.0, 5.0], "ticks_elapsed": 40, "ally_action": "yield", "living_enemies": 100},
		{"decisions": 2, "total_ms": 4.0, "decision_ms": [1.0, 3.0], "ticks_elapsed": 20, "ally_action": "guard", "living_enemies": 100},
	]
	var admission := {
		"admitted": 100,
		"refused": 0,
		"refusals": [],
		"per_hostile_ms": [0.5, 1.5, 2.5, 3.5],
		"total_ms": 8.0,
	}
	var report: Dictionary = PopulatedFieldBenchmark.create_scenario_report(
		idle,
		in_session,
		ally_turns,
		admission,
		{"headless": true, "renderer": "dummy"},
		{
			"synthesized_hostile_count": 100,
			"authored_hostile_count": 2,
			"field_hostile_count": 102,
			"ally_count": 3,
			"enemy_count": 100,
			"battle_hud_visible": true,
		},
		3,
		30,
		120.0,
		[50.0, 20.0, 2.0],
		{
			"method": "fixed_post_setup_warmup",
			"starts_after": "all_hostiles_admitted",
			"target_duration_ms": 2000,
			"actual_duration_ms": 2001.0,
			"discarded_frames": 300,
		},
		140.0,
		100,
		{
			"method": "fixed_post_setup_warmup",
			"starts_after": "synthesis_complete",
			"target_duration_ms": 2000,
			"actual_duration_ms": 2000.5,
			"discarded_frames": 290,
		},
	)

	# The FR-904 envelope every benchmark report shares.
	assert_str(report["schema_version"]).is_equal("1.0")
	assert_str(report["benchmark_id"]).is_equal("FR-904")
	assert_str(report["status"]).is_equal("ok")
	assert_str(report["target_scene"]).is_equal("res://world/test_room.tscn")
	assert_bool(report.has_all(["frame_time_ms", "monitors", "spans", "environment", "setup_phase"])).is_true()
	assert_int(report["measurement"]["warmup_frames"]).is_equal(30)
	assert_int(report["measurement"]["sample_count"]).is_equal(3)
	assert_int(report["frame_time_ms"]["sample_count"]).is_equal(3)
	assert_bool(report["frame_time_ms"].has_all(["p50", "p95", "p99"])).is_true()
	assert_str(report["frame_time_ms"]["window"]).is_equal("idle_field_no_session")
	assert_bool(
		report["monitors"].has_all(["draw_calls", "node_count", "physics_time_ms", "frame_interval_ms"])
	).is_true()
	assert_float(report["monitors"]["frame_interval_ms"]["p50"]).is_equal(7.0)
	assert_float(report["spans"]["battle_entry"]["battle_event_to_hud_interactive"]).is_equal(140.0)
	assert_float(report["setup_phase"]["duration_ms"]).is_equal(120.0)
	assert_str(report["setup_phase"]["window"]).is_equal("first_alert_to_session_active")
	assert_float(report["setup_phase"]["frame_time_ms"]["p95"]).is_equal(50.0)
	assert_str(report["measurement"]["settle_gate"]["starts_after"]).is_equal("all_hostiles_admitted")
	assert_str(report["measurement"]["idle_settle_gate"]["starts_after"]).is_equal("synthesis_complete")

	# Scenario identity and the provisional label.
	var scenario: Dictionary = report["scenario"]
	assert_str(scenario["id"]).is_equal("populated-field")
	assert_int(scenario["hostile_budget"]).is_equal(100)
	assert_int(scenario["synthesized_hostile_count"]).is_equal(100)
	assert_int(scenario["enemy_count"]).is_equal(100)
	assert_bool(scenario["acceptance_evidence"]).is_false()
	assert_str(scenario["evidence_class"]).is_equal("provisional")

	# The session block: in-session frame window, admission, and the D9 decision distribution.
	var session: Dictionary = report["session"]
	assert_int(session["frame_time_ms"]["sample_count"]).is_equal(3)
	assert_float(session["frame_time_ms"]["p50"]).is_equal(5.0)
	assert_bool(
		session["monitors"].has_all(["frame_interval_ms", "physics_time_ms", "draw_calls", "node_count"])
	).is_true()
	assert_float(session["monitors"]["frame_interval_ms"]["p50"]).is_equal(10.0)
	assert_int(session["admission"]["admitted"]).is_equal(100)
	assert_float(session["admission"]["per_hostile_ms"]["mean"]).is_equal(2.0)
	assert_float(session["admission"]["per_hostile_ms"]["max"]).is_equal(3.5)
	var decisions: Dictionary = session["ai_decisions"]
	assert_int(decisions["ally_turns"]).is_equal(3)
	assert_int(decisions["decision_count"]).is_equal(5)
	assert_int(decisions["ticks_elapsed"]).is_equal(60)
	assert_int(decisions["decision_target"]).is_equal(100)
	assert_bool(decisions["reached_target"]).is_false()
	assert_float(decisions["mean_ms"]).is_equal(2.6)
	assert_float(decisions["per_decision_ms"]["max"]).is_equal(5.0)
	assert_float(decisions["d9_budget_ms"]).is_equal(2.0)
	assert_bool(decisions["mean_within_d9_budget"]).is_false()
	assert_int(decisions["zero_decision_turns"]).is_equal(1)
	assert_float(decisions["zero_decision_turn_ms"]["mean"]).is_equal(7.0)
	assert_int((decisions["per_turn"] as Array).size()).is_equal(3)
	assert_float(decisions["per_turn"][1]["mean_ms_per_decision"]).is_equal(3.0)
	assert_str(decisions["per_turn"][2]["ally_action"]).is_equal("guard")


func test_report_flags_missing_samples_as_an_error() -> void:
	var empty := {
		"frame_time_ms": [], "frame_interval_ms": [], "physics_time_ms": [], "draw_calls": [], "node_count": []
	}
	var report: Dictionary = PopulatedFieldBenchmark.create_scenario_report(
		empty, empty, [], {}, {}, {}, 3
	)
	assert_str(report["status"]).is_equal("error")
	assert_array(report["errors"]).is_not_empty()
	assert_int(report["session"]["ai_decisions"]["decision_count"]).is_equal(0)
	assert_bool(report["session"]["ai_decisions"]["reached_target"]).is_false()
	assert_bool(report["session"]["ai_decisions"]["mean_within_d9_budget"]).is_false()


func _is_registered_with(hostile: Hostile, field: FieldMap) -> bool:
	for connection: Dictionary in hostile.alerted.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == field:
			return true
	return false
