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


func test_dom_contains_new_buildings_npcs_and_interactive_events() -> void:
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(5)

	for node_name in [
		"RegistryArchive",
		"BellHouse",
		"RiverShrine",
		"IronCompaniesBarracks",
		"ItemShop",
		"EquipmentShop",
		"TownHall",
		"ChefsHouse",
		"PlayersHouse",
		"HadrikVale",
		"TomaReedhand",
		"SellaVarn",
		"NoticeBoard",
		"BellHouseDoor",
		"RiverShrineMarker",
		"ItemShopDoor",
		"EquipmentShopDoor",
		"GarrisonDoor",
		"TownHallDoor",
		"ChefsHouseDoor",
		"PlayersHouseDoor",
		"SavePoint",
		"BuildingBoundaries",
	]:
		assert_object(runner.find_child(node_name, true, false)).is_not_null()


func test_dom_shops_and_home_save_point_are_repeatable_interactions() -> void:
	var original_flags := GameState.flags.duplicate(true)
	var original_inventory := GameState.inventory.serialize()
	var original_gp := GameState.gp
	var original_autosave_reason := SaveGame._pending_autosave_reason
	GameState.flags.clear()
	SaveGame._pending_autosave_reason = ""

	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(5)
	var player: Node2D = runner.find_child("Player", true, false)
	var item_shop: SMInteractable = runner.find_child("ItemShopDoor", true, false)
	var save_point: SMInteractable = runner.find_child("SavePoint", true, false)
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true

	item_shop._on_body(player, true)
	item_shop._unhandled_input(interact)
	assert_bool(UIManager.is_open()).is_true()
	await runner.simulate_frames(2)
	var shop: ShopScreen = UIManager._stack.back()
	var bread_before := GameState.item_count(ItemIds.CONSUMABLES_LOAM_BREAD)
	shop._buy(ShopScreen.ITEM_STOCK[0])
	assert_int(GameState.gp).is_equal(original_gp - int(ShopScreen.ITEM_STOCK[0]["price"]))
	assert_int(GameState.item_count(ItemIds.CONSUMABLES_LOAM_BREAD)).is_equal(bread_before + 1)
	UIManager.close_all()
	await runner.simulate_frames(2)
	item_shop._unhandled_input(interact)
	assert_bool(GameState.get_flag("dom_item_shop_visited")).is_true()
	assert_bool(item_shop._used).is_false()
	UIManager.close_all()

	save_point._on_body(player, true)
	save_point._unhandled_input(interact)
	assert_bool(GameState.get_flag("dom_save_point_used")).is_true()
	assert_str(SaveGame._pending_autosave_reason).is_equal("save-point-save_point")

	GameState.flags = original_flags
	SaveGame._pending_autosave_reason = original_autosave_reason
	GameState.inventory.clear()
	GameState.inventory.deserialize(original_inventory)
	GameState.inventory_changed.emit()
	GameState.gp = original_gp


func test_bellhouse_quest_opens_the_inspection_event_and_can_be_completed() -> void:
	var original_flags := GameState.flags.duplicate(true)
	var original_quests := QuestRegistry.to_dict().duplicate(true)
	GameState.flags.clear()
	QuestRegistry.reset()

	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(5)
	var bell: SMInteractable = runner.find_child("BellHouseDoor", true, false)
	var player: Node2D = runner.find_child("Player", true, false)

	# The bell cannot be inspected before Sella offers the quest.
	bell._on_body(player, true)
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	bell._unhandled_input(interact)
	assert_bool(GameState.get_flag("dom_bellhouse_inspected")).is_false()

	QuestRegistry.offer(QuestRegistry.BELLHOUSE_REPAIR)
	bell._unhandled_input(interact)
	assert_bool(GameState.get_flag("dom_bellhouse_inspected")).is_true()

	QuestRegistry.turn_in(QuestRegistry.BELLHOUSE_REPAIR, "heard-the-silence", false)
	assert_bool(QuestRegistry.is_done(QuestRegistry.BELLHOUSE_REPAIR)).is_true()

	QuestRegistry.reset()
	QuestRegistry.from_dict(original_quests)
	GameState.flags = original_flags
