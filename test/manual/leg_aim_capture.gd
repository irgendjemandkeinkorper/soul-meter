extends GdUnitTestSuite
## Rendered evidence for the task 11 legs slice: the production strike's LEG aim on the
## real bog-wight in the battle interface, and the hobbled-ally move readout, at 1920×1080.


func test_leg_aim_and_hobbled_move_readout() -> void:
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
	controller.start([actor], [wight], &"leg-capture")
	var ally_cell: Vector2i = grid.cell_of(actor)
	assert_bool(grid.displace(wight, ally_cell + Vector2i(1, 0))["allowed"]).is_true()
	CombatInjury.apply(actor, {
		"id": "leg-hobbled", "location_id": "leg", "severity": "minor",
		"effects": {"move_cost_percent": 50},
	}, "capture", 0)
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	var interface := (load("res://ui/hud/battle_interface.tscn") as PackedScene).instantiate() as BattleInterface
	interface.theme = ThemeBuilder.build()
	viewport.add_child(interface)
	await get_tree().process_frame
	interface.bind_controller(controller)
	var snapshot := CombatEvent.new()
	snapshot.type = &"battle_snapshot"
	snapshot.data = {"snapshot": controller.snapshot()}
	interface.consume_event(snapshot)
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	# 1. Leg aim armed on the wight.
	interface.select_pointer_action(&"strike")
	var wight_cell: Vector2i = grid.cell_of(wight)
	interface._on_tile_hovered({"x": wight_cell.x, "y": wight_cell.y})
	interface.act_target_panel.aim_button(&"leg").pressed.emit()
	interface._on_tile_hovered({"x": wight_cell.x, "y": wight_cell.y})
	for _frame: int in 5:
		await get_tree().process_frame
	var panel := interface.act_target_panel
	assert_bool(panel.get_global_rect().encloses(panel.aim_row.get_global_rect())).is_true()
	assert_str(panel.aim_title.text).contains("AIM LEG")
	assert_str(panel.aim_consequence.text).contains("40%")
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/leg-aim-1920.png")).is_equal(OK)
	# 2. Hobbled ally hovering a one-step move: the readout carries the priced AP.
	interface.select_pointer_action(&"")
	var step := ally_cell + Vector2i(0, 1)
	var quote := controller.move_query(grid._handle_for_cell(step))
	assert_bool(quote["allowed"]).override_failure_message(str(quote)).is_true()
	assert_int(int(quote["ap_cost"])).is_equal(2)
	var stage := interface.stage
	var point: Vector2 = stage.global_position + stage.cell_center(step)
	# A private SubViewport does not route pushed pointer events into GUI input, so the
	# stage's own handler is driven directly with a local-space motion event.
	var motion := InputEventMouseMotion.new()
	motion.position = point - stage.global_position
	motion.global_position = point
	stage._gui_input(motion)
	for _frame: int in 5:
		await get_tree().process_frame
	assert_int(stage.hovered_ap_cost()).is_equal(2)
	assert_str(interface.cursor_readout.text).contains("MOVE 2 AP")
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/leg-move-1920.png")).is_equal(OK)
