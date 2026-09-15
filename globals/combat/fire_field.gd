class_name FireField
extends RefCounted
## Khash prototype fire substrate (docs/ideas/khash-prototype-spell-cards.md, "Creature fire
## and the magical line"): magical fire lines on grid cells, creature Burning, Soaked
## protection, and the one-hazard-event-per-creature-per-round cap.
##
## Pure data and rules. `CombatController` owns every HP change and routes each hazard event
## and burn tick through `_apply_resolution_writes()`, so class-resource hooks see each real
## damage event exactly once and the replay path stays deterministic. Nothing here touches the
## scene tree, the scheduler, or an actor's HP directly.
##
## Every number below is PROVISIONAL playtest content from the prototype card sheet; the
## balance owner retunes them with evidence, not this file.

## Round checkpoints a Firebreak line survives after creation.
const LINE_DURATION_CHECKPOINTS := 2
## Fixed HP loss on the first entry or occupancy of a fire line in a round.
const HAZARD_DAMAGE := 3
## Fixed HP loss per Burning tick.
const BURN_TICK_DAMAGE := 3
## Ticks a fresh (or refreshed) Burning delivers at the next round checkpoints.
const BURNING_TICKS := 2
## Round checkpoints Douse's Soaked state protects a creature from this packet's Burning.
const SOAKED_CHECKPOINTS := 2

const IMPOSITION_BURNING := "burning"
const IMPOSITION_SOAKED := "soaked"

## Active lines: {id, owner_id, cells: Array[Vector2i], remaining_checkpoints, created_round}.
var lines: Array[Dictionary] = []
## combat_id (String) -> round number of that creature's last hazard event.
var hazard_round: Dictionary = {}
var _sequence := 0


func reset() -> void:
	lines.clear()
	hazard_round.clear()
	_sequence = 0


func is_empty() -> bool:
	return lines.is_empty()


## Creates a line over `cells`. The caller has already validated legality per cell; cells that
## became illegal are dropped before this call ("cells that become illegal at the beat are
## skipped"). An empty cell list creates nothing and reports `{"allowed": false}`.
func create_line(owner_id: StringName, cells: Array[Vector2i], round_number: int) -> Dictionary:
	if cells.is_empty():
		return {"allowed": false, "blocked_by": &"empty_line", "message": "No legal cell remains for the fire line."}
	_sequence += 1
	var line := {
		"id": _sequence,
		"owner_id": String(owner_id),
		"cells": cells.duplicate(),
		"remaining_checkpoints": LINE_DURATION_CHECKPOINTS,
		"created_round": round_number,
	}
	lines.append(line)
	return {"allowed": true, "line": line.duplicate(true)}


## The line covering `cell`, or `{}`. When lines overlap, the first-created line wins the
## credit for a hazard event (stable id as the tie-breaker, per the packet's credit rule).
func line_at(cell: Vector2i) -> Dictionary:
	for line: Dictionary in lines:
		if (line["cells"] as Array).has(cell):
			return line
	return {}


func is_burning_cell(cell: Vector2i) -> bool:
	return not line_at(cell).is_empty()


func remove_line(line_id: int) -> bool:
	for index: int in lines.size():
		if int(lines[index].get("id", 0)) == line_id:
			lines.remove_at(index)
			return true
	return false


## True when `combat_id` has not yet taken a hazard event this round.
func hazard_due(combat_id: StringName, round_number: int) -> bool:
	return int(hazard_round.get(String(combat_id), -1)) != round_number


func mark_hazard(combat_id: StringName, round_number: int) -> void:
	hazard_round[String(combat_id)] = round_number


## Ages every line by one checkpoint and returns the lines that expired (already removed).
func advance_checkpoint() -> Array[Dictionary]:
	var expired: Array[Dictionary] = []
	var kept: Array[Dictionary] = []
	for line: Dictionary in lines:
		line["remaining_checkpoints"] = int(line.get("remaining_checkpoints", 0)) - 1
		if int(line["remaining_checkpoints"]) <= 0:
			expired.append(line.duplicate(true))
		else:
			kept.append(line)
	lines = kept
	return expired


## HUD-facing view: one entry per line with serializable cells.
func snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: Dictionary in lines:
		out.append(_serialize_line(line))
	return out


func to_dict() -> Dictionary:
	return {"sequence": _sequence, "lines": snapshot(), "hazard_round": hazard_round.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	reset()
	_sequence = int(data.get("sequence", 0))
	for raw: Variant in data.get("lines", []):
		if raw is Dictionary:
			lines.append(_deserialize_line(raw as Dictionary))
	var rounds: Variant = data.get("hazard_round", {})
	if rounds is Dictionary:
		for key: Variant in rounds as Dictionary:
			hazard_round[str(key)] = int((rounds as Dictionary)[key])


static func cells_to_data(cells: Array[Vector2i]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cell: Vector2i in cells:
		out.append({"x": cell.x, "y": cell.y})
	return out


## Accepts `[{x, y}]`, `[Vector2i]`, or a mix; anything else is dropped, never guessed.
static func cells_from_data(value: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not value is Array:
		return out
	for raw: Variant in value as Array:
		if raw is Vector2i:
			out.append(raw as Vector2i)
		elif raw is Dictionary and (raw as Dictionary).has("x") and (raw as Dictionary).has("y"):
			out.append(Vector2i(int((raw as Dictionary)["x"]), int((raw as Dictionary)["y"])))
	return out


## Three distinct cells forming a contiguous straight cardinal line (Firebreak's shape).
static func is_cardinal_line(cells: Array[Vector2i]) -> bool:
	if cells.size() != 3:
		return false
	var sorted := cells.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)
	var first: Vector2i = sorted[0]
	var second: Vector2i = sorted[1]
	var third: Vector2i = sorted[2]
	var step := second - first
	if step != Vector2i(1, 0) and step != Vector2i(0, 1):
		return false
	return third - second == step


# ─── Creature impositions (stored on BattleActor.impositions) ────────────────────────────


static func is_burning(actor: BattleActor) -> bool:
	return actor != null and actor.impositions.has(IMPOSITION_BURNING)


static func is_soaked(actor: BattleActor) -> bool:
	return actor != null and actor.impositions.has(IMPOSITION_SOAKED)


## Applies or refreshes Burning. Refreshing resets to two remaining ticks and transfers the tick
## credit to `source_id`; it never stacks. Refused while Soaked. Returns `{applied, refreshed}`.
static func apply_burning(actor: BattleActor, source_id: StringName) -> Dictionary:
	if actor == null:
		return {"applied": false, "refreshed": false, "reason": "no_target"}
	if is_soaked(actor):
		return {"applied": false, "refreshed": false, "reason": "soaked"}
	var refreshed := is_burning(actor)
	actor.impositions[IMPOSITION_BURNING] = {
		"remaining_ticks": BURNING_TICKS,
		"source_id": String(source_id),
	}
	return {"applied": true, "refreshed": refreshed, "reason": ""}


static func clear_burning(actor: BattleActor) -> bool:
	if actor == null or not is_burning(actor):
		return false
	actor.impositions.erase(IMPOSITION_BURNING)
	return true


static func apply_soaked(actor: BattleActor) -> void:
	if actor == null:
		return
	actor.impositions[IMPOSITION_SOAKED] = {"remaining_checkpoints": SOAKED_CHECKPOINTS}


## Consumes one Burning tick after its damage was applied; removes Burning at zero.
static func consume_burn_tick(actor: BattleActor) -> int:
	if not is_burning(actor):
		return 0
	var burning: Dictionary = actor.impositions[IMPOSITION_BURNING]
	var remaining := int(burning.get("remaining_ticks", 0)) - 1
	if remaining <= 0:
		actor.impositions.erase(IMPOSITION_BURNING)
		return 0
	burning["remaining_ticks"] = remaining
	return remaining


## Ages Soaked by one checkpoint; returns true when it expired at this checkpoint.
static func age_soaked(actor: BattleActor) -> bool:
	if not is_soaked(actor):
		return false
	var soaked: Dictionary = actor.impositions[IMPOSITION_SOAKED]
	var remaining := int(soaked.get("remaining_checkpoints", 0)) - 1
	if remaining <= 0:
		actor.impositions.erase(IMPOSITION_SOAKED)
		return true
	soaked["remaining_checkpoints"] = remaining
	return false


static func burn_source_id(actor: BattleActor) -> StringName:
	if not is_burning(actor):
		return &""
	return StringName(str((actor.impositions[IMPOSITION_BURNING] as Dictionary).get("source_id", "")))


static func _serialize_line(line: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = []
	cells.assign(line.get("cells", []))
	return {
		"id": int(line.get("id", 0)),
		"owner_id": String(line.get("owner_id", "")),
		"cells": cells_to_data(cells),
		"remaining_checkpoints": int(line.get("remaining_checkpoints", 0)),
		"created_round": int(line.get("created_round", 0)),
	}


static func _deserialize_line(data: Dictionary) -> Dictionary:
	return {
		"id": int(data.get("id", 0)),
		"owner_id": String(data.get("owner_id", "")),
		"cells": cells_from_data(data.get("cells", [])),
		"remaining_checkpoints": int(data.get("remaining_checkpoints", 0)),
		"created_round": int(data.get("created_round", 0)),
	}
