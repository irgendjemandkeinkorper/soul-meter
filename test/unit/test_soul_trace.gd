extends GdUnitTestSuite
## P1.1: ephemeral cause-level diagnostics at the single Soul mutation seam.

var _state_before: Dictionary = {}
var _emitted: Array[Dictionary] = []


func before_test() -> void:
	_state_before = GameState.to_dict()
	GameState.flags.erase(GameState.HUSKED_FLAG)
	GameState.flags.erase(GameState.HUSKED_RECOVERY_CEILING_FLAG)
	GameState.set_soul_meter_with_cause(50.0, "test:setup")
	GameState.soul_lowest = 50.0
	GameState.clear_soul_trace()
	_emitted.clear()
	GameState.soul_traced.connect(_on_soul_traced)


func after_test() -> void:
	GameState.soul_traced.disconnect(_on_soul_traced)
	GameState.from_dict(_state_before)
	GameState.clear_soul_trace()


func _on_soul_traced(entry: Dictionary) -> void:
	# The signal must expose an entry that is already in the trace.
	assert_dict(GameState.soul_trace_entries().back()).is_equal(entry)
	_emitted.append(entry)


func test_normal_change_has_the_complete_typed_entry_and_existing_band() -> void:
	GameState.set_soul_meter_with_cause(44.0, "dialogue:iris_illepah:loam_memory")

	var expected: Dictionary = {
		"index": 1,
		"cause": "dialogue:iris_illepah:loam_memory",
		"requested": 44.0,
		"before": 50.0,
		"after": 44.0,
		"changed": true,
		"clamped": false,
		"ceiling": 100.0,
		"husked_before": false,
		"husked_after": false,
		"band_id": "frayed",
	}
	var entries := GameState.soul_trace_entries()
	assert_int(entries.size()).is_equal(1)
	assert_dict(entries[0]).is_equal(expected)
	for key: String in expected:
		assert_int(typeof(entries[0][key])).is_equal(typeof(expected[key]))
	assert_float(float(entries[0]["after"])).is_equal(GameState.soul_meter)


func test_direct_property_and_legacy_setter_are_unattributed() -> void:
	GameState.set_soul_meter_with_cause(45.0, "test:attributed")
	GameState.soul_meter = 40.0
	GameState.set_soul_meter(35.0)

	var entries := GameState.soul_trace_entries()
	assert_int(entries.size()).is_equal(3)
	assert_str(entries[0]["cause"]).is_equal("test:attributed")
	assert_str(entries[1]["cause"]).is_equal("unattributed")
	assert_str(entries[2]["cause"]).is_equal("unattributed")


func test_no_op_creates_no_entry_or_signal_and_consumes_the_cause() -> void:
	GameState.set_soul_meter_with_cause(50.0, "test:no_op")
	GameState.soul_meter = 50.0
	assert_array(GameState.soul_trace_entries()).is_empty()
	assert_array(_emitted).is_empty()

	GameState.soul_meter = 49.0
	assert_int(GameState.soul_trace_entries().size()).is_equal(1)
	assert_str(GameState.soul_trace_entries()[0]["cause"]).is_equal("unattributed")


func test_husking_recovery_and_ceiling_block_record_transitions_and_applied_ceiling() -> void:
	GameState.set_soul_meter_with_cause(0.0, "test:husk")
	GameState.set_soul_meter_with_cause(80.0, "test:recover")
	GameState.set_soul_meter_with_cause(80.0, "test:blocked_recovery")

	var entries := GameState.soul_trace_entries()
	assert_int(entries.size()).is_equal(3)
	assert_bool(entries[0]["husked_before"]).is_false()
	assert_bool(entries[0]["husked_after"]).is_true()
	assert_bool(entries[0]["changed"]).is_true()
	assert_bool(entries[0]["clamped"]).is_false()
	assert_float(entries[0]["ceiling"]).is_equal(100.0)
	assert_str(entries[0]["band_id"]).is_equal("husked")
	assert_bool(entries[1]["husked_before"]).is_true()
	assert_bool(entries[1]["husked_after"]).is_false()
	assert_bool(entries[1]["changed"]).is_true()
	assert_bool(entries[1]["clamped"]).is_true()
	assert_float(entries[1]["before"]).is_equal(0.0)
	assert_float(entries[1]["requested"]).is_equal(80.0)
	assert_float(entries[1]["after"]).is_equal(25.0)
	assert_float(entries[1]["ceiling"]).is_equal(25.0)
	assert_bool(entries[2]["changed"]).is_false()
	assert_bool(entries[2]["clamped"]).is_true()
	assert_bool(entries[2]["husked_before"]).is_false()
	assert_bool(entries[2]["husked_after"]).is_false()
	assert_float(entries[2]["before"]).is_equal(25.0)
	assert_float(entries[2]["after"]).is_equal(GameState.soul_meter)
	assert_float(entries[2]["ceiling"]).is_equal(25.0)


func test_upper_and_lower_bounds_trace_changes_and_fully_blocked_requests() -> void:
	GameState.set_soul_meter_with_cause(120.0, "test:upper")
	GameState.set_soul_meter_with_cause(120.0, "test:upper_blocked")
	GameState.set_soul_meter_with_cause(-5.0, "test:lower")
	GameState.set_soul_meter_with_cause(-5.0, "test:lower_blocked")

	var entries := GameState.soul_trace_entries()
	assert_int(entries.size()).is_equal(4)
	assert_float(entries[0]["before"]).is_equal(50.0)
	assert_float(entries[0]["after"]).is_equal(100.0)
	assert_float(entries[0]["requested"]).is_equal(120.0)
	assert_float(entries[2]["before"]).is_equal(100.0)
	assert_float(entries[2]["after"]).is_equal(0.0)
	assert_float(entries[2]["requested"]).is_equal(-5.0)
	for i: int in entries.size():
		assert_bool(entries[i]["clamped"]).is_true()
		assert_bool(entries[i]["changed"]).is_equal(i % 2 == 0)
	assert_bool(entries[2]["husked_after"]).is_true()
	assert_bool(entries[3]["husked_before"]).is_true()
	assert_bool(entries[3]["husked_after"]).is_true()
	GameState.soul_meter = 0.0
	assert_int(GameState.soul_trace_entries().size()).is_equal(4)


func test_limit_discards_oldest_without_reusing_indices() -> void:
	for i: int in GameState.SOUL_TRACE_LIMIT + 3:
		GameState.set_soul_meter_with_cause(40.0 + float(i % 2), "test:limit:%d" % i)

	var entries := GameState.soul_trace_entries()
	assert_int(entries.size()).is_equal(GameState.SOUL_TRACE_LIMIT)
	assert_int(entries[0]["index"]).is_equal(4)
	assert_str(entries[0]["cause"]).is_equal("test:limit:3")
	assert_int(entries.back()["index"]).is_equal(GameState.SOUL_TRACE_LIMIT + 3)
	for i: int in entries.size():
		assert_int(entries[i]["index"]).is_equal(i + 4)


func test_save_round_trip_preserves_payload_and_only_appends_the_load_change() -> void:
	GameState.set_soul_meter_with_cause(60.0, "test:saved")
	var saved := GameState.to_dict()
	var saved_bytes := var_to_bytes(saved)
	assert_bool(saved.has("soul_trace")).is_false()
	GameState.set_soul_meter_with_cause(70.0, "test:unsaved")
	var trace_before := GameState.soul_trace_entries()

	assert_bool(GameState.from_dict(saved)).is_true()
	var entries := GameState.soul_trace_entries()
	assert_int(entries.size()).is_equal(trace_before.size() + 1)
	for i: int in trace_before.size():
		assert_dict(entries[i]).is_equal(trace_before[i])
	assert_str(entries.back()["cause"]).is_equal("save:from_dict")
	assert_float(entries.back()["before"]).is_equal(70.0)
	assert_float(entries.back()["after"]).is_equal(60.0)
	assert_bool(var_to_bytes(GameState.to_dict()) == saved_bytes).is_true()
	assert_bool(var_to_bytes(saved) == saved_bytes).is_true()

	# Loading the same Soul again is still a no-op, including when an unknown
	# trace-shaped input key is present: the ephemeral buffer is never loaded.
	saved["soul_trace"] = [{"cause": "forged:save"}]
	assert_bool(GameState.from_dict(saved)).is_true()
	assert_array(GameState.soul_trace_entries()).is_equal(entries)
	assert_bool(var_to_bytes(GameState.to_dict()) == saved_bytes).is_true()


func test_trace_reads_and_signal_payloads_cannot_mutate_retained_entries() -> void:
	GameState.set_soul_meter_with_cause(40.0, "test:original")
	var entries := GameState.soul_trace_entries()
	entries[0]["cause"] = "changed:copy"
	entries.clear()
	_emitted[0]["cause"] = "changed:signal"

	assert_int(GameState.soul_trace_entries().size()).is_equal(1)
	assert_str(GameState.soul_trace_entries()[0]["cause"]).is_equal("test:original")


func test_clear_resets_indices_without_changing_saved_state_or_emitting() -> void:
	GameState.set_soul_meter_with_cause(0.0, "test:husk")
	var state_bytes := var_to_bytes(GameState.to_dict())
	GameState.clear_soul_trace()

	assert_array(GameState.soul_trace_entries()).is_empty()
	assert_bool(var_to_bytes(GameState.to_dict()) == state_bytes).is_true()
	assert_int(_emitted.size()).is_equal(1)
	GameState.set_soul_meter_with_cause(5.0, "test:after_clear")
	assert_int(GameState.soul_trace_entries()[0]["index"]).is_equal(1)


func test_signal_fires_once_per_change_or_blocked_clamp_and_never_per_no_op() -> void:
	GameState.set_soul_meter_with_cause(40.0, "test:change")
	GameState.set_soul_meter_with_cause(40.0, "test:no_op")
	GameState.set_soul_meter_with_cause(0.0, "test:husk")
	GameState.set_soul_meter_with_cause(100.0, "test:recovery")
	GameState.set_soul_meter_with_cause(100.0, "test:blocked")

	assert_int(_emitted.size()).is_equal(4)
	assert_array(_emitted).is_equal(GameState.soul_trace_entries())


func test_existing_gauge_band_identifiers_are_unchanged_at_boundaries() -> void:
	for sample: Dictionary in [
		{"value": 100.0, "id": "bright"}, {"value": 75.0, "id": "bright"},
		{"value": 74.0, "id": "whole"}, {"value": 50.0, "id": "whole"},
		{"value": 49.0, "id": "frayed"}, {"value": 25.0, "id": "frayed"},
		{"value": 24.0, "id": "guttering"}, {"value": 0.0, "id": "husked"},
	]:
		GameState.set_soul_meter_with_cause(sample["value"], "test:band")
		assert_str(GameState.soul_trace_entries().back()["band_id"]).is_equal(sample["id"])
		assert_str(SoulGauge.condition_for(sample["value"])).is_equal(sample["id"])
