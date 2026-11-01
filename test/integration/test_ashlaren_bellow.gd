extends GdUnitTestSuite
## P1.2 F: an optional challenge to the existing warehouse watch, using the
## object-lock path. Intimidation must commit once and survive a save round trip.

const SCENE := "res://world/ashlaren.tscn"
const LOCK_ID := "ashlaren-warehouse-challenge"
const INTERACTION_FLAG := "chapter_ashlaren_watch_challenged"

var _state_before: Dictionary = {}
var _checks_before: Dictionary = {}


func before_test() -> void:
	_state_before = GameState.to_dict()
	_checks_before = SkillCheck.to_dict()
	for flag: String in [INTERACTION_FLAG, "lock_picked_" + LOCK_ID, "lock_failed_" + LOCK_ID]:
		GameState.flags.erase(flag)
	SkillCheck.from_dict({})


func after_test() -> void:
	GameState.from_dict(_state_before)
	SkillCheck.from_dict(_checks_before)


func test_challenge_is_reachable_and_commits_bellow_once_across_save_load() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(5)
	var challenge := runner.find_child("WarehouseChallenge", true, false) as SMInteractable
	var watch := runner.find_child("AshlarenWarehouseWatch", true, false) as NPC
	var player := runner.find_child("Player", true, false) as Player
	assert_object(challenge).is_not_null()
	assert_object(watch).is_not_null()
	if challenge == null or watch == null:
		return
	assert_str(challenge.lock_skill).is_equal("bellow")
	assert_float(challenge.lock_modifier).is_equal(0.0)
	assert_str(challenge.required_flag).is_empty()
	assert_str(challenge.shop_type).is_empty()
	assert_bool(challenge.save_point).is_false()
	assert_bool(challenge.repeatable).is_false()

	var controller := player.get_node("ClickMoveController") as ClickMoveController
	var route := controller.request_move_to(challenge.global_position)
	assert_bool(bool(route.get("allowed", false))) \
		.override_failure_message("The yard challenge needs a real navigation approach.") \
		.is_true()
	controller.cancel_path()
	var grid := controller.get_iso_grid()
	player.global_position = grid.cell_to_world(grid.world_to_cell(challenge.global_position))
	await runner.simulate_frames(20)
	assert_bool(challenge._player_in_range).override_failure_message(
		"Player %s must enter the challenge range at %s."
		% [player.global_position, challenge.global_position]
	).is_true()
	# The guard's talk/pickpocket prompt must not consume the same interact press.
	assert_float(player.global_position.distance_to(watch.global_position)).is_greater(192.0)
	var prompt := challenge.get_node("Prompt") as Label
	assert_bool(prompt.visible).is_true()
	assert_str(prompt.text).contains("BELLOW")

	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	# Same handler as E; this also runs under the CI headless input backend.
	challenge._unhandled_input(press)
	var checks := SkillCheck.recent_checks()
	assert_int(checks.size()).is_equal(1)
	if checks.is_empty():
		return
	assert_str(str(checks.back()["skill"])).is_equal("bellow")
	assert_str(str(checks.back()["scene_id"])).is_equal("lock-" + LOCK_ID)
	assert_float(float(checks.back()["modifiers"])).is_equal(0.0)
	var passed := bool(checks.back()["success"])
	assert_bool(GameState.flag_is_true(challenge.lock_picked_flag())).is_equal(passed)
	assert_bool(GameState.flag_is_true(challenge.lock_failed_flag())).is_equal(not passed)
	assert_bool(GameState.flag_is_true(INTERACTION_FLAG)).is_equal(passed)
	assert_str(prompt.text).contains(
		challenge.interaction_text if passed else challenge.lock_failed_message
	)

	var saved := GameState.to_dict()
	GameState.flags.clear()
	assert_bool(GameState.from_dict(saved)).is_true()
	challenge._unhandled_input(press)
	assert_array(SkillCheck.recent_checks()).is_equal(checks)
	assert_bool(GameState.flag_is_true(INTERACTION_FLAG)).is_equal(passed)


func test_saved_failure_and_success_restore_their_prompts() -> void:
	var scene := load(SCENE) as PackedScene
	for passed: bool in [false, true]:
		GameState.flags.erase("lock_picked_" + LOCK_ID)
		GameState.flags.erase("lock_failed_" + LOCK_ID)
		GameState.set_flag(("lock_picked_" if passed else "lock_failed_") + LOCK_ID, true)
		GameState.set_flag(INTERACTION_FLAG, passed)
		var town: Node2D = auto_free(scene.instantiate())
		add_child(town)
		await get_tree().process_frame
		var challenge := town.get_node("WarehouseChallenge") as SMInteractable
		var prompt := challenge.get_node("Prompt") as Label
		assert_bool(challenge._used).is_equal(passed)
		assert_str(prompt.text).contains(
			challenge.prompt_text if passed else challenge.lock_failed_message
		)
		var retry := challenge.attempt_skill_lock()
		assert_bool(bool(retry["attempted"])).is_false()
		assert_bool(bool(retry["success"])).is_equal(passed)
		town.queue_free()
		await get_tree().process_frame
