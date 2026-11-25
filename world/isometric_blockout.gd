class_name IsometricBlockout
extends TileMapLayer
## Real generated isometric ground. The public script/class name stays stable
## for the existing world scenes, but the runtime graybox atlas is gone.

enum GroundStyle { DOM, DORTHKOR, GROVE }
enum RoadAxis { NONE, X, Y, CROSS }

const TILE_SIZE := Vector2i(64, 32)
const GROUND_TILESET := preload("res://assets/generated/sprites/ground/ground_tileset.tres")
const TILE_GRASS := Vector2i(0, 0)
const TILE_DIRT := Vector2i(1, 0)
const TILE_STONE := Vector2i(2, 0)
const TILE_ROAD := Vector2i(3, 0)

@export var map_size := Vector2i(25, 25)
## The first cell filled. A map whose art reaches above or left of the layer's origin starts
## its ground there instead of moving the layer, so every existing cell keeps its coordinates.
@export var cell_origin := Vector2i.ZERO
@export var ground_style: GroundStyle = GroundStyle.DOM
@export var road_axis: RoadAxis = RoadAxis.CROSS
@export_range(0, 4) var road_half_width := 1


func _ready() -> void:
	z_index = -10
	tile_set = GROUND_TILESET
	_fill_map()


func _fill_map() -> void:
	var base_tile := TILE_GRASS
	if ground_style == GroundStyle.DORTHKOR:
		base_tile = TILE_STONE
	elif ground_style == GroundStyle.GROVE:
		base_tile = TILE_DIRT
	var center := cell_origin + map_size / 2
	for y in range(cell_origin.y, cell_origin.y + map_size.y):
		for x in range(cell_origin.x, cell_origin.x + map_size.x):
			var tile := base_tile
			var on_x_road := (
				road_axis in [RoadAxis.X, RoadAxis.CROSS] and absi(y - center.y) <= road_half_width
			)
			var on_y_road := (
				road_axis in [RoadAxis.Y, RoadAxis.CROSS] and absi(x - center.x) <= road_half_width
			)
			if on_x_road or on_y_road:
				tile = TILE_ROAD
			set_cell(Vector2i(x, y), 0, tile, 0)


## The cells `_fill_map()` covers, before or after it runs.
func cell_rect() -> Rect2i:
	return Rect2i(cell_origin, map_size)
