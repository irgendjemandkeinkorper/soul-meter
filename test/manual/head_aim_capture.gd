extends GdUnitTestSuite
## Rendered evidence for the task 11 head/eyes slice: the production strike's HEAD aim on the
## real bog-wight, with Vex already sight-blurred so the attacker term shows, at 1920×1080.


func test_head_aim_with_blurred_sight() -> void:
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
	controller.start([actor], [wight], &"head-capture")
	assert_bool(grid.displace(wight, grid.cell_of(actor) + Vector2i(1, 0))["allowed"]).is_true()
	CombatInjury.apply(actor, {
		"id": "sight-blurred", "location_id": "head", "severity": "minor",
		"effects": {"sight_accuracy_pp": -15},
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
	interface.select_pointer_action(&"strike")
	var wight_cell: Vector2i = grid.cell_of(wight)
	interface._on_tile_hovered({"x": wight_cell.x, "y": wight_cell.y})
	interface.act_target_panel.aim_button(&"head").pressed.emit()
	interface._on_tile_hovered({"x": wight_cell.x, "y": wight_cell.y})
	for _frame: int in 5:
		await get_tree().process_frame
	var panel := interface.act_target_panel
	assert_bool(panel.get_global_rect().encloses(panel.aim_row.get_global_rect())).is_true()
	assert_str(panel.forecast.text).contains("AIM HEAD")
	assert_str(panel.forecast.text).contains("Injury: Head (sight) -15 pp")
	assert_str(panel.forecast.text).contains("30%")
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/head-aim-1920.png")).is_equal(OK)
