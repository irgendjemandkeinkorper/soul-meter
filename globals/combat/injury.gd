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
## Leg rule (task 11 legs slice): percent added to the priced cost of every move, expressed
## through whichever scheduler is active (AP units or CT). Never immobility.
const EFFECT_MOVE_COST_PERCENT := "move_cost_percent"
## Head/eyes rule (task 11 head slice): percentage points paid by shots that depend on sight —
## ranged non-spell attacks and every aimed attack. Melee swings at the body pay nothing.
const EFFECT_SIGHT_ACCURACY := "sight_accuracy_pp"
## Persistence rule (user decision 2026-09-17): serious injuries outlive combat until treated.
## Minor injuries are combat-local under the current authored rule (duration unsettled) and are
## dropped at every combat end: victory, defeat, flee, and same-map session end.
const PERSISTENT_SEVERITY := "serious"
## Save keys every stored record must carry. Anything else inside a record is preserved
## verbatim (unknown-record policy: keep what we do not understand, never invent or drop it).
const REQUIRED_RECORD_KEYS: Array[String] = ["injury_id", "location_id"]


## Stable identity of a record: instance id plus revision (its application count).
static func record_identity(record: Dictionary) -> Dictionary:
	return {
		"instance_id": str(record.get("instance_id", "")),
		"revision": int(record.get("applications", 1)),
	}


## Records that outlive combat, keyed by location. Pure; the input is untouched.
static func persistent_records(injuries: Dictionary) -> Dictionary:
	var kept: Dictionary = {}
	for location: Variant in injuries.keys():
		var record: Variant = injuries[location]
		if record is Dictionary and str((record as Dictionary).get("severity", "minor")) == PERSISTENT_SEVERITY:
			kept[str(location)] = (record as Dictionary).duplicate(true)
	return kept


## Loads records from a save. Old saves have no key and load with no injuries. A record
## missing a stable id is malformed and dropped; ids are plain strings, so a data rename
## must ship its own migration under SaveMigrations rather than silently re-keying here.
static func records_from_save(raw: Variant) -> Dictionary:
	var loaded: Dictionary = {}
	if not raw is Dictionary:
		return loaded
	for location: Variant in (raw as Dictionary).keys():
		var record: Variant = (raw as Dictionary)[location]
		if not record is Dictionary:
			continue
		var complete := true
		for key: String in REQUIRED_RECORD_KEYS:
			if str((record as Dictionary).get(key, "")).is_empty():
				complete = false
		if not complete:
			continue
		var copy: Dictionary = (record as Dictionary).duplicate(true)
		if not copy.get("effects") is Dictionary:
			copy["effects"] = {}
		loaded[str(location)] = copy
	return loaded


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
		# Instance identity (task 10): distinguishes this wound from a later one at the same
		# location. `applications` is its revision; a refresh bumps it so stale quotes reject.
		"instance_id": "%s@%s|%s" % [str(injury.get("id", "")), location, source_key],
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


## Movement cost terms an injured mover pays, in percent of the path price. Bounded by the
## one-record-per-location rule, so a refreshed leg never compounds.
static func move_cost_modifiers(actor: BattleActor) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	if actor == null:
		return modifiers
	for location: String in actor.injuries.keys():
		var record: Dictionary = actor.injuries[location]
		var percent := int((record.get("effects", {}) as Dictionary).get(EFFECT_MOVE_COST_PERCENT, 0))
		if percent == 0:
			continue
		modifiers.append({
			"id": "injury", "label": "Injury: %s (movement)" % location.capitalize(),
			"percent": percent, "location_id": location,
		})
	return modifiers


## Multiplier applied to a path's CT price before scheduler pricing; 1.0 when unhurt.
static func move_cost_multiplier(actor: BattleActor) -> float:
	var percent := 0
	for modifier: Dictionary in move_cost_modifiers(actor):
		percent += int(modifier["percent"])
	return maxf(0.0, 1.0 + float(percent) / 100.0)


## Accuracy terms an attacker with impaired sight pays on sight-dependent shots. Separate from
## Blinded and from physical visibility: a different physical cause, never a second charge of
## either of those.
static func sight_accuracy_modifiers(actor: BattleActor) -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	if actor == null:
		return modifiers
	for location: String in actor.injuries.keys():
		var record: Dictionary = actor.injuries[location]
		var points := int((record.get("effects", {}) as Dictionary).get(EFFECT_SIGHT_ACCURACY, 0))
		if points == 0:
			continue
		modifiers.append({
			"id": "injury", "label": "Injury: %s (sight)" % location.capitalize(),
			"percentage_points": points, "location_id": location,
		})
	return modifiers
