class_name TurnScheduler
extends RefCounted
## Turn-order authority. FR-102a (charge time), ratified by
## docs/prd-amendment-tactical-layer.md §2.1.
##
## This seam exists BEFORE any charge-time logic reaches CombatController, deliberately. The
## retired FR-102 AP economy had no interface: `action_points`/`ap_cost` were inlined across 34
## sites in combat_controller.gd, which is why retiring it is a controller rewrite instead of a
## swap. Building the seam first means the NEXT turn-order change — CT to something else, or CT
## back to AP on abort — costs a subclass, not a rewrite.
##
## No consumer names a concrete scheduler; creation goes through create_default(). If you find
## yourself writing `ChargeTimeScheduler` outside this file or a test, the seam has already
## failed.
##
## SCOPE — the scheduler owns ORDER ONLY. It answers "who acts next", "when", "may they", and
## "what does this cost". It never resolves actions, never touches HP, never emits CombatEvent.
## CombatController orchestrates it and owns everything else. Keeping this line is what makes
## the scheduler testable in isolation and swappable at all.

## CT threshold at which a participant may act.
const READY_AT := 100
## Ticks in one full measure — the weather/global-bias cadence.
const TICKS_PER_MEASURE := 16

## Lifecycle of a committed action. The AP round model had an implicit "resolve the turn, then
## check end conditions" boundary; a continuous queue has none, so the states are explicit.
enum Phase {
	IDLE,        ## nothing committed
	COMMITTED,   ## CT spent, action pending resolution
	RESOLVED,    ## controller applied the outcome; scheduler released the actor
	CANCELLED,   ## committed action voided before resolution; refund policy applied
	INTERRUPTED, ## external event (e.g. speech ending the battle) halted the queue
}


static func create_default(rules: CombatRules) -> TurnScheduler:
	var script := load("res://globals/combat/charge_time_scheduler.gd") as Script
	var scheduler := script.new() as TurnScheduler
	scheduler.configure(rules)
	return scheduler


func configure(_rules: CombatRules) -> void:
	pass


## Seats every participant. Seat order is assigned here, serialized, and used as the stable
## tie-break — so ordering survives save/load and replay.
func setup(_participants: Array[BattleActor]) -> void:
	push_error("TurnScheduler.setup() must be implemented.")


# ---- reads: never mutate ----


## CT cost of `action` for `actor`, without committing. This is the number the forecast and the
## timeline both display; it must equal what commit() actually charges.
func quote(_actor: BattleActor, _action: CombatAction) -> int:
	push_error("TurnScheduler.quote() must be implemented.")
	return 0


## Refusal taxonomy (FR-606, amendment §2.2). Returns {allowed, blocked_by, nearest_unblock,
## message}. `blocked_by` must distinguish the reason — &"ct_not_ready" is not the same
## refusal as &"interrupted" or &"not_participating", and the UI is required to say which.
func can_act(_actor: BattleActor) -> Dictionary:
	return _blocked(&"unimplemented", "TurnScheduler.can_act() must be implemented.", {})


## The participant whose turn it is, or null if nobody has reached the threshold yet.
func active_actor() -> BattleActor:
	return null


## Banked charge time for a participant.
func charge_of(_actor: BattleActor) -> int:
	return 0


## Projected upcoming order, at most `depth` entries: [{actor, charge, ticks_until, seat}].
##
## The timeline UI renders this directly. Per FR-102a it "must never lie" — derive it from the
## same arithmetic advance() uses, never from a parallel estimate.
func peek_order(_depth: int) -> Array[Dictionary]:
	return []


func tick_count() -> int:
	return 0


## Completed measures so far — the cadence weather and global bias tick on.
func measure_index() -> int:
	return 0


func phase() -> Phase:
	return Phase.IDLE


# ---- writes ----


## Advances time until someone reaches READY_AT. Returns
## {actor, ticks_elapsed, measures_crossed} — `measures_crossed` lets the controller fire the
## weather beat without the scheduler knowing what weather is.
func advance() -> Dictionary:
	push_error("TurnScheduler.advance() must be implemented.")
	return {}


## Spends `action`'s CT cost. Returns the refusal shape on failure, so a blocked commit
## explains itself the same way a blocked move does.
func commit(_actor: BattleActor, _action: CombatAction) -> Dictionary:
	return _blocked(&"unimplemented", "TurnScheduler.commit() must be implemented.", {})


## Marks the committed action resolved and releases the actor back into the queue.
func release(_actor: BattleActor) -> void:
	push_error("TurnScheduler.release() must be implemented.")


## Voids a committed-but-unresolved action. `refund` returns the spent CT — the wait-refunds
## rule and a cancelled cast both route through here rather than reaching into charge state.
func cancel_committed(_actor: BattleActor, _refund: bool) -> Dictionary:
	return _blocked(&"unimplemented", "TurnScheduler.cancel_committed() must be implemented.", {})


## Halts the queue — a speech check ending or splitting a battle mid-resolution.
##
## Amendment §4 requires an explicit answer to four questions, and an implementation must
## document its answer to each: does CT freeze while a dialogue balloon is open; is the acting
## unit's committed action voided or completed; what happens to participants already past
## READY_AT; and how the queue is rebuilt on a split without reordering banked CT.
func interrupt(_reason: StringName) -> Dictionary:
	return _blocked(&"unimplemented", "TurnScheduler.interrupt() must be implemented.", {})


## Resumes after an interrupt. Banked CT is preserved; this is not a reset.
func resume() -> void:
	push_error("TurnScheduler.resume() must be implemented.")


## Drops a participant (death, flight, a speech-driven split). Everyone else keeps their banked
## CT and their seat, so removal never silently reorders the queue.
func remove_participant(_actor: BattleActor) -> void:
	push_error("TurnScheduler.remove_participant() must be implemented.")


# ---- persistence: determinism across save/load and replay ----


func to_dict() -> Dictionary:
	return {}


func from_dict(_data: Dictionary) -> void:
	push_error("TurnScheduler.from_dict() must be implemented.")


# ---- helpers ----


static func _allowed(extra: Dictionary = {}) -> Dictionary:
	var result := {"allowed": true, "blocked_by": &"", "nearest_unblock": {}, "message": ""}
	result.merge(extra, true)
	return result


## Mirrors BattlefieldModel._blocked() exactly. One refusal shape across positioning, casting
## and turn order is what lets FR-606 answer "why can't I do this?" with one code path.
static func _blocked(
	blocked_by: StringName, message: String, nearest_unblock: Dictionary
) -> Dictionary:
	return {
		"allowed": false,
		"blocked_by": blocked_by,
		"nearest_unblock": nearest_unblock.duplicate(true),
		"message": message,
	}
