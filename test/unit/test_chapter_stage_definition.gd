extends GdUnitTestSuite
## Dedicated coverage for globals/chapter_stage_definition.gd (issue #69).
## ChapterStageDefinition is a plain data container consumed by ChapterDefinition
## (see test_chapter_definition.gd); this suite locks down its defaults and typing.


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
