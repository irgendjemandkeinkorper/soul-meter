extends GdUnitTestSuite
## Issue #140 — Weather: the global element on a 16-tick measure.
## Covers the issue's acceptance line verbatim (16 ticks produce exactly one weather
## application; Hush blocks charge movement without blocking the tick counter), the
## matching-element/clash-element charge math, weather_hush vs tile.hush independence, and the
## round-trip/determinism properties Gate T criteria 7 and 8 require.

const Weather := preload("res://globals/combat/weather.gd")
const TileState := preload("res://globals/combat/tile_state.gd")

## Zhur/Tham are a Clash pair per the issue body ("A Stormfront feeds Zhur and starves
## Tham") and `ui/theme/ds.gd`'s Wheel-of-Ten comment.
const WEATHER_ELEMENT := &"zhur"
const CLASH_ELEMENT := &"tham"
## Chord-adjacent to Zhur, not Clash — proves an unrelated element is left alone.
const UNRELATED_ELEMENT := &"khor"


func _measure(weather_element: StringName = WEATHER_ELEMENT) -> Weather:
	var weather := Weather.create(weather_element)
	return weather


# ---- acceptance line 1: 16 ticks produce exactly one weather application ----


func test_sixteen_ticks_produce_exactly_one_application() -> void:
	var weather := _measure()
	var applications := 0

	for i in range(TurnScheduler.TICKS_PER_MEASURE):
		var result := weather.tick([])
		if result["applied"]:
			applications += 1

	assert_int(applications).is_equal(1)
	assert_int(weather.measures_applied()).is_equal(1)
	assert_int(weather.total_ticks()).is_equal(TurnScheduler.TICKS_PER_MEASURE)


func test_partial_measure_applies_nothing() -> void:
	var weather := _measure()

	for i in range(TurnScheduler.TICKS_PER_MEASURE - 1):
		var result := weather.tick([])
		assert_bool(result["applied"]).is_false()

	assert_int(weather.measures_applied()).is_equal(0)
	assert_int(weather.ticks_since_application()).is_equal(TurnScheduler.TICKS_PER_MEASURE - 1)


func test_two_full_measures_produce_exactly_two_applications() -> void:
	var weather := _measure()
	var applications := 0

	for i in range(TurnScheduler.TICKS_PER_MEASURE * 2):
		var result := weather.tick([])
		if result["applied"]:
			applications += 1

	assert_int(applications).is_equal(2)
	assert_int(weather.measures_applied()).is_equal(2)


# ---- acceptance line 2: Hush blocks charge movement without blocking the tick counter ----


func test_weather_hush_blocks_charge_movement_without_blocking_tick_counter() -> void:
	var weather := _measure()
	weather.set_hush(true)
	var tile := TileState.create(&"battle-1", 0, 0)
	tile.apply_residue(WEATHER_ELEMENT)
	assert_int(tile.charge_level).is_equal(1)

	var last_result: Dictionary = {}
	for i in range(TurnScheduler.TICKS_PER_MEASURE):
		last_result = weather.tick([tile])

	assert_bool(last_result["applied"]).is_true()
	assert_bool(last_result["allowed"]).is_false()
	assert_str(String(last_result["blocked_by"])).is_equal("weather_hush")
	# Charge never moved...
	assert_int(tile.charge_level).is_equal(1)
	# ...but the tick counter kept running and rolled the measure over regardless.
	assert_int(weather.total_ticks()).is_equal(TurnScheduler.TICKS_PER_MEASURE)
	assert_int(weather.measures_applied()).is_equal(1)
	assert_int(weather.ticks_since_application()).is_equal(0)


func test_weather_hush_blocked_by_is_distinct_from_tile_hush_blocked_by() -> void:
	# Naming requirement from the issue: `weather_hush` (this file) must never collide with
	# `TileState.hush`'s own `&"hush"` blocked_by.
	var weather := _measure()
	weather.set_hush(true)
	var weather_result: Dictionary = {}
	for i in range(TurnScheduler.TICKS_PER_MEASURE):
		weather_result = weather.tick([])

	var tile := TileState.create(&"battle-1", 1, 1)
	tile.hush = true
	var tile_result := tile.apply_residue(WEATHER_ELEMENT)

	assert_str(String(weather_result["blocked_by"])).is_not_equal(
		String(tile_result["blocked_by"])
	)
	assert_str(String(weather_result["blocked_by"])).is_equal("weather_hush")
	assert_str(String(tile_result["blocked_by"])).is_equal("hush")


# ---- local (Hushwarden) tile.hush is independent of weather_hush ----


func test_local_tile_hush_blocks_that_tile_even_when_weather_is_not_hush() -> void:
	var weather := _measure()
	var hushed_tile := TileState.create(&"battle-1", 2, 2)
	hushed_tile.apply_residue(WEATHER_ELEMENT)
	hushed_tile.hush = true
	var normal_tile := TileState.create(&"battle-1", 3, 3)
	normal_tile.apply_residue(WEATHER_ELEMENT)

	var tiles: Array[TileState] = [hushed_tile, normal_tile]
	var last_result: Dictionary = {}
	for i in range(TurnScheduler.TICKS_PER_MEASURE):
		last_result = weather.tick(tiles)

	assert_bool(last_result["allowed"]).is_true()
	assert_int(last_result["locally_hushed_tiles"]).is_equal(1)
	assert_int(last_result["charged_tiles"]).is_equal(1)
	assert_int(hushed_tile.charge_level).is_equal(1)
	assert_int(normal_tile.charge_level).is_equal(2)


# ---- matching-element charge / clash-element drain, resolved through ElementWheel ----


func test_matching_element_tile_gains_one_charge() -> void:
	var weather := _measure(WEATHER_ELEMENT)
	var tile := TileState.create(&"battle-1", 0, 0)
	tile.apply_residue(WEATHER_ELEMENT)
	assert_int(tile.charge_level).is_equal(1)

	var tiles: Array[TileState] = [tile]
	var last_result: Dictionary = {}
	for i in range(TurnScheduler.TICKS_PER_MEASURE):
		last_result = weather.tick(tiles)

	assert_int(tile.charge_level).is_equal(2)
	assert_int(last_result["charged_tiles"]).is_equal(1)
	assert_int(last_result["drained_tiles"]).is_equal(0)


func test_clash_element_tile_loses_one_charge() -> void:
	assert_int(ElementWheel.distance(WEATHER_ELEMENT, CLASH_ELEMENT)).is_equal(5)
	var weather := _measure(WEATHER_ELEMENT)
	var tile := TileState.create(&"battle-1", 0, 0)
	tile.apply_residue(CLASH_ELEMENT)
	tile.apply_residue(CLASH_ELEMENT)
	assert_int(tile.charge_level).is_equal(2)

	var tiles: Array[TileState] = [tile]
	var last_result: Dictionary = {}
	for i in range(TurnScheduler.TICKS_PER_MEASURE):
		last_result = weather.tick(tiles)

	assert_int(tile.charge_level).is_equal(1)
	assert_str(String(tile.charge_element_id)).is_equal(String(CLASH_ELEMENT))
	assert_int(last_result["drained_tiles"]).is_equal(1)
	assert_int(last_result["charged_tiles"]).is_equal(0)


func test_clash_element_tile_clears_when_drained_to_zero() -> void:
	var weather := _measure(WEATHER_ELEMENT)
	var tile := TileState.create(&"battle-1", 0, 0)
	tile.apply_residue(CLASH_ELEMENT)
	assert_int(tile.charge_level).is_equal(1)

	var tiles: Array[TileState] = [tile]
	for i in range(TurnScheduler.TICKS_PER_MEASURE):
		weather.tick(tiles)

	assert_int(tile.charge_level).is_equal(0)
	assert_bool(tile.is_charged()).is_false()
	assert_str(String(tile.charge_element_id)).is_equal("")


func test_unrelated_element_tile_is_untouched() -> void:
	var weather := _measure(WEATHER_ELEMENT)
	var tile := TileState.create(&"battle-1", 0, 0)
	tile.apply_residue(UNRELATED_ELEMENT)
	assert_int(tile.charge_level).is_equal(1)

	var tiles: Array[TileState] = [tile]
	var last_result: Dictionary = {}
	for i in range(TurnScheduler.TICKS_PER_MEASURE):
		last_result = weather.tick(tiles)

	assert_int(tile.charge_level).is_equal(1)
	assert_int(last_result["charged_tiles"]).is_equal(0)
	assert_int(last_result["drained_tiles"]).is_equal(0)


func test_no_weather_authored_applies_nothing() -> void:
	var weather := Weather.create()
	var tile := TileState.create(&"battle-1", 0, 0)
	tile.apply_residue(WEATHER_ELEMENT)

	var tiles: Array[TileState] = [tile]
	var last_result: Dictionary = {}
	for i in range(TurnScheduler.TICKS_PER_MEASURE):
		last_result = weather.tick(tiles)

	assert_bool(last_result["allowed"]).is_true()
	assert_int(last_result["charged_tiles"]).is_equal(0)
	assert_int(tile.charge_level).is_equal(1)


# ---- unknown element is refused distinctly ----


func test_setting_unknown_element_is_refused() -> void:
	var weather := Weather.new()
	var result := weather.set_element(&"not-on-the-wheel")

	assert_bool(result["allowed"]).is_false()
	assert_str(String(result["blocked_by"])).is_equal("unknown_element")
	assert_str(String(weather.element_id)).is_equal("")


# ---- to_dict()/from_dict() round trip (Gate T criterion 8) ----


func test_round_trip_is_lossless_mid_measure() -> void:
	var weather := _measure(WEATHER_ELEMENT)
	weather.set_hush(true)
	for i in range(5):
		weather.tick([])

	var restored := Weather.from_dict(weather.to_dict())

	assert_dict(restored.to_dict()).is_equal(weather.to_dict())
	assert_str(String(restored.element_id)).is_equal(String(weather.element_id))
	assert_bool(restored.weather_hush).is_equal(weather.weather_hush)
	assert_int(restored.ticks_since_application()).is_equal(weather.ticks_since_application())
	assert_int(restored.total_ticks()).is_equal(weather.total_ticks())
	assert_int(restored.measures_applied()).is_equal(weather.measures_applied())


func test_round_trip_resumes_measure_phase_instead_of_realigning() -> void:
	# The save/load boundary itself must never count as a tick or trigger an application —
	# resuming mid-measure must finish that SAME measure on the 16th tick since the last one,
	# not restart the count from the load point.
	var weather := _measure(WEATHER_ELEMENT)
	var tile := TileState.create(&"battle-1", 0, 0)
	tile.apply_residue(WEATHER_ELEMENT)
	for i in range(TurnScheduler.TICKS_PER_MEASURE - 3):
		weather.tick([tile])

	var restored := Weather.from_dict(weather.to_dict())
	var restored_tile := TileState.from_dict(tile.to_dict())

	var applications := 0
	for i in range(3):
		var result := restored.tick([restored_tile])
		if result["applied"]:
			applications += 1

	assert_int(applications).is_equal(1)
	assert_int(restored_tile.charge_level).is_equal(2)


# ---- determinism (Gate T criterion 7) ----


func test_determinism_repeated_runs_produce_identical_results() -> void:
	var results_a: Array[Dictionary] = []
	var weather_a := _measure(WEATHER_ELEMENT)
	var tile_a := TileState.create(&"battle-1", 0, 0)
	tile_a.apply_residue(CLASH_ELEMENT)
	for i in range(TurnScheduler.TICKS_PER_MEASURE * 2):
		results_a.append(weather_a.tick([tile_a]))

	var results_b: Array[Dictionary] = []
	var weather_b := _measure(WEATHER_ELEMENT)
	var tile_b := TileState.create(&"battle-1", 0, 0)
	tile_b.apply_residue(CLASH_ELEMENT)
	for i in range(TurnScheduler.TICKS_PER_MEASURE * 2):
		results_b.append(weather_b.tick([tile_b]))

	assert_array(results_a).is_equal(results_b)
	assert_int(tile_a.charge_level).is_equal(tile_b.charge_level)
