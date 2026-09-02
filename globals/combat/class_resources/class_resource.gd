class_name ClassResource
extends RefCounted
## The seam every patron-class signature resource plugs into (roadmap Wave B, #223).
##
## One instance lives on each `BattleActor.class_resource`, attached by `CombatController.start()`
## from the actor's `PartyMember.patron` through `ClassResourceRegistry.for_patron()`. Actors with
## no patron (enemies, test dummies) get `NullClassResource`, so callers never null-check.
##
## Hooks are DISPATCHED BY THE CONTROLLER at its existing commit points — never by presentation,
## never by Resolution. A resource may mutate only its own state; anything it wants to change
## about a cast flows back through `on_cast_forecast()`'s returned context overrides, which the
## controller merges into the SAME context both forecast and commit use. That keeps
## forecast == resolution by construction: there is no second calculator.
##
## Contract detail and the B1–B10 authoring recipe: `docs/class-resources.md`.
## Numbers (caps, refund sizes, floors) belong to B11; anything hard-coded here is PROVISIONAL.

## Patron id this resource serves — the lower-case, diacritic-free form of `PartyMember.patron`
## (see `ClassResourceRegistry.normalize_patron()`), e.g. &"kero".
var patron_id: StringName = &""
## `BattleActor.combat_id` of the owner; set by the controller when attached.
var owner_id: StringName = &""


## Fires after every `action_resolved` event whose actor is the owner. `event.data` carries the
## full outcome dict (action_id, verb, resolution, ...). Use it to consume one-shot flags.
func on_action(_event: CombatEvent) -> void:
	pass


## Fires when an HP write reduces the owner's HP. `amount` is the positive HP lost;
## `source_id` is the attacker's combat id (may be empty for environmental damage).
func on_damage_taken(_amount: int, _source_id: StringName) -> void:
	pass


## Fires when a cast by the owner fizzles. `resolution` is the committed Resolution dict
## (`fizzled == true`, `fizzle_percent`, `fizzle_roll`, writes...). Read-only.
func on_fizzle(_resolution: Dictionary) -> void:
	pass


## Fires when an HP write by the owner takes a target from alive to 0 HP.
## `cause` is the action kind that did it: &"attack", &"cast", or &"defining_strike".
func on_kill(_target_id: StringName, _cause: StringName) -> void:
	pass


## Fires when the owner's turn begins (the controller's `turn_started` / enemy-turn beat),
## once per turn, not on AP continuations.
func on_turn_start() -> void:
	pass


## The ONLY channel back into resolution. Receives the context the controller is about to hand
## to `Resolution.resolve()` (read-only) and returns a dict of overrides merged on top of it —
## e.g. `{"to_hit_enabled": false}` for a guaranteed hit, or a `fizzle` sub-dict tweak. Return
## `{}` for no change. Called for forecast AND commit with identical input, so it must be pure
## with respect to its own state (do not consume flags here; consume them in `on_action`).
func on_cast_forecast(_context: Dictionary) -> Dictionary:
	return {}


## HUD-facing view: what the unit plate shows. Keep it small and stable.
func snapshot() -> Dictionary:
	return {"patron_id": String(patron_id)}


## Serialization — round-trips through `from_dict()`. Subclasses extend both.
func to_dict() -> Dictionary:
	return {"patron_id": String(patron_id), "owner_id": String(owner_id)}


func from_dict(data: Dictionary) -> void:
	patron_id = StringName(str(data.get("patron_id", String(patron_id))))
	owner_id = StringName(str(data.get("owner_id", String(owner_id))))


func is_null() -> bool:
	return false
