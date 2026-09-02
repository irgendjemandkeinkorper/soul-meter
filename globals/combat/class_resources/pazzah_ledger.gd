class_name PazzahLedger
extends ClassResource
## Oathclock — Pazzah: The Ledger. Effects wait for a future CT/turn checkpoint.
##
## Vault `systems/magic-system.md` §Per-class resources: "Queue an effect to resolve N turns
## later regardless of what happens between." The current seam has no scheduler callback for
## an owner-independent CT entry, so `advance_ledger()` is an explicit model hook for now.

const MAX_ENTRIES := 3  # PROVISIONAL — B11 owns the cap

var entries: Array[Dictionary] = []


func queue_effect(effect_id: StringName, turns: int, payload: Dictionary = {}) -> bool:
	if effect_id.is_empty() or turns <= 0 or entries.size() >= MAX_ENTRIES:
		return false
	entries.append({
		"effect_id": String(effect_id),
		"turns_remaining": turns,
		"payload": payload.duplicate(true),
	})
	return true


func on_turn_start() -> void:
	advance_ledger()


func advance_ledger() -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	var pending: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var remaining := int(entry.get("turns_remaining", 0)) - 1
		if remaining <= 0:
			resolved.append(entry.duplicate(true))
		else:
			var next := entry.duplicate(true)
			next["turns_remaining"] = remaining
			pending.append(next)
	entries = pending
	return resolved


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Ledger",
		"value": entries.size(),
		"max": MAX_ENTRIES,
		"pending": entries.duplicate(true),
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["entries"] = entries.duplicate(true)
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	entries.clear()
	var raw_entries: Variant = data.get("entries", [])
	if raw_entries is Array:
		for raw_entry: Variant in raw_entries as Array:
			if raw_entry is Dictionary:
				entries.append((raw_entry as Dictionary).duplicate(true))
				if entries.size() >= MAX_ENTRIES:
					break
