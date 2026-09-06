extends GdUnitTestSuite
## Screenshot sweep harness, not an assertion suite — photographs every screen
## and scene for visual QA. scripts/test.sh excludes test/manual from whole-tree
## runs; invoke this file explicitly under Xvfb.
##   xvfb-run -a -s "-screen 0 1920x1080x24" bash addons/gdUnit4/runtest.sh \
##     -a test/manual/screenshot_sweep.gd
## Writes user://qa/<name>.png per capture.

const CAPTURE_SIZE := Vector2i(1920, 1080)


func before() -> void:
	get_tree().root.size = CAPTURE_SIZE
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
	# In real play GameFlow._complete_scene_load() discovers the arrival hub on
	# the new-game boot; the sweep never travels, so seed it or the region map
	# photographs empty.
	GameState.discover_fast_travel_hub(&"dom")


## Quest activity in the seeded sweep state can pop UIManager's modal reward
## reveal over ANY later capture (it photobombed 02_chargen and 23_battle_grid).
## Hide it before every shot — the sweep photographs screens, not reward flow.
func _suppress_reward_reveal() -> void:
	var reveal := UIManager.get_node_or_null("RewardReveal")
	if reveal is CanvasItem:
		(reveal as CanvasItem).visible = false


func _shoot(
		scene_path: String,
		shot_name: String,
		frames: int = 25,
		player_anchor := Vector2.INF,
) -> void:
	var runner := scene_runner(scene_path)
	var scene := runner.scene()
	if scene is Control:
		(scene as Control).theme = ThemeBuilder.build()
	await runner.simulate_frames(frames)
	# The seeded QA save restores the player's SAVED position into every field
	# scene; for small scenes that lands outside the authored bounds and the
	# camera photographs empty clear color. An explicit anchor re-frames the
	# shot on the scene's own content.
	if player_anchor != Vector2.INF:
		var player := scene.get_node_or_null("Player")
		print("ANCHOR %s player=%s" % [shot_name, player])
		if player is Node2D:
			(player as Node2D).global_position = player_anchor
			var anchor_camera := (player as Node2D).get_node_or_null("Camera2D")
			if anchor_camera is Camera2D:
				# Earlier runner scenes stay in the tree, so THEIR camera is
				# still current — reclaim the viewport for this scene's shot.
				(anchor_camera as Camera2D).make_current()
				(anchor_camera as Camera2D).reset_smoothing()
		await runner.simulate_frames(2)
	var boot_scene := scene.get_tree().current_scene
	if boot_scene != null and boot_scene != scene:
		boot_scene.hide()
	_suppress_reward_reveal()
	await runner.simulate_frames(3)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := scene.get_viewport().get_texture().get_image()
	assert_object(image.get_size()).is_equal(CAPTURE_SIZE)
	image.save_png("user://qa/%s.png" % shot_name)
	print("SHOT %s %s" % [shot_name, image.get_size()])
	if boot_scene != null and boot_scene != scene:
		boot_scene.show()
	# Runner scenes stay in the tree until the test case ends — hide this one so
	# it cannot photobomb the next capture.
	if scene is CanvasItem:
		(scene as CanvasItem).hide()


## The chargen wizard is paged — photograph the illustrated pages a single
## cold-load shot (02_chargen, the Ancestry page) cannot show.
func test_chargen_wizard_pages() -> void:
	var runner := scene_runner("res://ui/screens/character_creation.tscn")
	var screen := runner.scene() as CharacterCreationScreen
	screen.theme = ThemeBuilder.build()
	await runner.simulate_frames(25)
	screen.select_ancestry(str(ChargenData.ANCESTRIES[4].get("id", "")))
	await runner.simulate_frames(5)
	await _capture_current(runner, screen, "02a_chargen_ancestry")
	screen.go_to_step(&"attributes")
	await runner.simulate_frames(5)
	await _capture_current(runner, screen, "02b_chargen_attributes")
	screen.go_to_step(&"identity")
	await runner.simulate_frames(5)
	await _capture_current(runner, screen, "02c_chargen_identity")
	if screen is CanvasItem:
		(screen as CanvasItem).hide()


func _capture_current(runner: GdUnitSceneRunner, scene: Node, shot_name: String) -> void:
	var boot_scene := scene.get_tree().current_scene
	if boot_scene != null and boot_scene != scene:
		boot_scene.hide()
	_suppress_reward_reveal()
	await runner.simulate_frames(3)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := scene.get_viewport().get_texture().get_image()
	image.save_png("user://qa/%s.png" % shot_name)
	print("SHOT %s %s" % [shot_name, image.get_size()])
	if boot_scene != null and boot_scene != scene:
		boot_scene.show()


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


## The blank-stage regression shipped unphotographed because the sweep had no
## battle capture — battle needs a live encounter, so it gets its own case.
func test_battle_screen() -> void:
	var member := PartyMember.new()
	member.display_name = "Sweep Fighter"
	member.hp = 40
	member.max_hp = 40
	GameState.party.append(member)
	Battle.start("trial-warden")
	await _shoot("res://ui/screens/battle.tscn", "23_battle_grid")
	Battle._release_battlefield_ground()
	Battle.controller = null
	Battle.allies.clear()
	Battle.enemies.clear()
	Battle._definition.clear()
	Battle._combat_history.clear()
	GameState.party.erase(member)


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
	var image := screen.get_viewport().get_texture().get_image()
	assert_object(image.get_size()).is_equal(CAPTURE_SIZE)
	image.save_png("user://qa/15_shop.png")
	print("SHOT 15_shop")
	if boot_scene != null and boot_scene != screen:
		boot_scene.show()


func test_marshal_conversation() -> void:
	var runner := scene_runner("res://world/starting_town.tscn")
	var town := runner.scene()
	await runner.simulate_frames(40)
	var boot_scene := town.get_tree().current_scene
	if boot_scene != null and boot_scene != town:
		boot_scene.hide()

	var balloon: Node = load("res://ui/dialogue/dialogue_balloon.tscn").instantiate()
	town.add_child(balloon)
	balloon.call("start", load("res://dialogue/marshal_coiljaw.dialogue"), "start")
	await runner.simulate_frames(10)
	var portrait := balloon.get("_portrait") as SMPortrait
	var portrait_image := portrait.get("_image") as TextureRect
	assert_str(portrait_image.texture.resource_path).ends_with(
		"marshal_coiljaw_portrait_neutral.png"
	)

	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := town.get_viewport().get_texture().get_image()
	assert_object(image.get_size()).is_equal(CAPTURE_SIZE)
	image.save_png("user://qa/16_marshal_conversation.png")
	print("SHOT 16_marshal_conversation %s" % image.get_size())
	balloon.free()
	if boot_scene != null and boot_scene != town:
		boot_scene.show()
	if town is CanvasItem:
		(town as CanvasItem).hide()


func test_iris_conversation() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var field := runner.scene()
	await runner.simulate_frames(40)
	var boot_scene := field.get_tree().current_scene
	if boot_scene != null and boot_scene != field:
		boot_scene.hide()

	var balloon: Node = load("res://ui/dialogue/dialogue_balloon.tscn").instantiate()
	field.add_child(balloon)
	balloon.call("start", load("res://dialogue/iris_illepah.dialogue"), "start")
	await runner.simulate_frames(10)
	var portrait := balloon.get("_portrait") as SMPortrait
	var portrait_image := portrait.get("_image") as TextureRect
	assert_str(portrait_image.texture.resource_path).ends_with(
		"iris_illepah_portrait_neutral.png"
	)

	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := field.get_viewport().get_texture().get_image()
	assert_object(image.get_size()).is_equal(CAPTURE_SIZE)
	image.save_png("user://qa/17_iris_conversation.png")
	print("SHOT 17_iris_conversation %s" % image.get_size())
	balloon.free()
	if boot_scene != null and boot_scene != field:
		boot_scene.show()
	if field is CanvasItem:
		(field as CanvasItem).hide()


func test_sella_conversation() -> void:
	var runner := scene_runner("res://world/interiors/trial_hall.tscn")
	var hall := runner.scene()
	await runner.simulate_frames(40)
	var boot_scene := hall.get_tree().current_scene
	if boot_scene != null and boot_scene != hall:
		boot_scene.hide()

	var balloon: Node = load("res://ui/dialogue/dialogue_balloon.tscn").instantiate()
	hall.add_child(balloon)
	balloon.call("start", load("res://dialogue/sella_varn.dialogue"), "start")
	await runner.simulate_frames(10)
	var portrait := balloon.get("_portrait") as SMPortrait
	var portrait_image := portrait.get("_image") as TextureRect
	assert_str(portrait_image.texture.resource_path).ends_with(
		"sella_varn_portrait_neutral.png"
	)

	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := hall.get_viewport().get_texture().get_image()
	assert_object(image.get_size()).is_equal(CAPTURE_SIZE)
	image.save_png("user://qa/18_sella_conversation.png")
	print("SHOT 18_sella_conversation %s" % image.get_size())
	balloon.free()
	if boot_scene != null and boot_scene != hall:
		boot_scene.show()
	if hall is CanvasItem:
		(hall as CanvasItem).hide()


func test_hadrik_conversation() -> void:
	var runner := scene_runner("res://world/interiors/registry_archive.tscn")
	var archive := runner.scene()
	await runner.simulate_frames(40)
	var boot_scene := archive.get_tree().current_scene
	if boot_scene != null and boot_scene != archive:
		boot_scene.hide()

	var balloon: Node = load("res://ui/dialogue/dialogue_balloon.tscn").instantiate()
	archive.add_child(balloon)
	balloon.call(
		"start",
		load("res://dialogue/dom_side_quests.dialogue"),
		"dom_side_rainbound_register",
	)
	await runner.simulate_frames(10)
	var portrait := balloon.get("_portrait") as SMPortrait
	var portrait_image := portrait.get("_image") as TextureRect
	assert_str(portrait_image.texture.resource_path).ends_with(
		"hadrik_vale_portrait_neutral.png"
	)

	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := archive.get_viewport().get_texture().get_image()
	assert_object(image.get_size()).is_equal(CAPTURE_SIZE)
	image.save_png("user://qa/19_hadrik_conversation.png")
	print("SHOT 19_hadrik_conversation %s" % image.get_size())
	balloon.free()
	if boot_scene != null and boot_scene != archive:
		boot_scene.show()
	if archive is CanvasItem:
		(archive as CanvasItem).hide()


func test_toma_conversation() -> void:
	var runner := scene_runner("res://world/interiors/river_shrine.tscn")
	var shrine := runner.scene()
	await runner.simulate_frames(40)
	var boot_scene := shrine.get_tree().current_scene
	if boot_scene != null and boot_scene != shrine:
		boot_scene.hide()

	var balloon: Node = load("res://ui/dialogue/dialogue_balloon.tscn").instantiate()
	shrine.add_child(balloon)
	balloon.call("start", load("res://dialogue/toma_reedhand.dialogue"), "start")
	await runner.simulate_frames(10)
	var portrait := balloon.get("_portrait") as SMPortrait
	var portrait_image := portrait.get("_image") as TextureRect
	assert_str(portrait_image.texture.resource_path).ends_with(
		"toma_reedhand_portrait_neutral.png"
	)

	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := shrine.get_viewport().get_texture().get_image()
	assert_object(image.get_size()).is_equal(CAPTURE_SIZE)
	image.save_png("user://qa/19_toma_conversation.png")
	print("SHOT 19_toma_conversation %s" % image.get_size())
	balloon.free()
	if boot_scene != null and boot_scene != shrine:
		boot_scene.show()
	if shrine is CanvasItem:
		(shrine as CanvasItem).hide()


func test_field_scenes() -> void:
	await _shoot("res://world/starting_town.tscn", "20_town", 40)
	await _shoot("res://world/test_room.tscn", "21_wilds", 40)
	await _shoot("res://world/dorthkor_road.tscn", "22_dorthkor_road", 40, Vector2(900, 450))
	await _shoot("res://world/wound_lip.tscn", "24_wound_lip", 40, Vector2(900, 450))


func test_interiors() -> void:
	await _shoot("res://world/interiors/dom_tavern.tscn", "30_tavern_interior", 40)
	await _shoot("res://world/interiors/item_shop.tscn", "31_item_shop_interior", 40)
	await _shoot("res://world/interiors/trial_hall.tscn", "32_trial_hall_interior", 40)
	await _shoot("res://world/interiors/river_shrine.tscn", "33_river_shrine_interior", 40)
