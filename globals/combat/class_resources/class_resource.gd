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
## Numbers (caps, refund sizes, floors) belong to B11 (`docs/class-resources-numbers.md`,
## ratified 2026-10-25); a new number added here is PROVISIONAL until B11 covers it.

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
## #285 slice 2: the owner's picked perks (`PartyMember.perk_ids`), set by the controller when
## attached and carried through `to_dict()` so a restored battle keeps them. A resource reads
## them only through `perk_total()`; the op and value live in canon (`PerkCatalog.EFFECT_OPS`).
var perk_ids: PackedStringArray = []


## Called by the controller when attached. Subclasses react in `_on_perks_applied()`.
func apply_perks(ids: PackedStringArray) -> void:
	perk_ids = ids.duplicate()
	_on_perks_applied()


## Sum of the picked perks' `effect_value` for `op`; 0 without a matching perk.
func perk_total(op: String) -> int:
	return PerkCatalog.effect_total(perk_ids, op)


## Override to move state that depends on a perk (a starting value that tracks a cap).
func _on_perks_applied() -> void:
	pass


## Fires after every `action_resolved` event whose actor is the owner. `event.data` carries the
## full outcome dict (action_id, verb, resolution, ...). Use it to consume one-shot flags.
func on_action(_event: CombatEvent) -> void:
	pass


## The authored PASS-kind commands this resource answers, by
## `CombatAction.class_resource_action` id. Empty is the honest default: a
## resource that is purely reactive has no button.
##
## `CombatController.query_action()` refuses a class-resource action whose
## command is not listed here, so an actor of the wrong patron sees a locked
## button with a reason instead of a working one that silently does nothing.
func commands() -> Array[StringName]:
	return []


func accepts_command(action_id: StringName) -> bool:
	return commands().has(action_id)


## Pure readiness check before AP/CT/Soul are committed. Subclasses add resource
## and payload requirements here; on_command remains the committed mutation hook.
func query_command(action_id: StringName, _target_id: StringName, _payload: Dictionary = {}) -> Dictionary:
	if not accepts_command(action_id):
		return command_refusal(&"class_resource", "This patron cannot use that class action.")
	return {"allowed": true, "blocked_by": &"", "message": "", "nearest_unblock": {}}


func command_refusal(reason: StringName, message: String) -> Dictionary:
	return {
		"allowed": false, "blocked_by": reason, "message": message,
		"nearest_unblock": {"type": &"class_resource", "patron": patron_id},
	}


## Optional command channel for authored PASS-kind class-resource actions.
## Only reached for a command this resource listed in `commands()`.
func on_command(_action_id: StringName, _target_id: StringName) -> void:
	pass


## Additive payload channel. Existing two-argument command implementations and
## hook consumers keep working; payload-driven resources override this wrapper.
func execute_command(action_id: StringName, target_id: StringName, _payload: Dictionary = {}) -> void:
	on_command(action_id, target_id)


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


## Broadcast after any combatant falls, including deferred damage.
func on_combatant_fell(_target_id: StringName) -> void:
	pass


## Final bookkeeping before the finish signal and persistence copy. Only earned,
## already-due Breath refunds are settled here; time and offensive effects stop.
func on_battle_end(_victory: bool) -> void:
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
## (kinds: hp, dot, breath, soul_meter, tile_state; before/after are materialized
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


## #285 slice 4: return a HIGHER `after` to soften an HP loss before it lands. Called on the
## target's resource first, then every other resource; each sees the previous answer.
func adjust_incoming_hp(_actor_id: StringName, _target_id: StringName, _before: int, after: int) -> int:
	return after


## #285 slice 4: overrides merged into an ALLY's cast context (Debt of Arms). Same contract as
## `on_cast_forecast()`: pure, called identically at forecast and commit.
func on_ally_cast_forecast(_actor_id: StringName, _context: Dictionary) -> Dictionary:
	return {}


## #285 slice 4: what crosses into the next battle (Kept Focus, Carried Lesson), and its intake.
func carry_out() -> Dictionary:
	return {}


func receive_carry(_carried: Dictionary) -> void:
	pass


## Refusal for a signature command the owner has not picked (#285 slice 4).
func perk_refusal(op: String, perk_name: String) -> Dictionary:
	if perk_total(op) > 0:
		return {}
	return command_refusal(&"perk_missing", "Needs the %s perk." % perk_name)


## The controller asks before charging a class command's Soul (Pocketed Gear, #285 slice 3).
## True skips the spend; the Gauge never rises.
func waives_soul_cost(_action_id: StringName) -> bool:
	return false


## Fires on every OTHER ally's turn start (the owner's own turn is `on_turn_start()`).
## Locksmirk's Second Pick retries an armed Jam here.
func on_ally_turn_start(_actor_id: StringName) -> void:
	pass


## HUD-facing view: what the unit plate shows. Keep it small and stable.
func snapshot() -> Dictionary:
	return {"patron_id": String(patron_id)}


## Serialization — round-trips through `from_dict()`. Subclasses extend both.
func to_dict() -> Dictionary:
	return {"patron_id": String(patron_id), "owner_id": String(owner_id), "perk_ids": Array(perk_ids)}


## Perks are read BEFORE a subclass clamps its own state against a cap a perk raises. A save
## written before slice 2 has no `perk_ids`; the controller re-applies them from the member.
func from_dict(data: Dictionary) -> void:
	patron_id = StringName(str(data.get("patron_id", String(patron_id))))
	owner_id = StringName(str(data.get("owner_id", String(owner_id))))
	perk_ids = PackedStringArray()
	for value: Variant in data.get("perk_ids", []):
		perk_ids.append(str(value))


func is_null() -> bool:
	return false
