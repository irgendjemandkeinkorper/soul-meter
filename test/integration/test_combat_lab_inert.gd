extends GdUnitTestSuite
## Release inertness for the combat lab after E2.5b (#337): the legacy autoload and its F3
## overlay are gone; the encounter sandbox lives only in the export-excluded Weftlumin model and
## stays undrivable until a panel hosts it.

const FIELD_SCENE := preload("res://world/test_room.tscn")
const CombatLabScript := preload("res://weftlumin/panels/models/combat_lab.gd")
const Release := preload("res://test/helpers/weftlumin_tool_release.gd")

var _game_state_before: Dictionary
var _reputation_before: Dictionary
var _renown_before: Dictionary
var _export_root: String
var _field_scene: Node2D
var _lab: Node = null


func before_test() -> void:
	_field_scene = FIELD_SCENE.instantiate() as Node2D
	add_child(_field_scene)
	_game_state_before = GameState.to_dict().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)
	_export_root = ProjectSettings.globalize_path("user://combat_lab")
	_lab = CombatLabScript.new() as Node
	add_child(_lab)
	var recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if recorder != null:
		recorder.set("force_enabled_for_tests", false)
		recorder.set("session_root_override", "")
	# The lab refuses to start over a live production battle by contract. In a
	# full run an earlier suite can leave one behind; state the precondition
	# rather than inherit it from run order.
	Battle.controller = null
	Battle.ended = true
	get_tree().paused = false


func after_test() -> void:
	if _lab != null:
		_lab.call("stop_test_session")
		_lab.free()
		_lab = null
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


func test_release_build_has_no_combat_lab_autoload_or_shipped_model() -> void:
	assert_bool(Release.autoload_absent(get_tree(), "CombatLab")).is_true()
	assert_bool(
		Release.model_only_in_excluded_home("combat_lab.gd", "res://globals/combat_lab.gd")
	).is_true()
	assert_str(Release.shipped_reference("weftlumin/panels/models/combat_lab.gd")).is_empty()


func test_unhosted_model_has_no_children_connections_input_or_files() -> void:
	_lab.call("start_test_session", _test_setup())
	_lab.call("start_lab_battle", _test_setup())

	assert_bool(bool(_lab.call("is_enabled"))).is_false()
	assert_int(_lab.get_child_count()).is_equal(0)
	assert_bool(_lab.is_processing_unhandled_key_input()).is_false()
	assert_bool(Battle.combat_event.is_connected(Callable(_lab, "_on_combat_event"))).is_false()
	assert_bool(Battle.turn_resolved.is_connected(Callable(_lab, "_on_turn_resolved"))).is_false()
	assert_bool(Battle.balance_changed.is_connected(Callable(_lab, "_on_balance_changed"))).is_false()
	assert_bool(Battle.battle_ended.is_connected(Callable(_lab, "_on_battle_ended"))).is_false()
	assert_object(Battle.controller).is_null()
	assert_bool(DirAccess.dir_exists_absolute(_export_root)).is_false()


func test_hosted_lab_binds_no_hotkey_builds_no_overlay_and_never_pauses() -> void:
	assert_bool(bool(_lab.call("host_in_panel", CombatLabScript.SANDBOX_OWNER))).is_true()
	await get_tree().process_frame

	_push_f3(_lab.get_viewport())
	await get_tree().process_frame

	assert_bool(get_tree().paused).is_false()
	assert_int(_lab.get_child_count()).is_equal(0)
	assert_bool(_lab.is_processing_unhandled_key_input()).is_false()
	assert_bool("TOGGLE_HOTKEY" in (CombatLabScript as Script).get_script_constant_map()).is_false()


func test_hosted_session_applies_runtime_overrides_and_feeds_the_inspector() -> void:
	assert_bool(bool(_lab.call("host_in_panel", CombatLabScript.SANDBOX_OWNER))).is_true()
	var payloads: Array[Dictionary] = []
	_lab.connect("inspector_changed", func(payload: Dictionary) -> void: payloads.append(payload))

	_lab.call("start_test_session", _test_setup())
	await get_tree().process_frame

	assert_object(Battle.controller).is_not_null()
	assert_str(String(Battle.controller.weather.element_id)).is_equal("zhur")
	var tile := Battle.controller.tile_state_at(Vector2i.ZERO)
	assert_object(tile).is_not_null()
	if tile != null:
		assert_str(String(tile.charge_element_id)).is_equal("mozh")
		assert_int(tile.charge_level).is_equal(2)
	assert_bool(payloads.is_empty()).is_false()
	if not payloads.is_empty():
		assert_bool(bool(payloads.back().get("running", false))).is_true()
	assert_bool(Battle.combat_event.is_connected(Callable(_lab, "_on_combat_event"))).is_true()
	assert_int(_lab.get_child_count()).is_equal(0)


func test_enabled_playtest_recorder_records_one_lab_start_event() -> void:
	var recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	assert_object(recorder).is_not_null()
	if recorder == null:
		return
	var base := OS.get_environment("SOUL_METER_TEST_DATA_DIR")
	recorder.set("session_root_override", base.path_join("combat_lab_recorder"))
	recorder.set("force_enabled_for_tests", true)
	assert_bool(bool(_lab.call("host_in_panel", CombatLabScript.SANDBOX_OWNER))).is_true()
	await get_tree().process_frame

	_lab.call("start_test_session", _test_setup())
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
		"weather_override": &"zhur",
		"tile_seed": {"cell": Vector2i.ZERO, "element_id": &"mozh", "charge": 2},
		"seed": 1234,
	}


func _push_f3(viewport: Viewport) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F3
	viewport.push_input(event, true)
