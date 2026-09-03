extends TurnScheduler
## The FR-102 AP round economy, expressed behind the TurnScheduler interface — the
## SHIPPED default scheduler since Gate T-10 was amended to CT→AP promotion
## (2026-08-28, `docs/fallout2-adoption-spec.md` Wave 0 item 5; this header previously
## called AP "retired", which the ratified promotion superseded).
##
## WHY THE SEAM EXISTS. Amendment §8 requires the abort path to be a flag flip rather than
## a revert, which is only true if both economies are reachable through the same interface.
## Branching inside CombatController would create two turn-order authorities in one file
## (§8.1 release blocker). So there is one authority — this interface — and two
## implementations; CT remains available behind the seam with its compatibility tests.
##
## This began as a FAITHFUL port of what `combat_controller.gd` did before the extraction:
##
##   - A round refreshes AP for every living participant, then allies act, then enemies act.
##   - An ally keeps acting while AP remains; the turn passes when AP hits zero or it yields.
##   - Enemies act once per round by default. CombatRules may opt into spending
##     their full AP pool; that flag is deliberately OFF in shipped data.
##   - Order inside a side is seat order, which is party order.
##
## The one-action-per-enemy rule is the clearest example of why this is a port and not a design:
## it is a property of the old enemy burst loop, not something anyone would choose. Do not "fix"
## it here. Fixing it changes live combat balance under a flag that is supposed to be inert.
##
## DETERMINISM. No RNG. Order is fully decided by (side, seat), seats are assigned at setup in
## participant order, and both are serialized — same inputs, same order, which is what lets the
## abort path be verified against recorded play.
##
## RETIREMENT. Gate T criterion 10 is "zero AP references or documented shims". This file is that
## shim, and it is documented here. It is deleted when Gate T passes, not before.

## Sides, in the order they act within a round.
const ALLY_SIDE: StringName = &"ally"
const ENEMY_SIDE: StringName = &"enemy"

var _rules: CombatRules
var _seats: Array[BattleActor] = []
var _seat_of: Dictionary = {}          # combat_id -> seat index
var _acted_this_round: Dictionary = {} # combat_id -> bool, enemies only
var _round: int = 0
var _side: StringName = ALLY_SIDE
var _active_seat: int = -1
var _started := false
var _committed_actor: BattleActor = null
var _committed_cost: int = 0
var _phase: Phase = Phase.IDLE
var _paused := false
var _interrupt_reason: StringName = &""
var _ticks: int = 0


func configure(rules: CombatRules) -> void:
	_rules = rules


func setup(participants: Array[BattleActor]) -> void:
	_seats.clear()
	_seat_of.clear()
	_acted_this_round.clear()
	_round = 0
	_side = ALLY_SIDE
	_active_seat = -1
	_started = false
	_committed_actor = null
	_committed_cost = 0
	_phase = Phase.IDLE
	_paused = false
	_interrupt_reason = &""
	_ticks = 0
	for actor in participants:
		if actor == null:
			continue
		_seat_of[actor.combat_id] = _seats.size()
		_seats.append(actor)


# ---- reads ----


## An AP action costs its authored `ap_cost`. This is the number the HUD shows and the number
## commit() charges; FR-102a's "the timeline must never lie" applies to the AP model too.
func quote(_actor: BattleActor, action: CombatAction) -> int:
	if action == null:
		return 0
	return action.ap_cost


func can_act(actor: BattleActor) -> Dictionary:
	if actor == null or not _seat_of.has(actor.combat_id):
		return _blocked(&"not_participating", "Not a combatant in this battle.", {})
	if _paused:
		return _blocked(&"interrupted", "The battle is held — %s." % String(_interrupt_reason), {})
	if not actor.is_alive():
		return _blocked(&"defeated", "%s cannot act." % actor.display_name, {})
	if _phase == Phase.COMMITTED and _committed_actor != actor:
		return _blocked(
			&"awaiting_resolution", "Another action is still resolving.", {"resolve": "release()"}
		)
	if active_actor() != actor:
		# &"ct_not_ready" is the interface's name for "your turn has not come round". It reads
		# oddly under AP, but the refusal taxonomy (FR-606) is shared across both schedulers on
		# purpose: a UI that learns one vocabulary must not have to learn a second one.
		return _blocked(&"ct_not_ready", "It is not %s's turn." % actor.display_name, {})
	return _allowed({})


## Whether `actor` can afford `action` specifically. Separate from can_act() because "it is not
## your turn" and "you cannot afford this" are different answers and FR-606 requires the UI to be
## able to tell them apart.
func can_afford(actor: BattleActor, action: CombatAction) -> Dictionary:
	var gate := can_act(actor)
	if not bool(gate.get("allowed", false)):
		return gate
	var cost := quote(actor, action)
	if actor.action_points < cost:
		return {
			"allowed": false,
			"blocked_by": &"action_points",
			"nearest_unblock": {
				"type": &"action_points",
				"minimum": cost,
				"delta": cost - actor.action_points,
			},
			"current_ap": actor.action_points,
			"required_ap": cost,
			"message": "Requires %d AP; %d AP remains." % [cost, actor.action_points],
		}
	return _allowed({})


func active_actor() -> BattleActor:
	if _paused or not _started:
		return null
	if _phase == Phase.COMMITTED:
		return _committed_actor
	if _active_seat < 0 or _active_seat >= _seats.size():
		return null
	var actor := _seats[_active_seat]
	return actor if actor.is_alive() else null


## Banked resource for a participant. Under AP that is remaining action points, not charge.
func charge_of(actor: BattleActor) -> int:
	if actor == null:
		return 0
	return actor.action_points


## Upcoming order: the rest of this round's allies, then this round's unacted enemies.
##
## Derived from the same walk advance() uses, never estimated separately — FR-102a requires the
## timeline to be a projection of the real arithmetic.
func peek_order(depth: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if depth <= 0:
		return out
	var current := active_actor()
	if current != null:
		out.append(_order_entry(current, 0))
	var side := _side
	var seat := _active_seat
	while out.size() < depth:
		var next := _next_in_side(seat, side)
		if next == null:
			if side == ALLY_SIDE:
				side = ENEMY_SIDE
				seat = -1
				continue
			break
		out.append(_order_entry(next, out.size()))
		seat = int(_seat_of[next.combat_id])
	return out


## Every living participant in current-round seat order (allies then enemies) with
## acted/pending/active state — the complete Region E payload (spec Wave 0 item 6).
## peek_order() deliberately filters to whoever can still act, which loses acted
## actors; presentation reads this instead so the round order never drops anyone.
func round_overview() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for side: StringName in [ALLY_SIDE, ENEMY_SIDE]:
		for actor: BattleActor in _seats:
			if actor == null or not actor.is_alive() or actor.side != side:
				continue
			out.append(_order_entry(actor, out.size()))
	return out


func tick_count() -> int:
	return _ticks


## Under AP a ROUND is the cadence, so a round is the measure. Weather and any other
## measure-driven beat therefore fire once per round under this scheduler and once per 16 ticks
## under charge time, which is the intended correspondence.
func measure_index() -> int:
	return maxi(0, _round - 1)


func round_number() -> int:
	return _round


func phase() -> Phase:
	return _phase


# ---- writes ----


## Advances until somebody can act.
##
## The returned dictionary carries the AP model's round bookkeeping in named keys —
## `round_started`, `refreshed`, `side_started`, `round_ended`. CombatController turns those into
## the `round_started` / `ap_refreshed` / `enemy_turn_started` / `round_ended` events it already
## emits, WITHOUT knowing which scheduler produced them. ChargeTimeScheduler simply never sets
## these keys, so those events stop appearing when the flag flips, which is exactly what FR-102a
## means by "round_started and ap_refreshed lose meaning".
##
## This mirrors `measures_crossed`, which is already in the contract for the same reason: it lets
## the controller fire a beat without the scheduler knowing what the beat is for.
func advance() -> Dictionary:
	if _paused:
		return _blocked(&"interrupted", "The battle is held — %s." % String(_interrupt_reason), {})
	if _phase == Phase.COMMITTED:
		return _blocked(
			&"awaiting_resolution", "An action is still resolving.", {"resolve": "release()"}
		)
	if not _has_living():
		return _blocked(&"no_participants", "No living combatants remain.", {})

	var start_measure := measure_index()
	var extras: Dictionary = {}

	if not _started:
		_started = true
		_ticks += 1
		extras.merge(_begin_round(), true)
	else:
		var current := active_actor()
		# The active combatant keeps the turn while it is still eligible. This is the AP model's
		# answer to "has anyone reached READY_AT" — the current one still has, so time does not
		# move on and no tick is spent.
		if _still_eligible(current):
			return _allowed({
				"actor": current,
				"ticks_elapsed": 0,
				"measures_crossed": 0,
				"charge": current.action_points,
			})
		_ticks += 1
		extras.merge(_step(), true)

	var ready := active_actor()
	if ready == null:
		return _blocked(&"no_participants", "No combatant became ready.", {})
	var result := {
		"actor": ready,
		"ticks_elapsed": 1,
		"measures_crossed": measure_index() - start_measure,
		"charge": ready.action_points,
	}
	result.merge(extras, true)
	return _allowed(result)


func commit(actor: BattleActor, action: CombatAction) -> Dictionary:
	var gate := can_afford(actor, action)
	if not bool(gate.get("allowed", false)):
		return gate
	var cost := quote(actor, action)
	actor.action_points = maxi(0, actor.action_points - cost)
	_committed_actor = actor
	_committed_cost = cost
	_phase = Phase.COMMITTED
	if (
		_side == ENEMY_SIDE
		and (
			_rules == null
			or not _rules.enemy_full_ap_turns
			or actor.action_points <= 0
			or cost <= 0  # a free action must not renew eligibility, or the side never advances
			or action.kind == CombatAction.Kind.PASS
		)
	):
		_acted_this_round[actor.combat_id] = true
	return _allowed({"actor": actor, "ct_spent": cost, "charge": actor.action_points})


func release(actor: BattleActor) -> void:
	if _committed_actor != actor:
		push_error("ApRoundScheduler.release(): %s has no committed action." % actor.combat_id)
		return
	_committed_actor = null
	_committed_cost = 0
	_phase = Phase.RESOLVED


func cancel_committed(actor: BattleActor, refund: bool) -> Dictionary:
	if _committed_actor != actor or _phase != Phase.COMMITTED:
		return _blocked(&"nothing_committed", "That combatant has no committed action.", {})
	var returned := 0
	if refund:
		var ratio: float = _rules.cancel_refund_ratio if _rules != null else 1.0
		returned = int(round(float(_committed_cost) * ratio))
		actor.action_points += returned
		if _side == ENEMY_SIDE:
			# A cancelled action was never taken, so it must not consume the enemy's one act.
			_acted_this_round.erase(actor.combat_id)
	_committed_actor = null
	_committed_cost = 0
	_phase = Phase.CANCELLED
	return _allowed({"actor": actor, "ct_refunded": returned})


## Ends the turn with AP still in hand — what `CombatController.end_turn()` has always done.
## Spending the remainder is what makes the turn actually pass, because the AP model's readiness
## test is "AP remains".
func yield_turn(actor: BattleActor) -> Dictionary:
	var gate := can_act(actor)
	if not bool(gate.get("allowed", false)):
		return gate
	var forfeited := actor.action_points
	actor.action_points = 0
	_phase = Phase.IDLE
	return _allowed({"actor": actor, "ct_spent": forfeited, "charge": 0})


func force_advance(actor: BattleActor) -> Dictionary:
	if actor == null or _seat_index_of(actor) < 0:
		return _blocked(&"not_participating", "That combatant is not in this battle.", {})
	var forfeited := maxi(0, actor.action_points)
	actor.action_points = 0
	# Gate on the active round side like commit()/cancel_committed(), not actor.side —
	# a forced pass outside the enemy round must not consume the enemy's one act.
	if _side == ENEMY_SIDE:
		_acted_this_round[actor.combat_id] = true
	if _committed_actor == actor:
		_committed_actor = null
		_committed_cost = 0
	_phase = Phase.IDLE
	return _allowed({"actor": actor, "ct_spent": forfeited, "ct_refunded": 0, "charge": 0})


func grant_extra_turn(actor: BattleActor) -> void:
	if actor != null and _seat_index_of(actor) >= 0:
		actor.action_points = maxi(actor.action_points, actor.max_action_points)


func interrupt(reason: StringName) -> Dictionary:
	if _paused:
		return _blocked(&"already_interrupted", "The battle is already held.", {})
	_paused = true
	_interrupt_reason = reason
	if _phase != Phase.COMMITTED:
		_phase = Phase.INTERRUPTED
	return _allowed({
		"reason": reason, "committed_actor": _committed_actor, "held_at_tick": _ticks
	})


func resume() -> void:
	_paused = false
	_interrupt_reason = &""
	if _phase == Phase.INTERRUPTED:
		_phase = Phase.IDLE


## Drops a participant without disturbing anyone else's seat or AP. Seats are kept and the entry
## is left in place rather than compacted, because compacting would silently renumber every seat
## after it and reorder the queue — the exact failure the interface promises never happens.
func remove_participant(actor: BattleActor) -> void:
	if actor == null:
		return
	if _committed_actor == actor:
		_committed_actor = null
		_committed_cost = 0
		_phase = Phase.IDLE
	_acted_this_round.erase(actor.combat_id)


# ---- persistence ----


func to_dict() -> Dictionary:
	var acted: Array[String] = []
	for key in _acted_this_round:
		if bool(_acted_this_round[key]):
			acted.append(String(key))
	acted.sort()
	var seats: Array[String] = []
	for actor in _seats:
		seats.append(String(actor.combat_id))
	return {
		"scheduler": "ap_round",
		"round": _round,
		"side": String(_side),
		"active_seat": _active_seat,
		"started": _started,
		"ticks": _ticks,
		"phase": int(_phase),
		"paused": _paused,
		"interrupt_reason": String(_interrupt_reason),
		"committed_cost": _committed_cost,
		"committed_actor": String(_committed_actor.combat_id) if _committed_actor else "",
		"acted_this_round": acted,
		"seats": seats,
	}


func from_dict(data: Dictionary) -> void:
	_round = int(data.get("round", 0))
	_side = StringName(data.get("side", String(ALLY_SIDE)))
	_active_seat = int(data.get("active_seat", -1))
	_started = bool(data.get("started", false))
	_ticks = int(data.get("ticks", 0))
	_phase = int(data.get("phase", Phase.IDLE)) as Phase
	_paused = bool(data.get("paused", false))
	_interrupt_reason = StringName(data.get("interrupt_reason", ""))
	_committed_cost = int(data.get("committed_cost", 0))
	_acted_this_round.clear()
	for key in data.get("acted_this_round", []):
		_acted_this_round[StringName(key)] = true
	var committed := String(data.get("committed_actor", ""))
	_committed_actor = null
	if not committed.is_empty():
		for actor in _seats:
			if String(actor.combat_id) == committed:
				_committed_actor = actor
				break


# ---- internals ----


func _begin_round() -> Dictionary:
	_round += 1
	_side = ALLY_SIDE
	_acted_this_round.clear()
	var refreshed: Array[Dictionary] = []
	for actor in _seats:
		if not actor.is_alive():
			continue
		actor.max_action_points = (
			_rules.action_points_for(actor) if _rules != null else actor.max_action_points
		)
		actor.action_points = actor.max_action_points
		refreshed.append({
			"actor": actor,
			"current_ap": actor.action_points,
			"maximum_ap": actor.max_action_points,
		})
	_active_seat = _seat_index_of(_next_in_side(-1, ALLY_SIDE))
	if _active_seat < 0:
		# No living ally opens the round. The controller reads this as a defeat; the scheduler
		# does not decide outcomes.
		_side = ENEMY_SIDE
		_active_seat = _seat_index_of(_next_in_side(-1, ENEMY_SIDE))
	return {
		"round_started": true,
		"round": _round,
		"refreshed": refreshed,
		"side_started": _side,
	}


## Moves to the next actor: next in this side, else the enemy side, else a new round.
func _step() -> Dictionary:
	var next := _next_in_side(_active_seat, _side)
	if next != null:
		_active_seat = _seat_index_of(next)
		return {}
	if _side == ALLY_SIDE:
		var first_enemy := _next_in_side(-1, ENEMY_SIDE)
		if first_enemy != null:
			_side = ENEMY_SIDE
			_active_seat = _seat_index_of(first_enemy)
			return {"side_started": ENEMY_SIDE}
	var ended := _round
	var opened := _begin_round()
	opened["round_ended"] = true
	opened["ended_round"] = ended
	return opened


## First living actor on `side` seated after `after_seat` that has not already used its act.
func _next_in_side(after_seat: int, side: StringName) -> BattleActor:
	for seat in range(after_seat + 1, _seats.size()):
		var actor := _seats[seat]
		if not actor.is_alive() or actor.side != side:
			continue
		# Allies act until their AP runs out; enemies act once per round. Both conditions are the
		# old controller's, kept verbatim.
		if side == ENEMY_SIDE and bool(_acted_this_round.get(actor.combat_id, false)):
			continue
		if side == ALLY_SIDE and actor.action_points <= 0:
			continue
		return actor
	return null


## Whether the current combatant may keep acting rather than passing the turn on.
##
## The two sides answer this differently, and that asymmetry IS the AP round model: an ally acts
## until its AP runs out, an enemy acts once. Branching on side here rather than at the call site
## keeps the rule in one place — the first version of advance() tested only the ally condition,
## which silently cost an enemy its turn whenever its action was cancelled rather than resolved.
func _still_eligible(actor: BattleActor) -> bool:
	if actor == null or not actor.is_alive():
		return false
	if actor.side == ENEMY_SIDE:
		return not bool(_acted_this_round.get(actor.combat_id, false))
	return actor.action_points > 0


func _seat_index_of(actor: BattleActor) -> int:
	if actor == null:
		return -1
	return int(_seat_of.get(actor.combat_id, -1))


func _order_entry(actor: BattleActor, distance: int) -> Dictionary:
	var acted := actor.action_points <= 0
	if actor.side == ENEMY_SIDE:
		acted = bool(_acted_this_round.get(actor.combat_id, false))
	return {
		"actor": actor,
		"charge": actor.action_points,
		"ticks_until": distance,
		"seat": int(_seat_of.get(actor.combat_id, 0)),
		"scheduler_mode": &"ap_round",
		"ap_remaining": actor.action_points,
		"max_ap": actor.max_action_points,
		"acted": acted,
		"pending": not acted,
		"active": actor == active_actor(),
	}


func _has_living() -> bool:
	for actor in _seats:
		if actor.is_alive():
			return true
	return false
