extends GdUnitTestSuite
## Dedicated coverage for globals/chapter_definition.gd (issue #68).

var original_flags: Dictionary


func before_test() -> void:
	original_flags = GameState.flags.duplicate(true)
	GameState.flags.clear()


func after_test() -> void:
	GameState.flags = original_flags


func test_get_current_stage_falls_back_to_the_first_stage_when_nothing_is_met() -> void:
	var stage_a := _stage("A", [_flag_req("never_set_a")])
	var stage_b := _stage("B", [_flag_req("never_set_b")])
	var def := _chapter([stage_a, stage_b])

	# Neither stage's requirement is met, so get_current_stage() falls through to
	# the explicit fallback branch rather than the reverse-chronological match.
	var current := def.get_current_stage()
	assert_str(current.id).is_equal("A")


func test_get_current_stage_prefers_the_most_advanced_stage_whose_requirements_are_met() -> void:
	var stage_a := _stage("A")
	var stage_b := _stage("B", [_flag_req("reached_b")])
	var stage_c := _stage("C", [_flag_req("reached_c")])
	var def := _chapter([stage_a, stage_b, stage_c])

	GameState.set_flag("reached_b", true)
	assert_str(def.get_current_stage().id).is_equal("B")

	GameState.set_flag("reached_c", true)
	assert_str(def.get_current_stage().id).is_equal("C")


func test_get_current_stage_returns_null_when_the_chapter_has_no_stages() -> void:
	var def := _chapter([])
	assert_object(def.get_current_stage()).is_null()


func test_follow_up_stages_only_apply_once_their_condition_flag_is_true() -> void:
	var standard := _stage("STANDARD")
	var extended := _stage("EXTENDED", [_flag_req("unlock_extended")])
	var def := _chapter([standard], [extended])
	def.follow_up_condition_flag = "prototype_extended_content"

	assert_str(def.get_current_stage().id).is_equal("STANDARD")

	GameState.set_flag("unlock_extended", true)
	# Condition flag still false: follow-up stages must not be consulted yet.
	assert_str(def.get_current_stage().id).is_equal("STANDARD")

	GameState.set_flag("prototype_extended_content", true)
	assert_str(def.get_current_stage().id).is_equal("EXTENDED")


func test_get_title_falls_back_to_default_when_stage_title_is_empty_or_stage_is_null() -> void:
	var def := _chapter([_stage("A")])
	def.default_title = "DEFAULT"

	assert_str(def.get_title(null)).is_equal("DEFAULT")

	var untitled := _stage("UNTITLED")
	untitled.title = ""
	assert_str(def.get_title(untitled)).is_equal("DEFAULT")

	var titled := _stage("TITLED")
	titled.title = "STAGE TITLE"
	assert_str(def.get_title(titled)).is_equal("STAGE TITLE")


func test_get_objective_reports_unclear_for_a_null_stage_or_an_invalid_requirement() -> void:
	var def := _chapter([_stage("A")])
	assert_str(def.get_objective(null)).is_equal("Objective status unclear. Check journal.")

	var stage := _stage("B")
	stage.objective = "Should not be shown"
	var invalid_req := FactRequirement.new()
	invalid_req.type = FactRequirement.Type.QUEST_ACTIVE
	invalid_req.target_quest = null
	var reqs: Array[Resource] = [invalid_req]
	stage.requirements = reqs

	assert_str(def.get_objective(stage)).is_equal("Objective status unclear. Check journal.")


func test_get_objective_prefers_the_dynamic_objective_quest_when_present() -> void:
	var def := _chapter([_stage("A")])
	var stage := _stage("B")
	stage.objective = "Static objective text"
	stage.dynamic_objective_quest = QuestRegistry.FIELD_DEBT

	assert_str(def.get_objective(stage)).is_equal(
		QuestRegistry.objective_for(QuestRegistry.FIELD_DEBT)
	)


func test_get_objective_returns_the_static_objective_when_no_dynamic_quest_is_set() -> void:
	var def := _chapter([_stage("A")])
	var stage := _stage("B")
	stage.objective = "Static objective text"

	assert_str(def.get_objective(stage)).is_equal("Static objective text")


func test_get_destination_and_action_hint_are_empty_for_a_null_stage() -> void:
	var def := _chapter([_stage("A")])
	assert_str(def.get_destination(null)).is_equal("")
	assert_str(def.get_action_hint(null)).is_equal("")

	var stage := _stage("B")
	stage.destination_hint = "The grove"
	stage.action_hint = "Explore"
	assert_str(def.get_destination(stage)).is_equal("The grove")
	assert_str(def.get_action_hint(stage)).is_equal("Explore")


func test_is_complete_matches_only_the_designated_completion_stage_id() -> void:
	var def := _chapter([_stage("A"), _stage("B")])
	def.completion_stage_id = "B"

	assert_bool(def.is_complete(_stage("B"))).is_true()
	assert_bool(def.is_complete(_stage("A"))).is_false()
	assert_bool(def.is_complete(null)).is_false()


func test_a_null_requirement_blocks_a_stage_from_becoming_current() -> void:
	# A requirements array with a hole in it (an unassigned export slot in an
	# authored .tres) must refuse the stage, not crash and not pass it through.
	var reqs: Array[Resource] = [null]
	var stage_a := _stage("A")
	var stage_b := _stage("B", reqs)
	var def := _chapter([stage_a, stage_b])

	assert_str(def.get_current_stage().id).is_equal("A")


func test_a_null_requirement_makes_the_objective_unclear() -> void:
	var def := _chapter([_stage("A")])
	var stage := _stage("B")
	stage.objective = "Should not be shown"
	var reqs: Array[Resource] = [null]
	stage.requirements = reqs

	assert_str(def.get_objective(stage)).is_equal("Objective status unclear. Check journal.")


func test_a_partially_met_requirement_set_refuses_the_stage() -> void:
	# All requirements must hold, not any: one unmet entry disqualifies the stage.
	var reqs: Array[Resource] = [_flag_req("met_one"), _flag_req("unmet_one")]
	var def := _chapter([_stage("A"), _stage("B", reqs)])
	GameState.set_flag("met_one", true)

	assert_str(def.get_current_stage().id).is_equal("A")

	GameState.set_flag("unmet_one", true)
	assert_str(def.get_current_stage().id).is_equal("B")


func test_follow_up_stages_are_evaluated_in_reverse_order_too() -> void:
	var early := _stage("EARLY_FOLLOW_UP")
	var late := _stage("LATE_FOLLOW_UP", [_flag_req("reached_late")])
	var def := _chapter([_stage("STANDARD")], [early, late])
	def.follow_up_condition_flag = "extended"
	GameState.set_flag("extended", true)

	assert_str(def.get_current_stage().id).is_equal("EARLY_FOLLOW_UP")

	GameState.set_flag("reached_late", true)
	assert_str(def.get_current_stage().id).is_equal("LATE_FOLLOW_UP")


func test_an_active_follow_up_flag_with_no_matching_follow_up_stage_falls_through() -> void:
	var unreachable := _stage("UNREACHABLE", [_flag_req("never_set")])
	var def := _chapter([_stage("STANDARD")], [unreachable])
	def.follow_up_condition_flag = "extended"
	GameState.set_flag("extended", true)

	assert_str(def.get_current_stage().id).is_equal("STANDARD")


func test_an_active_follow_up_flag_with_an_empty_follow_up_list_falls_through() -> void:
	var def := _chapter([_stage("STANDARD")])
	def.follow_up_condition_flag = "extended"
	GameState.set_flag("extended", true)

	assert_str(def.get_current_stage().id).is_equal("STANDARD")


func test_a_follow_up_flag_holding_a_numeric_value_is_read_as_truthiness() -> void:
	# ⚠ NOT COVERED, DELIBERATELY: a String-valued follow-up condition flag.
	# get_current_stage() calls bool(GameState.get_flag(...)) and Godot 4 has
	# no bool(String) constructor, so a string-valued flag raises
	# "Nonexistent 'bool' constructor" and the whole method returns null.
	# Reported for a decision rather than encoded here as expected behaviour.
	var extended := _stage("EXTENDED")
	var def := _chapter([_stage("STANDARD")], [extended])
	def.follow_up_condition_flag = "extended"

	GameState.set_flag("extended", 0)
	assert_str(def.get_current_stage().id).is_equal("STANDARD")

	GameState.set_flag("extended", 1)
	assert_str(def.get_current_stage().id).is_equal("EXTENDED")


func test_an_empty_completion_stage_id_matches_a_blank_stage_id() -> void:
	# ⚠ DOCUMENTS CURRENT BEHAVIOUR, NOT AN ENDORSEMENT.
	# is_complete() compares ids without requiring completion_stage_id to be
	# configured, so an unconfigured chapter reports a blank-id stage as
	# complete. Every authored stage carries a non-empty id today, so this is
	# latent rather than live. Reported rather than fixed: adding an
	# is_empty() guard changes the contract's public behaviour.
	var def := _chapter([_stage("")])
	assert_str(def.completion_stage_id).is_equal("")
	assert_bool(def.is_complete(_stage(""))).is_true()
	assert_bool(def.is_complete(_stage("A"))).is_false()


func test_get_title_falls_back_when_the_chapter_has_no_default_title_either() -> void:
	var def := _chapter([_stage("A")])
	assert_str(def.default_title).is_equal("")
	assert_str(def.get_title(null)).is_equal("")


func _chapter(
	stages: Array[Resource], follow_up_stages: Array[Resource] = []
) -> ChapterDefinition:
	var def := ChapterDefinition.new()
	def.stages = stages
	def.follow_up_stages = follow_up_stages
	return def


func _stage(id: String, requirements: Array[Resource] = []) -> ChapterStageDefinition:
	var stage := ChapterStageDefinition.new()
	stage.id = id
	stage.requirements = requirements
	return stage


func _flag_req(flag: String) -> FactRequirement:
	var req := FactRequirement.new()
	req.type = FactRequirement.Type.FLAG_TRUE
	req.target_flag = flag
	return req
