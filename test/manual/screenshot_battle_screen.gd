extends GdUnitTestSuite
## Screenshot harness, not an assertion suite — run under Xvfb to eyeball the
## battle screen (used for #211 layout QA). scripts/test.sh excludes test/manual
## from whole-tree runs; invoke this file explicitly under Xvfb.
## Whole-tree CI and acceptance runs skip it.
##   xvfb-run -a -s "-screen 0 1920x1080x24" bash addons/gdUnit4/runtest.sh \
##     -a test/manual/screenshot_battle_screen.gd
## Writes user://battle_screen_qa.png.

const CAPTURE_SIZE := Vector2i(1920, 1080)


func test_capture_battle_screen() -> void:
	get_tree().root.size = CAPTURE_SIZE
	Battle.start(&"dorthkor-vanguard")
	var runner := scene_runner("res://ui/screens/battle.tscn")
	var screen := runner.scene() as Control
	screen.theme = ThemeBuilder.build()
	await runner.simulate_frames(20)
	var stage := screen.find_child("Stage", true, false) as BattleStageRegion
	assert_str(stage.background_texture_path()).ends_with(
		"dorthkor-road-battlefield-v1.png"
	)
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
	assert_object(image.get_size()).is_equal(CAPTURE_SIZE)
	image.save_png("user://battle_screen_qa.png")
	print("SAVED ", ProjectSettings.globalize_path("user://battle_screen_qa.png"), " ", image.get_size())
	assert_bool(image.get_size().x > 0).is_true()
