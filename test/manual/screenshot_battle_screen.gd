extends GdUnitTestSuite
## Screenshot harness, not an assertion suite — run under Xvfb to eyeball the
## battle screen (used for #211 layout QA). Kept in test/manual/ so `-a test`
## CI runs (which target test/unit, test/integration, test/e2e) skip it.
##   xvfb-run -a -s "-screen 0 1920x1080x24" bash addons/gdUnit4/runtest.sh \
##     -a test/manual/screenshot_battle_screen.gd
## Writes user://battle_screen_qa.png.


func test_capture_battle_screen() -> void:
	Battle.start(&"dorthkor-vanguard")
	var runner := scene_runner("res://ui/screens/battle.tscn")
	var screen := runner.scene() as Control
	screen.theme = ThemeBuilder.build()
	await runner.simulate_frames(20)
	# The harness scene sits BELOW the boot main menu in the canvas (in
	# production, battle opens inside UIManager's CanvasLayer, above the field
	# scene). Hide the boot scene so z0 battle content is photographable.
	var boot_scene := screen.get_tree().current_scene
	if boot_scene != null and boot_scene != screen:
		boot_scene.hide()
	await runner.simulate_frames(3)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := screen.get_viewport().get_texture().get_image()
	image.save_png("user://battle_screen_qa.png")
	print("SAVED ", ProjectSettings.globalize_path("user://battle_screen_qa.png"), " ", image.get_size())
	assert_bool(image.get_size().x > 0).is_true()
