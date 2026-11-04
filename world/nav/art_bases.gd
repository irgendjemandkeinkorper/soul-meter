class_name ArtBases
extends RefCounted
## The ground base of each prop's art (owner ruling 2026-11-03, "Full bases, all maps"). A
## building, rock, cart or tent stops walking and fighting across the whole base it stands on in
## its picture, not only along a thin line at its front. ALL BASES ARE PROVISIONAL.
##
## Each entry is one or more convex polygons in the art file's own pixels. The four corners of an
## iso base are left, front, right and back. Most were fitted from the art's alpha (the lowest
## opaque edge is the base's front; the back mirrors it through the centre of the left and right
## corners) and checked by eye. Where the fit caught a cart shaft or a bench leg, or the art is
## not drawn at 2:1, the corners were traced by hand. A tree's base is its trunk and roots: the
## canopy can be walked under. The crenellated wall is an L, so its base is two strips.
## Contact sheet: docs/qa/map-bases-2026-11-03/08-art-bases.jpg.
##
## On every map in `SolidFootprints.PAINTED_MAPS`, a sprite showing one of these files is solid
## over its base, unless it is a ground decal or a soft detail (`NOT_SOLID_LAYERS`).
## `tools/paint_blocking.gd` writes the bases into the scenes as ConvexPolygonShape2D shapes, then
## paints the blocking layer from them; `test_blocking_paint` fails when the two drift apart.

const WORLD := "res://assets/generated/sprites/world/"
## Dressing layers whose sprites never block (the location-dressing pattern).
const NOT_SOLID_LAYERS: Array[String] = ["GroundDetails", "SoftDetails"]
## Name of the body given to a based sprite that has none.
const BASE_BODY := "Base"

const BASES := {
	WORLD + "dom-four-arms-tavern--building-facade.png": [
		[Vector2(23, 629), Vector2(324, 710), Vector2(490, 620), Vector2(189, 539)],
	],
	WORLD + "dom-item-shop--building-facade.png": [
		[Vector2(33, 616), Vector2(300, 668), Vector2(482, 617), Vector2(215, 565)],
	],
	# Traced: drawn front-on, its right face runs on past the fit's corner to the art's edge.
	WORLD + "dom-town-hall--building-facade.png": [
		[Vector2(48, 657), Vector2(384, 730), Vector2(472, 686), Vector2(136, 613)],
	],
	WORLD + "dom-lower-market--building-facade.png": [
		[Vector2(55, 651), Vector2(269, 736), Vector2(452, 641), Vector2(238, 556)],
	],
	WORLD + "dom-bell-house--building-facade.png": [
		[Vector2(136, 696), Vector2(267, 741), Vector2(378, 693), Vector2(247, 648)],
	],
	WORLD + "dom-wooden-sign--decorative.png": [
		[Vector2(105, 273), Vector2(129, 292), Vector2(163, 276), Vector2(139, 257)],
	],
	WORLD + "dom-moss-statue-fragment--decorative.png": [
		[Vector2(50, 212), Vector2(117, 235), Vector2(216, 201), Vector2(149, 178)],
	],
	# Traced: the left wheel, the shaft's tip on the ground, the handle.
	WORLD + "dom-cart--high.png": [
		[Vector2(16, 175), Vector2(200, 250), Vector2(240, 202), Vector2(56, 127)],
	],
	# Traced: the four legs of a long bench.
	WORLD + "dom-stall-bench--plank.png": [
		[Vector2(8, 224), Vector2(56, 250), Vector2(248, 175), Vector2(200, 149)],
	],
	WORLD + "dom-rock--mossy.png": [
		[Vector2(17, 373), Vector2(271, 495), Vector2(485, 372), Vector2(231, 250)],
	],
	WORLD + "dom-notice-board--decorative.png": [
		[Vector2(38, 195), Vector2(172, 233), Vector2(216, 220), Vector2(82, 182)],
	],
	WORLD + "dom-market-stall--decorative.png": [
		[Vector2(24, 197), Vector2(89, 238), Vector2(224, 184), Vector2(159, 143)],
	],
	# Traced: an L of two walls meeting at the front corner; each arm is a 32 px strip, so the
	# ground inside the L stays open.
	WORLD + "dom-wall--crenellated.png": [
		[Vector2(8, 138), Vector2(128, 219), Vector2(128, 251), Vector2(8, 170)],
		[Vector2(128, 219), Vector2(248, 138), Vector2(248, 170), Vector2(128, 251)],
	],
	# Traced: the three legs.
	WORLD + "dom-brazier-iron--street.png": [
		[Vector2(24, 175), Vector2(128, 243), Vector2(232, 196), Vector2(128, 128)],
	],
	WORLD + "dom-crate-wood--stacked.png": [
		[Vector2(87, 215), Vector2(121, 243), Vector2(163, 215), Vector2(129, 187)],
	],
	WORLD + "dom-tree--oak-a.png": [
		[Vector2(185, 475), Vector2(243, 500), Vector2(386, 459), Vector2(328, 434)],
	],
	WORLD + "dom-tree--oak-b.png": [
		[Vector2(159, 479), Vector2(204, 501), Vector2(309, 485), Vector2(264, 463)],
	],
	WORLD + "dom-tree--pine-a.png": [
		[Vector2(222, 486), Vector2(282, 501), Vector2(296, 492), Vector2(236, 477)],
	],
	WORLD + "jawbrace/jawbrace-empty-guard-post--decorative.png": [
		[Vector2(80, 221), Vector2(130, 242), Vector2(176, 223), Vector2(126, 202)],
	],
	WORLD + "loamroot-grove/loamroot-standing-stone--decorative.png": [
		[Vector2(48, 214), Vector2(131, 245), Vector2(208, 203), Vector2(125, 172)],
	],
	WORLD + "dorthkor-road/dorthkor-supply-cart--decorative.png": [
		[Vector2(20, 194), Vector2(156, 232), Vector2(235, 175), Vector2(99, 137)],
	],
	WORLD + "jawbrace/jawbrace-chain-post--decorative.png": [
		[Vector2(47, 213), Vector2(122, 249), Vector2(205, 216), Vector2(130, 180)],
	],
	# Traced: the tent's left and right skirts reach the ground past the fit's corners.
	WORLD + "dorthkor-road/dorthkor-camp-tent--decorative.png": [
		[Vector2(32, 270), Vector2(272, 385), Vector2(448, 250), Vector2(208, 135)],
	],
	WORLD + "loamroot-grove/loamroot-fallen-log--decorative.png": [
		[Vector2(42, 195), Vector2(127, 239), Vector2(215, 204), Vector2(130, 160)],
	],
	WORLD + "loamroot-grove/loamroot-old-stump--decorative.png": [
		[Vector2(15, 216), Vector2(98, 265), Vector2(300, 200), Vector2(217, 151)],
	],
	WORLD + "dorthkor-road/dorthkor-memorial-marker--decorative.png": [
		[Vector2(47, 223), Vector2(130, 250), Vector2(208, 218), Vector2(125, 191)],
	],
	WORLD + "dorthkor-road/dorthkor-breach-warning-post--decorative.png": [
		[Vector2(63, 232), Vector2(120, 252), Vector2(188, 233), Vector2(131, 213)],
	],
	WORLD + "dorthkor-road/dorthkor-road-drum--decorative.png": [
		[Vector2(32, 198), Vector2(111, 238), Vector2(226, 211), Vector2(147, 171)],
	],
	WORLD + "jawbrace/jawbrace-warning-plate--decorative.png": [
		[Vector2(53, 226), Vector2(95, 246), Vector2(199, 205), Vector2(157, 185)],
	],
	WORLD + "jawbrace/jawbrace-retaining-structure--decorative.png": [
		[Vector2(58, 204), Vector2(141, 234), Vector2(197, 223), Vector2(114, 193)],
	],
	WORLD + "dorthkor-road/dorthkor-campfire--decorative.png": [
		[Vector2(53, 155), Vector2(180, 215), Vector2(302, 148), Vector2(175, 88)],
	],
}


## Every sprite under `root` that shows a based art file and is not in a non-solid layer.
static func based_sprites(root: Node) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for node: Node in root.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite.texture == null or not BASES.has(sprite.texture.resource_path):
			continue
		if _in_non_solid_layer(sprite, root):
			continue
		found.append(sprite)
	return found


## The body that carries the sprite's base: the StaticBody2D it is drawn by, or null when the
## sprite has none yet (the tool then adds a `BASE_BODY` child).
static func body_of(sprite: Sprite2D) -> StaticBody2D:
	return sprite.get_parent() as StaticBody2D


## The sprite's base polygons in the coordinate space of the node that holds its shapes: its
## body when it has one, else the sprite itself (where the added Base body sits).
static func polygons_for(sprite: Sprite2D) -> Array[PackedVector2Array]:
	var rect := sprite.get_rect()
	var to_frame := sprite.transform if body_of(sprite) != null else Transform2D.IDENTITY
	var out: Array[PackedVector2Array] = []
	for polygon: Array in BASES[sprite.texture.resource_path]:
		var points := PackedVector2Array()
		for pixel: Vector2 in polygon:
			var local := pixel
			if sprite.flip_h:
				local.x = rect.size.x - local.x
			if sprite.flip_v:
				local.y = rect.size.y - local.y
			points.append(to_frame * (rect.position + local))
		out.append(points)
	return out


static func _in_non_solid_layer(node: Node, root: Node) -> bool:
	var current := node.get_parent()
	while current != null and current != root:
		if String(current.name) in NOT_SOLID_LAYERS:
			return true
		current = current.get_parent()
	return false
