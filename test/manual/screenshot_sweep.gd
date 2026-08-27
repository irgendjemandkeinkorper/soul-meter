extends GdUnitTestSuite
## Screenshot sweep harness, not an assertion suite — photographs every screen
## and scene for visual QA. Kept in test/manual/ so CI's -a test runs skip it.
##   xvfb-run -a -s "-screen 0 1920x1080x24" bash addons/gdUnit4/runtest.sh \
##     -a test/manual/screenshot_sweep.gd
## Writes user://qa/<name>.png per capture.


func before() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	# Give state-dependent screens something real to show.
	var candidates := GameState.recruitable_candidates()
	var picked: Array[PartyMember] = []
	for candidate in candidates:
		if candidate.min_reputation <= 0.0 and candidate.min_infamy <= 0.0:
			picked.append(candidate)
		if picked.size() >= 2:
			break
	GameState.set_companions(picked)
	GameState.inventory.create_and_add_item(ItemIds.MATERIALS_LOAMROOT_SPRIG)
	GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	GameState.inventory.create_and_add_item(ItemIds.CONSUMABLES_HEARTHLOAF)
	QuestRegistry.offer(QuestRegistry.FIELD_DEBT)


func _shoot(scene_path: String, shot_name: String, frames: int = 25) -> void:
	var runner := scene_runner(scene_path)
	var scene := runner.scene()
	if scene is Control:
		(scene as Control).theme = ThemeBuilder.build()
	await runner.simulate_frames(frames)
	var boot_scene := scene.get_tree().current_scene
	if boot_scene != null and boot_scene != scene:
		boot_scene.hide()
	await runner.simulate_frames(3)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := scene.get_viewport().get_texture().get_image()
	image.save_png("user://qa/%s.png" % shot_name)
	print("SHOT %s %s" % [shot_name, image.get_size()])
	if boot_scene != null and boot_scene != scene:
		boot_scene.show()
	# Runner scenes stay in the tree until the test case ends — hide this one so
	# it cannot photobomb the next capture.
	if scene is CanvasItem:
		(scene as CanvasItem).hide()


func test_menus_and_screens() -> void:
	await _shoot("res://ui/screens/main_menu.tscn", "01_main_menu")
	await _shoot("res://ui/screens/character_creation.tscn", "02_chargen")
	await _shoot("res://ui/screens/tavern.tscn", "03_tavern_picker")
	await _shoot("res://ui/screens/inventory.tscn", "04_inventory")
	await _shoot("res://ui/screens/party.tscn", "05_party")
	await _shoot("res://ui/screens/journal.tscn", "06_journal")
	await _shoot("res://ui/screens/standing.tscn", "07_standing")
	await _shoot("res://ui/screens/character_sheet.tscn", "08_character_sheet")
	await _shoot("res://ui/screens/region_map.tscn", "09_region_map")
	await _shoot("res://ui/screens/settings.tscn", "10_settings")
	await _shoot("res://ui/screens/load_game.tscn", "11_load_game")
	await _shoot("res://ui/screens/pause_menu.tscn", "12_pause_menu")
	await _shoot("res://ui/screens/chapter_complete.tscn", "13_chapter_complete")
	await _shoot("res://ui/screens/debug_menu.tscn", "14_debug_menu")


func test_shop_screen() -> void:
	var runner := scene_runner("res://ui/screens/shop.tscn")
	var screen := runner.scene() as Control
	screen.theme = ThemeBuilder.build()
	if screen.has_method("configure_shop"):
		screen.configure_shop("items")
	await runner.simulate_frames(25)
	var boot_scene := screen.get_tree().current_scene
	if boot_scene != null and boot_scene != screen:
		boot_scene.hide()
	await runner.simulate_frames(3)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	screen.get_viewport().get_texture().get_image().save_png("user://qa/15_shop.png")
	print("SHOT 15_shop")
	if boot_scene != null and boot_scene != screen:
		boot_scene.show()


func test_field_scenes() -> void:
	await _shoot("res://world/starting_town.tscn", "20_town", 40)
	await _shoot("res://world/test_room.tscn", "21_wilds", 40)
	await _shoot("res://world/dorthkor_road.tscn", "22_dorthkor_road", 40)


func test_interiors() -> void:
	await _shoot("res://world/interiors/dom_tavern.tscn", "30_tavern_interior", 40)
	await _shoot("res://world/interiors/item_shop.tscn", "31_item_shop_interior", 40)
	await _shoot("res://world/interiors/trial_hall.tscn", "32_trial_hall_interior", 40)
	await _shoot("res://world/interiors/river_shrine.tscn", "33_river_shrine_interior", 40)
