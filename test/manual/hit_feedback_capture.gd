extends GdUnitTestSuite

const UnitArtScript := preload("res://globals/unit_art.gd")


func test_confirmed_hit_and_miss_render_distinct_feedback() -> void:
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
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1920, 1080)
	add_child(viewport)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	for outcome: String in ["hit", "miss", "minor", "serious", "refresh"]:
		var want_hit := outcome != "miss"
		var want_injury := outcome in ["minor", "serious", "refresh"]
		var options := {"aim_location": "arm"} if want_injury else {}
		var grid := GridBattlefieldModel.new()
		grid.configure(rules)
		grid.build_grid(ground)
		var actor := BattleActor.new()
		actor.display_name = "Vex"
		actor.hp = 30
		actor.max_hp = 30
		actor.attack = 4 if outcome == "minor" else 12
		actor.attributes = {&"alacrity": 4, &"muster": 3}
		var target := EncounterCatalog.make_actor(&"bog-wight")
		var controller := CombatController.new()
		controller.configure(CombatActionCatalog.all(), grid, rules)
		controller.start([actor], [target], &"hit-feedback-capture")
		assert_bool(grid.displace(target, grid.cell_of(actor) + Vector2i(1, 0))["allowed"]).is_true()
		if outcome == "refresh":
			CombatInjury.apply(target, {"id": "existing-arm", "location_id": "arm", "severity": "minor"}, "earlier-action", 0)
		var interface := (load("res://ui/hud/battle_interface.tscn") as PackedScene).instantiate() as BattleInterface
		interface.theme = ThemeBuilder.build()
		viewport.add_child(interface)
		await get_tree().process_frame

		interface.bind_controller(controller)
		controller.event_emitted.connect(interface.consume_event)
		var snapshot := CombatEvent.new()
		snapshot.data = {"snapshot": controller.snapshot()}
		interface.consume_event(snapshot)
		interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for _frame: int in 5:
			await get_tree().process_frame
		var found := false
		for seed_value: int in 200:
			controller._sequence = seed_value
			var quote := controller.forecast_action(controller.action_by_id(&"strike"), target, options)
			if bool(quote["resolution"]["hit"]) == want_hit and (not want_injury or bool(quote["resolution"]["injury"]["applies"])):
				found = true
				break
		assert_bool(found).is_true()
		# Forecasting cannot create a committed result card.
		assert_object(interface.stage.get_node_or_null("FxLayer/DamagePop")).is_null()
		var result := controller.submit_action(&"strike", target, options)
		assert_bool(result["allowed"]).is_true()
		assert_bool(result["resolution"]["hit"]).is_equal(want_hit)
		var fx := interface.stage.get_node("FxLayer")
		assert_bool(fx.has_node("HitPulse")).is_equal(want_hit)
		var pop := fx.get_node("DamagePop") as PanelContainer
		assert_str((pop.get_node("Column/TargetName") as Label).text).is_equal(target.display_name)
		if not want_hit:
			assert_str((pop.get_node("Column/Outcome") as Label).text).is_equal("MISS")
		else:
			assert_str((pop.get_node("Column/Outcome") as Label).text).is_equal("%d DAMAGE" % int(result["damage"]))
		var injury := pop.get_node("Column/Injury") as Label
		assert_bool(injury.visible).is_equal(want_injury)
		if want_injury:
			var severity := "SERIOUS" if outcome == "serious" else "MINOR"
			assert_str(injury.text).contains("ARM · %s INJURY" % severity)
			assert_bool(injury.text.contains("REFRESHED")).is_equal(outcome == "refresh")
		for _frame: int in 3:
			await get_tree().process_frame
		assert_bool(Rect2(Vector2.ZERO, interface.stage.size).encloses(pop.get_rect())).is_true()
		assert_float(pop.size.y).is_less(150.0)
		assert_int(pop.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		assert_int(viewport.get_texture().get_image().save_png("user://qa/combat-result-%s-1920.png" % outcome)).is_equal(OK)
		await get_tree().create_timer(0.9).timeout
		assert_object(fx.get_node_or_null("DamagePop")).is_not_null()
		assert_bool(interface.stage.pointer_input_available()).is_true()
		await get_tree().create_timer(1.2).timeout
		assert_int(fx.get_child_count()).is_equal(0)
		interface.queue_free()
		await get_tree().process_frame

func test_field_overlay_hit_pulse_renders_on_borrowed_actor_art() -> void:
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = DS.STONE_1
	background.size = Vector2(1920, 1080)
	viewport.add_child(background)
	var field := Node2D.new()
	field.position = Vector2(800, 650)
	field.scale = Vector2(3, 3)
	viewport.add_child(field)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = tile_set.tile_size
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := TileMapLayer.new()
	ground.tile_set = tile_set
	ground.set_cell(Vector2i.ZERO, 0, Vector2i.ZERO)
	ground.set_cell(Vector2i(1, 0), 0, Vector2i.ZERO)
	field.add_child(ground)
	var grid := IsoGrid.new()
	grid.build(ground)
	var overlay := CombatOverlay.new()
	overlay.z_index = 1 # Same layer used by bind_field() in the production scene.
	field.add_child(overlay)
	overlay.bind_grid(grid, ground)
	for side: StringName in [&"ally", &"enemy"]:
		var actor := Node2D.new()
		field.add_child(actor)
		var sprite := Sprite2D.new()
		var unit_id := UnitArtScript.combat_unit_id(side, "bog-wight" if side == &"enemy" else "", "Bog Wight" if side == &"enemy" else "Vex")
		sprite.texture = load(UnitArtScript.texture_path(UnitArtScript.resolve(unit_id)))
		sprite.scale = Vector2.ONE * 64.0 / float(sprite.texture.get_height())
		sprite.position.y = -32.0
		actor.add_child(sprite)
		overlay.bind_actor(side, actor)
	var event := CombatEvent.new()
	event.type = &"action_resolved"
	event.actor_id = &"ally"
	event.target_id = &"enemy"
	event.data = {"damage": 13, "resolution": {"hit": true}, "snapshot": {
		"allies": [{"id": "ally", "display_name": "Vex", "position": Vector2i.ZERO, "hp": 30}],
		"enemies": [{"id": "enemy", "display_name": "Bog Wight", "position": Vector2i(1, 0), "hp": 20}],
	}}
	overlay.consume_event(event)
	assert_object(overlay.get_node_or_null("HitPulse")).is_not_null()
	for _frame: int in 3:
		await get_tree().process_frame
	var pop := overlay.get_node("DamagePop") as PanelContainer
	assert_vector(pop.get_global_transform_with_canvas().get_scale()).is_equal(Vector2.ONE)
	assert_int(pop.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var before := pop.get_global_transform_with_canvas().origin
	field.position += Vector2(60, 25)
	await get_tree().process_frame
	assert_vector(pop.get_global_transform_with_canvas().origin - before).is_equal(Vector2(60, 25))
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	assert_int(viewport.get_texture().get_image().save_png("user://qa/combat-result-field-1920.png")).is_equal(OK)
	await get_tree().create_timer(2.1).timeout
	assert_int(overlay.get_child_count()).is_equal(0)
