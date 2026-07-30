extends Node
## Renown — a second, faction-independent consequence ledger: how known
## (reputation) or notorious (infamy) the player is in general, regardless of
## any single faction's opinion (globals/reputation.gd covers that axis).
## Same append-only rule: nothing writes to the log except gain_reputation()/
## gain_infamy(), and nothing but combat feeds either — dialogue, quests, and
## other choices do too (see dialogue/iris_illepah.dialogue for an infamy
## example). Consumers: ui/screens/tavern.gd gates some recruits on a minimum
## reputation() or infamy(), the way a faction can gate a dialogue line.
##
## Deliberately separate from the Soul Gauge (GameState.soul_meter) — the
## vault's systems/magic-system.md floats an unresolved idea to rework the
## Gauge itself into a public karma meter, which it flags as contradicting
## current canon. This system doesn't touch the Gauge and isn't that proposal.

signal renown_changed(kind: StringName, total: float, event: RenownEvent)

var _log: Array[RenownEvent] = []
var _next_order: int = 0
var _reputation: float = 0.0
var _infamy: float = 0.0


func gain_reputation(actor: String, delta: float, cause: String, scene: String = "") -> RenownEvent:
	return _record(actor, &"reputation", delta, cause, scene)


func gain_infamy(actor: String, delta: float, cause: String, scene: String = "") -> RenownEvent:
	return _record(actor, &"infamy", delta, cause, scene)


func reputation() -> float:
	return _reputation


func infamy() -> float:
	return _infamy


## The most recent reasons behind one meter, newest first — same shape as
## Reputation.why().
func why(kind: StringName, limit: int = 5) -> Array[RenownEvent]:
	var events: Array[RenownEvent] = []
	for e in _log:
		if e.kind == kind:
			events.append(e)
	events.reverse()
	return events.slice(0, limit)


func _record(actor: String, kind: StringName, delta: float, cause: String, scene: String) -> RenownEvent:
	var e := RenownEvent.new()
	e.actor = actor
	e.kind = kind
	e.delta = delta
	e.cause = cause
	e.scene = scene if not scene.is_empty() else _current_scene_id()
	e.at = int(Time.get_unix_time_from_system())
	e.order = _next_order
	_next_order += 1
	_log.append(e)

	if kind == &"infamy":
		_infamy += delta
	else:
		_reputation += delta

	renown_changed.emit(kind, _infamy if kind == &"infamy" else _reputation, e)
	return e


func to_dict() -> Dictionary:
	var rows: Array[Dictionary] = []
	for e in _log:
		rows.append(e.to_dict())
	return {"log": rows, "next_order": _next_order}


func from_dict(d: Dictionary) -> void:
	_log.clear()
	_reputation = 0.0
	_infamy = 0.0
	for row in d.get("log", []):
		_log.append(RenownEvent.from_dict(row))
	_next_order = int(d.get("next_order", _log.size()))
	for e in _log:
		if e.kind == &"infamy":
			_infamy += e.delta
		else:
			_reputation += e.delta


func _current_scene_id() -> String:
	var cur := get_tree().current_scene
	return cur.scene_file_path if cur != null else ""
