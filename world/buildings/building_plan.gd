class_name BuildingPlan
extends RefCounted
## A walk-in building's floor plan, read from its text grid (owner list item 35, layouts ruled
## 2026-11-04): where the walls, windows, doorways, floor and furniture are, which rooms the walls
## close off, which kit piece stands on each wall cell, which pieces drop or fade for each room
## while the party is inside ("Your room opens"), and the roof over it all. Pure data with no scene
## tree, so tests, tools/render_building_kit.gd and WalkInBuilding all read the same plan.
##
## One character per ground cell: `#` wall, `W` window, `D` doorway, `.` floor, a space for
## outside, and a furniture letter (FURNITURE) for floor with furniture on it. Cell (i, j) is
## column i of row j: i runs along the ground's +x cells (screen right and down), j along its +y
## cells (screen left and down). A point (x, z) is in cell units, with cell (i, j) running from
## (i, j) at its back corner to (i + 1, j + 1) at its front corner.
##
## Every wall stands in the middle of the cells it blocks, so an inner wall needs no footprint edge
## to follow. A straight run gets one full piece per cell; a corner, junction, end or lone pillar
## gets half pieces towards each wall it meets and a post. Windows and doorways sit in straight runs.

const WALL := "#"
const WINDOW := "W"
const DOOR := "D"
const FLOOR := "."
const OUTSIDE := " "
## Furniture letters and the kit piece each draws.
const FURNITURE := {
	"B": "counter", "T": "table", "S": "shelves", "c": "chest", "F": "hearth", "K": "stove",
	"E": "bed",
}
## Kit spec in cell units (tools/render_building_kit.gd renders the pieces to these sizes).
const WALL_HEIGHT := 4.0
const STUB_HEIGHT := 0.5
const DOOR_HEIGHT := 3.0
const WALL_THICKNESS := 0.2
const POST_SIZE := 0.26
const PILLAR_SIZE := 0.5
## The roof rises at this pitch from every outer wall, so its slopes meet in ridges and hips and
## form valleys where wings join: height grows with the L-infinity distance to the outside, which
## for a footprint of whole cells is the straight-skeleton roof.
const ROOF_PITCH_DEGREES := 30.0
## How far the roof stands above the wall tops where it passes a post's outer corner.
const ROOF_SEAT := 0.03
## The map's projection: a cell is a 64 x 32 diamond, one unit of height 39.19 px (the kit's 30°).
const HALF_WIDTH := 32.0
const HALF_HEIGHT := 16.0
const PIXELS_PER_UNIT := 39.19
## A full wall that would hide these heights of a person in the party's room fades instead.
const WATCH_HEIGHTS: Array[float] = [0.0, 1.5]

enum Kind { WALL, WINDOW, LINTEL, POST, PILLAR }
## A piece's look while the party is inside: whole, dropped to its stub (a lintel goes), or faded.
enum State { FULL, LOW, FADED }

const _STEPS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var rows := PackedStringArray()
var size := Vector2i.ZERO
var room_count := 0
## {"letter", "kind", "rect": Rect2i}, one per rectangle of one furniture letter.
var furniture: Array[Dictionary] = []
## One per kit piece on a wall cell: {"kind": Kind, "cell": Vector2i, "run": "x"/"z"/"",
## "half": -1 (the back half: towards -x or -z), 0 (whole cell) or 1, "base": Vector2 (x, z) at
## the middle of its foot, "drop": rooms it drops for, "fade": rooms it fades for, "hull": its
## full height on screen, "with": for a post, the pieces it stands with}.
var pieces: Array[Dictionary] = []
var _room := {}
var _outside: Array[Vector2i] = []


## The plan of `source` rows, turned `quarter_turns` times (see `turned`).
static func from_rows(source: PackedStringArray, quarter_turns := 0) -> BuildingPlan:
	var plan := BuildingPlan.new()
	plan.rows = turned(source, quarter_turns)
	plan._parse()
	return plan


## `source` turned a quarter at a time: each turn puts the front row (largest j) on the right
## (largest i), so a building can face another street with its plan unchanged.
static func turned(source: PackedStringArray, quarter_turns: int) -> PackedStringArray:
	var out := source
	for turn in posmod(quarter_turns, 4):
		var width := out[0].length() if out.size() > 0 else 0
		var next := PackedStringArray()
		for j in width:
			var line := ""
			for i in out.size():
				line += out[i][width - 1 - j]
			next.append(line)
		out = next
	return out


## The character at `cell`; outside the grid is OUTSIDE.
func at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.y >= rows.size() or cell.x >= rows[cell.y].length():
		return OUTSIDE
	return rows[cell.y][cell.x]


func is_footprint(cell: Vector2i) -> bool:
	return at(cell) != OUTSIDE


## Walls and windows: cells that stop a walk.
func is_wall(cell: Vector2i) -> bool:
	return at(cell) == WALL or at(cell) == WINDOW


func is_room_cell(cell: Vector2i) -> bool:
	return at(cell) == FLOOR or FURNITURE.has(at(cell))


## The rooms `cell` belongs to: its own for floor and furniture, both sides' for a doorway.
func rooms_of(cell: Vector2i) -> Array[int]:
	var found: Array[int] = []
	if is_room_cell(cell):
		found.append(int(_room[cell]))
	elif at(cell) == DOOR:
		for step: Vector2i in _STEPS:
			var room: int = _room.get(cell + step, 0)
			if room > 0 and not room in found:
				found.append(room)
	return found


## Every cell of the footprint, in reading order.
func footprint_cells() -> Array[Vector2i]:
	return _cells_where(func(cell: Vector2i) -> bool: return is_footprint(cell))


## The cells that stop a walk: walls, windows and furniture.
func solid_cells() -> Array[Vector2i]:
	return _cells_where(func(cell: Vector2i) -> bool: return is_wall(cell) or FURNITURE.has(at(cell)))


## The cells that stop a shot in a fight: walls, not windows (owner ruling 2026-11-03, "Shots
## pass windows"), doorways or furniture.
func blocks_fire_cells() -> Array[Vector2i]:
	return _cells_where(func(cell: Vector2i) -> bool: return at(cell) == WALL)


## Rectangles of solid cells, for collision: maximal runs of wall cells along x, the wall cells left
## over in runs along z, and each piece of furniture.
func solid_rects() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	var taken := {}
	for j in size.y:
		var i := 0
		while i < size.x:
			var end := i
			while is_wall(Vector2i(end, j)):
				end += 1
			if end - i >= 2:
				rects.append(Rect2i(i, j, end - i, 1))
				for k in range(i, end):
					taken[Vector2i(k, j)] = true
			i = maxi(end, i + 1)
	for i in size.x:
		var j := 0
		while j < size.y:
			var end := j
			while is_wall(Vector2i(i, end)) and not taken.has(Vector2i(i, end)):
				end += 1
			if end > j:
				rects.append(Rect2i(i, j, 1, end - j))
			j = maxi(end, j + 1)
	for item: Dictionary in furniture:
		rects.append(item["rect"])
	return rects


## What is wrong with the plan, if anything: uneven rows, unknown characters, floor open to the
## outside, a room no doorway reaches, furniture that is not a rectangle, or a doorway or window
## off a straight wall.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	for j in rows.size():
		if rows[j].length() != size.x:
			found.append("row %d is %d long, not %d" % [j, rows[j].length(), size.x])
	for j in size.y:
		for i in size.x:
			var cell := Vector2i(i, j)
			var ch := at(cell)
			if not ch in [WALL, WINDOW, DOOR, FLOOR, OUTSIDE] and not FURNITURE.has(ch):
				found.append("unknown '%s' at %s" % [ch, cell])
			if is_room_cell(cell):
				for step: Vector2i in _STEPS:
					if at(cell + step) == OUTSIDE:
						found.append("floor at %s is open to the outside" % cell)
						break
			if (ch == DOOR or ch == WINDOW) and _straight_run(cell).is_empty():
				found.append("%s at %s is not in a straight wall" % [ch, cell])
	for item: Dictionary in furniture:
		var rect: Rect2i = item["rect"]
		for j in range(rect.position.y, rect.end.y):
			for i in range(rect.position.x, rect.end.x):
				if at(Vector2i(i, j)) != item["letter"]:
					found.append("furniture '%s' at %s is not a rectangle" % [item["letter"], rect])
					return found
	var reached := _reached_from_outside()
	for cell: Vector2i in _room:
		if not reached.has(cell):
			found.append("no doorway reaches %s" % cell)
			break
	return found


## The look of piece `index` while the party stands in `open_rooms` ("Your room opens"): low when
## it stands in front of one of those rooms, faded when it would hide part of one, else full. A
## post goes low only with every wall piece it stands with.
func state_of(index: int, open_rooms: Array[int]) -> int:
	if open_rooms.is_empty():
		return State.FULL
	var piece := pieces[index]
	if piece["kind"] == Kind.POST:
		var all_low := true
		for other: int in piece["with"]:
			all_low = all_low and state_of(other, open_rooms) == State.LOW
		if all_low:
			return State.LOW
	elif _meets(piece["drop"], open_rooms):
		return State.LOW
	return State.FADED if _meets(piece["fade"], open_rooms) else State.FULL


static func _meets(rooms: Array, open_rooms: Array[int]) -> bool:
	for room: int in rooms:
		if room in open_rooms:
			return true
	return false


# --- the roof ---------------------------------------------------------------------------------


## The L-infinity distance from point (x, z) to the nearest cell outside the footprint.
func outline_distance(x: float, z: float) -> float:
	var d := minf(minf(x, float(size.x) - x), minf(z, float(size.y) - z))
	for cell: Vector2i in _outside:
		var dx := maxf(0.0, maxf(float(cell.x) - x, x - float(cell.x) - 1.0))
		var dz := maxf(0.0, maxf(float(cell.y) - z, z - float(cell.y) - 1.0))
		d = minf(d, maxf(dx, dz))
	return maxf(d, 0.0)


## The roof's height at point (x, z): seated ROOF_SEAT above the wall tops at a post's outer corner
## and rising from there; at the footprint's outer edge it drops below the wall tops as eaves.
func roof_height(x: float, z: float) -> float:
	var seat_distance := 0.5 - POST_SIZE * 0.5
	return WALL_HEIGHT + ROOF_SEAT \
		+ tan(deg_to_rad(ROOF_PITCH_DEGREES)) * (outline_distance(x, z) - seat_distance)


## The roof as triangles of Vector3 (x, height, z), back to front. Each cell splits into four
## squares, each fanned from its centre, so every ridge, hip and valley lies on a triangle edge.
func roof_triangles() -> Array[PackedVector3Array]:
	var triangles: Array[PackedVector3Array] = []
	var heights := {}
	for j in size.y:
		for i in size.x:
			if not is_footprint(Vector2i(i, j)):
				continue
			for sz: float in [0.0, 0.5]:
				for sx: float in [0.0, 0.5]:
					var x0 := float(i) + sx
					var z0 := float(j) + sz
					var ring: Array[Vector2] = [
						Vector2(x0, z0), Vector2(x0 + 0.5, z0), Vector2(x0 + 0.5, z0 + 0.5),
						Vector2(x0, z0 + 0.5),
					]
					var middle := _roof_point(Vector2(x0 + 0.25, z0 + 0.25), heights)
					for k in 4:
						triangles.append(PackedVector3Array([
							_roof_point(ring[k], heights), _roof_point(ring[(k + 1) % 4], heights), middle,
						]))
	return triangles


func _roof_point(point: Vector2, heights: Dictionary) -> Vector3:
	if not heights.has(point):
		heights[point] = roof_height(point.x, point.y)
	return Vector3(point.x, float(heights[point]), point.y)


## The roof's top above cell `cell`'s centre, in cell units; 0 off the footprint.
func roof_top(cell: Vector2i) -> float:
	return roof_height(cell.x + 0.5, cell.y + 0.5) if is_footprint(cell) else 0.0


## Point (x, z) at height y on screen, relative to the grid's back corner.
static func project(x: float, z: float, y := 0.0) -> Vector2:
	return Vector2((x - z) * HALF_WIDTH, (x + z) * HALF_HEIGHT - y * PIXELS_PER_UNIT)


# --- parsing ----------------------------------------------------------------------------------


func _parse() -> void:
	size = Vector2i(rows[0].length() if rows.size() > 0 else 0, rows.size())
	_outside.clear()
	for j in size.y:
		for i in size.x:
			if at(Vector2i(i, j)) == OUTSIDE:
				_outside.append(Vector2i(i, j))
	_find_rooms()
	_find_furniture()
	_find_pieces()


func _cells_where(test: Callable) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for j in size.y:
		for i in size.x:
			if test.call(Vector2i(i, j)):
				found.append(Vector2i(i, j))
	return found


func _find_rooms() -> void:
	_room.clear()
	room_count = 0
	for j in size.y:
		for i in size.x:
			var start := Vector2i(i, j)
			if not is_room_cell(start) or _room.has(start):
				continue
			room_count += 1
			_room[start] = room_count
			var open: Array[Vector2i] = [start]
			while not open.is_empty():
				var cell: Vector2i = open.pop_back()
				for step: Vector2i in _STEPS:
					var next := cell + step
					if is_room_cell(next) and not _room.has(next):
						_room[next] = room_count
						open.append(next)


func _find_furniture() -> void:
	furniture.clear()
	var seen := {}
	for j in size.y:
		for i in size.x:
			var start := Vector2i(i, j)
			var letter := at(start)
			if not FURNITURE.has(letter) or seen.has(start):
				continue
			var rect := Rect2i(start, Vector2i.ONE)
			var open: Array[Vector2i] = [start]
			seen[start] = true
			while not open.is_empty():
				var cell: Vector2i = open.pop_back()
				rect = rect.merge(Rect2i(cell, Vector2i.ONE))
				for step: Vector2i in _STEPS:
					var next := cell + step
					if at(next) == letter and not seen.has(next):
						seen[next] = true
						open.append(next)
			furniture.append({"letter": letter, "kind": FURNITURE[letter], "rect": rect})


func _reached_from_outside() -> Dictionary:
	var reached := {}
	var open: Array[Vector2i] = []
	for j in size.y:
		for i in size.x:
			var cell := Vector2i(i, j)
			if at(cell) != DOOR:
				continue
			for step: Vector2i in _STEPS:
				if at(cell + step) == OUTSIDE:
					reached[cell] = true
					open.append(cell)
					break
	while not open.is_empty():
		var cell: Vector2i = open.pop_back()
		for step: Vector2i in _STEPS:
			var next := cell + step
			if (is_room_cell(next) or at(next) == DOOR) and not reached.has(next):
				reached[next] = true
				open.append(next)
	return reached


func _connects(cell: Vector2i) -> bool:
	return at(cell) in [WALL, WINDOW, DOOR]


## "x" or "z" when `cell` is a straight run of wall along that axis, else "".
func _straight_run(cell: Vector2i) -> String:
	var east := _connects(cell + Vector2i.RIGHT)
	var west := _connects(cell + Vector2i.LEFT)
	var south := _connects(cell + Vector2i.DOWN)
	var north := _connects(cell + Vector2i.UP)
	if east and west and not north and not south:
		return "x"
	if north and south and not east and not west:
		return "z"
	return ""


func _find_pieces() -> void:
	pieces.clear()
	for j in size.y:
		for i in size.x:
			var cell := Vector2i(i, j)
			var ch := at(cell)
			if not ch in [WALL, WINDOW, DOOR]:
				continue
			var centre := Vector2(i + 0.5, j + 0.5)
			var run := _straight_run(cell)
			if ch == DOOR:
				_add_piece(Kind.LINTEL, cell, run if run != "" else "x", 0, centre)
				continue
			if run != "":
				_add_piece(Kind.WINDOW if ch == WINDOW else Kind.WALL, cell, run, 0, centre)
				continue
			var first := pieces.size()
			if _connects(cell + Vector2i.LEFT):
				_add_piece(Kind.WALL, cell, "x", -1, Vector2(i + 0.25, j + 0.5))
			if _connects(cell + Vector2i.UP):
				_add_piece(Kind.WALL, cell, "z", -1, Vector2(i + 0.5, j + 0.25))
			if _connects(cell + Vector2i.RIGHT):
				_add_piece(Kind.WALL, cell, "x", 1, Vector2(i + 0.75, j + 0.5))
			if _connects(cell + Vector2i.DOWN):
				_add_piece(Kind.WALL, cell, "z", 1, Vector2(i + 0.5, j + 0.75))
			var with: Array[int] = []
			for index in range(first, pieces.size()):
				with.append(index)
			_add_piece(Kind.POST if not with.is_empty() else Kind.PILLAR, cell, "", 0, centre, with)
	_find_fades()


func _add_piece(kind: int, cell: Vector2i, run: String, half: int, base: Vector2, with: Array[int] = []) -> void:
	var drop: Array[int] = []
	if kind == Kind.PILLAR:
		drop = _rooms_behind([cell + Vector2i.UP, cell + Vector2i.LEFT, cell + Vector2i(-1, -1)])
	elif kind != Kind.POST:
		var across := Vector2i.UP if run == "x" else Vector2i.LEFT
		var along := Vector2i.RIGHT if run == "x" else Vector2i.DOWN
		var behind: Array[Vector2i] = [cell + across]
		if half == 0:
			behind.append_array([cell + across - along, cell + across + along])
		else:
			behind.append(cell + across + along * half)
		drop = _rooms_behind(behind)
	pieces.append({
		"kind": kind, "cell": cell, "run": run, "half": half, "base": base, "drop": drop,
		"fade": [] as Array[int], "hull": _hull(kind, cell, run, half), "with": with,
	})


func _rooms_behind(cells: Array[Vector2i]) -> Array[int]:
	var rooms: Array[int] = []
	for cell: Vector2i in cells:
		for room: int in rooms_of(cell):
			if not room in rooms:
				rooms.append(room)
	return rooms


## The piece at full height on screen: the hull of its box's corners.
func _hull(kind: int, cell: Vector2i, run: String, half: int) -> PackedVector2Array:
	var centre := Vector2(cell.x + 0.5, cell.y + 0.5)
	var lo := centre
	var hi := centre
	var bottom := 0.0
	match kind:
		Kind.POST, Kind.PILLAR:
			var radius := (POST_SIZE if kind == Kind.POST else PILLAR_SIZE) * 0.5
			lo -= Vector2(radius, radius)
			hi += Vector2(radius, radius)
		_:
			var along := Vector2(1, 0) if run == "x" else Vector2(0, 1)
			var across := Vector2(0, 1) if run == "x" else Vector2(1, 0)
			var from := -0.5 if half <= 0 else 0.0
			var to := 0.5 if half >= 0 else 0.0
			var a := centre + along * from - across * WALL_THICKNESS * 0.5
			var b := centre + along * to + across * WALL_THICKNESS * 0.5
			lo = Vector2(minf(a.x, b.x), minf(a.y, b.y))
			hi = Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
			if kind == Kind.LINTEL:
				bottom = DOOR_HEIGHT
	var corners := PackedVector2Array()
	for y: float in [bottom, WALL_HEIGHT]:
		for x: float in [lo.x, hi.x]:
			for z: float in [lo.y, hi.y]:
				corners.append(project(x, z, y))
	return Geometry2D.convex_hull(corners)


## For each full piece, the rooms it would hide part of: a cell of the room (or a doorway into it)
## drawn before the piece, with a watched height of a person there inside the piece's hull.
func _find_fades() -> void:
	var watched: Array[Dictionary] = []
	for j in size.y:
		for i in size.x:
			var cell := Vector2i(i, j)
			var rooms := rooms_of(cell)
			if rooms.is_empty():
				continue
			var points := PackedVector2Array()
			for height: float in WATCH_HEIGHTS:
				points.append(project(i + 0.5, j + 0.5, height))
			watched.append({"depth": float(i + j + 1), "points": points, "rooms": rooms})
	for piece: Dictionary in pieces:
		var hull: PackedVector2Array = piece["hull"]
		var box := Rect2(hull[0], Vector2.ZERO)
		for point: Vector2 in hull:
			box = box.expand(point)
		var base: Vector2 = piece["base"]
		var depth := base.x + base.y
		var fade: Array[int] = piece["fade"]
		for spot: Dictionary in watched:
			if float(spot["depth"]) >= depth:
				continue
			for point: Vector2 in spot["points"]:
				if box.has_point(point) and Geometry2D.is_point_in_polygon(point, hull):
					for room: int in spot["rooms"]:
						if not room in fade:
							fade.append(room)
					break
