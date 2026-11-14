extends GdUnitTestSuite
## Hex grid H1 at runtime (owner item 34; docs/design/hex-grid-plan-2026-11-03.md): the real test
## room with `soul_meter/grid/hex` on. A held key steps the player onto a hex, a click walks a hex
## path to the spot, and the followers trail through hexes two to a place in line.
## The setting is restored after each test; every other suite runs with it off.

const ROOM := "res://world/test_room.tscn"

var _setting_before: Variant
var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	_setting_before = ProjectSettings.get_setting(IsoGrid.HEX_SETTING, false)
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, true)


func after_test() -> void:
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, _setting_before)
	GameState.from_dict(_saved_state)


func _on_a_hex_centre(grid: IsoGrid, position: Vector2) -> bool:
	return grid.cell_to_world(grid.world_to_cell(position)).distance_to(position) < 0.5


func _settle(runner: GdUnitSceneRunner, player: Node2D, grid: IsoGrid) -> void:
	for _frame in 180:
		await runner.simulate_frames(1)
		if _on_a_hex_centre(grid, player.global_position):
			return


func test_a_held_key_steps_the_player_onto_a_hex() -> void:
	var runner := scene_runner(ROOM)
	await runner.simulate_frames(5)
	var player := runner.find_child("Player", true, false) as Node2D
	var controller := player.find_child("ClickMoveController", true, false) as ClickMoveController
	var grid := controller.get_iso_grid()
	assert_bool(grid.hex_mode).is_true()
	var start := player.global_position
	runner.simulate_action_press("move_right")
	await runner.simulate_frames(30)
	runner.simulate_action_release("move_right")
	await _settle(runner, player, grid)
	assert_float(player.global_position.x).is_greater(start.x)
	assert_bool(_on_a_hex_centre(grid, player.global_position)).override_failure_message(
		"the player came to rest off a hex centre at %s" % player.global_position
	).is_true()


func test_a_click_walks_a_hex_path_to_the_spot() -> void:
	var runner := scene_runner(ROOM)
	await runner.simulate_frames(5)
	var player := runner.find_child("Player", true, false) as Node2D
	var controller := player.find_child("ClickMoveController", true, false) as ClickMoveController
	var grid := controller.get_iso_grid()
	var here := grid.world_to_cell(player.global_position)
	# A spot about four cells away (eight hexes), open, on the map.
	var target_hex := Vector2i.ZERO
	var found := false
	for hex: Vector2i in HexMath.ring(here, 8):
		if grid.is_in_bounds(hex) and not grid.is_blocked_for(hex, player):
			target_hex = hex
			found = true
			break
	assert_bool(found).is_true()
	var result := controller.request_move_to(grid.cell_to_world(target_hex))
	assert_bool(bool(result.get("allowed", false))).override_failure_message("refused: %s" % result).is_true()
	var path := grid.path_cells(here, target_hex, player)
	for cell: Vector2 in path:
		assert_bool(grid.is_blocked_for(Vector2i(cell), player)).is_false()
	for _frame in 400:
		await runner.simulate_frames(1)
		if not controller.has_path():
			break
	assert_float(player.global_position.distance_to(grid.cell_to_world(target_hex))).is_less(HexLayout.DEFAULT_STEP)


func test_followers_trail_through_hexes_two_to_a_place() -> void:
	if GameState.companions().is_empty():
		GameState._seed_demo_data()
	var runner := scene_runner(ROOM)
	await runner.simulate_frames(5)
	var player := runner.find_child("Player", true, false) as Node2D
	var followers := runner.find_child("PartyFollowers", true, false) as PartyFollowers
	var grid := (player.find_child("ClickMoveController", true, false) as ClickMoveController).get_iso_grid()
	runner.simulate_action_press("move_right")
	await runner.simulate_frames(90)
	runner.simulate_action_release("move_right")
	await _settle(runner, player, grid)
	var trail := followers.trail_target_for(0)
	assert_bool(_on_a_hex_centre(grid, trail)).override_failure_message("the trail is off the hexes").is_true()
	# Two hexes behind the player, the ground one cell covers.
	var behind := HexMath.distance(grid.world_to_cell(player.global_position), grid.world_to_cell(trail))
	assert_int(behind).is_between(1, 2)
