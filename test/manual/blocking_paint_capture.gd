extends Node
## Rendered evidence for the painted map walls (2026-11-03, tools/paint_blocking.gd): each map in
## SolidFootprints.PAINTED_MAPS, framed whole, with its painted blocking cells in red and the
## solid bodies' collision shapes outlined in yellow. The red should sit on the yellow.
##
## Not a gdUnit suite: it is a temporary autoload, the recipe of scripts/check_generated_data.sh.
## Run under Xvfb (not headless) from the repository root:
##   cp project.godot /tmp/project.godot.bak
##   sed -i '/^Pandora=/a BlockingPaintCapture="*res://test/manual/blocking_paint_capture.gd"' project.godot
##   XDG_DATA_HOME="$(mktemp -d)" SOUL_METER_BLOCKING_CAPTURE_DIR="$PWD/docs/qa/<dir>" \
##     xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT_BIN" --path . --resolution 1280x720
##   cp /tmp/project.godot.bak project.godot
## Prints BLOCKING-CAPTURE: ok|FAILED lines; judge those, not the exit code.

const CAPTURE_ENV := "SOUL_METER_BLOCKING_CAPTURE_DIR"
const CELL_FILL := Color(0.9, 0.15, 0.1, 0.55)
const SHAPE_LINE := Color(1.0, 0.85, 0.1, 1.0)

var _dir := ""
var _log: PackedStringArray = []


func _ready() -> void:
	_dir = OS.get_environment(CAPTURE_ENV)
	if _dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	_run.call_deferred()


func _run() -> void:
	var ok := true
	# Let the main menu settle so it does not draw over the first map.
	for i in 30:
		await get_tree().process_frame
	var menu := get_tree().current_scene
	if menu != null:
		if menu is CanvasItem:
			(menu as CanvasItem).hide()
		for layer: Node in menu.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false
	for scene_path: String in SolidFootprints.PAINTED_MAPS:
		ok = await _capture(scene_path, SolidFootprints.PAINTED_MAPS[scene_path]) and ok
	_log.append("BLOCKING-CAPTURE: %s" % ("ok" if ok else "FAILED"))
	print("\n".join(_log))
	var file := FileAccess.open(_dir.path_join("blocking-capture.log"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(0 if ok else 1)


func _capture(scene_path: String, layer_path: String) -> bool:
	var scene := (load(scene_path) as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	for i in 3:
		await get_tree().process_frame
	var layer := scene.get_node_or_null(layer_path) as TileMapLayer
	if layer == null:
		_log.append("BLOCKING-CAPTURE: FAILED %s has no %s" % [scene_path, layer_path])
		scene.queue_free()
		return false
	for hud: Node in scene.find_children("*", "CanvasLayer", true, false):
		(hud as CanvasLayer).visible = false
	var shapes: Array[CollisionShape2D] = []
	var bounds := Rect2()
	for body: Node in scene.find_children("*", "StaticBody2D", true, false):
		if not SolidFootprints.is_solid(body, scene):
			continue
		for child: Node in body.get_children():
			if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
				var shape := child as CollisionShape2D
				shapes.append(shape)
				var size := (shape.shape as RectangleShape2D).size
				var box := shape.global_transform * Rect2(-size * 0.5, size)
				bounds = box if bounds.size == Vector2.ZERO else bounds.merge(box)
	var overlay := Node2D.new()
	overlay.z_index = 4000
	overlay.z_as_relative = false
	scene.add_child(overlay)
	overlay.draw.connect(_draw_overlay.bind(overlay, layer, shapes))
	overlay.queue_redraw()
	var camera := Camera2D.new()
	scene.add_child(camera)
	var view := Vector2(get_viewport().get_visible_rect().size)
	var zoom := minf(view.x / maxf(bounds.size.x, 1.0), view.y / maxf(bounds.size.y, 1.0)) * 0.98
	camera.zoom = Vector2(zoom, zoom)
	camera.global_position = bounds.get_center()
	camera.make_current()
	for i in 6:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var name := scene_path.get_file().get_basename()
	var out := _dir.path_join("walls-%s.png" % name)
	var error := image.save_png(out)
	_log.append("BLOCKING-CAPTURE: %s %s cells=%d solids=%d -> %s" % [
		"ok" if error == OK else "FAILED", name, layer.get_used_cells().size(), shapes.size(),
		out.get_file(),
	])
	scene.queue_free()
	await get_tree().process_frame
	return error == OK


func _draw_overlay(overlay: Node2D, layer: TileMapLayer, shapes: Array[CollisionShape2D]) -> void:
	var half := Vector2(layer.tile_set.tile_size) * 0.5
	for cell: Vector2i in layer.get_used_cells():
		var centre := overlay.to_local(layer.to_global(layer.map_to_local(cell)))
		overlay.draw_colored_polygon(PackedVector2Array([
			centre + Vector2(0, -half.y), centre + Vector2(half.x, 0),
			centre + Vector2(0, half.y), centre + Vector2(-half.x, 0),
		]), CELL_FILL)
	for shape: CollisionShape2D in shapes:
		var size := (shape.shape as RectangleShape2D).size
		var corners := PackedVector2Array()
		for corner: Vector2 in [
			Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5),
			Vector2(-0.5, -0.5),
		]:
			corners.append(overlay.to_local(shape.global_transform * (corner * size)))
		overlay.draw_polyline(corners, SHAPE_LINE, 3.0)
