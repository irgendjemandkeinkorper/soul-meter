class_name IzhakelThreads
extends ClassResource
## Threadwalker — Izhakel: Threads. Hidden contracts trigger when action data violates them.
##
## Conditions are data. The seam dispatches `on_action` only for the resource owner, not every
## actor, so cross-field evaluation remains a documented contract gap until that dispatch grows.

const MAX_THREADS := 3  # PROVISIONAL — B11 owns the cap

var threads: Array[Dictionary] = []


func bind_thread(target_id: StringName, condition: Dictionary, payoff: Dictionary) -> bool:
	if target_id.is_empty() or condition.is_empty() or threads.size() >= MAX_THREADS:
		return false
	threads.append({
		"target_id": String(target_id),
		"condition": condition.duplicate(true),
		"payoff": payoff.duplicate(true),
		"triggered": false,
	})
	return true


func on_action(event: CombatEvent) -> void:
	for thread: Dictionary in threads:
		if bool(thread.get("triggered", false)):
			continue
		if StringName(str(thread.get("target_id", ""))) != event.actor_id:
			continue
		var condition: Dictionary = thread.get("condition", {})
		if _matches_condition(event, condition):
			thread["triggered"] = true


func _matches_condition(event: CombatEvent, condition: Dictionary) -> bool:
	for key: String in condition:
		var expected: Variant = condition[key]
		var actual: Variant = event.data.get(key, null)
		if actual != expected:
			return false
	return true


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Threads",
		"value": threads.size(),
		"max": MAX_THREADS,
		"pending": threads.duplicate(true),
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["threads"] = threads.duplicate(true)
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	threads.clear()
	var raw_threads: Variant = data.get("threads", [])
	if raw_threads is Array:
		for raw_thread: Variant in raw_threads as Array:
			if raw_thread is Dictionary:
				threads.append((raw_thread as Dictionary).duplicate(true))
				if threads.size() >= MAX_THREADS:
					break
