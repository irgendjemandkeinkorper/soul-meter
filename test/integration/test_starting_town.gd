extends GdUnitTestSuite
## Integration tests for world/starting_town.tscn (Dom, the starting town) and
## ui/screens/tavern.gd. See docs/testing.md for when to reach for scene_runner
## vs. a plain unit suite.


func test_tavern_door_prompt_only_shows_when_player_is_in_range() -> void:
	var runner := scene_runner("res://world/starting_town.tscn")
	var door: Node2D = runner.find_child("TavernDoor", true, false)
	var player: Node2D = runner.find_child("Player", true, false)
	var prompt: Label = door.find_child("@Label@*", true, false)

	assert_bool(prompt.visible).is_false()

	player.global_position = door.global_position
	await runner.simulate_frames(20)

	assert_bool(prompt.visible).is_true()


func test_interacting_with_tavern_door_opens_tavern_screen() -> void:
	var runner := scene_runner("res://world/starting_town.tscn")
	var door: Node2D = runner.find_child("TavernDoor", true, false)
	var player: Node2D = runner.find_child("Player", true, false)

	player.global_position = door.global_position
	await runner.simulate_frames(20)
	assert_bool(UIManager.is_open()).is_false()

	runner.simulate_action_press("interact")
	await runner.simulate_frames(5)
	runner.simulate_action_release("interact")

	assert_bool(UIManager.is_open()).is_true()

	UIManager.close_all()
	await runner.simulate_frames(5)


func test_tavern_screen_lists_all_recruitable_candidates() -> void:
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(5)

	var screen = UIManager.open(UIManager.TAVERN, true)
	await runner.simulate_frames(5)

	assert_int(screen._checks.size()).is_equal(GameState.recruitable_candidates().size())

	UIManager.close_all()
	await runner.simulate_frames(5)


func test_cannot_select_more_than_max_party_size() -> void:
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(5)

	var screen = UIManager.open(UIManager.TAVERN, true)
	await runner.simulate_frames(5)

	for i in range(3):
		screen._checks[i].button_pressed = true
		screen._on_toggled(true, screen._checks[i])

	assert_bool(screen._checks[2].button_pressed).is_false()

	UIManager.close_all()
	await runner.simulate_frames(5)


func test_choosing_candidates_and_confirming_replaces_party() -> void:
	GameState._seed_demo_data()
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(5)

	var screen = UIManager.open(UIManager.TAVERN, true)
	await runner.simulate_frames(5)

	screen._checks[_candidate_index(screen, "Serai-Lun")].button_pressed = true
	screen._checks[_candidate_index(screen, "Old Grumbrand")].button_pressed = true
	screen._on_confirm()
	await runner.simulate_frames(5)

	assert_int(GameState.party.size()).is_equal(3)
	var names := [
		GameState.party[0].display_name,
		GameState.party[1].display_name,
		GameState.party[2].display_name,
	]
	assert_str(GameState.party[0].display_name).is_equal("Vex the Unbowed")
	assert_array(names).contains("Serai-Lun", "Old Grumbrand")
	assert_bool(UIManager.is_open()).is_false()

	# Restore the default demo party/inventory so later test runs aren't affected.
	GameState._seed_demo_data()


func test_candidate_requiring_reputation_is_locked_until_earned() -> void:
	Renown.from_dict({})  # clean slate so this test doesn't depend on run order
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(5)

	var screen = UIManager.open(UIManager.TAVERN, true)
	await runner.simulate_frames(5)
	var idx := _candidate_index(screen, "Korrath Ninefold")
	assert_bool(screen._checks[idx].disabled).is_true()
	UIManager.close_all()
	await runner.simulate_frames(5)

	Renown.gain_reputation("player", 10.0, "test setup", "test_room")

	screen = UIManager.open(UIManager.TAVERN, true)
	await runner.simulate_frames(5)
	idx = _candidate_index(screen, "Korrath Ninefold")
	assert_bool(screen._checks[idx].disabled).is_false()
	UIManager.close_all()
	await runner.simulate_frames(5)

	Renown.from_dict({})  # don't leak into later tests


func test_candidate_requiring_infamy_is_locked_until_earned() -> void:
	Renown.from_dict({})
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(5)

	var screen = UIManager.open(UIManager.TAVERN, true)
	await runner.simulate_frames(5)
	var idx := _candidate_index(screen, "Maura Greyfen")
	assert_bool(screen._checks[idx].disabled).is_true()
	UIManager.close_all()
	await runner.simulate_frames(5)

	Renown.gain_infamy("player", 8.0, "test setup", "test_room")

	screen = UIManager.open(UIManager.TAVERN, true)
	await runner.simulate_frames(5)
	idx = _candidate_index(screen, "Maura Greyfen")
	assert_bool(screen._checks[idx].disabled).is_false()
	UIManager.close_all()
	await runner.simulate_frames(5)

	Renown.from_dict({})


func _candidate_index(screen, display_name: String) -> int:
	for i in screen._candidates.size():
		if screen._candidates[i].display_name == display_name:
			return i
	fail("no candidate named '%s'" % display_name)
	return -1


func test_travel_exit_updates_gameflow_target_scene() -> void:
	var original_flags := GameState.flags.duplicate(true)
	var original_target: String = GameFlow._target_scene
	GameState.flags.clear()
	GameFlow._target_scene = GameFlow.TOWN_SCENE
	var runner := scene_runner("res://world/starting_town.tscn")
	var exit_node: TravelExit = runner.find_child("RoadToTheWilds", true, false)
	var player: Node2D = runner.find_child("Player", true, false)

	exit_node._on_body_entered(player)
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TOWN_SCENE)

	GameState.set_flag("chapter_one_free_roam", true)
	exit_node._on_body_entered(player)
	assert_str(GameFlow._target_scene).is_equal(GameFlow.WILDS_SCENE)
	GameState.flags = original_flags
	GameFlow._target_scene = original_target
