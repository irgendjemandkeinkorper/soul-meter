extends GdUnitTestSuite
## Rendered evidence for the task 11 serious slice: the forecast's SERIOUS marker when the
## quoted damage reaches the authored escalation threshold, at 1920×1080.


func test_serious_marker_on_the_arm_forecast() -> void:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = tile_set.tile_size
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tile_set
	for x: int in 4:
		for y: int in 3:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(ground)
	var actor := BattleActor.new()
	actor.display_name = "Vex"
	actor.hp = 30
	actor.max_hp = 30
	actor.attack = 12
	actor.attributes = {&"alacrity": 4, &"muster": 3}
	var wight := EncounterCatalog.make_actor(&"bog-wight")
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	controller.start([actor], [wight], &"serious-capture")
	assert_bool(grid.displace(wight, grid.cell_of(actor) + Vector2i(1, 0))["allowed"]).is_true()
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var interface := (load("res://ui/hud/battle_interface.tscn") as PackedScene).instantiate() as BattleInterface
	interface.theme = ThemeBuilder.build()
	viewport.add_child(interface)
	await get_tree().process_frame
	interface.bind_controller(controller)
	controller.event_emitted.connect(interface.consume_event)
	var snapshot := CombatEvent.new()
	snapshot.type = &"battle_snapshot"
	snapshot.data = {"snapshot": controller.snapshot()}
	interface.consume_event(snapshot)
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	interface.select_pointer_action(&"strike")
	var wight_cell: Vector2i = grid.cell_of(wight)
	interface._on_tile_hovered({"x": wight_cell.x, "y": wight_cell.y})
	interface.act_target_panel.aim_button(&"arm").pressed.emit()
	for _frame: int in 5:
		await get_tree().process_frame
	var panel := interface.act_target_panel
	assert_str(panel.aim_title.text).contains("AIM ARM")
	assert_str(panel.aim_consequence.text).contains("50% ON HIT")
	assert_str(panel.aim_consequence.text).contains("POSSIBLE SERIOUS INJURY")
	assert_bool(interface.get_global_rect().encloses(panel.get_global_rect())).is_true()
	assert_bool(panel.get_global_rect().encloses(panel.aim_summary.get_global_rect())).is_true()
	assert_bool(panel.forecast.visible).is_false()
	assert_str(panel.accuracy_summary.text).contains("Aim: Arm")
	assert_bool(panel.accuracy_details.visible).is_false()
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/serious-aim-1920.png")).is_equal(OK)
	panel.aim_details.button_pressed = true
	for _frame: int in 5:
		await get_tree().process_frame
	assert_bool(interface.get_global_rect().encloses(panel.get_global_rect())).is_true()
	assert_bool(panel.get_global_rect().encloses(panel.forecast.get_global_rect())).is_true()
	assert_bool(panel.accuracy_details.visible).is_true()
	assert_bool(panel.get_global_rect().encloses(panel.accuracy_details.get_global_rect())).is_true()
	assert_bool(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(interface.get_node("SafeFrame/Rows").get_global_rect())).is_true()
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/serious-aim-details-1920.png")).is_equal(OK)
	# A real committed injury drives the notification, not the earlier forecast.
	assert_bool(interface.injury_notice.visible).is_false()
	var injury_seed := -1
	for seed_value: int in 200:
		controller._sequence = seed_value
		var quote := controller.forecast_action(controller.action_by_id(&"strike"), wight, {"aim_location": "arm"})
		if bool(quote["resolution"]["injury"]["applies"]):
			injury_seed = seed_value
			break
	assert_int(injury_seed).is_greater_equal(0)
	controller._sequence = injury_seed
	var committed := controller.submit_action(&"strike", wight, {"aim_location": "arm"})
	assert_bool(committed["allowed"]).is_true()
	assert_bool(interface.injury_notice.visible).is_true()
	assert_str(interface.injury_notice.severity.text).is_equal("SERIOUS INJURY")
	assert_str(interface.injury_notice.details.text).contains("Attack accuracy: -20 percentage points")
	await get_tree().create_timer(0.9).timeout
	for expanded: bool in [false, true]:
		interface.injury_notice.details_toggle.button_pressed = expanded
		for _frame: int in 5:
			await get_tree().process_frame
		var notice := interface.injury_notice
		assert_bool(interface.stage.get_global_rect().encloses(notice.get_global_rect())).is_true()
		assert_bool(notice.get_global_rect().encloses(notice.dismiss_button.get_global_rect())).is_true()
		if expanded:
			assert_bool(notice.get_global_rect().encloses(notice.details.get_global_rect())).is_true()
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var suffix := "details" if expanded else "compact"
		assert_int(viewport.get_texture().get_image().save_png("user://qa/injury-notice-%s-1920.png" % suffix)).is_equal(OK)
	# Active-unit badges also render records restored before this snapshot (no impact event).
	interface.injury_notice.clear_notices()
	panel.aim_details.button_pressed = false
	var strike := controller.action_by_id(&"strike")
	for location: String in ["arm", "leg", "head", "throat"]:
		var profile: Dictionary = strike.aim_profiles[location]["injury"]
		var injury: Dictionary = (profile["serious"] as Dictionary).duplicate(true)
		injury["severity"] = "serious"
		injury["location_id"] = location
		CombatInjury.apply(actor, injury, "badge-capture-" + location, 1)
	snapshot.data = {"snapshot": controller.snapshot()}
	interface.consume_event(snapshot)
	for _frame: int in 5:
		await get_tree().process_frame
	var plate := interface.active_unit_plate
	assert_int(plate.injury_badges.get_child_count()).is_equal(4)
	assert_bool(plate.get_global_rect().encloses(plate.injury_badges.get_global_rect())).is_true()
	assert_bool(interface.get_global_rect().encloses(panel.get_global_rect())).is_true()
	plate.injury_button("throat").pressed.emit()
	for _frame: int in 5:
		await get_tree().process_frame
	var inspector := interface.injury_inspector
	assert_bool(inspector.visible).is_true()
	assert_bool(interface.get_global_rect().encloses(inspector.get_global_rect())).is_true()
	assert_bool(inspector.get_global_rect().encloses(inspector.details.get_global_rect())).is_true()
	assert_str(inspector.details.text).contains("Actions requiring a voice are blocked.")
	assert_bool(interface.injury_notice.visible).is_false()
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/active-injury-badges-1920.png")).is_equal(OK)
