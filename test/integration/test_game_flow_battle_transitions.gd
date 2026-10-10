extends GdUnitTestSuite

const FIELD_SCENE := preload("res://world/test_room.tscn")
const NO_COMBAT_SCENE := preload("res://world/interiors/players_house.tscn")
const BOOT_STATE := "StateChart/Root/Boot"
const TITLE_STATE := "StateChart/Root/Menus/Title"
const CHARACTER_CREATION_STATE := "StateChart/Root/Menus/CharacterCreation"
const INTRO_STATE := "StateChart/Root/Menus/IntroNarration"
const LOADING_STATE := "StateChart/Root/Playing/Loading"
const ACTIVE_STATE := "StateChart/Root/Playing/Active"
const PAUSED_STATE := "StateChart/Root/Playing/Paused"
const DEPLOYMENT_SLATE_STATE := "StateChart/Root/Playing/DeploymentSlate"
const DEPLOYMENT_ATTUNE_STATE := "StateChart/Root/Playing/DeploymentAttune"
const DEPLOYMENT_LOADOUT_STATE := "StateChart/Root/Playing/DeploymentLoadout"
const DEPLOYMENT_PLACE_STATE := "StateChart/Root/Playing/DeploymentPlace"
const BATTLE_STATE := "StateChart/Root/Playing/Battle"
const CHAPTER_COMPLETE_STATE := "StateChart/Root/Playing/ChapterComplete"

var _field_scene: Node2D
var _field: FieldMap
var _loading_handler_was_connected: bool = false
var _game_state_before: Dictionary
var _reputation_before: Dictionary
var _renown_before: Dictionary
var _quests_before: Dictionary
var _autosave_reason_before: String


func before_test() -> void:
	_game_state_before = GameState.to_dict().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)
	_quests_before = QuestRegistry.to_dict().duplicate(true)
	_autosave_reason_before = SaveGame._pending_autosave_reason
	GameState._seed_demo_data()
	GameState.set_flag("defeated_bog_wight", false)
	GameState.set_flag("field_debt_proof_looted", false)
	_reset_battle()
	_field_scene = FIELD_SCENE.instantiate() as Node2D
	add_child(_field_scene)
	_field = _field_scene.get_node("FieldMap") as FieldMap
	var loading_state: Node = GameFlow.get_node(LOADING_STATE)
	_loading_handler_was_connected = loading_state.state_entered.is_connected(
		GameFlow._on_loading_entered
	)
	if _loading_handler_was_connected:
		loading_state.state_entered.disconnect(GameFlow._on_loading_entered)
	await _enter_active_state()
	UIManager.close_all()
	get_tree().paused = false


func after_test() -> void:
	if _state_is_active(BATTLE_STATE):
		GameFlow.send_event(&"battle_end")
		await get_tree().process_frame
	await _return_to_title()
	var loading_state: Node = GameFlow.get_node(LOADING_STATE)
	if (
		_loading_handler_was_connected
		and not loading_state.state_entered.is_connected(GameFlow._on_loading_entered)
	):
		loading_state.state_entered.connect(GameFlow._on_loading_entered)
	if _field != null:
		_field.set_combat_mode(false)
	UIManager.close_all()
	get_tree().paused = false
	_reset_battle()
	_field_scene.free()
	_field_scene = null
	_field = null
	GameState.from_dict(_game_state_before)
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)
	QuestRegistry.reset()
	QuestRegistry.from_dict(_quests_before)
	SaveGame._pending_autosave_reason = _autosave_reason_before


func test_enter_battle_goes_directly_to_battle_and_pause_returns_there() -> void:
	var music_depth_before: int = MusicDirector.get_context_stack().size()
	Battle.start(EncounterIds.BOG_WIGHT)

	GameFlow.send_event(&"enter_battle")
	await get_tree().process_frame

	assert_bool(_state_is_active(BATTLE_STATE)).is_true()
	assert_bool(_state_is_active(DEPLOYMENT_SLATE_STATE)).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_field.combat_mode_active()).is_true()
	assert_int(MusicDirector.get_context_stack().size()).is_equal(music_depth_before + 1)

	GameFlow.send_event(&"pause")
	await get_tree().process_frame
	assert_bool(_state_is_active(PAUSED_STATE)).is_true()
	assert_bool(get_tree().paused).is_true()
	# Pausing mid-fight is not ending it: the field stays in combat mode and the battle music
	# context is neither popped nor re-pushed across the round trip.
	assert_bool(_field.combat_mode_active()).is_true()
	assert_int(MusicDirector.get_context_stack().size()).is_equal(music_depth_before + 1)

	GameFlow.send_event(&"resume")
	await get_tree().process_frame
	assert_bool(_state_is_active(BATTLE_STATE)).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_field.combat_mode_active()).is_true()
	assert_int(MusicDirector.get_context_stack().size()).is_equal(music_depth_before + 1)

	GameFlow.send_event(&"battle_end")
	await get_tree().process_frame
	assert_bool(_state_is_active(ACTIVE_STATE)).is_true()
	assert_bool(_field.combat_mode_active()).is_false()
	assert_int(MusicDirector.get_context_stack().size()).is_equal(music_depth_before)


## #281/#456: the authored wight alerts through physics, fights on this field, and
## unlocks the proof through the victory ledger. Only its HP is shortened in this fixture.
func test_bog_wight_is_fought_on_the_field_and_the_proof_unlocks_after_victory() -> void:
	var hostile := _field_scene.get_node("BogWight") as Hostile
	var player := _field.player()
	var proof := _field_scene.get_node("FieldDebtProof") as Pickup
	var field_id := _field_scene.get_instance_id()
	assert_bool(proof._is_unlocked()).is_false()
	GameFlow.watch_field_hostiles()
	await get_tree().physics_frame
	assert_bool(Battle.session_active).is_false()
	player.global_position = _field.iso_grid().cell_to_world(
		hostile.cell + Vector2i(1, 0)
	)
	for _frame: int in 30:
		if Battle.session_active:
			break
		await get_tree().physics_frame
	await get_tree().process_frame
	assert_bool(Battle.session_active).is_true()
	assert_bool(_state_is_active(BATTLE_STATE)).is_true()
	assert_bool(_state_is_active(DEPLOYMENT_SLATE_STATE)).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_object(Battle._current_field_map()).is_same(_field)
	assert_int(_field_scene.get_instance_id()).is_equal(field_id)
	assert_int(UIManager._stack.size()).is_equal(1)
	var hud := UIManager._stack.back() as Screen
	var interface := hud.find_child("BattleInterface", true, false) as BattleInterface
	assert_object(interface).is_not_null()
	assert_int(hud.find_children("BattleInterface", "", true, false).size()).is_equal(1)
	assert_object(_field.combat_overlay()).is_not_null()
	assert_bool((hud.get_node("Backdrop") as ColorRect).visible).is_false()
	assert_bool(interface.tactical_data_visible()).is_false()
	# The command dock toggles the region in the one interface, not another HUD.
	(hud.get("_tactical_data_button") as Button).pressed.emit()
	assert_bool(interface.tactical_data_visible()).is_true()
	(hud.get("_tactical_data_button") as Button).pressed.emit()
	assert_bool(interface.tactical_data_visible()).is_false()
	await _capture_bog_wight_hud()

	var foe := hostile.battle_actor()
	foe.hp = 1
	var submitted_strike := false
	for _step: int in 200:
		if Battle.ended or Battle.controller == null:
			break
		if Battle.controller.state == CombatController.State.ALLY_TURN:
			var result := Battle.controller.submit_action(&"strike", foe)
			if bool(result.get("allowed", false)):
				submitted_strike = true
			else:
				Battle.controller.end_turn()
		else:
			Battle.controller.end_turn()
	await get_tree().process_frame
	assert_bool(submitted_strike).is_true()
	assert_bool(Battle.ended).is_true()
	assert_int(Battle.last_result.state).is_equal(BattleResult.State.VICTORY)
	assert_bool(GameState.flag_is_true("defeated_bog_wight")).is_true()
	assert_int(hostile.state).is_equal(Hostile.State.DOWNED)
	assert_bool(hostile.get_collision_layer_value(1)).is_false()
	assert_bool(Battle.session_active).is_false()
	assert_bool(proof._is_unlocked()).is_true()

	# #473: ENCOUNTER RESOLVED waits until the field has presented the finishing beats.
	var outcome_deadline := Time.get_ticks_msec() + 60000
	while not bool(hud.call("outcome_shown")) and Time.get_ticks_msec() < outcome_deadline:
		await get_tree().process_frame
	assert_bool(bool(hud.call("outcome_shown"))).is_true()
	var outcome := hud.get("_outcome_box") as VBoxContainer
	(outcome.get_child(outcome.get_child_count() - 1) as Button).pressed.emit()
	await get_tree().process_frame
	if _state_is_active(BATTLE_STATE):
		var loot := UIManager._stack.back() as LootPanel
		assert_object(loot).is_not_null()
		loot.dismissed.emit([] as Array[Dictionary])
		await get_tree().process_frame
	assert_bool(_state_is_active(ACTIVE_STATE)).is_true()
	assert_bool(_field.combat_mode_active()).is_false()
	assert_bool(player.is_physics_processing()).is_true()
	assert_int(_field_scene.get_instance_id()).is_equal(field_id)
	var item_id := proof.item_id
	var count_before := GameState.item_count(item_id)
	player.global_position = proof.global_position
	for _frame: int in 4:
		await get_tree().physics_frame
	assert_bool(proof._player_in_range).is_true()
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	proof._unhandled_input(interact)
	await get_tree().process_frame
	assert_bool(GameState.flag_is_true("field_debt_proof_looted")).is_true()
	assert_int(GameState.item_count(item_id)).is_equal(count_before + 1)
	assert_bool(is_instance_valid(proof)).is_false()


## Optional rendered evidence from the same production flow; never wait on a draw headlessly.
func _capture_bog_wight_hud() -> void:
	var capture_dir := OS.get_environment("SOUL_METER_BOG_WIGHT_CAPTURE_DIR")
	if capture_dir.is_empty():
		return
	assert_str(DisplayServer.get_name()).is_not_equal("headless")
	if DisplayServer.get_name() == "headless":
		return
	assert_int(DirAccess.make_dir_recursive_absolute(capture_dir)).is_equal(OK)
	var boot := get_tree().current_scene as CanvasItem
	var boot_visible := boot.visible if boot != null else false
	if boot != null:
		boot.hide()
	var camera := _field.player().get_node("Camera2D") as Camera2D
	camera.make_current()
	camera.reset_smoothing()
	await get_tree().create_timer(0.5).timeout
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var capture_path := capture_dir.path_join("bog-wight-hud.png")
	assert_int(image.save_png(capture_path)).is_equal(OK)
	print("BOG WIGHT HUD CAPTURE: ", capture_path)
	if boot != null:
		boot.visible = boot_visible


func test_enter_set_piece_traverses_the_existing_deployment_chain() -> void:
	Battle.start(EncounterIds.BOG_WIGHT)

	GameFlow.send_event(&"enter_set_piece")
	await get_tree().process_frame
	assert_bool(_state_is_active(DEPLOYMENT_SLATE_STATE)).is_true()

	var expected_states: Array[String] = [
		DEPLOYMENT_ATTUNE_STATE,
		DEPLOYMENT_LOADOUT_STATE,
		DEPLOYMENT_PLACE_STATE,
	]
	for state_path: String in expected_states:
		GameFlow.send_event(&"deployment_next")
		await get_tree().process_frame
		assert_bool(_state_is_active(state_path)).is_true()

	GameFlow.send_event(&"accept_slate")
	await get_tree().process_frame
	assert_bool(_state_is_active(BATTLE_STATE)).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_field.combat_mode_active()).is_true()


func test_enter_battle_guard_refuses_a_no_combat_field_with_fr606_shape() -> void:
	_field_scene.free()
	_field_scene = NO_COMBAT_SCENE.instantiate() as Node2D
	add_child(_field_scene)
	_field = _field_scene.find_child("FieldMap", true, false) as FieldMap

	var refusal: Dictionary = Battle.can_fight_here()
	assert_bool(bool(refusal.get("allowed", true))).is_false()
	assert_str(String(refusal.get("blocked_by", &""))).is_equal("no_combat_zone")
	assert_bool(refusal.has("nearest_unblock")).is_true()
	assert_bool(refusal.has("message")).is_true()
	var guard: ExpressionGuard = GameFlow.get_node(
		"StateChart/Root/Playing/Active/ToBattle"
	).guard
	assert_str(guard.expression).is_equal("can_fight_here and not editor_open")

	GameFlow.send_event(&"enter_battle")
	await get_tree().process_frame

	assert_bool(_state_is_active(ACTIVE_STATE)).is_true()
	assert_bool(_state_is_active(BATTLE_STATE)).is_false()
	assert_bool(_field.combat_mode_active()).is_false()


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
	if _in_deployment():
		Battle.start(EncounterIds.BOG_WIGHT)
		await _finish_deployment()
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


func _return_to_title() -> void:
	await _enter_active_state()
	if _state_is_active(ACTIVE_STATE):
		GameFlow.send_event(&"pause")
		await get_tree().process_frame
	if _state_is_active(PAUSED_STATE):
		GameFlow.send_event(&"to_main_menu")
		await get_tree().process_frame


func _in_deployment() -> bool:
	return (
		_state_is_active(DEPLOYMENT_SLATE_STATE)
		or _state_is_active(DEPLOYMENT_ATTUNE_STATE)
		or _state_is_active(DEPLOYMENT_LOADOUT_STATE)
		or _state_is_active(DEPLOYMENT_PLACE_STATE)
	)


func _finish_deployment() -> void:
	if _state_is_active(DEPLOYMENT_SLATE_STATE):
		GameFlow.send_event(&"deployment_next")
		await get_tree().process_frame
	if _state_is_active(DEPLOYMENT_ATTUNE_STATE):
		GameFlow.send_event(&"deployment_next")
		await get_tree().process_frame
	if _state_is_active(DEPLOYMENT_LOADOUT_STATE):
		GameFlow.send_event(&"deployment_next")
		await get_tree().process_frame
	if _state_is_active(DEPLOYMENT_PLACE_STATE):
		GameFlow.send_event(&"accept_slate")
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


## F1 (#281): the flow, not the field, owns the edge from "a hostile noticed the party" to
## the chart entering Battle. The fixture bypasses `_complete_scene_load`, so the watch is
## armed by hand exactly as arrival on a real field arms it.
func _ambient_hostile(offset: Vector2) -> Hostile:
	# A hostile whose group is already flagged beaten retires itself in `_ready`; a prior test
	# in this suite wins that fight, so clear the flag before the fixture mob is born.
	GameState.set_flag("defeated_bog_wight", false)
	GameFlow.watch_field_hostiles()
	var player := _field_scene.find_child("Player", true, false) as Player
	var hostile := (
		load("res://actors/hostile/hostile.tscn") as PackedScene
	).instantiate() as Hostile
	hostile.name = "AmbientWight"
	hostile.unit_id = &"bog-wight"
	hostile.group_id = &"bog-wight"
	hostile.realert_cooldown = 0.0
	hostile.position = player.global_position + offset
	_field_scene.add_child(hostile)
	# The sensor's initial-overlap pass is deferred and then waits one physics frame.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	return hostile


func test_first_hostile_alert_opens_an_ambient_session_and_enters_battle() -> void:
	var hostile := await _ambient_hostile(Vector2(96.0, 0.0))

	assert_bool(Battle.session_active) \
		.override_failure_message("walking into a hostile's alert radius must open a session") \
		.is_true()
	assert_bool(_state_is_active(BATTLE_STATE)).is_true()
	assert_bool(_state_is_active(DEPLOYMENT_SLATE_STATE)).is_false()
	assert_bool(_field.combat_mode_active()).is_true()
	assert_int(hostile.state).is_equal(Hostile.State.IN_COMBAT)


func test_victory_downs_the_hostile_and_writes_its_group_flag() -> void:
	var hostile := await _ambient_hostile(Vector2(96.0, 0.0))
	assert_bool(Battle.session_active).is_true()

	hostile.battle_actor().hp = 0
	Battle.controller.force_finish(CombatController.ResultState.VICTORY, &"slain")
	await get_tree().process_frame

	assert_bool(Battle.session_active).is_false()
	assert_int(hostile.state).is_equal(Hostile.State.DOWNED)
	assert_bool(hostile.get_collision_layer_value(1)).is_false()
	assert_bool(GameState.flag_is_true("defeated_bog_wight")).is_true()


func test_fleeing_returns_a_standing_hostile_to_idle_at_full_hp() -> void:
	var hostile := await _ambient_hostile(Vector2(96.0, 0.0))
	assert_bool(Battle.session_active).is_true()
	var actor := hostile.battle_actor()
	actor.hp = 3
	# The party is still inside the radius after fleeing; the cooldown is what keeps the mob from
	# re-opening the fight on the very next physics frame, so give it a real one here.
	hostile.realert_cooldown = 60.0

	Battle.flee()
	await get_tree().process_frame

	assert_bool(Battle.session_active).is_false()
	assert_int(hostile.state).is_equal(Hostile.State.IDLE)
	assert_int(actor.hp).is_equal(actor.max_hp)
	assert_bool(hostile.get_collision_layer_value(1)).is_true()


## #281 G6a: in an ambient session charge time is authoritative, and the ally's first turn
## must still offer the move range. The party stops four cells from the authored wight, so
## there are free cells on every side of the ally once the wight has taken its first turn.
func test_ambient_ally_turn_offers_reachable_cells_under_charge_time() -> void:
	var hostile := _field_scene.get_node("BogWight") as Hostile
	var player := _field.player()
	GameFlow.watch_field_hostiles()
	await get_tree().physics_frame
	player.global_position = _field.iso_grid().cell_to_world(hostile.cell + Vector2i(4, 0))
	for _frame: int in 30:
		if Battle.session_active:
			break
		await get_tree().physics_frame
	await get_tree().process_frame
	assert_bool(Battle.session_active).is_true()
	var controller := Battle.controller
	assert_bool(controller.rules.use_charge_time).is_true()
	for _step: int in 20:
		if controller.state == CombatController.State.ALLY_TURN:
			break
		controller.end_turn()
	assert_int(controller.state).is_equal(CombatController.State.ALLY_TURN)

	var movement: Dictionary = controller.snapshot().get("movement", {})
	var reachable: Array = movement.get("reachable", [])
	assert_bool(reachable.is_empty()) \
		.override_failure_message(
			"the ally's CT turn offers no reachable cells: %s" % str(movement)
		) \
		.is_false()
	if reachable.is_empty():
		return
	var destination := StringName((reachable[0] as Dictionary).get("destination", &""))
	assert_bool(bool(controller.move_query(destination).get("allowed", false))).is_true()
