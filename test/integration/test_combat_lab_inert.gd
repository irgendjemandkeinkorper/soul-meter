extends GdUnitTestSuite

const FIELD_SCENE := preload("res://world/test_room.tscn")

var _game_state_before: Dictionary
var _reputation_before: Dictionary
var _renown_before: Dictionary
var _export_root: String
var _field_scene: Node2D


func before_test() -> void:
	_field_scene = FIELD_SCENE.instantiate() as Node2D
	add_child(_field_scene)
	_game_state_before = GameState.to_dict().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)
	_export_root = ProjectSettings.globalize_path("user://combat_lab")
	var singleton: Node = get_node_or_null("/root/CombatLab")
	if singleton != null:
		singleton.call("close_overlay")
		singleton.call("stop_test_session")
		singleton.set("force_enabled_for_tests", false)
	var recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if recorder != null:
		recorder.set("force_enabled_for_tests", false)
		recorder.set("session_root_override", "")
	# The F3 case asserts the lab OPENS, and the lab refuses to open over a live
	# production battle by contract. Scoped, this suite passes because nothing
	# started one; in a full run an earlier suite leaves one behind and F3
	# correctly refuses. State the precondition rather than inherit it from run
	# order — a suite that only passes in one ordering is not passing.
	Battle.controller = null
	Battle.ended = true
	get_tree().paused = false


func after_test() -> void:
	var singleton: Node = get_node_or_null("/root/CombatLab")
	if singleton != null:
		singleton.call("close_overlay")
		singleton.call("stop_test_session")
		singleton.set("force_enabled_for_tests", false)
	var recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if recorder != null:
		recorder.set("force_enabled_for_tests", false)
		recorder.set("session_root_override", "")
	var restored: bool = GameState.from_dict(_game_state_before)
	assert_bool(restored).is_true()
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)
	get_tree().paused = false
	_field_scene.free()
	_field_scene = null


func test_disabled_autoload_has_no_children_connections_input_or_files() -> void:
	var singleton: Node = get_node_or_null("/root/CombatLab")
	assert_object(singleton).is_not_null()
	if singleton == null:
		return

	assert_int(singleton.get_child_count()).is_equal(0)
	assert_bool(singleton.is_processing_unhandled_key_input()).is_false()
	assert_bool(Battle.combat_event.is_connected(Callable(singleton, "_on_combat_event"))).is_false()
	assert_bool(Battle.turn_resolved.is_connected(Callable(singleton, "_on_turn_resolved"))).is_false()
	assert_bool(Battle.balance_changed.is_connected(Callable(singleton, "_on_balance_changed"))).is_false()
	assert_bool(Battle.battle_ended.is_connected(Callable(singleton, "_on_battle_ended"))).is_false()
	assert_bool(DirAccess.dir_exists_absolute(_export_root)).is_false()


func test_forced_enablement_f3_toggles_setup_and_restores_pause_state() -> void:
	var singleton: Node = get_node_or_null("/root/CombatLab")
	assert_object(singleton).is_not_null()
	if singleton == null:
		return
	singleton.set("force_enabled_for_tests", true)
	await get_tree().process_frame

	_push_f3(singleton.get_viewport())
	await get_tree().process_frame

	assert_bool(get_tree().paused).is_true()
	assert_int(singleton.get_child_count()).is_equal(1)
	assert_object(singleton.find_child("CombatLabOverlay", true, false)).is_not_null()

	_push_f3(singleton.get_viewport())
	await get_tree().process_frame

	assert_bool(get_tree().paused).is_false()
	assert_int(singleton.get_child_count()).is_equal(0)


func test_forced_session_applies_runtime_overrides_and_builds_the_inspector() -> void:
	var singleton: Node = get_node_or_null("/root/CombatLab")
	assert_object(singleton).is_not_null()
	if singleton == null:
		return
	singleton.set("force_enabled_for_tests", true)
	await get_tree().process_frame

	singleton.call("start_test_session", _test_setup())
	await get_tree().process_frame

	assert_object(Battle.controller).is_not_null()
	assert_str(String(Battle.controller.weather.element_id)).is_equal("strom")
	var tile := Battle.controller.tile_state_at(Vector2i.ZERO)
	assert_object(tile).is_not_null()
	if tile != null:
		assert_str(String(tile.charge_element_id)).is_equal("molm")
		assert_int(tile.charge_level).is_equal(2)
	assert_object(singleton.find_child("InspectorDock", true, false)).is_not_null()
	assert_bool(Battle.combat_event.is_connected(Callable(singleton, "_on_combat_event"))).is_true()
	get_tree().paused = true
	singleton.call("close_overlay")
	assert_bool(get_tree().paused).is_true()


func test_enabled_playtest_recorder_records_one_lab_start_event() -> void:
	var singleton: Node = get_node_or_null("/root/CombatLab")
	var recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	assert_object(singleton).is_not_null()
	assert_object(recorder).is_not_null()
	if singleton == null or recorder == null:
		return
	var base := OS.get_environment("SOUL_METER_TEST_DATA_DIR")
	recorder.set("session_root_override", base.path_join("combat_lab_recorder"))
	recorder.set("force_enabled_for_tests", true)
	singleton.set("force_enabled_for_tests", true)
	await get_tree().process_frame

	singleton.call("start_test_session", _test_setup())
	await get_tree().process_frame

	var events_value: Variant = recorder.get("_events")
	var matching := 0
	if events_value is Array:
		for event_value: Variant in events_value:
			if event_value is Dictionary and str(event_value.get("type", "")) == "combat_lab_battle_started":
				matching += 1
	assert_int(matching).is_equal(1)


func _test_setup() -> Dictionary:
	var party_ids: Array[StringName] = []
	for member: PartyMember in GameState.party:
		party_ids.append(StringName(member.id))
	return {
		"encounter_id": EncounterIds.BOG_WIGHT,
		"party_ids": party_ids,
		"weather_override_enabled": true,
		"weather_override": &"strom",
		"tile_seed": {"cell": Vector2i.ZERO, "element_id": &"molm", "charge": 2},
		"seed": 1234,
	}


func _push_f3(viewport: Viewport) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F3
	viewport.push_input(event, true)
