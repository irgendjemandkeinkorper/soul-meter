class_name CombatEvent
extends Resource
## Immutable-by-convention presentation handoff. Consumers reconstruct their
## view from this stream and never need resolver-specific callbacks.

var sequence: int = 0
var type: StringName = &""
var actor_id: StringName = &""
var target_id: StringName = &""
var data: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"sequence": sequence,
		"type": type,
		"actor_id": actor_id,
		"target_id": target_id,
		"data": data.duplicate(true),
	}
