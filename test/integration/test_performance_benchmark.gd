extends GdUnitTestSuite

const PerformanceBenchmark := preload("res://tools/performance_benchmark.gd")
const PopulatedGridBenchmark := preload("res://tools/populated_grid_benchmark.gd")


func test_report_schema_honors_warmup_and_sample_counts() -> void:
	var report: Dictionary = PerformanceBenchmark.create_report(
		{"warmup_frames": 3, "sample_count": 4},
		{
			"frame_time_ms": [1.0, 2.0, 3.0, 4.0],
			"draw_calls": [5.0, 6.0, 7.0, 8.0],
			"node_count": [269.0, 269.0, 269.0, 269.0],
		},
		{
			"travel_transition": {
				"spans_ms": {
					"travel_request_to_loading_screen_visible": 1.0,
					"loading_screen_visible_to_resource_ready": 2.0,
					"resource_ready_to_scene_attached": 3.0,
					"scene_attached_to_npc_population_complete": 4.0,
					"npc_population_complete_to_first_interactive_frame": 5.0,
					"travel_request_to_first_interactive_frame": 15.0,
				},
			},
			"battle_entry": {"battle_event_to_hud_interactive": 6.0},
		},
		{
			"spawned_npcs": 60,
			"idle_sprites": 60,
			"process_active": true,
		},
		{"headless": true, "renderer": "dummy"},
	)

	assert_str(report["schema_version"]).is_equal("1.0")
	assert_str(report["benchmark_id"]).is_equal("FR-904")
	assert_int(report["measurement"]["warmup_frames"]).is_equal(3)
	assert_int(report["measurement"]["sample_count"]).is_equal(4)
	assert_int(report["frame_time_ms"]["sample_count"]).is_equal(4)
	assert_bool(report["frame_time_ms"].has_all(["p50", "p95", "p99"])).is_true()
	assert_bool(report["monitors"].has_all(["draw_calls", "node_count"])).is_true()
	assert_bool(
		report["spans"]["travel_transition"]["spans_ms"].has_all(
			[
				"travel_request_to_loading_screen_visible",
				"loading_screen_visible_to_resource_ready",
				"resource_ready_to_scene_attached",
				"scene_attached_to_npc_population_complete",
				"npc_population_complete_to_first_interactive_frame",
				"travel_request_to_first_interactive_frame",
			]
		)
	).is_true()
	assert_bool(
		report["spans"]["battle_entry"].has("battle_event_to_hud_interactive")
	).is_true()
	assert_int(report["scene_baseline"]["authored_nodes"]).is_equal(269)
	assert_int(report["scene_baseline"]["authored_sprite_2d_nodes"]).is_equal(105)
	_assert_populated_grid_report_keeps_fr904_metrics_and_describes_rendered_load()
	_assert_attribution_report_names_largest_measured_bucket()


func test_report_rejects_sample_count_mismatch() -> void:
	var report: Dictionary = PerformanceBenchmark.create_report(
		{"warmup_frames": 2, "sample_count": 3},
		{
			"frame_time_ms": [1.0, 2.0],
			"draw_calls": [1.0, 2.0],
			"node_count": [1.0, 2.0],
		},
		{},
		{},
		{},
	)

	assert_str(report["status"]).is_equal("error")
	assert_array(report["errors"]).is_not_empty()


func _assert_attribution_report_names_largest_measured_bucket() -> void:
	var attribution: Dictionary = PopulatedGridBenchmark.create_attribution_report(
		{
			"full_before": _profile_window([12.0, 14.0, 16.0]),
			"without_tile_stage": _profile_window([10.0, 11.0, 12.0]),
			"without_ct_timeline": _profile_window([11.0, 12.0, 13.0]),
			"without_other_hud": _profile_window([9.0, 10.0, 11.0]),
			"without_battle_interface": _profile_window([6.0, 7.0, 8.0]),
			"full_after": _profile_window([13.0, 15.0, 17.0]),
		},
		3,
		30,
	)

	assert_str(attribution["method"]).contains("visibility ablation")
	assert_int(attribution["sample_count_per_window"]).is_equal(3)
	assert_int(attribution["warmup_frames_per_window"]).is_equal(30)
	assert_str(attribution["top_cost"]["id"]).is_equal("engine_background_floor")
	assert_float(attribution["top_cost"]["attributed_p95_ms"]).is_equal(8.0)
	assert_bool(
		attribution["buckets"].has_all(
			[
				"setup_carryover",
				"charged_tile_stage",
				"ct_timeline",
				"other_battle_hud",
				"engine_background_floor",
			]
		)
	).is_true()
	assert_bool(
		attribution["windows"]["full_before"].has_all(
			[
				"frame_time_ms",
				"frame_interval_ms",
				"physics_time_ms",
				"navigation_time_ms",
				"draw_calls",
			]
		)
	).is_true()


func _assert_populated_grid_report_keeps_fr904_metrics_and_describes_rendered_load() -> void:
	var report: Dictionary = PopulatedGridBenchmark.create_scenario_report(
		{
			"frame_time_ms": [1.0, 2.0, 3.0],
			"draw_calls": [10.0, 11.0, 12.0],
			"node_count": [300.0, 301.0, 302.0],
		},
		{"headless": false, "renderer": "gl_compatibility"},
		{
			"ally_count": 3,
			"enemy_count": 2,
			"tile_count": 32,
			"charged_tile_count": 32,
			"battle_hud_visible": true,
			"ct_timeline_visible": true,
		},
		3,
		30,
		105.0,
		[80.0, 40.0, 2.0],
		{
			"method": "fixed_post_setup_warmup",
			"starts_after": "battle_hud_interactive",
			"target_duration_ms": 2000,
			"actual_duration_ms": 2001.0,
			"discarded_frames": 290,
		},
	)

	assert_str(report["schema_version"]).is_equal("1.0")
	assert_str(report["benchmark_id"]).is_equal("FR-904")
	assert_str(report["target_scene"]).is_equal("res://ui/screens/battle.tscn")
	assert_bool(report.has_all(["frame_time_ms", "monitors", "spans"])).is_true()
	assert_int(report["frame_time_ms"]["sample_count"]).is_equal(3)
	assert_float(report["setup_phase"]["duration_ms"]).is_equal(105.0)
	assert_str(report["setup_phase"]["window"]).is_equal("battle_event_to_settle_gate")
	assert_float(report["setup_phase"]["frame_time_ms"]["p95"]).is_equal(80.0)
	assert_str(report["measurement"]["settle_gate"]["method"]).is_equal(
		"fixed_post_setup_warmup"
	)
	assert_int(report["measurement"]["settle_gate"]["target_duration_ms"]).is_equal(2000)
	assert_str(report["scenario"]["id"]).is_equal("populated-grid-battle")
	assert_str(report["scenario"]["encounter_id"]).is_equal("dorthkor-vanguard")
	assert_int(report["scenario"]["ally_count"]).is_equal(3)
	assert_int(report["scenario"]["enemy_count"]).is_equal(2)
	assert_int(report["scenario"]["charged_tile_count"]).is_equal(32)
	assert_bool(report["scenario"]["battle_hud_visible"]).is_true()
	assert_bool(report["scenario"]["ct_timeline_visible"]).is_true()
	assert_bool(report["scenario"]["acceptance_evidence"]).is_false()


func _profile_window(frame_times: Array[float]) -> Dictionary:
	return {
		"frame_time_ms": frame_times,
		"frame_interval_ms": frame_times,
		"physics_time_ms": [1.0, 1.0, 1.0],
		"navigation_time_ms": [0.0, 0.0, 0.0],
		"draw_calls": [10.0, 10.0, 10.0],
	}
