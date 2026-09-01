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

## Ordering of the bands returned by band(). Lives here, next to the thresholds
## it ranks, so a rebalance moves both together. Callers that gate on "at least
## band X" must use band_at_least() rather than comparing raw standings against
## a copied threshold — a copied threshold silently stops tracking a rebalance.
const BAND_RANK := {
	&"hostile": 0,
	&"cold": 1,
	&"neutral": 2,
	&"warm": 3,
	&"allied": 4,
}

var _log: Array[ReputationEvent] = []
var _next_order: int = 0
## Derived cache: faction -> standing. Rebuilt from the log; never authoritative.
var _standings: Dictionary = {}
## Derived cache: faction -> array of events. Speeds up why() and events_for().
var _events_by_faction: Dictionary = {}


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

	if not _events_by_faction.has(faction):
		_events_by_faction[faction] = [] as Array[ReputationEvent]
	var faction_events: Array[ReputationEvent] = _events_by_faction[faction]
	faction_events.append(e)

	_standings[faction] = _derive(faction_events)
	# The signal and the return value are the two other ways a stored event could
	# escape by reference, and the signal is the one every live observer uses.
	# Both hand out copies so an observer cannot rewrite the log it is watching.
	reputation_changed.emit(faction, _standings[faction], e.copy())
	return e.copy()


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


## True when `faction`'s current band is at least `minimum_band`. An empty
## minimum means "no requirement". An unknown band id is a programming error,
## not a permissive default — it refuses and reports.
func band_at_least(faction: String, minimum_band: StringName) -> bool:
	if minimum_band.is_empty():
		return true
	if not BAND_RANK.has(minimum_band):
		push_error("Unknown reputation band: %s" % minimum_band)
		return false
	return int(BAND_RANK[band(faction)]) >= int(BAND_RANK[minimum_band])


## All factions that have ever appeared in the log, with their standings.
func all_standings() -> Dictionary:
	return _standings.duplicate()


## The query the whole design exists for: the most recent reasons, newest first.
func why(faction: String, limit: int = 5) -> Array[ReputationEvent]:
	var events: Array[ReputationEvent] = _events_by_faction.get(faction, [] as Array[ReputationEvent])
	var out: Array[ReputationEvent] = []
	var total := events.size()
	var count := mini(limit, total)
	for i in range(count):
		out.append(events[total - 1 - i].copy())
	return out


## The whole append-only log, newest first. This is a read-only derived query;
## limit <= 0 returns every event. Like every read here it yields COPIES: the log
## is append-only, and an accessor handing out the stored RefCounted would let a
## caller rewrite history in place while the derived standings kept the old total.
func history(limit: int = 0) -> Array[ReputationEvent]:
	var out: Array[ReputationEvent] = []
	var total: int = _log.size()
	var count: int = total if limit <= 0 else mini(limit, total)
	for index: int in range(count):
		out.append(_log[total - 1 - index].copy())
	return out


func events_for(faction: String) -> Array[ReputationEvent]:
	var events: Array[ReputationEvent] = _events_by_faction.get(faction, [] as Array[ReputationEvent])
	# duplicate() is a SHALLOW copy — a new array of the same event objects — so
	# the copies have to be made per element, not by copying the array.
	var out: Array[ReputationEvent] = []
	for e: ReputationEvent in events:
		out.append(e.copy())
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
	_events_by_faction.clear()
	for row in d.get("log", []):
		_log.append(ReputationEvent.from_dict(row))
	_next_order = int(d.get("next_order", _log.size()))
	_rebuild()


func _rebuild() -> void:
	_standings.clear()
	_events_by_faction.clear()
	for e in _log:
		if not _events_by_faction.has(e.faction):
			_events_by_faction[e.faction] = [] as Array[ReputationEvent]
		_events_by_faction[e.faction].append(e)
	for faction in _events_by_faction:
		_standings[faction] = _derive(_events_by_faction[faction])


func _current_scene_id() -> String:
	var cur := get_tree().current_scene
	return cur.scene_file_path if cur != null else ""
