class_name IzhakelThreads
extends ClassResource
## Threadwalker — Izhakel: Threads. Hidden contracts trigger when action data violates them.
##
## Conditions are data. Seam v2 broadcasts every resolved action so all actors can be watched.

const MAX_THREADS := 3  # PROVISIONAL — B11 owns the cap

var threads: Array[Dictionary] = []


func commands() -> Array[StringName]:
	return [&"bind_hostility"]


func query_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var gate := super.query_command(action_id, target_id, payload)
	if not bool(gate.allowed):
		return gate
	if threads.size() >= MAX_THREADS:
		return command_refusal(&"class_resource_full", "All Threads are bound. Wait for a contract to trigger.")
	if target_id.is_empty() or host == null:
		return command_refusal(&"no_target", "Touch a living enemy to bind the contract.")
	if not payload.get("amount") is int or int(payload.amount) <= 0:
		return command_refusal(&"class_resource_payload", "The contract needs a positive payoff.")
	for thread: Dictionary in threads:
		if str(thread.get("target_id", "")) == String(target_id) and thread.get("condition", {}) == {"verb": CombatAction.Verb.ATTACK}:
			return command_refusal(&"class_resource_duplicate", "That enemy already carries this contract.")
	return gate


func execute_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> void:
	if not bool(query_command(action_id, target_id, payload).allowed):
		return
	bind_thread(target_id, {"verb": CombatAction.Verb.ATTACK}, {
		"writes": [{"kind": "hp", "target_id": String(target_id), "amount": int(payload.amount)}],
	})


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


func on_any_action(
	actor_id: StringName, _action_id: StringName, _target_id: StringName, outcome: Dictionary
) -> void:
	var event := CombatEvent.new()
	event.actor_id = actor_id
	event.data = outcome
	var pending: Array[Dictionary] = []
	for thread: Dictionary in threads:
		if bool(thread.get("triggered", false)):
			continue
		if StringName(str(thread.get("target_id", ""))) != event.actor_id:
			pending.append(thread)
			continue
		var condition: Dictionary = thread.get("condition", {})
		if _matches_condition(event, condition):
			var payoff: Dictionary = thread.get("payoff", {})
			var queued: Dictionary = enqueue_deferred(payoff, {"delay_rounds": 0}, &"thread")
			if bool(queued.get("allowed", false)):
				thread["triggered"] = true
		if not bool(thread.get("triggered", false)):
			pending.append(thread)
	threads = pending


func on_combatant_fell(target_id: StringName) -> void:
	for index in range(threads.size() - 1, -1, -1):
		if StringName(str(threads[index].get("target_id", ""))) == target_id:
			threads.remove_at(index)


func take_triggered() -> Array[Dictionary]:
	var triggered: Array[Dictionary] = []
	var pending: Array[Dictionary] = []
	for thread: Dictionary in threads:
		if bool(thread.get("triggered", false)):
			triggered.append(thread.duplicate(true))
		else:
			pending.append(thread)
	threads = pending
	return triggered


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
