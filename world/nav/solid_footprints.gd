class_name SolidFootprints
extends RefCounted
## The ground cells a map's solid bodies stand on (2026-11-03). Hex slice H2 found that seven of
## the ten maps had nothing painted on their blocking layer: a building, a rock or the map's own
## border stopped the walking player through physics, but the grid that fights and click-to-move
## path on did not know it was there, so a fight walked through a facade or off the map.
##
## A solid is a StaticBody2D on collision layer 1 that is not an NPC (an occupant, not an
## obstacle; see `NavOccupancy`), not inside an Area2D (a travel exit's LockedBarrier opens and
## shuts with the story) and not switched off (process mode disabled). An enabled shape covers
## a ground cell when the cell's centre lies inside it. The cell under a shape's centre is always
## covered, so a prop smaller than a cell still fills one. Shapes are read as authored, before
## any node is ready.
##
## `tools/paint_blocking.gd` paints these cells into the blocking layer of each map in
## PAINTED_MAPS, so the blocking layer stays the one source of static passability
## (`BlockingLayer`). `test_blocking_paint` fails when a moved or added solid leaves the paint
## behind; rerun the tool then.

## Scene -> the blocking layer the tool paints, by node path from the scene root. The layer has
## the ground's transform, so its cells are ground cells.
const PAINTED_MAPS: Dictionary = {
	"res://world/kesselford.tscn": "Blocking",
	"res://world/ashlaren.tscn": "Blocking",
	"res://world/hollowmere.tscn": "Blocking",
	"res://world/long_verge.tscn": "Blocking",
	"res://world/dorthkor_road.tscn": "Blocking",
	"res://world/wound_lip.tscn": "Blocking",
	"res://world/interiors/lower_trial_hall.tscn": "Blocking",
}
const GROUND_NAME := "IsometricGround"


## The scene's ground layer. Before the scene is ready, generated ground gets its tile set here
## (its own _ready would set the same one), so cell maths work on a bare instance.
static func find_ground(root: Node) -> TileMapLayer:
	var ground := root.find_child(GROUND_NAME, true, false) as TileMapLayer
	if ground != null and ground.tile_set == null and ground is IsometricBlockout:
		ground.tile_set = IsometricBlockout.GROUND_TILESET
	return ground


## Every ground cell a solid under `root` covers, as {cell: true}. Bodies in `skip` are left out.
static func ground_cells(root: Node, ground: TileMapLayer, skip: Array = []) -> Dictionary:
	var cells := {}
	for body: Node in root.find_children("*", "StaticBody2D", true, false):
		if body in skip or not is_solid(body, root):
			continue
		for child: Node in body.get_children():
			for cell: Vector2i in shape_cells(child, root, ground):
				cells[cell] = true
	return cells


static func is_solid(body: Node, root: Node) -> bool:
	var solid := body as StaticBody2D
	if solid == null or solid is NPC or (solid.collision_layer & 1) == 0:
		return false
	var node: Node = solid.get_parent()
	while node != null and node != root:
		if node is Area2D:
			return false
		node = node.get_parent()
	# A body whose processing is off leaves the physics world (CollisionObject2D.disable_mode).
	node = solid
	while node != null and node.process_mode == Node.PROCESS_MODE_INHERIT:
		node = node.get_parent()
	return node == null or node.process_mode != Node.PROCESS_MODE_DISABLED


## The ground cells one CollisionShape2D or CollisionPolygon2D covers; none when it is disabled.
static func shape_cells(shape_node: Node, root: Node, ground: TileMapLayer) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var local_bounds := _local_bounds(shape_node)
	if local_bounds.size == Vector2.ZERO:
		return cells
	var to_root := transform_in(shape_node as Node2D, root)
	var ground_to_root := transform_in(ground, root)
	var root_to_ground := ground_to_root.affine_inverse()
	var ground_rect := ground_bounds(ground)
	var centre := ground.local_to_map(root_to_ground * to_root.origin)
	if ground_rect.has_point(centre):
		cells.append(centre)
	# A cell coordinate is linear in local position, so the box's corners bound the candidates.
	var low := Vector2i(1 << 30, 1 << 30)
	var high := -low
	for corner: Vector2 in [
		local_bounds.position, local_bounds.end,
		Vector2(local_bounds.position.x, local_bounds.end.y),
		Vector2(local_bounds.end.x, local_bounds.position.y),
	]:
		var cell := ground.local_to_map(root_to_ground * (to_root * corner))
		low = low.min(cell)
		high = high.max(cell)
	var to_shape := to_root.affine_inverse()
	for y in range(low.y - 1, high.y + 2):
		for x in range(low.x - 1, high.x + 2):
			var cell := Vector2i(x, y)
			if cell == centre or not ground_rect.has_point(cell):
				continue
			var point := to_shape * (ground_to_root * ground.map_to_local(cell))
			if _contains(shape_node, point):
				cells.append(cell)
	return cells


## `node`'s transform relative to `root`. It works before the scene is in the tree.
static func transform_in(node: Node2D, root: Node) -> Transform2D:
	var xform := Transform2D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node2D:
			xform = (current as Node2D).transform * xform
		current = current.get_parent()
	return xform


## The ground's cells. Generated ground (`IsometricBlockout`) fills its map_size when ready, so
## before that the rectangle comes from map_size.
static func ground_bounds(ground: TileMapLayer) -> Rect2i:
	var rect := ground.get_used_rect()
	if rect.size == Vector2i.ZERO and ground is IsometricBlockout:
		rect = Rect2i(Vector2i.ZERO, (ground as IsometricBlockout).map_size)
	return rect


static func _local_bounds(shape_node: Node) -> Rect2:
	if shape_node is CollisionPolygon2D:
		var polygon := shape_node as CollisionPolygon2D
		if polygon.disabled or polygon.polygon.size() < 3:
			return Rect2()
		var box := Rect2(polygon.polygon[0], Vector2.ZERO)
		for point: Vector2 in polygon.polygon:
			box = box.expand(point)
		return box
	if not shape_node is CollisionShape2D:
		return Rect2()
	var collision := shape_node as CollisionShape2D
	if collision.disabled or collision.shape == null:
		return Rect2()
	if collision.shape is RectangleShape2D:
		var size := (collision.shape as RectangleShape2D).size
		return Rect2(-size * 0.5, size)
	if collision.shape is CircleShape2D:
		var radius := (collision.shape as CircleShape2D).radius
		return Rect2(-Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if collision.shape is CapsuleShape2D:
		var capsule := collision.shape as CapsuleShape2D
		return Rect2(
			Vector2(-capsule.radius, -capsule.height * 0.5),
			Vector2(capsule.radius * 2.0, capsule.height),
		)
	# Any other shape still fills the cell under its centre.
	return Rect2(Vector2.ZERO, Vector2.ONE)


static func _contains(shape_node: Node, point: Vector2) -> bool:
	if shape_node is CollisionPolygon2D:
		return Geometry2D.is_point_in_polygon(point, (shape_node as CollisionPolygon2D).polygon)
	var shape := (shape_node as CollisionShape2D).shape
	if shape is RectangleShape2D:
		var half := (shape as RectangleShape2D).size * 0.5
		return absf(point.x) <= half.x and absf(point.y) <= half.y
	if shape is CircleShape2D:
		return point.length() <= (shape as CircleShape2D).radius
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var reach := maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		return Vector2(point.x, point.y - clampf(point.y, -reach, reach)).length() <= capsule.radius
	return false
