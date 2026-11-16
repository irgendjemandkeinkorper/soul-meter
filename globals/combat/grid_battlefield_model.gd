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
## No map is authored here. `build_grid()` consumes the field's Ground/Blocking layers and
## reads cover/elevation from its hidden Terrain sibling; this file supplies the mechanism only.
##
## Determinism: no RNG anywhere below. `IsoGrid`/`AStarGrid2D` tie-breaks are stable (lowest
## cell index wins), and `reachable_positions()` sorts its own result by handle string, so the
## same query returns the same answer every time — required for the save/replay path this
## interface will eventually serve (doc §1.8).
##
## Hexes (owner item 34, slice H2; `docs/design/hex-grid-plan-2026-11-03.md`). When the shared
## grid runs in hex mode (`soul_meter/grid/hex`), every cell below is an axial hex and the rules
## carry over by the plan's table: distances count hex steps (`GridMetric`), authored reaches and
## radii convert there, a move costs 1 CT per two hexes (an odd count rounds up), facing has six
## directions (front 1, side 4, back 1), sight lines walk hex lines, and each hex takes its
## height, cover and terrain from the square cell under its centre. Position handles keep their
## shape; on hexes they carry `q,r`.

const ALLY := &"ally"
const ENEMY := &"enemy"

## 8-direction facing order, also used to compute "opposite" for flank checks. Index 0 is east;
## indices increase clockwise on screen (Godot's y grows downward).
const _ORDER: Array[StringName] = [
	&"e", &"se", &"s", &"sw", &"w", &"nw", &"n", &"ne"
]
## Six hex facings in `HexMath.DIRECTIONS` order. They are screen directions, while the square
## names above are grid directions, so they carry a prefix and never alias one another.
const HEX_ORDER: Array[StringName] = [
	&"hex_e", &"hex_ne", &"hex_nw", &"hex_w", &"hex_sw", &"hex_se"
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

## Chebyshev cells an ambient-entry placement search may travel from a party member's own
## cell before the whole session is refused (F0 ruling 4, 2026-09-06). PROVISIONAL.
const PLACEMENT_SEARCH_RADIUS := 4

## 8-way steps for the placement search, matching the Chebyshev geometry the rest of this
## model uses. Listed row-major so an unsorted traversal is still deterministic.
const _PLACEMENT_STEPS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var _rules: CombatRules
var _grid: IsoGrid

## Terrain height per cell. Static per battlefield build, not per-actor: this is what the
## handle's elevation component (§1.3) reports.
var _elevation: Dictionary = {}  ## Vector2i -> int
## Cells explicitly authored impassable, independent of elevation weight.
var _cliffs: Dictionary = {}  ## Vector2i -> bool
## Cells that grant partial cover without blocking movement or line of sight.
var _cover: Dictionary = {}  ## Vector2i -> bool
## Cells authored as solid obstacles that block line of fire (walls), independent of the
## navigation blocking layer so a fence or shallow water never silently stops a shot.
var _obstacles: Dictionary = {}  ## Vector2i -> bool
## Authored physical visibility per cell; absent means clear.
var _visibility: Dictionary = {}  ## Vector2i -> StringName
const VISIBILITY_LEVELS: Array[StringName] = [&"clear", &"dim", &"obscured"]
## Field-grid flags as they were before combat first touched each cell, so
## `release_field_grid()` hands the shared IsoGrid back to navigation unchanged.
var _prior_solid: Dictionary = {}  ## Vector2i -> bool
var _prior_weight: Dictionary = {}  ## Vector2i -> float

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
## Actor references are local setup inputs: combat IDs are assigned by Controller.start().
var _initial_cells: Dictionary = {}
## Live probes: combat_id -> the real cell, restored by clear_probe().
var _probe_saved: Dictionary = {}
## Grows on every write to the board this model keeps: seats, occupancy, sides, terrain, rules
## or a rebuild (#642).
var _revision: int = 0
## Grows on the writes that can change any path answer: rules, a rebuild, a fresh setup.
var _structure_revision: int = 0
## Cell -> `_revision` at the last write that named it: a seat or occupancy change there, its
## elevation, cliff, cover, visibility or obstacle.
var _cell_revisions: Dictionary = {}


func configure_initial_cells(cells: Dictionary) -> Dictionary:
	if _grid == null:
		return _blocked(&"position", "Grid battlefield has not been built.", {"type": &"grid_ready"})
	var occupied: Dictionary = {}
	for actor: Variant in cells:
		if not actor is BattleActor or not cells[actor] is Vector2i:
			return _blocked(&"position", "Initial placement requires actors and cells.", {"type": &"known_position"})
		var cell: Vector2i = cells[actor]
		if not _grid.is_in_bounds(cell):
			return _blocked(&"position", "That %s is outside the battlefield." % GridMetric.step_word(1), {"type": &"cell_in_bounds"})
		if occupied.has(cell):
			return _blocked(&"position", "That cell is occupied.", {"type": &"cell_free"})
		if _grid.is_point_solid(cell):
			return _blocked(&"position", "That cell is impassable.", {"type": &"cell_passable"})
		occupied[cell] = true
	_initial_cells = cells.duplicate()
	return _allowed({})


## Ambient-entry placement (F0 ruling 4, 2026-09-06). `desired` is the party's live field
## cells in `GameState.party` order; `desired[0]` is the player, the anchor, and is never
## relocated. Members whose own cell is free keep it; overlapping members take the nearest
## free cell found by breadth-first search over *reachable* cells — never Euclidean, so a
## companion can never be seated across a wall from the party it is fighting with. Ties
## inside one search ring break by row then column, so the answer is identical across two
## runs and across a save round trip.
##
## Refusal is atomic by construction: this is a pure query over the grid, so a caller that
## refuses has moved nothing. Returns `{"cells": Array[Vector2i]}` on success.
func resolve_placement(desired: Array[Vector2i]) -> Dictionary:
	if _grid == null:
		return _blocked(&"position", "Grid battlefield has not been built.", {"type": &"grid_ready"})
	if desired.is_empty():
		return _blocked(
			&"composition", "There is no party to seat.", {"type": &"present_combatant"}
		)
	var anchor: Vector2i = desired[0]
	if not _is_seatable(anchor):
		return _blocked(
			&"position",
			"The party cannot enter combat from this %s." % GridMetric.step_word(1),
			{"type": &"anchor_placeable"},
		)
	var taken: Dictionary = {anchor: true}
	var resolved: Array[Vector2i] = [anchor]
	for index in range(1, desired.size()):
		var wanted: Vector2i = desired[index]
		if not taken.has(wanted) and _is_seatable(wanted):
			taken[wanted] = true
			resolved.append(wanted)
			continue
		var search := _nearest_free_cell(wanted, taken)
		if not bool(search.get("ok", false)):
			return _blocked(
				&"position",
				"No free %s within %d of the party." % [GridMetric.step_word(1), PLACEMENT_SEARCH_RADIUS],
				{"type": &"cell_free"},
			)
		var found: Vector2i = search["cell"]
		taken[found] = true
		resolved.append(found)
	return _allowed({"cells": resolved})


## Set-piece seating (#281 D5): `wanted` itself when it is free, otherwise the nearest free
## reachable cell under the same bounded search `resolve_placement()` uses for an overlapping
## companion. `taken` holds the cells this placement pass already handed out. Same return
## shape as that search: `{"ok": true, "cell": Vector2i}` or `{"ok": false}`.
##
## With `reach_from` (a cell, the party's anchor), the seat must also stand on the anchor's
## side of every wall: see `_nearest_cell_reached_from()`. Without it the search is unchanged.
func seat_near(wanted: Vector2i, taken: Dictionary, reach_from: Variant = null) -> Dictionary:
	if _grid == null:
		return {"ok": false}
	if reach_from is Vector2i:
		return _nearest_cell_reached_from(reach_from, wanted, taken)
	if not taken.has(wanted) and _is_seatable(wanted):
		return {"ok": true, "cell": wanted}
	return _nearest_free_cell(wanted, taken)


## In bounds, passable, and nothing already stands there. Occupied cells are also solid (see
## `_place()`), so the occupancy test is belt-and-braces against a caller that seats actors
## through a path that skips `_set_solid()`.
func _is_seatable(cell: Vector2i) -> bool:
	return (
		_grid != null
		and _grid.is_in_bounds(cell)
		and not _grid.is_point_solid(cell)
		and not _occupancy.has(cell)
	)


## Breadth-first ring search outward from `from`, bounded by `PLACEMENT_SEARCH_RADIUS`.
## Impassable cells are not traversed, only skipped: a candidate is therefore always
## connected to the cell its actor is standing on, which is what "reachable" buys over a
## radius test. Each ring is sorted by row then column before it is examined, so the first
## acceptable cell in the nearest ring is a deterministic choice, not an insertion-order one.
func _nearest_free_cell(from: Vector2i, taken: Dictionary) -> Dictionary:
	var visited: Dictionary = {from: true}
	var frontier: Array[Vector2i] = [from]
	var steps: Array[Vector2i] = _grid.neighbor_offsets() if _grid.hex_mode else _PLACEMENT_STEPS
	for _depth in GridMetric.radius(PLACEMENT_SEARCH_RADIUS):
		var ring: Array[Vector2i] = []
		for cell: Vector2i in frontier:
			for step: Vector2i in steps:
				var neighbour: Vector2i = cell + step
				if visited.has(neighbour):
					continue
				if not _grid.is_in_bounds(neighbour) or _grid.is_point_solid(neighbour):
					visited[neighbour] = true
					continue
				if _grid.is_edge_walled(cell, neighbour):
					# Another ring cell may still reach it without crossing the wall.
					continue
				visited[neighbour] = true
				ring.append(neighbour)
		ring.sort_custom(_row_then_column)
		for cell: Vector2i in ring:
			if not taken.has(cell) and not _occupancy.has(cell):
				return {"ok": true, "cell": cell}
		if ring.is_empty():
			break
		frontier = ring
	return {"ok": false}


## Set-piece seats that cannot land across a wall (T1, 2026-11-07). `wanted` comes from a fixed
## screen offset, so it may lie in the next room, or inside the wall itself; the search around
## it then accepts only cells the anchor reaches. The candidates are the free cells within
## `PLACEMENT_SEARCH_RADIUS` of `wanted`, nearest ring first, each ring by row then column, as in
## `_nearest_free_cell()`. A candidate is reached when a path from the anchor gets there without
## entering a wall or cliff, crossing a walled hex edge, or cutting a wall corner on squares, and
## that path is at most `PLACEMENT_SEARCH_RADIUS` steps longer than the straight distance. The
## bound keeps a door far along the wall from opening the far side: a party inside a building
## does not get its foes seated in the street beyond the wall it stands against. Actors do not
## close a path; they only take their own cells.
func _nearest_cell_reached_from(anchor: Vector2i, wanted: Vector2i, taken: Dictionary) -> Dictionary:
	var radius := GridMetric.radius(PLACEMENT_SEARCH_RADIUS)
	var depth := _wall_free_steps(anchor, GridMetric.distance(anchor, wanted) + 2 * radius)
	for ring_steps in radius + 1:
		var ring := GridMetric.ring(wanted, ring_steps)
		ring.sort_custom(_row_then_column)
		for cell: Vector2i in ring:
			if not depth.has(cell) or taken.has(cell) or not _is_seatable(cell):
				continue
			if int(depth[cell]) <= GridMetric.distance(anchor, cell) + radius:
				return {"ok": true, "cell": cell}
	return {"ok": false}


## Steps from `from` to every cell a wall-free path reaches within `limit` steps (breadth-first,
## so each count is the shortest). Hex steps may not cross a walled edge; a square diagonal may
## not cut the corner of a blocked cell, the rule movement uses. A cell an actor stands on is
## passable here: a body is not a wall.
func _wall_free_steps(from: Vector2i, limit: int) -> Dictionary:
	var depth: Dictionary = {from: 0}
	var frontier: Array[Vector2i] = [from]
	var steps: Array[Vector2i] = _grid.neighbor_offsets() if _grid.hex_mode else _PLACEMENT_STEPS
	for count in range(1, limit + 1):
		var next_frontier: Array[Vector2i] = []
		for cell: Vector2i in frontier:
			for step: Vector2i in steps:
				var next := cell + step
				if depth.has(next) or _blocks_path(next):
					continue
				if _grid.hex_mode:
					if _grid.is_edge_walled(cell, next):
						continue
				elif step.x != 0 and step.y != 0:
					if _blocks_path(cell + Vector2i(step.x, 0)) or _blocks_path(cell + Vector2i(0, step.y)):
						continue
				depth[next] = count
				next_frontier.append(next)
		if next_frontier.is_empty():
			break
		frontier = next_frontier
	return depth


func _blocks_path(cell: Vector2i) -> bool:
	if not _grid.is_in_bounds(cell):
		return true
	return _grid.is_point_solid(cell) and not _occupancy.has(cell)


func _row_then_column(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y if a.y != b.y else a.x < b.x


func configure(rules: CombatRules) -> void:
	_wrote()
	_structure_revision += 1
	_rules = rules


## Every write to the board starts here. It also ends an open path memo: the memo's search
## read the board as it was, so no answer may come from it after a write (#642).
func _wrote() -> void:
	_revision += 1
	_path_memo = {}


func _touch(cell: Vector2i) -> void:
	_cell_revisions[cell] = _revision


## Builds from the field layers. A live FieldMap supplies the exact IsoGrid already owned by
## ClickMoveController; bare-layer unit fixtures retain a local fallback grid.
func build_grid(ground: TileMapLayer, blocking: TileMapLayer = null) -> void:
	_wrote()
	_structure_revision += 1
	_handle_cache.clear()
	_initial_cells.clear()
	_tiles_snapshot_cache = []
	_elevation.clear()
	_cover.clear()
	_obstacles.clear()
	_visibility.clear()
	_cliffs.clear()
	_prior_solid.clear()
	_prior_weight.clear()
	var parent: Node = ground.get_parent()
	var field: FieldMap = (
		parent.find_child("FieldMap", true, false) as FieldMap if parent != null else null
	)
	_grid = field.iso_grid() if field != null else null
	if _grid == null:
		_grid = IsoGrid.new()
		_grid.build(ground, blocking)
	_read_authored_terrain(ground)
	for cell: Vector2i in _elevation.keys():
		_apply_elevation_weight(cell)
	for cell: Vector2i in _cliffs.keys():
		if bool(_cliffs[cell]):
			_set_solid(cell, true)


func _read_authored_terrain(ground: TileMapLayer) -> void:
	var parent: Node = ground.get_parent()
	var terrain: TileMapLayer = (
		parent.find_child("Terrain", true, false) as TileMapLayer if parent != null else null
	)
	if terrain == null or terrain.tile_set == null:
		return
	# A tile set need not carry every layer (the map terrain set has no `visibility`), and asking
	# a tile for a layer its set lacks logs an engine error, so only present layers are read.
	var present := {}
	for layer: StringName in [&"cover", &"blocks_fire", &"visibility", &"elevation"]:
		present[layer] = terrain.tile_set.get_custom_data_layer_by_name(layer) >= 0
	for square_cell: Vector2i in terrain.get_used_cells():
		var tile_data: TileData = terrain.get_cell_tile_data(square_cell)
		if tile_data == null:
			continue
		var cover_value: Variant = tile_data.get_custom_data(&"cover") if present[&"cover"] else null
		var obstacle_value: Variant = tile_data.get_custom_data(&"blocks_fire") if present[&"blocks_fire"] else null
		var visibility_value: Variant = tile_data.get_custom_data(&"visibility") if present[&"visibility"] else null
		var elevation_value: Variant = tile_data.get_custom_data(&"elevation") if present[&"elevation"] else null
		# On hexes, every hex whose centre lies on the authored cell takes its terrain.
		for cell: Vector2i in _grid.cells_on_square(square_cell):
			if cover_value is bool and cover_value:
				set_cover(cell)
			if obstacle_value is bool and obstacle_value:
				set_obstacle(cell)
			if visibility_value is String and not (visibility_value as String).is_empty():
				set_visibility(cell, StringName(visibility_value))
			if elevation_value is int and elevation_value != 0:
				set_elevation(cell, clampi(elevation_value, 0, DS.ELEVATION_MAX))


## The cells of this battlefield on one authored square cell: the cell itself, or on hexes the
## four to six hexes whose centre lies on it. Boards authored in cells (harnesses, fixtures)
## write their terrain through this, so a ridge stays a ridge on either grid.
func cells_on_square(square_cell: Vector2i) -> Array[Vector2i]:
	if _grid == null:
		return [square_cell]
	return _grid.cells_on_square(square_cell)


## Terrain height at `cell`. Scales the CT cost of entering it — never makes it impassable.
func set_elevation(cell: Vector2i, elevation: int) -> void:
	_wrote()
	_touch(cell)
	_handle_cache.clear()
	_tiles_snapshot_cache = []
	_elevation[cell] = elevation
	_apply_elevation_weight(cell)


func elevation_at(cell: Vector2i) -> int:
	return int(_elevation.get(cell, 0))


## Marks (or clears) `cell` as a cliff: impassable outright, regardless of elevation weight.
func set_cliff(cell: Vector2i, is_cliff: bool = true) -> void:
	_wrote()
	_touch(cell)
	_tiles_snapshot_cache = []
	_cliffs[cell] = is_cliff
	if _grid != null and _grid.is_in_bounds(cell):
		_set_solid(cell, is_cliff)


## Authors partial cover independently from elevation and impassability.
func set_cover(cell: Vector2i, grants_cover: bool = true) -> void:
	_wrote()
	_touch(cell)
	_tiles_snapshot_cache = []
	_cover[cell] = grants_cover


func setup(allies: Array[BattleActor], enemies: Array[BattleActor]) -> void:
	_wrote()
	_structure_revision += 1
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
	# The default columns are authored on the square cells; on hexes each seat is the hex under
	# that cell's centre.
	var rect := _grid.square_rect()
	for i in allies.size():
		var seat := _grid.cell_at_square(Vector2i(rect.position.x, rect.position.y + i))
		_place(allies[i], _initial_cells.get(allies[i], seat), side_facing(ALLY))
	for i in enemies.size():
		var seat := _grid.cell_at_square(Vector2i(rect.end.x - 1, rect.position.y + i))
		_place(enemies[i], _initial_cells.get(enemies[i], seat), side_facing(ENEMY))
	_initial_cells.clear()


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


## Seats one combatant on an authored cell mid-battle (same-map combat D5). Unlike `_place()`,
## which clamps silently because `setup()` only ever hands it column positions it computed
## itself, this refuses out-of-bounds, impassable and occupied cells: an admitted hostile stands
## where the scene authored it or the admission fails loudly.
func admit_combatant(actor: BattleActor, position: StringName, side: StringName) -> Dictionary:
	if actor == null:
		return _blocked(
			&"composition", "There is no combatant to admit.", {"type": &"present_combatant"}
		)
	if has_combatant(actor):
		return _blocked(
			&"composition", "Combatant is already on the battlefield.", {"type": &"absent_combatant"}
		)
	if not _groups.has(side):
		return _blocked(
			&"composition", "Unknown battlefield side: %s." % side, {"type": &"known_side"}
		)
	if _grid == null:
		return _blocked(
			&"position", "Grid battlefield has not been built.", {"type": &"grid_ready"}
		)
	var parsed := _parse_handle(position)
	if not bool(parsed.get("ok", false)):
		return _blocked(
			&"position", "That is not a battlefield position.", {"type": &"known_position"}
		)
	var cell: Vector2i = parsed["cell"]
	if not _grid.is_in_bounds(cell):
		return _blocked(
			&"position", "That %s is outside the battlefield." % GridMetric.step_word(1), {"type": &"cell_in_bounds"}
		)
	if _occupancy.has(cell):
		return _blocked(&"position", "That cell is occupied.", {"type": &"cell_free"})
	if _grid.is_point_solid(cell):
		return _blocked(&"position", "That cell is impassable.", {"type": &"cell_passable"})
	_sides[actor.combat_id] = side
	var group: Array = _groups.get(side, [])
	group.append(actor)
	_place(actor, cell, side_facing(side))
	return _allowed({"to_side": side, "to_position": position_of(actor)})


func remove_combatant(actor: BattleActor) -> Dictionary:
	if not has_combatant(actor):
		return _blocked(
			&"composition", "Combatant is not on the battlefield.", {"type": &"present_combatant"}
		)
	_wrote()
	var previous_side := side_of(actor)
	var previous_position := position_of(actor)
	var id := actor.combat_id
	if _cells.has(id):
		var cell: Vector2i = _cells[id]
		_touch(cell)
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
	_wrote()
	if _cells.has(actor.combat_id):
		_touch(_cells[actor.combat_id])
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
	_wrote()
	_touch(origin_cell)
	_touch(dest_cell)
	_occupancy.erase(origin_cell)
	_release_solid(origin_cell)
	_occupancy[dest_cell] = actor
	_set_solid(dest_cell, true)
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
	# `_allowed({from, to, ct_cost, path})` written out: same keys, same order (#642).
	return {
		"allowed": true, "blocked_by": &"", "nearest_unblock": {}, "message": "",
		"from": position_of(actor), "to": destination, "ct_cost": query.get("ct_cost", 0),
		"path": query.get("path", []),
	}


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
		if GridMetric.distance(_cells[actor.combat_id], _cells[target.combat_id]) > 1:
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
func set_visibility(cell: Vector2i, level: StringName) -> Dictionary:
	if not VISIBILITY_LEVELS.has(level):
		return _blocked(
			&"visibility", "Unknown visibility level: %s." % level, {"type": &"visibility_level"}
		)
	_wrote()
	_touch(cell)
	_tiles_snapshot_cache = []
	if level == &"clear":
		_visibility.erase(cell)
	else:
		_visibility[cell] = level
	return _allowed({"cell": cell, "level": level})


func visibility_at(cell: Vector2i) -> StringName:
	return _visibility.get(cell, &"clear")


func visibility_between(actor: BattleActor, target: BattleActor) -> Dictionary:
	if not has_combatant(actor) or not has_combatant(target):
		return {"level": &"clear", "causes": []}
	var causes: Array[Dictionary] = []
	var worst := 0
	for cell: Vector2i in [_cells[actor.combat_id], _cells[target.combat_id]]:
		var level := visibility_at(cell)
		if level == &"clear":
			continue
		causes.append({"cell": cell, "level": level})
		worst = maxi(worst, VISIBILITY_LEVELS.find(level))
	return {"level": VISIBILITY_LEVELS[worst], "causes": causes}


func set_obstacle(cell: Vector2i, blocks_fire: bool = true) -> void:
	_wrote()
	_touch(cell)
	_tiles_snapshot_cache = []
	_obstacles[cell] = blocks_fire


## Low cover hides the target's cover-hidden locations only when the target hugs a cover cell
## that stands toward the attacker (the same directional rule as `cover_bonus`) AND the
## attacker does not stand above the target: high ground sees over low cover, matching
## `line_of_sight()`. Facing plays no part — a low wall hides the same parts from any side.
func location_cover(actor: BattleActor, target: BattleActor) -> Dictionary:
	if not has_combatant(actor) or not has_combatant(target):
		return {"covered": false, "seen_over": false}
	var attacker_cell: Vector2i = _cells[actor.combat_id]
	var target_cell: Vector2i = _cells[target.combat_id]
	var cover_cell: Variant = _cover_cell_between(attacker_cell, target_cell)
	if cover_cell == null:
		return {"covered": false, "seen_over": false}
	if elevation_at(attacker_cell) > elevation_at(target_cell):
		return {"covered": false, "seen_over": true, "cell": cover_cell}
	return {"covered": true, "seen_over": false, "cell": cover_cell}


func cover_bonus(actor: BattleActor, target: BattleActor) -> int:
	if _rules == null or not has_combatant(actor) or not has_combatant(target):
		return 0
	var attacker_cell: Vector2i = _cells[actor.combat_id]
	var target_cell: Vector2i = _cells[target.combat_id]
	return _cover_bonus_between(attacker_cell, target_cell)


func cover_bonus_at(attacker: BattleActor, target_position: StringName) -> int:
	if _rules == null or not has_combatant(attacker):
		return 0
	var parsed: Dictionary = _parse_handle(target_position)
	if not bool(parsed.get("ok", false)):
		return 0
	var target_cell: Vector2i = parsed.get("cell", Vector2i.ZERO)
	if _grid == null or not _grid.is_in_bounds(target_cell):
		return 0
	var attacker_cell: Vector2i = _cells[attacker.combat_id]
	return _cover_bonus_between(attacker_cell, target_cell)


func _cover_bonus_between(attacker_cell: Vector2i, target_cell: Vector2i) -> int:
	return _rules.cover_defense_bonus if _cover_cell_between(attacker_cell, target_cell) != null else 0


## The cover cell the target hugs against a shot from `attacker_cell`, or null.
func _cover_cell_between(attacker_cell: Vector2i, target_cell: Vector2i) -> Variant:
	for offset: Vector2i in GridMetric.neighbor_offsets():
		var cover_cell := target_cell + offset
		if not bool(_cover.get(cover_cell, false)):
			continue
		if GridMetric.distance(cover_cell, attacker_cell) < GridMetric.distance(target_cell, attacker_cell):
			return cover_cell
	return null


func flank_bonus(actor: BattleActor, target: BattleActor) -> int:
	if _rules == null or not has_combatant(actor) or not has_combatant(target):
		return 0
	var target_facing := facing_of(target)
	if target_facing == &"":
		return 0
	var attack_dir := facing_for_delta(
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
		for cell: Vector2i in _grid.region_cells():
			_tiles_snapshot_cache.append({
				"x": cell.x,
				"y": cell.y,
				"height_delta": elevation_at(cell),
				"cliff": bool(_cliffs.get(cell, false)),
				"cover": bool(_cover.get(cell, false)),
				"visibility": String(visibility_at(cell)),
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
## `begin_path_memo()`'s shared search: `{origin, tree}`, or empty.
var _path_memo: Dictionary = {}


func reachable_positions(actor: BattleActor, ct_budget: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var handles: Array[String] = []
	if _grid == null or not has_combatant(actor):
		return result
	var id := actor.combat_id
	if not _cells.has(id):
		return result
	var origin: Vector2i = _cells[id]
	var move_cost := maxi(1, _rules.move_ct_cost if _rules != null else 1)
	var max_radius := int(ct_budget / move_cost) + 1
	var search_cap := _search_cost_cap(ct_budget)
	var rect := _grid.get_used_rect()
	# One search from the origin serves every cell in the box (#282). It settles cells in the
	# same order a per-cell search would, so each cell gets the path that search would return.
	# Inside a path memo for this actor and budget, the memo's search is that same search (#642).
	var answers: Variant = _memo_answers(actor, search_cap)
	var tree: Dictionary = _path_memo["tree"] if answers != null else _search_from(origin, search_cap)
	var settled: Dictionary = tree["settled"]
	if _grid.hex_mode:
		# Every hex within the budget is in the capped search's tree.
		for cell: Vector2i in settled:
			if cell == origin:
				continue
			var hex_handle := _handle_for_cell(cell)
			var hex_query := _path_query_cell(actor, cell, search_cap, tree)
			if answers != null:
				(answers as Dictionary)[hex_handle] = hex_query
			if bool(hex_query.get("allowed", false)) and int(hex_query.get("ct_cost", 0)) <= ct_budget:
				handles.append(String(hex_handle))
		handles.sort()
		for handle_text: String in handles:
			result.append(StringName(handle_text))
		return result
	var min_y := maxi(rect.position.y, origin.y - max_radius)
	var max_y := mini(rect.end.y - 1, origin.y + max_radius)
	var min_x := maxi(rect.position.x, origin.x - max_radius)
	var max_x := mini(rect.end.x - 1, origin.x + max_radius)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cell := Vector2i(x, y)
			# A cell the search never settled has no path, so `_path_query` could only refuse it.
			if cell == origin or not settled.has(cell):
				continue
			var handle := _handle_for_cell(cell)
			var query := _path_query_cell(actor, cell, search_cap, tree)
			if answers != null:
				(answers as Dictionary)[handle] = query
			if bool(query.get("allowed", false)) and int(query.get("ct_cost", 0)) <= ct_budget:
				handles.append(String(handle))
	# Sort as String, never as StringName: StringName's `<` compares by internal pointer, so a
	# StringName sort would be interning order and the by-handle order documented above would
	# quietly not hold.
	handles.sort()
	for handle_text: String in handles:
		result.append(StringName(handle_text))
	return result


## Path cost in the refusal shape (doc §1.3). Adds `ct_cost`/`path` when allowed. This is the
## one place that walks the shared `IsoGrid`'s A* — `move()`, `move_query()`, and
## `reachable_positions()` all route through it so the quoted cost and the paid cost can never
## drift apart (doc §1.7).
func path_query(actor: BattleActor, destination: StringName) -> Dictionary:
	if not _path_memo.is_empty() and has_combatant(actor) and _cells.get(actor.combat_id) == _path_memo["origin"]:
		# `reachable_positions()` already answered this cell from the memo's search (#642).
		if actor.combat_id == _path_memo["actor_id"]:
			var answered: Variant = (_path_memo["answers"] as Dictionary).get(destination)
			if answered != null:
				return answered
		var parsed := _parse_handle(destination)
		# Only a cell the capped search settled has its uncapped path in the tree.
		if bool(parsed.get("ok", false)) and ((_path_memo["tree"] as Dictionary)["settled"] as Dictionary).has(parsed["cell"]):
			return _path_query(actor, destination, INF, _path_memo["tree"])
	return _path_query(actor, destination, INF)


## While a caller asks many uncapped path queries from one actor's cell (the movement snapshot
## quotes every reachable cell), one search from that cell, capped at `ct_budget`, answers every
## cell it settles. It settles cells in the order each per-destination search would, so every
## path and cost is unchanged (#282). A cell it did not settle, a query from any other cell, or
## any query after `end_path_memo()` searches as before. Nothing may move between the two.
func begin_path_memo(actor: BattleActor, ct_budget: int) -> void:
	_path_memo = {}
	if _grid == null or not has_combatant(actor) or not _cells.has(actor.combat_id):
		return
	var origin: Vector2i = _cells[actor.combat_id]
	var cap := _search_cost_cap(ct_budget)
	_path_memo = {
		"origin": origin, "tree": _search_from(origin, cap), "cap": cap,
		"actor_id": actor.combat_id, "answers": {},
	}


## The cells of `path` when it is the very walk an answer of the open path memo carried (its
## handles, read-only), else null: the same cells describing each handle gives, already built
## by the search (#642).
func memo_walk_cells(path: Array) -> Variant:
	if _path_memo.is_empty() or path.is_empty() or not path.is_read_only():
		return null
	var walks: Variant = (_path_memo["tree"] as Dictionary).get("walks")
	if walks == null:
		return null
	var parsed := _parse_handle(StringName(path.back()))
	if not bool(parsed.get("ok", false)):
		return null
	var walk: Variant = (walks as Dictionary).get(parsed["cell"])
	if walk == null or not is_same(walk[0], path):
		return null
	return walk[2]


func end_path_memo() -> void:
	_path_memo = {}


## What the open path memo's search read, as a stamp for `reach_stamp_current()`: the cells it
## settled and every neighbour it looked at, with this model's and the grid's write counters.
## A reach priced inside the memo reads nothing else from the board (#642). Empty with no memo.
func path_memo_stamp() -> Dictionary:
	if _path_memo.is_empty() or _grid == null:
		return {}
	var region: Dictionary = {}
	var offsets := _grid.neighbor_offsets()
	for cell: Vector2i in ((_path_memo["tree"] as Dictionary)["settled"] as Dictionary):
		region[cell] = true
		for offset: Vector2i in offsets:
			region[cell + offset] = true
	return {
		"region": region.keys(),
		"structure": [_structure_revision, _grid.get_instance_id(), _grid.structure_revision, _grid.hex_mode],
		"revision": _revision,
		"grid_revision": _grid.revision,
	}


## True while no write has touched a cell `stamp` names and nothing was rebuilt since it was
## taken: every path answer its search gave is unchanged. An enemy moving across the map does
## not touch an ally's reach, so the ally's priced stands stand (#642). A passing check moves
## the stamp up to now, so the next one costs nothing until the board is written again.
func reach_stamp_current(stamp: Dictionary) -> bool:
	if stamp.is_empty() or _grid == null:
		return false
	if stamp["structure"] != [_structure_revision, _grid.get_instance_id(), _grid.structure_revision, _grid.hex_mode]:
		return false
	var seen_revision: int = stamp["revision"]
	var seen_grid_revision: int = stamp["grid_revision"]
	if seen_revision == _revision and seen_grid_revision == _grid.revision:
		return true
	for cell: Vector2i in (stamp["region"] as Array):
		if int(_cell_revisions.get(cell, -1)) > seen_revision:
			return false
		if _grid.cell_revision(cell) > seen_grid_revision:
			return false
	stamp["revision"] = _revision
	stamp["grid_revision"] = _grid.revision
	return true


## The memo's answers by handle when the memo is `actor`'s, from where it stands, under the same
## search cap; null otherwise. `_path_query()` given the memo's tree answers a settled cell the
## same whatever its cap, so `reachable_positions()` fills this and `path_query()` reads it:
## pricing a reach no longer walks each stand's path twice (#642).
func _memo_answers(actor: BattleActor, search_cap: float) -> Variant:
	if _path_memo.is_empty() or actor.combat_id != _path_memo["actor_id"]:
		return null
	if _cells.get(actor.combat_id) != _path_memo["origin"] or float(_path_memo["cap"]) != search_cap:
		return null
	return _path_memo["answers"]


## `_settled_paths()` out of `origin`, which its standing actor holds solid: the cell is opened
## for the walk and closed again (`IsoGrid.probe_open()`, which is not a write, #642).
func _search_from(origin: Vector2i, max_search_cost: float) -> Dictionary:
	var was_solid := _grid.probe_open(origin)
	var tree := _settled_paths(origin, max_search_cost)
	_grid.probe_close(origin, was_solid)
	return tree


## `path_query()` with the search stopped once every unsettled cell costs more than
## `max_search_cost` (in `_deterministic_path` cost units). Below the cap the search order, and
## so the path and its tie-breaks, are exactly `path_query()`'s; past it the answer is "No path"
## instead of a path the caller would have rejected anyway (see `_search_cost_cap`).
## `tree`, when given, is `_settled_paths()` from the actor's cell under the same cap and
## stands in for a fresh search; every refusal check still runs.
func _path_query(
	actor: BattleActor, destination: StringName, max_search_cost: float, tree: Dictionary = {}
) -> Dictionary:
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
	return _path_query_cell(actor, parsed["cell"], max_search_cost, tree)


## `_path_query()` from the parsed destination cell on (#642: the reach loop has the cell).
func _path_query_cell(
	actor: BattleActor, dest_cell: Vector2i, max_search_cost: float, tree: Dictionary = {}
) -> Dictionary:
	if not _grid.is_in_bounds(dest_cell):
		return _blocked(
			&"position", "That %s is outside the battlefield." % GridMetric.step_word(1), {"type": &"in_bounds"}
		)
	if _grid.is_point_solid(dest_cell) and _occupancy.get(dest_cell) == null:
		return _blocked(&"position", "That cell is impassable.", {"type": &"cell_passable"})
	var occupant: BattleActor = _occupancy.get(dest_cell)
	if occupant != null and occupant != actor:
		return _blocked(&"position", "That cell is occupied.", {"type": &"cell_free"})
	var origin_cell: Vector2i = _cells[actor.combat_id]
	if origin_cell == dest_cell:
		return _blocked(&"position", "Combatant is already there.", {"type": &"different_position"})
	if not tree.is_empty():
		var walk := _tree_walk(tree, origin_cell, dest_cell)
		if walk.is_empty():
			return _blocked(&"position", "No path to that %s." % GridMetric.step_word(1), {"type": &"reachable"})
		# `_allowed({"ct_cost": …, "path": …})` written out: the same keys in the same order,
		# without a merge per stand (#642).
		return {
			"allowed": true, "blocked_by": &"", "nearest_unblock": {}, "message": "",
			"ct_cost": _walk_ct_cost(walk[1]), "path": walk[0],
		}
	var was_solid := _grid.probe_open(origin_cell)
	var path := _deterministic_path(origin_cell, dest_cell, max_search_cost)
	_grid.probe_close(origin_cell, was_solid)
	if path.is_empty():
		return _blocked(&"position", "No path to that %s." % GridMetric.step_word(1), {"type": &"reachable"})
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
	var order := facing_order()
	if not order.has(facing):
		return _blocked(
			&"facing", "Unknown facing: %s." % facing, {"type": &"facing", "valid": order.duplicate()}
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
	return _line_of_sight_cells(_cells[actor.combat_id], _cells[target.combat_id], actor, target)


## Combat polish 2026-11-02: the actor's cell reads as `cell` for targeting, range, sight and
## positional forecasts until clear_probe(). Only `_cells` moves: occupancy and the shared
## IsoGrid are untouched, so nothing a probe answers leaks into pathing or the board.
func probe_cell(actor: BattleActor, cell: Vector2i) -> void:
	if actor == null or not _cells.has(actor.combat_id):
		return
	if not _probe_saved.has(actor.combat_id):
		_probe_saved[actor.combat_id] = _cells[actor.combat_id]
	_cells[actor.combat_id] = cell


func clear_probe(actor: BattleActor) -> void:
	if actor == null or not _probe_saved.has(actor.combat_id):
		return
	_cells[actor.combat_id] = _probe_saved[actor.combat_id]
	_probe_saved.erase(actor.combat_id)


func occupant_of(position: StringName) -> BattleActor:
	var parsed := _parse_handle(position)
	if not bool(parsed.get("ok", false)):
		return null
	return _occupancy.get(parsed["cell"])


func cell_of(actor: BattleActor) -> Variant:
	if actor == null or not _cells.has(actor.combat_id):
		return null
	return _cells[actor.combat_id]


func cell_query(cell: Vector2i) -> Dictionary:
	if _grid == null:
		return _blocked(&"position", "Grid battlefield has not been built.", {"type": &"grid_ready"})
	if not _grid.is_in_bounds(cell):
		return _blocked(
			&"position", "That %s is outside the battlefield." % GridMetric.step_word(1), {"type": &"in_bounds", "cell": cell}
		)
	var occupant: BattleActor = _occupancy.get(cell)
	var passable := not _grid.is_point_solid(cell) or occupant != null
	if bool(_cliffs.get(cell, false)):
		passable = false
	return _allowed({
		"in_bounds": true,
		"passable": passable,
		"occupant_id": occupant.combat_id if occupant != null else &"",
	})


## Forced displacement: no path, no cost, no facing change. Refuses an out-of-bounds,
## impassable or occupied destination so a pull can never stack two combatants on one cell.
func displace(actor: BattleActor, cell: Vector2i) -> Dictionary:
	if _grid == null:
		return _blocked(&"position", "Grid battlefield has not been built.", {"type": &"grid_ready"})
	if not has_combatant(actor) or not _cells.has(actor.combat_id):
		return _blocked(
			&"position", "Combatant is not on the battlefield.", {"type": &"present_combatant"}
		)
	if not _grid.is_in_bounds(cell):
		return _blocked(&"position", "That %s is outside the battlefield." % GridMetric.step_word(1), {"type": &"in_bounds"})
	var occupant: BattleActor = _occupancy.get(cell)
	if occupant != null and occupant != actor:
		return _blocked(&"position", "That cell is occupied.", {"type": &"cell_free"})
	if occupant == null and _grid.is_point_solid(cell):
		return _blocked(&"position", "That cell is impassable.", {"type": &"cell_passable"})
	var origin_cell: Vector2i = _cells[actor.combat_id]
	if origin_cell == cell:
		return _allowed({"from": position_of(actor), "to": position_of(actor)})
	var previous := position_of(actor)
	_wrote()
	_touch(origin_cell)
	_touch(cell)
	_occupancy.erase(origin_cell)
	_release_solid(origin_cell)
	_occupancy[cell] = actor
	_set_solid(cell, true)
	_cells[actor.combat_id] = cell
	return _allowed({"from": previous, "to": position_of(actor)})


func line_of_sight_to_cell(actor: BattleActor, cell: Vector2i) -> Dictionary:
	if _grid == null or not has_combatant(actor):
		return _blocked(
			&"blocked_by_range", "Combatant is not on the battlefield.", {"type": &"present_combatant"}
		)
	return _line_of_sight_cells(_cells[actor.combat_id], cell, actor, null)


func line_of_sight_between_cells(from: Vector2i, to: Vector2i) -> Dictionary:
	if _grid == null:
		return _blocked(&"blocked_by_range", "Grid battlefield has not been built.", {"type": &"grid_ready"})
	return _line_of_sight_cells(from, to, _occupancy.get(from), _occupancy.get(to))


## Shared sightline walk for `line_of_sight()` and the cell variants. `viewer`/`viewed` are the
## combatants standing at either end (or null) so they never block their own sightline.
func _line_of_sight_cells(
	from_cell: Vector2i, to_cell: Vector2i, viewer: BattleActor, viewed: BattleActor
) -> Dictionary:
	if not _grid.is_in_bounds(to_cell):
		return _blocked(
			&"blocked_by_range", "That %s is outside the battlefield." % GridMetric.step_word(1), {"type": &"in_bounds"}
		)
	var range_bonus := int(viewer.defining_effects.get("range_bonus", 0)) if viewer != null else 0
	var max_range := float(GridMetric.reach(int(_LOS_MAX_RANGE) + range_bonus))
	if GridMetric.distance(from_cell, to_cell) > max_range:
		return _blocked(
			&"blocked_by_range",
			"Target is beyond line-of-sight range.",
			{"type": &"range", "max_range": max_range},
		)
	var from_elev := elevation_at(from_cell)
	var to_elev := elevation_at(to_cell)
	var line: Array[Vector2i] = HexMath.line(from_cell, to_cell) if _grid.hex_mode else _bresenham(from_cell, to_cell)
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
		if bool(_obstacles.get(cell, false)):
			return _blocked(
				&"blocked_by_obstacle",
				"A solid obstacle blocks the line of fire.",
				{"type": &"obstacle", "cell": cell},
			)
		var occupant: BattleActor = _occupancy.get(cell)
		if occupant != null and occupant != viewer and occupant != viewed:
			if from_elev <= elevation_at(cell):
				return _blocked(
					&"blocked_by_occupancy",
					"A combatant blocks the line of sight.",
					{"type": &"occupancy", "cell": cell},
				)
	return _allowed()


func elevation_delta(actor: BattleActor, target: BattleActor) -> int:
	if not has_combatant(actor) or not has_combatant(target):
		return 0
	return elevation_at(_cells[target.combat_id]) - elevation_at(_cells[actor.combat_id])


# ---- internal: the only code in the project allowed to build or parse a position handle ----


## Cell -> handle. A handle names the cell's elevation, so any elevation write empties it.
var _handle_cache: Dictionary = {}
## Handle -> its parse, read-only. Parsing reads nothing but the text, so it never goes stale.
var _parse_cache: Dictionary = {}


## Formatting and parsing handles was most of a reach pricing's path work: every stand's path
## is written as handles and read back as cells (#642). Both are cached; the values are those
## the uncached code builds.
func _handle_for_cell(cell: Vector2i) -> StringName:
	var cached: Variant = _handle_cache.get(cell)
	if cached != null:
		return cached
	var handle := StringName("c:%d,%d,%d" % [cell.x, cell.y, elevation_at(cell)])
	_handle_cache[cell] = handle
	return handle


func _parse_handle(handle: StringName) -> Dictionary:
	var cached: Variant = _parse_cache.get(handle)
	if cached != null:
		return cached
	var parsed := _parse_handle_text(String(handle))
	parsed.make_read_only()
	_parse_cache[handle] = parsed
	return parsed


func _parse_handle_text(text: String) -> Dictionary:
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
	_wrote()
	if _cells.has(id):
		_touch(_cells[id])
	_touch(clamped)
	_cells[id] = clamped
	_facings[id] = facing
	_occupancy[clamped] = actor
	_set_solid(clamped, true)


func _apply_elevation_weight(cell: Vector2i) -> void:
	if _grid == null or not _grid.is_in_bounds(cell):
		return
	var elevation := elevation_at(cell)
	if not _prior_weight.has(cell):
		_prior_weight[cell] = _grid.get_point_weight_scale(cell)
	_grid.set_point_weight_scale(cell, maxf(1.0, 1.0 + float(elevation) * _ELEVATION_WEIGHT_PER_LEVEL))


## Restores a vacated cell's solid flag. A cliff cell must stay solid even after whatever stood
## on it moves or dies — occupancy and cliff-impassability share `IsoGrid.set_point_solid()`,
## so vacating must not accidentally reopen a cliff.
func _release_solid(cell: Vector2i) -> void:
	if _grid != null:
		_set_solid(cell, bool(_cliffs.get(cell, false)) or bool(_prior_solid.get(cell, false)))


## Every solid write goes through here so the field grid's pre-combat flag is remembered once.
func _set_solid(cell: Vector2i, solid: bool) -> void:
	if _grid == null:
		return
	if not _prior_solid.has(cell):
		_prior_solid[cell] = _grid.is_point_solid(cell)
	_grid.set_point_solid(cell, solid)


## Hands the shared field IsoGrid back to navigation: every solid flag and weight this model
## wrote is restored to its pre-combat value. Combat bookkeeping stays readable for the result
## screen; only the grid is released. Idempotent. Battle calls it when a fight ends or is
## superseded by a new one.
func release_field_grid() -> void:
	if _grid == null:
		return
	for cell: Vector2i in _prior_solid.keys():
		_grid.set_point_solid(cell, bool(_prior_solid[cell]))
	for cell: Vector2i in _prior_weight.keys():
		_grid.set_point_weight_scale(cell, float(_prior_weight[cell]))
	_prior_solid.clear()
	_prior_weight.clear()


func _path_ct_cost(path: PackedVector2Array) -> int:
	var move_cost := _rules.move_ct_cost if _rules != null else 1
	if _grid.hex_mode:
		# Two hexes cover one cell's ground: half a cell's price each, rounded up once for the
		# whole move. The AP economy charges whole cells (`_priced_move_action`), so an odd
		# count rounds up there: 3 hexes = 2 AP. PROVISIONAL (owner item 34).
		var halves := 0.0
		for i in range(1, path.size()):
			halves += move_cost * _grid.get_point_weight_scale(Vector2i(path[i]))
		return int(ceil(halves / 2.0 - 0.000001))
	var total := 0
	for i in range(1, path.size()):
		var cell := Vector2i(path[i])
		total += int(ceil(move_cost * _grid.get_point_weight_scale(cell)))
	return total


## The largest `_deterministic_path` cost a path can have and still cost `ct_budget` or less in
## CT. A step costs `ceil(move_ct_cost * w)` CT and at most `sqrt(2) * w` search cost for the
## same weight `w`, so CT >= search cost * move_ct_cost / sqrt(2) on every path. A search that
## has passed this cap can only reach `to_cell` by a path whose CT exceeds the budget. Without
## the cap, every unreachable cell in the move box (an enemy hemmed in by its own side) flooded
## the whole grid: 2.6 s per enemy decision with 100 hostiles admitted (#282).
func _search_cost_cap(ct_budget: int) -> float:
	var move_cost := _rules.move_ct_cost if _rules != null else 1
	if move_cost <= 0:
		return INF
	if _grid != null and _grid.hex_mode:
		# A hex step costs `w` to search and `move_ct_cost * w / 2` CT before the one rounding.
		return float(ct_budget) * 2.0 / float(move_cost)
	return float(ct_budget) * sqrt(2.0) / float(move_cost)


## AStarGrid2D is deterministic on one engine build, but its equal-f-score choice is not the
## Gate T contract: equal-cost paths must prefer the lowest row-major cell index. This compact
## Dijkstra walk makes that tie-break explicit while preserving octile diagonal cost and the
## no-corner-cutting rule used by IsoGrid.
func _deterministic_path(
	from_cell: Vector2i, to_cell: Vector2i, max_search_cost: float = INF
) -> PackedVector2Array:
	return _settled_path(_dijkstra(from_cell, to_cell, max_search_cost), from_cell, to_cell)


## Every cell the walk settles from `from_cell` within `max_search_cost`, with the predecessor
## it had when it settled. Same walk as `_deterministic_path()`, run to exhaustion.
func _settled_paths(from_cell: Vector2i, max_search_cost: float) -> Dictionary:
	return _dijkstra(from_cell, null, max_search_cost)


## `to_cell`'s walk from the tree's origin: `[handles, cost]`, the path as read-only handles and
## its running CT cost before rounding, or empty when the search never settled it. A walk is its
## predecessor's plus one cell, so the tree keeps each one it builds and the stands of a reach
## reuse their shared prefixes instead of each retracing and repricing its whole path (#642).
## The handles and the cost are the ones `_settled_path()` and `_path_ct_cost()` give: the same
## cells in the same order, the cost summed step by step in the same order.
func _tree_walk(tree: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> Array:
	var settled: Dictionary = tree["settled"]
	if not settled.has(to_cell):
		return []
	if not tree.has("walks"):
		var origin_handles: Array[StringName] = [_handle_for_cell(from_cell)]
		origin_handles.make_read_only()
		var origin_cells: Array[Vector2i] = [from_cell]
		origin_cells.make_read_only()
		tree["walks"] = {from_cell: [origin_handles, 0.0 if _grid.hex_mode else 0, origin_cells]}
	var walks: Dictionary = tree["walks"]
	var pending: Array[Vector2i] = []
	var cursor := to_cell
	while not walks.has(cursor):
		pending.append(cursor)
		cursor = settled[cursor]
	var move_cost := _rules.move_ct_cost if _rules != null else 1
	var walk: Array = walks[cursor]
	for i in range(pending.size() - 1, -1, -1):
		var cell := pending[i]
		var handles: Array[StringName] = (walk[0] as Array[StringName]).duplicate()
		handles.append(_handle_for_cell(cell))
		handles.make_read_only()
		var cells: Array[Vector2i] = (walk[2] as Array[Vector2i]).duplicate()
		cells.append(cell)
		cells.make_read_only()
		var cost: Variant
		if _grid.hex_mode:
			cost = float(walk[1]) + move_cost * _grid.get_point_weight_scale(cell)
		else:
			cost = int(walk[1]) + int(ceil(move_cost * _grid.get_point_weight_scale(cell)))
		walk = [handles, cost, cells]
		walks[cell] = walk
	return walk


## A walk's running cost as `_path_ct_cost()` returns it: hex halves rounded up once.
func _walk_ct_cost(cost: Variant) -> int:
	if _grid.hex_mode:
		return int(ceil(float(cost) / 2.0 - 0.000001))
	return int(cost)


## The path `_dijkstra()` settled for `to_cell`, or empty when it never settled.
func _settled_path(tree: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> PackedVector2Array:
	var settled: Dictionary = tree["settled"]
	if not settled.has(to_cell):
		return PackedVector2Array()
	var reversed: Array[Vector2i] = [to_cell]
	var cursor := to_cell
	while cursor != from_cell:
		cursor = settled[cursor]
		reversed.append(cursor)
	reversed.reverse()
	return PackedVector2Array(reversed)


## The Dijkstra walk behind every grid path. `settled` maps each settled cell to its
## predecessor at the moment it settled (`from_cell` maps to itself). With a `stop_at` cell the
## walk ends once that cell settles; without one it runs until the cap or the frontier runs out.
## Settle order, and so every tie-break, is identical either way: the walk only stops sooner.
func _dijkstra(from_cell: Vector2i, stop_at: Variant, max_search_cost: float) -> Dictionary:
	var rect := _grid.get_used_rect()
	var frontier := _Frontier.new()
	frontier.push(from_cell, 0.0, _cell_index(from_cell, rect))
	var costs: Dictionary = {from_cell: 0.0}
	var previous: Dictionary = {from_cell: from_cell}
	var settled: Dictionary = {}
	if rect.size.x >= 3:
		_ordered_walk(frontier, rect, costs, previous, settled, stop_at, max_search_cost)
		return {"settled": settled}
	while not frontier.is_empty():
		var cell := frontier.top_cell()
		var current_cost := frontier.top_cost()
		frontier.pop()
		if current_cost > float(costs.get(cell, INF)):
			continue
		if current_cost > max_search_cost + 0.000001:
			# Everything still unsettled costs at least this much.
			break
		settled[cell] = previous[cell]
		if stop_at != null and cell == stop_at:
			break
		var neighbors: Array[Vector2i] = []
		if _grid.hex_mode:
			for offset: Vector2i in HexMath.DIRECTIONS:
				var hex := cell + offset
				if _grid.is_in_bounds(hex) and not _grid.is_point_solid(hex) and not _grid.is_edge_walled(cell, hex):
					neighbors.append(hex)
		else:
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
			# Every hex neighbour is one step away; a square diagonal is octile.
			var diagonal := not _grid.hex_mode and next.x != cell.x and next.y != cell.y
			var step_cost := (sqrt(2.0) if diagonal else 1.0) * _grid.get_point_weight_scale(next)
			var next_cost := float(costs[cell]) + step_cost
			if next_cost + 0.000001 < float(costs.get(next, INF)):
				costs[next] = next_cost
				previous[next] = cell
				frontier.push(next, next_cost, _cell_index(next, rect))
	return {"settled": settled}


## `_dijkstra()`'s loop with each cell's steps from one `IsoGrid.append_square_steps()` or
## `append_hex_steps()` call (#642). The steps come in row-major order, the order the general
## loop sorts them into (on a grid three or more columns wide a neighbour's index differs from
## its cell's by `dy * width + dx`), and cost what it prices them at: the same walk, the same
## settle order, the same predecessors.
func _ordered_walk(
	frontier: _Frontier, rect: Rect2i, costs: Dictionary, previous: Dictionary,
	settled: Dictionary, stop_at: Variant, max_search_cost: float,
) -> void:
	var step_cells: Array[Vector2i] = []
	var step_costs: Array[float] = []
	var hex := _grid.hex_mode
	while not frontier.is_empty():
		var cell := frontier.top_cell()
		var current_cost := frontier.top_cost()
		frontier.pop()
		var known_cost: float = costs.get(cell, INF)
		if current_cost > known_cost:
			continue
		if current_cost > max_search_cost + 0.000001:
			break
		settled[cell] = previous[cell]
		if stop_at != null and cell == stop_at:
			break
		step_cells.clear()
		step_costs.clear()
		if hex:
			_grid.append_hex_steps(cell, step_cells, step_costs)
		else:
			_grid.append_square_steps(cell, step_cells, step_costs)
		for i: int in step_cells.size():
			var next := step_cells[i]
			var next_cost := known_cost + step_costs[i]
			if next_cost + 0.000001 < float(costs.get(next, INF)):
				costs[next] = next_cost
				previous[next] = cell
				frontier.push(next, next_cost, _cell_index(next, rect))


## The walk's frontier: a binary min-heap over (cost, row-major cell index), so the cheapest cell
## settles first and equal costs settle lowest index first, the order the walk always had. It
## replaces a sort of the whole frontier on every step, which hexes made the largest single cost
## of an AI turn (owner item 34; #282).
class _Frontier:
	var _cost: Array[float] = []
	var _key: Array[int] = []
	var _cell: Array[Vector2i] = []

	func is_empty() -> bool:
		return _cost.is_empty()

	func top_cell() -> Vector2i:
		return _cell[0]

	func top_cost() -> float:
		return _cost[0]

	## Sifts with a hole instead of swapping all three arrays at each level (#642): the same
	## comparisons in the same order, so the same entries end in the same slots.
	func push(cell: Vector2i, cost: float, key: int) -> void:
		_cost.append(cost)
		_key.append(key)
		_cell.append(cell)
		var i := _cost.size() - 1
		while i > 0:
			var parent := (i - 1) >> 1
			if not _before(cost, key, _cost[parent], _key[parent]):
				break
			_cost[i] = _cost[parent]
			_key[i] = _key[parent]
			_cell[i] = _cell[parent]
			i = parent
		_cost[i] = cost
		_key[i] = key
		_cell[i] = cell

	## Drops the cheapest entry (read it first with `top_cell()` and `top_cost()`).
	func pop() -> void:
		var last := _cost.size() - 1
		var cost := _cost[last]
		var key := _key[last]
		var cell := _cell[last]
		_cost.resize(last)
		_key.resize(last)
		_cell.resize(last)
		if last == 0:
			return
		var i := 0
		while true:
			var left := 2 * i + 1
			var smallest := i
			var smallest_cost := cost
			var smallest_key := key
			if left < last and _before(_cost[left], _key[left], smallest_cost, smallest_key):
				smallest = left
				smallest_cost = _cost[left]
				smallest_key = _key[left]
			if left + 1 < last and _before(_cost[left + 1], _key[left + 1], smallest_cost, smallest_key):
				smallest = left + 1
			if smallest == i:
				break
			_cost[i] = _cost[smallest]
			_key[i] = _key[smallest]
			_cell[i] = _cell[smallest]
			i = smallest
		_cost[i] = cost
		_key[i] = key
		_cell[i] = cell

	## Cheaper first; costs within rounding of each other go lowest cell index first.
	static func _before(cost_a: float, key_a: int, cost_b: float, key_b: int) -> bool:
		if not is_equal_approx(cost_a, cost_b):
			return cost_a < cost_b
		return key_a < key_b


static func _cell_index(cell: Vector2i, rect: Rect2i) -> int:
	return (cell.y - rect.position.y) * rect.size.x + (cell.x - rect.position.x)


## The facings this grid uses: eight grid directions on squares, six screen directions on hexes.
static func facing_order() -> Array[StringName]:
	return HEX_ORDER if GridMetric.hex() else _ORDER


## The facing that looks along `delta` (a cell difference), or empty for no difference. On
## squares, the nearest of eight grid directions; on hexes, the first step of the hex line.
## Hex facing by offset: `HexMath.direction_toward()` walks the whole hex line to the offset to
## find its first step, ~36 µs, and an enemy scores every stand it can reach by it. The answer
## depends on the offset alone, so each is worked out once (#642).
static var _hex_facing_by_delta: Dictionary = {}


static func facing_for_delta(delta: Vector2i) -> StringName:
	if delta == Vector2i.ZERO:
		return &""
	if GridMetric.hex():
		var known: Variant = _hex_facing_by_delta.get(delta)
		if known == null:
			known = HEX_ORDER[HexMath.direction_toward(Vector2i.ZERO, delta)]
			_hex_facing_by_delta[delta] = known
		return known
	var angle := atan2(delta.y, delta.x)
	var index := int(round(angle / (PI / 4.0)))
	index = ((index % 8) + 8) % 8
	return _ORDER[index]


## The facing straight behind `facing`, or empty for an unknown one.
static func opposite_facing(facing: StringName) -> StringName:
	var order := facing_order()
	var i := order.find(facing)
	if i == -1:
		return &""
	return order[(i + order.size() / 2) % order.size()]


## A side's facing at seating: the party looks east and its foes west.
static func side_facing(side: StringName) -> StringName:
	var order := facing_order()
	return order[order.size() / 2] if side == ENEMY else order[0]


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
