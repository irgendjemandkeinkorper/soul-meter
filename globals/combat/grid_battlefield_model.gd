class_name GridBattlefieldModel
extends BattlefieldModel
## FR-105a grid seam (issue #137, architecture doc §1.6, amendment §2.1/§2.3).
##
## Owns exactly one `IsoGrid` (world/nav/iso_grid.gd) and expresses it through the same
## opaque-handle contract `zone_battlefield_model.gd` already satisfies. Nothing outside this
## file may construct or parse a position `StringName` — see `_handle_for_cell()` /
## `_parse_handle()`, the only two places that touch the wire format (`&"c:<x>,<y>,<elev>"`,
## per architecture doc §1.3's example).
##
## Two knobs stay orthogonal on purpose, per doc §1.6: `set_elevation()` scales the CT cost of
## entering a cell (`IsoGrid.set_point_weight_scale()`); `set_cliff()` makes a cell impassable
## outright (`IsoGrid.set_point_solid()`). A cliff must never merely be expensive — collapsing
## the two into one derived rule would make "blocked by elevation" and "expensive because of
## elevation" the same refusal, which FR-606 forbids.
##
## No map is authored here. `build_grid()` takes bare `TileMapLayer` nodes and elevation/cliff
## data from the caller that owns the encounter; this file supplies the mechanism only.
##
## Determinism: no RNG anywhere below. `IsoGrid`/`AStarGrid2D` tie-breaks are stable (lowest
## cell index wins), and `reachable_positions()` sorts its own result by handle string, so the
## same query returns the same answer every time — required for the save/replay path this
## interface will eventually serve (doc §1.8).

const ALLY := &"ally"
const ENEMY := &"enemy"

## 8-direction facing order, also used to compute "opposite" for flank checks. Index 0 is east;
## indices increase clockwise on screen (Godot's y grows downward).
const _ORDER: Array[StringName] = [
	&"e", &"se", &"s", &"sw", &"w", &"nw", &"n", &"ne"
]

## Chebyshev cells a query will scan outward from an actor while bounding reachable_positions()
## by CT budget. Weight scale only ever raises a step's cost above 1.0, so budget / move_ct_cost
## is a safe (if occasionally generous) upper bound on radius.
const _LOS_MAX_RANGE := 12.0
## Ridge must clear the interpolated sightline by more than this to count as blocking. Guards
## against float noise turning a flat line into a false elevation block.
const _ELEVATION_LOS_EPSILON := 0.5
## CT-cost weight added per level of terrain elevation. A cliff is handled separately (solid),
## never through this multiplier — see the header note.
const _ELEVATION_WEIGHT_PER_LEVEL := 0.5

var _rules: CombatRules
var _grid: IsoGrid

## Terrain height per cell. Static per battlefield build, not per-actor: this is what the
## handle's elevation component (§1.3) reports.
var _elevation: Dictionary = {}  ## Vector2i -> int
## Cells explicitly authored impassable, independent of elevation weight.
var _cliffs: Dictionary = {}  ## Vector2i -> bool
## Cells that grant partial cover without blocking movement or line of sight.
var _cover: Dictionary = {}  ## Vector2i -> bool

## Keyed on `BattleActor.combat_id` (StringName) — the FR-802 stable id assigned by
## `CombatController._assign_combat_ids()` at encounter setup (issue #186). Deliberately NOT
## `actor.get_instance_id()`: that is process-local, does not survive a save round trip, and is
## allocation-order dependent rather than deterministic across two runs with identical inputs.
## Cached tiles_snapshot() result. Terrain is static per build, so the per-cell dicts
## are built once and shared by reference across every CombatEvent snapshot — consumers
## treat them as read-only (the stage region deep-duplicates what it keeps).
var _tiles_snapshot_cache: Array[Dictionary] = []

var _cells: Dictionary = {}  ## StringName (combat_id) -> Vector2i
var _sides: Dictionary = {}  ## StringName (combat_id) -> StringName
var _facings: Dictionary = {}  ## StringName (combat_id) -> StringName
var _occupancy: Dictionary = {}  ## Vector2i -> BattleActor
var _groups: Dictionary = {ALLY: [], ENEMY: []}


func configure(rules: CombatRules) -> void:
	_rules = rules


## Builds the shared `IsoGrid` this model owns. Not scene-required: any caller (a real map
## loader later, or a test today) may hand this bare `TileMapLayer` nodes it built in code.
## Elevation/cliff data is supplied separately via `set_elevation()` / `set_cliff()` so the two
## concerns stay independently settable, per the header note.
func build_grid(ground: TileMapLayer, blocking: TileMapLayer = null) -> void:
	_tiles_snapshot_cache = []
	_grid = IsoGrid.new()
	_grid.build(ground, blocking)
	for cell: Vector2i in _elevation.keys():
		_apply_elevation_weight(cell)
	for cell: Vector2i in _cliffs.keys():
		if bool(_cliffs[cell]):
			_grid.set_point_solid(cell, true)


## Terrain height at `cell`. Scales the CT cost of entering it — never makes it impassable.
func set_elevation(cell: Vector2i, elevation: int) -> void:
	_tiles_snapshot_cache = []
	_elevation[cell] = elevation
	_apply_elevation_weight(cell)


func elevation_at(cell: Vector2i) -> int:
	return int(_elevation.get(cell, 0))


## Marks (or clears) `cell` as a cliff: impassable outright, regardless of elevation weight.
func set_cliff(cell: Vector2i, is_cliff: bool = true) -> void:
	_tiles_snapshot_cache = []
	_cliffs[cell] = is_cliff
	if _grid != null and _grid.is_in_bounds(cell):
		_grid.set_point_solid(cell, is_cliff)


## Authors partial cover independently from elevation and impassability.
func set_cover(cell: Vector2i, grants_cover: bool = true) -> void:
	_tiles_snapshot_cache = []
	_cover[cell] = grants_cover


func setup(allies: Array[BattleActor], enemies: Array[BattleActor]) -> void:
	for id: StringName in _cells.keys():
		_release_solid(_cells[id])
	_cells.clear()
	_sides.clear()
	_facings.clear()
	_occupancy.clear()
	_groups = {ALLY: allies.duplicate(), ENEMY: enemies.duplicate()}
	for actor in allies:
		_sides[actor.combat_id] = ALLY
	for actor in enemies:
		_sides[actor.combat_id] = ENEMY
	if _grid == null:
		return
	var rect := _grid.get_used_rect()
	for i in allies.size():
		_place(allies[i], Vector2i(rect.position.x, rect.position.y + i), &"e")
	for i in enemies.size():
		_place(enemies[i], Vector2i(rect.end.x - 1, rect.position.y + i), &"w")


func position_of(actor: BattleActor) -> StringName:
	if actor == null or not _cells.has(actor.combat_id):
		return &""
	return _handle_for_cell(_cells[actor.combat_id])


func side_of(actor: BattleActor) -> StringName:
	if actor == null:
		return &""
	return StringName(_sides.get(actor.combat_id, &""))


func has_combatant(actor: BattleActor) -> bool:
	return actor != null and _sides.has(actor.combat_id)


func combatants_on_side(side: StringName) -> Array[BattleActor]:
	var result: Array[BattleActor] = []
	for actor: BattleActor in _groups.get(side, []):
		result.append(actor)
	return result


func remove_combatant(actor: BattleActor) -> Dictionary:
	if not has_combatant(actor):
		return _blocked(
			&"composition", "Combatant is not on the battlefield.", {"type": &"present_combatant"}
		)
	var previous_side := side_of(actor)
	var previous_position := position_of(actor)
	var id := actor.combat_id
	if _cells.has(id):
		var cell: Vector2i = _cells[id]
		_occupancy.erase(cell)
		_release_solid(cell)
		_cells.erase(id)
	_facings.erase(id)
	_sides.erase(id)
	var group: Array = _groups.get(previous_side, [])
	group.erase(actor)
	return _allowed({"from_side": previous_side, "from_position": previous_position})


func transfer_combatant(actor: BattleActor, new_side: StringName) -> Dictionary:
	if not has_combatant(actor):
		return _blocked(
			&"composition", "Combatant is not on the battlefield.", {"type": &"present_combatant"}
		)
	if not _groups.has(new_side):
		return _blocked(
			&"composition", "Unknown battlefield side: %s." % new_side, {"type": &"known_side"}
		)
	var previous_side := side_of(actor)
	if previous_side == new_side:
		return _blocked(
			&"composition", "Combatant is already on that side.", {"type": &"different_side"}
		)
	var previous_group: Array = _groups.get(previous_side, [])
	previous_group.erase(actor)
	var new_group: Array = _groups.get(new_side, [])
	new_group.append(actor)
	_sides[actor.combat_id] = new_side
	return _allowed({"from_side": previous_side, "to_side": new_side})


func move(actor: BattleActor, destination: StringName) -> Dictionary:
	var query := move_query(actor, destination)
	if not bool(query.get("allowed", false)):
		return query
	var parsed := _parse_handle(destination)
	var dest_cell: Vector2i = parsed["cell"]
	var origin_cell: Vector2i = _cells[actor.combat_id]
	_occupancy.erase(origin_cell)
	_release_solid(origin_cell)
	_occupancy[dest_cell] = actor
	_grid.set_point_solid(dest_cell, true)
	var previous := position_of(actor)
	_cells[actor.combat_id] = dest_cell
	return _allowed({
		"from": previous,
		"to": position_of(actor),
		"ct_cost": int(query.get("ct_cost", 0)),
		"path": query.get("path", []),
	})


func move_query(actor: BattleActor, destination: StringName) -> Dictionary:
	var query := path_query(actor, destination)
	if not bool(query.get("allowed", false)):
		return query
	return _allowed({
		"from": position_of(actor), "to": destination, "ct_cost": query.get("ct_cost", 0),
		"path": query.get("path", []),
	})


func target_query(actor: BattleActor, target: BattleActor, profile: StringName) -> Dictionary:
	if not has_combatant(actor):
		return _blocked(
			&"target", "Acting combatant is not on the battlefield.", {"type": &"present_actor"}
		)
	if not has_combatant(target) or not target.is_alive():
		return _blocked(&"target", "Target is not available.", {"type": &"living_target"})
	if profile == &"self":
		return _allowed() if actor == target else _blocked(
			&"target", "This action targets only its user.", {"type": &"self"}
		)
	if side_of(actor) == side_of(target):
		return _blocked(&"target", "This action requires an opposing target.", {"type": &"enemy"})
	if profile == &"encounter" or profile == &"any_enemy":
		return _allowed()
	if profile == &"ranged":
		return line_of_sight(actor, target)
	if profile == &"melee":
		if _chebyshev(_cells[actor.combat_id], _cells[target.combat_id]) > 1:
			return _blocked(
				&"position", "Move adjacent to make a melee attack.", {"type": &"adjacency"}
			)
		var height_difference := absi(elevation_delta(actor, target))
		var jump := maxi(actor.attribute_value(&"jump"), 0)
		if height_difference > jump:
			return _blocked(
				&"blocked_by_elevation",
				"The elevation difference exceeds this combatant's jump.",
				{"type": &"jump", "required": height_difference, "available": jump},
			)
		return _allowed()
	return _blocked(
		&"target_profile",
		"Unknown targeting profile: %s." % profile,
		{"type": &"target_profile"},
	)


## PROVISIONAL magnitude comes from CombatRules.cover_defense_bonus (currently +2 defense).
## Cover is DEFENDER-ANCHORED and DIRECTIONAL: the bonus applies only when a cover tile is
## Chebyshev-adjacent to the target AND strictly nearer the attacker than the target is —
## i.e. the target is hugging cover that stands between it and the shot. A crate beside the
## ATTACKER grants nothing (the round-1 rule was directionless; Wave P gate finding class).
func cover_bonus(actor: BattleActor, target: BattleActor) -> int:
	if _rules == null or not has_combatant(actor) or not has_combatant(target):
		return 0
	var attacker_cell: Vector2i = _cells[actor.combat_id]
	var target_cell: Vector2i = _cells[target.combat_id]
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			if x_offset == 0 and y_offset == 0:
				continue
			var cover_cell := target_cell + Vector2i(x_offset, y_offset)
			if not bool(_cover.get(cover_cell, false)):
				continue
			if _chebyshev(cover_cell, attacker_cell) < _chebyshev(target_cell, attacker_cell):
				return _rules.cover_defense_bonus
	return 0


func flank_bonus(actor: BattleActor, target: BattleActor) -> int:
	if _rules == null or not has_combatant(actor) or not has_combatant(target):
		return 0
	var target_facing := facing_of(target)
	if target_facing == &"":
		return 0
	var attack_dir := _direction_of(
		_cells[actor.combat_id] - _cells[target.combat_id]
	)
	# Front is the only safe direction; side and back both consume the flank term.
	if attack_dir != &"" and attack_dir != target_facing:
		return _rules.flank_power_bonus
	return 0


func targets_for(
	actor: BattleActor, primary: BattleActor, shape: StringName
) -> Array[BattleActor]:
	var result: Array[BattleActor] = []
	if primary == null:
		return result
	if shape == &"single" or shape == &"position":
		if primary.is_alive():
			result.append(primary)
		return result
	if shape == &"side":
		for candidate: BattleActor in _groups.get(side_of(primary), []):
			if candidate.is_alive():
				result.append(candidate)
		return result
	var query := target_query(actor, primary, &"any_enemy")
	if bool(query.get("allowed", false)):
		result.append(primary)
	return result


func tiles_snapshot() -> Array[Dictionary]:
	if _grid == null:
		return []
	if _tiles_snapshot_cache.is_empty():
		var rect := _grid.get_used_rect()
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if not _grid.is_in_bounds(cell):
					continue
				_tiles_snapshot_cache.append({
					"x": x,
					"y": y,
					"height_delta": elevation_at(cell),
					"cliff": bool(_cliffs.get(cell, false)),
					"cover": bool(_cover.get(cell, false)),
				})
	return _tiles_snapshot_cache


func capabilities() -> Dictionary:
	return {
		"cells": true,
		"elevation": true,
		"facing": true,
		"occupancy": true,
		"line_of_sight": true,
		"path_cost": true,
		"cover": true,
	}


func describe_position(position: StringName) -> Dictionary:
	var parsed := _parse_handle(position)
	if not bool(parsed.get("ok", false)):
		return {}
	return {"kind": &"cell", "cell": parsed["cell"], "elevation": parsed["elevation"]}


## Budget-bounded flood fill (architecture doc §1.6). Scans an expanding box around the actor
## and keeps every cell `path_query()` (the same A* this model uses for real moves) reports
## reachable within `ct_budget` — so the range display and an actual move never disagree.
func reachable_positions(actor: BattleActor, ct_budget: int) -> Array[StringName]:
	var result: Array[StringName] = []
	if _grid == null or not has_combatant(actor):
		return result
	var id := actor.combat_id
	if not _cells.has(id):
		return result
	var origin: Vector2i = _cells[id]
	var move_cost := maxi(1, _rules.move_ct_cost if _rules != null else 1)
	var max_radius := int(ct_budget / move_cost) + 1
	var rect := _grid.get_used_rect()
	var min_y := maxi(rect.position.y, origin.y - max_radius)
	var max_y := mini(rect.end.y - 1, origin.y + max_radius)
	var min_x := maxi(rect.position.x, origin.x - max_radius)
	var max_x := mini(rect.end.x - 1, origin.x + max_radius)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cell := Vector2i(x, y)
			if cell == origin:
				continue
			var handle := _handle_for_cell(cell)
			var query := path_query(actor, handle)
			if bool(query.get("allowed", false)) and int(query.get("ct_cost", 0)) <= ct_budget:
				result.append(handle)
	result.sort()
	return result


## Path cost in the refusal shape (doc §1.3). Adds `ct_cost`/`path` when allowed. This is the
## one place that walks the shared `IsoGrid`'s A* — `move()`, `move_query()`, and
## `reachable_positions()` all route through it so the quoted cost and the paid cost can never
## drift apart (doc §1.7).
func path_query(actor: BattleActor, destination: StringName) -> Dictionary:
	if _grid == null:
		return _blocked(&"position", "Grid battlefield has not been built.", {"type": &"grid_ready"})
	if not has_combatant(actor):
		return _blocked(
			&"position", "Acting combatant is not on the battlefield.", {"type": &"present_actor"}
		)
	var parsed := _parse_handle(destination)
	if not bool(parsed.get("ok", false)):
		return _blocked(
			&"position", "Unknown battlefield position: %s." % destination, {"type": &"position"}
		)
	var dest_cell: Vector2i = parsed["cell"]
	if not _grid.is_in_bounds(dest_cell):
		return _blocked(
			&"position", "That cell is outside the battlefield.", {"type": &"in_bounds"}
		)
	if _grid.is_point_solid(dest_cell) and _occupancy.get(dest_cell) == null:
		return _blocked(&"position", "That cell is impassable.", {"type": &"cell_passable"})
	var occupant: BattleActor = _occupancy.get(dest_cell)
	if occupant != null and occupant != actor:
		return _blocked(&"position", "That cell is occupied.", {"type": &"cell_free"})
	var origin_cell: Vector2i = _cells[actor.combat_id]
	if origin_cell == dest_cell:
		return _blocked(&"position", "Combatant is already there.", {"type": &"different_position"})
	var was_solid := _grid.is_point_solid(origin_cell)
	_grid.set_point_solid(origin_cell, false)
	var path := _deterministic_path(origin_cell, dest_cell)
	_grid.set_point_solid(origin_cell, was_solid)
	if path.is_empty():
		return _blocked(&"position", "No path to that cell.", {"type": &"reachable"})
	var handles: Array[StringName] = []
	for point in path:
		handles.append(_handle_for_cell(Vector2i(point)))
	return _allowed({"ct_cost": _path_ct_cost(path), "path": handles})


func facing_of(actor: BattleActor) -> StringName:
	if actor == null:
		return &""
	return StringName(_facings.get(actor.combat_id, &""))


func set_facing(actor: BattleActor, facing: StringName) -> Dictionary:
	if not has_combatant(actor):
		return _blocked(
			&"facing", "Combatant is not on the battlefield.", {"type": &"present_combatant"}
		)
	if not _ORDER.has(facing):
		return _blocked(
			&"facing", "Unknown facing: %s." % facing, {"type": &"facing", "valid": _ORDER.duplicate()}
		)
	_facings[actor.combat_id] = facing
	return _allowed({"facing": facing})


## Line of sight in the refusal shape. `blocked_by` names one of three causes — FR-606 forbids
## collapsing these into a single `&"no_los"` (doc §1.3, §2.2). "High ground sees across low
## cover": an intermediate occupant only blocks sight when the viewer is not strictly higher
## than it.
func line_of_sight(actor: BattleActor, target: BattleActor) -> Dictionary:
	if _grid == null or not has_combatant(actor) or not has_combatant(target):
		return _blocked(
			&"blocked_by_range", "Combatant is not on the battlefield.", {"type": &"present_combatant"}
		)
	var from_cell: Vector2i = _cells[actor.combat_id]
	var to_cell: Vector2i = _cells[target.combat_id]
	if _chebyshev(from_cell, to_cell) > _LOS_MAX_RANGE:
		return _blocked(
			&"blocked_by_range",
			"Target is beyond line-of-sight range.",
			{"type": &"range", "max_range": _LOS_MAX_RANGE},
		)
	var from_elev := elevation_at(from_cell)
	var to_elev := elevation_at(to_cell)
	var line := _bresenham(from_cell, to_cell)
	var last_index := line.size() - 1
	for i in range(1, last_index):
		var cell: Vector2i = line[i]
		var t := float(i) / float(last_index)
		var interpolated_elev := lerpf(float(from_elev), float(to_elev), t)
		if float(elevation_at(cell)) > interpolated_elev + _ELEVATION_LOS_EPSILON:
			return _blocked(
				&"blocked_by_elevation",
				"Higher ground blocks the line of sight.",
				{"type": &"elevation", "cell": cell},
			)
		var occupant: BattleActor = _occupancy.get(cell)
		if occupant != null and occupant != actor and occupant != target:
			if from_elev <= elevation_at(cell):
				return _blocked(
					&"blocked_by_occupancy",
					"A combatant blocks the line of sight.",
					{"type": &"occupancy", "cell": cell},
				)
	return _allowed()


func occupant_of(position: StringName) -> BattleActor:
	var parsed := _parse_handle(position)
	if not bool(parsed.get("ok", false)):
		return null
	return _occupancy.get(parsed["cell"])


func elevation_delta(actor: BattleActor, target: BattleActor) -> int:
	if not has_combatant(actor) or not has_combatant(target):
		return 0
	return elevation_at(_cells[target.combat_id]) - elevation_at(_cells[actor.combat_id])


# ---- internal: the only code in the project allowed to build or parse a position handle ----


func _handle_for_cell(cell: Vector2i) -> StringName:
	return StringName("c:%d,%d,%d" % [cell.x, cell.y, elevation_at(cell)])


func _parse_handle(handle: StringName) -> Dictionary:
	var text := String(handle)
	if not text.begins_with("c:"):
		return {"ok": false}
	var parts := text.substr(2).split(",")
	if parts.size() != 3:
		return {"ok": false}
	for part in parts:
		if not part.is_valid_int():
			return {"ok": false}
	return {
		"ok": true,
		"cell": Vector2i(int(parts[0]), int(parts[1])),
		"elevation": int(parts[2]),
	}


# ---- internal: placement, cost, geometry ----


func _place(actor: BattleActor, cell: Vector2i, facing: StringName) -> void:
	var rect := _grid.get_used_rect()
	var clamped := Vector2i(
		clampi(cell.x, rect.position.x, rect.end.x - 1),
		clampi(cell.y, rect.position.y, rect.end.y - 1),
	)
	var id := actor.combat_id
	_cells[id] = clamped
	_facings[id] = facing
	_occupancy[clamped] = actor
	_grid.set_point_solid(clamped, true)


func _apply_elevation_weight(cell: Vector2i) -> void:
	if _grid == null or not _grid.is_in_bounds(cell):
		return
	var elevation := elevation_at(cell)
	_grid.set_point_weight_scale(cell, maxf(1.0, 1.0 + float(elevation) * _ELEVATION_WEIGHT_PER_LEVEL))


## Restores a vacated cell's solid flag. A cliff cell must stay solid even after whatever stood
## on it moves or dies — occupancy and cliff-impassability share `IsoGrid.set_point_solid()`,
## so vacating must not accidentally reopen a cliff.
func _release_solid(cell: Vector2i) -> void:
	if _grid != null:
		_grid.set_point_solid(cell, bool(_cliffs.get(cell, false)))


func _path_ct_cost(path: PackedVector2Array) -> int:
	var move_cost := _rules.move_ct_cost if _rules != null else 1
	var total := 0
	for i in range(1, path.size()):
		var cell := Vector2i(path[i])
		total += int(ceil(move_cost * _grid.get_point_weight_scale(cell)))
	return total


## AStarGrid2D is deterministic on one engine build, but its equal-f-score choice is not the
## Gate T contract: equal-cost paths must prefer the lowest row-major cell index. This compact
## Dijkstra walk makes that tie-break explicit while preserving octile diagonal cost and the
## no-corner-cutting rule used by IsoGrid.
func _deterministic_path(from_cell: Vector2i, to_cell: Vector2i) -> PackedVector2Array:
	var rect := _grid.get_used_rect()
	var frontier: Array[Dictionary] = [{"cell": from_cell, "cost": 0.0}]
	var costs: Dictionary = {from_cell: 0.0}
	var previous: Dictionary = {}
	while not frontier.is_empty():
		frontier.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if not is_equal_approx(float(a["cost"]), float(b["cost"])):
				return float(a["cost"]) < float(b["cost"])
			return _cell_index(a["cell"], rect) < _cell_index(b["cell"], rect)
		)
		var current: Dictionary = frontier.pop_front()
		var cell: Vector2i = current["cell"]
		if float(current["cost"]) > float(costs.get(cell, INF)):
			continue
		if cell == to_cell:
			break
		var neighbors: Array[Vector2i] = []
		for y_offset in range(-1, 2):
			for x_offset in range(-1, 2):
				if x_offset == 0 and y_offset == 0:
					continue
				var next := cell + Vector2i(x_offset, y_offset)
				if not _grid.is_in_bounds(next) or _grid.is_point_solid(next):
					continue
				if x_offset != 0 and y_offset != 0:
					if (
						_grid.is_point_solid(cell + Vector2i(x_offset, 0))
						or _grid.is_point_solid(cell + Vector2i(0, y_offset))
					):
						continue
				neighbors.append(next)
		neighbors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return _cell_index(a, rect) < _cell_index(b, rect)
		)
		for next in neighbors:
			var diagonal := next.x != cell.x and next.y != cell.y
			var step_cost := (sqrt(2.0) if diagonal else 1.0) * _grid.get_point_weight_scale(next)
			var next_cost := float(costs[cell]) + step_cost
			if next_cost + 0.000001 < float(costs.get(next, INF)):
				costs[next] = next_cost
				previous[next] = cell
				frontier.append({"cell": next, "cost": next_cost})
	if not costs.has(to_cell):
		return PackedVector2Array()
	var reversed: Array[Vector2i] = [to_cell]
	var cursor := to_cell
	while cursor != from_cell:
		cursor = previous[cursor]
		reversed.append(cursor)
	reversed.reverse()
	return PackedVector2Array(reversed)


static func _cell_index(cell: Vector2i, rect: Rect2i) -> int:
	return (cell.y - rect.position.y) * rect.size.x + (cell.x - rect.position.x)


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _direction_of(delta: Vector2i) -> StringName:
	if delta == Vector2i.ZERO:
		return &""
	var angle := atan2(delta.y, delta.x)
	var index := int(round(angle / (PI / 4.0)))
	index = ((index % 8) + 8) % 8
	return _ORDER[index]


func _opposite(facing: StringName) -> StringName:
	var i := _ORDER.find(facing)
	if i == -1:
		return &""
	return _ORDER[(i + 4) % 8]


func _bresenham(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var x0 := from_cell.x
	var y0 := from_cell.y
	var x1 := to_cell.x
	var y1 := to_cell.y
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return points
