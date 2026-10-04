extends GdUnitTestSuite

const UnitArtScript := preload("res://globals/unit_art.gd")

class FieldFixture extends FieldMap:
	var layer: TileMapLayer
	var grid: IsoGrid

	func ground() -> TileMapLayer:
		return layer

	func iso_grid() -> IsoGrid:
		return grid


func test_target_quote_tracks_aim_and_field_projection() -> void:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = tile_set.tile_size
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var field := FieldFixture.new()
	viewport.add_child(field)
	field.layer = TileMapLayer.new()
	field.layer.tile_set = tile_set
	field.add_child(field.layer)
	for x: int in 4:
		for y: int in 3:
			field.layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	field.grid = IsoGrid.new()
	field.grid.build(field.layer)
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(field.layer)
	var actor := BattleActor.new()
	actor.display_name = "Vex"
	actor.hp = 30
	actor.max_hp = 30
	actor.attack = 12
	actor.attributes = {&"alacrity": 4, &"muster": 3}
	var target := EncounterCatalog.make_actor(&"bog-wight")
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	controller.start([actor], [target], &"target-preview-capture")
	assert_bool(grid.displace(target, grid.cell_of(actor) + Vector2i(1, 0))["allowed"]).is_true()
	var interface := (load("res://ui/hud/battle_interface.tscn") as PackedScene).instantiate() as BattleInterface
	interface.theme = ThemeBuilder.build()
	viewport.add_child(interface)
	await get_tree().process_frame
	interface.bind_controller(controller)
	controller.event_emitted.connect(interface.consume_event)
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var snapshot := CombatEvent.new()
	snapshot.data = {"snapshot": controller.snapshot()}
	interface.consume_event(snapshot)
	for _frame: int in 5:
		await get_tree().process_frame
	var cell: Vector2i = grid.cell_of(target)
	var ap_before := actor.action_points
	for field_view: bool in [false, true]:
		if field_view:
			field.position = Vector2(650, 560)
			field.scale = Vector2(3, 3)
			interface.stage.bind_field(field)
			for unit: BattleActor in [actor, target]:
				var node := Node2D.new()
				field.add_child(node)
				var sprite := Sprite2D.new()
				var unit_id := UnitArtScript.combat_unit_id(&"ally" if unit == actor else &"enemy", "bog-wight", unit.display_name)
				sprite.texture = load(UnitArtScript.texture_path(UnitArtScript.resolve(unit_id)))
				sprite.scale = Vector2.ONE * 64.0 / float(sprite.texture.get_height())
				sprite.position.y = -32
				node.add_child(sprite)
				interface.stage._field_overlay.bind_actor(unit.combat_id, node)
			interface.consume_event(snapshot)
		interface._on_tile_hovered({"x": cell.x, "y": cell.y})
		interface.select_aim(&"arm")
		await get_tree().process_frame
		var preview := interface.stage.target_preview
		assert_bool(preview.visible).is_true()
		assert_int(preview.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		var quote := controller.forecast_action(controller.action_by_id(&"strike"), target, {"aim_location": "arm"})
		assert_str((preview.get_node("Column/Quote") as Label).text).contains("HIT %d%%" % int(quote["resolution"]["accuracy_breakdown"]["effective_hit_chance"]))
		assert_bool(Rect2(Vector2.ZERO, interface.stage.size).encloses(preview.get_rect())).is_true()
		if field_view:
			var before := preview.position
			field.position.x += 40
			await get_tree().process_frame
			assert_float(preview.position.x - before.x).is_equal_approx(40, 0.01)
			assert_str(String(interface.stage._field_overlay._preview_id)).is_equal(String(target.combat_id))
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
		var suffix := "field" if field_view else "board"
		assert_int(viewport.get_texture().get_image().save_png("user://qa/target-preview-%s-1920.png" % suffix)).is_equal(OK)
	assert_int(actor.action_points).is_equal(ap_before)
	interface.stage.clear_pointer()
	assert_bool(interface.stage.target_preview.visible).is_false()
	assert_str(String(interface.stage._field_overlay._preview_id)).is_empty()
