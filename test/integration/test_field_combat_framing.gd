extends GdUnitTestSuite
## Owner 2026-11-01, combat presentation: the Lower Trial Hall warden fight runs on the field
## map with the map full-screen. The field HUD stays up and its one bar grows the combat parts;
## the only top chrome is the thin turn-order strip; the field camera keeps its room limits
## and zoom and pans to whoever acts; on combat end the bar retracts and the camera returns.

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	get_tree().root.size = Vector2i(1920, 1080)


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	UIManager.close_all()
	GameState.from_dict(_saved_state)


func test_trial_warden_fight_keeps_the_field_hud_and_grows_its_one_bar() -> void:
	GameState.flags.clear()
	if GameState.party.is_empty():
		GameState._seed_demo_data()
	var runner := scene_runner(GameFlow.TRIAL_SCENE)
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	var field := root.find_child("FieldMap", true, false) as FieldMap
	var player := field.player()
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()
	var room_limits := [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]
	var room_zoom := camera.zoom
	var hud := field.field_hud()
	assert_object(hud).is_not_null()
	var bar := hud.bar()
	assert_float(bar.size.y).is_equal_approx(FieldHUD.EXPLORE_BAR_HEIGHT, 1.0)
	assert_bool(hud.combat_active()).is_false()

	root.call("request_warden_encounter")
	await runner.simulate_frames(2)
	assert_bool(Battle.session_active).is_true()
	UIManager.close_all()
	GameFlow._on_battle_entered()
	await runner.simulate_frames(60, 16)

	# 1. One bar, both modes: no full-screen HUD layer, the field HUD visible, its bar grown.
	assert_int(UIManager._stack.size()).override_failure_message(
		"combat must not open a full-screen HUD layer over a live field"
	).is_equal(0)
	assert_bool(hud.visible).is_true()
	assert_bool(hud.combat_active()).is_true()
	assert_float(bar.size.y).is_equal_approx(FieldHUD.COMBAT_BAR_HEIGHT, 1.0)
	var combat_bar := hud.combat_bar
	assert_object(combat_bar).is_not_null()
	assert_bool(combat_bar.is_visible_in_tree()).is_true()
	assert_object(combat_bar.get_parent()).is_same(bar)
	assert_bool(bar.get_global_rect().encloses(combat_bar.get_global_rect())).is_true()
	assert_object(bar.find_child("SoulGauge", true, false)).is_not_null()
	for part: String in ["ActiveUnitPlate", "MessageLog", "Actions", "PartyRows", "EndTurnButton", "WithdrawButton", "BreakdownButton"]:
		var node := combat_bar.find_child(part, true, false) as CanvasItem
		assert_object(node).override_failure_message("the bar lost its %s" % part).is_not_null()
		assert_bool(node.is_visible_in_tree()).override_failure_message("%s hidden" % part).is_true()
	var labels := PackedStringArray()
	for button: Button in combat_bar.get("_action_buttons"):
		labels.append(button.text)
	assert_str("\n".join(labels)).contains("STRIKE")
	assert_str("\n".join(labels)).contains("GUARD")
	assert_int(combat_bar.log_lines().size()).override_failure_message(
		"entering combat writes one cue line to the message window"
	).is_greater_equal(1)
	assert_str(combat_bar.log_lines()[0]).is_equal("COMBAT BEGINS")

	# The map stays full-screen: nothing docks left or right, and the only top chrome is the
	# thin turn strip. No visible panel covers the open window between strip and bar.
	var interface := hud.battle_interface
	assert_object(interface).is_not_null()
	var viewport := get_tree().root.get_visible_rect()
	var strip := interface.turn_strip
	assert_bool(strip.is_visible_in_tree()).is_true()
	assert_float(strip.size.y).override_failure_message("the turn strip must stay thin").is_less(80.0)
	assert_float(strip.global_position.y).is_equal_approx(0.0, 1.0)
	assert_float(strip.size.x).is_less(viewport.size.x * 0.6)
	assert_bool(interface.breakdown_visible()).is_false()
	var open_window := interface.stage.open_window()
	assert_float(open_window.size.y).is_greater(viewport.size.y - strip.size.y - bar.size.y - 2.0)
	assert_float(open_window.size.x).is_equal_approx(viewport.size.x, 1.0)
	for panel: Node in hud.find_children("*", "PanelContainer", true, false):
		var control := panel as Control
		if not control.is_visible_in_tree() or bar.is_ancestor_of(control) or strip.is_ancestor_of(control):
			continue
		assert_bool(control.get_global_rect().intersects(open_window)).override_failure_message(
			"%s (%s) covers the map at %s" % [control.name, control.get_path(), control.get_global_rect()]
		).is_false()
	assert_bool((root.get_node("EntranceInstruction") as CanvasItem).visible).is_false()

	# 3. Field camera: no reframing, no stage window, no zoom change, no room-limit lifting.
	assert_array([camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]) \
		.is_equal(room_limits)
	assert_vector(camera.zoom).is_equal(room_zoom)
	var combatants: Array[Node2D] = [player]
	for body: Hostile in Battle._spawned_hostiles:
		combatants.append(body)
	assert_int(combatants.size()).is_greater(1)
	# The acting enemy is in the open window on its presented turn (D9 pan rules keep applying).
	var hostiles_by_id: Dictionary = {}
	for body: Hostile in Battle._spawned_hostiles:
		if body.battle_actor() != null:
			hostiles_by_id[body.battle_actor().combat_id] = body
	if Battle.controller.state == CombatController.State.ALLY_TURN:
		Battle.end_turn()
	var enemy_turns_seen := 0
	for _frame: int in 90:
		await runner.simulate_frames(1, 16)
		var presented := interface.stage.presented_event()
		if presented == null:
			continue
		var acting_id := StringName(str((presented.data.get("snapshot", {}) as Dictionary).get("active_actor_id", "")))
		if not hostiles_by_id.has(acting_id) or interface.stage.is_presenting_beats():
			continue
		enemy_turns_seen += 1
		var body := hostiles_by_id[acting_id] as Node2D
		var on_screen := body.get_global_transform_with_canvas().origin
		assert_bool(open_window.has_point(on_screen)).override_failure_message(
			"acting enemy %s drawn at %s, outside the open window %s" % [body.name, on_screen, open_window]
		).is_true()
	# The pan rule itself is pinned by test/unit/test_combat_overlay.gd; this run only checks
	# the settled enemy turns it happened to present.
	print("FRAMING enemy turns checked against the open window: ", enemy_turns_seen)
	assert_array([camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]) \
		.is_equal(room_limits)

	# Combat end retracts the combat parts and hands the camera back.
	GameFlow._on_battle_exited()
	Battle._end_session(null)
	await runner.simulate_frames(30, 16)
	assert_bool(hud.combat_active()).is_false()
	assert_bool(hud.visible).is_true()
	assert_float(bar.size.y).is_equal_approx(FieldHUD.EXPLORE_BAR_HEIGHT, 1.0)
	assert_object(hud.combat_bar).is_null()
	assert_object(hud.find_child("BattleInterface", true, false)).is_null()
	assert_object(bar.find_child("CombatBar", true, false)).is_null()
	assert_object(field.combat_overlay()).is_null()
	assert_array([camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]) \
		.is_equal(room_limits)
	assert_vector(camera.zoom).is_equal(room_zoom)
	assert_vector(camera.offset).is_equal(Vector2.ZERO)
