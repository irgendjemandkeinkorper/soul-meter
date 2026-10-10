extends GdUnitTestSuite
## #281 after-pack: the #466 audit harness (combat_legibility_capture.gd on qa/281-legibility),
## re-timed for sequenced beats. Each committed action is framed along its presented beats
## (lunge, result card alone, enemy turn cue, enemy result, next turn) at half speed.
##
## Rendered acceptance evidence for #281's carried-forward #211 sentence: "A Bog Wight encounter
## is readable end-to-end with the log hidden: you can see who acted, on whom, from where, and
## what it cost." The fight opens through the production flow (field watch -> alert -> chart
## Battle state -> UIManager-mounted battle HUD), the dock's log label is hidden, and frames are
## captured at each beat. Presentation only: no combat rule, actor stat or art is changed except
## the Bog Wight's HP before the KO strike, so the KO beat is reachable in one hit.
##
## Beats tween over 0.14-0.22 s. To land a frame mid-beat the harness slows Engine.time_scale
## while a beat plays (frames are still rendered by the real overlay); captured file names say so.
##
## Run explicitly under Xvfb:
##   SOUL_METER_LEGIBILITY_CAPTURE_DIR=<dir> bash scripts/test.sh -a test/manual/combat_legibility_after_capture.gd

const FIELD_SCENE := preload("res://world/test_room.tscn")
const BOOT_STATE := "StateChart/Root/Boot"
const TITLE_STATE := "StateChart/Root/Menus/Title"
const CHARACTER_CREATION_STATE := "StateChart/Root/Menus/CharacterCreation"
const INTRO_STATE := "StateChart/Root/Menus/IntroNarration"
const LOADING_STATE := "StateChart/Root/Playing/Loading"
const ACTIVE_STATE := "StateChart/Root/Playing/Active"
const PAUSED_STATE := "StateChart/Root/Playing/Paused"
const DEPLOYMENT_SLATE_STATE := "StateChart/Root/Playing/DeploymentSlate"
const BATTLE_STATE := "StateChart/Root/Playing/Battle"
const CHAPTER_COMPLETE_STATE := "StateChart/Root/Playing/ChapterComplete"
const SLOW := 0.08
## Beat frames are keyed to presented beats; see _capture_beats.
const BEAT_SCALE := 1.0

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
var _stage: BattleStageRegion
var _overlay: CombatOverlay


func before_test() -> void:
	_dir = OS.get_environment("SOUL_METER_LEGIBILITY_CAPTURE_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://qa/combat-legibility")
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


func test_bog_wight_encounter_beats_with_the_log_hidden() -> void:
	var wight := _field_scene.get_node("BogWight") as Hostile
	# Same placement the production-flow test uses: the party walks up beside the wight.
	var interface := await _open_session(wight, Vector2i(1, 0))
	_print_roster("open")

	# (a) session open: units at cells, active highlight, facing.
	await _capture("01-session-open")

	# (b) hover a cell through the real GUI input path; the cursor strip reads it out.
	var foe := wight.battle_actor()
	var hover_cell := _cell_of(foe.combat_id) + Vector2i(0, 2)
	_push_motion(hover_cell)
	await _settle(0.3)
	var readout := interface.cursor_readout.text
	print("HOVER ", hover_cell, " READOUT ", readout)
	assert_str(readout).contains("(%d,%d)" % [hover_cell.x, hover_cell.y])
	await _capture("02-hover-height-strip")
	# Hovering the foe during the ally turn arms the target preview (current-target highlight).
	_push_motion(_cell_of(foe.combat_id))
	await _settle(0.4)
	print("HOVER FOE READOUT ", interface.cursor_readout.text)
	await _capture("02b-hover-foe-target-preview")
	_push_motion_away()

	# (c)/(d) a real Strike from the active ally; frames mid-beat and after.
	await _until_ally_turn()
	var striker := Battle.controller.active_actor()
	var hit := false
	for attempt: int in 6:
		await _until_ally_turn()
		if Battle.ended:
			break
		var hp_before := foe.hp
		Engine.time_scale = BEAT_SCALE
		var result := Battle.controller.submit_action(&"strike", foe)
		print("STRIKE attempt ", attempt, " allowed=", result.get("allowed"), " hp ", hp_before, "->", foe.hp)
		if not bool(result.get("allowed", false)):
			Engine.time_scale = 1.0
			Battle.controller.end_turn()
			continue
		await _capture_beats("03-strike-%d" % attempt)
		Engine.time_scale = 1.0
		await _settle(1.0)
		await _capture("05-hp-after-strike-%d" % attempt)
		if foe.hp < hp_before:
			hit = true
			break
	print("STRIKER ", striker.display_name if striker else "?", " HIT ", hit, " FOE HP ", foe.hp, "/", foe.max_hp)

	# Enemy beat: end the ally turn so the wight acts on the party.
	if not Battle.ended and Battle.controller.state == CombatController.State.ALLY_TURN:
		Engine.time_scale = BEAT_SCALE
		Battle.controller.end_turn()
		await _capture_beats("06-end-turn")
		Engine.time_scale = 1.0
		await _settle(1.0)
		_print_roster("after enemy")

	# (f) a move along a path from the ally side, when the active ally has a reachable cell.
	await _until_ally_turn()
	if not Battle.ended:
		await _try_ally_move("08")

	# (e) KO: shorten the wight to 1 HP, strike until it falls, frame the fall.
	foe.hp = 1
	for _attempt: int in 10:
		await _until_ally_turn()
		if Battle.ended or not foe.is_alive():
			break
		Engine.time_scale = SLOW
		var result := Battle.controller.submit_action(&"strike", foe)
		if not bool(result.get("allowed", false)):
			Engine.time_scale = 1.0
			Battle.controller.end_turn()
			continue
		await _real(0.05)
		if not foe.is_alive():
			Engine.time_scale = 1.0
			await _real(0.2)
			await _capture("11-ko-fading")
			await _settle(1.0)
			await _capture("12-ko-downed")
			await _settle(1.5)
			await _capture("13-ko-settled")
			break
		Engine.time_scale = 1.0
		await _settle(2.0)
	print("KO ", not foe.is_alive(), " ended ", Battle.ended)
	Engine.time_scale = 1.0


## The party stops `offset` cells from the wight, inside its alert radius; the real field
## watch opens the session and the chart enters Battle with no deployment step.
func _open_session(wight: Hostile, offset: Vector2i) -> BattleInterface:
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
	assert_bool(_state_is_active(DEPLOYMENT_SLATE_STATE)).is_false()
	_hud = UIManager._stack.back() as Screen
	var interface := _hud.find_child("BattleInterface", true, false) as BattleInterface
	_stage = interface.stage
	_overlay = _field.combat_overlay() as CombatOverlay
	assert_object(_overlay).is_not_null()
	var boot := get_tree().current_scene as CanvasItem
	if boot != null:
		_boot_visible = boot.visible
		boot.hide()
	var camera := player.get_node("Camera2D") as Camera2D
	camera.make_current()
	camera.reset_smoothing()
	# Log hidden: the dock's message label is the combat log.
	(_hud.get("_log_lbl") as Control).hide()
	await _settle(1.5)
	return interface


## A separated start: the party stops four cells off, so the wight has to walk (move slide)
## before it can strike, and the opening frame shows the two sides apart.
func test_bog_wight_approach_shows_a_move_slide() -> void:
	var wight := _field_scene.get_node("BogWight") as Hostile
	await _open_session(wight, Vector2i(4, 0))
	_print_roster("approach open")
	await _capture("20-separated-open")
	await _until_ally_turn()
	await _try_ally_move("21")
	await _until_ally_turn()
	if Battle.ended:
		return
	# Fixture (presentation evidence only): session seating puts the wight beside the party and
	# the ally has no movement budget (see README), so no real path exists to watch. Displace the
	# wight four cells back on the battlefield model, push one snapshot to the HUD so the overlay
	# re-seats it, then let the controller's own enemy turn walk it back along its path.
	var foe := wight.battle_actor()
	var back := _cell_of(foe.combat_id) + Vector2i(-4, 0)
	var moved: Dictionary = Battle.controller.battlefield.displace(foe, back)
	print("DISPLACE wight to ", back, " allowed=", moved.get("allowed"))
	var resync := CombatEvent.new()
	resync.data = {"snapshot": Battle.controller.snapshot()}
	_stage.consume_event(resync)
	await _settle(0.8)
	await _capture("21-fixture-wight-displaced")
	_print_roster("displaced")
	# Enemy approach: end the ally turn; the wight walks along its path, then acts.
	# Three cells at DUR_FAST each is ~0.42 s of game time; at SLOW that is ~5 s of wall clock.
	Engine.time_scale = SLOW
	Battle.controller.end_turn()
	for index: int in 8:
		await _real(1.3)
		await _capture("22-enemy-approach-slowmo-%d" % index)
	Engine.time_scale = BEAT_SCALE
	await _capture_beats("22-after-approach")
	Engine.time_scale = 1.0
	await _settle(2.4)
	await _capture("23-enemy-approach-settled")
	_print_roster("approach after")


func _try_ally_move(prefix: String) -> void:
	var mover := Battle.controller.active_actor()
	if mover == null:
		return
	var from := _cell_of(mover.combat_id)
	print("MOVER ", mover.display_name, " AP ", mover.action_points)
	for action: CombatAction in Battle.available_actions():
		if String(action.id).begins_with("move"):
			print("  action ", action.id, " lock '", Battle.action_lock_reason(action), "'")
	var dest := _far_reachable(from)
	print("MOVE ", mover.display_name, " ", from, " -> ", dest)
	if dest == Vector2i(-1, -1):
		return
	Engine.time_scale = SLOW * 0.5
	_push_click(dest)
	await _real(0.10)
	await _capture(prefix + "-move-slide-mid-path-slowmo")
	await _real(0.25)
	await _capture(prefix + "-move-slide-later-slowmo")
	Engine.time_scale = 1.0
	await _settle(1.0)
	await _capture(prefix + "-move-arrived")
	_print_roster("after move")


## Frames one command's presented beats. Rendering under Xvfb is slow and frame deltas lag the
## wall clock, so frames are keyed to what the overlay has presented (game time), not to
## wall-clock offsets: the first beat, then each change of active actor or target (a turn cue
## or an action beat) and its result a moment later, then the settled next turn.
func _capture_beats(prefix: String) -> void:
	var shot := 0
	await _game(0.1)
	await _capture("%s-%d-%s" % [prefix, shot, _beat_label()])
	shot += 1
	if _overlay._target_id != &"":
		await _game(0.6)
		await _capture("%s-%d-%s-result" % [prefix, shot, _beat_label()])
		shot += 1
	var active := _overlay._active_id
	var target := _overlay._target_id
	var deadline := Time.get_ticks_msec() + 30000
	while _overlay.is_presenting() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if _overlay._active_id == active and _overlay._target_id == target:
			continue
		active = _overlay._active_id
		target = _overlay._target_id
		await _game(0.12)
		await _capture("%s-%d-%s" % [prefix, shot, _beat_label()])
		shot += 1
		if target != &"":
			await _game(0.5)
			await _capture("%s-%d-%s-result" % [prefix, shot, _beat_label()])
			shot += 1
	await _game(0.3)
	await _capture("%s-%d-settled" % [prefix, shot])


func _beat_label() -> String:
	var who := _short(_overlay._active_id)
	return who + ("-on-" + _short(_overlay._target_id) if _overlay._target_id != &"" else "-turn")


func _short(id: StringName) -> String:
	return "wight" if String(id).contains("BogWight") else ("vex" if String(id).begins_with("ally") else String(id).get_file())


## Game-time wait: follows Engine.time_scale and the same frame deltas the overlay's tweens use.
func _game(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, false).timeout


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Wall-clock wait regardless of Engine.time_scale.
func _real(seconds: float) -> void:
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
			# Let the overlay finish whatever enemy beat put us here.
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


func _push_motion_away() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(4, 4)
	motion.global_position = motion.position
	get_viewport().push_input(motion)


func _push_click(cell: Vector2i) -> void:
	_push_motion(cell)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = _viewport_point(cell)
		click.global_position = click.position
		get_viewport().push_input(click)


func _far_reachable(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_len := 0
	var snapshot := Battle.controller.snapshot()
	var rows: Array = (snapshot.get("movement", {}) as Dictionary).get("reachable", [])
	print("REACHABLE rows ", rows.size(), " from ", from)
	for row: Dictionary in rows:
		var cells: Array = row.get("path_cells", [])
		print("  row ", row.get("destination", ""), " cells ", cells)
		if cells.size() < 3 or cells.size() > 4:
			continue
		var end: Vector2i = cells.back()
		var rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(-200)
		if not rect.has_point(_viewport_point(end)):
			continue
		if cells.size() > best_len:
			best_len = cells.size()
			best = end
	return best


func _print_roster(tag: String) -> void:
	for side: Array in [Battle.controller.allies, Battle.controller.enemies]:
		for actor: BattleActor in side:
			print(tag, ": ", actor.display_name, " cell ", _cell_of(actor.combat_id), " facing ",
				Battle.controller.battlefield.facing_of(actor), " hp ", actor.hp, "/", actor.max_hp,
				" screen ", _viewport_point(_cell_of(actor.combat_id)))


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
