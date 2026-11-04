extends GdUnitTestSuite
## Walk-in orders (combat polish, owner ruling 2026-11-02): pressing a creature out of reach
## walks the unit into reach and acts, as one order. When the AP covers the walk but not the
## action, the order is previewed and refused ("preview, then refuse"). Strike costs 2 AP, a
## flat cell 1 AP, and a bare actor has 4 AP; actors start at the row's two ends.

## Written in square cells and square distances on a made-up board, so it pins the square grid
## (hex slice H3b; test/helpers/grid_mode.gd names the hex counterparts).
const GridMode := preload("res://test/helpers/grid_mode.gd")
var _grid_before: Variant


func before() -> void:
	_grid_before = GridMode.use_squares()


func after() -> void:
	GridMode.restore(_grid_before)


var _silenced_controls: Array[Dictionary] = []


func after_test() -> void:
	for saved: Dictionary in _silenced_controls:
		var control_value: Variant = saved.get("control")
		if not is_instance_valid(control_value):
			continue
		var control := control_value as Control
		control.visible = bool(saved.get("visible", true))
		control.mouse_filter = int(saved.get("mouse_filter", Control.MOUSE_FILTER_STOP))
	_silenced_controls.clear()


func test_a_strike_out_of_reach_walks_in_then_strikes_as_one_order() -> void:
	var fixture := _battle(4)  # ally (0,0), enemy (3,0): walk 2, strike 2 = 4 AP
	var controller := fixture["controller"] as CombatController
	var ally := fixture["ally"] as BattleActor
	var enemy := fixture["enemy"] as BattleActor
	var strike := controller.action_by_id(&"strike")
	assert_bool(bool(controller.query_action(strike, enemy).get("allowed", false))).is_false()

	var plan := controller.approach_query(strike, enemy)
	assert_bool(bool(plan.get("allowed", false))).override_failure_message(str(plan)).is_true()
	assert_int(int(plan["move_ap"])).is_equal(2)
	assert_int(int(plan["action_ap"])).is_equal(2)
	assert_int(int(plan["total_ap"])).is_equal(4)
	assert_bool((plan["forecast"] as Dictionary).get("allowed", false)).is_true()

	var resolved: Array[StringName] = []
	var messages: Array[String] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void:
		if event.type == &"action_resolved" and event.actor_id == ally.combat_id:
			resolved.append(StringName(str(event.data.get("action_id", ""))))
			messages.append(str(event.data.get("message", "")))
	)
	var result := controller.submit_approach(&"strike", enemy)
	assert_bool(bool(result.get("allowed", false))).override_failure_message(str(result)).is_true()
	assert_that(controller.battlefield.cell_of(ally)).is_equal(Vector2i(2, 0))
	assert_array(resolved).contains_exactly([&"move", &"strike"])
	# The log names the walk in cells, never the grid's internal position key.
	assert_str(messages[0]).is_equal("Approach Ally moves 2 cells.")


func test_short_ap_previews_the_whole_order_and_refuses_without_moving() -> void:
	var fixture := _battle(5)  # enemy (4,0): walk 3 + strike 2 = 5 AP, 4 AP on hand
	var controller := fixture["controller"] as CombatController
	var ally := fixture["ally"] as BattleActor
	var enemy := fixture["enemy"] as BattleActor
	var strike := controller.action_by_id(&"strike")

	var plan := controller.approach_query(strike, enemy)
	assert_str(str(plan.get("blocked_by", ""))).is_equal("approach_ap")
	assert_str(str(plan.get("message", ""))).is_equal("Move 3 + Strike 2 = 5 AP; 4 AP left.")
	assert_int((plan.get("path_cells", []) as Array).size()).is_greater(0)

	var result := controller.submit_approach(&"strike", enemy)
	assert_bool(bool(result.get("allowed", true))).is_false()
	assert_that(controller.battlefield.cell_of(ally)).is_equal(Vector2i(0, 0))
	assert_int(ally.action_points).is_equal(4)


func test_a_target_no_affordable_walk_can_reach_is_out_of_reach_this_turn() -> void:
	var fixture := _battle(8)  # enemy (7,0): four cells of walking leaves it three away
	var controller := fixture["controller"] as CombatController
	var plan := controller.approach_query(controller.action_by_id(&"strike"), fixture["enemy"])
	assert_str(str(plan.get("blocked_by", ""))).is_equal("approach_out_of_reach")
	assert_str(str(plan.get("message", ""))).is_equal("Approach Enemy is out of reach this turn.")


func test_a_target_in_reach_needs_no_walk() -> void:
	var fixture := _battle(2)
	var controller := fixture["controller"] as CombatController
	var enemy := fixture["enemy"] as BattleActor
	assert_dict(controller.approach_query(controller.action_by_id(&"strike"), enemy)).is_empty()
	var result := controller.submit_approach(&"strike", enemy)
	assert_bool(bool(result.get("allowed", false))).is_true()
	assert_that(controller.battlefield.cell_of(fixture["ally"])).is_equal(Vector2i(0, 0))


func test_planning_leaves_the_board_as_it_was() -> void:
	var fixture := _battle(5)
	var controller := fixture["controller"] as CombatController
	var ally := fixture["ally"] as BattleActor
	var model := controller.battlefield as GridBattlefieldModel
	var before := model.position_of(ally)
	controller.approach_query(controller.action_by_id(&"strike"), fixture["enemy"])
	assert_that(model.cell_of(ally)).is_equal(Vector2i(0, 0))
	assert_object(model.occupant_of(before)).is_same(ally)
	assert_bool(bool(model.cell_query(Vector2i(3, 0)).get("allowed", false))).is_true()


func test_hovering_a_far_enemy_quotes_the_walk_and_clicking_it_walks_in_and_strikes() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var model := _grid_model(4)
	var controller := _controller(model)
	interface.bind_controller(controller)
	controller.event_emitted.connect(interface.consume_event)
	var ally := _actor("Approach Ally")
	var enemy := _actor("Approach Enemy")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	controller.start(allies, enemies)
	var resolved: Array[StringName] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void:
		if event.type == &"action_resolved" and event.actor_id == ally.combat_id:
			resolved.append(StringName(str(event.data.get("action_id", ""))))
	)
	interface.select_pointer_action(&"strike")
	await runner.simulate_frames(3)
	_silence_root_controls(interface)

	var enemy_point := interface.stage.global_position + interface.stage.cell_center(Vector2i(3, 0))
	_push(interface, _motion(enemy_point))
	await runner.simulate_frames(1)
	var quote := (interface.stage.target_preview.get_node("Column/Quote") as Label).text
	assert_str(quote).contains("WALK IN · MOVE 2 + STRIKE 2 = 4 AP")

	_push(interface, _press(enemy_point))
	await runner.simulate_frames(2)
	assert_that(model.cell_of(ally)).is_equal(Vector2i(2, 0))
	assert_array(resolved).contains_exactly([&"move", &"strike"])


func _battle(width: int) -> Dictionary:
	var controller := _controller(_grid_model(width))
	var ally := _actor("Approach Ally")
	var enemy := _actor("Approach Enemy")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	controller.start(allies, enemies)
	return {"controller": controller, "ally": ally, "enemy": enemy}


func _controller(model: GridBattlefieldModel) -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), model, rules)
	return controller


func _grid_model(width: int) -> GridBattlefieldModel:
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
	for x: int in width:
		ground.set_cell(Vector2i(x, 0), 0, Vector2i.ZERO)
	var model := GridBattlefieldModel.new()
	model.configure(load("res://data/combat/combat_rules.tres") as CombatRules)
	model.build_grid(ground)
	return model


func _actor(display_name: String) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = display_name
	actor.hp = 40
	actor.max_hp = 40
	actor.attack = 5
	actor.defense = 1
	return actor


func _motion(point: Vector2) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	return motion


func _press(point: Vector2) -> InputEventMouseButton:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	press.global_position = point
	return press


func _push(interface: Control, event: InputEvent) -> void:
	interface.get_viewport().push_input(event)


## Screens leaked open by earlier suites sit above the scene under test and would take the
## pointer (the pattern test_battle_pointer_controls.gd uses).
func _silence_root_controls(scene_under_test: Node) -> void:
	for child: Node in scene_under_test.get_tree().root.get_children():
		if child == scene_under_test:
			continue
		if child is Control:
			_silence(child as Control)
		elif child is CanvasLayer:
			for layer_child: Node in child.get_children():
				if layer_child is Control:
					_silence(layer_child as Control)


func _silence(control: Control) -> void:
	_silenced_controls.append({"control": control, "visible": control.visible, "mouse_filter": control.mouse_filter})
	control.visible = false
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
