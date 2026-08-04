extends GdUnitTestSuite

const PerformanceBenchmark := preload("res://tools/performance_benchmark.gd")


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
