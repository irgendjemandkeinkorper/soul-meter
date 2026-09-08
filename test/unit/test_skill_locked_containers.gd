extends GdUnitTestSuite
## #284 / game-identity ruling 7 ("stats matter outside combat"). A skill-locked
## interactable resolves ONE committed DRAMGID check and records the outcome
## durably. The thing being pinned is that the attempt cannot be repeated: an
## unlimited retry converts any non-zero chance into a certainty and makes the
## skill decorative.

const CHEST_SCENE := preload("res://actors/chest/chest.tscn")

var _flags_before: Dictionary


func before_test() -> void:
	_flags_before = GameState.flags.duplicate(true)


func after_test() -> void:
	GameState.flags = _flags_before.duplicate(true)


func _locked_chest(skill: String, lock_id: String) -> Chest:
	var chest: Chest = auto_free(CHEST_SCENE.instantiate())
	chest.container_id = lock_id
	chest.lock_skill = skill
	chest.lock_id = lock_id
	return chest


func test_a_chest_without_a_lock_skill_is_unchanged() -> void:
	var chest := _locked_chest("", "unlocked-crate")
	assert_bool(chest.has_skill_lock()).is_false()
	assert_dict(chest.attempt_skill_lock()).is_equal({"attempted": false, "success": false})


## `lock_id` is what makes the outcome recordable. Without it there is no flag to
## write, so the check would be re-rollable by walking away and coming back.
func test_a_lock_skill_without_a_lock_id_is_not_a_lock() -> void:
	var chest := _locked_chest("strain", "")
	chest.lock_id = ""
	assert_bool(chest.has_skill_lock()).is_false()


func test_a_successful_pick_is_recorded_and_never_re_rolled() -> void:
	var chest := _locked_chest("strain", "test-crate-success")
	GameState.set_flag(chest.lock_picked_flag(), true)

	var repeat := chest.attempt_skill_lock()
	assert_bool(bool(repeat["attempted"])).override_failure_message(
		"a picked lock must not roll again"
	).is_false()
	assert_bool(bool(repeat["success"])).is_true()


func test_a_failed_lock_stays_failed() -> void:
	var chest := _locked_chest("strain", "test-crate-failure")
	GameState.set_flag(chest.lock_failed_flag(), true)

	var retry := chest.attempt_skill_lock()
	assert_bool(bool(retry["attempted"])).override_failure_message(
		"a failed lock must not offer a second roll — that is the whole mechanic"
	).is_false()
	assert_bool(bool(retry["success"])).is_false()


## Every attempt writes exactly one of the two flags, so no path leaves the lock
## in a state that can be re-attempted.
func test_one_attempt_always_records_an_outcome() -> void:
	var chest := _locked_chest("strain", "test-crate-outcome")
	var result := chest.attempt_skill_lock()

	assert_bool(bool(result["attempted"])).is_true()
	var picked := GameState.flag_is_true(chest.lock_picked_flag())
	var failed := GameState.flag_is_true(chest.lock_failed_flag())
	assert_bool(picked or failed).override_failure_message(
		"an attempt that records neither outcome is an attempt that can be repeated"
	).is_true()
	assert_bool(picked and failed).override_failure_message(
		"a lock cannot be both picked and failed"
	).is_false()
	assert_bool(picked).is_equal(bool(result["success"]))


## An unknown skill id opens the lock rather than sealing content behind a typo,
## and says so. Refusing silently would look exactly like a very hard lock.
func test_an_unknown_lock_skill_opens_rather_than_seals() -> void:
	var chest := _locked_chest("picking-locks", "test-crate-typo")
	var result := chest.attempt_skill_lock()

	assert_bool(bool(result["success"])).is_true()
	assert_bool(GameState.flag_is_true(chest.lock_picked_flag())).is_true()


func test_the_lock_skill_is_a_real_dramgid_skill() -> void:
	assert_bool(DramgidSchema.is_skill("strain")).override_failure_message(
		"the authored Dorthkor Road crate uses 'strain'"
	).is_true()
	assert_bool(DramgidSchema.is_skill("slip")).is_true()
