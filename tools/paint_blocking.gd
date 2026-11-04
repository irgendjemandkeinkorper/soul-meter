extends SceneTree
## Paints each map's blocking layer from the solid bodies placed on it (`SolidFootprints`).
##
##   godot --headless --path . --script res://tools/paint_blocking.gd
##   godot --headless --path . --script res://tools/paint_blocking.gd -- --check
##
## For every scene in _footprints.PAINTED_MAPS it works in two steps:
##   1. Bases (2026-11-03): every prop sprite whose art has a base in `ArtBases` gets that base as
##      its collision: its body's CollisionShape2D takes a ConvexPolygonShape2D, and a sprite
##      with no body gains a `Base` StaticBody2D child. Rectangles nothing uses any more go.
##      Walk-in buildings (`WalkInBuilding`, item 35) get their wall line the same way: a
##      `WallBody` StaticBody2D child holding one ConvexPolygonShape2D per unbroken wall run.
##      The wall cells, less the windows, also go into the map's combat terrain
##      (`blocks_fire_cells`), so a fight's line of fire cannot cross a wall but passes a window.
##   2. Paint: the layer's `tile_map_data` line is rewritten from the solids' cells. A cell inside
##      a walk-in building's footprint takes `BlockingLayer.THIN_TILE` (no walk clearance ring).
## Nothing else in the file changes. `--check` writes nothing and lists the maps whose bases or
## paint are out of date. Run it after moving, adding or removing a prop or a solid on one of
## those maps; `test_blocking_paint` fails until you do. Judge the printed lines, not the exit
## code: a headless tool run here can abort on exit (docs/performance-benchmark.md).

const TILE_SOURCE := 0
const TILE_ATLAS := Vector2i.ZERO
## `BlockingLayer.THIN_TILE`. The tool names no project class at compile time (see
## FOOTPRINTS_SCRIPT); `test_walk_in_wayhouse` checks that the two agree.
const THIN_TILE := 1
## Loaded at runtime, never preloaded: map scripts name autoloads (GameState), which do not exist
## yet when a `--script` harness is compiled (as in tools/populated_field_benchmark.gd).
const FOOTPRINTS_SCRIPT := "res://world/nav/solid_footprints.gd"
const BASES_SCRIPT := "res://world/nav/art_bases.gd"
const WALK_IN_SCRIPT := "res://world/buildings/walk_in_building.gd"
const SHAPE_NODE := "CollisionShape2D"
const TERRAIN_NODE := "Terrain"
## CombatTerrainLayer.blocks_fire_cells.
const FIRE_CELLS := "blocks_fire_cells"

var _footprints: GDScript
var _bases: GDScript
var _walk_in: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_footprints = load(FOOTPRINTS_SCRIPT) as GDScript
	_bases = load(BASES_SCRIPT) as GDScript
	_walk_in = load(WALK_IN_SCRIPT) as GDScript
	var check_only := "--check" in OS.get_cmdline_user_args()
	var stale := 0
	var maps: Dictionary = _footprints.PAINTED_MAPS
	for scene_path: String in maps:
		var layer_path: String = maps[scene_path]
		var shaped := shape_bases(scene_path, not check_only)
		if shaped.has("error"):
			printerr("PAINT_BLOCKING error %s: %s" % [scene_path, shaped["error"]])
			stale += 1
			continue
		var bases_changed: bool = shaped["changed"]
		print("PAINT_BLOCKING bases %s %s: %d props" % [
			"stale" if bases_changed and check_only else ("shaped" if bases_changed else "current"),
			scene_path, int(shaped["props"]),
		])
		if bases_changed and check_only:
			stale += 1
			continue
		if bases_changed:
			stale += 1
		var result := paint(scene_path, layer_path, not check_only)
		if result.has("error"):
			printerr("PAINT_BLOCKING error %s: %s" % [scene_path, result["error"]])
			stale += 1
			continue
		var changed: bool = result["changed"]
		if changed and not bases_changed:
			stale += 1
		print("PAINT_BLOCKING %s %s: %d cells" % [
			"stale" if changed and check_only else ("painted" if changed else "current"),
			scene_path, int(result["cells"]),
		])
	print("PAINT_BLOCKING done: %d %s" % [stale, "stale" if check_only else "changed"])
	quit(1 if check_only and stale > 0 else 0)


## Computes the map's cells and, when `write` is set and they differ from the paint, rewrites the
## layer's tile_map_data line. Returns {"cells": count, "changed": bool} or {"error": text}.
func paint(scene_path: String, layer_path: String, write: bool) -> Dictionary:
	var packed := _load_fresh(scene_path)
	if packed == null:
		return {"error": "cannot load"}
	var root := packed.instantiate()
	var ground: TileMapLayer = _footprints.find_ground(root)
	var layer := root.get_node_or_null(layer_path) as TileMapLayer
	if ground == null or layer == null:
		root.free()
		return {"error": "no %s or no %s" % [_footprints.GROUND_NAME, layer_path]}
	var ground_xform: Transform2D = _footprints.transform_in(ground, root)
	var layer_xform: Transform2D = _footprints.transform_in(layer, root)
	if not layer_xform.is_equal_approx(ground_xform):
		root.free()
		return {"error": "%s does not share the ground's transform" % layer_path}
	var found: Dictionary = _footprints.ground_cells(root, ground)
	var cells: Array = found.keys()
	cells.sort()
	var thin := thin_cells(root, cells)
	var painted := {}
	for cell: Vector2i in layer.get_used_cells():
		painted[cell] = layer.get_cell_alternative_tile(cell)
	var changed := painted.size() != cells.size()
	for cell: Vector2i in cells:
		var tile := THIN_TILE if thin.has(cell) else 0
		if not painted.has(cell) or int(painted[cell]) != tile:
			changed = true
	if changed and write:
		# A fresh layer: clearing the loaded one keeps its old cells in the data as erased rows.
		var fresh := TileMapLayer.new()
		fresh.tile_set = layer.tile_set
		for cell: Vector2i in cells:
			fresh.set_cell(cell, TILE_SOURCE, TILE_ATLAS, THIN_TILE if thin.has(cell) else 0)
		var data := fresh.tile_map_data
		fresh.free()
		var written := data if not cells.is_empty() else PackedByteArray()
		var error := _write_layer_data(scene_path, layer_path, written)
		if error != "":
			root.free()
			return {"error": error}
	root.free()
	return {"cells": cells.size(), "changed": changed}


## Writes each based prop's art base into the scene (step 1). Returns {"props": count,
## "changed": bool} or {"error": text}.
func shape_bases(scene_path: String, write: bool) -> Dictionary:
	var packed := _load_fresh(scene_path)
	if packed == null:
		return {"error": "cannot load"}
	var root := packed.instantiate()
	var text := FileAccess.get_file_as_string(scene_path)
	var scene := SceneText.new(text)
	var sprites: Array = _bases.based_sprites(root)
	for sprite: Sprite2D in sprites:
		var error := _shape_one(scene, root, sprite)
		if error != "":
			root.free()
			return {"error": error}
	var buildings := walk_in_buildings(root)
	for building: Node2D in buildings:
		var error := _shape_walls(scene, root, building)
		if error != "":
			root.free()
			return {"error": error}
	var fire_error := _mark_fire_walls(scene, root, buildings)
	if fire_error != "":
		root.free()
		return {"error": fire_error}
	root.free()
	scene.drop_unused_sub_resources()
	var updated := scene.to_text()
	var changed := updated != text
	if changed and write:
		var file := FileAccess.open(scene_path, FileAccess.WRITE)
		if file == null:
			return {"error": "cannot write %s" % scene_path}
		file.store_string(updated)
		file.close()
	return {"props": sprites.size() + buildings.size(), "changed": changed}


## The cells of `cells` that lie inside a walk-in building's footprint: its walls and furniture,
## painted as thin solids.
func thin_cells(root: Node, cells: Array) -> Dictionary:
	var thin := {}
	for building: Node2D in walk_in_buildings(root):
		var origin: Vector2i = building.get("origin_cell")
		var size: Vector2i = building.get("cells")
		var footprint := Rect2i(origin, size)
		for cell: Vector2i in cells:
			if footprint.has_point(cell):
				thin[cell] = true
	return thin


## The map's combat terrain layer: the `Terrain` beside the ground, where the battlefield reads
## it (GridBattlefieldModel._read_authored_terrain).
func terrain_layer(root: Node) -> TileMapLayer:
	var ground: TileMapLayer = _footprints.find_ground(root)
	if ground == null or ground.get_parent() == null:
		return null
	return ground.get_parent().find_child(TERRAIN_NODE, true, false) as TileMapLayer


## Every walk-in cell that stops a shot (walls less windows), sorted: what the terrain's
## `blocks_fire_cells` must hold.
func fire_wall_cells(buildings: Array[Node2D]) -> Array[Vector2i]:
	var found := {}
	for building: Node2D in buildings:
		for cell: Vector2i in building.call("blocks_fire_cells"):
			found[cell] = true
	var cells: Array[Vector2i] = []
	cells.assign(found.keys())
	cells.sort()
	return cells


func _mark_fire_walls(scene: SceneText, root: Node, buildings: Array[Node2D]) -> String:
	var terrain := terrain_layer(root)
	if terrain == null:
		return "" if buildings.is_empty() else "no %s layer for the walk-in walls" % TERRAIN_NODE
	var path := str(root.get_path_to(terrain))
	if scene.find_node(path) < 0:
		return "" if buildings.is_empty() else "%s is inside an instanced scene" % path
	var cells := fire_wall_cells(buildings)
	if cells.is_empty():
		scene.remove_property(path, FIRE_CELLS)
		return ""
	var parts := PackedStringArray()
	for cell: Vector2i in cells:
		parts.append("Vector2i(%d, %d)" % [cell.x, cell.y])
	scene.set_property(path, FIRE_CELLS, "Array[Vector2i]([%s])" % ", ".join(parts))
	return ""


## Every walk-in building under `root` (nodes running `WALK_IN_SCRIPT`).
func walk_in_buildings(root: Node) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node: Node in root.find_children("*", "Node2D", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path == WALK_IN_SCRIPT:
			found.append(node as Node2D)
	return found


## The building's wall line as its `WallBody` shapes, in the building's own space: one convex
## strip per unbroken run, from `WalkInBuilding.wall_polygons()` bound to the scene's ground.
func wall_polygons_in_scene(root: Node, building: Node2D) -> Array:
	var ground: TileMapLayer = _footprints.find_ground(root)
	if ground == null:
		return []
	var to_building: Transform2D = _footprints.transform_in(building, root).affine_inverse()
	building.call("bind", ground, to_building * _footprints.transform_in(ground, root))
	return building.call("wall_polygons")


func _shape_walls(scene: SceneText, root: Node, building: Node2D) -> String:
	var building_path := str(root.get_path_to(building))
	if scene.find_node(building_path) < 0:
		return "%s is inside an instanced scene; give its walls in that scene" % building_path
	var polygons := wall_polygons_in_scene(root, building)
	if polygons.is_empty():
		return "%s has no ground to stand its walls on" % building_path
	var wall_body: String = _walk_in.get_script_constant_map()["WALL_BODY"]
	var holder := building_path + "/" + wall_body
	scene.ensure_node(holder, "StaticBody2D", building_path)
	var names: Array[String] = []
	for index in polygons.size():
		names.append(SHAPE_NODE if index == 0 else "%s%d" % [SHAPE_NODE, index + 1])
	var existing := building.get_node_or_null(wall_body)
	if existing != null:
		for child: Node in existing.get_children():
			if not String(child.name) in names:
				scene.remove_node(holder + "/" + String(child.name))
	var previous := holder
	for index in polygons.size():
		var shape_path := holder + "/" + names[index]
		var id := "wall_" + holder.replace("/", "_").validate_node_name().replace(" ", "_")
		if index > 0:
			id += "_%d" % (index + 1)
		scene.set_sub_resource(id, "ConvexPolygonShape2D", [
			"points = PackedVector2Array(%s)" % _format_points(polygons[index]),
		])
		scene.ensure_node(shape_path, SHAPE_NODE, previous)
		scene.set_property(shape_path, "shape", 'SubResource("%s")' % id)
		previous = shape_path
	return ""


func _shape_one(scene: SceneText, root: Node, sprite: Sprite2D) -> String:
	var sprite_path := str(root.get_path_to(sprite))
	if scene.find_node(sprite_path) < 0:
		return "%s is inside an instanced scene; give its base in that scene" % sprite_path
	var body: StaticBody2D = _bases.body_of(sprite)
	var holder := ""
	if body != null:
		holder = str(root.get_path_to(body))
	else:
		holder = sprite_path + "/" + _bases.BASE_BODY
		scene.ensure_node(holder, "StaticBody2D", sprite_path)
	var polygons: Array = _bases.polygons_for(sprite)
	var names: Array[String] = []
	for index in polygons.size():
		names.append(SHAPE_NODE if index == 0 else "%s%d" % [SHAPE_NODE, index + 1])
	if body != null:
		for child: Node in body.get_children():
			var is_shape := child is CollisionShape2D or child is CollisionPolygon2D
			if is_shape and not String(child.name) in names:
				return "%s has a shape %s the base would leave behind" % [holder, child.name]
	var previous := holder
	for index in polygons.size():
		var shape_path := holder + "/" + names[index]
		var id := "base_" + holder.replace("/", "_").validate_node_name().replace(" ", "_")
		if index > 0:
			id += "_%d" % (index + 1)
		scene.set_sub_resource(id, "ConvexPolygonShape2D", [
			"points = PackedVector2Array(%s)" % _format_points(polygons[index]),
		])
		scene.ensure_node(shape_path, SHAPE_NODE, previous)
		scene.set_property(shape_path, "shape", 'SubResource("%s")' % id)
		for key: String in ["position", "rotation", "scale", "skew"]:
			scene.remove_property(shape_path, key)
		previous = shape_path
	return ""


static func _format_points(points: PackedVector2Array) -> String:
	var parts := PackedStringArray()
	for point: Vector2 in points:
		parts.append(_format_number(point.x))
		parts.append(_format_number(point.y))
	return ", ".join(parts)


## As Godot writes a float into a scene: 12 rather than 12.0, so an editor save changes nothing.
static func _format_number(value: float) -> String:
	var snapped := snappedf(value, 0.01)
	if is_equal_approx(snapped, roundf(snapped)):
		return str(int(roundf(snapped)))
	return str(snapped)


## The scene as stored now, bypassing the resource cache (step 1 may just have rewritten it).
static func _load_fresh(scene_path: String) -> PackedScene:
	return ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene


## Replaces (or adds, or with empty data removes) the `tile_map_data` line in the layer's node
## block. The block must already exist in this scene file.
static func _write_layer_data(
	scene_path: String, layer_path: String, data: PackedByteArray
) -> String:
	var text := FileAccess.get_file_as_string(scene_path)
	if text == "":
		return "cannot read %s" % scene_path
	var name := layer_path.get_file()
	var parent := "." if not "/" in layer_path else layer_path.get_base_dir()
	var lines := text.split("\n")
	var start := -1
	for index in lines.size():
		var line := lines[index]
		if line.begins_with('[node name="%s"' % name) and ('parent="%s"' % parent) in line:
			start = index
			break
	if start < 0:
		return "no node block for %s" % layer_path
	var finish := start + 1
	while finish < lines.size() and not lines[finish].begins_with("["):
		finish += 1
	var block: Array[String] = []
	for index in range(start + 1, finish):
		if not lines[index].begins_with("tile_map_data = "):
			block.append(lines[index])
	if not data.is_empty():
		var entry := 'tile_map_data = PackedByteArray("%s")' % Marshalls.raw_to_base64(data)
		var at := block.size()
		for index in block.size():
			if block[index].begins_with("tile_set = ") or block[index].begins_with("script = "):
				at = index
				break
		# Keep the blank line that ends the block after the new property.
		while at > 0 and block[at - 1] == "":
			at -= 1
		block.insert(at, entry)
	var out: Array[String] = []
	for index in range(0, start + 1):
		out.append(lines[index])
	out.append_array(block)
	for index in range(finish, lines.size()):
		out.append(lines[index])
	var file := FileAccess.open(scene_path, FileAccess.WRITE)
	if file == null:
		return "cannot write %s" % scene_path
	file.store_string("\n".join(out))
	file.close()
	return ""


## A .tscn file as its header and sections ([ext_resource], [sub_resource], [node], ...), each
## with the lines that follow it. Edits keep every untouched line byte for byte.
class SceneText:
	const SECTION_HEADS: Array[String] = [
		"[ext_resource", "[sub_resource", "[node", "[connection", "[editable", "[resource",
	]

	var _header: Array[String] = []
	var _sections: Array[Dictionary] = []
	var _resource_count := 0

	func _init(text: String) -> void:
		var current: Dictionary = {}
		for line: String in text.split("\n"):
			if _is_head(line):
				current = {"head": line, "body": [] as Array[String]}
				_sections.append(current)
			elif current.is_empty():
				_header.append(line)
			else:
				(current["body"] as Array[String]).append(line)
		_resource_count = _count_resources()

	func to_text() -> String:
		var lines: Array[String] = []
		lines.append_array(_header)
		var added := _count_resources() - _resource_count
		if added != 0 and not lines.is_empty():
			var steps := RegEx.create_from_string("load_steps=(\\d+)")
			var found := steps.search(lines[0])
			if found != null:
				lines[0] = lines[0].replace(
					found.get_string(), "load_steps=%d" % (int(found.get_string(1)) + added)
				)
		for section: Dictionary in _sections:
			lines.append(section["head"])
			lines.append_array(section["body"])
		return "\n".join(lines)

	## The index of the node section at `path` (from the scene root), or -1.
	func find_node(path: String) -> int:
		for index in _sections.size():
			if _node_path(_sections[index]["head"]) == path:
				return index
		return -1

	## Removes the node section at `path` and every section below it.
	func remove_node(path: String) -> void:
		for index in range(_sections.size() - 1, -1, -1):
			var at := _node_path(_sections[index]["head"])
			if at == path or at.begins_with(path + "/"):
				_sections.remove_at(index)

	## Adds an empty node section right after `after`'s section unless `path` has one.
	func ensure_node(path: String, type: String, after: String) -> void:
		if find_node(path) >= 0:
			return
		var parent := path.get_base_dir()
		var head := '[node name="%s" type="%s" parent="%s"]' % [path.get_file(), type, parent]
		var at := find_node(after)
		_sections.insert(at + 1, {"head": head, "body": [""] as Array[String]})

	func set_property(path: String, key: String, value: String) -> void:
		var body: Array[String] = _sections[find_node(path)]["body"]
		var line := "%s = %s" % [key, value]
		for index in body.size():
			if body[index].begins_with(key + " = "):
				body[index] = line
				return
		var at := body.size()
		while at > 0 and body[at - 1] == "":
			at -= 1
		body.insert(at, line)

	func remove_property(path: String, key: String) -> void:
		var body: Array[String] = _sections[find_node(path)]["body"]
		for index in range(body.size() - 1, -1, -1):
			if body[index].begins_with(key + " = "):
				body.remove_at(index)

	## Sets a sub-resource's properties, adding it after the last resource section if new.
	func set_sub_resource(id: String, type: String, properties: Array[String]) -> void:
		var body: Array[String] = properties.duplicate()
		body.append("")
		var last_resource := -1
		for index in _sections.size():
			var head: String = _sections[index]["head"]
			if head.begins_with("[sub_resource") and ('id="%s"' % id) in head:
				_sections[index] = {"head": head, "body": body}
				return
			if head.begins_with("[ext_resource") or head.begins_with("[sub_resource"):
				last_resource = index
		var new_head := '[sub_resource type="%s" id="%s"]' % [type, id]
		_sections.insert(last_resource + 1, {"head": new_head, "body": body})

	## Removes sub-resources no section refers to (a replaced rectangle).
	func drop_unused_sub_resources() -> void:
		var dropped := true
		while dropped:
			dropped = false
			for index in range(_sections.size() - 1, -1, -1):
				var head: String = _sections[index]["head"]
				if not head.begins_with("[sub_resource"):
					continue
				var id := head.get_slice('id="', 1).get_slice('"', 0)
				if not _is_referenced('SubResource("%s")' % id, index):
					_sections.remove_at(index)
					dropped = true

	func _is_referenced(token: String, skip: int) -> bool:
		for index in _sections.size():
			if index == skip:
				continue
			var section: Dictionary = _sections[index]
			if token in section["head"]:
				return true
			for line: String in section["body"]:
				if token in line:
					return true
		return false

	func _count_resources() -> int:
		var count := 0
		for section: Dictionary in _sections:
			var head: String = section["head"]
			if head.begins_with("[ext_resource") or head.begins_with("[sub_resource"):
				count += 1
		return count

	static func _is_head(line: String) -> bool:
		for prefix: String in SECTION_HEADS:
			if line.begins_with(prefix):
				return true
		return false

	static func _node_path(head: String) -> String:
		if not head.begins_with("[node"):
			return ""
		var name := head.get_slice('name="', 1).get_slice('"', 0)
		if not 'parent="' in head:
			return "."
		var parent := head.get_slice('parent="', 1).get_slice('"', 0)
		return name if parent == "." else parent + "/" + name
