extends GdUnitTestSuite
## FR-504a world clock (`docs/prd-amendment-living-world.md`) — §5 criteria
## 1–3 at the unit level: default phase, declared-trigger-only advancement,
## and save round-trip at every phase.

var _phase_before: StringName
var _phase_count_before: int


func before_test() -> void:
	_phase_before = WorldClock.phase()
	_phase_count_before = WorldClock.phase_count
	WorldClock.set_phase(WorldClock.DEFAULT_PHASE, "test-setup")
	WorldClock.phase_count = 0


func after_test() -> void:
	WorldClock.set_phase(_phase_before, "test-restore")
	WorldClock.phase_count = _phase_count_before


func test_four_phases_and_default() -> void:
	assert_int(WorldClock.PHASES.size()).is_equal(4)
	assert_array(WorldClock.PHASES).contains_exactly(
		[&"morning", &"afternoon", &"evening", &"night"]
	)
	assert_str(String(WorldClock.DEFAULT_PHASE)).is_equal("morning")


func test_advance_walks_phases_in_order_and_wraps() -> void:
	assert_str(String(WorldClock.advance("test"))).is_equal("afternoon")
	assert_str(String(WorldClock.advance("test"))).is_equal("evening")
	assert_str(String(WorldClock.advance("test"))).is_equal("night")
	assert_str(String(WorldClock.advance("test"))).is_equal("morning")


func test_advance_counts_phases_and_day_index_uses_four_phase_days() -> void:
	assert_int(WorldClock.phase_count).is_equal(0)
	assert_int(WorldClock.day_index()).is_equal(0)
	for _i in range(3):
		WorldClock.advance("test")
	assert_int(WorldClock.phase_count).is_equal(3)
	assert_int(WorldClock.day_index()).is_equal(0)
	WorldClock.advance("test")
	assert_int(WorldClock.phase_count).is_equal(4)
	assert_int(WorldClock.day_index()).is_equal(1)


func test_advance_emits_phase_changed_with_cause() -> void:
	var seen: Array = []
	var handler := func(previous: StringName, current: StringName, cause: String) -> void:
		seen.append([previous, current, cause])
	WorldClock.phase_changed.connect(handler)
	WorldClock.advance("travel:test")
	WorldClock.phase_changed.disconnect(handler)
	assert_int(seen.size()).is_equal(1)
	assert_str(String(seen[0][0])).is_equal("morning")
	assert_str(String(seen[0][1])).is_equal("afternoon")
	assert_str(str(seen[0][2])).is_equal("travel:test")


func test_set_phase_rejects_unknown_phase() -> void:
	assert_bool(WorldClock.set_phase(&"noon", "test")).is_false()
	assert_str(String(WorldClock.phase())).is_equal("morning")


func test_clock_does_not_advance_on_its_own() -> void:
	# §5 criterion 3 (unit form): no _process, no timer — idle frames leave
	# the phase alone.
	for _i in range(10):
		await get_tree().process_frame
	assert_str(String(WorldClock.phase())).is_equal("morning")


func test_round_trip_survives_every_phase() -> void:
	for phase: StringName in WorldClock.PHASES:
		WorldClock.set_phase(phase, "test")
		WorldClock.phase_count = 7
		var data := WorldClock.to_dict()
		WorldClock.set_phase(WorldClock.DEFAULT_PHASE, "test")
		WorldClock.phase_count = 0
		WorldClock.from_dict(data)
		assert_str(String(WorldClock.phase())).is_equal(String(phase))
		assert_int(WorldClock.phase_count).is_equal(7)


func test_from_dict_normalizes_garbage_to_default() -> void:
	WorldClock.set_phase(&"night", "test")
	WorldClock.from_dict({"phase": "high-noon"})
	assert_str(String(WorldClock.phase())).is_equal("morning")
	WorldClock.from_dict({})
	assert_str(String(WorldClock.phase())).is_equal("morning")
	assert_int(WorldClock.phase_count).is_equal(0)


func test_validate_save_data() -> void:
	assert_bool(WorldClock.validate_save_data({"phase": "evening", "phase_count": 4})).is_true()
	assert_bool(WorldClock.validate_save_data({})).is_true()
	assert_bool(WorldClock.validate_save_data({"phase": "noon"})).is_false()
	assert_bool(WorldClock.validate_save_data({"phase": 3})).is_false()
	assert_bool(WorldClock.validate_save_data({"phase_count": -1})).is_false()
	assert_bool(WorldClock.validate_save_data({"phase_count": 1.5})).is_false()
	assert_bool(WorldClock.validate_save_data("morning")).is_false()


func test_advance_for_quest_requires_declaration() -> void:
	var silent := FlagQuest.new()
	silent.quest_name = "Undeclared"
	WorldClock.advance_for_quest(silent)
	assert_str(String(WorldClock.phase())).is_equal("morning")

	var declared := FlagQuest.new()
	declared.quest_name = "Declared"
	declared.advances_clock = true
	WorldClock.advance_for_quest(declared)
	assert_str(String(WorldClock.phase())).is_equal("afternoon")

	WorldClock.advance_for_quest(null)
	assert_str(String(WorldClock.phase())).is_equal("afternoon")
