class_name CombatTerrainLayer
extends TileMapLayer
## Hidden map-authored combat metadata. Tile custom data is the runtime source of truth.

const TERRAIN_TILE_SET := preload("res://world/nav/combat_terrain_tiles.tres")
const COVER_TILE := Vector2i(1, 0)
const ELEVATION_ONE_TILE := Vector2i(2, 0)
const ELEVATION_TWO_TILE := Vector2i(3, 0)

@export var cover_cells: Array[Vector2i] = []
@export var elevation_one_cells: Array[Vector2i] = []
@export var elevation_two_cells: Array[Vector2i] = []


func _ready() -> void:
	tile_set = TERRAIN_TILE_SET
	for cell: Vector2i in cover_cells:
		set_cell(cell, 0, COVER_TILE)
	for cell: Vector2i in elevation_one_cells:
		set_cell(cell, 0, ELEVATION_ONE_TILE)
	for cell: Vector2i in elevation_two_cells:
		set_cell(cell, 0, ELEVATION_TWO_TILE)
