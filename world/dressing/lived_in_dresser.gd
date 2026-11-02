class_name LivedInDresser
extends RefCounted
## The rules that dress a map densely, Fallout-style (lived-in maps M3, owner 2026-11-02:
## "dense; small decor walkable"). Pure: a layout and a catalogue in, placements out, the same
## for the same seed. `tools/dress_location.gd` reads the layout from a live map and writes
## the placements as a generated scene.
##
## Layout keys:
##   origin: Vector2       world centre of ground cell (0, 0); cells are 64x32 diamonds
##   cells: Dictionary     playable ground cells (Vector2i -> true)
##   occupied: Dictionary  cells under a static body (buildings, existing solid props)
##   structures: Array     screen-space Rect2 contact footprints of buildings (wall bases)
##   keep_clear: Array     Rect2 zones nothing standing may enter (spawns, exits, doors)
##   corridor: Dictionary  main-route cells; walkable for everyone, no standing props
##   playable: Rect2       the area inside the map's boundary walls
##   roads: Array          polylines (Array of Vector2) to pave as worn-cobble bands
## Catalogue rows: {id, texture, category, placement, height_class, content_height}.
##
## Every density below is PROVISIONAL, tuned by eye on Kesselford.

const HALF_TILE := Vector2(32.0, 16.0)
## Ground decals: the chance a playable cell seeds one, and the box (px) another must clear.
const GROUND_CHANCE := 0.09
const GROUND_GAP := Vector2(150.0, 76.0)
const ROUTE_DECAL_STEP := 7
## Wall-base clusters: spacing along a building front, and the chance one is placed.
const WALL_SPACING := Vector2(64.0, 104.0)
const WALL_CLUSTER_CHANCE := 0.85
const YARD_RANGE := Vector2(90.0, 280.0)
const YARD_CHANCE := 0.1
const YARD_SPACING := 120.0
const EDGE_CHANCE := 0.2
const OPEN_GROWTH_CHANCE := 0.035
const OPEN_STORY_CHANCE := 0.009
## A road is a band of overlapping worn-cobble decals this far apart along its line.
const ROAD_STEP := 96.0
const ROAD_PIECES: Array[String] = [
	"kf-paving--broken-cobbles", "kf-road-cobble--sinking-edge", "kf-paving--moss-flags",
	"kf-paving--cracks", "kf-road-cobble--frayed-end",
]
## Standing props keep this far apart (contact points), so clusters do not interpenetrate.
const FORD_STEP := 64.0
const FORD_MUD: Array[String] = ["kf-ground-patch--wet-mud", "kf-stain--damp"]
const FORD_REEDS: Array[String] = ["kf-reeds--clump", "kf-weeds--tuft-b", "kf-fern"]
const STANDING_GAP := 26.0
const COVER_CLASSES: Array[String] = ["waist", "head", "tall"]

const WALL_ANCHORS: Array[String] = [
	"kf-barrel--upright", "kf-barrel--tipped", "kf-barrels--plank-pair", "kf-barrel--rain-downspout",
	"kf-crate--small", "kf-sacks--pile", "kf-firewood--low-heap", "kf-washtub--washboard", "kf-planks--stack",
]
const BASE_PATCHES: Array[String] = [
	"kf-ground-patch--packed-earth", "kf-ground-patch--wet-mud", "kf-ground-patch--trampled-grass",
]
const PUDDLES: Array[String] = ["kf-puddle--shallow", "kf-puddle--long", "kf-puddle--rain-ringed"]
const ROUTE_DECALS: Array[String] = ["kf-ruts--straight", "kf-ruts--curve", "kf-trail--footprints-hooves"]
const EDGE_GROWTH: Array[String] = [
	"kf-weeds--tuft-a", "kf-weeds--tuft-b", "kf-weeds--tuft-c", "kf-nettles--clump", "kf-cobbles--loose",
	"kf-branch--dead", "kf-fern",
]


static func dress(layout: Dictionary, catalog: Array[Dictionary], seed_value: int) -> Dictionary:
	var state := {
		"rng": RandomNumberGenerator.new(),
		"layout": layout,
		"by_id": {},
		"placements": [] as Array[Dictionary],
		"standing": {},  # cell -> Array[Vector2] contact points
		"blocked": {},
		"cover": {},
	}
	(state["rng"] as RandomNumberGenerator).seed = seed_value
	for row: Dictionary in catalog:
		(state["by_id"] as Dictionary)[str(row["id"])] = row
	var cells := _sorted_cells(layout["cells"] as Dictionary)
	_dress_roads(state)
	_dress_fords(state)
	_dress_ground(state, cells)
	_dress_wall_bases(state)
	_dress_yards(state, cells)
	_dress_path_edges(state, cells)
	_dress_open_ground(state, cells)
	var blocked: Array[Vector2i] = []
	blocked.assign(_sorted_cells(state["blocked"]))
	var cover: Array[Vector2i] = []
	cover.assign(_sorted_cells(state["cover"]))
	return {"placements": state["placements"], "blocked": blocked, "cover": cover}


static func cell_center(origin: Vector2, cell: Vector2i) -> Vector2:
	return origin + Vector2((cell.x - cell.y) * HALF_TILE.x, (cell.x + cell.y) * HALF_TILE.y)


static func cell_at(origin: Vector2, point: Vector2) -> Vector2i:
	var d := point - origin
	var a := d.x / HALF_TILE.x
	var b := d.y / HALF_TILE.y
	return Vector2i(roundi((a + b) * 0.5), roundi((b - a) * 0.5))


static func role_ids(catalog: Array[Dictionary], test: Callable) -> Array[String]:
	var ids: Array[String] = []
	for row: Dictionary in catalog:
		if test.call(row):
			ids.append(str(row["id"]))
	return ids


# --- passes ----------------------------------------------------------------------------------


static func _dress_ground(state: Dictionary, cells: Array[Vector2i]) -> void:
	var layout: Dictionary = state["layout"]
	var rng: RandomNumberGenerator = state["rng"]
	var litter := _ids(state, func(row: Dictionary) -> bool:
		return str(row["placement"]) == "ground" and not BASE_PATCHES.has(str(row["id"])) \
			and not PUDDLES.has(str(row["id"])) and not ROUTE_DECALS.has(str(row["id"])) \
			and not str(row["id"]).begins_with("kf-road") and str(row["category"]) == "ground")
	var patches := _present(state, BASE_PATCHES)
	var puddles := _present(state, PUDDLES)
	var route := _present(state, ROUTE_DECALS)
	var corridor: Dictionary = layout["corridor"]
	# Scattered, not on a lattice: a lattice reads as tiles. Each decal keeps GROUND_GAP px
	# from the last few hundred, so the ground changes underfoot without stamping a pattern.
	var placed: Array[Vector2] = []
	for cell: Vector2i in _shuffled(rng, cells):
		if rng.randf() >= GROUND_CHANCE:
			continue
		var at := cell_center(layout["origin"], cell) + Vector2(rng.randf_range(-32.0, 32.0), rng.randf_range(-16.0, 16.0))
		if placed.any(func(other: Vector2) -> bool: return absf(other.x - at.x) < GROUND_GAP.x and absf(other.y - at.y) < GROUND_GAP.y):
			continue
		var roll := rng.randf()
		var pool := litter if roll < 0.55 else (patches if roll < 0.88 else puddles)
		if pool.is_empty():
			pool = litter if not litter.is_empty() else patches
		if pool.is_empty():
			continue
		var id := _pick(rng, pool)
		_place_ground(state, id, at)
		placed.append(at)
	for cell: Vector2i in cells:
		if corridor.has(cell) and posmod(cell.x + cell.y, ROUTE_DECAL_STEP) == 0 \
				and rng.randf() < 0.4 and not route.is_empty():
			_place_ground(state, _pick(rng, route), cell_center(layout["origin"], cell))


static func _dress_roads(state: Dictionary) -> void:
	var rng: RandomNumberGenerator = state["rng"]
	var pieces := _present(state, ROAD_PIECES)
	if pieces.is_empty():
		return
	for line: Array in (state["layout"] as Dictionary).get("roads", []):
		for index: int in range(line.size() - 1):
			var from: Vector2 = line[index]
			var to: Vector2 = line[index + 1]
			var steps := maxi(1, ceili(from.distance_to(to) / ROAD_STEP))
			for step: int in steps:
				var at := from.lerp(to, step / float(steps)) + Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-10.0, 10.0))
				_place_ground(state, _pick(rng, pieces), at, true)


## A wet bank along each ford line: puddles wander either side of it, mud spreads to one
## side, and reeds stand off the line where nothing else blocks. Replaces stamped puddle rows.
static func _dress_fords(state: Dictionary) -> void:
	var rng: RandomNumberGenerator = state["rng"]
	var puddles := _present(state, PUDDLES)
	var mud := _present(state, FORD_MUD)
	var reeds := _present(state, FORD_REEDS)
	for line: Array in (state["layout"] as Dictionary).get("fords", []):
		for index: int in range(line.size() - 1):
			var from: Vector2 = line[index]
			var to: Vector2 = line[index + 1]
			var side := (to - from).orthogonal().normalized()
			var steps := maxi(1, ceili(from.distance_to(to) / FORD_STEP))
			for step: int in steps:
				var along := from.lerp(to, (step + rng.randf_range(-0.3, 0.3)) / float(steps))
				if not puddles.is_empty() and rng.randf() < 0.7:
					_place_ground(state, _pick(rng, puddles), along + side * rng.randf_range(-70.0, 70.0))
				if not mud.is_empty() and rng.randf() < 0.55:
					_place_ground(state, _pick(rng, mud), along + side * rng.randf_range(-150.0, 40.0))
				if not reeds.is_empty() and rng.randf() < 0.45:
					var lean := 1.0 if rng.randf() < 0.5 else -1.0
					_place_standing(state, _pick(rng, reeds), along + side * lean * rng.randf_range(60.0, 140.0))


static func _dress_wall_bases(state: Dictionary) -> void:
	var rng: RandomNumberGenerator = state["rng"]
	var anchors := _present(state, WALL_ANCHORS)
	var smalls := _ids(state, func(row: Dictionary) -> bool:
		return str(row["category"]) == "wall-base" and str(row["placement"]) == "walkable")
	if anchors.is_empty() and smalls.is_empty():
		return
	for rect: Rect2 in (state["layout"] as Dictionary)["structures"]:
		var x := rect.position.x + rng.randf_range(12.0, 40.0)
		while x < rect.end.x - 12.0:
			if rng.randf() < WALL_CLUSTER_CHANCE:
				_cluster(state, Vector2(x, rect.end.y + rng.randf_range(10.0, 24.0)), anchors, smalls)
			x += rng.randf_range(WALL_SPACING.x, WALL_SPACING.y)
		for side: float in [rect.position.x - 26.0, rect.end.x + 26.0]:
			if rng.randf() < 0.55:
				_cluster(state, Vector2(side, rect.end.y - 2.0), anchors, smalls)


static func _cluster(state: Dictionary, at: Vector2, anchors: Array[String], smalls: Array[String]) -> void:
	var rng: RandomNumberGenerator = state["rng"]
	var placed_anchor := false
	if not anchors.is_empty():
		placed_anchor = _place_standing(state, _pick(rng, anchors), at)
	if not placed_anchor and smalls.is_empty():
		return
	for _index: int in rng.randi_range(2, 4):
		if smalls.is_empty():
			break
		var offset := Vector2(rng.randf_range(26.0, 58.0) * (1.0 if rng.randf() < 0.5 else -1.0),
			rng.randf_range(-6.0, 18.0))
		_place_standing(state, _pick(rng, smalls), at + offset)


static func _dress_yards(state: Dictionary, cells: Array[Vector2i]) -> void:
	var rng: RandomNumberGenerator = state["rng"]
	var layout: Dictionary = state["layout"]
	var yard := _ids(state, func(row: Dictionary) -> bool:
		return str(row["category"]) == "yard" and str(row["placement"]) != "ground")
	if yard.is_empty():
		return
	var placed: Array[Vector2] = []
	for cell: Vector2i in _shuffled(rng, cells):
		if rng.randf() >= YARD_CHANCE:
			continue
		var point := cell_center(layout["origin"], cell)
		var distance := _structure_distance(layout["structures"], point)
		if distance < YARD_RANGE.x or distance > YARD_RANGE.y:
			continue
		if placed.any(func(other: Vector2) -> bool: return other.distance_to(point) < YARD_SPACING):
			continue
		if _place_standing(state, _pick(rng, yard), point):
			placed.append(point)


static func _dress_path_edges(state: Dictionary, cells: Array[Vector2i]) -> void:
	var rng: RandomNumberGenerator = state["rng"]
	var layout: Dictionary = state["layout"]
	var growth := _present(state, EDGE_GROWTH)
	if growth.is_empty():
		return
	var corridor: Dictionary = layout["corridor"]
	for cell: Vector2i in cells:
		if corridor.has(cell) or not _touches(corridor, cell) or rng.randf() >= EDGE_CHANCE:
			continue
		var jitter := Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-8.0, 8.0))
		_place_standing(state, _pick(rng, growth), cell_center(layout["origin"], cell) + jitter)


static func _dress_open_ground(state: Dictionary, cells: Array[Vector2i]) -> void:
	var rng: RandomNumberGenerator = state["rng"]
	var layout: Dictionary = state["layout"]
	var growth := _ids(state, func(row: Dictionary) -> bool:
		return str(row["category"]) == "growth" and not EDGE_GROWTH.has(str(row["id"])))
	var stories := _ids(state, func(row: Dictionary) -> bool: return str(row["category"]) == "story")
	for cell: Vector2i in cells:
		var roll := rng.randf()
		var pool: Array[String] = []
		if roll < OPEN_STORY_CHANCE:
			pool = stories
		elif roll < OPEN_STORY_CHANCE + OPEN_GROWTH_CHANCE:
			pool = growth
		if pool.is_empty():
			continue
		var jitter := Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-10.0, 10.0))
		_place_standing(state, _pick(rng, pool), cell_center(layout["origin"], cell) + jitter)


# --- placement --------------------------------------------------------------------------------


static func _place_ground(state: Dictionary, id: String, at: Vector2, road: bool = false) -> void:
	var layout: Dictionary = state["layout"]
	if not (layout["playable"] as Rect2).has_point(at):
		return
	var rng: RandomNumberGenerator = state["rng"]
	var row: Dictionary = (state["by_id"] as Dictionary)[id]
	var kind := "strip" if id.begins_with("kf-road") or id.begins_with("kf-ruts") else \
		("patch" if BASE_PATCHES.has(id) or PUDDLES.has(id) or road else "small")
	(state["placements"] as Array[Dictionary]).append({
		"id": id, "texture": row["texture"], "layer": "ground", "position": at.round(),
		"scale": PropScale.ground_scale(kind) * rng.randf_range(0.85, 1.2),
		"flip_h": rng.randf() < 0.5, "solid": false,
		"alpha": 1.0 if road else (rng.randf_range(0.4, 0.7) if BASE_PATCHES.has(id) else rng.randf_range(0.75, 1.0)),
	})


## Places a standing prop if its contact point is free; returns whether it was placed.
static func _place_standing(state: Dictionary, id: String, at: Vector2) -> bool:
	var layout: Dictionary = state["layout"]
	var row: Dictionary = (state["by_id"] as Dictionary)[id]
	var solid := str(row["placement"]) == "solid"
	if not (layout["playable"] as Rect2).has_point(at):
		return false
	var cell := cell_at(layout["origin"], at)
	if not (layout["cells"] as Dictionary).has(cell) or (layout["occupied"] as Dictionary).has(cell):
		return false
	if (layout["corridor"] as Dictionary).has(cell) or (state["blocked"] as Dictionary).has(cell):
		return false
	for zone: Rect2 in layout["keep_clear"]:
		if zone.has_point(at):
			return false
	var standing: Dictionary = state["standing"]
	if solid and standing.has(cell):
		return false
	for neighbour: Vector2i in [cell, cell + Vector2i.RIGHT, cell + Vector2i.LEFT, cell + Vector2i.UP, cell + Vector2i.DOWN]:
		for other: Vector2 in standing.get(neighbour, []):
			if other.distance_to(at) < STANDING_GAP:
				return false
	var rng: RandomNumberGenerator = state["rng"]
	var height_class := str(row["height_class"])
	(state["placements"] as Array[Dictionary]).append({
		"id": id, "texture": row["texture"], "layer": "props", "position": at.round(),
		"scale": PropScale.standing_scale(float(row["content_height"]), height_class) * rng.randf_range(0.92, 1.08),
		"flip_h": rng.randf() < 0.5, "solid": solid, "cell": cell,
	})
	if not standing.has(cell):
		standing[cell] = []
	(standing[cell] as Array).append(at)
	if solid:
		(state["blocked"] as Dictionary)[cell] = true
		if COVER_CLASSES.has(height_class):
			(state["cover"] as Dictionary)[cell] = true
	return true


# --- helpers ----------------------------------------------------------------------------------


static func _ids(state: Dictionary, test: Callable) -> Array[String]:
	var ids: Array[String] = []
	for id: String in _sorted_keys(state["by_id"]):
		if test.call((state["by_id"] as Dictionary)[id]):
			ids.append(id)
	return ids


static func _present(state: Dictionary, wanted: Array[String]) -> Array[String]:
	var ids: Array[String] = []
	for id: String in wanted:
		if (state["by_id"] as Dictionary).has(id):
			ids.append(id)
	return ids


static func _pick(rng: RandomNumberGenerator, pool: Array[String]) -> String:
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _touches(cells: Dictionary, cell: Vector2i) -> bool:
	for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		if cells.has(cell + step):
			return true
	return false


static func _structure_distance(structures: Array, point: Vector2) -> float:
	var best := INF
	for rect: Rect2 in structures:
		var nearest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
		best = minf(best, nearest.distance_to(point))
	return best


static func _sorted_cells(cells: Dictionary) -> Array[Vector2i]:
	var sorted: Array[Vector2i] = []
	sorted.assign(cells.keys())
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return sorted


static func _sorted_keys(values: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	keys.assign(values.keys())
	keys.sort()
	return keys


static func _shuffled(rng: RandomNumberGenerator, cells: Array[Vector2i]) -> Array[Vector2i]:
	var copy := cells.duplicate()
	for index: int in range(copy.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held: Vector2i = copy[index]
		copy[index] = copy[swap]
		copy[swap] = held
	return copy
