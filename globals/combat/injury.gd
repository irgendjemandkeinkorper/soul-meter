class_name CombatInjury
extends RefCounted
## Bounded location injuries on a BattleActor (called-shots task 7, combat-local slice).
##
## A record lives in `BattleActor.injuries` keyed by location id. Bound rule (accepted
## 2026-09-19): ONE record per location. A second qualifying hit REFRESHES that record
## (`applications` +1, provenance updated) and never escalates severity or stacks penalties.
## Records are separate from elemental impositions and carry the authored effects they impose,
## so the resolver reads records, never a catalog. Persistence beyond combat is task 9.

const EFFECT_ATTACK_ACCURACY := "attack_accuracy_pp"
## Minor throat rule: percentage points paid by voice-tagged actions that roll to hit.
const EFFECT_VOCAL_ACCURACY := "vocal_accuracy_pp"
## Severe throat rule: actions that require an intact voice are refused until recovery.
const EFFECT_VOICE_BLOCKED := "voice_blocked"


## Applies `injury` (the resolver's finalized injury dict) to `target`. `source_key` is the
## committing action's provenance; replaying the same commit is a no-op, so a cached
## resolution applies its result exactly once.
static func apply(target: BattleActor, injury: Dictionary, source_key: String, tick: int) -> Dictionary:
	if target == null or injury.is_empty():
		return {"applied": false, "refreshed": false}
	var location := str(injury.get("location_id", ""))
	if location.is_empty():
		return {"applied": false, "refreshed": false}
	var existing: Dictionary = target.injuries.get(location, {})
	if not existing.is_empty() and str(existing.get("source_key", "")) == source_key:
		return {"applied": false, "refreshed": false, "replayed": true}
	if not existing.is_empty():
		existing["applications"] = int(existing.get("applications", 1)) + 1
		existing["source_key"] = source_key
		existing["refreshed_at_tick"] = tick
		target.injuries[location] = existing
		return {"applied": true, "refreshed": true, "record": existing.duplicate(true)}
	var record := {
		"injury_id": str(injury.get("id", "")),
		"location_id": location,
		"severity": str(injury.get("severity", "minor")),
		"effects": (injury.get("effects", {}) as Dictionary).duplicate(true),
		"applications": 1,
		"source_key": source_key,
		"applied_at_tick": tick,
		"refreshed_at_tick": tick,
		"recovery": "untreated",
	}
	target.injuries[location] = record
	return {"applied": true, "refreshed": false, "record": record.duplicate(true)}


## Accuracy terms a voice-tagged action pays. Nonvocal actions never see these.
static func vocal_accuracy_modifiers(actor: BattleActor) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	if actor == null:
		return modifiers
	for location: String in actor.injuries.keys():
		var record: Dictionary = actor.injuries[location]
		var points := int((record.get("effects", {}) as Dictionary).get(EFFECT_VOCAL_ACCURACY, 0))
		if points == 0:
			continue
		modifiers.append({
			"id": "injury", "label": "Injury: %s (voice)" % location.capitalize(),
			"percentage_points": points, "location_id": location,
		})
	return modifiers


## The record that currently blocks the actor's voice, or an empty dictionary. This is a
## physical injury contract: it never reads or writes the Muted imposition, whose Tempo
## meaning belongs to the spell-card rules.
static func voice_block(actor: BattleActor) -> Dictionary:
	if actor == null:
		return {}
	for location: String in actor.injuries.keys():
		var record: Dictionary = actor.injuries[location]
		if bool((record.get("effects", {}) as Dictionary).get(EFFECT_VOICE_BLOCKED, false)):
			return record
	return {}


## Accuracy terms an injured attacker pays on eligible attacks. Action-specific by design:
## base Alacrity is never touched, so timing and other derived behavior stay unchanged.
static func attack_accuracy_modifiers(actor: BattleActor) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	if actor == null:
		return modifiers
	for location: String in actor.injuries.keys():
		var record: Dictionary = actor.injuries[location]
		var effects: Dictionary = record.get("effects", {})
		var points := int(effects.get(EFFECT_ATTACK_ACCURACY, 0))
		if points == 0:
			continue
		modifiers.append({
			"id": "injury", "label": "Injury: %s" % location.capitalize(),
			"percentage_points": points, "location_id": location,
		})
	return modifiers
