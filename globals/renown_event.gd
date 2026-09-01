class_name RenownEvent
extends RefCounted
## One immutable entry in the renown ledger (globals/renown.gd):
##   { actor, kind, delta, cause, scene, timestamp }
## Same append-only rule as ReputationEvent — never mutated or deleted.

var actor: String        ## who did it ("player", a party member id, …)
var kind: StringName     ## &"reputation" or &"infamy" — which meter this delta hit
var delta: float         ## signed change (usually positive; the meter itself never goes down)
var cause: String        ## human-readable, shown to the player
var scene: String        ## where it happened (scene path or location id)
var at: int              ## unix timestamp (wall clock, for save forensics)
var order: int           ## monotonic sequence number — the authoritative ordering


## A detached copy — see ReputationEvent.copy() for why every ledger read returns
## copies rather than the stored event.
func copy() -> RenownEvent:
	var e := RenownEvent.new()
	e.actor = actor
	e.kind = kind
	e.delta = delta
	e.cause = cause
	e.scene = scene
	e.at = at
	e.order = order
	return e


func to_dict() -> Dictionary:
	return {
		"actor": actor, "kind": kind, "delta": delta,
		"cause": cause, "scene": scene, "at": at, "order": order,
	}


static func from_dict(d: Dictionary) -> RenownEvent:
	var e := RenownEvent.new()
	# SECURITY: Coerce values to expected types to avoid casting or reference issues with arbitrary payloads.
	e.actor = str(d.get("actor", ""))
	var kind_str := str(d.get("kind", "reputation"))
	e.kind = &"infamy" if kind_str == "infamy" else &"reputation"
	e.delta = float(d.get("delta", 0.0))
	e.cause = str(d.get("cause", ""))
	e.scene = str(d.get("scene", ""))
	e.at = int(d.get("at", 0))
	e.order = int(d.get("order", 0))
	return e
