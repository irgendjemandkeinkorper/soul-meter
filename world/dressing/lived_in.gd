class_name LivedIn
extends Node2D
## Root of a generated lived-in dressing scene (lived-in maps M3, owner 2026-11-02). The scene
## is written by `tools/dress_location.gd`; do not hand-edit it, rerun the tool. The canonical
## map instances it once inside its `<Location>Dressing` node.
##
## Solid greebles block the cells they stand on through the map's own Blocking layer
## (`set_structure_footprint`), so walking, pathfinding and same-map combat agree; waist-high
## ones also mark cover on the combat Terrain layer. Walkable decor blocks nothing.

const BLOCKING_TILE: Array = [0, Vector2i.ZERO, 0]
const CombatTerrainLayerScript := preload("res://world/nav/combat_terrain_layer.gd")

## Ground cells (IsometricGround space) that solid greebles stand on.
@export var blocked_cells: Array[Vector2i] = []
## Ground cells whose solid greeble is waist high or taller: cover in a fight.
@export var cover_cells: Array[Vector2i] = []
## The tool's seed and recipe, for provenance.
@export var dressing_seed: int = 0
@export var source_batch: String = ""


func _ready() -> void:
	# Instanced into a map, this node's owner is the map's root.
	var scene_root: Node = owner if owner != null else _top_ancestor()
	var blocking := scene_root.find_child("Blocking", true, false) as TileMapLayer
	if blocking != null and blocking.has_method("set_structure_footprint") and not blocked_cells.is_empty():
		var tiles := {}
		for cell: Vector2i in blocked_cells:
			if blocking.get_cell_source_id(cell) == -1:
				tiles[cell] = BLOCKING_TILE
		blocking.call("set_structure_footprint", tiles, true)
	var terrain := scene_root.find_child("Terrain", true, false) as TileMapLayer
	if terrain != null and not cover_cells.is_empty():
		for cell: Vector2i in cover_cells:
			if terrain.get_cell_source_id(cell) == -1:
				terrain.set_cell(cell, 0, CombatTerrainLayerScript.COVER_TILE)


func _top_ancestor() -> Node:
	var node: Node = self
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node
