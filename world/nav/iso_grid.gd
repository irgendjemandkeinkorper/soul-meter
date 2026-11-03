class_name IsoGrid
extends RefCounted
## Shared isometric pathfinding substrate. `docs/architecture-tactical-and-navigation.md` §2.2
## (D4, 2026-08-07) selects this design: ONE `AStarGrid2D` construction serves two consumers —
## the overworld click-to-move controller AND `GridBattlefieldModel`'s movement-range queries.
## Neither consumer knows about the other. Neither consumer should ever touch `AStarGrid2D`
## directly; go through this class so both stay behind one seam.
##
## WHY AStarGrid2D and not NavigationServer2D/NavigationAgent2D: the tactical layer needs
## discrete cells, a per-cell movement budget, occupancy, and range highlight. A navigation
## mesh gives a continuous path and cannot answer "which cells can I reach with 40 charge
## time". One technology for both layers is worth more than the smoothness a navmesh would add
## to the overworld alone — see §2.2 for the full argument. Do not swap this for
## NavigationServer2D without revisiting that argument.
##
## WHY HEURISTIC_OCTILE: isometric diagonals look cardinal on screen. A Euclidean heuristic
## ranks them incorrectly, so octile is mandatory here, not a tuning choice.
##
## WHY DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES: a path must never cut a corner through a building.
##
## NO dependency on globals/combat/. This file is the shared layer that GridBattlefieldModel
## will consume later (§1.6) — the dependency direction runs combat -> IsoGrid, never the
## reverse. Keep it that way.
##
## Determinism: AStarGrid2D's own tie-breaking is stable (lowest-index cell wins ties), and
## nothing in this file introduces RNG. The same query returns the same path every time —
## required by §1.8 (save/replay determinism) for the future GridBattlefieldModel consumer.
##
## HEX MODE (owner item 34, 2026-11-03; `docs/design/hex-grid-plan-2026-11-03.md`, slice H1).
## With `hex_mode` on, every public call takes and returns axial hexes (`HexMath`, `HexLayout`)
## instead of square cells: Fallout-scale hexes, about four to a cell, rows left to right. The
## square grid is still built underneath as the authoring layer. The painted region and the
## baked obstacles stay in cell space. A hex is solid when its centre or any corner pulled halfway
## in lands on a solid cell, and a step between two open hexes is refused when its straight walk
## line crosses a solid cell, so no path leaks through a wall one cell thick. Hex paths use
## `AStar2D` (`AStarGrid2D` is square-only), built on the first path query so a placement-only
## grid stays cheap. Off by default (`soul_meter/grid/hex`) until the combat side (H2) speaks
## hexes too.

const HEX_SETTING := "soul_meter/grid/hex"

var _astar := AStarGrid2D.new()
var _ground: TileMapLayer
var _blocking: TileMapLayer  ## obstacle layer; may be null
var _static_clearance_cells: int = 0
var _project_blocking_to_ground: bool = false

## Cells the STATIC obstacle layer painted. Kept separately from AStarGrid2D's own solid flags
## so clearing an occupant restores the cell to whatever the painted map said, instead of
## punching a permanent hole through a wall an actor happened to stand next to.
var _static_solid: Dictionary = {}  ## Vector2i -> true
## Cells a DYNAMIC actor currently stands on (GH #190). Same concept as
## `GridBattlefieldModel._occupancy`, deliberately hoisted down here into the shared substrate:
## static walls and standing actors are two layers of ONE passability query, and amendment §8.1
## treats a second source of truth for position as a release blocker. The overworld therefore
## does not get its own answer — it asks this grid. (`GridBattlefieldModel` still keeps its own
## `_occupancy` dictionary because it maps cells to `BattleActor` with combat-specific
## semantics — cover, LOS, turn order. That is the tactical layer's business and is out of
## scope here; the two should converge on this one when that file is next opened.)
var _occupancy: Dictionary = {}  ## Vector2i -> Object
var _occupant_cells: Dictionary = {}  ## Object -> Vector2i

## Hex mode (see the header). Set before `build()`; a test may turn it on for one grid.
var hex_mode: bool = hex_enabled()
var _layout: HexLayout
var _hex_in_region: Dictionary = {}  ## Vector2i hex -> bool, filled on demand
var _hex_static: Dictionary = {}  ## Vector2i hex -> bool, filled on demand
var _hex_solid: Dictionary = {}  ## Vector2i hex -> true: solid by occupancy or a caller
var _hex_weights: Dictionary = {}  ## Vector2i hex -> float
var _hex_astar: AStar2D = null
var _hex_ids: Dictionary = {}  ## Vector2i hex -> AStar2D point id
var _hex_by_id: Array[Vector2i] = []
var _hex_bounds := Rect2i()
var _hex_bounds_ready := false

## Whether new grids use hexes: the project setting `soul_meter/grid/hex` (off by default).
static func hex_enabled() -> bool:
	return bool(ProjectSettings.get_setting(HEX_SETTING, false))


## The hexes over a ground layer, in the layer's local space: a hex step is half a cell side
## (ruling H-a2: two hex steps cover one cell step). Anything else that places things on hexes
## (party followers) uses this, so every consumer sees the same hexes.
##
## A cell side is measured in flat space (screen with y doubled): an isometric 64x32 diamond is
## a square of side 64 / sqrt(2) there, as on every shipped map. A plain rectangular 64x32 tile,
## which only test and harness boards use, is a square of side 64. Measuring the real shape
## keeps about 4.6 hexes to a cell either way, so a move covers the same ground on both.
static func hex_layout_for(ground: TileMapLayer) -> HexLayout:
	var tile := Vector2(ground.tile_set.tile_size)
	var side := tile.x
	if ground.tile_set.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC:
		side = tile.x / sqrt(2.0)
	return HexLayout.new(ground.map_to_local(Vector2i.ZERO), side / 2.0)


const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]


## Builds the grid from a ground TileMapLayer (defines the region and cell size) and an
## optional blocking TileMapLayer (used cells become solid points). A transformed field
## layer can opt into projecting its collision footprint into Ground cell space. Call once
## after both layers exist; call again if the map itself changes shape.
func build(
	ground: TileMapLayer,
	blocking: TileMapLayer = null,
	static_clearance_cells: int = 0,
	project_blocking_to_ground: bool = false
) -> void:
	if is_instance_valid(_blocking) and _blocking.changed.is_connected(_refresh_obstacles):
		_blocking.changed.disconnect(_refresh_obstacles)
	# A hex rebuild over the same ground keeps its path graph and patches it: click-to-move
	# rebuilds on every repath, and a full hex graph costs a few hundred milliseconds on a big map.
	var keep_hex_graph := (
		hex_mode and _hex_astar != null and _ground == ground
		and ground.get_used_rect() == _astar.region
	)
	var static_before: Dictionary = _static_solid.duplicate()
	_ground = ground
	_blocking = blocking
	if _blocking != null:
		_blocking.changed.connect(_refresh_obstacles)
	_static_clearance_cells = maxi(static_clearance_cells, 0)
	_project_blocking_to_ground = project_blocking_to_ground
	var used := ground.get_used_rect()
	_astar.region = used
	_astar.cell_size = Vector2(ground.tile_set.tile_size)  # 64 x 32
	# Iso diagonals look cardinal. A Euclidean heuristic ranks them incorrectly.
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	# Never cut a corner through a building.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	_astar.fill_solid_region(used, false)
	if keep_hex_graph:
		var solid_before: Array = _hex_solid.keys()
		_clear_hex_marks()
		_bake_obstacles()
		_reapply_occupancy()
		for hex: Vector2i in solid_before:
			if _hex_ids.has(hex):
				_hex_astar.set_point_disabled(int(_hex_ids[hex]), _raw_solid(hex))
		_sync_hex_solids(static_before)
		return
	_reset_hex_state()
	_bake_obstacles()
	_reapply_occupancy()


## Forgets hex solids and weights on a kept graph, as `AStarGrid2D.update()` does for cells. The
## caller re-derives each formerly solid hex once the obstacles are baked again.
func _clear_hex_marks() -> void:
	_hex_static.clear()
	for hex: Vector2i in _hex_weights:
		if _hex_ids.has(hex):
			_hex_astar.set_point_weight_scale(int(_hex_ids[hex]), 1.0)
	_hex_weights.clear()
	_hex_solid.clear()


## A rebuild forgets hex solids and weights, as `AStarGrid2D.update()` does for cells;
## `_reapply_occupancy()` restores the standing actors.
func _reset_hex_state() -> void:
	_hex_in_region.clear()
	_hex_static.clear()
	_hex_solid.clear()
	_hex_weights.clear()
	_hex_astar = null
	_hex_ids.clear()
	_hex_by_id.clear()
	_hex_bounds_ready = false
	if hex_mode:
		_layout = hex_layout_for(_ground)


## Destructible scenery edits the authored collision layer. Refresh every consumer
## immediately without rebuilding AStar (which would erase terrain weights).
func _refresh_obstacles() -> void:
	# Layer teardown can emit changed after another layer released its TileSet.
	if not is_instance_valid(_ground) or not is_instance_valid(_blocking):
		return
	if _ground.tile_set == null or _blocking.tile_set == null:
		return
	var before: Dictionary = _static_solid.duplicate()
	for cell: Vector2i in _static_solid:
		_astar.set_point_solid(cell, false)
	_bake_obstacles()
	_hex_static.clear()
	_reapply_occupancy()
	_sync_hex_solids(before)


func _bake_obstacles() -> void:
	_static_solid.clear()
	if _blocking == null:
		return
	# Blocking can have a different transform from Ground (Dom's expanded
	# layout scales its authored collision layer). Bake in Ground cell space
	# so AStar and the physics polygons describe the same world positions.
	var occupied_ground_cells: Array[Vector2i] = []
	if (
		not _project_blocking_to_ground
		or (
			_ground.global_transform.is_equal_approx(_blocking.global_transform)
			and _ground.tile_set.tile_size == _blocking.tile_set.tile_size
		)
	):
		occupied_ground_cells.assign(_blocking.get_used_cells())
	else:
		var half_tile := Vector2(_ground.tile_set.tile_size) * 0.5
		var sample_offsets: Array[Vector2] = [
			Vector2.ZERO,
			Vector2(-half_tile.x, 0.0),
			Vector2(half_tile.x, 0.0),
			Vector2(0.0, -half_tile.y),
			Vector2(0.0, half_tile.y),
		]
		for ground_cell in _ground.get_used_cells():
			var ground_center := _ground.map_to_local(ground_cell)
			for sample_offset in sample_offsets:
				var world_position := _ground.to_global(ground_center + sample_offset)
				var blocking_cell := _blocking.local_to_map(_blocking.to_local(world_position))
				if _blocking.get_cell_source_id(blocking_cell) == -1:
					continue
				occupied_ground_cells.append(ground_cell)
				break
	for occupied_cell in occupied_ground_cells:
		for dx in range(-_static_clearance_cells, _static_clearance_cells + 1):
			for dy in range(-_static_clearance_cells, _static_clearance_cells + 1):
				var cell := occupied_cell + Vector2i(dx, dy)
				if not _astar.is_in_boundsv(cell):
					continue
				_astar.set_point_solid(cell, true)
				_static_solid[cell] = true


# --- coordinate conversion: the ONLY place that holds world/cell math ---


func world_to_cell(world: Vector2) -> Vector2i:
	if hex_mode:
		return _layout.world_to_hex(_ground.to_local(world))
	return _ground.local_to_map(_ground.to_local(world))


func cell_to_world(cell: Vector2i) -> Vector2:
	if hex_mode:
		return _ground.to_global(_layout.hex_to_world(cell))
	return _square_center(cell)


func _square_center(cell: Vector2i) -> Vector2:
	return _ground.to_global(_ground.map_to_local(cell))


## Returns the neighboring cell whose world-space direction most closely matches the
## requested screen direction. TileMapLayer owns the projection, so this remains correct
## if a field's grid transform differs from the default 64x32 diamond layout.
func screen_direction_to_neighbor(cell: Vector2i, screen_direction: Vector2) -> Vector2i:
	var ranked: Array[Vector2i] = neighbors_by_screen_direction(cell, screen_direction)
	return cell if ranked.is_empty() else ranked[0]


## Orders all adjacent cells (eight squares, or six hexes) from closest to furthest angular match. This is public
## so keyboard stepping and its tests share one definition of screen-relative movement.
func neighbors_by_screen_direction(
	cell: Vector2i,
	screen_direction: Vector2
) -> Array[Vector2i]:
	var ranked: Array[Vector2i] = []
	if screen_direction.is_zero_approx():
		return ranked
	var remaining: Array[Vector2i] = _neighbor_offsets().duplicate()
	var requested: Vector2 = screen_direction.normalized()
	var origin_world: Vector2 = cell_to_world(cell)
	while not remaining.is_empty():
		var best_index: int = 0
		var best_score: float = -INF
		for index in range(remaining.size()):
			var offset: Vector2i = remaining[index]
			var world_direction: Vector2 = cell_to_world(cell + offset) - origin_world
			var score: float = requested.dot(world_direction.normalized())
			if score > best_score:
				best_score = score
				best_index = index
		ranked.append(cell + remaining[best_index])
		remaining.remove_at(best_index)
	return ranked


## Chooses the best matching open neighbor. If the direct match is blocked, the two
## angularly-nearest alternatives are tried in order so held movement glides along walls.
func resolve_step_cell(
	cell: Vector2i,
	screen_direction: Vector2,
	mover: Object = null
) -> Variant:
	var ranked: Array[Vector2i] = neighbors_by_screen_direction(cell, screen_direction)
	for index in range(mini(3, ranked.size())):
		var candidate: Vector2i = ranked[index]
		if is_step_blocked(candidate, mover):
			continue
		# Corner-cut rule for cell-space diagonals: the body passes between the two
		# flanking cardinals, so at least one of them must be open or a non-zero-width
		# body wedges on the seam even though the destination cell itself is free.
		# Hex neighbours share an edge, so a hex step has no corner to cut; its walk line must
		# still stay off the walls.
		if hex_mode and _is_hex_edge_walled(cell, candidate):
			continue
		var offset: Vector2i = candidate - cell
		if not hex_mode and offset.x != 0 and offset.y != 0:
			var flank_a := Vector2i(cell.x + offset.x, cell.y)
			var flank_b := Vector2i(cell.x, cell.y + offset.y)
			if is_step_blocked(flank_a, mover) and is_step_blocked(flank_b, mover):
				continue
		return candidate
	return null


# --- pathfinding ---


## Routes around both painted obstacles and standing actors. `mover` is the actor asking: its
## OWN occupied cell must never block its own path, which is the easy half of this to get wrong.
## The cell the path starts from is likewise exempt from occupancy (never from a painted wall) —
## an actor another body is overlapping must still be able to walk away.
func path_cells(from: Vector2i, to: Vector2i, mover: Object = null) -> PackedVector2Array:
	if is_blocked_for(to, mover):
		return PackedVector2Array()
	if hex_mode and not _in_region(from):
		return PackedVector2Array()
	var freed := _free_cells_for_pathing(from, mover)
	var result: PackedVector2Array
	if hex_mode:
		result = _hex_path(from, to)
	else:
		result = _astar.get_id_path(from, to)
	for cell in freed:
		_set_solid_raw(cell, true)
	return result


func _hex_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	_ensure_hex_astar()
	var result := PackedVector2Array()
	for id: int in _hex_astar.get_id_path(int(_hex_ids[from]), int(_hex_ids[to])):
		result.append(Vector2(_hex_by_id[id]))
	return result


## Temporarily un-solids the cells a path query must be allowed to stand on: the start cell and
## the mover's own. Returns them so the caller can restore them. Only occupancy is lifted —
## a painted wall stays solid, so this can never route a body through a building.
func _free_cells_for_pathing(from: Vector2i, mover: Object) -> Array[Vector2i]:
	var freed: Array[Vector2i] = []
	var candidates: Array[Vector2i] = [from]
	if mover != null and _occupant_cells.has(mover):
		candidates.append(_occupant_cells[mover])
	for cell in candidates:
		if freed.has(cell) or _is_static(cell) or not _occupancy.has(cell):
			continue
		if not _in_region(cell):
			continue
		_set_solid_raw(cell, false)
		freed.append(cell)
	return freed


func path_world(from: Vector2, to: Vector2, mover: Object = null) -> PackedVector2Array:
	var cells := path_cells(world_to_cell(from), world_to_cell(to), mover)
	var out := PackedVector2Array()
	for c in cells:
		out.append(cell_to_world(Vector2i(c)))
	return out


# --- passability / cost, exposed for GridBattlefieldModel (§1.6) and any overworld caller ---


## Marks (or clears) a cell as impassable. Living combatants and static obstacles both go
## through this — do not reach into the underlying AStarGrid2D from outside this class.
func set_point_solid(cell: Vector2i, solid: bool = true) -> void:
	if _in_region(cell):
		_set_solid_raw(cell, solid)


func is_point_solid(cell: Vector2i) -> bool:
	return _in_region(cell) and _raw_solid(cell)


## Scales the cost of entering `cell`. §1.6 uses this for elevation: a climb costs more charge
## time. A cliff should be `set_point_solid()`, never an expensive weight — "blocked by
## elevation" and "expensive because of elevation" must stay distinguishable refusals.
func set_point_weight_scale(cell: Vector2i, weight_scale: float) -> void:
	if not _in_region(cell):
		return
	if not hex_mode:
		_astar.set_point_weight_scale(cell, weight_scale)
		return
	_hex_weights[cell] = weight_scale
	if _hex_astar != null and _hex_ids.has(cell):
		_hex_astar.set_point_weight_scale(int(_hex_ids[cell]), weight_scale)


func get_point_weight_scale(cell: Vector2i) -> float:
	if not _in_region(cell):
		return 1.0
	if hex_mode:
		return float(_hex_weights.get(cell, 1.0))
	return _astar.get_point_weight_scale(cell)


# --- dynamic occupancy (GH #190): the second layer of ONE passability query ---


## Registers `occupant` as standing on `cell`, vacating whichever cell it stood on before.
## The cell becomes impassable to everyone except `occupant` itself. Idempotent — call it every
## frame with a walking actor's current cell if you like.
func set_occupant(occupant: Object, cell: Vector2i) -> void:
	if occupant == null or not _in_region(cell):
		return
	var previous: Variant = _occupant_cells.get(occupant)
	if previous != null and previous == cell:
		return
	if previous != null:
		_vacate(previous)
	_occupancy[cell] = occupant
	_occupant_cells[occupant] = cell
	_set_solid_raw(cell, true)


func clear_occupant(occupant: Object) -> void:
	var cell: Variant = _occupant_cells.get(occupant)
	if cell == null:
		return
	_occupant_cells.erase(occupant)
	_vacate(cell)


func clear_all_occupants() -> void:
	for cell: Vector2i in _occupancy.keys():
		_set_solid_raw(cell, _is_static(cell))
	_occupancy.clear()
	_occupant_cells.clear()


func occupant_of(cell: Vector2i) -> Object:
	return _occupancy.get(cell)


## The cell `occupant` currently stands on, or `null` if it is not registered.
func cell_of_occupant(occupant: Object) -> Variant:
	return _occupant_cells.get(occupant)


## The one question a caller should ask: "can `mover` path through this cell?" Static geometry
## and dynamic occupancy are answered together, in that order, by this single method.
## World-space bounding box of the painted region (the diamond's corner cells).
## Camera bounds alone cannot bound movement in an iso scene — the diamond's left
## and top corners project to negative world coordinates outside any screen rect.
func world_bounds() -> Rect2:
	# The painted square region in both modes: hexes cover the same ground.
	var rect: Rect2i = _astar.region
	var bounds := Rect2(_square_center(rect.position), Vector2.ZERO)
	bounds = bounds.expand(_square_center(Vector2i(rect.end.x - 1, rect.position.y)))
	bounds = bounds.expand(_square_center(Vector2i(rect.position.x, rect.end.y - 1)))
	bounds = bounds.expand(_square_center(rect.end - Vector2i.ONE))
	return bounds


## Passability for grid STEPPING and PLACEMENT (Wave Q). The iso lattice extends
## beyond the painted ground: a cell outside the built region carries no paint and
## no tracked occupancy, so it is OPEN — parity with the free-movement era, where
## unpainted ground was walkable. Physics colliders still bound the world out
## there (backed by the player's wedge recovery). Pathfinding (`find_path` /
## `is_blocked_for`) stays region-bounded: A* cannot route through virtual cells.
func is_step_blocked(cell: Vector2i, mover: Object = null) -> bool:
	if not _in_region(cell):
		return false
	return is_blocked_for(cell, mover)


func is_blocked_for(cell: Vector2i, mover: Object = null) -> bool:
	if not _in_region(cell):
		return true
	if _is_static(cell):
		return true
	if _raw_solid(cell) and not _occupancy.has(cell):
		return true  # set solid by a caller outside this class (e.g. a tactical-layer cliff)
	var occupant: Object = _occupancy.get(cell)
	return occupant != null and occupant != mover


func _vacate(cell: Vector2i) -> void:
	_occupancy.erase(cell)
	_set_solid_raw(cell, _is_static(cell))


## Re-asserts occupancy after `build()` wiped AStarGrid2D's solid flags, and drops any occupant
## that has since been freed or moved outside the new region.
func _reapply_occupancy() -> void:
	var live: Array = _occupant_cells.keys()
	_occupancy.clear()
	for occupant in live:
		var cell: Vector2i = _occupant_cells[occupant]
		if (occupant is Object and not is_instance_valid(occupant)) or not _in_region(cell):
			_occupant_cells.erase(occupant)
			continue
		_occupancy[cell] = occupant
		_set_solid_raw(cell, true)


func is_in_bounds(cell: Vector2i) -> bool:
	return _in_region(cell)


## The grid's bounding rectangle. In hex mode it bounds the axial hexes, and not every hex inside
## it is on the grid: iterate it with `is_in_bounds`.
func get_used_rect() -> Rect2i:
	if not hex_mode:
		return _astar.region
	if not _hex_bounds_ready:
		var hexes := _hex_region_hexes()
		_hex_bounds = Rect2i()
		if not hexes.is_empty():
			var low := hexes[0]
			var high := hexes[0]
			for hex: Vector2i in hexes:
				low = Vector2i(mini(low.x, hex.x), mini(low.y, hex.y))
				high = Vector2i(maxi(high.x, hex.x), maxi(high.y, hex.y))
			_hex_bounds = Rect2i(low, high - low + Vector2i.ONE)
		_hex_bounds_ready = true
	return _hex_bounds


# --- what combat needs from the grid (hex slice H2): the same answers on cells and hexes ---


## The steps one move can take: the six hex directions, or the eight square neighbours.
func neighbor_offsets() -> Array[Vector2i]:
	return _neighbor_offsets()


## Whether the straight step between two neighbouring hexes crosses a painted wall (see
## `_is_hex_edge_walled`). Always false on the square grid, whose own rule is the corner cut.
func is_edge_walled(from: Vector2i, to: Vector2i) -> bool:
	return hex_mode and _is_hex_edge_walled(from, to)


## The square cell under a hex's centre, where the hex's height, cover and terrain are authored.
## On the square grid, the cell itself.
func square_cell_of(cell: Vector2i) -> Vector2i:
	if not hex_mode:
		return cell
	return _ground.local_to_map(_layout.hex_to_world(cell))


## The hexes whose centre lies on one square cell (four or five of them). They take that cell's
## authored terrain. On the square grid, the cell itself.
func cells_on_square(square_cell: Vector2i) -> Array[Vector2i]:
	if not hex_mode:
		return [square_cell]
	var tile := Vector2(_ground.tile_set.tile_size)
	var center := _ground.map_to_local(square_cell)
	var result: Array[Vector2i] = []
	for hex: Vector2i in _layout.hexes_in_rect(Rect2(center - tile * 0.5, tile)):
		if _ground.local_to_map(_layout.hex_to_world(hex)) == square_cell:
			result.append(hex)
	return result


## The painted square region, in cells, on either grid.
func square_rect() -> Rect2i:
	return _astar.region


## The cell of this grid at a square cell's centre: the cell itself, or the hex under its centre.
## Anything authored on cells (default seats) lands here.
func cell_at_square(square_cell: Vector2i) -> Vector2i:
	if not hex_mode:
		return square_cell
	return _layout.world_to_hex(_ground.map_to_local(square_cell))


## Every cell, or every hex, on the grid.
func region_cells() -> Array[Vector2i]:
	if hex_mode:
		return _hex_region_hexes()
	var cells: Array[Vector2i] = []
	var rect: Rect2i = _astar.region
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
	return cells


## The cell or hex `cell_steps` square steps from `from` toward a screen direction. On the square
## grid each step is the best-matching neighbour, as before. On hexes it covers the same ground:
## the best-matching square step's offset, `cell_steps` times, then the hex under that point. Set
## pieces therefore keep the spacing they were authored with.
func screen_steps(from: Vector2i, screen_direction: Vector2, cell_steps: int) -> Vector2i:
	if not hex_mode:
		var cell := from
		for _step in cell_steps:
			cell = screen_direction_to_neighbor(cell, screen_direction)
		return cell
	if screen_direction.is_zero_approx():
		return from
	var requested := screen_direction.normalized()
	var origin := _ground.map_to_local(Vector2i.ZERO)
	var best := Vector2.ZERO
	var best_score := -INF
	for offset: Vector2i in NEIGHBOR_OFFSETS:
		var step := _ground.map_to_local(offset) - origin
		var score := requested.dot(step.normalized())
		if score > best_score:
			best_score = score
			best = step
	return _layout.world_to_hex(_layout.hex_to_world(from) + best * float(cell_steps))


# --- one set of calls over two grids: square cells, or hexes in hex mode ---


func _neighbor_offsets() -> Array[Vector2i]:
	return HexMath.DIRECTIONS if hex_mode else NEIGHBOR_OFFSETS


## Whether a cell (or hex) is on the grid. A hex is on it when its centre lies on a cell of the
## square region.
func _in_region(cell: Vector2i) -> bool:
	if not hex_mode:
		return _astar.is_in_boundsv(cell)
	var known: Variant = _hex_in_region.get(cell)
	if known == null:
		known = _astar.is_in_boundsv(_ground.local_to_map(_layout.hex_to_world(cell)))
		_hex_in_region[cell] = known
	return bool(known)


## Painted obstacles. A hex is solid when its centre, or any corner pulled halfway in, lands on a
## solid cell: walls get slightly thicker, and none can be slipped through.
func _is_static(cell: Vector2i) -> bool:
	if not hex_mode:
		return _static_solid.has(cell)
	var known: Variant = _hex_static.get(cell)
	if known == null:
		known = false
		if not _static_solid.is_empty():
			for point: Vector2 in _layout.sample_points(cell):
				if _static_solid.has(_ground.local_to_map(point)):
					known = true
					break
		_hex_static[cell] = known
	return bool(known)


func _raw_solid(cell: Vector2i) -> bool:
	if not hex_mode:
		return _astar.is_point_solid(cell)
	return _hex_solid.has(cell) or _is_static(cell)


func _set_solid_raw(cell: Vector2i, solid: bool) -> void:
	if not hex_mode:
		_astar.set_point_solid(cell, solid)
		return
	if solid:
		_hex_solid[cell] = true
	else:
		_hex_solid.erase(cell)
	if _hex_astar != null and _hex_ids.has(cell):
		_hex_astar.set_point_disabled(int(_hex_ids[cell]), _raw_solid(cell))


## Every hex on the grid: the hexes whose centre lies on a cell of the square region.
func _hex_region_hexes() -> Array[Vector2i]:
	var region: Rect2i = _astar.region
	var tile := Vector2(_ground.tile_set.tile_size)
	var local := Rect2(_ground.map_to_local(region.position), Vector2.ZERO)
	local = local.expand(_ground.map_to_local(Vector2i(region.end.x - 1, region.position.y)))
	local = local.expand(_ground.map_to_local(Vector2i(region.position.x, region.end.y - 1)))
	local = local.expand(_ground.map_to_local(region.end - Vector2i.ONE))
	# Grow by half a tile so the region's outer diamond corners are inside.
	local = local.grow_individual(tile.x * 0.5, tile.y * 0.5, tile.x * 0.5, tile.y * 0.5)
	var hexes: Array[Vector2i] = []
	for hex: Vector2i in _layout.hexes_in_rect(local):
		if _in_region(hex):
			hexes.append(hex)
	return hexes


## Builds the hex `AStar2D` on the first path query. Points sit in flat space (y undone 2:1) so
## every neighbour is the same distance apart and the Euclidean heuristic holds.
func _ensure_hex_astar() -> void:
	if _hex_astar != null:
		return
	_hex_astar = AStar2D.new()
	_hex_ids.clear()
	_hex_by_id.clear()
	var hexes := _hex_region_hexes()
	_hex_astar.reserve_space(hexes.size())
	for hex: Vector2i in hexes:
		var id := _hex_by_id.size()
		_hex_ids[hex] = id
		_hex_by_id.append(hex)
		var at := _layout.hex_to_world(hex)
		_hex_astar.add_point(
			id, Vector2(at.x, at.y / HexLayout.SQUASH), float(_hex_weights.get(hex, 1.0))
		)
		if _raw_solid(hex):
			_hex_astar.set_point_disabled(id, true)
	# E, NE and NW from every hex covers each of the six edges once.
	for hex: Vector2i in hexes:
		for direction in 3:
			var other: Vector2i = hex + HexMath.DIRECTIONS[direction]
			if _hex_ids.has(other) and not _is_hex_edge_walled(hex, other):
				_hex_astar.connect_points(int(_hex_ids[hex]), int(_hex_ids[other]), true)


## Whether the straight walk line between two neighbouring hexes crosses a solid cell. Two wall
## cells that touch only at a corner leave a gap of zero width there, and a row of hexes can pass
## within a pixel of it, so the midpoint is also tested a little to either side of the line.
func _is_hex_edge_walled(from: Vector2i, to: Vector2i) -> bool:
	if _static_solid.is_empty():
		return false
	var a := _layout.hex_to_world(from)
	var b := _layout.hex_to_world(to)
	var middle := a.lerp(b, 0.5)
	var side := (b - a).orthogonal().normalized() * 1.5
	for point: Vector2 in [a.lerp(b, 0.25), middle, a.lerp(b, 0.75), middle + side, middle - side]:
		if _static_solid.has(_ground.local_to_map(point)):
			return true
	return false


## After the painted obstacles change, patch the built hex graph around the cells that changed:
## each nearby hex's solid flag and its six edges. A full rebuild of a large map takes a few
## hundred milliseconds; destructible scenery must not stall the game for that.
func _sync_hex_solids(static_before: Dictionary) -> void:
	if not hex_mode or _hex_astar == null:
		return
	var changed: Array[Vector2i] = []
	for cell: Vector2i in static_before:
		if not _static_solid.has(cell):
			changed.append(cell)
	for cell: Vector2i in _static_solid:
		if not static_before.has(cell):
			changed.append(cell)
	var tile := Vector2(_ground.tile_set.tile_size)
	var touched := {}
	for cell: Vector2i in changed:
		# Every hex whose samples or walk lines can reach this cell's diamond.
		var center := _ground.map_to_local(cell)
		for hex: Vector2i in _layout.hexes_in_rect(Rect2(center - tile, tile * 2.0)):
			touched[hex] = true
	for hex: Vector2i in touched:
		if not _hex_ids.has(hex):
			continue
		var id := int(_hex_ids[hex])
		_hex_astar.set_point_disabled(id, _raw_solid(hex))
		for offset: Vector2i in HexMath.DIRECTIONS:
			var other: Vector2i = hex + offset
			if not _hex_ids.has(other):
				continue
			var other_id := int(_hex_ids[other])
			var walled := _is_hex_edge_walled(hex, other)
			var linked := _hex_astar.are_points_connected(id, other_id)
			if walled and linked:
				_hex_astar.disconnect_points(id, other_id)
			elif not walled and not linked:
				_hex_astar.connect_points(id, other_id)


## Builds the hex path graph now instead of on the first path query. The player's grid calls it at
## map load: on the largest map the build takes a few hundred milliseconds, which must not land on
## the first click. Does nothing on the square grid.
func prepare_paths() -> void:
	if hex_mode:
		_ensure_hex_astar()
