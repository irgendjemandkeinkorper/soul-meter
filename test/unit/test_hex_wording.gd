extends GdUnitTestSuite
## Hex slice H3b (owner item 34; docs/design/hex-grid-plan-2026-11-03.md): what the player reads
## counts the grid's own steps. On squares the words stay "cell" and "cells"; on hexes they read
## "hex" and "hexes" with the converted counts. A fire line runs along any of the three hex axes.
## Each case sets the grid it needs, and the setting is restored after it.

var _setting_before: Variant


func before_test() -> void:
	_setting_before = ProjectSettings.get_setting(IsoGrid.HEX_SETTING, false)


func after_test() -> void:
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, _setting_before)


func _use_hexes(on: bool) -> void:
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, on)


func _ranged(reach: int) -> CombatAction:
	var action := CombatAction.new()
	action.target_profile = &"ranged"
	action.effect_payload = {"range": reach}
	return action


func _cells(points: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for point: Array in points:
		cells.append(Vector2i(int(point[0]), int(point[1])))
	return cells


func test_step_words_follow_the_grid() -> void:
	_use_hexes(false)
	assert_str(GridMetric.step_word(1)).is_equal("cell")
	assert_str(GridMetric.step_word()).is_equal("cells")
	assert_str(GridMetric.steps_text(4)).is_equal("4 cells")
	assert_str(GridMetric.spelled_steps_text(2)).is_equal("two cells")
	_use_hexes(true)
	assert_str(GridMetric.step_word(1)).is_equal("hex")
	assert_str(GridMetric.step_word()).is_equal("hexes")
	assert_str(GridMetric.steps_text(1)).is_equal("1 hex")
	assert_str(GridMetric.steps_text(8)).is_equal("8 hexes")
	assert_str(GridMetric.spelled_steps_text(4)).is_equal("four hexes")
	assert_str(GridMetric.spelled_steps_text(12)).is_equal("12 hexes")


func test_a_command_reach_reads_in_the_grid_steps_the_ring_draws() -> void:
	_use_hexes(false)
	assert_str(_ranged(4).reach_text()).is_equal("reach 4 cells")
	_use_hexes(true)
	assert_str(_ranged(4).reach_text()).override_failure_message("reach 4 doubles on hexes").is_equal("reach 8 hexes")
	assert_int(_ranged(4).reach_steps()).is_equal(8)
	var melee := CombatAction.new()
	melee.target_profile = &"melee"
	melee.target_side = "enemy"
	assert_str(melee.reach_text()).is_equal("melee")
	var working := CombatAction.new()
	working.target_profile = &"cells"
	working.effect_payload = {"range": 3}
	assert_str(working.reach_text()).is_equal("reach 6 hexes")


func test_a_fire_line_runs_along_any_hex_axis() -> void:
	_use_hexes(true)
	for axis: Vector2i in HexMath.DIRECTIONS:
		var line: Array[Vector2i] = [Vector2i(4, 4), Vector2i(4, 4) + axis, Vector2i(4, 4) + axis * 2]
		assert_bool(FireField.is_cardinal_line(line)).override_failure_message("axis %s" % axis).is_true()
	assert_bool(FireField.is_cardinal_line(_cells([[4, 4], [5, 4], [5, 5]]))).override_failure_message("bent").is_false()
	assert_bool(FireField.is_cardinal_line(_cells([[4, 4], [5, 4], [7, 4]]))).override_failure_message("gap").is_false()
	_use_hexes(false)
	assert_bool(FireField.is_cardinal_line(_cells([[1, 1], [2, 1], [3, 1]]))).is_true()
	assert_bool(FireField.is_cardinal_line(_cells([[0, 2], [1, 1], [2, 0]]))).override_failure_message(
		"a square diagonal is not a line"
	).is_false()
