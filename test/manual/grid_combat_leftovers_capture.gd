extends GdUnitTestSuite
## #473 before/after pack: grid combat leftovers from #281, rendered through the production flow
## (field watch -> alert -> chart Battle state -> UIManager-mounted battle HUD) on test_room.
##   1. the command dock on a grid battlefield (zone FRONT/BACK/FLANK move cards);
##   2. the hover readout over a reachable cell under charge time;
##   3. the dock (party HP, unit plate, CT strip, ENCOUNTER RESOLVED) during sequenced beats.
## Presentation only: no combat rule or actor stat is changed except the Bog Wight's HP before
## the finishing strike, so the KO beat is reachable in one hit.
##
## Run explicitly under Xvfb:
##   SOUL_METER_473_CAPTURE_DIR=<dir> bash scripts/test.sh -a test/manual/grid_combat_leftovers_capture.gd

const FIELD_SCENE := preload("res://world/test_room.tscn")
const BOOT_STATE := "StateChart/Root/Boot"
const TITLE_STATE := "StateChart/Root/Menus/Title"
const CHARACTER_CREATION_STATE := "StateChart/Root/Menus/CharacterCreation"
const INTRO_STATE := "StateChart/Root/Menus/IntroNarration"
const LOADING_STATE := "StateChart/Root/Playing/Loading"
const ACTIVE_STATE := "StateChart/Root/Playing/Active"
const PAUSED_STATE := "StateChart/Root/Playing/Paused"
const BATTLE_STATE := "StateChart/Root/Playing/Battle"
const CHAPTER_COMPLETE_STATE := "StateChart/Root/Playing/ChapterComplete"

var _field_scene: Node2D
var _field: FieldMap
var _loading_handler_was_connected := false
var _game_state_before: Dictionary
var _reputation_before: Dictionary
var _renown_before: Dictionary
var _quests_before: Dictionary
var _boot_visible := true
var _dir := ""
var _hud: Screen
var _interface: BattleInterface
var _overlay: CombatOverlay


func before_test() -> void:
	_dir = OS.get_environment("SOUL_METER_473_CAPTURE_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://qa/grid-combat-leftovers-473")
	DirAccess.make_dir_recursive_absolute(_dir)
	get_tree().root.size = Vector2i(1920, 1080)
	_game_state_before = GameState.to_dict().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)
	_quests_before = QuestRegistry.to_dict().duplicate(true)
	GameState._seed_demo_data()
	GameState.set_flag("defeated_bog_wight", false)
	_reset_battle()
	_field_scene = FIELD_SCENE.instantiate() as Node2D
	add_child(_field_scene)
	_field = _field_scene.get_node("FieldMap") as FieldMap
	var loading_state: Node = GameFlow.get_node(LOADING_STATE)
	_loading_handler_was_connected = loading_state.state_entered.is_connected(GameFlow._on_loading_entered)
	if _loading_handler_was_connected:
		loading_state.state_entered.disconnect(GameFlow._on_loading_entered)
	await _enter_active_state()
	UIManager.close_all()
	get_tree().paused = false


func after_test() -> void:
	Engine.time_scale = 1.0
	if _state_is_active(BATTLE_STATE):
		GameFlow.send_event(&"battle_end")
		await get_tree().process_frame
	var loading_state: Node = GameFlow.get_node(LOADING_STATE)
	if _loading_handler_was_connected and not loading_state.state_entered.is_connected(GameFlow._on_loading_entered):
		loading_state.state_entered.connect(GameFlow._on_loading_entered)
	if _field != null:
		_field.set_combat_mode(false)
	UIManager.close_all()
	get_tree().paused = false
	_reset_battle()
	_field_scene.free()
	GameState.from_dict(_game_state_before)
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)
	QuestRegistry.reset()
	QuestRegistry.from_dict(_quests_before)
	var boot := get_tree().current_scene as CanvasItem
	if boot != null:
		boot.visible = _boot_visible


## Items 1 and 2: the dock on the grid, then a hovered reachable cell under charge time.
func test_dock_and_hover_quote_on_the_grid() -> void:
	var wight := _field_scene.get_node("BogWight") as Hostile
	await _open_session(wight, Vector2i(4, 0))
	await _until_ally_turn()
	print("USE_CHARGE_TIME ", Battle.controller.rules.use_charge_time)
	var buttons: Array = _hud.get("_action_buttons")
	for button: Button in buttons:
		print("CARD '", button.text, "' visible=", button.is_visible_in_tree(), " disabled=", button.disabled,
			" tip=", button.tooltip_text.replace("\n", " | "))
	await _capture("item1-dock-grid")

	var mover := Battle.controller.active_actor()
	var from := _cell_of(mover.combat_id)
	var row := _far_reachable(from)
	if row.is_empty():
		print("NO REACHABLE CELL from ", from)
		return
	var cells: Array = row.get("path_cells", [])
	var dest: Vector2i = cells.back()
	print("HOVER ", from, " -> ", dest, " ap_cost=", row.get("ap_cost"), " ct_cost=", row.get("ct_cost"),
		" charge=", Battle.controller.scheduler.charge_of(mover))
	_push_motion(dest)
	await _settle(0.4)
	print("READOUT '", _interface.cursor_readout.text, "'")
	await _capture("item2-hover-move-quote")


## Item 3: the dock while an enemy phase is still being presented, then the finishing strike.
func test_dock_follows_presented_beats() -> void:
	var wight := _field_scene.get_node("BogWight") as Hostile
	await _open_session(wight, Vector2i(1, 0))
	var foe := wight.battle_actor()
	var captured_enemy_beat := false
	for attempt: int in 8:
		await _until_ally_turn()
		if Battle.ended:
			break
		var hp_before := _party_hp()
		Battle.controller.end_turn()
		var hp_after := _party_hp()
		if hp_after == hp_before:
			await _settle(1.5)
			continue
		print("ENEMY PHASE attempt ", attempt, " party HP ", hp_before, " -> ", hp_after)
		await _game(0.15)
		_print_dock("mid-enemy-phase")
		await _capture("item3-enemy-phase-mid-beat")
		while _overlay.is_presenting():
			await get_tree().process_frame
		await _game(0.4)
		_print_dock("enemy-phase-settled")
		await _capture("item3-enemy-phase-settled")
		captured_enemy_beat = true
		break
	print("CAPTURED ENEMY BEAT ", captured_enemy_beat)

	foe.hp = 1
	for _attempt: int in 10:
		await _until_ally_turn()
		if Battle.ended or not foe.is_alive():
			break
		var result := Battle.controller.submit_action(&"strike", foe)
		if not bool(result.get("allowed", false)) or foe.is_alive():
			Battle.controller.end_turn()
			await _settle(1.5)
			continue
		await _game(0.3)
		_print_dock("ko-strike-mid-beat")
		await _capture("item3-ko-strike-mid-beat")
		var deadline := Time.get_ticks_msec() + 10000
		while _overlay.is_presenting() and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		await _game(0.3)
		_print_dock("ko-strike-settled")
		await _capture("item3-ko-strike-settled")
		break
	print("KO ", not foe.is_alive(), " ended ", Battle.ended)


func _print_dock(tag: String) -> void:
	var lines: PackedStringArray = []
	for row: Node in (_hud.get("_party_box") as Node).get_children():
		var texts: PackedStringArray = []
		for child: Node in row.get_children():
			if child is Label:
				texts.append((child as Label).text)
		lines.append(" ".join(texts))
	var outcome := _hud.get("_outcome_box") as Control
	var overlay_hp: PackedStringArray = []
	for id: StringName in _overlay._actors:
		overlay_hp.append("%s=%s" % [id, _overlay._actors[id].get("hp")])
	print(tag, " DOCK ", " / ".join(lines), " | FOE '", (_hud.get("_enemy_lbl") as Label).text,
		"' | PLATE '", _interface.active_unit_plate.hp_label.text, "' ", _interface.active_unit_plate.ct_label.text,
		" | RESOLVED ", outcome.visible, " | OVERLAY ", ", ".join(overlay_hp),
		" | presenting ", _overlay.is_presenting())


func _party_hp() -> Array[int]:
	var hp: Array[int] = []
	for ally: BattleActor in Battle.controller.allies:
		hp.append(ally.hp)
	return hp


func _open_session(wight: Hostile, offset: Vector2i) -> void:
	assert_str(DisplayServer.get_name()).is_not_equal("headless")
	var player := _field.player()
	GameFlow.watch_field_hostiles()
	await get_tree().physics_frame
	player.global_position = _field.iso_grid().cell_to_world(wight.cell + offset)
	for _frame: int in 30:
		if Battle.session_active:
			break
		await get_tree().physics_frame
	await get_tree().process_frame
	assert_bool(Battle.session_active).is_true()
	assert_bool(_state_is_active(BATTLE_STATE)).is_true()
	_hud = UIManager._stack.back() as Screen
	_interface = _hud.find_child("BattleInterface", true, false) as BattleInterface
	_overlay = _field.combat_overlay() as CombatOverlay
	assert_object(_overlay).is_not_null()
	var boot := get_tree().current_scene as CanvasItem
	if boot != null:
		_boot_visible = boot.visible
		boot.hide()
	var camera := player.get_node("Camera2D") as Camera2D
	camera.make_current()
	camera.reset_smoothing()
	await _settle(1.5)


func _game(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, false).timeout


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _dir.path_join(name + ".png")
	assert_int(image.save_png(path)).is_equal(OK)
	print("SHOT ", path)


func _until_ally_turn() -> void:
	for _step: int in 40:
		if Battle.ended or Battle.controller == null:
			return
		if Battle.controller.state == CombatController.State.ALLY_TURN:
			var deadline := Time.get_ticks_msec() + 8000
			while Time.get_ticks_msec() < deadline and _overlay.is_presenting():
				await get_tree().process_frame
			return
		Battle.controller.end_turn()
		await get_tree().process_frame


func _cell_of(actor_id: StringName) -> Vector2i:
	var actor := Battle.controller.actor_by_id(actor_id)
	var token := String(Battle.controller.battlefield.position_of(actor))
	var parts := token.trim_prefix("c:").split(",")
	return Vector2i(parts[0].to_int(), parts[1].to_int()) if parts.size() >= 2 else Vector2i(-1, -1)


func _viewport_point(cell: Vector2i) -> Vector2:
	return _overlay.get_global_transform_with_canvas() * _overlay.cell_center(cell)


func _push_motion(cell: Vector2i) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _viewport_point(cell)
	motion.global_position = motion.position
	get_viewport().push_input(motion)


func _far_reachable(from: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_len := 0
	var rows: Array = (Battle.controller.snapshot().get("movement", {}) as Dictionary).get("reachable", [])
	print("REACHABLE rows ", rows.size(), " from ", from)
	for row: Dictionary in rows:
		var cells: Array = row.get("path_cells", [])
		if cells.size() < 3 or cells.size() > 4:
			continue
		var rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(-200)
		if not rect.has_point(_viewport_point(cells.back())):
			continue
		if cells.size() > best_len:
			best_len = cells.size()
			best = row
	return best


func _enter_active_state() -> void:
	if _state_is_active(ACTIVE_STATE):
		return
	if _state_is_active(BOOT_STATE):
		GameFlow.send_event(&"boot_done")
		await get_tree().process_frame
	if _state_is_active(CHARACTER_CREATION_STATE):
		GameFlow.send_event(&"new_game")
		await get_tree().process_frame
	if _state_is_active(INTRO_STATE):
		GameFlow.send_event(&"intro_done")
		await get_tree().process_frame
	if _state_is_active(PAUSED_STATE):
		GameFlow.chart.set_expression_property(&"resume_to_battle", false)
		GameFlow.send_event(&"resume")
		await get_tree().process_frame
	if _state_is_active(BATTLE_STATE):
		GameFlow.send_event(&"battle_end")
		await get_tree().process_frame
	if _state_is_active(CHAPTER_COMPLETE_STATE):
		GameFlow.send_event(&"continue_exploring")
		await get_tree().process_frame
	if _state_is_active(TITLE_STATE):
		GameFlow.send_event(&"new_game")
		await get_tree().process_frame
	if _state_is_active(LOADING_STATE):
		GameFlow.send_event(&"level_ready")
		await get_tree().process_frame


func _state_is_active(path: String) -> bool:
	var state: Node = GameFlow.get_node_or_null(path)
	return state != null and bool(state.get("active"))


func _reset_battle() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.allies.clear()
	Battle.enemies.clear()
	Battle._definition.clear()
	Battle._combat_history.clear()
	Battle.encounter_id = &""
	Battle.last_result = null
	Battle.ended = true
