extends GdUnitTestSuite

var _used_global_battle := false
var _saved_party: Array[PartyMember] = []
var _silenced_controls: Array[Dictionary] = []


func before_test() -> void:
	_used_global_battle = false
	_silenced_controls.clear()
	_saved_party = GameState.party.duplicate()


func after_test() -> void:
	for saved: Dictionary in _silenced_controls:
		# Validity BEFORE the cast: gdUnit's memory observer can free the runner
		# scene (and these controls) during input-processing awaits, and casting
		# a freed object raises a runtime error gdUnit records as a failure —
		# the long-standing CI-headless-only failure of this suite.
		var control_value: Variant = saved.get("control")
		if not is_instance_valid(control_value):
			continue
		var control := control_value as Control
		control.visible = bool(saved.get("visible", true))
		control.mouse_filter = int(saved.get("mouse_filter", Control.MOUSE_FILTER_STOP))
	if not _used_global_battle:
		return
	Battle.controller = null
	Battle.allies.clear()
	Battle.enemies.clear()
	Battle._combat_history.clear()
	Battle.ended = true
	GameState.party.clear()
	for member: PartyMember in _saved_party:
		GameState.party.append(member)


func test_hover_quote_click_move_and_snapshot_refresh_use_controller_events() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var model := _grid_model(4, 2)
	model.set_cover(Vector2i(1, 1), true)
	var fixture := _bind_controller(interface, model)
	var controller := fixture["controller"] as CombatController
	var ally := fixture["ally"] as BattleActor
	await runner.simulate_frames(3)
	_silence_root_controls(interface)

	var row := _reachable_destination(controller)
	assert_dict(row).is_not_empty()
	var destination := StringName(row.get("destination", &""))
	var quote: Dictionary = controller.move_query(destination)
	var path_cells: Array = row.get("path_cells", [])
	var cell: Vector2i = path_cells.back()
	var stage := interface.stage
	var point := stage.global_position + stage.cell_center(cell)
	_push_hover(interface, point)
	await runner.simulate_frames(2)

	assert_int(stage.hovered_ap_cost()).is_equal(int(quote.get("ap_cost", -1)))
	assert_str(interface.cursor_readout.text).contains(
		"MOVE %d AP" % int(quote.get("ap_cost", -1))
	)
	assert_int(stage.cover_marker_count()).is_equal(1)

	var ap_before := ally.action_points
	var position_before := model.position_of(ally)
	_push_click(interface, point)
	await runner.simulate_frames(2)

	assert_str(String(model.position_of(ally))).is_equal(String(destination))
	assert_str(String(model.position_of(ally))).is_not_equal(String(position_before))
	assert_int(ally.action_points).is_equal(ap_before - int(quote.get("ap_cost", 0)))
	assert_int(stage.hovered_ap_cost()).is_equal(-1)
	assert_str(interface.cursor_readout.text).not_contains(
		"MOVE %d AP" % int(quote.get("ap_cost", -1))
	)


func test_attack_animation_lock_ignores_second_click_and_selection_side_effects() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var fixture := _bind_controller(interface, _grid_model(2, 1))
	var controller := fixture["controller"] as CombatController
	var ally := fixture["ally"] as BattleActor
	var enemy := fixture["enemy"] as BattleActor
	enemy.hp = 80
	enemy.max_hp = 80
	await runner.simulate_frames(3)
	_silence_root_controls(interface)

	var selections: Array[Dictionary] = []
	interface.stage.tile_selected.connect(
		func(tile: Dictionary) -> void: selections.append(tile)
	)
	var enemy_point := interface.stage.global_position \
		+ interface.stage.cell_center(Vector2i(1, 0))
	_push_hover(interface, enemy_point)
	await runner.simulate_frames(1)
	var ap_before := ally.action_points
	_push_click(interface, enemy_point)
	var ap_after_first := ally.action_points
	assert_int(ap_after_first).is_less(ap_before)
	assert_int(selections.size()).is_equal(1)

	var ally_point := interface.stage.global_position \
		+ interface.stage.cell_center(Vector2i(0, 0))
	_push_hover(interface, ally_point)
	_push_click(interface, ally_point)
	assert_int(ally.action_points).is_equal(ap_after_first)
	assert_int(selections.size()).is_equal(1)
	assert_bool(interface.stage.pointer_input_available()).is_false()
	assert_bool(controller.state == CombatController.State.ALLY_TURN).is_true()


func test_blocked_los_enemy_click_does_not_submit() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var model := _grid_model(5, 1)
	model.set_elevation(Vector2i(2, 0), 10)
	var shot := CombatAction.new()
	shot.id = &"pointer-test-shot"
	shot.display_name = "Test Shot"
	shot.kind = CombatAction.Kind.ATTACK
	shot.target_profile = &"ranged"
	shot.ap_cost = 1
	var actions := CombatActionCatalog.all()
	actions.append(shot)
	var fixture := _bind_controller(interface, model, actions)
	var controller := fixture["controller"] as CombatController
	var ally := fixture["ally"] as BattleActor
	var enemy := fixture["enemy"] as BattleActor
	interface.select_pointer_action(shot.id)
	await runner.simulate_frames(3)
	_silence_root_controls(interface)

	var payload := controller.forecast_action(shot, enemy)
	assert_bool(payload.get("allowed", true)).is_false()
	var captured := {"resolved_count": 0}
	controller.event_emitted.connect(
		func(event: CombatEvent) -> void:
			if event.type == &"action_resolved":
				captured["resolved_count"] = int(captured["resolved_count"]) + 1
	)
	var ap_before := ally.action_points
	var enemy_point := interface.stage.global_position \
		+ interface.stage.cell_center(Vector2i(4, 0))
	_push_hover(interface, enemy_point)
	await runner.simulate_frames(1)
	_push_click(interface, enemy_point)
	await runner.simulate_frames(1)

	assert_int(ally.action_points).is_equal(ap_before)
	assert_int(int(captured["resolved_count"])).is_equal(0)
	assert_str(interface.act_target_panel.forecast.text).is_equal(
		str(payload.get("message", ""))
	)


## Gate Wave P finding 2: region D once recomputed its number through a
## Resolution context that carries no cover term, so cover changed only the
## "COVER +n" copy — never the forecast NUMBER. The number shown must be the
## controller's quoted damage, and it must move when cover appears.
func test_covered_enemy_hover_changes_the_forecast_number_to_the_controller_quote() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var model := _grid_model(5, 1)
	var shot := CombatAction.new()
	shot.id = &"pointer-cover-shot"
	shot.display_name = "Cover Shot"
	shot.kind = CombatAction.Kind.ATTACK
	shot.target_profile = &"ranged"
	shot.ap_cost = 1
	var actions := CombatActionCatalog.all()
	actions.append(shot)
	var fixture := _bind_controller(interface, model, actions)
	var controller := fixture["controller"] as CombatController
	var enemy := fixture["enemy"] as BattleActor
	interface.select_pointer_action(shot.id)
	await runner.simulate_frames(3)
	_silence_root_controls(interface)
	var enemy_point := interface.stage.global_position \
		+ interface.stage.cell_center(Vector2i(4, 0))

	_push_hover(interface, enemy_point)
	await runner.simulate_frames(1)
	var open_number := _forecast_number(interface)

	interface.stage.clear_pointer()
	model.set_cover(Vector2i(3, 0), true)
	var covered_payload := controller.forecast_action(shot, enemy)
	assert_bool(bool(covered_payload.get("allowed", false))).is_true()
	assert_int(
		int((covered_payload.get("positioning", {}) as Dictionary).get("cover_bonus", 0))
	).is_greater(0)
	_push_hover(interface, enemy_point)
	await runner.simulate_frames(1)
	var covered_number := _forecast_number(interface)

	assert_int(covered_number).is_equal(int(covered_payload["damage"]))
	assert_int(covered_number).is_not_equal(open_number)
	assert_str(interface.act_target_panel.forecast.text).contains("COVER")


func _forecast_number(interface: BattleInterface) -> int:
	var expression := RegEx.new()
	expression.compile("FORECAST (\\d+)")
	var found := expression.search(interface.act_target_panel.forecast.text)
	assert_object(found) \
		.override_failure_message(
			"no FORECAST line in: %s" % interface.act_target_panel.forecast.text
		) \
		.is_not_null()
	return int(found.get_string(1)) if found != null else -1


func test_command_rail_button_still_completes_a_battle() -> void:
	_used_global_battle = true
	GameState.party.clear()
	var member := PartyMember.new()
	member.display_name = "Pointer Tester"
	member.hp = 20
	member.max_hp = 20
	member.attack = 100
	member.defense = 5
	GameState.party.append(member)
	var enemy := BattleActor.new()
	enemy.display_name = "Rail Target"
	enemy.hp = 1
	enemy.max_hp = 1
	enemy.defense = 0
	Battle.start(enemy)

	var runner := scene_runner("res://ui/screens/battle.tscn")
	var screen := runner.scene() as Control
	await runner.simulate_frames(3)
	_silence_root_controls(screen)
	var strike_button: Button = null
	for child: Node in screen.find_children("*", "Button", true, false):
		if child is Button and (child as Button).text.begins_with("STRIKE"):
			strike_button = child as Button
			break
	assert_object(strike_button).is_not_null()
	strike_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_bool(Battle.ended).is_true()
	assert_int(enemy.hp).is_equal(0)


func _bind_controller(
	interface: BattleInterface,
	model: GridBattlefieldModel,
	actions: Array[CombatAction] = [],
) -> Dictionary:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) \
		as CombatRules
	var controller := CombatController.new()
	if actions.is_empty():
		actions = CombatActionCatalog.all()
	controller.configure(actions, model, rules)
	interface.bind_controller(controller)
	controller.event_emitted.connect(interface.consume_event)
	var ally := _actor("Pointer Ally", 40, 5, 2)
	var enemy := _actor("Pointer Enemy", 40, 4, 1)
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	controller.start(allies, enemies)
	return {"controller": controller, "ally": ally, "enemy": enemy}


## Pushes pointer events straight into the interface's viewport instead of the
## runner's global mouse simulation — the runner path drops the suite's first
## motion event when the full suite runs headless (same class as the field-room
## click flakes), while push_input routes deterministically through the same
## Control GUI pipeline (the pattern test_click_to_move_input.gd uses).
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
		elif child is CanvasLayer:
			# Autoload overlays (UIManager screens, dialogue balloons) live inside
			# CanvasLayers above the scene under test; a screen leaked open by an
			# earlier suite otherwise captures every pointer event.
			for layer_child: Node in child.get_children():
				if layer_child is Control:
					_silence_control(layer_child as Control)


func _silence_control(control: Control) -> void:
	_silenced_controls.append({
		"control": control,
		"visible": control.visible,
		"mouse_filter": control.mouse_filter,
	})
	control.visible = false
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _reachable_destination(controller: CombatController) -> Dictionary:
	var movement: Dictionary = controller.snapshot().get("movement", {})
	var rows: Variant = movement.get("reachable", [])
	if rows is not Array:
		return {}
	for value: Variant in rows:
		if value is Dictionary:
			var path_value: Variant = (value as Dictionary).get("path_cells", [])
			if path_value is Array and not (path_value as Array).is_empty():
				return value
	return {}


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
