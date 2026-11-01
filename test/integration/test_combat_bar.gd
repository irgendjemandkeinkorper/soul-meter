extends GdUnitTestSuite
## Owner 2026-11-01, combat presentation on the one bar: the bar's buttons route to the same
## Battle / controller commands the old command dock did, hovering an enemy quotes it in a
## small tooltip, the breakdown popover is closed until the bar's button or the key opens it,
## and combat end retracts the combat parts.

const TEST_ROOM_SCENE := "res://world/test_room.tscn"
const HOSTILE_SCENE := "res://actors/hostile/hostile.tscn"

var _game_state_before: Dictionary
var _saved_party: Array[PartyMember] = []


func before_test() -> void:
	_game_state_before = GameState.to_dict().duplicate(true)
	_saved_party = GameState.party.duplicate()
	get_tree().root.size = Vector2i(1920, 1080)


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.allies.clear()
	Battle.enemies.clear()
	Battle._combat_history.clear()
	Battle.ended = true
	UIManager.close_all()
	GameState.from_dict(_game_state_before)
	GameState.party.clear()
	for member: PartyMember in _saved_party:
		GameState.party.append(member)


func test_bar_actions_route_to_the_same_controller_commands() -> void:
	var session := await _session("CommandWight")
	var hud: FieldHUD = session.hud
	var bar: CombatBar = hud.combat_bar
	var foe := (session.hostile as Hostile).battle_actor()
	await _until_presented(hud.battle_interface.stage)
	assert_int(Battle.controller.state).is_equal(CombatController.State.ALLY_TURN)
	var ally := Battle.controller.active_actor()

	# GUARD resolves through the controller: the actor guards and an action_resolved event lands.
	var history_before := Battle._combat_history.size()
	_press(bar, "GUARD")
	assert_bool(ally.guarding).is_true()
	assert_str(_resolved_action_since(history_before, ally)).is_equal("guard")

	# STRIKE arms the pointer action and strikes the current target through Battle.use_action.
	await _until_presented(hud.battle_interface.stage)
	_await_ally_turn()
	var striker := Battle.controller.active_actor()
	history_before = Battle._combat_history.size()
	_press(bar, "STRIKE")
	assert_str(_resolved_action_since(history_before, striker)).is_equal("strike")

	# END TURN hands the turn on.
	await _until_presented(hud.battle_interface.stage)
	_await_ally_turn()
	var active_before := Battle.controller.active_actor()
	var acted_before: Array = Battle.controller.snapshot().get("turn_order", [])
	(bar.get("_end_turn_button") as Button).pressed.emit()
	assert_bool(
		Battle.controller.active_actor() != active_before
		or Battle.controller.state != CombatController.State.ALLY_TURN
		or Battle.ended
		or Battle.controller.snapshot().get("turn_order", []) != acted_before
	).override_failure_message("END TURN must call Battle.end_turn()").is_true()

	# WITHDRAW flees through Battle.flee.
	await _until_presented(hud.battle_interface.stage)
	(bar.get("_withdraw_button") as Button).pressed.emit()
	assert_bool(Battle.ended).is_true()
	assert_int(Battle.last_result.state).is_equal(BattleResult.State.FLED)
	await _close(session)


func test_enemy_hover_quotes_name_hp_hit_chance_and_damage() -> void:
	var session := await _session("HoverWight")
	var hud: FieldHUD = session.hud
	var interface := hud.battle_interface
	await _until_presented(interface.stage)
	_await_ally_turn()
	var foe := (session.hostile as Hostile).battle_actor()
	var cell: Vector2i = Battle.controller.battlefield.cell_of(foe)
	interface.select_pointer_action(&"strike")
	interface._on_tile_hovered({"x": cell.x, "y": cell.y})
	var preview := interface.stage.target_preview
	assert_bool(preview.visible).is_true()
	assert_str((preview.get_node("Column/TargetName") as Label).text).is_equal(foe.display_name)
	var quote := (preview.get_node("Column/Quote") as Label).text
	var forecast := Battle.controller.forecast_action(Battle.controller.action_by_id(&"strike"), foe, {})
	assert_str(quote).contains("HP %d / %d" % [foe.hp, foe.max_hp])
	assert_str(quote).contains("HIT %d%%" % int(forecast["resolution"]["accuracy_breakdown"]["effective_hit_chance"]))
	assert_str(quote).contains("%d DMG" % int(forecast["damage_on_hit"]))
	# The tooltip stays small: a few lines, not the breakdown.
	assert_int(quote.split("\n").size()).is_less_equal(4)
	assert_bool(interface.breakdown_visible()).is_false()
	interface._on_pointer_cleared()
	assert_bool(preview.visible).is_false()
	await _close(session)


func test_breakdown_popover_opens_from_the_bar_button_and_the_key() -> void:
	var session := await _session("BreakdownWight")
	var hud: FieldHUD = session.hud
	var interface := hud.battle_interface
	var popover := interface.tactical_popover
	assert_bool(popover.visible).is_false()
	assert_bool(interface.tactical_data.is_visible_in_tree()).is_false()
	var button := hud.combat_bar.get("_breakdown_button") as Button
	button.pressed.emit()
	assert_bool(popover.visible).is_true()
	assert_bool(button.button_pressed).is_true()
	assert_bool(interface.tactical_data.is_visible_in_tree()).is_true()
	assert_bool(interface.act_target_panel.is_visible_in_tree()).is_true()
	# It is one compact popover above the bar, not a docked panel.
	await get_tree().process_frame
	var bar_rect := hud.bar().get_global_rect()
	var viewport := get_tree().root.get_visible_rect()
	assert_float(popover.size.x).is_less(viewport.size.x * 0.4)
	assert_float(popover.size.y).is_less(viewport.size.y * 0.7)
	assert_bool(popover.get_global_rect().intersects(bar_rect)).is_false()
	button.pressed.emit()
	assert_bool(popover.visible).is_false()
	var key := InputEventAction.new()
	key.action = &"combat_breakdown"
	key.pressed = true
	get_tree().root.push_input(key)
	await get_tree().process_frame
	assert_bool(popover.visible).is_true()
	assert_bool(button.button_pressed).is_true()
	get_tree().root.push_input(key)
	await get_tree().process_frame
	assert_bool(popover.visible).is_false()
	await _close(session)


func test_combat_end_retracts_the_combat_parts() -> void:
	var session := await _session("RetractWight")
	var hud: FieldHUD = session.hud
	var bar := hud.bar()
	await get_tree().create_timer(DS.DUR_BASE + 0.05).timeout
	assert_float(bar.size.y).is_equal_approx(FieldHUD.COMBAT_BAR_HEIGHT, 1.0)
	assert_bool(hud.combat_active()).is_true()
	assert_bool((bar.get_node("BarColumn") as CanvasItem).visible).is_false()
	hud.exit_combat()
	assert_bool(hud.combat_active()).is_false()
	assert_object(hud.combat_bar).is_null()
	assert_object(hud.find_child("BattleInterface", true, false)).is_null()
	assert_object(bar.find_child("CombatBar", true, false)).is_null()
	assert_bool((bar.get_node("BarColumn") as CanvasItem).visible).is_true()
	assert_int(bar.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	await get_tree().create_timer(DS.DUR_BASE + 0.05).timeout
	assert_float(bar.size.y).is_equal_approx(FieldHUD.EXPLORE_BAR_HEIGHT, 1.0)
	assert_object((session.field as FieldMap).combat_overlay()).is_null()
	await _close(session)


## Ruling 4: the combat parts slide in with the bar, a brief edge vignette, a sound and one
## log line, all inside 0.5 s; reduced motion skips the motion and lands the bar at once.
func test_entry_cue_finishes_inside_half_a_second_and_honours_reduced_motion() -> void:
	var session := await _session("CueWight")
	var hud: FieldHUD = session.hud
	var interface: BattleInterface = hud.battle_interface
	assert_bool(interface.vignette.visible).is_true()
	assert_str(hud.combat_bar.log_lines()[0]).is_equal("COMBAT BEGINS")
	assert_object(hud.find_child("CombatAudio", false, false)).is_not_null()
	await get_tree().create_timer(0.5).timeout
	assert_bool(interface.vignette.visible).is_false()
	assert_float(hud.bar().size.y).is_equal_approx(FieldHUD.COMBAT_BAR_HEIGHT, 1.0)
	assert_float(hud.combat_bar.modulate.a).is_equal_approx(1.0, 0.001)
	await _close(session)

	GameState.set_setting("accessibility", "reduced_motion", true)
	var still := await _session("StillWight")
	var still_hud: FieldHUD = still.hud
	assert_bool(still_hud.battle_interface.vignette.visible).is_false()
	assert_float(still_hud.bar().size.y).is_equal_approx(FieldHUD.COMBAT_BAR_HEIGHT, 1.0)
	assert_float(still_hud.combat_bar.modulate.a).is_equal_approx(1.0, 0.001)
	still_hud.exit_combat()
	await get_tree().process_frame
	assert_float(still_hud.bar().size.y).is_equal_approx(FieldHUD.EXPLORE_BAR_HEIGHT, 1.0)
	GameState.set_setting("accessibility", "reduced_motion", false)
	await _close(still)


func _session(hostile_name: String, offset: Vector2i = Vector2i(1, 0)) -> Dictionary:
	var scene: Node = (load(TEST_ROOM_SCENE) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	var field := scene.find_child("FieldMap", true, false) as FieldMap
	var anchor := field.party_cells()[0]
	var hostile := (load(HOSTILE_SCENE) as PackedScene).instantiate() as Hostile
	hostile.name = hostile_name
	hostile.unit_id = &"bog-wight"
	hostile.realert_cooldown = 0.0
	field.get_parent().add_child(hostile)
	hostile.global_position = field.iso_grid().cell_to_world(anchor + offset)
	hostile.sync_cell()
	assert_bool(Battle.start_session(field, hostile).get("allowed", false)).is_true()
	var hud := field.field_hud()
	assert_object(hud).is_not_null()
	hud.enter_combat(field)
	await get_tree().process_frame
	return {"scene": scene, "field": field, "hostile": hostile, "hud": hud}


func _close(session: Dictionary) -> void:
	(session.hud as FieldHUD).exit_combat()
	if Battle.session_active:
		Battle._end_session(null)
	(session.scene as Node).queue_free()
	await get_tree().process_frame


func _press(bar: CombatBar, label_prefix: String) -> void:
	for button: Button in bar.get("_action_buttons"):
		if button.text.begins_with(label_prefix):
			assert_bool(button.disabled).override_failure_message("%s is locked" % button.text).is_false()
			button.pressed.emit()
			return
	fail("no %s button on the bar" % label_prefix)


func _await_ally_turn() -> void:
	for _step: int in 40:
		if Battle.ended or Battle.controller.state == CombatController.State.ALLY_TURN:
			return
		Battle.controller.end_turn()


## The id of the first action `actor` resolved after history index `since` (an enemy phase
## can follow in the same frame, so the last resolved action is not always the ally's).
func _resolved_action_since(since: int, actor: BattleActor) -> String:
	for index: int in range(since, Battle._combat_history.size()):
		var event: CombatEvent = Battle._combat_history[index]
		if event.type == &"action_resolved" and event.actor_id == actor.combat_id:
			return str(event.data.get("action_id", ""))
	return ""


func _until_presented(stage: BattleStageRegion, limit_ms: int = 8000) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline and stage.is_presenting_beats():
		await get_tree().process_frame
