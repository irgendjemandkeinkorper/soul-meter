class_name WalkInBuilding
extends Node2D
## A building the party walks into on the map, with no scene change (owner list item 35, rulings
## of 2026-11-03: "Modular kit", "One prototype", "One-cell wall line", "Grow to 12 × 9").
##
## The building is a footprint of ground cells. Kit pieces (tools/render_building_kit.gd) stand
## on it: a floor tile per cell, a wall piece on every outer cell edge except the doorway's, a
## post at each corner and doorway jamb, and one roof. When anyone in the party stands on the
## footprint, the roof fades away and the front walls drop to their stubs; when someone stands
## behind the building, the roof and front walls fade the way painted facades do.
##
## Blocking follows the owner's "one-cell wall line": the outermost ring of footprint cells is
## solid, except the doorway. `tools/paint_blocking.gd` writes that ring into the scene as the
## `WallBody` shapes (`wall_polygons()`), then paints the map's Blocking layer from them, so
## walking, the grid and fights all see the walls with no code of their own. Every painted cell
## inside the footprint is a thin solid (`BlockingLayer.THIN_TILE`): the walk grid gives it no
## clearance ring, so the two-cell doorway and the room stay open. Collision stands
## `WALL_INSET_PX` in from the cells' edges, so a body in the next cell clears it.
##
## Sides are named for where they sit on screen: the back walls run along the top two edges of the
## footprint's diamond, the front walls along the bottom two. All looks are PROVISIONAL.

enum Side { BACK_RIGHT, BACK_LEFT, FRONT_LEFT, FRONT_RIGHT }

const KIT_DIR := "res://assets/generated/sprites/building-kit/"
const KIT_MANIFEST := KIT_DIR + "building_kit.json"
## Party members lift the roof; anyone standing behind fades it (as FacadeOccluder does).
const PARTY_GROUPS: Array[StringName] = [&"player", &"party_follower", &"party_followers"]
const BEHIND_GROUPS: Array[StringName] = [
	&"player", &"party_follower", &"party_followers", &"generated_townsfolk",
]
const FADE_DURATION := 0.15
const WALL_BODY := "WallBody"
## How far a wall's collision stands in from its cells' edges. The player's box (30 × 22) centred
## in the next cell reaches about 16.5 px towards the wall; the cell edge is 14.3 px away.
const WALL_INSET_PX := 3.0
## Kit spec: a wall is 4 units tall; one unit of height is this many pixels on screen.
const WALL_UNITS := 4.0
const PIXELS_PER_UNIT_HEIGHT := 40.477
const ROOF_PITCH_DEGREES := 35.0

enum Look { OUTSIDE, SEEN_THROUGH, INSIDE }

@export var building_name := ""
## The ground cell at the footprint's back (top) corner.
@export var origin_cell := Vector2i.ZERO
## Footprint size in ground cells: x along the ground's +x cells, y along its +y cells.
@export var cells := Vector2i(12, 9)
@export var door_side := Side.FRONT_LEFT
## The doorway's first cell along its side, counted from the side's start (its back or left end).
@export var door_start := 9
@export var door_width := 2
## Cells along each side whose wall piece has a window, by `Side` value.
@export var windows := {}

var _ground: TileMapLayer
var _ground_to_self := Transform2D.IDENTITY
var _floor: Node2D
var _back: Node2D
var _front: Node2D
var _stubs: Node2D
var _roof: Sprite2D
var _footprint := PackedVector2Array()
var _silhouette := PackedVector2Array()
var _look := -1
var _fade: Tween


func _ready() -> void:
	y_sort_enabled = true
	var ground := SolidFootprints.find_ground(owner if owner != null else get_parent())
	if ground == null:
		push_error("WalkInBuilding '%s' finds no %s." % [name, SolidFootprints.GROUND_NAME])
		set_physics_process(false)
		return
	bind(ground, global_transform.affine_inverse() * ground.global_transform)
	var kit := _read_kit()
	if kit.is_empty():
		push_error("WalkInBuilding '%s' has no kit manifest at %s." % [name, KIT_MANIFEST])
		set_physics_process(false)
		return
	_build(kit)
	_footprint = footprint_polygon()
	_silhouette = _silhouette_polygon()
	_set_look(Look.OUTSIDE, false)


func _physics_process(_delta: float) -> void:
	var next_look := Look.OUTSIDE
	if _any_in_group_at(PARTY_GROUPS, _footprint, PackedVector2Array()):
		next_look = Look.INSIDE
	elif _any_in_group_at(BEHIND_GROUPS, _silhouette, _footprint):
		next_look = Look.SEEN_THROUGH
	if next_look != _look:
		_set_look(next_look, true)


## The look now: OUTSIDE (roof on), SEEN_THROUGH (someone is behind) or INSIDE (cut away).
func current_look() -> int:
	return _look


## Sets the ground the footprint's cells belong to, and the transform from that layer's space to
## this node's. `_ready` binds the map's ground; a tool working on a scene that is not in the tree
## (tools/paint_blocking.gd) binds it from the scene's own transforms.
func bind(ground: TileMapLayer, ground_to_self: Transform2D) -> void:
	_ground = ground
	_ground_to_self = ground_to_self


# --- geometry: footprint cells and points, in this node's space -------------------------------


## The top corner of the cell at footprint coordinates (i, j); i and j may run to the far edges.
func corner(i: float, j: float) -> Vector2:
	var tile := Vector2(_ground.tile_set.tile_size)
	var top := _ground.map_to_local(origin_cell) - Vector2(0.0, tile.y * 0.5)
	var along_x := _ground.map_to_local(origin_cell + Vector2i(1, 0)) - _ground.map_to_local(origin_cell)
	var along_y := _ground.map_to_local(origin_cell + Vector2i(0, 1)) - _ground.map_to_local(origin_cell)
	return _ground_to_self * (top + along_x * i + along_y * j)


## The footprint's outline: back, right, front and left corners.
func footprint_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		corner(0, 0), corner(cells.x, 0), corner(cells.x, cells.y), corner(0, cells.y),
	])


## How many cells run along `side`.
func side_length(side: int) -> int:
	return cells.x if side in [Side.BACK_RIGHT, Side.FRONT_LEFT] else cells.y


## Whether cell `index` along `side` is part of the doorway.
func is_doorway(side: int, index: int) -> bool:
	return side == door_side and index >= door_start and index < door_start + door_width


## The footprint cell (i, j) that the wall line holds at `index` along `side`.
func ring_cell(side: int, index: int) -> Vector2i:
	match side:
		Side.BACK_RIGHT:
			return Vector2i(index, 0)
		Side.BACK_LEFT:
			return Vector2i(0, index)
		Side.FRONT_LEFT:
			return Vector2i(index, cells.y - 1)
		_:
			return Vector2i(cells.x - 1, index)


## The ground cells the wall line blocks: the footprint's outer ring, less the doorway.
func wall_cells() -> Array[Vector2i]:
	var found := {}
	for side: int in Side.values():
		for index in side_length(side):
			if not is_doorway(side, index):
				found[origin_cell + ring_cell(side, index)] = true
	var result: Array[Vector2i] = []
	result.assign(found.keys())
	result.sort()
	return result


## The wall line as convex strips in this node's space, one per unbroken run of a side. Each strip
## lies `WALL_INSET_PX` inside its cells, so the cells whose centres it holds are the wall line.
func wall_polygons() -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for side: int in Side.values():
		var start := -1
		for index in side_length(side) + 1:
			var open := index == side_length(side) or is_doorway(side, index)
			if not open and start < 0:
				start = index
			elif open and start >= 0:
				polygons.append(_strip(side, start, index))
				start = -1
	return polygons


func _strip(side: int, from: int, to: int) -> PackedVector2Array:
	var a := ring_cell(side, from)
	var b := ring_cell(side, to - 1) + Vector2i.ONE
	var cells_outline := PackedVector2Array([
		corner(a.x, a.y), corner(b.x, a.y), corner(b.x, b.y), corner(a.x, b.y),
	])
	return _inset(cells_outline, WALL_INSET_PX)


## A convex polygon, clockwise on screen, with every edge moved `by` pixels inwards.
static func _inset(points: PackedVector2Array, by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := points.size()
	for index in count:
		var before := points[posmod(index - 1, count)]
		var at := points[index]
		var after := points[(index + 1) % count]
		var incoming := at - before
		var outgoing := after - at
		var hit: Variant = Geometry2D.line_intersects_line(
			before + Vector2(-incoming.y, incoming.x).normalized() * by, incoming,
			at + Vector2(-outgoing.y, outgoing.x).normalized() * by, outgoing,
		)
		out.append(hit if hit is Vector2 else at)
	return out


## The base of the wall piece at `index` along `side`: its two ends on the footprint's outline.
func edge_segment(side: int, index: int) -> Array[Vector2]:
	match side:
		Side.BACK_RIGHT:
			return [corner(index, 0), corner(index + 1, 0)]
		Side.BACK_LEFT:
			return [corner(0, index), corner(0, index + 1)]
		Side.FRONT_LEFT:
			return [corner(index, cells.y), corner(index + 1, cells.y)]
		_:
			return [corner(cells.x, index), corner(cells.x, index + 1)]


# --- building the pieces ------------------------------------------------------------------------


func _read_kit() -> Dictionary:
	var json := load(KIT_MANIFEST) as JSON
	if json == null or not json.data is Dictionary:
		return {}
	var pieces: Variant = (json.data as Dictionary).get("pieces", {})
	return pieces if pieces is Dictionary else {}


func _build(kit: Dictionary) -> void:
	_floor = _layer("Floor", false)
	_floor.z_index = -1
	_back = _layer("BackWalls", true)
	_front = _layer("FrontWalls", true)
	_stubs = _layer("FrontStubs", true)
	for j in cells.y:
		for i in cells.x:
			_place(_floor, kit, "floor-planks", corner(i + 0.5, j + 0.5))
	for side: int in Side.values():
		var front := side in [Side.FRONT_LEFT, Side.FRONT_RIGHT]
		var run := "x" if side in [Side.BACK_RIGHT, Side.FRONT_LEFT] else "z"
		var window_cells: Array = windows.get(int(side), [])
		for index in side_length(side):
			var ends := edge_segment(side, index)
			var middle := ends[0].lerp(ends[1], 0.5)
			if is_doorway(side, index):
				_place(_front if front else _back, kit, "lintel-" + run, middle)
				continue
			var piece := ("wall-window-" if index in window_cells else "wall-") + run
			_place(_front if front else _back, kit, piece, middle)
			if front:
				_place(_stubs, kit, "wall-stub-" + run, middle)
	# Posts: the back corner stands with the back walls; the rest belong to the front.
	_place(_back, kit, "post", corner(0, 0))
	var jambs: Array[Vector2] = [corner(cells.x, 0), corner(cells.x, cells.y), corner(0, cells.y)]
	var door_ends := edge_segment(door_side, door_start)
	jambs.append(door_ends[0])
	jambs.append(edge_segment(door_side, door_start + door_width - 1)[1])
	for point: Vector2 in jambs:
		_place(_front, kit, "post", point)
		_place(_stubs, kit, "post-stub", point)
	_roof = _place(self, kit, "roof-%dx%d" % [cells.x, cells.y], corner(cells.x, cells.y))
	if _roof == null:
		push_error("WalkInBuilding '%s': the kit has no roof for %s cells." % [name, cells])


func _layer(layer_name: String, y_sorted: bool) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.y_sort_enabled = y_sorted
	add_child(layer)
	return layer


## A kit piece's sprite with its pivot on `at`; null when the kit lacks the piece.
func _place(parent: Node, kit: Dictionary, piece: String, at: Vector2) -> Sprite2D:
	var entry: Variant = kit.get(piece, {})
	if not entry is Dictionary or (entry as Dictionary).is_empty():
		return null
	var texture := load(KIT_DIR + str(entry["file"])) as Texture2D
	if texture == null:
		return null
	var pivot: Array = entry["pivot"]
	var sprite := Sprite2D.new()
	sprite.name = piece.to_pascal_case()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -Vector2(float(pivot[0]), float(pivot[1]))
	sprite.position = at
	parent.add_child(sprite)
	return sprite


# --- the look -------------------------------------------------------------------------------------


func _set_look(next_look: int, animate: bool) -> void:
	_look = next_look
	var inside := next_look == Look.INSIDE
	var fade := DS.FACADE_OCCLUDED_ALPHA if next_look == Look.SEEN_THROUGH else 1.0
	# Outside, the roof hides the back walls; drawn, their tops would show along its back eave.
	_back.visible = inside
	_stubs.visible = inside
	var roof_alpha := 0.0 if inside else fade
	var front_alpha := 0.0 if inside else fade
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not animate:
		_front.modulate.a = front_alpha
		if _roof != null:
			_roof.modulate.a = roof_alpha
		return
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(_front, "modulate:a", front_alpha, FADE_DURATION)
	if _roof != null:
		_fade.tween_property(_roof, "modulate:a", roof_alpha, FADE_DURATION)


## The screen area the building covers outside: its footprint with walls and roof on top.
func _silhouette_polygon() -> PackedVector2Array:
	var wall := Vector2(0.0, WALL_UNITS * PIXELS_PER_UNIT_HEIGHT)
	var rise := Vector2(
		0.0, float(cells.y) * 0.5 * tan(deg_to_rad(ROOF_PITCH_DEGREES)) * PIXELS_PER_UNIT_HEIGHT
	)
	var points := PackedVector2Array()
	for point: Vector2 in footprint_polygon():
		points.append(point)
		points.append(point - wall)
	points.append(corner(0, cells.y * 0.5) - wall - rise)
	points.append(corner(cells.x, cells.y * 0.5) - wall - rise)
	return Geometry2D.convex_hull(points)


## Whether a member of `groups` has its feet in `area` and not in `outside_of`.
func _any_in_group_at(
	groups: Array[StringName], area: PackedVector2Array, outside_of: PackedVector2Array
) -> bool:
	for group: StringName in groups:
		for node: Node in get_tree().get_nodes_in_group(group):
			var actor := node as Node2D
			if actor == null or not actor.is_visible_in_tree():
				continue
			var feet := to_local(actor.global_position)
			if not Geometry2D.is_point_in_polygon(feet, area):
				continue
			if outside_of.is_empty() or not Geometry2D.is_point_in_polygon(feet, outside_of):
				return true
	return false
