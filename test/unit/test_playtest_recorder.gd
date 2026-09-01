extends GdUnitTestSuite

const RecorderScript := preload("res://globals/playtest_recorder.gd")

var _recorders: Array[Node] = []


func after_test() -> void:
	for recorder: Node in _recorders:
		if is_instance_valid(recorder):
			recorder.set("force_enabled_for_tests", false)
	_recorders.clear()
	get_tree().paused = false


func test_append_writes_one_flushed_json_line_per_event() -> void:
	var recorder: Node = _new_recorder()
	recorder.call("append_event", &"first", {"value": 1})
	var events_path: String = str(recorder.call("get_events_path"))
	var after_first: PackedStringArray = _non_empty_lines(
		FileAccess.get_file_as_string(events_path)
	)

	# The recorder listens to the whole SceneTree by design, so in a full-suite
	# run other suites' scenes legitimately interleave `scene_started` events
	# here. Assert on the subsequence this test authored — and on the property
	# that actually matters: EVERY line is one complete, flushed JSON object.
	assert_str(after_first[0]).contains("session")
	_assert_every_line_is_one_json_object(after_first)
	var mine_first: Array[Dictionary] = _events_of_types(after_first, ["first", "second"])
	assert_int(mine_first.size()).is_equal(1)
	assert_str(str(mine_first[0].get("type", ""))).is_equal("first")
	assert_int(int(mine_first[0].get("value", 0))).is_equal(1)
	assert_bool(mine_first[0].has("t")).is_true()

	recorder.call("append_event", &"second", {"value": 2})
	var after_second: PackedStringArray = _non_empty_lines(
		FileAccess.get_file_as_string(events_path)
	)
	_assert_every_line_is_one_json_object(after_second)
	var mine_second: Array[Dictionary] = _events_of_types(after_second, ["first", "second"])
	assert_int(mine_second.size()).is_equal(2)
	assert_str(str(mine_second[0].get("type", ""))).is_equal("first")
	assert_str(str(mine_second[1].get("type", ""))).is_equal("second")
	assert_int(int(mine_second[1].get("value", 0))).is_equal(2)


func test_session_header_describes_capture_and_privacy_without_personal_data() -> void:
	var recorder: Node = _new_recorder()
	var content: String = FileAccess.get_file_as_string(str(recorder.call("get_events_path")))
	var lines: PackedStringArray = _non_empty_lines(content)
	var parsed: Variant = JSON.parse_string(lines[0])

	assert_bool(parsed is Dictionary).is_true()
	var header: Dictionary = parsed as Dictionary
	assert_str(str(header.get("type", ""))).is_equal("session_started")
	assert_int(int(header.get("schema", 0))).is_equal(1)
	assert_bool(header.get("captured_categories", []) is Array).is_true()
	assert_bool(header.get("uncaptured_categories", []) is Array).is_true()
	assert_str(str(header.get("privacy", ""))).contains("gameplay telemetry")
	assert_bool(header.has("username")).is_false()
	assert_bool(header.has("hostname")).is_false()
	assert_bool(header.has("ip")).is_false()


func test_subsystem_coverage_requires_complete_tactical_and_save_load_evidence() -> void:
	var events: Array[Dictionary] = [
		{"t": 10, "type": "dialogue_started"},
		{"t": 20, "type": "reputation_changed"},
		{"t": 30, "type": "battle_started"},
		{"t": 40, "type": "tactical_event", "event_type": "turn_started"},
		{"t": 50, "type": "tactical_event", "event_type": "weather_applied"},
		{
			"t": 60,
			"type": "tactical_event",
			"event_type": "action_resolved",
			"data": {"tile": {"residue_applied": true}},
		},
		{"t": 70, "type": "save_performed"},
		{"t": 80, "type": "load_performed"},
		{"t": 90, "type": "mock_ng_plus_observed"},
	]

	var coverage: Dictionary = RecorderScript.derive_subsystem_coverage(events)

	assert_bool(bool(coverage.get("dialogue", false))).is_true()
	assert_bool(bool(coverage.get("consequence_write", false))).is_true()
	assert_bool(bool(coverage.get("ct_order", false))).is_true()
	assert_bool(bool(coverage.get("weather_balance", false))).is_true()
	assert_bool(bool(coverage.get("tile_event", false))).is_true()
	assert_bool(bool(coverage.get("tactical_battle", false))).is_true()
	assert_bool(bool(coverage.get("save_load", false))).is_true()
	assert_bool(bool(coverage.get("mock_ng_plus", false))).is_true()

	events.pop_back()
	coverage = RecorderScript.derive_subsystem_coverage(events)
	assert_bool(bool(coverage.get("mock_ng_plus", true))).is_false()


func test_tile_coverage_ignores_unchanged_tiles_in_routine_combat_snapshots() -> void:
	var events: Array[Dictionary] = [
		{"t": 10, "type": "battle_started"},
		{
			"t": 20,
			"type": "tactical_event",
			"event_type": "turn_started",
			"data": {"snapshot": {"tiles": [{"x": 1, "y": 2, "charge_level": 0}]}},
		},
		{
			"t": 30,
			"type": "tactical_event",
			"event_type": "weather_applied",
			"data": {
				"charged_tiles": 0,
				"drained_tiles": 0,
				"snapshot": {"tiles": [{"x": 1, "y": 2, "charge_level": 0}]},
			},
		},
	]

	var coverage: Dictionary = RecorderScript.derive_subsystem_coverage(events)
	assert_bool(bool(coverage.get("tile_event", true))).is_false()
	assert_bool(bool(coverage.get("tactical_battle", true))).is_false()

	events.append(
		{
			"t": 40,
			"type": "tactical_event",
			"event_type": "action_resolved",
			"data": {
				"tile_changes": [
					{
						"x": 1,
						"y": 2,
						"before": {"charge_level": 0},
						"after": {"charge_level": 1},
					}
				]
			},
		}
	)
	coverage = RecorderScript.derive_subsystem_coverage(events)
	assert_bool(bool(coverage.get("tile_event", false))).is_true()
	assert_bool(bool(coverage.get("tactical_battle", false))).is_true()


func test_markdown_export_contains_packet_form_duration_coverage_and_blank_answers() -> void:
	var events: Array[Dictionary] = [
		{"t": 1000, "type": "dialogue_started"},
		{"t": 2000, "type": "renown_changed"},
		{"t": 3000, "type": "battle_started"},
		{"t": 4000, "type": "tactical_event", "event_type": "turn_started"},
		{"t": 5000, "type": "tactical_event", "event_type": "balance_changed"},
		{"t": 6000, "type": "tactical_event", "event_type": "tile_detonated"},
		{"t": 7000, "type": "save_performed"},
		{"t": 8000, "type": "load_performed"},
		{"t": 9000, "type": "mock_ng_plus_observed"},
		{"t": 65_000, "type": "note", "text": "Lost the turn-order marker."},
	]
	var manifest := {
		"artifact": "SoulMeter.x86_64",
		"commit_sha": "abc123",
		"export_target": "Linux/X11",
	}

	var markdown: String = RecorderScript.build_markdown(events, manifest, 5_430_000)

	assert_str(markdown).contains("## Build and session record")
	assert_str(markdown).contains("SoulMeter.x86_64")
	assert_str(markdown).contains("abc123")
	assert_str(markdown).contains("Linux/X11")
	assert_str(markdown).contains("01:30:30")
	assert_str(markdown).contains("### Subsystem coverage")
	assert_str(markdown).contains("- [x] Dialogue")
	assert_str(markdown).contains("- [x] Tactical battle (CT + weather/Balance + tile event)")
	assert_str(markdown).contains("### Gate question 1 — cast refusal")
	assert_str(markdown).contains("### Gate question 2 — Balance")
	assert_str(markdown).contains("### Gate question 3 — CT order")
	assert_str(markdown).contains("### Gate question 4 — tile state")
	assert_str(markdown).contains("| | | PASS / FAIL |")
	assert_str(markdown).contains("Lost the turn-order marker.")


func _new_recorder() -> Node:
	var recorder: Node = auto_free(RecorderScript.new()) as Node
	_recorders.append(recorder)
	recorder.set("session_root_override", _unique_test_root())
	recorder.set("force_enabled_for_tests", true)
	add_child(recorder)
	return recorder


func _unique_test_root() -> String:
	var base: String = OS.get_environment("SOUL_METER_TEST_DATA_DIR")
	if base.is_empty():
		base = OS.get_temp_dir()
	return base.path_join("playtest-recorder-unit-%d" % Time.get_ticks_usec())


## Every emitted line must be exactly one complete JSON object — this is what
## "one flushed line per event" buys: no partial writes, no multi-line records,
## so a crashed session still yields a parseable evidence file.
func _assert_every_line_is_one_json_object(lines: PackedStringArray) -> void:
	for line: String in lines:
		var parsed: Variant = JSON.parse_string(line)
		assert_bool(parsed is Dictionary) \
			.override_failure_message("Not a single complete JSON object: %s" % line) \
			.is_true()


func _events_of_types(lines: PackedStringArray, types: Array) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for line: String in lines:
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary and types.has(str((parsed as Dictionary).get("type", ""))):
			found.append(parsed as Dictionary)
	return found


func _non_empty_lines(content: String) -> PackedStringArray:
	var result := PackedStringArray()
	for line: String in content.split("\n"):
		if not line.is_empty():
			result.append(line)
	return result
