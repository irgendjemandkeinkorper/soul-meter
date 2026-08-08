extends GdUnitTestSuite
## Dedicated coverage for globals/chapter_stage_definition.gd (issue #69).
## ChapterStageDefinition is a plain data container consumed by ChapterDefinition
## (see test_chapter_definition.gd); this suite locks down its defaults and typing.

var original_flags: Dictionary


func before_test() -> void:
	original_flags = GameState.flags.duplicate(true)
	GameState.flags.clear()


func after_test() -> void:
	GameState.flags = original_flags


func test_defaults_are_empty_strings_no_quest_and_no_requirements() -> void:
	var stage := ChapterStageDefinition.new()

	assert_str(stage.id).is_equal("")
	assert_str(stage.title).is_equal("")
	assert_str(stage.objective).is_equal("")
	assert_str(stage.destination_hint).is_equal("")
	assert_str(stage.action_hint).is_equal("")
	assert_object(stage.dynamic_objective_quest).is_null()
	assert_bool(stage.requirements.is_empty()).is_true()


func test_requirements_array_holds_the_assigned_fact_requirements_in_order() -> void:
	var stage := ChapterStageDefinition.new()
	var first := FactRequirement.new()
	first.type = FactRequirement.Type.FLAG_TRUE
	first.target_flag = "first_flag"
	var second := FactRequirement.new()
	second.type = FactRequirement.Type.FLAG_TRUE
	second.target_flag = "second_flag"

	var requirements: Array[Resource] = [first, second]
	stage.requirements = requirements

	assert_int(stage.requirements.size()).is_equal(2)
	assert_object(stage.requirements[0]).is_same(first)
	assert_object(stage.requirements[1]).is_same(second)


func test_dynamic_objective_quest_accepts_a_quest_resource() -> void:
	var stage := ChapterStageDefinition.new()
	stage.dynamic_objective_quest = QuestRegistry.FIELD_DEBT

	assert_object(stage.dynamic_objective_quest).is_same(QuestRegistry.FIELD_DEBT)


func test_is_a_plain_resource_and_participates_in_a_scene_level_round_trip() -> void:
	# ChapterStageDefinition has no custom serialize/deserialize of its own — its
	# round trip is Godot's generic Resource save, exercised here directly rather
	# than only implicitly through ChapterDefinition's higher-level tests.
	var stage := ChapterStageDefinition.new()
	stage.id = "ROUND_TRIP"
	stage.title = "Round Trip Title"
	stage.objective = "Round Trip Objective"
	stage.destination_hint = "Somewhere"
	stage.action_hint = "Do the thing"

	var path := "user://test_chapter_stage_definition_round_trip.tres"
	assert_int(ResourceSaver.save(stage, path)).is_equal(OK)
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(path)

	assert_object(loaded).is_not_null()
	assert_str(loaded.id).is_equal("ROUND_TRIP")
	assert_str(loaded.title).is_equal("Round Trip Title")
	assert_str(loaded.objective).is_equal("Round Trip Objective")
	assert_str(loaded.destination_hint).is_equal("Somewhere")
	assert_str(loaded.action_hint).is_equal("Do the thing")


func test_a_stage_reports_satisfaction_only_when_every_fact_requirement_is_met() -> void:
	# The stage itself has no predicate; satisfaction is reported by
	# ChapterDefinition reading stage.requirements. This is the contract the
	# stage's requirements array actually has to honour.
	var gated := _stage_with_flags(["needs_a", "needs_b"])
	var reachable := ChapterStageDefinition.new()
	reachable.id = "REACHABLE"
	var def := _chapter_with([reachable, gated])

	assert_str(def.get_current_stage().id).is_equal("REACHABLE")
	assert_str(def.get_objective(gated)).is_equal("Reach the stage")

	# One of two satisfied is still not satisfied.
	GameState.set_flag("needs_a", true)
	assert_str(def.get_current_stage().id).is_equal("REACHABLE")

	GameState.set_flag("needs_b", true)
	assert_object(def.get_current_stage()).is_same(gated)


func test_a_stage_holding_a_null_requirement_is_reported_as_unsatisfied() -> void:
	var stage := ChapterStageDefinition.new()
	stage.id = "HOLED"
	stage.objective = "Reach the stage"
	var reqs: Array[Resource] = [null]
	stage.requirements = reqs

	var reachable := ChapterStageDefinition.new()
	reachable.id = "REACHABLE"
	var def := _chapter_with([reachable, stage])

	# The holed stage is the most advanced, but its null requirement refuses it.
	assert_str(def.get_current_stage().id).is_equal("REACHABLE")
	assert_str(def.get_objective(stage)).is_equal("Objective status unclear. Check journal.")


func test_a_stage_with_an_invalid_fact_requirement_is_reported_as_unsatisfied() -> void:
	var stage := ChapterStageDefinition.new()
	stage.id = "INVALID_REQ"
	stage.objective = "Reach the stage"
	var broken := FactRequirement.new()
	broken.type = FactRequirement.Type.QUEST_DONE
	broken.target_quest = null
	var reqs: Array[Resource] = [broken]
	stage.requirements = reqs

	var reachable := ChapterStageDefinition.new()
	reachable.id = "REACHABLE"
	var def := _chapter_with([reachable, stage])

	assert_str(def.get_current_stage().id).is_equal("REACHABLE")


func test_a_round_trip_preserves_nested_fact_requirements() -> void:
	var stage := _stage_with_flags(["persisted_flag"])
	var path := "user://test_chapter_stage_definition_requirement_round_trip.tres"
	assert_int(ResourceSaver.save(stage, path)).is_equal(OK)
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(path)

	assert_object(loaded).is_not_null()
	assert_int(loaded.requirements.size()).is_equal(1)
	var req: FactRequirement = loaded.requirements[0]
	assert_int(req.type).is_equal(FactRequirement.Type.FLAG_TRUE)
	assert_str(req.target_flag).is_equal("persisted_flag")
	assert_bool(req.is_valid()).is_true()


func _stage_with_flags(flags: Array) -> ChapterStageDefinition:
	var stage := ChapterStageDefinition.new()
	stage.id = "GATED"
	stage.objective = "Reach the stage"
	var reqs: Array[Resource] = []
	for flag: String in flags:
		var req := FactRequirement.new()
		req.type = FactRequirement.Type.FLAG_TRUE
		req.target_flag = flag
		reqs.append(req)
	stage.requirements = reqs
	return stage


func _chapter_with(stages: Array[Resource]) -> ChapterDefinition:
	var def := ChapterDefinition.new()
	def.stages = stages
	return def
