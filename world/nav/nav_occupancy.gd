class_name NavOccupancy
extends RefCounted
## Overworld actor occupancy — the dynamic half of `docs/architecture-tactical-and-navigation.md`
## §2.3's single source of truth for passability (GH #190).
##
## §2.3 makes the painted `Blocking` layer authoritative for STATIC geometry. It says nothing
## about actors, because actors are not map data. But a click-path that ignores them routes the
## player straight into a standing shopkeeper: `AStarGrid2D` sees open ground, `move_and_slide()`
## hits a body. So actors are layered ON TOP of the painted set as occupancy, inside the same
## `IsoGrid` — NOT as a second passability system. One caller, one question:
## `IsoGrid.is_blocked_for(cell, mover)`.
##
## Membership is opt-in via `GROUP`. A node joins when it is a solid, standing obstacle a path
## should route around. Party followers deliberately do NOT join: they trail the player at close
## range, so making them solid would have the player continually re-routing around their own
## retinue (and, when boxed in, refusing to move at all). They are the player's problem to walk
## through, not the pathfinder's.
##
## Occupancy is PULLED, not pushed, because each overworld consumer builds its own `IsoGrid`
## (see `ClickMoveController._rebuild_grid`). Pushing would require actors to know which grids
## exist. Pulling costs one `get_nodes_in_group()` per path request — ~35 nodes in Dom.

## Nodes in this group occupy their current cell and block other actors' paths.
const GROUP := &"nav_blocker"


## Adds `node` to the occupancy group. A one-line indirection so actor scripts never hard-code
## the group name and `rg NavOccupancy` finds every participant.
static func register(node: Node) -> void:
	if node != null and not node.is_in_group(GROUP):
		node.add_to_group(GROUP)


## Rewrites `grid`'s occupancy from the live positions of every `GROUP` member under `root`.
##
## Scoping to `root` is load-bearing, not tidiness: gdUnit4 boots the whole project, so a
## previous suite's leaked actors sit under the same `SceneTree` as the scene under test. A
## tree-wide sweep would make an isolated fixture's pathfinding depend on suite ordering.
##
## `exclude` is the actor doing the asking — normally redundant (the mover's own cell is exempt
## inside `IsoGrid.path_cells`), but it also keeps the player out of the map entirely so nothing
## else can accidentally treat the player as scenery.
static func sync(grid: IsoGrid, root: Node, exclude: Object = null) -> void:
	if grid == null or root == null or not root.is_inside_tree():
		return
	grid.clear_all_occupants()
	for node in root.get_tree().get_nodes_in_group(GROUP):
		var actor := node as Node2D
		if actor == null or actor == exclude:
			continue
		if not actor.is_inside_tree() or not root.is_ancestor_of(actor):
			continue
		grid.set_occupant(actor, grid.world_to_cell(actor.global_position))
