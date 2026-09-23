class_name IzhakelThreads
extends ClassResource
## Threadwalker — Izhakel: Threads. Hidden contracts trigger when action data violates them.
##
## Conditions are data. Seam v2 broadcasts every resolved action so all actors can be watched.

const MAX_THREADS := 3  # PROVISIONAL — B11 owns the cap
const KIND_HOSTILITY := &"hostility"
const KIND_WITNESS := &"witness"
const KIND_DAYLIGHT := &"daylight"

var threads: Array[Dictionary] = []


func commands() -> Array[StringName]:
	return [&"bind_hostility", &"bind_witness"]


func query_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var gate := super.query_command(action_id, target_id, payload)
	if not bool(gate.allowed):
		return gate
	if threads.size() >= MAX_THREADS:
		return command_refusal(&"class_resource_full", "All Threads are bound. Wait for a contract to trigger.")
	if target_id.is_empty() or host == null:
		return command_refusal(&"no_target", "Touch a living enemy to bind the contract.")
	var kind := _kind_of_command(action_id)
	if kind == KIND_HOSTILITY and (not payload.get("amount") is int or int(payload.amount) <= 0):
		return command_refusal(&"class_resource_payload", "The contract needs a positive payoff.")
	if has_contract(target_id, kind):
		return command_refusal(&"class_resource_duplicate", "That enemy already carries this contract.")
	return gate


func execute_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> void:
	if not bool(query_command(action_id, target_id, payload).allowed):
		return
	match _kind_of_command(action_id):
		KIND_HOSTILITY:
			bind_thread(target_id, {"verb": CombatAction.Verb.ATTACK}, {
				"writes": [{"kind": "hp", "target_id": String(target_id), "amount": int(payload.amount)}],
			}, KIND_HOSTILITY)
		KIND_WITNESS:
			# Witness Weaver Tier 1: the payoff is information, never damage — Exposed on the
			# target and its casting signature torn open (S3).
			bind_thread(target_id, {"verb": CombatAction.Verb.ATTACK}, {
				"writes": [
					{"kind": "reveal_signature", "target_id": String(target_id)},
					{"kind": "exposed", "target_id": String(target_id), "checkpoints": int(payload.get("checkpoints", 2))},
				],
			}, KIND_WITNESS)


func bind_thread(target_id: StringName, condition: Dictionary, payoff: Dictionary, kind: StringName = KIND_HOSTILITY) -> bool:
	if target_id.is_empty() or condition.is_empty() or threads.size() >= MAX_THREADS:
		return false
	threads.append({
		"target_id": String(target_id),
		"condition": condition.duplicate(true),
		"payoff": payoff.duplicate(true),
		"kind": String(kind),
		"triggered": false,
	})
	return true


func has_contract(target_id: StringName, kind: StringName) -> bool:
	for thread: Dictionary in threads:
		if str(thread.get("target_id", "")) == String(target_id) and str(thread.get("kind", KIND_HOSTILITY)) == String(kind):
			return true
	return false


## Witness Weaver Tier 2 gate: a free Thread, no duplicate, and only one moving revelation.
func query_daylight(target_id: StringName) -> Dictionary:
	if threads.size() >= MAX_THREADS:
		return command_refusal(&"class_resource_full", "All Threads are bound. Wait for a contract to trigger.")
	if has_contract(target_id, KIND_DAYLIGHT):
		return command_refusal(&"class_resource_duplicate", "That enemy already carries a Term of Daylight.")
	for thread: Dictionary in threads:
		if str(thread.get("kind", "")) == String(KIND_DAYLIGHT):
			return command_refusal(&"one_revelation", "Only one moving revelation at a time.")
	return {"allowed": true, "blocked_by": &"", "nearest_unblock": {}, "message": ""}


## Condition: the target's next MOVE that ends inside `field_id`. Payoff: the field's
## revelation follows the creature for one checkpoint (radius 0).
func bind_daylight(target_id: StringName, field_id: int) -> bool:
	if not bool(query_daylight(target_id).get("allowed", false)):
		return false
	return bind_thread(target_id, {"verb": CombatAction.Verb.MOVE, "ended_in_light": field_id}, {
		"writes": [{"kind": "lit", "target_id": String(target_id), "field_id": field_id, "checkpoints": 1}],
	}, KIND_DAYLIGHT)


## Noon Contract: hands back the Witness payoffs bound on `target_id` and frees those slots.
func release_witness(target_id: StringName) -> Array[Dictionary]:
	var payoffs: Array[Dictionary] = []
	var pending: Array[Dictionary] = []
	for thread: Dictionary in threads:
		if str(thread.get("target_id", "")) == String(target_id) and str(thread.get("kind", "")) == String(KIND_WITNESS):
			payoffs.append((thread.get("payoff", {}) as Dictionary).duplicate(true))
		else:
			pending.append(thread)
	threads = pending
	return payoffs


static func _kind_of_command(action_id: StringName) -> StringName:
	return KIND_WITNESS if action_id == &"bind_witness" else KIND_HOSTILITY


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
