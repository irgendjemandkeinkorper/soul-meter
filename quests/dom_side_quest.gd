class_name DomSideQuest
extends FlagQuest
## A choice-resolved Dom side quest attached to authored townsfolk hooks.
##
## QuestSystem owns active/completed pools, GameState owns durable evidence and
## resolution flags, and QuestRegistry is the only place that applies an
## outcome to the reputation ledger.

const ACT_OF_AGREEMENT_TAG := "act_of_agreement"

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
## Optional parallel reward metadata. Empty arrays preserve every existing resource.
@export var outcome_tags: Array[PackedStringArray] = []
@export var outcome_soul_deltas: PackedFloat32Array = []


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
		"tags": outcome_tags[index].duplicate() if not outcome_tags.is_empty() else PackedStringArray(),
		"soul_delta": outcome_soul_deltas[index] if not outcome_soul_deltas.is_empty() else 0.0,
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
		and has_valid_reward_schema()
	)


func has_valid_reward_schema() -> bool:
	if outcome_tags.is_empty() and outcome_soul_deltas.is_empty():
		return true
	if outcome_tags.size() != outcome_count() or outcome_soul_deltas.size() != outcome_count():
		return false
	for index in outcome_count():
		var seen_tags: Dictionary = {}
		for tag: String in outcome_tags[index]:
			var normalized := tag.strip_edges()
			if normalized.is_empty() or seen_tags.has(normalized):
				return false
			seen_tags[normalized] = true
		var soul_delta := outcome_soul_deltas[index]
		if not is_finite(soul_delta) or soul_delta < 0.0:
			return false
		var is_agreement := outcome_tags[index].has(ACT_OF_AGREEMENT_TAG)
		if is_agreement != (soul_delta > 0.0):
			return false
	return true


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
