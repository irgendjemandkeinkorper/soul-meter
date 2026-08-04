class_name DomSideQuest
extends FlagQuest
## A choice-resolved Dom side quest attached to authored townsfolk hooks.
##
## QuestSystem owns active/completed pools, GameState owns durable evidence and
## resolution flags, and QuestRegistry is the only place that applies an
## outcome to the reputation ledger.

@export var stable_id: String = ""
@export var giver_actor_id: String = ""
@export var participant_actor_ids: PackedStringArray = []
@export var hook_ids: PackedStringArray = []
@export var dialogue_title: String = ""
@export_multiline var decision_prompt: String = ""
@export var resolution_flag: String = ""
@export var outcome_ids: PackedStringArray = []
@export var outcome_labels: PackedStringArray = []
@export var outcome_faction_ids: PackedStringArray = []
@export var outcome_reputation_deltas: PackedFloat32Array = []
@export var outcome_causes: PackedStringArray = []
@export var outcome_readbacks: PackedStringArray = []


func outcome_count() -> int:
	return outcome_ids.size()


func quest_id_record() -> Dictionary:
	return StableIds.quest(stable_id)


func giver_id_record() -> Dictionary:
	return StableIds.actor(giver_actor_id)


func participant_id_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for actor_id in participant_actor_ids:
		records.append(StableIds.actor(actor_id))
	return records


func hook_id_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for hook_id in hook_ids:
		records.append(StableIds.quest(hook_id))
	return records


func outcome_for(outcome_id: String) -> Dictionary:
	var index := outcome_ids.find(outcome_id)
	if index < 0 or not has_complete_outcome_schema():
		return {}
	return {
		"id": outcome_ids[index],
		"label": outcome_labels[index],
		"faction_id": outcome_faction_ids[index],
		"reputation_delta": outcome_reputation_deltas[index],
		"cause": outcome_causes[index],
		"readback": outcome_readbacks[index],
	}


func has_complete_outcome_schema() -> bool:
	var count := outcome_count()
	return (
		count >= 2
		and outcome_labels.size() == count
		and outcome_faction_ids.size() == count
		and outcome_reputation_deltas.size() == count
		and outcome_causes.size() == count
		and outcome_readbacks.size() == count
	)


func serialize() -> Dictionary:
	## Static authored metadata lives in the resource and must not be duplicated
	## into saves. Only mutable QuestSystem progress crosses the save boundary.
	return {
		"objective_completed": objective_completed,
		"current_stage": current_stage,
	}


func deserialize(data: Dictionary) -> void:
	objective_completed = bool(data.get("objective_completed", false))
	current_stage = clampi(int(data.get("current_stage", 0)), 0, required_flags.size())
