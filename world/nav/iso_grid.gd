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


## Builds the grid from a ground TileMapLayer (defines the region and cell size) and an
## optional blocking TileMapLayer (used cells become solid points). Call once after both
## layers exist; call again if the map itself changes shape.
func build(ground: TileMapLayer, blocking: TileMapLayer = null) -> void:
	_ground = ground
	_blocking = blocking
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


func _bake_obstacles() -> void:
	if _blocking == null:
		return
	for cell in _blocking.get_used_cells():
		if _astar.is_in_boundsv(cell):
			_astar.set_point_solid(cell, true)


# --- coordinate conversion: the ONLY place that holds world/cell math ---


func world_to_cell(world: Vector2) -> Vector2i:
	return _ground.local_to_map(_ground.to_local(world))


func cell_to_world(cell: Vector2i) -> Vector2:
	return _ground.to_global(_ground.map_to_local(cell))


# --- pathfinding ---


func path_cells(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	if not _astar.is_in_boundsv(to) or _astar.is_point_solid(to):
		return PackedVector2Array()
	return _astar.get_id_path(from, to)


func path_world(from: Vector2, to: Vector2) -> PackedVector2Array:
	var cells := path_cells(world_to_cell(from), world_to_cell(to))
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


func is_in_bounds(cell: Vector2i) -> bool:
	return _astar.is_in_boundsv(cell)


func get_used_rect() -> Rect2i:
	return _astar.region
