extends GdUnitTestSuite

const BUILDING_DOOR_SCENE := preload("res://actors/building_door/building_door.tscn")
const ACTIVE_STATE_PATH := "StateChart/Root/Playing/Active"
const LOADING_STATE_PATH := "StateChart/Root/Playing/Loading"
const PAUSED_STATE_PATH := "StateChart/Root/Playing/Paused"
const TITLE_STATE_PATH := "StateChart/Root/Menus/Title"

var _loading_handler_was_connected := false
var _reputation_before: Dictionary
var _target_scene_before := ""
var _target_spawn_before: StringName = &"default"
var _world_clock_before: Dictionary
var _pending_spawn_before: StringName = &"default"
var _pending_position_flag_before := false


func before_test() -> void:
	_reputation_before = Reputation.to_dict()
	_world_clock_before = WorldClock.to_dict()
	_target_scene_before = GameFlow._target_scene
	_target_spawn_before = GameFlow._target_spawn_id
	_pending_spawn_before = SaveGame.pending_spawn_id
	_pending_position_flag_before = SaveGame.has_pending_player_position
	var loading_state := GameFlow.get_node(LOADING_STATE_PATH)
	_loading_handler_was_connected = loading_state.state_entered.is_connected(
		GameFlow._on_loading_entered
	)
	if _loading_handler_was_connected:
		loading_state.state_entered.disconnect(GameFlow._on_loading_entered)
	await _enter_active_state()
	Reputation.from_dict({})
	# from_dict() restores standings without emitting reputation_changed, so the
	# chart's derived guard properties must be refreshed explicitly.
	GameFlow._sync_reputation_guards()
	GameFlow.chart.set_expression_property(&"rep_iron_companies", 0.0)


func after_test() -> void:
	await _return_to_title()
	var loading_state := GameFlow.get_node(LOADING_STATE_PATH)
	if (
		_loading_handler_was_connected
		and not loading_state.state_entered.is_connected(GameFlow._on_loading_entered)
	):
		loading_state.state_entered.connect(GameFlow._on_loading_entered)
	Reputation.from_dict(_reputation_before)
	GameFlow._sync_reputation_guards()
	GameFlow.chart.set_expression_property(
		&"rep_iron_companies", Reputation.standing("iron-companies")
	)
	WorldClock.from_dict(_world_clock_before)
	GameFlow._target_scene = _target_scene_before
	GameFlow._target_spawn_id = _target_spawn_before
	SaveGame.pending_spawn_id = _pending_spawn_before
	SaveGame.has_pending_player_position = _pending_position_flag_before


func test_garrison_area_access_is_decided_by_the_reputation_chart_guard() -> void:
	var door := auto_free(BUILDING_DOOR_SCENE.instantiate()) as BuildingDoor
	door.transition_id = GameFlow.GARRISON_YARD_TRANSITION_ID
	add_child(door)
	door._player_in_range = true
	var target_before := GameFlow._target_scene
	var refused: bool = door._try_travel()
	assert_bool(refused).is_false()
	assert_bool(_state_is_active(ACTIVE_STATE_PATH)).is_true()
	assert_str(GameFlow._target_scene).is_equal(target_before)
	assert_str(door._prompt.text).is_equal(
		"LOCKED — Earn warm standing with the Iron Companies to enter."
	)

	# Derived, never copied: a rebalance of BAND_WARM must move this test with
	# it rather than leaving it asserting a threshold that no longer exists.
	Reputation.record("player", "iron-companies", Reputation.BAND_WARM, "test gate", "test")
	assert_float(
		float(GameFlow.chart.get_expression_property(&"rep_iron_companies", -1.0))
	).is_equal_approx(Reputation.BAND_WARM, 0.001)
	var accepted: bool = door._try_travel()
	assert_bool(accepted).is_true()
	assert_bool(_state_is_active(LOADING_STATE_PATH)).is_true()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.GARRISON_YARD_SCENE)
	assert_str(String(GameFlow._target_spawn_id)).is_equal("entry")


func test_area_access_is_refused_from_a_gameplay_state_that_is_not_active() -> void:
	# Gate r3 finding 3: "not Active" is not the same as "detached". Paused,
	# Loading, Battle and Deployment are all real gameplay states, and an
	# allowed request in one of them would rewrite _target_scene and SaveGame's
	# pending spawn while a load may already be in flight.
	Reputation.record("player", "iron-companies", Reputation.BAND_ALLIED, "test", "test")
	var transition := BuildingTransitionRegistry.by_id(
		GameFlow.GARRISON_YARD_TRANSITION_ID
	)
	assert_bool(
		Reputation.band_at_least(
			transition.reputation_faction, transition.minimum_reputation_band
		)
	).is_true()

	GameFlow.send_event(&"pause")
	await get_tree().process_frame
	assert_bool(_state_is_active(PAUSED_STATE_PATH)).is_true()

	var target_before := GameFlow._target_scene
	var spawn_before := SaveGame.pending_spawn_id
	var accepted: bool = GameFlow.request_area_access(
		GameFlow.GARRISON_YARD_TRANSITION_ID, GameFlow.GARRISON_YARD_SCENE, &"entry"
	)
	assert_bool(accepted) \
		.override_failure_message(
			"Travel is an Active-only behaviour; a paused request must not be granted"
		) \
		.is_false()
	assert_str(GameFlow._target_scene).is_equal(target_before)
	assert_str(String(SaveGame.pending_spawn_id)).is_equal(String(spawn_before))
	assert_str(GameFlow._pending_area_scene) \
		.override_failure_message("A refused request must not leave a destination staged") \
		.is_empty()


func test_the_chart_guard_carries_no_copy_of_the_authored_gate_data() -> void:
	# The chart owns the DECISION; the .tres owns the DATA. A guard expression
	# containing a threshold literal (the original `rep_iron_companies >= 15.0`)
	# duplicates both the authored minimum_reputation_band and Reputation's band
	# thresholds, so either could be rebalanced without moving the gate.
	var guard: ExpressionGuard = (
		GameFlow.get_node("StateChart/Root/Playing/Active/ToGarrisonLoading").guard
	)
	assert_str(guard.expression) \
		.override_failure_message(
			"The area-access guard must read a derived boolean, not a threshold literal"
		) \
		.is_equal("garrison_access_granted")

	# And the derived property must track the AUTHORED band across the whole
	# scale, not a number that merely happens to agree with it today.
	var transition := BuildingTransitionRegistry.by_id(
		GameFlow.GARRISON_YARD_TRANSITION_ID
	)
	assert_object(transition).is_not_null()
	# Boundary values derived from the authoritative thresholds, so a rebalance
	# keeps sweeping the real band edges instead of stale numbers.
	var sweep: Array[float] = [
		Reputation.BAND_HOSTILE - 10.0,
		Reputation.BAND_COLD - 5.0,
		0.0,
		Reputation.BAND_WARM - 0.1,
		Reputation.BAND_WARM,
		Reputation.BAND_ALLIED + 1.0,
	]
	for standing: float in sweep:
		Reputation.from_dict({})
		Reputation.record("player", transition.reputation_faction, standing, "sweep", "test")
		var expected := Reputation.band_at_least(
			transition.reputation_faction, transition.minimum_reputation_band
		)
		assert_bool(
			bool(GameFlow.chart.get_expression_property(&"garrison_access_granted", false))
		) \
			.override_failure_message(
				"garrison_access_granted disagreed with the authored band at standing %f"
				% standing
			) \
			.is_equal(expected)


func _enter_active_state() -> void:
	if _state_is_active(ACTIVE_STATE_PATH):
		return
	if _state_is_active(PAUSED_STATE_PATH):
		GameFlow.send_event(&"resume")
		await get_tree().process_frame
		return
	if _state_is_active(TITLE_STATE_PATH):
		GameFlow.send_event(&"new_game")
		await get_tree().process_frame
	if _state_is_active(LOADING_STATE_PATH):
		GameFlow.send_event(&"level_ready")
		await get_tree().process_frame


func _return_to_title() -> void:
	if _state_is_active(LOADING_STATE_PATH):
		GameFlow.send_event(&"level_ready")
		await get_tree().process_frame
	if _state_is_active(ACTIVE_STATE_PATH):
		GameFlow.send_event(&"pause")
		await get_tree().process_frame
	if _state_is_active(PAUSED_STATE_PATH):
		GameFlow.send_event(&"to_main_menu")
		await get_tree().process_frame


func _state_is_active(path: String) -> bool:
	var state := GameFlow.get_node_or_null(path)
	return state != null and bool(state.get("active"))
