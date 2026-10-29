class_name IzhakelThreads
extends ClassResource
## Threadwalker — Izhakel: Threads. Hidden contracts trigger when action data violates them.
##
## Conditions are data. Seam v2 broadcasts every resolved action so all actors can be watched.

const MAX_THREADS := 3  # B11, ratified 2026-10-25 (owner item 6).
const KIND_HOSTILITY := &"hostility"
const KIND_WITNESS := &"witness"
const KIND_DAYLIGHT := &"daylight"
## The Unspoken Term (#285 slice 4, ruled 2026-10-26): a Hostility contract keyed on a CAST.
const KIND_HOSTILITY_CAST := &"hostility_cast"

var threads: Array[Dictionary] = []


## The live cap: MAX_THREADS plus any picked `cap_delta` perk (Fourth Thread, #285 slice 2).
func max_threads() -> int:
	return MAX_THREADS + perk_total("cap_delta")


func commands() -> Array[StringName]:
	return [&"bind_hostility", &"bind_witness", &"bind_cast", &"cash_in"]


func query_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var gate := super.query_command(action_id, target_id, payload)
	if not bool(gate.allowed):
		return gate
	if action_id in [&"bind_cast", &"cash_in"]:
		var missing := perk_refusal("unspoken_term", "The Unspoken Term")
		if not missing.is_empty():
			return missing
	if action_id == &"cash_in":
		if target_id.is_empty() or _first_cashable(target_id) < 0:
			return command_refusal(&"no_contract", "That enemy carries no Hostility contract to cash in.")
		return gate
	if threads.size() >= max_threads():
		return command_refusal(&"class_resource_full", "All Threads are bound. Wait for a contract to trigger.")
	if target_id.is_empty() or host == null:
		return command_refusal(&"no_target", "Touch a living enemy to bind the contract.")
	var kind := _kind_of_command(action_id)
	if kind in [KIND_HOSTILITY, KIND_HOSTILITY_CAST] and (not payload.get("amount") is int or int(payload.amount) <= 0):
		return command_refusal(&"class_resource_payload", "The contract needs a positive payoff.")
	# Doubled Knot (#285 slice 3): the same contract may sit on one enemy twice.
	if contract_count(target_id, kind) >= maxi(perk_total("contract_twice"), 1):
		return command_refusal(&"class_resource_duplicate", "That enemy already carries this contract.")
	return gate


func execute_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> void:
	if not bool(query_command(action_id, target_id, payload).allowed):
		return
	if action_id == &"cash_in":
		cash_in(target_id)
		return
	# Known Contract (#285 slice 3): the bound enemy has heard what the thread costs.
	if perk_total("delay_on_bind") > 0 and host != null:
		host.delay_actor(target_id, perk_total("delay_on_bind"))
	match _kind_of_command(action_id):
		KIND_HOSTILITY_CAST:
			bind_thread(target_id, {"verb": CombatAction.Verb.CAST}, {
				"writes": [{"kind": "hp", "target_id": String(target_id), "amount": int(payload.amount)}],
			}, KIND_HOSTILITY_CAST)
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
	if target_id.is_empty() or condition.is_empty() or threads.size() >= max_threads():
		return false
	threads.append({
		"target_id": String(target_id),
		"condition": condition.duplicate(true),
		"payoff": payoff.duplicate(true),
		"kind": String(kind),
		"triggered": false,
	})
	return true


func contract_count(target_id: StringName, kind: StringName) -> int:
	var count := 0
	for thread: Dictionary in threads:
		if str(thread.get("target_id", "")) == String(target_id) and str(thread.get("kind", KIND_HOSTILITY)) == String(kind):
			count += 1
	return count


func has_contract(target_id: StringName, kind: StringName) -> bool:
	for thread: Dictionary in threads:
		if str(thread.get("target_id", "")) == String(target_id) and str(thread.get("kind", KIND_HOSTILITY)) == String(kind):
			return true
	return false


## Witness Weaver Tier 2 gate: a free Thread, no duplicate, and only one moving revelation.
func query_daylight(target_id: StringName) -> Dictionary:
	if threads.size() >= max_threads():
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
	match action_id:
		&"bind_witness":
			return KIND_WITNESS
		&"bind_cast":
			return KIND_HOSTILITY_CAST
	return KIND_HOSTILITY


## The Unspoken Term: fire one bound Hostility contract's payoff now and free its slot.
func cash_in(target_id: StringName) -> bool:
	var index := _first_cashable(target_id)
	if index < 0:
		return false
	var queued: Dictionary = enqueue_deferred(threads[index].get("payoff", {}), {"delay_rounds": 0}, &"thread")
	if not bool(queued.get("allowed", false)):
		return false
	threads.remove_at(index)
	return true


func _first_cashable(target_id: StringName) -> int:
	for index in threads.size():
		var thread: Dictionary = threads[index]
		if str(thread.get("target_id", "")) == String(target_id) and not bool(thread.get("triggered", false)) \
				and str(thread.get("kind", KIND_HOSTILITY)) in [String(KIND_HOSTILITY), String(KIND_HOSTILITY_CAST)]:
			return index
	return -1


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
		"max": max_threads(),
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
				if threads.size() >= max_threads():
					break
