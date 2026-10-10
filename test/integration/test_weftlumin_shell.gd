extends GdUnitTestSuite

const FIELD := preload("res://world/test_room.tscn")
const PLAYING := "StateChart/Root/Playing/"

var _field_scene: Node2D
var _field: FieldMap
var _snapshot: Dictionary
var _rng_seed: int
var _rng_state: int
var _loading_connected := false
var _title_connected := false
var _force_before := false


func before_test() -> void:
	_snapshot = SaveGame.capture_runtime_state()
	_rng_seed = SkillCheck.random_number_generator.seed
	_rng_state = SkillCheck.random_number_generator.state
	_force_before = WeftluminBootstrap.force_enabled_for_tests
	WeftluminBootstrap.close()
	Battle.abandon()
	var loading: Node = GameFlow.get_node(PLAYING + "Loading")
	_loading_connected = loading.state_entered.is_connected(GameFlow._on_loading_entered)
	if _loading_connected:
		loading.state_entered.disconnect(GameFlow._on_loading_entered)
	var title: Node = GameFlow.get_node("StateChart/Root/Menus/Title")
	_title_connected = title.state_entered.is_connected(GameFlow._on_title_entered)
	if _title_connected:
		title.state_entered.disconnect(GameFlow._on_title_entered)
	GameState._seed_demo_data()
	GameState.set_flag("defeated_bog_wight", false)
	_field_scene = FIELD.instantiate() as Node2D
	add_child(_field_scene)
	_field = _field_scene.get_node("FieldMap") as FieldMap
	await _enter_active()
	UIManager.close_all()
	get_tree().paused = false
	WeftluminBootstrap.force_enabled_for_tests = true


func after_test() -> void:
	WeftluminBootstrap.close()
	WeftluminBootstrap.force_enabled_for_tests = _force_before
	Battle.abandon()
	await _enter_active()
	GameFlow.send_event(&"pause")
	GameFlow.send_event(&"to_main_menu")
	await get_tree().process_frame
	var loading: Node = GameFlow.get_node(PLAYING + "Loading")
	if _loading_connected:
		loading.state_entered.connect(GameFlow._on_loading_entered)
	var title: Node = GameFlow.get_node("StateChart/Root/Menus/Title")
	if _title_connected:
		title.state_entered.connect(GameFlow._on_title_entered)
	UIManager.close_all()
	get_tree().paused = false
	_field_scene.free()
	assert_bool(SaveGame.restore_runtime_state(_snapshot)).is_true()
	SkillCheck.random_number_generator.seed = _rng_seed
	SkillCheck.random_number_generator.state = _rng_state


func _enter_active() -> void:
	GameFlow.set_editor_open(false)
	if _active("Paused"):
		GameFlow.chart.set_expression_property(&"resume_to_battle", false)
		GameFlow.send_event(&"resume")
	if _active("Battle"):
		GameFlow.send_event(&"battle_end")
	if _active("ChapterComplete"):
		GameFlow.send_event(&"continue_exploring")
	GameFlow.send_event(&"boot_done")
	GameFlow.send_event(&"new_game")
	GameFlow.send_event(&"intro_done")
	GameFlow.send_event(&"level_ready")
	await get_tree().process_frame
	assert_bool(_active("Active")).is_true()


func _active(state: String) -> bool:
	return bool(GameFlow.get_node(PLAYING + state).get("active"))


func _open() -> WeftluminShell:
	WeftluminBootstrap.open()
	return WeftluminBootstrap.get_child(0) as WeftluminShell


func test_open_pauses_through_chart_without_a_pause_menu_and_close_resumes() -> void:
	var shell := _open()
	assert_bool(_active("Paused")).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool(bool(GameFlow.chart.get_expression_property(&"editor_open"))).is_true()
	assert_array(UIManager._stack).is_empty()
	GameFlow.send_event(&"pause")
	assert_array(UIManager._stack).is_empty()
	assert_bool((_transition("Active/ToPaused")).evaluate_guard()).is_false()
	assert_bool((_transition("Battle/ToPaused")).evaluate_guard()).is_false()
	shell.close()
	await get_tree().process_frame
	assert_bool(_active("Active")).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_bool(bool(GameFlow.chart.get_expression_property(&"editor_open"))).is_false()
	assert_int(WeftluminBootstrap.get_child_count()).is_equal(0)


func test_travel_refusal_preserves_destination_spawn_and_clock() -> void:
	_open()
	var target: String = GameFlow._target_scene
	var spawn: StringName = SaveGame.pending_spawn_id
	var position_pending: bool = SaveGame.has_pending_player_position
	var clock_before: Dictionary = WorldClock.to_dict().duplicate(true)
	assert_bool(GameFlow.travel(GameFlow.TOWN_SCENE, &"editor-must-not-stage")).is_false()
	assert_bool(GameFlow.load_destination(LoadDestination.new(&"dom", &"default"))).is_false()
	GameFlow.send_event(&"travel")
	assert_bool(_active("Paused")).is_true()
	assert_bool(_transition("Active/ToLoading").evaluate_guard()).is_false()
	assert_str(GameFlow._target_scene).is_equal(target)
	assert_str(String(SaveGame.pending_spawn_id)).is_equal(String(spawn))
	assert_bool(SaveGame.has_pending_player_position).is_equal(position_pending)
	assert_dict(WorldClock.to_dict()).is_equal(clock_before)


func test_enter_battle_guard_refuses_editor_even_on_a_combat_field() -> void:
	_open()
	GameFlow.send_event(&"enter_battle")
	assert_bool(bool(GameFlow.chart.get_expression_property(&"can_fight_here"))).is_true()
	assert_bool(_transition("Active/ToBattle").evaluate_guard()).is_false()
	assert_bool(_active("Battle")).is_false()
	assert_array(UIManager._stack).is_empty()


func test_loading_entry_closes_editor_and_restores_camera_and_pause() -> void:
	var player_camera := _field.player().get_node("Camera2D") as Camera2D
	player_camera.make_current()
	_open()
	# Exercise actual Loading entry through the save/new-game path, independent of travel.
	GameFlow.send_event(&"to_main_menu")
	GameFlow.send_event(&"new_game")
	await get_tree().process_frame
	assert_bool(_active("Loading")).is_true()
	assert_int(WeftluminBootstrap.get_child_count()).is_equal(0)
	assert_bool(bool(GameFlow.chart.get_expression_property(&"editor_open"))).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_object(get_viewport().get_camera_2d()).is_same(player_camera)


func test_preexisting_pause_is_preserved() -> void:
	GameFlow.send_event(&"pause")
	var count_before := UIManager._stack.size()
	_open().close()
	await get_tree().process_frame
	assert_bool(_active("Paused")).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(UIManager._stack.size()).is_equal(count_before)


func test_editor_round_trip_preserves_running_battle() -> void:
	var hostile := _field_scene.get_node("BogWight") as Hostile
	var result: Dictionary = Battle.start_session(_field, hostile)
	assert_bool(bool(result.get("allowed", false))).is_true()
	GameFlow.send_event(&"enter_battle")
	var controller: CombatController = Battle.controller
	var depth: int = MusicDirector.get_context_stack().size()
	var shell := _open()
	assert_bool(shell.production_owner_live()).is_true()
	assert_bool(_active("Paused")).is_true()
	shell.close()
	await get_tree().process_frame
	assert_bool(_active("Battle")).is_true()
	assert_bool(Battle.session_active).is_true()
	assert_object(Battle.controller).is_same(controller)
	assert_bool(get_tree().paused).is_false()
	assert_int(MusicDirector.get_context_stack().size()).is_equal(depth)


func test_shell_has_one_themed_root_and_required_docks() -> void:
	var shell := _open()
	await get_tree().process_frame
	assert_int(shell.layer).is_equal(1000)
	assert_int(shell.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_int(shell.get_child_count()).is_equal(1)
	assert_object(shell.root.theme).is_same(shell.adapter.theme())
	assert_vector(shell.root.size).is_equal(get_viewport().get_visible_rect().size)
	assert_int(shell.bottom_tabs.get_tab_count()).is_equal(4)
	assert_object(shell.root.find_child("TreePalette", true, false)).is_not_null()
	assert_object(shell.root.find_child("Inspector", true, false)).is_not_null()
	assert_object(shell.viewport_surface).is_not_null()
	assert_float(shell.viewport_surface.size.x).is_greater(0.0)
	assert_float(shell.viewport_surface.size.y).is_greater(shell.bottom_tabs.size.y)
	for base: String in [
		"Tree", "TabContainer", "SplitContainer", "SpinBox", "OptionButton",
		"CheckBox", "TextEdit", "PopupMenu",
	]:
		assert_str(shell.root.theme.get_type_variation_base("Editor" + base)).is_equal(base)


func test_free_camera_ignores_player_limits_and_restores_on_close() -> void:
	var previous := _field.player().get_node("Camera2D") as Camera2D
	previous.make_current()
	previous.force_update_scroll()
	var old_position := previous.position
	var old_zoom := previous.zoom
	var old_limit := previous.limit_right
	var shell := _open()
	assert_object(get_viewport().get_camera_2d()).is_same(shell.camera)
	shell.camera.position = Vector2(old_limit + 10000.0, 10000.0)
	shell.camera.force_update_scroll()
	assert_float(shell.camera.get_screen_center_position().x).is_greater(float(old_limit))
	shell.close()
	await get_tree().process_frame
	assert_object(get_viewport().get_camera_2d()).is_same(previous)
	assert_vector(previous.position).is_equal(old_position)
	assert_vector(previous.zoom).is_equal(old_zoom)
	assert_int(previous.limit_right).is_equal(old_limit)


func test_input_is_consumed_and_toggle_closes_while_paused() -> void:
	var shell := _open()
	var inventory := InputEventKey.new()
	inventory.physical_keycode = KEY_I
	inventory.pressed = true
	get_viewport().push_input(inventory)
	assert_bool(get_viewport().is_input_handled()).is_true()
	assert_array(UIManager._stack).is_empty()
	var pan := InputEventMouseButton.new()
	pan.button_index = MOUSE_BUTTON_MIDDLE
	pan.pressed = true
	shell.viewport_surface.gui_input.emit(pan)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80, 40)
	var before := shell.camera.position
	shell.viewport_surface.gui_input.emit(motion)
	assert_vector(shell.camera.position).is_not_equal(before)
	# Releasing over chrome must stop a drag before the pointer returns to the viewport.
	pan.pressed = false
	get_viewport().push_input(pan)
	before = shell.camera.position
	shell.viewport_surface.gui_input.emit(motion)
	assert_vector(shell.camera.position).is_equal(before)
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_F12
	toggle.pressed = true
	get_viewport().push_input(toggle)
	await get_tree().process_frame
	assert_int(WeftluminBootstrap.get_child_count()).is_equal(0)
	assert_bool(get_tree().paused).is_false()


func test_bootstrap_disable_releases_shell_and_host_connections() -> void:
	_open()
	WeftluminBootstrap.force_enabled_for_tests = false
	assert_int(WeftluminBootstrap.get_child_count()).is_equal(0)
	assert_bool(get_tree().paused).is_false()
	var loading: Node = GameFlow.get_node(PLAYING + "Loading")
	for connection: Dictionary in loading.state_entered.get_connections():
		var callback: Callable = connection["callable"]
		assert_bool(callback.get_object() is WeftluminShell).is_false()


func test_sandbox_panel_restores_before_returning_to_authoring() -> void:
	var shell := _open()
	var replay := WeftluminPanel.new()
	replay.needs_sandbox = true
	shell.root.add_child(replay)
	var before: Dictionary = GameState.to_dict().duplicate(true)
	assert_bool(shell.activate_panel(replay)).is_true()
	GameState.set_flag("weftlumin-transient", true)
	var authoring := shell.bottom_tabs.get_tab_control(0) as WeftluminPanel
	assert_bool(shell.activate_panel(authoring)).is_true()
	assert_bool(WeftluminSandbox.shared().is_armed()).is_false()
	assert_dict(GameState.to_dict()).is_equal(before)


func test_abandon_ends_session_without_production_outcome_and_is_idempotent() -> void:
	var hostile := _field_scene.get_node("BogWight") as Hostile
	var result: Dictionary = Battle.start_session(_field, hostile)
	assert_bool(bool(result.get("allowed", false))).is_true()
	var retired_controller: CombatController = Battle.controller
	var game_before: Dictionary = GameState.to_dict().duplicate(true)
	var reputation_before: Dictionary = Reputation.to_dict().duplicate(true)
	var renown_before: Dictionary = Renown.to_dict().duplicate(true)
	var pending_before: String = SaveGame._pending_autosave_reason
	var outcomes: Array[BattleResult] = []
	var endings: Array[BattleResult] = []
	var on_outcome := func(outcome: BattleResult) -> void: outcomes.append(outcome)
	var on_session := func(outcome: BattleResult) -> void: endings.append(outcome)
	Battle.battle_ended.connect(on_outcome)
	Battle.session_ended.connect(on_session)
	Battle.abandon()
	Battle.abandon()
	retired_controller.force_finish(CombatController.ResultState.VICTORY, &"slain")
	Battle.battle_ended.disconnect(on_outcome)
	Battle.session_ended.disconnect(on_session)
	assert_bool(Battle.session_active).is_false()
	assert_bool(Battle.ended).is_true()
	assert_object(Battle.controller).is_null()
	assert_object(Battle.last_result).is_null()
	assert_array(Battle.allies).is_empty()
	assert_array(Battle.enemies).is_empty()
	assert_array(outcomes).is_empty()
	assert_int(endings.size()).is_equal(1)
	assert_int(hostile.state).is_equal(Hostile.State.IDLE)
	assert_bool(_field.hostile_alerted.is_connected(Battle._on_field_hostile_alerted)).is_false()
	assert_bool(_field.tree_exiting.is_connected(Battle._on_session_field_exiting)).is_false()
	assert_dict(GameState.to_dict()).is_equal(game_before)
	assert_dict(Reputation.to_dict()).is_equal(reputation_before)
	assert_dict(Renown.to_dict()).is_equal(renown_before)
	assert_str(SaveGame._pending_autosave_reason).is_equal(pending_before)
	assert_bool(bool(Battle.start_session(_field, hostile).get("allowed", false))).is_true()


func test_field_hud_hides_while_editing_and_restores_on_close() -> void:
	var hud: CanvasLayer = null
	for node: Node in _field_scene.find_children("*", "CanvasLayer", true, false):
		if node.scene_file_path == FieldMap.FIELD_HUD_SCENE:
			hud = node as CanvasLayer
	assert_object(hud).is_not_null()
	assert_bool(hud.visible).is_true()
	var shell := _open()
	assert_bool(hud.visible).override_failure_message(
		"the field hotkey bar must not draw through the editor dock"
	).is_false()
	shell.close()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(hud.visible).is_true()


func test_shell_sources_never_assign_scene_tree_pause() -> void:
	var pattern := RegEx.new()
	assert_int(pattern.compile("\\.paused\\s*=")).is_equal(OK)
	for filename: String in DirAccess.get_files_at("res://addons/weftlumin/shell"):
		if filename.ends_with(".gd"):
			var source := FileAccess.get_file_as_string("res://addons/weftlumin/shell/" + filename)
			assert_object(pattern.search(source)).override_failure_message(filename).is_null()


func test_rendered_dock_pointer_zoom_and_close() -> void:
	var capture_dir := OS.get_environment("SOUL_METER_WEFTLUMIN_CAPTURE_DIR")
	if capture_dir.is_empty():
		return
	assert_str(DisplayServer.get_name()).is_not_equal("headless")
	if DisplayServer.get_name() == "headless":
		return
	var current := get_tree().current_scene as CanvasItem
	var visible_before := current.visible if current != null else false
	if current != null:
		current.hide()
	(_field.player().get_node("Camera2D") as Camera2D).make_current()
	var shell := _open()
	await get_tree().create_timer(0.3).timeout
	var wheel := InputEventMouseButton.new()
	wheel.position = shell.viewport_surface.get_global_rect().get_center()
	wheel.global_position = wheel.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var zoom_before := shell.camera.zoom.x
	get_viewport().push_input(wheel)
	assert_float(shell.camera.zoom.x).is_greater(zoom_before)
	# A real wheel notch is a press AND a release. Without the release the GUI keeps mouse focus
	# on the viewport surface and routes every later click there instead of the Close button.
	var wheel_up := wheel.duplicate() as InputEventMouseButton
	wheel_up.pressed = false
	get_viewport().push_input(wheel_up)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(DirAccess.make_dir_recursive_absolute(capture_dir)).is_equal(OK)
	assert_int(get_viewport().get_texture().get_image().save_png(
		capture_dir.path_join("weftlumin-shell.png")
	)).is_equal(OK)
	var button := shell.root.find_child("Close", true, false) as Button
	var pressed_count: Array[int] = [0]
	button.pressed.connect(func() -> void: pressed_count[0] += 1)
	# Move the pointer onto the button first: the GUI only routes a click to the control the
	# viewport believes is under the mouse.
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	get_viewport().push_input(motion)
	for pressed: bool in [true, false]:
		# A fresh event per edge: push_input keeps the instance, so mutating one shared event
		# turns the press into a release before the button sees it.
		var click := InputEventMouseButton.new()
		click.position = motion.position
		click.global_position = motion.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.pressed = pressed
		get_viewport().push_input(click)
	assert_int(pressed_count[0]).override_failure_message("Close click never reached the button").is_equal(1)
	# close() defers the bootstrap release, which then frees the shell: two frames.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(WeftluminBootstrap.get_child_count()).is_equal(0)
	if current != null:
		current.visible = visible_before


func _transition(path: String) -> Transition:
	return GameFlow.get_node(PLAYING + path) as Transition
