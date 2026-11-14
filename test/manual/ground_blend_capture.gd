extends Node
## Rendered evidence for the ground blend (2026-11-03, item 35, world/ground_blend.gd): each map
## with ground art, framed on its painted backdrop, as the game draws it (`after`) and with the
## blend taken off (`before`), plus a close crop of each frame's busiest ground.
##
## Not a gdUnit suite: it is a temporary autoload, the recipe of the blocking capture.
## Run under Xvfb (not headless) from the repository root:
##   cp project.godot /tmp/project.godot.bak
##   sed -i '/^Pandora=/a GroundBlendCapture="*res://test/manual/ground_blend_capture.gd"' \
##     project.godot
##   XDG_DATA_HOME="$(mktemp -d)" SOUL_METER_GROUND_CAPTURE_DIR="$PWD/docs/qa/<dir>" \
##     xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT_BIN" --path . --resolution 1920x1080
##   cp /tmp/project.godot.bak project.godot
## Prints GROUND-CAPTURE: ok|FAILED lines; judge those, not the exit code.

const CAPTURE_ENV := "SOUL_METER_GROUND_CAPTURE_DIR"
const MAPS: Array[String] = [
	"res://world/hollowmere.tscn",
	"res://world/long_verge.tscn",
	"res://world/kesselford.tscn",
	"res://world/ashlaren.tscn",
	"res://world/dorthkor_road.tscn",
	"res://world/starting_town.tscn",
	"res://world/wound_lip.tscn",
]

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
	for scene_path: String in MAPS:
		ok = await _capture(scene_path) and ok
	_log.append("GROUND-CAPTURE: %s" % ("ok" if ok else "FAILED"))
	print("\n".join(_log))
	var file := FileAccess.open(_dir.path_join("ground-capture.log"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
	get_tree().quit(0 if ok else 1)


func _capture(scene_path: String) -> bool:
	var scene := (load(scene_path) as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	for i in 3:
		await get_tree().process_frame
	for hud: Node in scene.find_children("*", "CanvasLayer", true, false):
		(hud as CanvasLayer).visible = false
	var name := scene_path.get_file().get_basename()
	var sprites: Array[Sprite2D] = []
	var bounds := Rect2()
	for layer: Node in scene.find_children(GroundBlend.LAYER, "Node2D", true, false):
		for child: Node in layer.get_children():
			var sprite := child as Sprite2D
			if sprite != null and sprite.material != null:
				sprites.append(sprite)
				var box := sprite.global_transform * sprite.get_rect()
				bounds = box if bounds.size == Vector2.ZERO else bounds.merge(box)
	var backdrop := scene.find_child(GroundBlend.BACKDROP, true, false) as Sprite2D
	var frame := bounds
	if backdrop != null:
		frame = backdrop.global_transform * backdrop.get_rect()
	elif frame.size == Vector2.ZERO:
		frame = Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var camera := Camera2D.new()
	scene.add_child(camera)
	var view := Vector2(get_viewport().get_visible_rect().size)
	var zoom := minf(view.x / frame.size.x, view.y / frame.size.y)
	camera.zoom = Vector2(zoom, zoom)
	camera.global_position = frame.get_center()
	camera.make_current()
	var ok := await _save("%s-after" % name)
	var materials: Array[Material] = []
	for sprite: Sprite2D in sprites:
		materials.append(sprite.material)
		sprite.material = null
	ok = await _save("%s-before" % name) and ok
	for index in sprites.size():
		sprites[index].material = materials[index]
	_log.append("GROUND-CAPTURE: %s %s blended=%d" % ["ok" if ok else "FAILED", name, sprites.size()])
	scene.queue_free()
	await get_tree().process_frame
	return ok


func _save(stem: String) -> bool:
	for i in 6:
		await get_tree().process_frame
	var out := _dir.path_join("%s.png" % stem)
	return get_viewport().get_texture().get_image().save_png(out) == OK
