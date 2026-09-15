extends GdUnitTestSuite
## Pointer flow for cell workings and creature-side cards: a Firebreak is aimed by picking
## three cells on the stage, Douse can target an ally, and the stage tints the board state.


func test_three_cell_presses_submit_a_firebreak_and_the_stage_tints_it() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var model := _grid_model(5, 3)
	var fixture := _bind_controller(interface, model)
	var controller := fixture["controller"] as CombatController
	var ally := fixture["ally"] as BattleActor
	interface.select_pointer_action(&"firebreak")
	await runner.simulate_frames(3)
	_silence_root_controls(interface)
	var resolved: Array[StringName] = []
	controller.event_emitted.connect(
		func(event: CombatEvent) -> void:
			if event.type == &"action_resolved":
				resolved.append(StringName(str(event.data.get("action_id", ""))))
	)
	var breath_before := ally.breath
	for cell: Vector2i in [Vector2i(2, 0), Vector2i(2, 1)]:
		_push_click(interface, _stage_point(interface, cell))
		await runner.simulate_frames(1)
	assert_int(interface.pending_cells().size()).is_equal(2)
	assert_int(resolved.size()).is_equal(0)
	# Hovering the closing cell quotes the working before it is committed.
	_push_hover(interface, _stage_point(interface, Vector2i(2, 2)))
	await runner.simulate_frames(1)
	assert_str(interface.act_target_panel.forecast.text).contains("FIREBREAK")
	assert_str(interface.act_target_panel.forecast.text).contains("BREATH 12")
	_push_click(interface, _stage_point(interface, Vector2i(2, 2)))
	await runner.simulate_frames(2)
	assert_array(resolved).contains([&"firebreak"])
	assert_int(ally.breath).is_equal(breath_before - 12)
	assert_bool(controller.fire.is_burning_cell(Vector2i(2, 1))).is_true()
	assert_int(interface.pending_cells().size()).is_equal(0)
	assert_int(interface.stage.fire_cell_count()).is_equal(3)


func test_a_bent_line_is_refused_on_the_panel_and_nothing_is_spent() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var fixture := _bind_controller(interface, _grid_model(5, 3))
	var controller := fixture["controller"] as CombatController
	var ally := fixture["ally"] as BattleActor
	interface.select_pointer_action(&"firebreak")
	await runner.simulate_frames(3)
	_silence_root_controls(interface)
	var ap_before := ally.action_points
	for cell: Vector2i in [Vector2i(1, 0), Vector2i(2, 1), Vector2i(3, 2)]:
		_push_click(interface, _stage_point(interface, cell))
		await runner.simulate_frames(1)
	assert_int(ally.action_points).is_equal(ap_before)
	assert_bool(controller.fire.is_empty()).is_true()
	assert_str(interface.act_target_panel.forecast.text).contains("straight")
	assert_int(interface.pending_cells().size()).is_equal(0)


func test_douse_can_be_aimed_at_an_ally_by_pointer() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var fixture := _bind_controller(interface, _grid_model(5, 3))
	var controller := fixture["controller"] as CombatController
	var ally := fixture["ally"] as BattleActor
	FireField.apply_burning(ally, &"someone")
	interface.select_pointer_action(&"douse")
	await runner.simulate_frames(3)
	_silence_root_controls(interface)
	var at: Variant = controller.battlefield.cell_of(ally)
	_push_click(interface, _stage_point(interface, at as Vector2i))
	await runner.simulate_frames(2)
	assert_bool(FireField.is_burning(ally)).is_false()
	assert_bool(FireField.is_soaked(ally)).is_true()


func _stage_point(interface: BattleInterface, cell: Vector2i) -> Vector2:
	return interface.stage.global_position + interface.stage.cell_center(cell)


func _bind_controller(interface: BattleInterface, model: GridBattlefieldModel) -> Dictionary:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) \
		as CombatRules
	rules.use_charge_time = false
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), model, rules)
	interface.bind_controller(controller)
	controller.event_emitted.connect(interface.consume_event)
	var ally := _actor("Pointer Ally", 40, 5, 2)
	ally.breath = 60
	ally.source_member = PartyMember.new()
	ally.source_member.id = "pointer-ally"
	ally.source_member.patron = "Pazzah"
	var enemy := _actor("Pointer Enemy", 40, 4, 1)
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	controller.start(allies, enemies)
	return {"controller": controller, "ally": ally, "enemy": enemy}


func _push_hover(interface: Control, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	interface.get_viewport().push_input(motion)


func _push_click(interface: Control, point: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	press.global_position = point
	interface.get_viewport().push_input(press)


func _silence_root_controls(scene_under_test: Node) -> void:
	for child: Node in scene_under_test.get_tree().root.get_children():
		if child == scene_under_test:
			continue
		if child is Control:
			_silence_control(child as Control)
		for nested: Node in child.find_children("*", "Control", true, false):
			_silence_control(nested as Control)


func _silence_control(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _grid_model(width: int, height: int) -> GridBattlefieldModel:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tile_set
	for y: int in height:
		for x: int in width:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var model := GridBattlefieldModel.new()
	var rules := load("res://data/combat/combat_rules.tres") as CombatRules
	model.configure(rules)
	model.build_grid(ground)
	return model


func _actor(name: String, hp: int, attack: int, defense: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	return actor
