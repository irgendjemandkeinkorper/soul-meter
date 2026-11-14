extends GdUnitTestSuite
## Explicit rendered check of the accuracy forecast at two viewport sizes. On the one-bar HUD
## (owner 2026-11-01) the act-target panel lives in the tactical popover the bar's breakdown
## button opens, so the capture opens it first.


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
		"visibility": {"applies": true, "level": "obscured"},
		"attacker_injury_modifiers": [{"label": "Injury: Arm", "percentage_points": -15}],
	})
	interface.set_breakdown_visible(true)
	var hidden: Array = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	for viewport_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_tree().root.size = viewport_size
		await runner.simulate_frames(5)
		var panel := interface.act_target_panel
		assert_bool(interface.get_global_rect().encloses(panel.get_global_rect())).is_true()
		assert_bool(panel.get_global_rect().encloses(panel.forecast.get_global_rect())).is_true()
		assert_str(panel.forecast.text).contains("HIT 42%")
		assert_str(panel.accuracy_summary.text).contains("Visibility: obscured -25 pp · Injury: Arm -15 pp")
		# The popover IS the details (owner 2026-11-01): the full accuracy terms stay pinned
		# open and the in-panel compact/details toggle retires.
		assert_bool(panel.details_pinned).is_true()
		assert_bool(panel.aim_details.visible).is_false()
		assert_bool(panel.accuracy_details.visible).is_true()
		assert_bool(panel.accuracy_summary.visible).is_false()
		assert_str(panel.accuracy_details.text).contains("Final hit chance 42%")
		var popover := interface.tactical_popover
		assert_bool(interface.get_global_rect().encloses(popover.get_global_rect())).is_true()
		assert_float(panel.get_global_rect().size.x).is_less_equal(popover.get_global_rect().size.x)
		# The boot flow mounts the title menu after the first frames; hide it at shot time.
		hidden.append_array(_isolate(interface))
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var capture := get_viewport().get_texture().get_image()
		var path := "user://qa/accuracy-reasons-popover-%d.png" % viewport_size.x
		assert_int(capture.save_png(path)).is_equal(OK)
		print("SHOT ", ProjectSettings.globalize_path(path))
	get_tree().root.size = Vector2i(1920, 1080)
	for item: Variant in hidden:
		if is_instance_valid(item):
			item.show()
	if boot != null:
		boot.visible = was_visible


## The harness leaves the boot menu in the tree; production frees it on travel. Its
## CanvasLayers do not inherit the hidden boot scene's visibility, so hide every root canvas
## item and canvas layer outside `target`. Returns what it hid, to restore afterwards.
func _isolate(target: Node) -> Array:
	var hidden: Array = []
	for child: Node in get_tree().root.get_children():
		if child == target or child.is_ancestor_of(target) or not child is CanvasItem:
			continue
		if (child as CanvasItem).visible:
			(child as CanvasItem).hide()
			hidden.append(child)
	for node: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		if layer.visible and not target.is_ancestor_of(layer) and not layer.is_ancestor_of(target):
			layer.hide()
			hidden.append(layer)
	return hidden


func test_defining_strike_dialog_labels_both_checks() -> void:
	var saved := GameState.to_dict().duplicate(true)
	Battle.start(&"trial-warden")
	var target := Battle.controller.enemies[0]
	target.archetype_id = &"loam-maddened-boar"
	target.discovered_weakness_ids = [&"loam-maddened-boar/knee"]
	var runner := scene_runner("res://ui/screens/battle.tscn")
	var screen := runner.scene() as Screen
	screen.theme = ThemeBuilder.build()
	# The Defining Strike dialog belongs to the combat bar now, not the battle screen.
	var bar: CombatBar = screen.call("combat_bar")
	bar._open_weakness_dialog()
	await runner.simulate_frames(5)
	var label: Label = bar._weakness_forecast
	var dialog: Window = bar._weakness_dialog
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
