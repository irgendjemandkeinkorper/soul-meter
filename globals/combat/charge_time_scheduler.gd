extends TurnScheduler
## FR-102a charge-time implementation. No consumer names this type; creation goes through
## TurnScheduler.create_default().
##
## Rules (amendment §1): each tick every living participant gains CT equal to its Speed; a
## participant acts at CT 100; moving costs 20, actions 30-60, waiting refunds. 16 ticks make a
## measure.
##
## DETERMINISM. There is no RNG here at all. Ordering is fully decided by (charge desc, seat
## asc), seats are assigned at setup in participant order, and both are serialized. Same inputs
## always produce the same order — which is what lets replay, the forecast preview, and AI
## evaluation share one code path (amendment §5 criterion 9).
##
## OVERFLOW IS PRESERVED. A participant that reaches 112 CT keeps the extra 12 after spending.
## Truncating to 100 would quietly punish being fast, and would make the timeline lie about the
## next turn.
##
## INTERRUPT CONTRACT (amendment §4 requires an explicit answer to each):
##   1. Does CT freeze while a dialogue balloon is open?
##      Yes. interrupt() sets a paused flag; advance() refuses to tick while paused.
##   2. Is the acting unit's committed action voided or completed?
##      Neither implicitly. The committed action survives the interrupt in COMMITTED phase; the
##      controller decides, calling release() to complete it or cancel_committed() to void it.
##      Silence is not a policy, so the scheduler will not guess.
##   3. What about participants already past READY_AT?
##      They keep their banked CT and their seat. Resuming does not re-roll or reset anyone.
##   4. How is the queue rebuilt on a split?
##      remove_participant() drops one entry and touches nobody else's charge or seat, so a
##      split never reorders the survivors.

var _rules: CombatRules
var _seats: Array[BattleActor] = []
var _charge: Dictionary = {}          # combat_id -> int
var _speed: Dictionary = {}           # combat_id -> int
var _seat_of: Dictionary = {}         # combat_id -> int
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
	_charge.clear()
	_speed.clear()
	_seat_of.clear()
	_committed_actor = null
	_committed_cost = 0
	_phase = Phase.IDLE
	_paused = false
	_interrupt_reason = &""
	_ticks = 0
	for actor in participants:
		if actor == null:
			continue
		var key := _key(actor)
		if _seat_of.has(key):
			push_error("TurnScheduler: duplicate combat_id %s; seats must be unique." % key)
			continue
		_seat_of[key] = _seats.size()
		_seats.append(actor)
		_charge[key] = 0
		_speed[key] = _rules.charge_speed_for(actor) if _rules != null else 1


# ---- reads ----


func quote(_actor: BattleActor, action: CombatAction) -> int:
	if _rules == null:
		return 0
	return _rules.charge_cost_for(action)


func can_act(actor: BattleActor) -> Dictionary:
	if actor == null or not _seat_of.has(_key(actor)):
		return _blocked(&"not_participating", "That combatant is not in this battle.", {})
	if _paused:
		return _blocked(
			&"interrupted",
			"The measure is held — %s." % String(_interrupt_reason),
			{"resume": "resolve the interruption"},
		)
	if not actor.is_alive():
		return _blocked(&"defeated", "%s cannot act." % actor.display_name, {})
	if _phase == Phase.COMMITTED and _committed_actor != actor:
		return _blocked(
			&"awaiting_resolution",
			"Another action is still resolving.",
			{"resolve": "let the committed action finish"},
		)
	var charge := int(_charge.get(_key(actor), 0))
	if charge < READY_AT:
		var speed: int = maxi(1, int(_speed.get(_key(actor), 1)))
		var deficit := READY_AT - charge
		var ticks := int(ceil(float(deficit) / float(speed)))
		return _blocked(
			&"ct_not_ready",
			"%s is not ready — %d charge of %d." % [actor.display_name, charge, READY_AT],
			{"ticks": ticks, "charge_needed": deficit},
		)
	return _allowed({"charge": charge})


func active_actor() -> BattleActor:
	if _paused:
		return null
	if _phase == Phase.COMMITTED:
		return _committed_actor
	var best: BattleActor = null
	var best_charge := -1
	var best_seat := -1
	for actor in _seats:
		if not actor.is_alive():
			continue
		var charge := int(_charge.get(_key(actor), 0))
		if charge < READY_AT:
			continue
		var seat := int(_seat_of.get(_key(actor), 0))
		# Tie-break: higher charge first, then lower seat. Both are serialized, so this
		# ordering is identical after a save/load round trip.
		if charge > best_charge or (charge == best_charge and seat < best_seat):
			best = actor
			best_charge = charge
			best_seat = seat
	return best


func charge_of(actor: BattleActor) -> int:
	return int(_charge.get(_key(actor), 0))


func peek_order(depth: int) -> Array[Dictionary]:
	var projected: Array[Dictionary] = []
	if depth <= 0:
		return projected
	# Projected from the same arithmetic advance() uses — FR-102a: the timeline must never lie.
	var simulated: Dictionary = {}
	for actor in _seats:
		if actor.is_alive():
			simulated[_key(actor)] = int(_charge.get(_key(actor), 0))
	var ticks := 0
	var guard := 0
	while projected.size() < depth and guard < 10000:
		guard += 1
		var ready: Array[BattleActor] = []
		for actor in _seats:
			if actor.is_alive() and int(simulated.get(_key(actor), 0)) >= READY_AT:
				ready.append(actor)
		if ready.is_empty():
			var any := false
			for actor in _seats:
				if not actor.is_alive():
					continue
				any = true
				var key := _key(actor)
				simulated[key] = int(simulated[key]) + maxi(1, int(_speed.get(key, 1)))
			if not any:
				break
			ticks += 1
			continue
		ready.sort_custom(func(a: BattleActor, b: BattleActor) -> bool:
			var ca := int(simulated.get(_key(a), 0))
			var cb := int(simulated.get(_key(b), 0))
			if ca != cb:
				return ca > cb
			return int(_seat_of.get(_key(a), 0)) < int(_seat_of.get(_key(b), 0))
		)
		var next: BattleActor = ready[0]
		projected.append({
			"actor": next,
			"charge": int(simulated.get(_key(next), 0)),
			"ticks_until": ticks,
			"seat": int(_seat_of.get(_key(next), 0)),
		})
		# Assume a median action so the projection past the first entry stays honest about
		# being an estimate of intent, not a promise about a choice not yet made.
		var assumed: int = _rules.minimum_action_ct_cost if _rules != null else 30
		simulated[_key(next)] = int(simulated.get(_key(next), 0)) - assumed
	return projected


func tick_count() -> int:
	return _ticks


func measure_index() -> int:
	return _ticks / TICKS_PER_MEASURE


func phase() -> Phase:
	return _phase


# ---- writes ----


func advance() -> Dictionary:
	if _paused:
		return _blocked(
			&"interrupted", "The measure is held — %s." % String(_interrupt_reason), {}
		)
	if _phase == Phase.COMMITTED:
		return _blocked(
			&"awaiting_resolution", "An action is still resolving.", {"resolve": "release()"}
		)
	var start_measure := measure_index()
	var ticks_elapsed := 0
	var ready := active_actor()
	var guard := 0
	while ready == null and guard < 10000:
		guard += 1
		var living := false
		for actor in _seats:
			if not actor.is_alive():
				continue
			living = true
			var key := _key(actor)
			_charge[key] = int(_charge[key]) + maxi(1, int(_speed.get(key, 1)))
		if not living:
			return _blocked(&"no_participants", "No living combatants remain.", {})
		_ticks += 1
		ticks_elapsed += 1
		ready = active_actor()
	if ready == null:
		return _blocked(&"no_participants", "No combatant became ready.", {})
	return _allowed({
		"actor": ready,
		"ticks_elapsed": ticks_elapsed,
		"measures_crossed": measure_index() - start_measure,
		"charge": charge_of(ready),
	})


func commit(actor: BattleActor, action: CombatAction) -> Dictionary:
	var gate := can_act(actor)
	if not bool(gate.get("allowed", false)):
		return gate
	var cost := quote(actor, action)
	var key := _key(actor)
	# Overflow above READY_AT is preserved — being fast should stay an advantage.
	_charge[key] = int(_charge[key]) - cost
	_committed_actor = actor
	_committed_cost = cost
	_phase = Phase.COMMITTED
	return _allowed({"actor": actor, "ct_spent": cost, "charge": int(_charge[key])})


func release(actor: BattleActor) -> void:
	if _committed_actor != actor:
		push_error("TurnScheduler.release(): %s has no committed action." % _key(actor))
		return
	_committed_actor = null
	_committed_cost = 0
	_phase = Phase.RESOLVED


## Spends readiness and takes no action. Overflow above READY_AT is preserved, exactly as it is
## in commit() — a fast unit that waits stays fast.
##
## ⚠ FR-102a also ratifies that **waiting refunds**, and that discount is deliberately NOT
## implemented here. The size of the refund is a balance value and it has not been authored:
## `CombatRules` prices actions, movement and cancellation, but has no wait cost. Shipping a
## plausible number would be a balance decision made by accident, which the tactical amendment
## forbids in §10.1. This is therefore the neutral baseline — waiting costs one readiness and
## returns nothing — and the discount is an owner decision tracked on #138.
func yield_turn(actor: BattleActor) -> Dictionary:
	var gate := can_act(actor)
	if not bool(gate.get("allowed", false)):
		return gate
	var key := _key(actor)
	_charge[key] = int(_charge[key]) - READY_AT
	_phase = Phase.IDLE
	return _allowed({"actor": actor, "ct_spent": READY_AT, "charge": int(_charge[key])})


func cancel_committed(actor: BattleActor, refund: bool) -> Dictionary:
	if _committed_actor != actor or _phase != Phase.COMMITTED:
		return _blocked(&"nothing_committed", "That combatant has no committed action.", {})
	var returned := 0
	if refund:
		var ratio: float = _rules.cancel_refund_ratio if _rules != null else 1.0
		returned = int(round(float(_committed_cost) * ratio))
		var key := _key(actor)
		_charge[key] = int(_charge[key]) + returned
	_committed_actor = null
	_committed_cost = 0
	_phase = Phase.CANCELLED
	return _allowed({"actor": actor, "ct_refunded": returned})


func interrupt(reason: StringName) -> Dictionary:
	if _paused:
		return _blocked(&"already_interrupted", "The measure is already held.", {})
	_paused = true
	_interrupt_reason = reason
	# The committed action is left standing in COMMITTED. The controller chooses release() or
	# cancel_committed() — the scheduler will not guess whether a speech voided the swing.
	if _phase != Phase.COMMITTED:
		_phase = Phase.INTERRUPTED
	return _allowed({
		"reason": reason,
		"committed_actor": _committed_actor,
		"held_at_tick": _ticks,
	})


func resume() -> void:
	_paused = false
	_interrupt_reason = &""
	if _phase == Phase.INTERRUPTED:
		_phase = Phase.IDLE


func remove_participant(actor: BattleActor) -> void:
	var key := _key(actor)
	if not _seat_of.has(key):
		return
	if _committed_actor == actor:
		_committed_actor = null
		_committed_cost = 0
		_phase = Phase.IDLE
	var index := _seats.find(actor)
	if index >= 0:
		_seats.remove_at(index)
	_charge.erase(key)
	_speed.erase(key)
	# Seats are NOT reassigned. Renumbering would silently reorder every tie-break behind this
	# one, which is exactly the kind of drift a split must not cause.


# ---- persistence ----


func to_dict() -> Dictionary:
	var charges: Dictionary = {}
	for key in _charge:
		charges[String(key)] = int(_charge[key])
	var seats: Dictionary = {}
	for key in _seat_of:
		seats[String(key)] = int(_seat_of[key])
	return {
		"ticks": _ticks,
		"phase": int(_phase),
		"paused": _paused,
		"interrupt_reason": String(_interrupt_reason),
		"committed_id": String(_key(_committed_actor)) if _committed_actor != null else "",
		"committed_cost": _committed_cost,
		"charge": charges,
		"seats": seats,
	}


func from_dict(data: Dictionary) -> void:
	_ticks = int(data.get("ticks", 0))
	_phase = int(data.get("phase", Phase.IDLE)) as Phase
	_paused = bool(data.get("paused", false))
	_interrupt_reason = StringName(str(data.get("interrupt_reason", "")))
	_committed_cost = int(data.get("committed_cost", 0))
	var charges: Dictionary = data.get("charge", {})
	for key in charges:
		_charge[StringName(key)] = int(charges[key])
	var seats: Dictionary = data.get("seats", {})
	for key in seats:
		_seat_of[StringName(key)] = int(seats[key])
	var committed_id := str(data.get("committed_id", ""))
	_committed_actor = null
	if committed_id != "":
		for actor in _seats:
			if String(_key(actor)) == committed_id:
				_committed_actor = actor
				break


static func _key(actor: BattleActor) -> StringName:
	if actor == null:
		return &""
	return actor.combat_id
