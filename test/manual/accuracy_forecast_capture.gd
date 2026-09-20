extends GdUnitTestSuite
## Explicit rendered check of the accuracy forecast at two viewport sizes.


func test_accuracy_forecast_layout() -> void:
	var boot := get_tree().current_scene as CanvasItem
	var was_visible := boot.visible if boot != null else false
	if boot != null:
		boot.hide()
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	interface.theme = ThemeBuilder.build()
	interface.set_forecast_context({
		"to_hit_enabled": true,
		"unit": {"id": "caster", "alacrity": 4, "attack_scale": 1.0},
		"target": {"id": "target", "hp": 20, "element_id": &"tham"},
		"ability": {"id": "strike", "power": 10, "element_id": &"zhur", "elements": [&"zhur"], "magnitude": &"note"},
		"facing": {"id": &"side"}, "height_advantage_steps": -1,
	})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	for viewport_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_tree().root.size = viewport_size
		await runner.simulate_frames(5)
		var panel := interface.act_target_panel
		assert_bool(interface.get_global_rect().encloses(panel.get_global_rect())).is_true()
		assert_bool(panel.get_global_rect().encloses(panel.forecast.get_global_rect())).is_true()
		assert_str(panel.forecast.text).contains("HIT 82%")
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var capture := get_viewport().get_texture().get_image()
		assert_int(capture.save_png("user://qa/accuracy-%d.png" % viewport_size.x)).is_equal(OK)
	get_tree().root.size = Vector2i(1920, 1080)
	if boot != null:
		boot.visible = was_visible


func test_defining_strike_dialog_labels_both_checks() -> void:
	var saved := GameState.to_dict().duplicate(true)
	Battle.start(&"trial-warden")
	var target := Battle.controller.enemies[0]
	target.archetype_id = &"loam-maddened-boar"
	target.discovered_weakness_ids = [&"loam-maddened-boar/knee"]
	var runner := scene_runner("res://ui/screens/battle.tscn")
	var screen := runner.scene() as Screen
	screen.theme = ThemeBuilder.build()
	screen._open_weakness_dialog()
	await runner.simulate_frames(5)
	var label: Label = screen._weakness_forecast
	var dialog: Window = screen._weakness_dialog
	assert_str(label.text).contains("KNOWLEDGE")
	assert_str(label.text).contains("HIT")
	assert_str(label.text).contains("DAMAGE ON HIT")
	assert_bool(Rect2(Vector2.ZERO, Vector2(dialog.size)).encloses(label.get_global_rect())).is_true()
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	assert_int(dialog.get_texture().get_image().save_png("user://qa/defining-strike.png")).is_equal(OK)
	dialog.hide()
	Battle.controller = null
	Battle.ended = true
	Battle._release_field_grid()
	GameState.from_dict(saved)
