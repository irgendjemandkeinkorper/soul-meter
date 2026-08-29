class_name GridPlacement
extends RefCounted
## Apply-time snapping of authored field-actor positions onto the overworld iso grid
## (Wave Q, owner-ratified 2026-08-29: everything rests on cell centers). Authored
## scene/routine coordinates remain untouched — actors call `snap_to_walkable_cell()`
## when a position is APPLIED (ready, routine phase), and scenes without an
## IsometricGround layer keep free placement.
##
## Placement deliberately does NOT reuse the player's pathing grid: that grid dilates
## painted blocking by the mover's body clearance, which wrongly marks every
## wall/stall-adjacent cell unplaceable and would hunt "nearest walkable" far across
## the map. A standing actor IS an obstacle; it needs raw painted passability only.

## Snapping is a small correction onto the grid, never a relocation. If no open cell
## center exists within this Chebyshev radius of the authored cell, the authored
## position is kept as-is (an off-grid but visually-correct stand beats teleporting
## an NPC across a plaza).
const MAX_SNAP_CELLS: int = 2

## Placement passability is the raw painted map — no mover-body dilation.
const PLACEMENT_CLEARANCE_CELLS: int = 0


## Moves `actor` to the open cell center nearest `authored_position` (within
## MAX_SNAP_CELLS), or leaves it at the authored position when no navigation grid
## exists in its scene or no nearby cell is open.
static func snap_to_walkable_cell(actor: Node2D, authored_position: Vector2) -> void:
	var navigation_root: Node = _navigation_root(actor)
	if navigation_root == null:
		actor.global_position = authored_position
		return
	var ground: TileMapLayer = (
		navigation_root.find_child("IsometricGround", true, false) as TileMapLayer
	)
	if ground == null or ground.tile_set == null:
		actor.global_position = authored_position
		return
	var grid := IsoGrid.new()
	var blocking: TileMapLayer = (
		navigation_root.find_child("Blocking", true, false) as TileMapLayer
	)
	grid.build(ground, blocking, PLACEMENT_CLEARANCE_CELLS, true)
	NavOccupancy.sync(grid, navigation_root, actor)
	var snapped: Variant = _nearby_open_cell_center(grid, actor, authored_position)
	actor.global_position = snapped if snapped is Vector2 else authored_position


static func _navigation_root(actor: Node2D) -> Node:
	if not actor.is_inside_tree():
		return null
	var scene: Node = actor.get_tree().current_scene
	if scene != null and (scene == actor or scene.is_ancestor_of(actor)):
		return scene
	var root: Node = actor
	while root.get_parent() != null and root.get_parent() != actor.get_tree().root:
		root = root.get_parent()
	return root


static func _nearby_open_cell_center(
	grid: IsoGrid,
	actor: Node2D,
	authored_position: Vector2
) -> Variant:
	var used_rect: Rect2i = grid.get_used_rect()
	var authored_cell: Vector2i = grid.world_to_cell(authored_position)
	var nearest_position: Variant = null
	var nearest_distance_squared: float = INF
	for y: int in range(authored_cell.y - MAX_SNAP_CELLS, authored_cell.y + MAX_SNAP_CELLS + 1):
		for x: int in range(authored_cell.x - MAX_SNAP_CELLS, authored_cell.x + MAX_SNAP_CELLS + 1):
			var cell := Vector2i(x, y)
			if not used_rect.has_point(cell):
				continue
			if grid.is_blocked_for(cell, actor):
				continue
			var candidate: Vector2 = grid.cell_to_world(cell)
			var distance_squared: float = candidate.distance_squared_to(authored_position)
			if distance_squared < nearest_distance_squared:
				nearest_distance_squared = distance_squared
				nearest_position = candidate
	return nearest_position
