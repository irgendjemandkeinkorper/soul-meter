extends GdUnitTestSuite
## Integration tests for world/starting_town.tscn (Dom, the starting town) and
## ui/screens/tavern.gd. See docs/testing.md for when to reach for scene_runner
## vs. a plain unit suite.


## The tavern assertions assume no one has been recruited yet ("Available",
## check-toggle counting), but earlier suites in a whole-tree run leave their
## recruited party in the GameState autoload. Establish the precondition
## instead of assuming a clean autoload. set_companions() can't do this — it
## validates for exactly REQUIRED_COMPANIONS and refuses an empty list — so
## reset via the wholesale set_party() path, keeping only the lead.
func before_test() -> void:
	_set_lead_only()


func after_test() -> void:
	_set_lead_only()


func _set_lead_only() -> void:
	var lead_only: Array[PartyMember] = []
	for member: PartyMember in GameState.party:
		if member.id == GameState.PROTAGONIST_ID:
			lead_only.append(member)
	GameState.set_party(lead_only)


func test_party_followers_spawn_on_the_shared_grid_cell_center() -> void:
	var party: Array[PartyMember] = GameState.party.duplicate()
	var candidates: Array[PartyMember] = GameState.recruitable_candidates()
	party.append(candidates[0])
	GameState.set_party(party)

	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(2)
	var manager := runner.find_child("PartyFollowers", true, false) as PartyFollowers
	var player := runner.find_child("Player", true, false) as Node2D
	var ground := runner.find_child("IsometricGround", true, false) as TileMapLayer

	assert_object(manager).is_not_null()
	assert_object(ground).is_not_null()
	assert_int(manager.follower_count()).is_equal(1)
	var player_cell: Vector2i = ground.local_to_map(ground.to_local(player.global_position))
	var player_center: Vector2 = ground.to_global(ground.map_to_local(player_cell))
	assert_vector(manager.trail_target_for(0)).is_equal(player_center)
	assert_vector(manager.followers()[0].global_position).is_equal(player_center)
	var follower_node: Node = manager.followers()[0]
	assert_bool(follower_node is CollisionObject2D).is_false()


func test_tavern_door_prompt_only_shows_when_player_is_in_range() -> void:
	var runner := scene_runner("res://world/starting_town.tscn")
	var door: Node2D = runner.find_child("TavernDoor", true, false)
	var player: Node2D = runner.find_child("Player", true, false)
	var prompt: Label = door.find_child("@Label@*", true, false)

	assert_bool(prompt.visible).is_false()

	player.global_position = door.global_position
	await runner.simulate_frames(20)

	assert_bool(prompt.visible).is_true()


func test_interacting_with_tavern_door_requests_tavern_interior_travel() -> void:
	var runner := scene_runner("res://world/starting_town.tscn")
	var door: Node2D = runner.find_child("TavernDoor", true, false)
	var player: Node2D = runner.find_child("Player", true, false)
	var original_target: String = GameFlow._target_scene
	var original_spawn: StringName = GameFlow._target_spawn_id

	player.global_position = door.global_position
	await runner.simulate_frames(20)
	assert_bool(UIManager.is_open()).is_false()

	runner.simulate_action_press("interact")
	await runner.simulate_frames(1)
	runner.simulate_action_release("interact")

	assert_bool(UIManager.is_open()).is_false()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TAVERN_SCENE)
	assert_str(GameFlow._target_spawn_id).is_equal("entry")
	GameFlow._target_scene = original_target
	GameFlow._target_spawn_id = original_spawn


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


func test_tavern_detail_sheet_focuses_first_candidate_and_follows_selection() -> void:
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(5)

	var screen = UIManager.open(UIManager.TAVERN, true)
	await runner.simulate_frames(5)

	# recruitable_candidates() constructs fresh PartyMember instances per call, so this
	# must compare against the screen's own _candidates array, not a re-fetched one.
	var candidates: Array[PartyMember] = screen._candidates
	assert_object(screen._focused_member).is_equal(candidates[0])
	assert_str(screen._detail_name_lbl.text).contains(candidates[0].display_name)
	assert_str(screen._detail_status_lbl.text).is_equal("Available")

	screen._on_row_gui_input(
		InputEventMouseButton.new(), candidates[1]
	)  # not a left-click press: no-op, proves focus only moves on a real click
	assert_object(screen._focused_member).is_equal(candidates[0])

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen._on_row_gui_input(click, candidates[1])
	assert_object(screen._focused_member).is_equal(candidates[1])
	assert_str(screen._detail_name_lbl.text).contains(candidates[1].display_name)

	screen._checks[1].button_pressed = true
	screen._on_toggled(true, screen._checks[1])
	assert_str(screen._detail_status_lbl.text).is_equal("Chosen for the company")

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
	]:
		assert_object(runner.find_child(node_name, true, false)).is_not_null()


func test_dom_buildings_use_rendered_sprites_and_y_sorting() -> void:
	var packed := load("res://world/starting_town.tscn") as PackedScene
	var town := packed.instantiate() as Node2D
	auto_free(town)

	assert_bool(town.y_sort_enabled).is_true()
	assert_int(town.find_children("*", "ColorRect", true, false).size()).is_equal(0)
	for building_name in [
		"TrialHall",
		"RegistryArchive",
		"BellHouse",
		"RiverShrine",
		"IronCompaniesBarracks",
		"LowerMarket",
		"ItemShop",
		"EquipmentShop",
		"TownHall",
		"ChefsHouse",
		"PlayersHouse",
		"FourArmsTavern",
	]:
		var building := town.find_child(building_name, true, false) as Node2D
		assert_object(building).is_not_null()
		var sprites := building.find_children("*", "Sprite2D", true, false)
		assert_int(sprites.size()).is_greater(0)
		for sprite: Sprite2D in sprites:
			assert_object(sprite.texture).is_not_null()
			assert_float(sprite.offset.y).is_less(-50.596)

	# The block that used to live here asserted each building's y-position against its
	# `BuildingBoundaries` rectangle. Those rectangles were the second, drifting source of truth
	# for passability and are deleted (GH #187) — the assertion went with them. It is NOT
	# reconstructable against the `Blocking` layer: painted cells are a set, not a rectangle,
	# with no "bottom edge" to compare a sprite origin to. What it was really protecting (a
	# sortable sprite's origin sits at its feet, §2.4 rule 3) is covered by
	# test/integration/test_y_sort.gd.

	for dressing_name in ["OakNorthWest", "PineNorth", "RockEast", "GrassShrine"]:
		assert_object(town.find_child(dressing_name, true, false)).is_not_null()
	var old_tavern_facade := town.get_node("TavernDoor/Facade") as Polygon2D
	assert_bool(old_tavern_facade.visible).is_false()


func test_dom_shops_and_home_save_point_are_repeatable_interactions() -> void:
	var original_flags := GameState.flags.duplicate(true)
	var original_inventory := GameState.inventory.serialize()
	var original_vendor_stock := GameState.vendor_stock.duplicate(true)
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
	var bread_entry: Dictionary = {}
	for entry: Dictionary in shop.catalog_entries():
		if entry["id"] == ItemIds.CONSUMABLES_LOAM_BREAD:
			bread_entry = entry
			break
	assert_bool(bread_entry.is_empty()).is_false()
	shop._buy(bread_entry)
	assert_int(GameState.gp).is_equal(original_gp - int(bread_entry["buy_price"]))
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
	GameState.vendor_stock = original_vendor_stock
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


func test_blocking_cells_are_authored_data_not_painted_by_code() -> void:
	# GH #187. The whole point is that the layer can be OPENED AND PAINTED. Instantiating
	# without adding to the tree means no `_ready()` has run — anything present here is data
	# that came out of the .tscn, which is exactly what an editor would show an author.
	var town := (load("res://world/starting_town.tscn") as PackedScene).instantiate() as Node2D
	auto_free(town)

	var blocking := town.find_child("Blocking", true, false) as TileMapLayer
	assert_object(blocking).is_not_null()
	assert_int(blocking.get_used_cells().size()) \
		.override_failure_message(
			"Blocking has no authored cells — they must live in tile_map_data, not in code"
		) \
		.is_greater(200)

	# The TileSet is a real resource on disk, not built at runtime.
	assert_object(blocking.tile_set).is_not_null()
	assert_str(blocking.tile_set.resource_path).is_equal("res://world/nav/blocking_tiles.tres")
	assert_int(blocking.tile_set.get_physics_layers_count()).is_greater(0)

	# The script is a file under world/nav/, not an embedded SubResource.
	assert_str(blocking.get_script().resource_path).is_equal("res://world/nav/blocking_layer.gd")

	# The legacy duplicate obstacle authoring path is gone (#187) — `Blocking` is the only one.
	assert_object(town.find_child("BuildingBoundaries", true, false)) \
		.override_failure_message("BuildingBoundaries is a second source of truth; it must stay deleted") \
		.is_null()
