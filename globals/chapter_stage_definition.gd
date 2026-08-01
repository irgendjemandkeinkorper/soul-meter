class_name ChapterStageDefinition
extends Resource
## ChapterStageDefinition — a single generic chapter stage in the progression contract.

@export var id: String = ""
@export var title: String = ""
@export var objective: String = ""
@export var destination_hint: String = ""
@export var action_hint: String = ""
@export var dynamic_objective_quest: Quest = null
@export var requirements: Array[Resource] = []
