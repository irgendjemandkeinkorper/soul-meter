class_name IsometricBlockout
extends TileMapLayer
## Runtime-built project-owned graybox atlas. The map is a real isometric
## TileMapLayer (64x32 cells), giving later environment art a stable seam.

enum GroundStyle { DOM, DORTHKOR, GROVE }
enum RoadAxis { NONE, X, Y, CROSS }

const TILE_SIZE := Vector2i(64, 32)
const ATLAS := preload("res://assets/blockout/isometric_tiles.svg")

@export var map_size := Vector2i(25, 25)
@export var ground_style: GroundStyle = GroundStyle.DOM
@export var road_axis: RoadAxis = RoadAxis.CROSS
@export_range(0, 4) var road_half_width := 1


func _ready() -> void:
	z_index = -10
	_build_tileset()
	_fill_map()


func _build_tileset() -> void:
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tileset.tile_size = TILE_SIZE
	var source := TileSetAtlasSource.new()
	source.texture = ATLAS
	source.texture_region_size = TILE_SIZE
	for atlas_x in 4:
		source.create_tile(Vector2i(atlas_x, 0))
	tileset.add_source(source, 0)
	tile_set = tileset


func _fill_map() -> void:
	var base_tile := 0
	if ground_style == GroundStyle.DORTHKOR:
		base_tile = 3
	elif ground_style == GroundStyle.GROVE:
		base_tile = 2
	var center := map_size / 2
	for y in map_size.y:
		for x in map_size.x:
			var tile := base_tile
			var on_x_road := (
				road_axis in [RoadAxis.X, RoadAxis.CROSS] and absi(y - center.y) <= road_half_width
			)
			var on_y_road := (
				road_axis in [RoadAxis.Y, RoadAxis.CROSS] and absi(x - center.x) <= road_half_width
			)
			if on_x_road or on_y_road:
				tile = 1
			set_cell(Vector2i(x, y), 0, Vector2i(tile, 0), 0)
