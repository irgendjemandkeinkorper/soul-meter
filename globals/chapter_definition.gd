class_name ChapterDefinition
extends Resource
## ChapterDefinition — the progression and content contract for a chapter.

@export var id: String = ""
@export var default_title: String = ""
@export var stages: Array[Resource] = []
@export var follow_up_stages: Array[Resource] = []
@export var follow_up_condition_flag: String = ""
@export var completion_stage_id: String = ""


func get_current_stage() -> Resource:
	# Evaluate follow-up/extended stages first if conditions are met
	if not follow_up_condition_flag.is_empty() and bool(GameState.get_flag(follow_up_condition_flag, false)):
		for i in range(follow_up_stages.size() - 1, -1, -1):
			var stage := follow_up_stages[i]
			if _are_requirements_met(stage):
				return stage

	# Evaluate standard stages in reverse chronological order
	for i in range(stages.size() - 1, -1, -1):
		var stage := stages[i]
		if _are_requirements_met(stage):
			return stage

	# Return the first stage as fallback if nothing is met
	if not stages.is_empty():
		return stages[0]
	return null


func get_title(stage: Resource) -> String:
	if stage == null or stage.title.is_empty():
		return default_title
	return stage.title


func get_objective(stage: Resource) -> String:
	if stage == null:
		return "Objective status unclear. Check journal."

	# Verify that none of the requirements are invalid/incomplete
	for req in stage.requirements:
		if req == null or not req.is_valid():
			return "Objective status unclear. Check journal."

	if stage.dynamic_objective_quest != null:
		return QuestRegistry.objective_for(stage.dynamic_objective_quest)

	return stage.objective


func is_complete(stage: Resource) -> bool:
	return stage != null and stage.id == completion_stage_id


func _are_requirements_met(stage: Resource) -> bool:
	for req in stage.requirements:
		if req == null or not req.is_valid() or not req.is_met():
			return false
	return true
