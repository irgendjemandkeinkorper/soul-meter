extends GdUnitTestSuite

const DialogueLabScript := preload("res://globals/dialogue_lab.gd")
const TEST_FLAG := "dialogue_lab_test_flag"
const TEST_FACTION := "the-registry"

var _lab: Node = null
var _incoming_runtime: Dictionary = {}
var _incoming_rng_seed: int = 0
var _incoming_rng_state: int = 0


func before_test() -> void:
	_incoming_runtime = SaveGame.capture_runtime_state()
	_incoming_rng_seed = SkillCheck.random_number_generator.seed
	_incoming_rng_state = SkillCheck.random_number_generator.state
	QuestRegistry.reset()
	_lab = auto_free(DialogueLabScript.new()) as Node
	add_child(_lab)
	_lab.set("force_enabled_for_tests", true)


func after_test() -> void:
	if _lab != null:
		_lab.call("end_session")
		_lab.set("force_enabled_for_tests", false)
	_restore_incoming_state()
	_clear_test_battle()
	get_tree().paused = false


func test_dialogue_files_and_titles_are_derived_from_disk_resources() -> void:
	var expected_files: Array[String] = _dialogue_files_on_disk()
	var actual_files: Array[String] = _lab.call("dialogue_files")

	assert_array(actual_files).is_equal(expected_files)
	assert_bool(actual_files.is_empty()).is_false()
	var resource := ResourceLoader.load(actual_files[0]) as DialogueResource
	assert_object(resource).is_not_null()
	var expected_titles: Array[String] = []
	for cue: String in resource.get_cues():
		expected_titles.append(cue)
	expected_titles.sort()
	var actual_titles: Array[String] = _lab.call("titles_for_file", actual_files[0])
	assert_array(actual_titles).is_equal(expected_titles)


func test_enabled_lab_builds_and_closes_the_setup_overlay() -> void:
	var paused_before := get_tree().paused

	_lab.call("open_setup")

	assert_object(_lab.get("_overlay_layer")).is_not_null()
	assert_int(_lab.get_child_count()).is_equal(1)
	assert_bool(get_tree().paused).is_true()
	_lab.call("close_overlay")
	assert_object(_lab.get("_overlay_layer")).is_null()
	assert_bool(get_tree().paused).is_equal(paused_before)


func test_setup_state_is_applied_inside_the_snapshot_and_restored() -> void:
	var clean: Dictionary = _snapshot_all_state()
	var setup: Dictionary = _valid_setup()
	setup["flags"] = {TEST_FLAG: true, "dialogue_lab_cleared_flag": false}
	setup["reputation"] = {TEST_FACTION: 21.0}
	setup["renown_reputation"] = 8.0
	setup["renown_infamy"] = 3.0

	_lab.call("start_test_session", setup)

	assert_bool(GameState.flag_is_true(TEST_FLAG)).is_true()
	assert_float(Reputation.standing(TEST_FACTION)).is_equal(21.0)
	assert_float(Renown.reputation()).is_equal(8.0)
	assert_float(Renown.infamy()).is_equal(3.0)
	_dirty_quest_registry()
	SkillCheck.from_dict({"expert_rerolls_used": {"dialogue-lab/test": 1}})
	SkillCheck.random_number_generator.seed = 991
	SkillCheck.random_number_generator.randi()

	_lab.call("end_session")

	_assert_all_state_equals(clean)


func test_restarted_session_is_rearmed_and_restores_every_runtime_surface() -> void:
	var clean: Dictionary = _snapshot_all_state()
	var setup: Dictionary = _valid_setup()

	_lab.call("start_test_session", setup)
	_dirty_all_state("first")
	_lab.call("start_test_session", setup)
	assert_bool(bool(_lab.call("sandbox_is_armed"))) \
		.override_failure_message("Every restarted session must begin armed") \
		.is_true()
	_dirty_all_state("restarted")

	_lab.call("end_session")

	_assert_all_state_equals(clean)


func test_restored_snapshot_disarms_before_normal_progress_resumes() -> void:
	_lab.call("start_test_session", _valid_setup())
	_lab.call("end_session")
	GameState.set_flag("dialogue_lab_progress_after_session", true)
	var earned_after: Dictionary = GameState.to_dict().duplicate(true)

	_lab.call("end_session")

	assert_dict(GameState.to_dict()).is_equal(earned_after)


func test_disabled_lab_is_not_drivable() -> void:
	var setup: Dictionary = _valid_setup()
	_lab.call("end_session")
	_lab.set("force_enabled_for_tests", false)
	_lab.set("_setup", setup)

	_lab.call("open_setup")
	_lab.call("start_replay", setup)
	_lab.call("start_test_session", setup)
	_lab.call("replay_same_state")
	_lab.call("reload_and_replay")

	assert_bool(bool(_lab.call("sandbox_is_armed"))).is_false()
	assert_object(_lab.get("_overlay_layer")).is_null()
	assert_int(_lab.get_child_count()).is_equal(0)


func test_every_replay_entry_point_refuses_over_a_live_battle() -> void:
	_lab.set("_setup", _valid_setup())
	Battle.start(EncounterIds.BOG_WIGHT)
	var production_controller: CombatController = Battle.controller
	assert_object(production_controller).is_not_null()

	_lab.call("open_setup")
	_lab.call("start_replay", _valid_setup())
	_lab.call("start_test_session", _valid_setup())
	_lab.call("replay_same_state")
	_lab.call("reload_and_replay")

	assert_object(Battle.controller).is_same(production_controller)
	assert_bool(bool(_lab.call("sandbox_is_armed"))).is_false()
	assert_object(_lab.get("_overlay_layer")).is_null()


func test_every_replay_entry_point_refuses_over_a_live_production_dialogue() -> void:
	var resource := ResourceLoader.load(_valid_setup()["dialogue_path"]) as DialogueResource
	assert_object(resource).is_not_null()
	DialogueManager.dialogue_started.emit(resource)
	_lab.set("_setup", _valid_setup())

	_lab.call("open_setup")
	_lab.call("start_replay", _valid_setup())
	_lab.call("start_test_session", _valid_setup())
	_lab.call("replay_same_state")
	_lab.call("reload_and_replay")

	assert_bool(bool(_lab.call("sandbox_is_armed"))).is_false()
	assert_object(_lab.get("_overlay_layer")).is_null()
	DialogueManager.dialogue_ended.emit(resource)


func test_a_session_contains_zhavar_and_the_other_save_game_runtime_surfaces() -> void:
	# The five globals the lab originally snapshotted were not the whole set.
	# `do SaveGame.raise_zhavar("wilds")` is authored in dialogue/sella_varn.dialogue,
	# and raising a rung is permanent, so a leak here silently advances the
	# campaign's escalation ladder every time an author replays that beat.
	var zhavar_before := SaveGame.zhavar_rung("wilds")
	var clean: Dictionary = _snapshot_all_state()

	_lab.call("start_test_session", _valid_setup())
	SaveGame.raise_zhavar("wilds")
	assert_str(SaveGame.zhavar_rung("wilds")) \
		.override_failure_message("precondition: the replay must actually raise the rung") \
		.is_not_equal(zhavar_before)
	_lab.call("end_session")

	assert_str(SaveGame.zhavar_rung("wilds")).is_equal(zhavar_before)
	_assert_all_state_equals(clean)


func test_an_autosave_requested_during_a_session_never_fires_after_it() -> void:
	# Eight QuestRegistry mutators reachable from a dialogue `do` line call
	# SaveGame.request_autosave(), which flushes DEFERRED — on a later idle
	# frame, by which time the session has already restored and closed its
	# sandbox. Refusing the write only at flush time is not enough, because the
	# flush runs UNSUPPRESSED after the session ends. The request must never be
	# staged at all, so this asserts the state AFTER the session, which is the
	# ordering the deferred call actually has.
	_lab.call("start_test_session", _valid_setup())
	assert_bool(SaveGame.runtime_sandbox_is_armed()) \
		.override_failure_message("a live session must hold a sandbox") \
		.is_true()
	SaveGame.request_autosave("dialogue-lab-containment-test")

	_lab.call("end_session")

	assert_bool(SaveGame.runtime_sandbox_is_armed()) \
		.override_failure_message("ending the session must close the sandbox") \
		.is_false()
	assert_str(SaveGame._pending_autosave_reason) \
		.override_failure_message("a request staged during a session must never survive it") \
		.is_empty()
	assert_bool(SaveGame.flush_pending_autosave()) \
		.override_failure_message("nothing may flush after the session ends") \
		.is_false()


func test_the_sandbox_is_balanced_across_a_restarted_session() -> void:
	_lab.call("start_test_session", _valid_setup())
	_lab.call("start_test_session", _valid_setup())
	_lab.call("end_session")

	assert_bool(SaveGame.runtime_sandbox_is_armed()) \
		.override_failure_message("restart must not leave the sandbox armed forever") \
		.is_false()


func test_the_combat_lab_cannot_start_inside_a_live_dialogue_lab_session() -> void:
	# Two labs holding snapshots at once restore in whatever order they end, and
	# a non-LIFO restore reinstates this session's dirty state after it already
	# cleaned up. They are mutually exclusive rather than nested.
	var encounter := {"encounter_id": EncounterIds.BOG_WIGHT}
	CombatLab.force_enabled_for_tests = true

	# Precondition: this exact call DOES arm a combat snapshot on its own, so the
	# refusal below is attributable to the guard rather than to a setup the
	# combat lab would have rejected anyway.
	CombatLab.start_test_session(encounter)
	assert_bool(bool(CombatLab.call("sandbox_is_armed"))) \
		.override_failure_message("precondition: this setup must normally arm a snapshot") \
		.is_true()
	CombatLab.stop_test_session()

	_lab.call("start_test_session", _valid_setup())
	assert_bool(CombatLab.another_sandbox_is_armed()) \
		.override_failure_message("the combat lab must see this session's sandbox") \
		.is_true()
	CombatLab.start_test_session(encounter)

	assert_bool(bool(CombatLab.call("sandbox_is_armed"))) \
		.override_failure_message("the combat lab must not capture a dialogue-dirtied snapshot") \
		.is_false()
	_lab.call("end_session")
	CombatLab.force_enabled_for_tests = false


func _valid_setup() -> Dictionary:
	var files: Array[String] = _lab.call("dialogue_files")
	var titles: Array[String] = _lab.call("titles_for_file", files[0])
	return {
		"dialogue_path": files[0],
		"title": titles[0],
		"flags": {},
		"reputation": {},
	}


func _dirty_all_state(suffix: String) -> void:
	GameState.set_flag("%s_%s" % [TEST_FLAG, suffix], true)
	Reputation.record("dialogue-lab", TEST_FACTION, 4.0, "Dialogue Lab containment test")
	Renown.gain_reputation("dialogue-lab", 2.0, "Dialogue Lab containment test")
	Renown.gain_infamy("dialogue-lab", 1.0, "Dialogue Lab containment test")
	_dirty_quest_registry()
	SkillCheck.from_dict({"expert_rerolls_used": {"dialogue-lab/%s" % suffix: 1}})
	SkillCheck.random_number_generator.seed = 1000 + suffix.length()
	SkillCheck.random_number_generator.randi()


func _snapshot_all_state() -> Dictionary:
	# Deliberately the SAME authoritative list the lab restores, so a global
	# added to SaveGame.capture_runtime_state() is covered here automatically.
	# Enumerating the surfaces independently here is what let the original
	# containment gap pass its own tests.
	return {
		"runtime": SaveGame.capture_runtime_state(),
		"rng_seed": SkillCheck.random_number_generator.seed,
		"rng_state": SkillCheck.random_number_generator.state,
	}


func _dirty_quest_registry() -> void:
	QuestRegistry.from_dict({
		"available": [{
			"id": QuestRegistry.BELLHOUSE_REPAIR.id,
			"data": QuestRegistry.BELLHOUSE_REPAIR.serialize(),
		}],
		"active": [],
		"completed": [],
	})


func _assert_all_state_equals(expected: Dictionary) -> void:
	assert_dict(SaveGame.capture_runtime_state()).is_equal(expected["runtime"])
	assert_int(SkillCheck.random_number_generator.seed).is_equal(expected["rng_seed"])
	assert_int(SkillCheck.random_number_generator.state).is_equal(expected["rng_state"])


func _dialogue_files_on_disk() -> Array[String]:
	var result: Array[String] = []
	for directory: String in ["res://dialogue", "res://dialogue/companions"]:
		for file_name: String in DirAccess.get_files_at(directory):
			if file_name.get_extension() == "dialogue":
				result.append(directory.path_join(file_name))
	result.sort()
	return result


func _restore_incoming_state() -> void:
	assert_bool(SaveGame.restore_runtime_state(_incoming_runtime)).is_true()
	SkillCheck.random_number_generator.seed = _incoming_rng_seed
	SkillCheck.random_number_generator.state = _incoming_rng_state
	# A test that failed mid-session must not leak an armed sandbox into later
	# suites, where it would silently disable every autosave.
	while SaveGame.runtime_sandbox_is_armed():
		SaveGame.end_runtime_sandbox()
	SaveGame._pending_autosave_reason = ""


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
