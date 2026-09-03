class_name StuidClarity
extends ClassResource
## Lensbearer — Stuid: Clarity. A depleting reserve burned to expose one forecast.
##
## Vault `systems/magic-system.md` §Per-class resources: "A depleting stat burned for
## guaranteed information (true fizzle %, hidden resistances, traps)."
##
## The armed reveal is returned through the shared forecast context and consumed only after
## the owner's cast outcome is committed.

const MAX_CLARITY := 3  # PROVISIONAL — B11 owns the cap

var clarity: int = MAX_CLARITY
var reveal_armed: bool = false


func spend_clarity() -> bool:
	if clarity <= 0 or reveal_armed:
		return false
	clarity -= 1
	reveal_armed = true
	return true


func on_cast_forecast(_context: Dictionary) -> Dictionary:
	if not reveal_armed:
		return {}
	return {"reveal": true}


func on_action(event: CombatEvent) -> void:
	if not reveal_armed or event.actor_id != owner_id:
		return
	var data: Dictionary = event.data
	var action_verb: Variant = data.get("verb", null)
	var action_kind: Variant = data.get("kind", null)
	if action_verb != CombatAction.Verb.CAST and action_kind != CombatAction.Kind.CAST:
		return
	if data.has("resolution") and not (data.get("resolution", {}) as Dictionary).is_empty():
		reveal_armed = false


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Clarity",
		"value": clarity,
		"max": MAX_CLARITY,
		"armed": reveal_armed,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["clarity"] = clarity
	data["reveal_armed"] = reveal_armed
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	clarity = clampi(int(data.get("clarity", MAX_CLARITY)), 0, MAX_CLARITY)
	reveal_armed = bool(data.get("reveal_armed", false))
