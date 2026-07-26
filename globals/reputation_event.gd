class_name ReputationEvent
extends RefCounted
## One immutable entry in the reputation ledger (docs/godot-architecture.md):
##   { actor, faction, delta, cause, scene, timestamp }
## Events are appended by Reputation.record() and NEVER mutated or deleted —
## standings are derived, and "why does this faction hate me" is a query.

var actor: String        ## who did it ("player", a party member id, …)
var faction: String      ## faction id — the lore vault's kebab id (e.g. "mirror-choir")
var delta: float         ## signed reputation change
var cause: String        ## human-readable, shown to the player ("Sided with the Backface")
var scene: String        ## where it happened (scene path or location id)
var at: int              ## unix timestamp (wall clock, for save forensics)
var order: int           ## monotonic sequence number — the authoritative ordering


func to_dict() -> Dictionary:
	return {
		"actor": actor, "faction": faction, "delta": delta,
		"cause": cause, "scene": scene, "at": at, "order": order,
	}


static func from_dict(d: Dictionary) -> ReputationEvent:
	var e := ReputationEvent.new()
	e.actor = d.get("actor", "")
	e.faction = d.get("faction", "")
	e.delta = d.get("delta", 0.0)
	e.cause = d.get("cause", "")
	e.scene = d.get("scene", "")
	e.at = int(d.get("at", 0))
	e.order = int(d.get("order", 0))
	return e
