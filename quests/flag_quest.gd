class_name FlagQuest
extends Quest
## Ordered story quest whose progress is derived from durable GameState flags.

@export var required_flags: PackedStringArray = []
@export var objectives: PackedStringArray = []
@export var quest_giver: String = ""
@export var quest_location: String = ""
var current_stage := 0


func update(_args: Dictionary = {}) -> void:
	current_stage = 0
	for flag in required_flags:
		if not GameState.get_flag(flag):
			break
		current_stage += 1
	objective_completed = current_stage >= required_flags.size()
	super.update(_args)


func current_objective() -> String:
	if objectives.is_empty():
		return quest_objective
	return objectives[mini(current_stage, objectives.size() - 1)]
