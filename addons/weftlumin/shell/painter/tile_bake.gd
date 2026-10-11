class_name WeftluminTileBake
extends RefCounted
## The bake side of the data-layer painters (`docs/architecture-in-game-editor.md` §4.4, §4.6.2,
## §4.6.3): scene document ops applied to a `.tscn` **text**, never to the running scene.
##
## A bake opens the scene text (`TscnDocument`), decodes each painted layer into an out-of-tree
## `TileMapLayer` (or the exported cell lists a list-stored layer is authored in), replays the
## log's effective `paint_cells` stream on a fresh bus — which verifies every recorded
## `pre_state` against the file first, so a log recorded against a differently scaled layer
## refuses rather than painting the wrong cells — and writes the result back surgically:
## `tile_map_data` through `TscnDocument.set_packed_bytes()` in the file's existing style, cell
## lists and transforms through `set_property()`. Untouched lines stay byte-identical.
##
## `normalize_blocking_scale` is **bake-only**: it exists only on this bus, so it can rewrite a
## scene file for review but can never run against a live scene. It re-authors a scaled
## `Blocking` layer at scale 1 in its ground's lattice, sampling exactly the points
## `IsoGrid._bake_obstacles()` samples when it projects a transformed layer, so the navigation
## grid built from the result is the one the scaled layer produced.

const KIND := WeftluminTilePainter.KIND
const OP_PAINT := WeftluminTilePainter.OP_PAINT
const OP_NORMALIZE := "normalize_blocking_scale"
const TILE_OPS: Array[String] = [OP_PAINT, OP_NORMALIZE]

var document: TscnDocument = null
var bus: WeftluminCommandBus = null
## One entry per `normalize_blocking_scale` applied: what changed, for the reviewer.
var reports: Array[Dictionary] = []

## node path -> {store, layer, lists, dirty_lists, position, scale, dirty, transform_dirty}
var _states: Dictionary = {}


## A bake session over `text`. `close()` it when done (it holds out-of-tree layers).
static func open(text: String, source_path: String = "") -> WeftluminTileBake:
	var baker := WeftluminTileBake.new()
	baker.document = TscnDocument.parse(text)
	baker.document.source_path = source_path
	baker.bus = WeftluminCommandBus.new("bake")
	baker.bus.persist_log = false
	baker.bus.register_document_op(KIND, OP_PAINT, baker._capture, baker._apply, baker._revert)
	baker.bus.register_document_op(KIND, OP_NORMALIZE, baker._capture, baker._apply, baker._revert)
	return baker


## Replay the tile ops of a command log (`commands.jsonl` entries, undo/redo bookkeeping
## included) onto `text`. `{allowed, text, applied, skipped_ops, reports, message}`.
static func bake(text: String, entries: Array, source_path: String = "") -> Dictionary:
	var baker := open(text, source_path)
	var stream: Array = []
	var skipped := 0
	for entry: Variant in entries:
		var data: Dictionary = entry as Dictionary if entry is Dictionary else {}
		var op: String = str(data.get("op", ""))
		if op in [WeftluminCommand.OP_UNDO, WeftluminCommand.OP_REDO]:
			stream.append(data)
		elif str(data.get("kind", "")) == KIND and op in TILE_OPS:
			stream.append(data)
		else:
			skipped += 1
	var outcome: Dictionary = baker.bus.replay(stream)
	if bool(outcome.get("allowed", false)):
		var flushed: Dictionary = baker.flush()
		if not bool(flushed["allowed"]):
			outcome = flushed
	outcome["text"] = baker.text() if bool(outcome.get("allowed", false)) else text
	outcome["skipped_ops"] = skipped
	outcome["reports"] = baker.reports.duplicate(true)
	baker.close()
	return outcome


## The bake-only command: re-author `blocking` at scale 1 in `ground`'s cell space. The ground
## layer's tile set is named explicitly because a procedural ground assigns it at runtime, so
## the scene file does not carry it.
static func normalize_command(
	scene_path: String, blocking: String, ground: String, ground_tile_set: String,
	package_name: String = "",
) -> WeftluminCommand:
	return WeftluminCommand.make(
		KIND, OP_NORMALIZE, {"scene": scene_path, "node": blocking},
		{"ground": ground, "ground_tile_set": ground_tile_set}, package_name,
		{"source": "bake", "actor": "owner"},
	)


## Run one command against the document (capturing its pre_state from the file).
func execute(command: WeftluminCommand) -> Dictionary:
	return bus.execute(command)


## Write every decoded layer that changed back into the document.
func flush() -> Dictionary:
	for path: String in _states:
		var state: Dictionary = _states[path]
		if bool(state["dirty"]) and state["layer"] != null:
			if not document.set_packed_bytes(path, "tile_map_data", (state["layer"] as TileMapLayer).tile_map_data):
				return _refusal(document.last_error)
		if bool(state["transform_dirty"]):
			for key: String in ["position", "scale"]:
				if not document.set_property(path, key, var_to_str(state[key])):
					return _refusal(document.last_error)
		for property: String in state["dirty_lists"]:
			if not document.set_property(path, property, var_to_str(state["lists"][property])):
				return _refusal(document.last_error)
		state["dirty"] = false
		state["transform_dirty"] = false
		(state["dirty_lists"] as Dictionary).clear()
	return _allowed()


func text() -> String:
	return document.serialise()


func close() -> void:
	for state: Dictionary in _states.values():
		if state["layer"] != null and is_instance_valid(state["layer"]):
			(state["layer"] as TileMapLayer).free()
	_states.clear()


# --- bus handlers -----------------------------------------------------------------------------


func _capture(command: WeftluminCommand) -> Dictionary:
	var path: String = str(command.target.get("node", ""))
	var state: Dictionary = _state(path, _store_of(command))
	if state.is_empty():
		return {}
	var record: Array = WeftluminTilePainter.transform_record(state["position"], state["scale"])
	if command.op == OP_NORMALIZE:
		return {"transform": record, "cells": (state["layer"] as TileMapLayer).get_used_cells().size()}
	var before: Array = []
	for cell: Vector2i in WeftluminTilePainter.cells_of(command):
		before.append([cell.x, cell.y] + _tile(state, cell))
	return {"transform": record, "cells": before}


func _apply(command: WeftluminCommand) -> Dictionary:
	var path: String = str(command.target.get("node", ""))
	var state: Dictionary = _state(path, _store_of(command))
	if state.is_empty():
		return _blocked(&"scene_boundary", &"paintable_layer", "No paintable layer at %s in the scene file." % path)
	if command.op == OP_NORMALIZE:
		return _normalize(command, path, state)
	var value: Array = command.params.get("tile", []) as Array
	for cell: Vector2i in WeftluminTilePainter.cells_of(command):
		_write(state, cell, value)
	return _allowed()


func _revert(command: WeftluminCommand) -> Dictionary:
	if command.op == OP_NORMALIZE:
		return _blocked(&"history", &"fresh_bake", "normalize_blocking_scale is undone by baking again without it.")
	var state: Dictionary = _state(str(command.target.get("node", "")), _store_of(command))
	for entry: Variant in command.pre_state.get("cells", []):
		var row: Array = entry as Array
		_write(state, Vector2i(int(row[0]), int(row[1])), row.slice(2))
	return _allowed()


# --- normalize_blocking_scale -------------------------------------------------------------------


func _normalize(command: WeftluminCommand, path: String, state: Dictionary) -> Dictionary:
	var ground_path: String = str(command.params.get("ground", ""))
	var blocking_node: Dictionary = _node(path)
	var ground_node: Dictionary = _node(ground_path)
	if ground_node.is_empty():
		return _blocked(&"scene_boundary", &"ground_layer", "No ground layer at %s in the scene file." % ground_path)
	if str(blocking_node["attributes"].get("parent", "")) != str(ground_node["attributes"].get("parent", "")):
		return _blocked(&"transform", &"sibling_layers", "%s and %s must share a parent." % [path, ground_path])
	for section: Dictionary in [blocking_node, ground_node]:
		for key: String in ["rotation", "skew"]:
			if not _property_text(section, key).is_empty():
				return _blocked(&"transform", &"axis_aligned_layer", "A rotated or skewed layer cannot be normalised.")
	var tile_set: TileSet = (state["layer"] as TileMapLayer).tile_set
	var ground_set := load(str(command.params.get("ground_tile_set", ""))) as TileSet
	if tile_set == null or ground_set == null:
		return _blocked(&"tile_set", &"declared_tile_set", "Both layers need a tile set to normalise.")
	if (
		tile_set.tile_size != ground_set.tile_size or tile_set.tile_shape != ground_set.tile_shape
		or tile_set.tile_layout != ground_set.tile_layout
		or tile_set.tile_offset_axis != ground_set.tile_offset_axis
	):
		return _blocked(&"tile_set", &"matching_lattice", "Blocking and ground lattices differ; normalising would move walls.")
	var ground_scale: Vector2 = _vector(ground_node, "scale", Vector2.ONE)
	if not ground_scale.is_equal_approx(Vector2.ONE):
		return _blocked(&"transform", &"unit_scale_ground", "The ground layer is itself scaled.")
	var ground_position: Vector2 = _vector(ground_node, "position", Vector2.ZERO)
	# Sample through the layers' own to_global/to_local, the arithmetic IsoGrid uses, so a point on
	# a lattice edge rounds the same way here as in the grid this must reproduce.
	var old_layer: TileMapLayer = state["layer"]
	old_layer.position = state["position"]
	old_layer.scale = state["scale"]
	var new_layer := TileMapLayer.new()
	new_layer.tile_set = tile_set
	new_layer.position = ground_position
	var half := Vector2(ground_set.tile_size) * 0.5
	# The five points IsoGrid._bake_obstacles() samples per ground cell.
	var samples: Array[Vector2] = [
		Vector2.ZERO, Vector2(-half.x, 0.0), Vector2(half.x, 0.0), Vector2(0.0, -half.y), Vector2(0.0, half.y),
	]
	var candidates := Rect2i()
	var first := true
	for cell: Vector2i in old_layer.get_used_cells():
		for offset: Vector2 in samples:
			var world: Vector2 = old_layer.to_global(old_layer.map_to_local(cell) + offset)
			var reached: Vector2i = new_layer.local_to_map(new_layer.to_local(world))
			candidates = Rect2i(reached, Vector2i.ONE) if first else candidates.expand(reached)
			first = false
	candidates = candidates.grow(2)
	for y: int in range(candidates.position.y, candidates.end.y):
		for x: int in range(candidates.position.x, candidates.end.x):
			var cell := Vector2i(x, y)
			var centre: Vector2 = new_layer.map_to_local(cell)
			for offset: Vector2 in samples:
				var old_cell: Vector2i = old_layer.local_to_map(old_layer.to_local(new_layer.to_global(centre + offset)))
				if old_layer.get_cell_source_id(old_cell) != -1:
					WeftluminTilePainter.write_tile(new_layer, cell, WeftluminTilePainter.read_tile(old_layer, old_cell))
					break
	reports.append({
		"op": OP_NORMALIZE, "node": path, "cells_before": old_layer.get_used_cells().size(),
		"cells_after": new_layer.get_used_cells().size(),
		"scale_before": [state["scale"].x, state["scale"].y],
		"position_before": [state["position"].x, state["position"].y],
		"position_after": [ground_position.x, ground_position.y],
	})
	old_layer.free()
	state["layer"] = new_layer
	state["position"] = ground_position
	state["scale"] = Vector2.ONE
	state["dirty"] = true
	state["transform_dirty"] = true
	return _allowed()


# --- document state ---------------------------------------------------------------------------


func _store_of(command: WeftluminCommand) -> Dictionary:
	if command.op == OP_NORMALIZE:
		return {"kind": WeftluminTilePainter.STORE_TILES}
	return command.params.get("store", {}) as Dictionary


## Decoded state of the layer at `path`, loaded on first use. Empty when the node is missing or
## a command addresses it through a different storage kind than an earlier one did.
func _state(path: String, store: Dictionary) -> Dictionary:
	var kind: String = str(store.get("kind", WeftluminTilePainter.STORE_TILES))
	if _states.has(path):
		var known: Dictionary = _states[path]
		return known if str((known["store"] as Dictionary).get("kind", "")) == kind else {}
	var node: Dictionary = _node(path)
	if node.is_empty():
		return {}
	var state := {
		"store": store.duplicate(true), "layer": null, "lists": {}, "dirty_lists": {},
		"position": _vector(node, "position", Vector2.ZERO), "scale": _vector(node, "scale", Vector2.ONE),
		"dirty": false, "transform_dirty": false,
	}
	if kind == WeftluminTilePainter.STORE_LISTS:
		for property: Variant in (store.get("lists", {}) as Dictionary).values():
			var cells: Array[Vector2i] = []
			var authored: Variant = _value(node, str(property))
			if authored is Array:
				cells.assign(authored)
			state["lists"][str(property)] = cells
	else:
		var layer := TileMapLayer.new()
		var bytes: Variant = _value(node, "tile_map_data")
		if bytes is PackedByteArray:
			layer.tile_map_data = bytes
		layer.tile_set = _ext_resource(node, "tile_set") as TileSet
		state["layer"] = layer
	_states[path] = state
	return state


func _tile(state: Dictionary, cell: Vector2i) -> Array:
	if state["layer"] != null:
		return WeftluminTilePainter.read_tile(state["layer"], cell)
	var found: Array = []
	var store: Dictionary = state["store"]
	var lists: Dictionary = store.get("lists", {}) as Dictionary
	# The layer re-creates tiles list by list, so the last list naming a cell wins.
	for key: Variant in lists:
		if (state["lists"][str(lists[key])] as Array[Vector2i]).has(cell):
			var atlas: PackedStringArray = str(key).split(",")
			found = [int(store.get("source", 0)), int(atlas[0]), int(atlas[1]), 0]
	return found


func _write(state: Dictionary, cell: Vector2i, value: Array) -> void:
	if state["layer"] != null:
		WeftluminTilePainter.write_tile(state["layer"], cell, value)
		state["dirty"] = true
		return
	var target: String = WeftluminTilePainter.list_for(state["store"], value)
	for property: String in state["lists"]:
		var cells: Array[Vector2i] = state["lists"][property]
		if cells.has(cell) and property != target:
			cells.erase(cell)
			state["dirty_lists"][property] = true
	if state["lists"].has(target) and not (state["lists"][target] as Array[Vector2i]).has(cell):
		(state["lists"][target] as Array[Vector2i]).append(cell)
		state["dirty_lists"][target] = true


func _node(path: String) -> Dictionary:
	for node: Dictionary in document.nodes:
		var attributes: Dictionary = node["attributes"]
		var parent: String = str(attributes.get("parent", ""))
		var node_name: String = str(attributes.get("name", ""))
		var node_path: String = "." if not attributes.has("parent") else (node_name if parent == "." else parent + "/" + node_name)
		if node_path == path:
			return node
	return {}


## The value text of a single-line property of `node`, or "" when absent.
static func _property_text(node: Dictionary, key: String) -> String:
	var prefix := RegEx.create_from_string("^[ \\t]*" + key.replace("/", "\\/") + "[ \\t]*=[ \\t]*")
	for line: String in node.get("property_lines", []):
		var found: RegExMatch = prefix.search(line)
		if found != null:
			return line.substr(found.get_end()).strip_edges()
	return ""


## The parsed value of a single-line property, or null when absent.
static func _value(node: Dictionary, key: String) -> Variant:
	var text: String = _property_text(node, key)
	return null if text.is_empty() else str_to_var(text)


static func _vector(node: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _value(node, key)
	return value if value is Vector2 else fallback


func _ext_resource(node: Dictionary, key: String) -> Resource:
	var reference := RegEx.create_from_string('^ExtResource\\(\\s*"([^"]+)"\\s*\\)$').search(_property_text(node, key))
	if reference == null:
		return null
	for resource: Dictionary in document.ext_resources:
		var attributes: Dictionary = resource["attributes"]
		if str(attributes.get("id", "")) == reference.get_string(1):
			var path: String = str(attributes.get("path", ""))
			return load(path) if ResourceLoader.exists(path) else null
	return null


static func _refusal(error: Dictionary) -> Dictionary:
	return _blocked(&"tscn_document", &"writable_scene", "%s: %s" % [error.get("field", ""), error.get("message", "write refused")])


static func _allowed(extra: Dictionary = {}) -> Dictionary:
	var result := {"allowed": true, "blocked_by": &"", "nearest_unblock": &"", "message": ""}
	result.merge(extra, true)
	return result


static func _blocked(by: StringName, unblock: StringName, message: String) -> Dictionary:
	return {"allowed": false, "blocked_by": by, "nearest_unblock": unblock, "message": message}
