extends GdUnitTestSuite
## Rendered check of the anatomical aim row in the real battle interface.


func test_aim_row_layout_fits_the_forecast_panel() -> void:
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
	ground.set_cell(Vector2i(0, 0), 0, Vector2i.ZERO)
	ground.set_cell(Vector2i(1, 0), 0, Vector2i.ZERO)
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(ground)
	var action := CombatAction.make(&"aim-strike", "Aim strike", CombatAction.Kind.ATTACK, 0, 0, 0.0, 1)
	action.ct_cost = 30
	action.aim_profiles = preload("res://globals/combat_lab.gd").AIM_PROFILES.duplicate(true)
	var actor := BattleActor.new()
	actor.display_name = "Aimer"
	actor.hp = 30
	actor.max_hp = 30
	actor.attack = 8
	actor.attributes = {&"edge": 2, &"pitch": 2}
	var target := BattleActor.new()
	target.display_name = "Mark"
	target.hp = 30
	target.max_hp = 30
	target.anatomy = {
		"torso": {"display_name": "Torso", "exposed": true},
		"arm": {"display_name": "Shield arm", "exposed": false},
		"throat": {"display_name": "Throat", "exposed": true},
	}
	var controller := CombatController.new()
	var actions := CombatActionCatalog.all()
	actions.append(action)
	controller.configure(actions, grid, rules)
	controller.start([actor], [target], &"aim-capture")
	# Render in a private SubViewport: the boot scene (main menu) otherwise draws over the
	# runner's scene in the shared root, so a root capture would show the menu.
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	interface.select_pointer_action(&"aim-strike")
	interface._on_tile_hovered({"x": 1, "y": 0})
	interface.act_target_panel.aim_button(&"throat").pressed.emit()
	interface._on_tile_hovered({"x": 1, "y": 0})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	# The design frame is fixed 1920×1080 (design/DESIGN_SYSTEM.md); smaller windows scale
	# that frame, so a raw 1280×720 viewport is not a supported layout and is not checked.
	for viewport_size: Vector2i in [Vector2i(1920, 1080)]:
		viewport.size = viewport_size
		interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for _frame: int in 5:
			await get_tree().process_frame
		var panel := interface.act_target_panel
		assert_bool(interface.get_global_rect().encloses(panel.get_global_rect())).is_true()
		assert_bool(panel.get_global_rect().encloses(panel.aim_row.get_global_rect())).is_true()
		assert_bool(panel.get_global_rect().encloses(panel.forecast.get_global_rect())).is_true()
		assert_str(panel.forecast.text).contains("AIM THROAT")
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var capture := viewport.get_texture().get_image()
		assert_int(capture.save_png("user://qa/aim-row-%d.png" % viewport_size.x)).is_equal(OK)
