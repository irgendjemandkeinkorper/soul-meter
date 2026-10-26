class_name PazzahLedger
extends ClassResource
## Oathclock — Pazzah: The Ledger. Effects wait for a future CT/turn checkpoint.
##
## Vault `systems/magic-system.md` §Per-class resources: "Queue an effect to resolve N turns
## later regardless of what happens between." The controller owns the deferred scheduler;
## this resource only records its entries and completion events.

const MAX_ENTRIES := 3  # PROVISIONAL — B11 owns the cap

var entries: Array[Dictionary] = []
var ready: Array[Dictionary] = []


## The live cap: MAX_ENTRIES plus any picked `cap_delta` perk (Longer Docket, #285 slice 2).
func max_entries() -> int:
	return MAX_ENTRIES + perk_total("cap_delta")


func commands() -> Array[StringName]:
	return [&"file_sentence"]


func query_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var gate := super.query_command(action_id, target_id, payload)
	if not bool(gate.allowed):
		return gate
	if entries.size() >= max_entries():
		return command_refusal(&"class_resource_full", "The Ledger is full. Wait for a sentence to resolve.")
	if target_id.is_empty() or host == null:
		return command_refusal(&"no_target", "Choose a living enemy for the sentence.")
	if not payload.get("amount") is int or int(payload.amount) <= 0 or not payload.get("delay_rounds") is int or int(payload.delay_rounds) <= 0:
		return command_refusal(&"class_resource_payload", "The sentence needs positive damage and a future round.")
	return gate


func execute_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> void:
	if not bool(query_command(action_id, target_id, payload).allowed):
		return
	queue_effect(action_id, int(payload.delay_rounds), {
		"writes": [{"kind": "hp", "target_id": String(target_id), "amount": int(payload.amount)}],
	})


func queue_effect(effect_id: StringName, turns: int, payload: Dictionary = {}) -> bool:
	if effect_id.is_empty() or turns <= 0 or entries.size() >= max_entries():
		return false
	var raw_writes: Variant = payload.get("writes", [])
	if not raw_writes is Array or (raw_writes as Array).is_empty():
		return false
	# Prompt Court (#285 slice 3): due one round sooner, never sooner than the next round.
	var due := {"delay_rounds": maxi(turns - perk_total("sentence_sooner"), 1)}
	# Public Verdict (#285 slice 3): filed with an ally adjacent, the Sentence cannot be Jammed.
	if perk_total("unjammable_with_ally_adjacent") > 0 and host != null and host.allies_within(owner_id, 1) > 0:
		due["unjammable"] = true
	var queued: Dictionary = enqueue_deferred(
		{"writes": (raw_writes as Array).duplicate(true)}, due, effect_id
	)
	if not bool(queued.get("allowed", false)):
		return false
	var deferred_entry: Dictionary = queued.get("entry", {})
	entries.append({
		"effect_id": String(effect_id),
		"entry_id": int(deferred_entry.get("id", 0)),
		"payload": payload.duplicate(true),
	})
	return true


func on_deferred_fired(entry: Dictionary) -> void:
	var fired_id := int(entry.get("id", 0))
	for pending: Dictionary in entries:
		if int(pending.get("entry_id", 0)) == fired_id:
			ready.append(pending.duplicate(true))
			entries.erase(pending)
			return


func on_deferred_cancelled(entry: Dictionary, _by_id: StringName) -> void:
	var cancelled_id := int(entry.get("id", 0))
	for pending: Dictionary in entries:
		if int(pending.get("entry_id", 0)) == cancelled_id:
			entries.erase(pending)
			return


func drain_ready() -> Array[Dictionary]:
	var resolved: Array[Dictionary] = ready.duplicate(true)
	ready.clear()
	return resolved


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Ledger",
		"value": entries.size(),
		"max": max_entries(),
		"pending": entries.duplicate(true),
		"ready": ready.duplicate(true),
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["entries"] = entries.duplicate(true)
	data["ready"] = ready.duplicate(true)
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	entries.clear()
	ready.clear()
	var raw_entries: Variant = data.get("entries", [])
	if raw_entries is Array:
		for raw_entry: Variant in raw_entries as Array:
			if raw_entry is Dictionary:
				entries.append((raw_entry as Dictionary).duplicate(true))
				if entries.size() >= max_entries():
					break
	var raw_ready: Variant = data.get("ready", [])
	if raw_ready is Array:
		for raw_entry: Variant in raw_ready as Array:
			if raw_entry is Dictionary:
				ready.append((raw_entry as Dictionary).duplicate(true))
