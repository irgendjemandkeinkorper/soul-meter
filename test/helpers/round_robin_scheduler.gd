extends TurnScheduler
## Test-only second TurnScheduler implementation. Exists solely to prove the seam is real.
##
## Amendment §2.1 makes this a verifiable requirement rather than a claim: "a second concrete
## scheduler (a throwaway test-only implementation is fine) must compile and pass the same
## determinism and interrupt tests as the production one. If it can't, the seam isn't real."
##
## Deliberately NOT charge time — it is a plain round robin. If a test passes against
## ChargeTimeScheduler but fails here, the test is coupled to charge-time internals rather than
## to the TurnScheduler contract, and that is the bug the second implementation is here to catch.
##
## Never referenced by game code. Do not promote this to globals/.

const FLAT_COST := 1

var _rules: CombatRules
var _seats: Array[BattleActor] = []
var _seat_of: Dictionary = {}
var _cursor: int = 0
var _committed_actor: BattleActor = null
var _phase: Phase = Phase.IDLE
var _paused := false
var _interrupt_reason: StringName = &""
var _ticks: int = 0


func configure(rules: CombatRules) -> void:
	_rules = rules


func setup(participants: Array[BattleActor]) -> void:
	_seats.clear()
	_seat_of.clear()
	_cursor = 0
	_committed_actor = null
	_phase = Phase.IDLE
	_paused = false
	_ticks = 0
	for actor in participants:
		if actor == null:
			continue
		_seat_of[actor.combat_id] = _seats.size()
		_seats.append(actor)


func quote(_actor: BattleActor, _action: CombatAction) -> int:
	return FLAT_COST


func can_act(actor: BattleActor) -> Dictionary:
	if actor == null or not _seat_of.has(actor.combat_id):
		return _blocked(&"not_participating", "Not in this battle.", {})
	if _paused:
		return _blocked(&"interrupted", "Held — %s." % String(_interrupt_reason), {})
	if not actor.is_alive():
		return _blocked(&"defeated", "Cannot act.", {})
	if _phase == Phase.COMMITTED and _committed_actor != actor:
		return _blocked(&"awaiting_resolution", "Another action is resolving.", {})
	if active_actor() != actor:
		return _blocked(&"ct_not_ready", "Not this combatant's turn.", {"ticks": 1})
	return _allowed({})


func active_actor() -> BattleActor:
	if _paused:
		return null
	if _phase == Phase.COMMITTED:
		return _committed_actor
	var living := _living()
	if living.is_empty():
		return null
	return living[_cursor % living.size()]


func charge_of(actor: BattleActor) -> int:
	return READY_AT if active_actor() == actor else 0


func peek_order(depth: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var living := _living()
	if living.is_empty():
		return out
	for i in depth:
		var actor: BattleActor = living[(_cursor + i) % living.size()]
		out.append({
			"actor": actor,
			"charge": READY_AT,
			"ticks_until": i,
			"seat": int(_seat_of.get(actor.combat_id, 0)),
		})
	return out


func tick_count() -> int:
	return _ticks


func measure_index() -> int:
	return _ticks / TICKS_PER_MEASURE


func phase() -> Phase:
	return _phase


func advance() -> Dictionary:
	if _paused:
		return _blocked(&"interrupted", "Held.", {})
	if _phase == Phase.COMMITTED:
		return _blocked(&"awaiting_resolution", "An action is resolving.", {})
	if _living().is_empty():
		return _blocked(&"no_participants", "No living combatants remain.", {})
	var start_measure := measure_index()
	_ticks += 1
	return _allowed({
		"actor": active_actor(),
		"ticks_elapsed": 1,
		"measures_crossed": measure_index() - start_measure,
		"charge": READY_AT,
	})


func commit(actor: BattleActor, action: CombatAction) -> Dictionary:
	var gate := can_act(actor)
	if not bool(gate.get("allowed", false)):
		return gate
	_committed_actor = actor
	_phase = Phase.COMMITTED
	return _allowed({"actor": actor, "ct_spent": quote(actor, action), "charge": 0})


func release(actor: BattleActor) -> void:
	if _committed_actor != actor:
		push_error("release(): nothing committed for that actor.")
		return
	_committed_actor = null
	_phase = Phase.RESOLVED
	_cursor += 1


func cancel_committed(actor: BattleActor, refund: bool) -> Dictionary:
	if _committed_actor != actor or _phase != Phase.COMMITTED:
		return _blocked(&"nothing_committed", "No committed action.", {})
	_committed_actor = null
	_phase = Phase.CANCELLED
	if not refund:
		_cursor += 1
	return _allowed({"actor": actor, "ct_refunded": FLAT_COST if refund else 0})


func interrupt(reason: StringName) -> Dictionary:
	if _paused:
		return _blocked(&"already_interrupted", "Already held.", {})
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


func remove_participant(actor: BattleActor) -> void:
	if _committed_actor == actor:
		_committed_actor = null
		_phase = Phase.IDLE
	var index := _seats.find(actor)
	if index >= 0:
		_seats.remove_at(index)
	_seat_of.erase(actor.combat_id)


func to_dict() -> Dictionary:
	return {"ticks": _ticks, "cursor": _cursor, "phase": int(_phase), "paused": _paused}


func from_dict(data: Dictionary) -> void:
	_ticks = int(data.get("ticks", 0))
	_cursor = int(data.get("cursor", 0))
	_phase = int(data.get("phase", Phase.IDLE)) as Phase
	_paused = bool(data.get("paused", false))


func _living() -> Array[BattleActor]:
	var out: Array[BattleActor] = []
	for actor in _seats:
		if actor.is_alive():
			out.append(actor)
	return out
