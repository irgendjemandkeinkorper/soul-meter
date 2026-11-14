class_name CombatTerrainLayer
extends TileMapLayer
## Hidden map-authored combat metadata. Tile custom data is the runtime source of truth.

const TERRAIN_TILE_SET := preload("res://world/nav/combat_terrain_tiles.tres")
const COVER_TILE := Vector2i(1, 0)
const ELEVATION_ONE_TILE := Vector2i(2, 0)
const ELEVATION_TWO_TILE := Vector2i(3, 0)
## A wall that stops a line of fire: the plain tile's alternative with `blocks_fire` set (the
## atlas holds four tiles, so the wall is an alternative rather than a fifth tile).
const WALL_TILE := Vector2i.ZERO
const WALL_ALTERNATIVE := 1

@export var cover_cells: Array[Vector2i] = []
@export var elevation_one_cells: Array[Vector2i] = []
@export var elevation_two_cells: Array[Vector2i] = []
## Walk-in building walls less their windows (owner list item 35): a fight's line of fire cannot
## cross them.
## Written by tools/paint_blocking.gd from each building's wall line; never by hand.
@export var blocks_fire_cells: Array[Vector2i] = []


func _ready() -> void:
	tile_set = TERRAIN_TILE_SET
	for cell: Vector2i in cover_cells:
		set_cell(cell, 0, COVER_TILE)
	for cell: Vector2i in elevation_one_cells:
		set_cell(cell, 0, ELEVATION_ONE_TILE)
	for cell: Vector2i in elevation_two_cells:
		set_cell(cell, 0, ELEVATION_TWO_TILE)
	for cell: Vector2i in blocks_fire_cells:
		set_cell(cell, 0, WALL_TILE, WALL_ALTERNATIVE)
