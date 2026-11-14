extends GdUnitTestSuite

## The Gauge's low-water mark. Chapter One's ledger reads it back beside the final value
## (roadmap 2026-10-30, Phase 0), so a chapter that went to the edge and came back says so.

var _state_before: Dictionary = {}


func before_test() -> void:
	_state_before = GameState.to_dict()
	# A husked state from an earlier suite would cap the Gauge below these values.
	GameState.flags.erase(GameState.HUSKED_FLAG)
	GameState.flags.erase(GameState.HUSKED_RECOVERY_CEILING_FLAG)
	GameState.soul_meter = 50.0
	GameState.soul_lowest = 50.0


func after_test() -> void:
	GameState.from_dict(_state_before)


func test_the_low_water_mark_follows_the_gauge_down_and_never_up() -> void:
	GameState.soul_meter = 31.0
	GameState.soul_meter = 64.0

	assert_float(GameState.soul_lowest).is_equal(31.0)
	assert_float(GameState.soul_meter).is_equal(64.0)


func test_the_low_water_mark_survives_a_save_and_defaults_for_older_saves() -> void:
	GameState.soul_meter = 12.0
	GameState.soul_meter = 40.0
	var data := GameState.to_dict()
	assert_float(float(data["soul_lowest"])).is_equal(12.0)

	assert_bool(GameState.from_dict(data)).is_true()
	assert_float(GameState.soul_lowest).is_equal(12.0)

	data.erase("soul_lowest")
	assert_bool(GameState.from_dict(data)).is_true()
	assert_float(GameState.soul_lowest) \
		.override_failure_message("a save without the key starts from its loaded Gauge") \
		.is_equal(40.0)


func test_the_chapter_ledger_reads_the_low_water_mark_back() -> void:
	GameState.soul_meter = 23.0
	GameState.soul_meter = 57.0
	var screen: Node = auto_free(preload("res://ui/screens/chapter_complete.tscn").instantiate())

	var ledger: String = screen.call("_ledger_text")

	assert_str(ledger).contains("SOUL  57 / 100  ·  LOWEST 23")
