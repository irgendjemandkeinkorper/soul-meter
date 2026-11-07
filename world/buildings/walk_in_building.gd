class_name WalkInBuilding
extends Node2D
## A building the party walks into on the map, with no scene change (owner list item 35: "Modular
## kit" and "One-cell wall line", 2026-11-03; layouts and "Your room opens", 2026-11-04).
##
## The building is a `BuildingLayout`: a text grid of walls, windows, doorways, floor and furniture,
## laid on the map's ground cells from `origin_cell` and turned `quarter_turns` times. Its
## `BuildingPlan` says which kit piece (tools/render_building_kit.gd) stands where: a floor tile per
## cell (a stone footing under a wall), wall pieces in the middle of the cells they block, a post
## where walls meet, furniture from the layout's letters, and one roof computed from the outline.
##
## The look follows the party. Outside, the roof is on. When anyone in the party stands on the
## footprint, the roof goes and the party's rooms open: walls in front of those rooms drop to their
## stubs (a doorway loses its lintel), a wall of another room that would hide part of them fades,
## and every other wall stays up, so rooms nobody is in stay tucked away. When someone stands where
## the roof hides them, the roof and walls fade the way painted facades do.
##
## A shop's vendors (`vendor_ids`) stand at `vendor_cell`, behind its counter, and trade across it.
##
## Blocking: walls, windows and furniture are solid cells. `tools/paint_blocking.gd` writes them
## into the scene as the `WallBody` shapes (`solid_polygons()`) and paints the map's Blocking layer
## from those, so walking, the grid and fights see them with no code of their own; every painted
## cell on the footprint is a thin solid (`BlockingLayer.THIN_TILE`, no clearance ring), so doorways
## and rooms stay open. The tool also writes the walls (not windows: "Shots pass windows",
## 2026-11-03) into the map's combat terrain (`blocks_fire_cells()`). Collision stands
## `WALL_INSET_PX` in from the cells' edges. All looks are PROVISIONAL.

const KIT_DIR := "res://assets/generated/sprites/building-kit/"
const KIT_MANIFEST := KIT_DIR + "building_kit.json"
## Party members open the building; anyone the roof hides fades it (as FacadeOccluder does).
const PARTY_GROUPS: Array[StringName] = [&"player", &"party_follower", &"party_followers"]
const BEHIND_GROUPS: Array[StringName] = [
	&"player", &"party_follower", &"party_followers", &"generated_townsfolk",
]
const FADE_DURATION := 0.15
const WALL_BODY := "WallBody"
## How far collision stands in from its cells' edges. The player's box (30 × 22) centred in the
## next cell reaches about 16.5 px towards it; the cell edge is 14.3 px away.
const WALL_INSET_PX := 3.0
## Far enough to trade across a counter: a vendor two cells deep from the customer is 72 px away.
const VENDOR_INTERACTION_RADIUS := 96.0

enum Look { OUTSIDE, SEEN_THROUGH, INSIDE }

@export var building_name := ""
@export var layout: BuildingLayout
## Quarter turns of the layout: each puts its front row on the right (`BuildingPlan.turned`).
@export_range(0, 3) var quarter_turns := 0
## The ground cell under the layout grid's back (top) corner cell.
@export var origin_cell := Vector2i.ZERO
## Generated vendor ids (`VendorRegistry`) who keep shop here.
@export var vendor_ids := PackedStringArray()
## The plan cell (after the turn) the first vendor stands on; any others stand beside, along x.
@export var vendor_cell := Vector2i.ZERO
## False for a building with no sky over it (the Lower Trial Hall's rooms, 2026-11-04): no roof
## is placed, so no roof piece needs rendering, and the walls cut away room by room as usual.
@export var roofed := true

var _plan: BuildingPlan
var _ground: TileMapLayer
var _ground_to_self := Transform2D.IDENTITY
var _pieces: Array[Sprite2D] = []
## Per piece: [full texture, full offset, low texture or null, low offset].
var _looks: Array[Array] = []
var _roof: Sprite2D
var _behind := {}
var _look := -1
var _open: Array[int] = []
var _fade: Tween


func _ready() -> void:
	y_sort_enabled = true
	var ground := SolidFootprints.find_ground(owner if owner != null else get_parent())
	if ground == null:
		push_error("WalkInBuilding '%s' finds no %s." % [name, SolidFootprints.GROUND_NAME])
		set_physics_process(false)
		return
	bind(ground, global_transform.affine_inverse() * ground.global_transform)
	var problems := plan().problems() if layout != null else PackedStringArray(["no layout"])
	if not problems.is_empty():
		push_error("WalkInBuilding '%s': %s" % [name, "; ".join(problems)])
		set_physics_process(false)
		return
	var kit := _read_kit()
	if kit.is_empty():
		push_error("WalkInBuilding '%s' has no kit manifest at %s." % [name, KIT_MANIFEST])
		set_physics_process(false)
		return
	_build(kit)
	_add_vendors()
	_behind = _behind_cells()
	_set_look(Look.OUTSIDE, [] as Array[int], false)


func _physics_process(_delta: float) -> void:
	var open: Array[int] = []
	var inside := false
	for actor: Node2D in _actors(PARTY_GROUPS):
		var cell := layout_cell_at(actor.global_position)
		if plan().is_footprint(cell):
			inside = true
			for room: int in plan().rooms_of(cell):
				if not room in open:
					open.append(room)
	open.sort()
	var next_look := Look.INSIDE if inside else Look.OUTSIDE
	if not inside:
		for actor: Node2D in _actors(BEHIND_GROUPS):
			if _behind.has(layout_cell_at(actor.global_position)):
				next_look = Look.SEEN_THROUGH
				break
	if next_look != _look or open != _open:
		_set_look(next_look, open, true)


## The look now: OUTSIDE (roof on), SEEN_THROUGH (someone is behind) or INSIDE (cut away).
func current_look() -> int:
	return _look


## The rooms the party stands in (`BuildingPlan` room numbers); empty unless the look is INSIDE.
func open_rooms() -> Array[int]:
	return _open.duplicate()


## The building's floor plan: its layout read and turned.
func plan() -> BuildingPlan:
	if _plan == null:
		_plan = layout.plan(quarter_turns) if layout != null else BuildingPlan.from_rows(PackedStringArray())
	return _plan


## The kit's roof for this layout and turn.
func roof_piece() -> String:
	var layout_name := layout.resource_path.get_file().get_basename() if layout != null else ""
	return "roof-%s-t%d" % [layout_name, quarter_turns]


## Sets the ground the layout's cells belong to, and the transform from that layer's space to this
## node's. `_ready` binds the map's ground; a tool working on a scene that is not in the tree
## (tools/paint_blocking.gd) binds it from the scene's own transforms.
func bind(ground: TileMapLayer, ground_to_self: Transform2D) -> void:
	_ground = ground
	_ground_to_self = ground_to_self


# --- geometry: cells and points -----------------------------------------------------------------


## Point (x, z) of the layout grid, in cell units from its back corner, in this node's space.
func corner(x: float, z: float) -> Vector2:
	var top := _ground.map_to_local(origin_cell) - Vector2(0.0, _ground.tile_set.tile_size.y * 0.5)
	var along_x := _ground.map_to_local(origin_cell + Vector2i(1, 0)) - _ground.map_to_local(origin_cell)
	var along_z := _ground.map_to_local(origin_cell + Vector2i(0, 1)) - _ground.map_to_local(origin_cell)
	return _ground_to_self * (top + along_x * x + along_z * z)


## The layout cell under a point in global space (it may lie off the footprint).
func layout_cell_at(global_point: Vector2) -> Vector2i:
	return _ground.local_to_map(_ground.to_local(global_point)) - origin_cell


## The ground cells the building stands on.
func footprint_cells() -> Array[Vector2i]:
	return _to_map(plan().footprint_cells())


## The ground cells its walls and windows block.
func wall_cells() -> Array[Vector2i]:
	var walls: Array[Vector2i] = []
	for cell: Vector2i in plan().solid_cells():
		if plan().is_wall(cell):
			walls.append(cell)
	return _to_map(walls)


## The ground cells that stop a walk: walls, windows and furniture.
func solid_cells() -> Array[Vector2i]:
	return _to_map(plan().solid_cells())


## The ground cells that stop a shot in a fight: the walls, not the windows (owner ruling
## 2026-11-03, "Shots pass windows"), doorways or furniture.
func blocks_fire_cells() -> Array[Vector2i]:
	return _to_map(plan().blocks_fire_cells())


## The solid cells as convex shapes in this node's space, one per rectangle of
## `BuildingPlan.solid_rects()`, each `WALL_INSET_PX` inside its cells.
func solid_polygons() -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for rect: Rect2i in plan().solid_rects():
		var a := Vector2(rect.position)
		var b := Vector2(rect.end)
		polygons.append(_inset(PackedVector2Array([
			corner(a.x, a.y), corner(b.x, a.y), corner(b.x, b.y), corner(a.x, b.y),
		]), WALL_INSET_PX))
	return polygons


func _to_map(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		result.append(origin_cell + cell)
	return result


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


## Cells off the footprint where the roof hides someone's feet: behind a footprint cell, straight
## up the screen, within the height of the roof over it.
func _behind_cells() -> Dictionary:
	var behind := {}
	var cell_rise := 2.0 * BuildingPlan.HALF_HEIGHT
	for cell: Vector2i in plan().footprint_cells():
		var reach := (plan().roof_top(cell) * BuildingPlan.PIXELS_PER_UNIT + BuildingPlan.HALF_HEIGHT) / cell_rise
		for k in range(1, int(reach) + 1):
			var hidden := cell - Vector2i(k, k)
			if not plan().is_footprint(hidden):
				behind[hidden] = true
	return behind


# --- building the pieces ------------------------------------------------------------------------


func _read_kit() -> Dictionary:
	var json := load(KIT_MANIFEST) as JSON
	if json == null or not json.data is Dictionary:
		return {}
	var pieces: Variant = (json.data as Dictionary).get("pieces", {})
	return pieces if pieces is Dictionary else {}


func _build(kit: Dictionary) -> void:
	var floor_layer := Node2D.new()
	floor_layer.name = "Floor"
	floor_layer.z_index = -1
	add_child(floor_layer)
	var walls := _layer("Walls")
	var furniture := _layer("Furniture")
	var current := plan()
	for cell: Vector2i in current.footprint_cells():
		var tile := "floor-footing" if current.is_wall(cell) else "floor-planks"
		_place(floor_layer, kit, tile, corner(cell.x + 0.5, cell.y + 0.5))
	for piece: Dictionary in current.pieces:
		var names := _piece_names(piece)
		var base: Vector2 = piece["base"]
		var sprite := _place(walls, kit, names[0], corner(base.x, base.y))
		if sprite == null:
			push_error("WalkInBuilding '%s': the kit has no %s." % [name, names[0]])
			sprite = Sprite2D.new()
			walls.add_child(sprite)
		var low := _entry(kit, names[1])
		_pieces.append(sprite)
		_looks.append([
			sprite.texture, sprite.offset,
			null if low.is_empty() else load(KIT_DIR + str(low["file"])), -_pivot(low),
		])
	for item: Dictionary in current.furniture:
		var rect: Rect2i = item["rect"]
		var piece_name := "%s-%dx%d" % [item["kind"], rect.size.x, rect.size.y]
		var centre := Vector2(rect.position) + Vector2(rect.size) * 0.5
		if _place(furniture, kit, piece_name, corner(centre.x, centre.y)) == null:
			push_error("WalkInBuilding '%s': the kit has no %s." % [name, piece_name])
	# The roof sorts at the footprint's front-most point, so anyone in front draws over it.
	var front := corner(0, 0)
	for cell: Vector2i in current.footprint_cells():
		var point := corner(cell.x + 1, cell.y + 1)
		if point.y > front.y:
			front = point
	if not roofed:
		return
	_roof = _place(self, kit, roof_piece(), front)
	if _roof == null:
		push_error("WalkInBuilding '%s': the kit has no %s." % [name, roof_piece()])
	else:
		_roof.name = "Roof"
		_roof.offset += corner(0, 0) - front


func _add_vendors() -> void:
	for index in vendor_ids.size():
		var cell := vendor_cell + Vector2i(index, 0)
		if plan().at(cell) != BuildingPlan.FLOOR:
			push_error("WalkInBuilding '%s': vendor cell %s is not open floor." % [name, cell])
			continue
		var npc := BuildingInterior.vendor_npc(vendor_ids[index], VENDOR_INTERACTION_RADIUS)
		if npc == null:
			continue
		npc.position = corner(cell.x + 0.5, cell.y + 0.5)
		add_child(npc)


## The kit pieces for a wall piece: its full look and its low one ("" for none: a lintel goes).
static func _piece_names(piece: Dictionary) -> Array[String]:
	var run: String = piece["run"]
	var half := int(piece["half"]) != 0
	match int(piece["kind"]):
		BuildingPlan.Kind.WINDOW:
			return ["wall-window-" + run, "wall-stub-" + run]
		BuildingPlan.Kind.LINTEL:
			return ["lintel-" + run, ""]
		BuildingPlan.Kind.POST:
			return ["post", "post-stub"]
		BuildingPlan.Kind.PILLAR:
			return ["pillar", "pillar-stub"]
	if half:
		return ["wall-half-" + run, "wall-stub-half-" + run]
	return ["wall-" + run, "wall-stub-" + run]


func _layer(layer_name: String) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.y_sort_enabled = true
	add_child(layer)
	return layer


static func _entry(kit: Dictionary, piece: String) -> Dictionary:
	var entry: Variant = kit.get(piece, {})
	return entry if entry is Dictionary else {}


static func _pivot(entry: Dictionary) -> Vector2:
	if entry.is_empty():
		return Vector2.ZERO
	var pivot: Array = entry["pivot"]
	return Vector2(float(pivot[0]), float(pivot[1]))


## A kit piece's sprite with its pivot on `at`; null when the kit lacks the piece.
func _place(parent: Node, kit: Dictionary, piece: String, at: Vector2) -> Sprite2D:
	var entry := _entry(kit, piece)
	if entry.is_empty():
		return null
	var texture := load(KIT_DIR + str(entry["file"])) as Texture2D
	if texture == null:
		return null
	var sprite := Sprite2D.new()
	sprite.name = piece.to_pascal_case()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -_pivot(entry)
	sprite.position = at
	parent.add_child(sprite)
	return sprite


# --- the look -------------------------------------------------------------------------------------


func _set_look(next_look: int, open: Array[int], animate: bool) -> void:
	_look = next_look
	_open.clear()
	if next_look == Look.INSIDE:
		_open.append_array(open)
	var seen_through := next_look == Look.SEEN_THROUGH
	var targets: Dictionary = {}
	targets[_roof] = 0.0 if next_look == Look.INSIDE else (DS.FACADE_OCCLUDED_ALPHA if seen_through else 1.0)
	for index in _pieces.size():
		var sprite := _pieces[index]
		var look: Array = _looks[index]
		var state := plan().state_of(index, _open)
		var low := state == BuildingPlan.State.LOW
		if low and look[2] != null:
			sprite.texture = look[2]
			sprite.offset = look[3]
		else:
			sprite.texture = look[0]
			sprite.offset = look[1]
		var alpha := 1.0
		if seen_through:
			alpha = DS.FACADE_OCCLUDED_ALPHA
		elif low and look[2] == null:
			alpha = 0.0
		elif state == BuildingPlan.State.FADED:
			alpha = DS.FACADE_OCCLUDED_ALPHA
		targets[sprite] = alpha
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not animate:
		for item: Variant in targets:
			if item != null:
				(item as CanvasItem).modulate.a = targets[item]
		return
	_fade = create_tween().set_parallel(true)
	var changed := false
	for item: Variant in targets:
		if item != null and not is_equal_approx((item as CanvasItem).modulate.a, targets[item]):
			_fade.tween_property(item, "modulate:a", targets[item], FADE_DURATION)
			changed = true
	if not changed:
		_fade.kill()


## The visible members of `groups`.
func _actors(groups: Array[StringName]) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for group: StringName in groups:
		for node: Node in get_tree().get_nodes_in_group(group):
			var actor := node as Node2D
			if actor != null and actor.is_visible_in_tree() and not actor in found:
				found.append(actor)
	return found
