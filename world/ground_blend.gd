class_name GroundBlend
extends RefCounted
## Soft blend for a map's flat ground art (owner ruling 2026-11-03, item 35, "Soft blend pass").
## The ground slabs maps are dressed with were drawn as little raised blocks with earth sides;
## laid in rows and grids they read as pasted onto the painted backdrop. Every sprite in a
## `GroundDetails` layer now blends into the backdrop under it:
## - a slab (FACES) shows only its top face, and the face's edge fades out raggedly, so slabs
##   laid to overlap read as one patch;
## - its colour moves toward the backdrop's colour under it (TONE, FLAT_TONE), more so at the
##   fading edge.
## Art drawn standing (`--decorative` files) keeps its colours. Without a `TerrainBackdrop` (Wound
## Lip's ledges over the void) only the slab masks apply. ALL TUNING IS PROVISIONAL.
## A location root calls `apply()` from its _ready (chapter_location.gd, starting_town.gd).

const SHADER := preload("res://world/ground_blend.gdshader")
const LAYER := "GroundDetails"
const BACKDROP := "TerrainBackdrop"
const KEEPS_COLOURS := "--decorative.png"
const WORLD := "res://assets/generated/sprites/world/"

## The top face of each slab in the file's pixels: left, front, right and back corners. Fitted
## from the art's alpha: the left and right corners are the art's outermost opaque columns, the
## back corner its topmost middle pixel, and the front corner mirrors the back (the art is drawn
## steeper than the grid's 2:1). Traced by hand: the straight road, drawn a little turned. Not
## listed: the road memorial (a shrine stands on it) and Wound Lip's ledges (their sides are the
## cliff).
const FACES := {
	WORLD + "loamroot-grove/loamroot-grove--water.png": [
		Vector2(4, 120), Vector2(128, 191), Vector2(251, 120), Vector2(128, 50),
	],
	WORLD + "loamroot-grove/loamroot-grove--grass.png": [
		Vector2(7, 124), Vector2(128, 190), Vector2(248, 124), Vector2(128, 57),
	],
	WORLD + "loamroot-grove/loamroot-grove--mud.png": [
		Vector2(5, 132), Vector2(128, 198), Vector2(251, 132), Vector2(128, 66),
	],
	WORLD + "loamroot-grove/loamroot-grove--shadow.png": [
		Vector2(4, 124), Vector2(126, 193), Vector2(247, 124), Vector2(126, 54),
	],
	WORLD + "loamroot-grove/loamroot-grove--bloom-bed.png": [
		Vector2(5, 130), Vector2(128, 205), Vector2(251, 130), Vector2(128, 54),
	],
	WORLD + "loamroot-grove/loamroot-grove--root-transition.png": [
		Vector2(10, 120), Vector2(128, 194), Vector2(245, 120), Vector2(128, 47),
	],
	# Traced: the road runs corner to corner and the slab is drawn turned off 2:1.
	WORLD + "dorthkor-road/dorthkor-road--straight.png": [
		Vector2(8, 150), Vector2(110, 220), Vector2(248, 124), Vector2(158, 68),
	],
	WORLD + "dorthkor-road/dorthkor-road--broken.png": [
		Vector2(12, 125), Vector2(128, 190), Vector2(243, 125), Vector2(128, 60),
	],
	WORLD + "dorthkor-road/dorthkor-road--grass-shoulder.png": [
		Vector2(4, 115), Vector2(128, 179), Vector2(251, 115), Vector2(128, 51),
	],
	WORLD + "dom-cobble-edge--outer.png": [
		Vector2(5, 111), Vector2(127, 183), Vector2(249, 111), Vector2(127, 39),
	],
}

## PROVISIONAL tuning. The edge is in the file's pixels; the colour reach is in world pixels.
const FEATHER_PX := 12.0
const RAGGED_PX := 9.0
const TONE := 0.3
## Flat ground files (puddles, wet road, paving) take more of the backdrop's colour than slabs.
const FLAT_TONE := 0.45
const REACH_PX := 56.0

## Mean colour of each file's face (or of its opaque pixels), by path.
static var _means: Dictionary = {}


## Gives every blending sprite in the `GroundDetails` layers under `root` the blend. Returns how
## many sprites blend.
static func apply(root: Node) -> int:
	var backdrop := root.find_child(BACKDROP, true, false) as Sprite2D
	var count := 0
	for layer: Node in root.find_children(LAYER, "Node2D", true, false):
		var materials := {}
		for child: Node in layer.get_children():
			var sprite := child as Sprite2D
			if sprite == null or not blends(sprite.texture):
				continue
			var path := sprite.texture.resource_path
			if not materials.has(path):
				materials[path] = material_for(sprite.texture, backdrop)
			sprite.material = materials[path]
			count += 1
	return count


## Whether a ground sprite showing `texture` blends: every slab, and every flat ground file.
static func blends(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var path := texture.resource_path
	return FACES.has(path) or not path.ends_with(KEEPS_COLOURS)


static func material_for(texture: Texture2D, backdrop: Sprite2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var face: Array = FACES.get(texture.resource_path, [])
	material.set_shader_parameter("mask_face", not face.is_empty())
	if not face.is_empty():
		material.set_shader_parameter("face_left", face[0])
		material.set_shader_parameter("face_front", face[1])
		material.set_shader_parameter("face_right", face[2])
		material.set_shader_parameter("face_back", face[3])
	material.set_shader_parameter("feather_px", FEATHER_PX)
	material.set_shader_parameter("ragged_px", RAGGED_PX)
	var has_backdrop := backdrop != null and backdrop.texture != null
	material.set_shader_parameter("has_backdrop", has_backdrop)
	if has_backdrop:
		var to_uv := backdrop_uv(backdrop)
		material.set_shader_parameter("backdrop", backdrop.texture)
		material.set_shader_parameter(
			"backdrop_row0", Vector3(to_uv.x.x, to_uv.y.x, to_uv.origin.x)
		)
		material.set_shader_parameter(
			"backdrop_row1", Vector3(to_uv.x.y, to_uv.y.y, to_uv.origin.y)
		)
		material.set_shader_parameter("reach_px", REACH_PX)
		material.set_shader_parameter("face_mean", mean_colour(texture, face))
		material.set_shader_parameter("tone", FLAT_TONE if face.is_empty() else TONE)
	return material


## World position -> the backdrop texture's UV.
static func backdrop_uv(backdrop: Sprite2D) -> Transform2D:
	var rect := backdrop.get_rect()
	var to_rect := Transform2D(
		Vector2(1.0 / rect.size.x, 0.0), Vector2(0.0, 1.0 / rect.size.y), -rect.position / rect.size
	)
	return to_rect * backdrop.global_transform.affine_inverse()


## The mean colour of the file's face, or of its opaque pixels when it has none. Mid grey when
## the image cannot be read (a headless run keeps no pixels).
static func mean_colour(texture: Texture2D, face: Array) -> Vector3:
	var path := texture.resource_path
	if _means.has(path):
		return _means[path]
	var mean := Vector3(0.5, 0.5, 0.5)
	var image := texture.get_image()
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		var polygon := PackedVector2Array(face)
		var total := Vector3.ZERO
		var samples := 0
		for y in range(0, image.get_height(), 4):
			for x in range(0, image.get_width(), 4):
				var pixel := image.get_pixel(x, y)
				if pixel.a < 0.5:
					continue
				if not polygon.is_empty() and not Geometry2D.is_point_in_polygon(
					Vector2(x, y), polygon
				):
					continue
				total += Vector3(pixel.r, pixel.g, pixel.b)
				samples += 1
		if samples > 0:
			mean = total / samples
	_means[path] = mean
	return mean
