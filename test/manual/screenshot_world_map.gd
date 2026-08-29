extends GdUnitTestSuite
## Screenshot harness, not an assertion suite — run under Xvfb to eyeball the
## world-map screen (Wave 2 travel QA). scripts/test.sh excludes test/manual
## from whole-tree runs; invoke this file explicitly under Xvfb.
##   xvfb-run -a -s "-screen 0 1920x1080x24" bash addons/gdUnit4/runtest.sh \
##     -a test/manual/screenshot_world_map.gd
## Writes user://world_map_qa.png.

const CAPTURE_SIZE := Vector2i(1920, 1080)


func test_capture_world_map() -> void:
	get_tree().root.size = CAPTURE_SIZE
	for location: Dictionary in WorldMapRegistry.all_locations():
		GameState.discover_world_location(StringName(location["id"]))
	var runner := scene_runner("res://ui/screens/region_map.tscn")
	var screen := runner.scene() as Control
	screen.theme = ThemeBuilder.build()
	await runner.simulate_frames(10)
	var map_screen := screen as RegionMapScreen
	map_screen._select_location(&"dorthkor-road")
	await runner.simulate_frames(5)
	var boot_scene := screen.get_tree().current_scene
	if boot_scene != null and boot_scene != screen:
		boot_scene.hide()
	await runner.simulate_frames(3)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := screen.get_viewport().get_texture().get_image()
	image.save_png("user://world_map_qa.png")
	print("SAVED ", ProjectSettings.globalize_path("user://world_map_qa.png"), " ", image.get_size())
	assert_bool(image.get_size().x > 0).is_true()
