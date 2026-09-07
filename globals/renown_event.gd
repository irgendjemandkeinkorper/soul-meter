class_name RenownEvent
extends RefCounted
## One immutable entry in the renown ledger (globals/renown.gd):
##   { actor, kind, delta, cause, scene, timestamp }
## Same append-only rule as ReputationEvent — never mutated or deleted.
##
## Yothmeru (RFC-0007, docs/architecture-dramgid.md §3.7) added the scaling
## record: `base` is what the author wrote, `applied` is what the meter actually
## moved by after the attribute multiplier, and `fame_shift` is the Fame figure
## the same act would produce. They are recorded on every event so the numeric
## pass can audit real play data rather than re-deriving it from prose.

## Every meter the ledger can carry. The event class owns this vocabulary rather
## than the autoload so `from_dict()` can validate a row without the singleton.
const KINDS: Array[StringName] = [&"reputation", &"infamy", &"karma", &"fame"]

var actor: String        ## who did it ("player", a party member id, …)
var kind: StringName     ## one of KINDS
var delta: float         ## signed change this event applies to its own meter
var cause: String        ## human-readable, shown to the player
var scene: String        ## where it happened (scene path or location id)
var at: int              ## unix timestamp (wall clock, for save forensics)
var order: int           ## monotonic sequence number — the authoritative ordering

## RFC-0007 §4. `base` is the authored magnitude before any multiplier; `applied`
## is `base` after the governing attribute scaled it. For Karma they differ (the
## Doctrine multiplier is live); for Reputation/Infamy they are equal, because
## scaling those would move the totals the tavern gates read — see Renown's
## header for why that is deliberate.
var base: float = 0.0
var applied: float = 0.0
## The Fame magnitude this act produces: `abs(base) × witness_factor × Decorum
## scale`. RECORDED, NOT YET SUMMED — `Renown.fame()` is `reputation + infamy`
## per §3.7. Present so owner ruling 9 can be settled against real numbers.
var fame_shift: float = 0.0
## How publicly the act landed (RFC-0007 §4). 1.0 is an ordinary witnessed act;
## 0.0 is the unwitnessed case the RFC names for banking Harmony.
var witness_factor: float = 1.0


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
	e.base = base
	e.applied = applied
	e.fame_shift = fame_shift
	e.witness_factor = witness_factor
	return e


func to_dict() -> Dictionary:
	return {
		"actor": actor, "kind": kind, "delta": delta,
		"cause": cause, "scene": scene, "at": at, "order": order,
		"base": base, "applied": applied,
		"fame_shift": fame_shift, "witness_factor": witness_factor,
	}


static func from_dict(d: Dictionary) -> RenownEvent:
	var e := RenownEvent.new()
	# SECURITY: Coerce values to expected types to avoid casting or reference issues with arbitrary payloads.
	e.actor = str(d.get("actor", ""))
	var kind_str := str(d.get("kind", "reputation"))
	# An unknown kind falls back to reputation rather than being dropped: the
	# ledger is append-only, so a row we cannot classify must still be replayed.
	e.kind = StringName(kind_str) if KINDS.has(StringName(kind_str)) else &"reputation"
	e.delta = float(d.get("delta", 0.0))
	e.cause = str(d.get("cause", ""))
	e.scene = str(d.get("scene", ""))
	e.at = int(d.get("at", 0))
	e.order = int(d.get("order", 0))
	# Additive Yothmeru keys: a pre-Yothmeru save has none, and for those rows
	# base == applied == delta is exactly what happened.
	e.base = float(d.get("base", e.delta))
	e.applied = float(d.get("applied", e.delta))
	e.fame_shift = float(d.get("fame_shift", 0.0))
	e.witness_factor = float(d.get("witness_factor", 1.0))
	return e
