extends GdUnitTestSuite

var _game_state_before: Dictionary = {}
var _world_clock_before: Dictionary = {}
var _reputation_before: Dictionary = {}
var _renown_before: Dictionary = {}
var _quests_before: Dictionary = {}
var _skill_check_before: Dictionary = {}
var _travel_plan_before: TravelPlan
var _target_scene_before := ""
var _target_spawn_before: StringName = &"default"
var _save_paths_before: Array[String] = []
var _test_save_paths: Array[String] = []
var _flow_was_active := false
var _save_runtime_before: Dictionary = {}
var _skip_breath_refill_before := false


func before_test() -> void:
	_game_state_before = GameState.to_dict()
	_world_clock_before = WorldClock.to_dict()
	_reputation_before = Reputation.to_dict()
	_renown_before = Renown.to_dict()
	_quests_before = QuestRegistry.to_dict()
	_skill_check_before = SkillCheck.to_dict()
	_travel_plan_before = GameFlow.travel_plan
	_target_scene_before = GameFlow._target_scene
	_target_spawn_before = GameFlow._target_spawn_id
	_save_paths_before = [SaveGame.save_path, SaveGame.temp_path, SaveGame.backup_path]
	var test_save_prefix := OS.get_temp_dir().path_join(
		"soul-meter-travel-flow-%s" % Time.get_ticks_usec()
	)
	SaveGame.save_path = test_save_prefix + ".save"
	SaveGame.temp_path = test_save_prefix + ".save.tmp"
	SaveGame.backup_path = test_save_prefix + ".save.bak"
	_test_save_paths = [SaveGame.save_path, SaveGame.temp_path, SaveGame.backup_path]
	_save_runtime_before = {
		"pending_player_position": SaveGame.pending_player_position,
		"has_pending_player_position": SaveGame.has_pending_player_position,
		"pending_spawn_id": SaveGame.pending_spawn_id,
		"pending_autosave_reason": SaveGame._pending_autosave_reason,
		"run_started_unix": SaveGame._run_started_unix,
		"elapsed_before_load": SaveGame._elapsed_before_load,
		"ng_plus": SaveGame.ng_plus.duplicate(true),
		"zhavar": SaveGame.zhavar.duplicate(true),
		"unit_roster": SaveGame.unit_roster.to_dict(),
	}
	_skip_breath_refill_before = GameFlow._skip_next_breath_refill
	_flow_was_active = bool(GameFlow.get_node("StateChart/Root/Playing/Active").get("active"))
	_remove_test_saves()
	GameFlow.travel_plan = null
	GameState.travel_plan = {}
	GameState.party = [_traveler()]
	get_tree().paused = false


func after_test() -> void:
	_restore_flow_after_battle_test()
	_clear_test_battle()
	_remove_test_saves()
	SaveGame.save_path = _save_paths_before[0]
	SaveGame.temp_path = _save_paths_before[1]
	SaveGame.backup_path = _save_paths_before[2]
	GameState.from_dict(_game_state_before)
	WorldClock.from_dict(_world_clock_before)
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)
	QuestRegistry.from_dict(_quests_before)
	SkillCheck.from_dict(_skill_check_before)
	SaveGame.pending_player_position = _save_runtime_before["pending_player_position"]
	SaveGame.has_pending_player_position = _save_runtime_before["has_pending_player_position"]
	SaveGame.pending_spawn_id = _save_runtime_before["pending_spawn_id"]
	SaveGame._pending_autosave_reason = _save_runtime_before["pending_autosave_reason"]
	SaveGame._run_started_unix = _save_runtime_before["run_started_unix"]
	SaveGame._elapsed_before_load = _save_runtime_before["elapsed_before_load"]
	SaveGame.ng_plus = _save_runtime_before["ng_plus"].duplicate(true)
	SaveGame.zhavar = _save_runtime_before["zhavar"].duplicate(true)
	var roster_data: Dictionary = _save_runtime_before["unit_roster"]
	SaveGame.unit_roster = UnitRoster.from_dict(roster_data)
	GameFlow.travel_plan = _travel_plan_before
	GameFlow._target_scene = _target_scene_before
	GameFlow._target_spawn_id = _target_spawn_before
	GameFlow._skip_next_breath_refill = _skip_breath_refill_before
	get_tree().paused = false


func test_start_journey_builds_and_persists_plan_without_mutating_on_invalid_route() -> void:
	assert_bool(GameFlow.start_journey(&"dom", &"dorthkor-road")).is_true()
	var plan: TravelPlan = GameFlow.travel_plan
	assert_object(plan).is_not_null()
	assert_str(plan.origin_id).is_equal("dom")
	assert_str(plan.destination_id).is_equal("dorthkor-road")
	assert_int(plan.progress_step).is_zero()
	assert_int(plan.total_steps).is_equal(12)
	assert_int(int(plan.state)).is_equal(TravelPlan.State.EN_ROUTE)
	var route: Dictionary = WorldMapRegistry.route_between(&"dom", &"dorthkor-road")
	assert_array(plan.encounter_schedule).is_equal(
		EncounterDirector.build_schedule(route, plan.rng_seed)
	)
	assert_dict(GameState.travel_plan).is_equal(plan.to_dict())

	var before_invalid: Dictionary = plan.to_dict()
	assert_bool(GameFlow.start_journey(&"dom", &"missing-place")).is_false()
	assert_dict(GameFlow.travel_plan.to_dict()).is_equal(before_invalid)
	assert_dict(GameState.travel_plan).is_equal(before_invalid)


func test_loading_to_active_wiring_refills_party_breath_for_travel() -> void:
	GameState.party[0].breath_max = 15
	GameState.party[0].breath = 2

	GameFlow.get_node("StateChart/Root/Playing/Loading/ToActive").emit_signal("taken")

	assert_int(GameState.party[0].breath).is_equal(15)


func test_loading_a_save_preserves_spent_breath_after_active_transition() -> void:
	GameState.party[0].breath_max = 15
	GameState.party[0].breath = 6
	GameFlow._on_save_loaded()

	GameFlow.get_node("StateChart/Root/Playing/Loading/ToActive").emit_signal("taken")

	assert_int(GameState.party[0].breath).is_equal(6)
	GameState.party[0].breath = 2
	GameFlow.get_node("StateChart/Root/Playing/Loading/ToActive").emit_signal("taken")
	assert_int(GameState.party[0].breath).is_equal(15)


func test_advance_journey_stops_at_seeded_encounter_prompt() -> void:
	var plan := _prompt_plan(7421)
	plan.state = TravelPlan.State.EN_ROUTE
	_install_plan(plan)

	var result: Dictionary = GameFlow.advance_journey(2)
	assert_str(result["event"]).is_equal("encounter_prompt")
	assert_str(result["encounter_id"]).is_equal("loam-boar")
	var route: Dictionary = WorldMapRegistry.route_between(plan.origin_id, plan.destination_id)
	assert_float(float(result["avoidance_chance"])).is_equal_approx(
		EncounterDirector.avoidance_chance(route, GameState.party), 0.001
	)
	assert_int(plan.progress_step).is_equal(2)
	assert_int(int(plan.state)).is_equal(TravelPlan.State.AVOID_PROMPT)
	assert_dict(GameState.travel_plan).is_equal(plan.to_dict())


func test_multi_step_advance_clamps_at_the_first_unresolved_encounter_boundary() -> void:
	var plan := _prompt_plan(43)
	plan.state = TravelPlan.State.EN_ROUTE
	_install_plan(plan)

	var result: Dictionary = GameFlow.advance_journey(9)
	assert_str(result["event"]).is_equal("encounter_prompt")
	assert_int(plan.progress_step).is_equal(2)
	assert_int(int(plan.state)).is_equal(TravelPlan.State.AVOID_PROMPT)


func test_successful_avoidance_marks_slot_resolved() -> void:
	var chance := _avoidance_chance()
	var plan := _prompt_plan(_seed_for_avoidance(chance, true))
	plan.progress_step = 2
	_install_plan(plan)

	var result: Dictionary = GameFlow.resolve_encounter_prompt(true)
	assert_str(result["event"]).is_equal("avoided")
	assert_bool(bool(plan.encounter_schedule[0]["resolved"])).is_true()
	assert_int(int(plan.state)).is_equal(TravelPlan.State.EN_ROUTE)
	assert_dict(GameState.travel_plan).is_equal(plan.to_dict())


func test_failed_avoidance_starts_existing_battle_path() -> void:
	var chance := _avoidance_chance()
	var plan := _prompt_plan(_seed_for_avoidance(chance, false))
	plan.progress_step = 2
	_install_plan(plan)

	var result: Dictionary = GameFlow.resolve_encounter_prompt(true)
	assert_str(result["event"]).is_equal("battle_started")
	assert_str(Battle.encounter_id).is_equal("loam-boar")
	assert_bool(Battle.ended).is_false()
	assert_int(int(plan.state)).is_equal(TravelPlan.State.IN_BATTLE)


func test_cancel_journey_returns_to_origin_and_clears_persistence() -> void:
	var plan := _prompt_plan(11)
	plan.state = TravelPlan.State.EN_ROUTE
	_install_plan(plan)

	GameFlow.cancel_journey()
	assert_object(GameFlow.travel_plan).is_null()
	assert_dict(GameState.travel_plan).is_empty()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TOWN_SCENE)


func test_arrival_advances_exact_route_phase_cost_and_uses_travel_path() -> void:
	var plan := _prompt_plan(19)
	plan.state = TravelPlan.State.EN_ROUTE
	plan.total_steps = 1
	plan.encounter_schedule.clear()
	_install_plan(plan)
	var initial_phase_index := WorldClock.PHASES.find(WorldClock.phase())

	var result: Dictionary = GameFlow.advance_journey()
	assert_str(result["event"]).is_equal("arrived")
	assert_int(int(plan.state)).is_equal(TravelPlan.State.ARRIVED)
	assert_int(plan.elapsed_phases).is_equal(3)
	assert_str(WorldClock.phase()).is_equal(
		WorldClock.PHASES[(initial_phase_index + 3) % WorldClock.PHASES.size()]
	)
	assert_str(GameFlow._target_scene).is_equal(GameFlow.DORTHKOR_SCENE)


func test_battle_victory_grants_spoils_exactly_once_across_duplicate_events_and_reload() -> void:
	var plan := _prompt_plan(23)
	plan.progress_step = 2
	plan.state = TravelPlan.State.IN_BATTLE
	_install_plan(plan)
	var expected_spoils: Array[Dictionary] = SpoilsTable.roll(&"loam-boar", plan.rng_seed, 0)
	var victory := BattleResult.new()
	victory.state = BattleResult.State.VICTORY

	Battle.battle_ended.emit(victory)
	assert_bool(bool(plan.encounter_schedule[0]["resolved"])).is_true()
	assert_bool(bool(plan.encounter_schedule[0]["spoils_granted"])).is_true()
	assert_int(int(plan.state)).is_equal(TravelPlan.State.EN_ROUTE)
	assert_dict(GameState.travel_plan).is_equal(plan.to_dict())
	assert_array(victory.spoils).is_equal(expected_spoils)

	Battle.battle_ended.emit(victory)
	assert_array(victory.spoils).is_equal(expected_spoils)
	assert_bool(SaveGame.save()).is_true()

	GameState.travel_plan = {}
	GameFlow.travel_plan = null
	assert_bool(SaveGame.load_save()).is_true()
	var restored: TravelPlan = GameFlow.travel_plan
	assert_bool(bool(restored.encounter_schedule[0]["spoils_granted"])).is_true()

	Battle.battle_ended.emit(victory)
	assert_array(victory.spoils).is_equal(expected_spoils)


func test_non_victory_battle_signal_returns_to_the_unresolved_prompt() -> void:
	for outcome: int in [BattleResult.State.DEFEAT, BattleResult.State.FLED]:
		var plan := _prompt_plan(29)
		plan.progress_step = 2
		plan.state = TravelPlan.State.IN_BATTLE
		_install_plan(plan)
		var result := BattleResult.new()
		result.state = outcome

		Battle.battle_ended.emit(result)
		assert_bool(bool(plan.encounter_schedule[0]["resolved"])).is_false()
		assert_int(int(plan.state)).is_equal(TravelPlan.State.AVOID_PROMPT)
		assert_dict(GameState.travel_plan).is_equal(plan.to_dict())


func test_new_game_clears_a_persisted_journey_before_load_requested() -> void:
	_install_plan(_prompt_plan(31))

	SaveGame.new_game()

	assert_dict(GameState.travel_plan).is_empty()
	assert_object(GameFlow.travel_plan).is_null()


func test_mid_journey_save_reload_preserves_plan_and_avoidance_stream() -> void:
	var chance := _avoidance_chance()
	var plan := _prompt_plan(_seed_for_avoidance(chance, true))
	plan.progress_step = 2
	_install_plan(plan)
	var expected_plan: Dictionary = plan.to_dict()
	assert_bool(SaveGame.load_requested.is_connected(GameFlow._on_load_requested)).is_true()
	assert_bool(SaveGame.save()).is_true()

	var first_result: Dictionary = GameFlow.resolve_encounter_prompt(true)
	GameState.travel_plan = {}
	GameFlow.travel_plan = null
	assert_bool(SaveGame.load_save()).is_true()
	var restored: TravelPlan = GameFlow.travel_plan
	assert_dict(restored.to_dict()).is_equal(expected_plan)
	var second_result: Dictionary = GameFlow.resolve_encounter_prompt(true)

	assert_str(second_result["event"]).is_equal(str(first_result["event"]))
	assert_int(restored.rng_seed).is_equal(plan.rng_seed)
	assert_bool(bool(restored.encounter_schedule[0]["resolved"])).is_equal(
		bool(plan.encounter_schedule[0]["resolved"])
	)


func test_in_battle_save_reloads_to_a_resumable_avoid_prompt() -> void:
	var plan := _prompt_plan(37)
	plan.progress_step = 2
	plan.state = TravelPlan.State.IN_BATTLE
	_install_plan(plan)
	assert_bool(SaveGame.save()).is_true()

	GameState.travel_plan = {}
	GameFlow.travel_plan = null
	assert_bool(SaveGame.load_save()).is_true()

	var restored: TravelPlan = GameFlow.travel_plan
	assert_int(int(restored.state)).is_equal(TravelPlan.State.AVOID_PROMPT)
	var result: Dictionary = GameFlow.resolve_encounter_prompt(false)
	assert_str(result["event"]).is_equal("battle_started")
	assert_int(int(restored.state)).is_equal(TravelPlan.State.IN_BATTLE)


func test_prompt_state_with_no_reached_slot_reloads_to_en_route() -> void:
	var plan := _prompt_plan(41)
	plan.progress_step = 0
	plan.encounter_schedule[0]["at_step"] = 5
	plan.state = TravelPlan.State.AVOID_PROMPT
	_install_plan(plan)
	assert_bool(SaveGame.save()).is_true()

	GameState.travel_plan = {}
	GameFlow.travel_plan = null
	assert_bool(SaveGame.load_save()).is_true()

	assert_int(int(GameFlow.travel_plan.state)).is_equal(TravelPlan.State.EN_ROUTE)


func test_out_of_bounds_slot_is_clamped_on_reload_and_blocks_arrival() -> void:
	var plan := _prompt_plan(47)
	plan.state = TravelPlan.State.EN_ROUTE
	plan.total_steps = 4
	plan.encounter_schedule[0]["at_step"] = 99
	_install_plan(plan)
	assert_bool(SaveGame.save()).is_true()

	GameState.travel_plan = {}
	GameFlow.travel_plan = null
	assert_bool(SaveGame.load_save()).is_true()

	var restored: TravelPlan = GameFlow.travel_plan
	assert_int(int(restored.encounter_schedule[0]["at_step"])).is_equal(4)
	var result: Dictionary = GameFlow.advance_journey(99)
	assert_str(result["event"]).is_equal("encounter_prompt")


func test_finished_journey_states_reload_to_no_plan() -> void:
	for finished: int in [TravelPlan.State.ARRIVED, TravelPlan.State.CANCELLED]:
		var plan := _prompt_plan(53)
		plan.state = finished as TravelPlan.State
		_install_plan(plan)
		assert_bool(SaveGame.save()).is_true()

		GameFlow.travel_plan = null
		assert_bool(SaveGame.load_save()).is_true()

		assert_object(GameFlow.travel_plan).is_null()
		assert_dict(GameState.travel_plan).is_empty()


func test_cancel_journey_from_the_avoid_prompt_clears_the_plan() -> void:
	var plan := _prompt_plan(59)
	plan.progress_step = 2
	_install_plan(plan)

	GameFlow.cancel_journey()

	assert_object(GameFlow.travel_plan).is_null()
	assert_dict(GameState.travel_plan).is_empty()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TOWN_SCENE)


func _traveler() -> PartyMember:
	var member := PartyMember.new()
	member.id = "travel-flow-test"
	member.display_name = "Traveler"
	member.hp = 20
	member.max_hp = 20
	member.attributes = {"anchor": 8.0}
	member.skill_percentages = {"survival": 20.0}
	member.skill_tiers = {"survival": "untrained"}
	return member


func _prompt_plan(seed: int) -> TravelPlan:
	var plan := TravelPlan.new()
	plan.origin_id = &"dom"
	plan.destination_id = &"dorthkor-road"
	plan.progress_step = 0
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


func _assert_spoil_counts(spoils: Array[Dictionary], counts_before: Dictionary) -> void:
	for spoil: Dictionary in spoils:
		var item_id := String(spoil["item_id"])
		assert_int(GameState.item_count(item_id)).is_equal(
			int(counts_before[item_id]) + int(spoil["quantity"])
		)


func _avoidance_chance() -> float:
	var route: Dictionary = WorldMapRegistry.route_between(&"dom", &"dorthkor-road")
	return EncounterDirector.avoidance_chance(route, GameState.party)


func _seed_for_avoidance(chance: float, succeeds: bool) -> int:
	for seed: int in range(1, 10000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		if (rng.randf_range(0.0, 100.0) < chance) == succeeds:
			return seed
	fail("Could not find deterministic avoidance seed")
	return 0


func _restore_flow_after_battle_test() -> void:
	if not _flow_was_active:
		return
	for event: StringName in [
		&"level_ready",
		&"deployment_next",
		&"deployment_next",
		&"deployment_next",
		&"accept_slate",
		&"battle_end",
	]:
		GameFlow.send_event(event)


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


func _remove_test_saves() -> void:
	for path: String in _test_save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
