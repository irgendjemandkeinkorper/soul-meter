extends Node
## Reputation — the append-only consequence ledger (docs/godot-architecture.md).
##
## THE ONE RULE: nothing writes to the log except record(). No setter for standings
## exists anywhere. Standings are DERIVED from the log, which buys three things:
##   1. why(faction) shows the player exactly why a faction feels how it does.
##   2. Rebalancing = changing _derive(); existing saves stay valid.
##   3. "Why is this NPC hostile" is a query, not an archaeology project.
##
## Consumers: statechart guards read mirrored expression properties (GameFlow wires
## `rep_<faction>` on every change); Dialogue Manager conditions call
## Reputation.standing()/band() directly. Faction ids are the lore vault's kebab ids
## ("mirror-choir", "the-registry", …) — a generated FactionIds constants class comes
## with the Pandora sync pass later.

signal reputation_changed(faction: String, standing: float, event: ReputationEvent)

## Band thresholds — REBALANCE HERE (or in _derive), never by editing the log.
const BAND_ALLIED := 40.0
const BAND_WARM := 15.0
const BAND_COLD := -15.0
const BAND_HOSTILE := -40.0

var _log: Array[ReputationEvent] = []
var _next_order: int = 0
## Derived cache: faction -> standing. Rebuilt from the log; never authoritative.
var _standings: Dictionary = {}


# --- the single append API ----------------------------------------------------

## Record a reputation-bearing act. `cause` is a promise the game keeps — it is
## shown to the player, so say what the world will remember, not a debug code.
func record(actor: String, faction: String, delta: float, cause: String, scene: String = "") -> ReputationEvent:
	var e := ReputationEvent.new()
	e.actor = actor
	e.faction = faction
	e.delta = delta
	e.cause = cause
	e.scene = scene if not scene.is_empty() else _current_scene_id()
	e.at = int(Time.get_unix_time_from_system())
	e.order = _next_order
	_next_order += 1
	_log.append(e)
	_standings[faction] = _derive(events_for(faction))
	reputation_changed.emit(faction, _standings[faction], e)
	return e


# --- derived state (read-only) ------------------------------------------------

func standing(faction: String) -> float:
	return _standings.get(faction, 0.0)


## hostile / cold / neutral / warm / allied
func band(faction: String) -> StringName:
	var s := standing(faction)
	if s <= BAND_HOSTILE:
		return &"hostile"
	if s <= BAND_COLD:
		return &"cold"
	if s >= BAND_ALLIED:
		return &"allied"
	if s >= BAND_WARM:
		return &"warm"
	return &"neutral"


## All factions that have ever appeared in the log, with their standings.
func all_standings() -> Dictionary:
	return _standings.duplicate()


## The query the whole design exists for: the most recent reasons, newest first.
func why(faction: String, limit: int = 5) -> Array[ReputationEvent]:
	var events := events_for(faction)
	events.reverse()
	return events.slice(0, limit)


func events_for(faction: String) -> Array[ReputationEvent]:
	var out: Array[ReputationEvent] = []
	for e in _log:
		if e.faction == faction:
			out.append(e)
	return out


func event_count() -> int:
	return _log.size()


# --- derivation (REBALANCE HERE) ----------------------------------------------

## Standing = sum of deltas. Deliberately simple; this is the single seam where
## decay, diminishing returns, or actor weighting land later — saves carry the
## log, so any change here retroactively re-scores history without migration.
func _derive(events: Array[ReputationEvent]) -> float:
	var total := 0.0
	for e in events:
		total += e.delta
	return total


# --- persistence (the log IS the save data; standings are rebuilt) -------------

func to_dict() -> Dictionary:
	var rows: Array[Dictionary] = []
	for e in _log:
		rows.append(e.to_dict())
	return {"log": rows, "next_order": _next_order}


func from_dict(d: Dictionary) -> void:
	_log.clear()
	_standings.clear()
	for row in d.get("log", []):
		_log.append(ReputationEvent.from_dict(row))
	_next_order = int(d.get("next_order", _log.size()))
	_rebuild()


func _rebuild() -> void:
	_standings.clear()
	var by_faction: Dictionary = {}
	for e in _log:
		by_faction.get_or_add(e.faction, [] as Array[ReputationEvent]).append(e)
	for faction in by_faction:
		_standings[faction] = _derive(by_faction[faction])


func _current_scene_id() -> String:
	var cur := get_tree().current_scene
	return cur.scene_file_path if cur != null else ""
