class_name DressingShadows
extends Node2D
## Soft contact shadows under standing dressing (lived-in maps M1, owner 2026-11-02). One node
## draws them all, between the ground decals (z -2) and the actors (z 0), so nothing floats.
## It reads every visible Sprite2D under the dressing root's `SoftDetails`, `SolidProps` and
## `Props` layers (a nested lived-in scene's included), finds each sprite's contact point
## from its texture's opaque bounds, and draws one squashed soft disc there. Facades and other
## art taller than MAX_HEIGHT_PX are skipped: a building is not a prop on the ground.

const STANDING_LAYERS: Array[StringName] = [&"SoftDetails", &"SolidProps", &"Props"]
const SHADOW_ALPHA := 0.45
## Shadow width as a share of the sprite's opaque width; depth is half the width (2:1 iso).
const WIDTH_SHARE := 0.85
const DEPTH_SHARE := 0.42
## The key light is upper left (art bible Part I), so the shadow leans down and right.
const LIGHT_LEAN := Vector2(0.10, 0.06)
const MAX_HEIGHT_PX := 220.0
const MIN_WIDTH_PX := 10.0

## The node whose dressing layers are shadowed. Defaults to two levels up: a lived-in scene
## sits inside the location's `<Location>Dressing` node.
@export var dressing_root_path: NodePath = ^"../.."

static var _bounds_cache: Dictionary = {}
static var _disc: GradientTexture2D

var _shadows: Array[Rect2] = []
var _refresh_queued := false


func _ready() -> void:
	_queue_refresh()
	var root := get_node_or_null(dressing_root_path)
	if root == null:
		return
	for layer: Node in _layers(root):
		layer.child_entered_tree.connect(_on_layer_changed)
		layer.child_exiting_tree.connect(_on_layer_changed)


func shadow_count() -> int:
	return _shadows.size()


func shadow_rects() -> Array[Rect2]:
	return _shadows.duplicate()


func refresh() -> void:
	_refresh_queued = false
	_shadows.clear()
	var root := get_node_or_null(dressing_root_path)
	if root != null:
		for layer: Node in _layers(root):
			for sprite: Node in layer.find_children("*", "Sprite2D", true, false):
				var rect := _shadow_for(sprite as Sprite2D)
				if rect.size != Vector2.ZERO:
					_shadows.append(rect)
	queue_redraw()


func _draw() -> void:
	var disc := _disc_texture()
	for rect: Rect2 in _shadows:
		draw_texture_rect(disc, rect, false, Color(1, 1, 1, SHADOW_ALPHA))


func _on_layer_changed(_node: Node) -> void:
	_queue_refresh()


func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	refresh.call_deferred()


func _layers(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	for layer_name: StringName in STANDING_LAYERS:
		for node: Node in root.find_children(String(layer_name), "Node2D", true, false):
			found.append(node)
	return found


## The shadow rect in this node's space, or an empty rect when the sprite casts none.
func _shadow_for(sprite: Sprite2D) -> Rect2:
	if sprite == null or sprite.texture == null or not sprite.is_visible_in_tree():
		return Rect2()
	var bounds := opaque_bounds(sprite.texture)
	var local := bounds
	if sprite.region_enabled:
		local = Rect2(Vector2.ZERO, sprite.region_rect.size)
	var top_left := local.position + sprite.offset
	if sprite.centered:
		top_left -= Vector2(sprite.texture.get_size() if not sprite.region_enabled else sprite.region_rect.size) * 0.5
	var transform := sprite.get_global_transform()
	var foot_left := transform * (top_left + Vector2(0.0, local.size.y))
	var foot_right := transform * (top_left + local.size)
	var head := transform * top_left
	var width := absf(foot_right.x - foot_left.x)
	var height := absf(foot_left.y - head.y)
	if width < MIN_WIDTH_PX or height > MAX_HEIGHT_PX:
		return Rect2()
	var size := Vector2(width * WIDTH_SHARE, width * WIDTH_SHARE * DEPTH_SHARE)
	var foot := (foot_left + foot_right) * 0.5 + size * LIGHT_LEAN
	var centre := get_global_transform().affine_inverse() * foot
	return Rect2(centre - size * 0.5, size)


## The texture's opaque bounds, cached per texture. A texture whose pixels cannot be read
## (a headless dummy renderer) is treated as fully opaque.
static func opaque_bounds(texture: Texture2D) -> Rect2:
	var key := texture.resource_path if not texture.resource_path.is_empty() else str(texture.get_rid())
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var bounds := Rect2(Vector2.ZERO, texture.get_size())
	var image := texture.get_image()
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		var used := image.get_used_rect()
		if used.size != Vector2i.ZERO:
			bounds = Rect2(used)
	_bounds_cache[key] = bounds
	return bounds


static func _disc_texture() -> GradientTexture2D:
	if _disc != null:
		return _disc
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 1))
	gradient.set_color(1, Color(0, 0, 0, 0))
	gradient.add_point(0.55, Color(0, 0, 0, 0.55))
	_disc = GradientTexture2D.new()
	_disc.gradient = gradient
	_disc.fill = GradientTexture2D.FILL_RADIAL
	_disc.fill_from = Vector2(0.5, 0.5)
	_disc.fill_to = Vector2(1.0, 0.5)
	_disc.width = 64
	_disc.height = 64
	return _disc
