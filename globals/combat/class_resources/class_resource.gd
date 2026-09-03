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
## Seam v2: the controller this resource is attached to. Set by the controller when attached
## (never by a subclass). It is the target of the v2 request helpers below — `enqueue_deferred()`
## and `request_cancel()` — and is null for a resource that lives outside a battle (unit tests,
## a save being restored before `Battle.start()`), in which case those helpers refuse.
var host: CombatController = null


## Fires after every `action_resolved` event whose actor is the owner. `event.data` carries the
## full outcome dict (action_id, verb, resolution, ...). Use it to consume one-shot flags.
func on_action(_event: CombatEvent) -> void:
	pass


## Optional command channel for authored PASS-kind class-resource actions.
func on_command(_action_id: StringName, _target_id: StringName) -> void:
	pass


## Seam v2 broadcast: fires on EVERY actor's resource for EVERY `action_resolved` event, after the
## owner's `on_action`. `actor_id` is who acted, `action_id` the `CombatAction` id (&"strike",
## &"move", ...), `target_id` the declared target (may be empty), `outcome` the same outcome dict
## `on_action` receives (`resolution`, `verb`, `damage`, ...). Threadwalker Threads watches other
## actors through this; the owner's own actions arrive here too, so guard on `actor_id` if needed.
func on_any_action(
	_actor_id: StringName, _action_id: StringName, _target_id: StringName, _outcome: Dictionary
) -> void:
	pass


## Seam v2: fires on the SOURCE resource when one of its deferred entries fires (after the
## writes were applied). `entry` is the queued dict plus `"applied": [materialized writes]`.
func on_deferred_fired(_entry: Dictionary) -> void:
	pass


## Seam v2: fires on the SOURCE resource when one of its deferred entries was cancelled by
## `CombatController.request_cancel()` (Jam the Gears), before the `action_cancelled` event.
func on_deferred_cancelled(_entry: Dictionary, _by_id: StringName) -> void:
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


## Seam v2 request: queue an effect the controller fires later, at a scheduler boundary, through
## the SAME write-application path Resolution writes take (`_apply_resolution_writes`), so it is
## deterministic and replayable. `effect` is `{"writes": [{kind, target_id, delta|amount, ...}]}`
## (kinds: hp, dot, breath, soul_refund, soul_meter, tile_state; before/after are materialized
## at fire time from live state). `due` is one of `{"delay_ticks": n}` / `{"due_tick": t}`
## (charge-time clock) or `{"delay_rounds": n}` / `{"due_round": r}` (AP rounds). Returns the
## controller's refusal shape; `entry.id` on success. Oathclock Ledger's channel.
func enqueue_deferred(effect: Dictionary, due: Dictionary, label: StringName = &"") -> Dictionary:
	if host == null:
		return {"allowed": false, "blocked_by": "no_host", "message": "Resource is not attached to a battle.", "nearest_unblock": {}}
	var entry := due.duplicate(true)
	entry["source_id"] = String(owner_id)
	entry["effect"] = effect.duplicate(true)
	entry["label"] = String(label)
	return host.enqueue_deferred(entry)


## Seam v2 request: cancel what `target_id` has in flight. `kind` is &"deferred" (that actor's
## queued deferred entries), &"committed" (its committed-but-unresolved scheduler action — a
## charging Song under charge time), or &"any" (both). Locksmirk Jam the Gears' channel.
func request_cancel(target_id: StringName, kind: StringName = &"any") -> Dictionary:
	if host == null:
		return {"allowed": false, "blocked_by": "no_host", "message": "Resource is not attached to a battle.", "nearest_unblock": {}}
	return host.request_cancel(owner_id, target_id, kind)


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
