class_name BlockingLayer
extends TileMapLayer
## The obstacle authoring layer — `docs/architecture-tactical-and-navigation.md` §2.3's
## SINGLE source of truth for static passability (GH #161, moved out of the scene by #187).
##
## The cells are PAINTED, in the editor, into this layer's own `tile_map_data`. They are not
## generated at runtime. That is the whole point: the same painted set drives BOTH the
## `AStarGrid2D` bake (`world/nav/iso_grid.gd`, via `IsoGrid.build(ground, blocking)`) and
## physics collision (the layer's `TileSet` carries a physics layer with a diamond collision
## polygon), so the two can never drift apart. Adding a building means painting cells — never
## editing code, and never authoring an obstacle twice.
##
## The layer is `visible = false`: it exists to be occupied, not seen.
##
## Cell data is authored in the scene. This script validates that contract and applies
## opt-in destruction/restoration to an object's captured footprint. It fails loudly when
## the contract breaks — a missing `TileSet` means no physics AND no bake, and a player walks through a
## wall with nothing in the log. It is the guard #187 asked for in place of the 221-element
## constant it replaced.
##
## Actors (NPCs, townsfolk) are NOT painted here. They are dynamic and are layered on top of
## this static set as occupancy — see `world/nav/nav_occupancy.gd` and `IsoGrid.set_occupant()`.


## Each row is the authored [source_id, atlas_coords, alternative_tile]. Notify
## consumers once after the whole edit: TileMapLayer cell writes do not emit changed.
func set_structure_footprint(tiles: Dictionary, enabled: bool) -> void:
	var edited := false
	for cell: Vector2i in tiles:
		var tile: Array = tiles[cell]
		if enabled:
			if (
				get_cell_source_id(cell) == tile[0]
				and get_cell_atlas_coords(cell) == tile[1]
				and get_cell_alternative_tile(cell) == tile[2]
			):
				continue
			set_cell(cell, tile[0], tile[1], tile[2])
		else:
			if get_cell_source_id(cell) == -1:
				continue
			erase_cell(cell)
		edited = true
	if edited:
		changed.emit()


func _ready() -> void:
	if tile_set == null:
		push_error(
			"%s has no TileSet. Assign world/nav/blocking_tiles.tres — without it this layer "
			% name
			+ "provides neither physics collision nor pathfinding obstacles."
		)
		return
	if tile_set.get_physics_layers_count() <= 0:
		push_error(
			"%s's TileSet has no physics layer, so painted cells are invisible to " % name
			+ "move_and_slide(). Pathfinding and collision would disagree."
		)
	if get_used_cells().is_empty():
		push_warning(
			"%s is empty — nothing in this scene blocks movement. If that is intentional, " % name
			+ "delete the layer instead of leaving it unpainted."
		)
