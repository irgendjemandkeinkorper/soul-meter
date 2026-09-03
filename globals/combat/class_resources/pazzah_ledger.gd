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


func queue_effect(effect_id: StringName, turns: int, payload: Dictionary = {}) -> bool:
	if effect_id.is_empty() or turns <= 0 or entries.size() >= MAX_ENTRIES:
		return false
	var raw_writes: Variant = payload.get("writes", [])
	if not raw_writes is Array or (raw_writes as Array).is_empty():
		return false
	var queued: Dictionary = enqueue_deferred(
		{"writes": (raw_writes as Array).duplicate(true)}, {"delay_rounds": turns}, effect_id
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
		"max": MAX_ENTRIES,
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
				if entries.size() >= MAX_ENTRIES:
					break
	var raw_ready: Variant = data.get("ready", [])
	if raw_ready is Array:
		for raw_entry: Variant in raw_ready as Array:
			if raw_entry is Dictionary:
				ready.append((raw_entry as Dictionary).duplicate(true))
