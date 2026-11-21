extends GdUnitTestSuite
## #649: a region-map journey runs under the pause menu, because the map is opened from there.
## These cases drive the chart into Paused the way a player does, then check the edges a
## journey needs. A failed avoid must enter Battle and arrival must enter Loading. A fight
## paused under the menu must refuse journeys. An ambush that cannot be seated must hand back
## the prompt with CANCEL still working.
##
## Loading's scene load is disconnected for the run, as test_reputation_area_access.gd does, so
## entering Loading changes chart state only.

const ACTIVE := "StateChart/Root/Playing/Active"
const PAUSED := "StateChart/Root/Playing/Paused"
const BATTLE := "StateChart/Root/Playing/Battle"
const LOADING := "StateChart/Root/Playing/Loading"
const TITLE := "StateChart/Root/Menus/Title"
const CHARGEN := "StateChart/Root/Menus/CharacterCreation"
const INTRO := "StateChart/Root/Menus/IntroNarration"
const PAUSE_MENU_SCENE := "res://ui/screens/pause_menu.tscn"

var _field_scene: Node2D
var _field: FieldMap
var _game_state_before: Dictionary
var _world_clock_before: Dictionary
var _travel_plan_before: TravelPlan
var _target_scene_before := ""
var _target_spawn_before: StringName = &"default"
var _pending_spawn_before: StringName = &"default"
var _pending_position_flag_before := false
var _save_paths_before: Array[String] = []
var _test_save_paths: Array[String] = []
var _loading_handler_was_connected := false


func before_test() -> void:
	_game_state_before = GameState.to_dict()
	_world_clock_before = WorldClock.to_dict()
	_travel_plan_before = GameFlow.travel_plan
	_target_scene_before = GameFlow._target_scene
	_target_spawn_before = GameFlow._target_spawn_id
	_pending_spawn_before = SaveGame.pending_spawn_id
	_pending_position_flag_before = SaveGame.has_pending_player_position
	_save_paths_before = [SaveGame.save_path, SaveGame.temp_path, SaveGame.backup_path]
	var prefix := OS.get_temp_dir().path_join("soul-meter-journey-pause-%s" % Time.get_ticks_usec())
	SaveGame.save_path = prefix + ".save"
	SaveGame.temp_path = prefix + ".save.tmp"
	SaveGame.backup_path = prefix + ".save.bak"
	_test_save_paths = [SaveGame.save_path, SaveGame.temp_path, SaveGame.backup_path]
	var loading_state := GameFlow.get_node(LOADING)
	_loading_handler_was_connected = loading_state.state_entered.is_connected(
		GameFlow._on_loading_entered
	)
	if _loading_handler_was_connected:
		loading_state.state_entered.disconnect(GameFlow._on_loading_entered)
	_field_scene = (load("res://world/test_room.tscn") as PackedScene).instantiate() as Node2D
	add_child(_field_scene)
	_field = _field_scene.find_child("FieldMap", true, false) as FieldMap
	await _enter_active_state()
	GameFlow.travel_plan = null
	GameState.travel_plan = {}
	GameState.party = [_traveler()]
	GameFlow._sync_battle_guard()


func after_test() -> void:
	await _return_to_title()
	if is_instance_valid(_field_scene):
		_field_scene.free()
	_field_scene = null
	_field = null
	_clear_test_battle()
	var loading_state := GameFlow.get_node(LOADING)
	if (
		_loading_handler_was_connected
		and not loading_state.state_entered.is_connected(GameFlow._on_loading_entered)
	):
		loading_state.state_entered.connect(GameFlow._on_loading_entered)
	for path: String in _test_save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SaveGame.save_path = _save_paths_before[0]
	SaveGame.temp_path = _save_paths_before[1]
	SaveGame.backup_path = _save_paths_before[2]
	GameState.from_dict(_game_state_before)
	WorldClock.from_dict(_world_clock_before)
	GameFlow.travel_plan = _travel_plan_before
	GameFlow._target_scene = _target_scene_before
	GameFlow._target_spawn_id = _target_spawn_before
	SaveGame.pending_spawn_id = _pending_spawn_before
	SaveGame.has_pending_player_position = _pending_position_flag_before
	get_tree().paused = false


func test_failed_avoid_from_the_pause_menu_enters_battle() -> void:
	await _pause()
	_install_plan(_prompt_plan(_seed_for_avoidance(_avoidance_chance(), false)))

	var result: Dictionary = GameFlow.resolve_encounter_prompt(true)
	await get_tree().process_frame

	assert_str(String(result.get("event", ""))).is_equal("battle_started")
	assert_bool(_active(BATTLE)).is_true()
	assert_bool(_active(PAUSED)).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_pause_menu_open()).is_false()
	assert_bool(Battle.session_active).is_true()
	assert_int(int(GameFlow.travel_plan.state)).is_equal(TravelPlan.State.IN_BATTLE)


func test_arrival_from_the_pause_menu_enters_loading_for_the_destination() -> void:
	await _pause()
	var plan := _prompt_plan(19)
	plan.state = TravelPlan.State.EN_ROUTE
	plan.total_steps = 1
	plan.encounter_schedule.clear()
	_install_plan(plan)
	var phases_before := WorldClock.phase_count

	var result: Dictionary = GameFlow.advance_journey()
	await get_tree().process_frame

	assert_str(String(result.get("event", ""))).is_equal("arrived")
	assert_bool(_active(LOADING)).is_true()
	assert_bool(_active(PAUSED)).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.DORTHKOR_SCENE)
	assert_int(WorldClock.phase_count - phases_before).is_equal(3)
	assert_int(int(plan.state)).is_equal(TravelPlan.State.ARRIVED)


func test_a_fight_paused_under_the_menu_refuses_journeys() -> void:
	var hostile := _field_scene.get_node("BogWight") as Hostile
	assert_bool(bool(Battle.start_session(_field, hostile).get("allowed", false))).is_true()
	GameFlow.send_event(&"enter_battle")
	assert_bool(_active(BATTLE)).is_true()
	await _pause()
	var target_before := GameFlow._target_scene
	var phases_before := WorldClock.phase_count

	assert_str(GameFlow.journey_refusal()).is_equal(GameFlow.JOURNEY_FIGHT_REFUSAL)
	assert_bool(GameFlow.start_journey(&"dom", &"dorthkor_road")).is_false()
	var plan := _prompt_plan(19)
	plan.state = TravelPlan.State.EN_ROUTE
	plan.total_steps = 1
	plan.encounter_schedule.clear()
	_install_plan(plan)
	var result: Dictionary = GameFlow.advance_journey()
	assert_str(String(result.get("event", ""))).is_equal("refused")
	assert_int(int(plan.state)).is_equal(TravelPlan.State.EN_ROUTE)
	assert_bool(GameFlow.travel(GameFlow.DORTHKOR_SCENE)).is_false()
	assert_bool(_active(PAUSED)).is_true()
	assert_str(GameFlow._target_scene).is_equal(target_before)
	assert_int(WorldClock.phase_count).is_equal(phases_before)


func test_an_ambush_that_cannot_be_seated_returns_the_prompt_and_cancel_works() -> void:
	await _pause()
	# Off every cell of the field's walking grid, as Dom's new-game spawn was before #649.
	_field.player().global_position = Vector2(-100000.0, -100000.0)
	_install_plan(_prompt_plan(_seed_for_avoidance(_avoidance_chance(), false)))

	var result: Dictionary = GameFlow.resolve_encounter_prompt(true)

	assert_str(String(result.get("event", ""))).is_equal("battle_refused")
	assert_str(String((result["refusal"] as Dictionary).get("blocked_by", ""))).is_equal("seating")
	assert_int(int(GameFlow.travel_plan.state)).is_equal(TravelPlan.State.AVOID_PROMPT)
	assert_bool(Battle.session_active).is_false()
	assert_bool(_active(PAUSED)).is_true()

	GameFlow.cancel_journey()
	await get_tree().process_frame
	assert_object(GameFlow.travel_plan).is_null()
	assert_dict(GameState.travel_plan).is_empty()
	assert_bool(_active(LOADING)).is_true()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TOWN_SCENE)


func _pause() -> void:
	GameFlow.send_event(&"pause")
	await get_tree().process_frame
	assert_bool(_active(PAUSED)).is_true()
	assert_bool(_pause_menu_open()).is_true()


func _pause_menu_open() -> bool:
	for screen: Control in UIManager._stack:
		if screen.scene_file_path == PAUSE_MENU_SCENE:
			return true
	return false


func _traveler() -> PartyMember:
	var member := PartyMember.new()
	member.id = "journey-pause-test"
	member.display_name = "Traveler"
	member.hp = 20
	member.max_hp = 20
	member.attributes = {"anchor": 8.0}
	member.skill_percentages = {"wayfinding": 20.0}
	member.skill_tiers = {"wayfinding": "untrained"}
	return member


func _prompt_plan(seed: int) -> TravelPlan:
	var plan := TravelPlan.new()
	plan.origin_id = &"dom"
	plan.destination_id = &"dorthkor_road"
	plan.progress_step = 2
	plan.total_steps = 12
	plan.rng_seed = seed
	plan.state = TravelPlan.State.AVOID_PROMPT
	plan.encounter_schedule = [{
		"at_step": 2,
		"encounter_id": &"loam-boar",
		"resolved": false,
		"spoils_granted": false,
	}]
	return plan


func _install_plan(plan: TravelPlan) -> void:
	GameFlow.travel_plan = plan
	GameState.travel_plan = plan.to_dict()


func _avoidance_chance() -> float:
	var route: Dictionary = WorldMapRegistry.route_between(&"dom", &"dorthkor_road")
	return EncounterDirector.avoidance_chance(route, GameState.party)


func _seed_for_avoidance(chance: float, succeeds: bool) -> int:
	for seed: int in range(1, 10000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		if (rng.randf_range(0.0, 100.0) < chance) == succeeds:
			return seed
	fail("Could not find a deterministic avoidance seed")
	return 0


func _clear_test_battle() -> void:
	if Battle.encounter_id.is_empty():
		return
	Battle.allies.clear()
	Battle.enemies.clear()
	Battle._definition.clear()
	Battle._combat_history.clear()
	Battle.controller = null
	Battle.encounter_id = &""
	Battle.last_result = null
	Battle.ended = true


func _enter_active_state() -> void:
	if _active(ACTIVE):
		return
	if _active(CHARGEN):
		GameFlow.send_event(&"new_game")
		await get_tree().process_frame
	if _active(INTRO):
		GameFlow.send_event(&"intro_done")
		await get_tree().process_frame
	if _active(PAUSED):
		GameFlow.send_event(&"resume")
		await get_tree().process_frame
	if _active(BATTLE):
		GameFlow.send_event(&"battle_end")
		await get_tree().process_frame
	if _active(TITLE):
		GameFlow.send_event(&"new_game")
		await get_tree().process_frame
	if _active(LOADING):
		GameFlow.send_event(&"level_ready")
		await get_tree().process_frame


func _return_to_title() -> void:
	if _active(PAUSED) and bool(GameFlow.chart.get_expression_property(&"resume_to_battle", false)):
		GameFlow.send_event(&"resume")
		await get_tree().process_frame
	if _active(BATTLE):
		GameFlow.send_event(&"battle_end")
		await get_tree().process_frame
	if _active(LOADING):
		GameFlow.send_event(&"level_ready")
		await get_tree().process_frame
	if _active(ACTIVE):
		GameFlow.send_event(&"pause")
		await get_tree().process_frame
	if _active(PAUSED):
		GameFlow.send_event(&"to_main_menu")
		await get_tree().process_frame


func _active(path: String) -> bool:
	var state := GameFlow.get_node_or_null(path)
	return state != null and bool(state.get("active"))
