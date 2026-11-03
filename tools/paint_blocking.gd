extends SceneTree
## Paints each map's blocking layer from the solid bodies placed on it (`SolidFootprints`).
##
##   godot --headless --path . --script res://tools/paint_blocking.gd
##   godot --headless --path . --script res://tools/paint_blocking.gd -- --check
##
## For every scene in _footprints.PAINTED_MAPS it replaces the layer's `tile_map_data` line
## in the .tscn and touches nothing else in the file. `--check` writes nothing and lists the maps
## whose paint is out of date. Run it after moving, adding or removing a solid on one of those
## maps; `test_blocking_paint` fails until you do. Judge the printed lines, not the exit code: a
## headless tool run here can abort on exit (docs/performance-benchmark.md).

const TILE_SOURCE := 0
const TILE_ATLAS := Vector2i.ZERO
## Loaded at runtime, never preloaded: map scripts name autoloads (GameState), which do not exist
## yet when a `--script` harness is compiled (as in tools/populated_field_benchmark.gd).
const FOOTPRINTS_SCRIPT := "res://world/nav/solid_footprints.gd"

var _footprints: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_footprints = load(FOOTPRINTS_SCRIPT) as GDScript
	var check_only := "--check" in OS.get_cmdline_user_args()
	var stale := 0
	var maps: Dictionary = _footprints.PAINTED_MAPS
	for scene_path: String in maps:
		var layer_path: String = maps[scene_path]
		var result := paint(scene_path, layer_path, not check_only)
		if result.has("error"):
			printerr("PAINT_BLOCKING error %s: %s" % [scene_path, result["error"]])
			stale += 1
			continue
		var changed: bool = result["changed"]
		if changed:
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
	var packed := load(scene_path) as PackedScene
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
	var painted := {}
	for cell: Vector2i in layer.get_used_cells():
		painted[cell] = true
	var changed := painted.size() != cells.size()
	for cell: Vector2i in cells:
		if not painted.has(cell):
			changed = true
	if changed and write:
		# A fresh layer: clearing the loaded one keeps its old cells in the data as erased rows.
		var fresh := TileMapLayer.new()
		fresh.tile_set = layer.tile_set
		for cell: Vector2i in cells:
			fresh.set_cell(cell, TILE_SOURCE, TILE_ATLAS, 0)
		var data := fresh.tile_map_data
		fresh.free()
		var written := data if not cells.is_empty() else PackedByteArray()
		var error := _write_layer_data(scene_path, layer_path, written)
		if error != "":
			root.free()
			return {"error": error}
	root.free()
	return {"cells": cells.size(), "changed": changed}


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
