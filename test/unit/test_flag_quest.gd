extends GdUnitTestSuite

var original_flags: Dictionary
var quest: FlagQuest


func before_test() -> void:
	original_flags = GameState.flags.duplicate(true)
	GameState.flags.clear()
	quest = auto_free(FlagQuest.new())
	quest.required_flags = PackedStringArray(["reached", "demon", "dead"])
	quest.objectives = PackedStringArray(["Reach road", "Break demons", "Face dead", "Return"])


func after_test() -> void:
	GameState.flags = original_flags


func test_progress_is_derived_from_ordered_durable_flags() -> void:
	quest.update()
	assert_int(quest.current_stage).is_equal(0)
	assert_str(quest.current_objective()).is_equal("Reach road")

	GameState.set_flag("reached", true)
	GameState.set_flag("demon", true)
	quest.update()

	assert_int(quest.current_stage).is_equal(2)
	assert_str(quest.current_objective()).is_equal("Face dead")
	assert_bool(quest.objective_completed).is_false()


func test_all_flags_complete_the_objective_and_point_home() -> void:
	for flag in quest.required_flags:
		GameState.set_flag(flag, true)
	quest.update()

	assert_bool(quest.objective_completed).is_true()
	assert_str(quest.current_objective()).is_equal("Return")


func test_later_flags_do_not_skip_an_unfinished_step() -> void:
	GameState.set_flag("dead", true)
	quest.update()

	assert_int(quest.current_stage).is_equal(0)
	assert_bool(quest.objective_completed).is_false()
