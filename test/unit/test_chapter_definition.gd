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
