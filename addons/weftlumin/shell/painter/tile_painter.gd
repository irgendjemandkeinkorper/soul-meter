class_name WeftluminTilePainter
extends RefCounted
## Paints the invisible data layers same-map combat and navigation read
## (`docs/architecture-in-game-editor.md` §4.6.3): `Blocking` and `Terrain`.
##
## **One stroke, one command.** A press-drag-release gesture becomes one `scene/paint_cells`
## document op on the scene model's bus, so it is one undo step and one log entry. The bus
## captures `pre_state` — the previous tile of every cell the stroke touches, plus the layer's
## transform — from the live layer, which is what lets a bake refuse a log recorded against a
## differently scaled layer (`WeftluminTileBake`).
##
## **Cell space.** Each layer is painted in the cell space of a "space" layer the host names:
## `Blocking` in its own (`local_to_map(to_local(world))`), and `Terrain` in whatever lattice its
## consumer reads its cells in. Brushes never convert coordinates themselves.
##
## **Live walkability.** After every apply, undo and redo the host's grids are rebuilt with
## `IsoGrid.build()` — the same instance the player's click-to-move uses, so a painted wall
## changes where the player can walk at once, and the overlay follows.
##
## **Storage.** A command names how its layer persists, so a bake needs no host knowledge:
## `{"kind": "tiles"}` is the layer's own `tile_map_data`; `{"kind": "lists", "lists":
## {"x,y": "property"}}` is a layer whose cells are authored as exported per-tile cell lists (the
## shape #281 gave `CombatTerrainLayer`). Painting keeps both the tiles and the lists in step.

signal painted(layer_id: StringName)

const KIND := "scene"
const OP_PAINT := "paint_cells"
const STORE_TILES := "tiles"
const STORE_LISTS := "lists"
const SESSION_META := &"weftlumin_tile_painter"

## The live scene the painted layers belong to.
var scene_root: Node = null
var bus: WeftluminCommandBus = null
var shape: WeftluminBrushes.Shape = WeftluminBrushes.Shape.CELL
var active_layer: StringName = &""
## `[source, atlas_x, atlas_y, alternative]`; empty erases.
var tile: Array = []
## Grid rebuilds since this painter was made: one per applied, undone or redone stroke.
var rebuild_count := 0
## `() -> bool`, true while the host's production content (a live battle) owns the grids. A
## rebuild would discard that session's terrain weights, so painting refuses meanwhile.
var production_live: Callable = Callable()

## id -> {node, space, store, values, bounds}
var _layers: Dictionary = {}
## [{grid, ground, blocking, clearance, project, label}]
var _grids: Array[Dictionary] = []
var _stroke: Dictionary = {}


## The painter that belongs to `model`'s scene. A hosted scene keeps one across shell close and
## reopen, because its undo history (on the model's bus) calls back into it.
static func session_for(model: WeftluminSceneModel) -> WeftluminTilePainter:
	var root: Node = model.scene_root
	var painter: WeftluminTilePainter = null
	if is_instance_valid(root) and root.has_meta(SESSION_META):
		painter = root.get_meta(SESSION_META) as WeftluminTilePainter
	if painter == null:
		painter = WeftluminTilePainter.new()
		if is_instance_valid(root):
			root.set_meta(SESSION_META, painter)
	painter.attach(model)
	return painter


## Bind to `model`'s scene and register `paint_cells` on its bus (idempotent).
func attach(model: WeftluminSceneModel) -> void:
	scene_root = model.scene_root
	if model.bus != null and bus != model.bus:
		bus = model.bus
		bus.register_document_op(KIND, OP_PAINT, _capture, _apply, _revert)


## Declare a paintable layer. `space` is the layer whose transform and tile set define the cell
## space (`node` itself for its own). `values` is `[{label, tile}]`; `bounds_ground` limits fills
## and rectangles to the cells covering that layer's used region.
func add_layer(
	id: StringName, node: TileMapLayer, space: TileMapLayer, store: Dictionary,
	values: Array[Dictionary], bounds_ground: TileMapLayer = null
) -> void:
	_layers[id] = {
		"node": node, "space": space, "store": store.duplicate(true), "values": values,
		"bounds": _bounds_in(space, bounds_ground if bounds_ground != null else space),
	}
	if active_layer.is_empty():
		active_layer = id
		tile = (values[0]["tile"] as Array).duplicate() if not values.is_empty() else []


func clear_layers() -> void:
	_layers.clear()
	_grids.clear()
	active_layer = &""
	_stroke.clear()


func layer_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _layers:
		ids.append(id)
	return ids


func layer_values(id: StringName) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	if _layers.has(id):
		values.assign(_layers[id]["values"])
	return values


func layer_node(id: StringName) -> TileMapLayer:
	return _layers[id]["node"] as TileMapLayer if _layers.has(id) else null


func space_layer(id: StringName) -> TileMapLayer:
	return _layers[id]["space"] as TileMapLayer if _layers.has(id) else null


## A grid to `IsoGrid.build()` after every stroke, with the clearance the caller uses it at.
func add_grid(
	grid: IsoGrid, ground: TileMapLayer, blocking: TileMapLayer, clearance: int,
	project: bool, label: String
) -> void:
	_grids.append({
		"grid": grid, "ground": ground, "blocking": blocking, "clearance": clearance,
		"project": project, "label": label,
	})


## `[{grid, clearance, label}]`, in declaration order (the overlay's choices).
func grids() -> Array[Dictionary]:
	return _grids.duplicate()


# --- pointer strokes --------------------------------------------------------------------------


## World position -> the active layer's cell.
func cell_at(world_position: Vector2, id: StringName = active_layer) -> Vector2i:
	var space: TileMapLayer = space_layer(id)
	return space.local_to_map(space.to_local(world_position)) if space != null else Vector2i.ZERO


## The cells a stroke in progress would paint (for the brush preview).
func preview_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if _stroke.is_empty():
		return cells
	if shape == WeftluminBrushes.Shape.CELL:
		for cell: Vector2i in _stroke["cells"]:
			cells.append(cell)
		return cells
	return WeftluminBrushes.shape_cells(shape, _stroke["anchor"], _stroke["current"])


func stroke_active() -> bool:
	return not _stroke.is_empty()


## Press: start a stroke at `world_position`. A fill paints at once.
func press(world_position: Vector2) -> Dictionary:
	_stroke.clear()
	if not _layers.has(active_layer):
		return _blocked(&"layer", &"paintable_layer", "This scene has no paintable layer.")
	var cell: Vector2i = cell_at(world_position)
	if shape == WeftluminBrushes.Shape.FILL:
		var result: Dictionary = WeftluminBrushes.fill(
			cell, func(at: Vector2i) -> Array: return tile_of(active_layer, at),
			_layers[active_layer]["bounds"],
		)
		if bool(result["truncated"]):
			return _blocked(
				&"fill", &"bounded_region",
				"Fill would exceed %d cells; paint a boundary first." % WeftluminBrushes.FILL_LIMIT,
			)
		var cells: Array[Vector2i] = []
		cells.assign(result["cells"])
		return paint(active_layer, cells, tile)
	_stroke = {"anchor": cell, "current": cell, "cells": {cell: true}}
	return _allowed()


## Drag: extend the stroke. A cell brush leaves a gap-free trail; rect and line re-shape.
func drag(world_position: Vector2) -> void:
	if _stroke.is_empty():
		return
	var cell: Vector2i = cell_at(world_position)
	if shape == WeftluminBrushes.Shape.CELL:
		for step: Vector2i in WeftluminBrushes.line(_stroke["current"], cell):
			(_stroke["cells"] as Dictionary)[step] = true
	_stroke["current"] = cell


## Release: commit the stroke as one `paint_cells` command.
func release() -> Dictionary:
	if _stroke.is_empty():
		return _allowed()
	var cells: Array[Vector2i] = preview_cells()
	_stroke.clear()
	return paint(active_layer, cells, tile)


func cancel() -> void:
	_stroke.clear()


# --- commands ---------------------------------------------------------------------------------


## Paint `cells` of layer `id` with `with_tile` (`[]` erases) as one command. Cells that already
## hold that tile are left out; a stroke that changes nothing writes no command.
func paint(id: StringName, cells: Array[Vector2i], with_tile: Array) -> Dictionary:
	if not _layers.has(id):
		return _blocked(&"layer", &"paintable_layer", "No paintable layer %s." % id)
	if bus == null or not is_instance_valid(scene_root):
		return _blocked(&"scene_boundary", &"edited_scene", "No edited scene.")
	if production_live.is_valid() and bool(production_live.call()):
		return _blocked(&"production_owner", &"no_live_battle", "End the battle before painting its map.")
	var node: TileMapLayer = _layers[id]["node"]
	var changed: Array = []
	var seen: Dictionary = {}
	for cell: Vector2i in cells:
		if seen.has(cell):
			continue
		seen[cell] = true
		if tile_of(id, cell) != with_tile:
			changed.append([cell.x, cell.y])
	if changed.is_empty():
		return _allowed({"commands": PackedStringArray()})
	if changed.size() > WeftluminBrushes.FILL_LIMIT:
		return _blocked(&"stroke", &"smaller_stroke", "A stroke may change at most %d cells." % WeftluminBrushes.FILL_LIMIT)
	var command := WeftluminCommand.make(
		KIND, OP_PAINT,
		{"scene": scene_root.scene_file_path, "node": String(scene_root.get_path_to(node))},
		{"cells": changed, "tile": with_tile.duplicate(), "store": (_layers[id]["store"] as Dictionary).duplicate(true)},
		bus.package,
	)
	var outcome: Dictionary = bus.execute(command)
	if bool(outcome.get("allowed", false)):
		outcome["commands"] = PackedStringArray([command.id])
	return outcome


## `[source, atlas_x, atlas_y, alternative]` at `cell` of layer `id`, `[]` when empty.
func tile_of(id: StringName, cell: Vector2i) -> Array:
	var node: TileMapLayer = layer_node(id)
	return read_tile(node, cell) if node != null else []


static func read_tile(layer: TileMapLayer, cell: Vector2i) -> Array:
	var source: int = layer.get_cell_source_id(cell)
	if source == -1:
		return []
	var atlas: Vector2i = layer.get_cell_atlas_coords(cell)
	return [source, atlas.x, atlas.y, layer.get_cell_alternative_tile(cell)]


static func write_tile(layer: TileMapLayer, cell: Vector2i, value: Array) -> void:
	if value.is_empty():
		layer.erase_cell(cell)
	else:
		layer.set_cell(cell, int(value[0]), Vector2i(int(value[1]), int(value[2])), int(value[3]))


## `[position.x, position.y, scale.x, scale.y]`: what a bake compares against the scene file.
static func transform_record(position: Vector2, scale: Vector2) -> Array:
	return [position.x, position.y, scale.x, scale.y]


## The cell list a list-stored tile belongs to (`""` for none).
static func list_for(store: Dictionary, value: Array) -> String:
	if value.is_empty():
		return ""
	var lists: Dictionary = store.get("lists", {}) as Dictionary
	return str(lists.get("%d,%d" % [int(value[1]), int(value[2])], ""))


static func cells_of(command: WeftluminCommand) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for entry: Variant in command.params.get("cells", []):
		var pair: Array = entry as Array
		cells.append(Vector2i(int(pair[0]), int(pair[1])))
	return cells


func _capture(command: WeftluminCommand) -> Dictionary:
	var node := _resolve(command)
	if node == null:
		return {}
	var before: Array = []
	for cell: Vector2i in cells_of(command):
		before.append([cell.x, cell.y] + read_tile(node, cell))
	return {"transform": transform_record(node.position, node.scale), "cells": before}


func _apply(command: WeftluminCommand) -> Dictionary:
	var node := _resolve(command)
	if node == null:
		return _blocked(&"scene_boundary", &"node_in_scene", "No paintable layer at %s." % command.target.get("node", ""))
	if node.owner != scene_root and node != scene_root:
		return _blocked(&"scene_ownership", &"scene_owned_node", "%s is not owned by the edited scene." % node.name)
	var value: Array = command.params.get("tile", []) as Array
	var cells: Array[Vector2i] = cells_of(command)
	for cell: Vector2i in cells:
		write_tile(node, cell, value)
	_sync_lists(node, command.params.get("store", {}) as Dictionary, cells)
	_after_edit(node)
	return _allowed()


func _revert(command: WeftluminCommand) -> Dictionary:
	var node := _resolve(command)
	if node == null:
		return _blocked(&"history", &"node_in_scene", "The painted layer is gone.")
	var cells: Array[Vector2i] = []
	for entry: Variant in command.pre_state.get("cells", []):
		var row: Array = entry as Array
		var cell := Vector2i(int(row[0]), int(row[1]))
		cells.append(cell)
		write_tile(node, cell, row.slice(2))
	_sync_lists(node, command.params.get("store", {}) as Dictionary, cells)
	_after_edit(node)
	return _allowed()


## A list-stored layer re-creates its tiles from its lists, so the lists must say what the tiles
## now say: each touched cell leaves every list, then joins the one its tile names.
func _sync_lists(node: TileMapLayer, store: Dictionary, cells: Array[Vector2i]) -> void:
	if str(store.get("kind", "")) != STORE_LISTS:
		return
	var lists: Dictionary = {}
	for property: Variant in (store.get("lists", {}) as Dictionary).values():
		var authored: Variant = node.get(str(property))
		if not authored is Array:
			continue
		var current: Array[Vector2i] = []
		current.assign(authored)
		lists[str(property)] = current
	for cell: Vector2i in cells:
		for property: String in lists:
			(lists[property] as Array[Vector2i]).erase(cell)
		var target: String = list_for(store, read_tile(node, cell))
		if lists.has(target):
			(lists[target] as Array[Vector2i]).append(cell)
	for property: String in lists:
		node.set(property, lists[property])


func _after_edit(node: TileMapLayer) -> void:
	for spec: Dictionary in _grids:
		var grid: IsoGrid = spec["grid"]
		var ground: TileMapLayer = spec["ground"]
		if grid == null or not is_instance_valid(ground) or ground.tile_set == null:
			continue
		var blocking: TileMapLayer = spec["blocking"] if is_instance_valid(spec["blocking"]) else null
		grid.build(ground, blocking, int(spec["clearance"]), bool(spec["project"]))
	rebuild_count += 1
	for id: StringName in _layers:
		if _layers[id]["node"] == node:
			painted.emit(id)
			return
	painted.emit(&"")


func _resolve(command: WeftluminCommand) -> TileMapLayer:
	if not is_instance_valid(scene_root):
		return null
	return scene_root.get_node_or_null(NodePath(str(command.target.get("node", "")))) as TileMapLayer


## Cells of `space` covering `region`'s used cells (both may be the same layer), one cell wider.
static func _bounds_in(space: TileMapLayer, region: TileMapLayer) -> Rect2i:
	if space == null or region == null:
		return Rect2i()
	var used: Rect2i = region.get_used_rect()
	if space == region:
		return used.grow(1)
	var corners: Array[Vector2i] = [
		used.position, Vector2i(used.end.x - 1, used.position.y),
		Vector2i(used.position.x, used.end.y - 1), used.end - Vector2i.ONE,
	]
	var bounds := Rect2i()
	for index: int in corners.size():
		var world: Vector2 = region.to_global(region.map_to_local(corners[index]))
		var cell: Vector2i = space.local_to_map(space.to_local(world))
		bounds = Rect2i(cell, Vector2i.ONE) if index == 0 else bounds.expand(cell)
	return bounds.grow(2)


static func _allowed(extra: Dictionary = {}) -> Dictionary:
	var result := {"allowed": true, "blocked_by": &"", "nearest_unblock": &"", "message": ""}
	result.merge(extra, true)
	return result


static func _blocked(by: StringName, unblock: StringName, message: String) -> Dictionary:
	return {"allowed": false, "blocked_by": by, "nearest_unblock": unblock, "message": message}
