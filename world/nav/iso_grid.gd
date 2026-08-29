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
	_ground = ground
	_blocking = blocking
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
	_bake_obstacles()
	_reapply_occupancy()


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
	return _ground.local_to_map(_ground.to_local(world))


func cell_to_world(cell: Vector2i) -> Vector2:
	return _ground.to_global(_ground.map_to_local(cell))


## Returns the neighboring cell whose world-space direction most closely matches the
## requested screen direction. TileMapLayer owns the projection, so this remains correct
## if a field's grid transform differs from the default 64x32 diamond layout.
func screen_direction_to_neighbor(cell: Vector2i, screen_direction: Vector2) -> Vector2i:
	var ranked: Array[Vector2i] = neighbors_by_screen_direction(cell, screen_direction)
	return cell if ranked.is_empty() else ranked[0]


## Orders all eight adjacent cells from closest to furthest angular match. This is public
## so keyboard stepping and its tests share one definition of screen-relative movement.
func neighbors_by_screen_direction(
	cell: Vector2i,
	screen_direction: Vector2
) -> Array[Vector2i]:
	var ranked: Array[Vector2i] = []
	if screen_direction.is_zero_approx():
		return ranked
	var remaining: Array[Vector2i] = NEIGHBOR_OFFSETS.duplicate()
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
		if not is_blocked_for(candidate, mover):
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
	var freed := _free_cells_for_pathing(from, mover)
	var result := _astar.get_id_path(from, to)
	for cell in freed:
		_astar.set_point_solid(cell, true)
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
		if freed.has(cell) or _static_solid.has(cell) or not _occupancy.has(cell):
			continue
		if not _astar.is_in_boundsv(cell):
			continue
		_astar.set_point_solid(cell, false)
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
	if _astar.is_in_boundsv(cell):
		_astar.set_point_solid(cell, solid)


func is_point_solid(cell: Vector2i) -> bool:
	return _astar.is_in_boundsv(cell) and _astar.is_point_solid(cell)


## Scales the cost of entering `cell`. §1.6 uses this for elevation: a climb costs more charge
## time. A cliff should be `set_point_solid()`, never an expensive weight — "blocked by
## elevation" and "expensive because of elevation" must stay distinguishable refusals.
func set_point_weight_scale(cell: Vector2i, weight_scale: float) -> void:
	if _astar.is_in_boundsv(cell):
		_astar.set_point_weight_scale(cell, weight_scale)


func get_point_weight_scale(cell: Vector2i) -> float:
	if _astar.is_in_boundsv(cell):
		return _astar.get_point_weight_scale(cell)
	return 1.0


# --- dynamic occupancy (GH #190): the second layer of ONE passability query ---


## Registers `occupant` as standing on `cell`, vacating whichever cell it stood on before.
## The cell becomes impassable to everyone except `occupant` itself. Idempotent — call it every
## frame with a walking actor's current cell if you like.
func set_occupant(occupant: Object, cell: Vector2i) -> void:
	if occupant == null or not _astar.is_in_boundsv(cell):
		return
	var previous: Variant = _occupant_cells.get(occupant)
	if previous != null and previous == cell:
		return
	if previous != null:
		_vacate(previous)
	_occupancy[cell] = occupant
	_occupant_cells[occupant] = cell
	_astar.set_point_solid(cell, true)


func clear_occupant(occupant: Object) -> void:
	var cell: Variant = _occupant_cells.get(occupant)
	if cell == null:
		return
	_occupant_cells.erase(occupant)
	_vacate(cell)


func clear_all_occupants() -> void:
	for cell in _occupancy.keys():
		_astar.set_point_solid(cell, _static_solid.has(cell))
	_occupancy.clear()
	_occupant_cells.clear()


func occupant_of(cell: Vector2i) -> Object:
	return _occupancy.get(cell)


## The cell `occupant` currently stands on, or `null` if it is not registered.
func cell_of_occupant(occupant: Object) -> Variant:
	return _occupant_cells.get(occupant)


## The one question a caller should ask: "can `mover` path through this cell?" Static geometry
## and dynamic occupancy are answered together, in that order, by this single method.
func is_blocked_for(cell: Vector2i, mover: Object = null) -> bool:
	if not _astar.is_in_boundsv(cell):
		return true
	if _static_solid.has(cell):
		return true
	if _astar.is_point_solid(cell) and not _occupancy.has(cell):
		return true  # set solid by a caller outside this class (e.g. a tactical-layer cliff)
	var occupant: Object = _occupancy.get(cell)
	return occupant != null and occupant != mover


func _vacate(cell: Vector2i) -> void:
	_occupancy.erase(cell)
	_astar.set_point_solid(cell, _static_solid.has(cell))


## Re-asserts occupancy after `build()` wiped AStarGrid2D's solid flags, and drops any occupant
## that has since been freed or moved outside the new region.
func _reapply_occupancy() -> void:
	var live: Array = _occupant_cells.keys()
	_occupancy.clear()
	for occupant in live:
		var cell: Vector2i = _occupant_cells[occupant]
		if (occupant is Object and not is_instance_valid(occupant)) or not _astar.is_in_boundsv(cell):
			_occupant_cells.erase(occupant)
			continue
		_occupancy[cell] = occupant
		_astar.set_point_solid(cell, true)


func is_in_bounds(cell: Vector2i) -> bool:
	return _astar.is_in_boundsv(cell)


func get_used_rect() -> Rect2i:
	return _astar.region
