extends GdUnitTestSuite
## Hex grid H1 (owner item 34; docs/design/hex-grid-plan-2026-11-03.md): on every shipped map,
## hexes reach the places the square grid reaches and open no new ones. Both grids are built
## the way `ClickMoveController` builds the player's grid (its clearance, blocking projected onto
## the ground), from the map's own layers. Each map is loaded for real, because structures fill
## the blocking layer at runtime, and the game state is restored after every map.

const MAPS: Array[String] = [
	"res://world/kesselford.tscn",
	"res://world/starting_town.tscn",
	"res://world/interiors/lower_trial_hall.tscn",
	"res://world/test_room.tscn",
	"res://world/dorthkor_road.tscn",
	"res://world/wound_lip.tscn",
	"res://world/ashlaren.tscn",
	"res://world/hollowmere.tscn",
	"res://world/long_verge.tscn",
	"res://world/fixtures/structure_yard.tscn",
]
## A square area this big must survive as one hex area.
const LARGE_AREA := 30
## Of a large square area, the share whose hexes must sit in its one hex area.
const SAME_AREA_SHARE := 0.9
## Hexes are solid when a corner pulled halfway in touches a wall, so walls thicken a little.
## The share of open square ground that may land on a solid hex.
const MAX_LOST_SHARE := 0.2


func test_hexes_reach_what_the_square_grid_reaches_on_every_map() -> void:
	var blocked_maps := 0
	for map_path: String in MAPS:
		var scene := await _load_map(map_path)
		var ground := scene.find_child("IsometricGround", true, false) as TileMapLayer
		var blocking := scene.find_child("Blocking", true, false) as TileMapLayer
		assert_object(ground).override_failure_message("%s has no IsometricGround" % map_path).is_not_null()
		if ground == null:
			await _unload(scene)
			continue
		var square := IsoGrid.new()
		square.hex_mode = false
		square.build(ground, blocking, ClickMoveController.STATIC_CLEARANCE_CELLS, true)
		var hexes := IsoGrid.new()
		hexes.hex_mode = true
		hexes.build(ground, blocking, ClickMoveController.STATIC_CLEARANCE_CELLS, true)
		var square_area := _square_areas(square)
		var hex_area := _hex_areas(hexes)

		var hex_areas_of_square := {}  # square area -> {hex area: cells}
		var square_areas_of_hex := {}  # hex area -> {square area: true}
		for cell: Vector2i in square_area:
			var hex := hexes.world_to_cell(square.cell_to_world(cell))
			if not hex_area.has(hex):
				continue
			var s: int = square_area[cell]
			var h: int = hex_area[hex]
			var counts: Dictionary = hex_areas_of_square.get_or_add(s, {})
			counts[h] = int(counts.get(h, 0)) + 1
			(square_areas_of_hex.get_or_add(h, {}) as Dictionary)[s] = true

		# No new connections: a hex area never joins two square areas.
		var joined := 0
		for h: int in square_areas_of_hex:
			if (square_areas_of_hex[h] as Dictionary).size() > 1:
				joined += 1
		assert_int(joined).override_failure_message(
			"%s: %d hex areas join square areas a wall keeps apart" % [map_path, joined]
		).is_equal(0)

		# The same places: each large square area stays one hex area.
		var sizes := {}
		for cell: Vector2i in square_area:
			sizes[square_area[cell]] = int(sizes.get(square_area[cell], 0)) + 1
		for s: int in sizes:
			if int(sizes[s]) < LARGE_AREA or not hex_areas_of_square.has(s):
				continue
			var counts: Dictionary = hex_areas_of_square[s]
			var total := 0
			var largest := 0
			for h: int in counts:
				total += int(counts[h])
				largest = maxi(largest, int(counts[h]))
			assert_float(float(largest) / float(total)).override_failure_message(
				"%s: a square area of %d cells split into %d hex areas" % [map_path, sizes[s], counts.size()]
			).is_greater_equal(SAME_AREA_SHARE)

		if square_area.size() < square.get_used_rect().get_area():
			blocked_maps += 1
		# Thickening: of the hexes standing on open square ground, the share that are solid.
		var on_open := 0
		var lost := 0
		var rect := hexes.get_used_rect()
		for r in range(rect.position.y, rect.end.y):
			for q in range(rect.position.x, rect.end.x):
				var hex := Vector2i(q, r)
				if not hexes.is_in_bounds(hex):
					continue
				if not square_area.has(square.world_to_cell(hexes.cell_to_world(hex))):
					continue
				on_open += 1
				if hexes.is_blocked_for(hex):
					lost += 1
		var lost_share := float(lost) / float(maxi(on_open, 1))
		print("HEXMAP %s open_cells=%d/%d open_hexes=%d square_areas=%d hex_areas=%d lost=%.3f" % [
			map_path.get_file(), square_area.size(), square.get_used_rect().get_area(),
			hex_area.size(), sizes.size(), _count_areas(hex_area), lost_share,
		])
		assert_float(lost_share).override_failure_message(
			"%s: %.0f%% of the open ground lands on solid hexes" % [map_path, lost_share * 100.0]
		).is_less_equal(MAX_LOST_SHARE)
		await _unload(scene)
	# Most maps stop the player with physics colliders and paint no grid walls; the town, the
	# test room and the structure yard do. A pass over empty ground alone would prove nothing.
	assert_int(blocked_maps).is_greater_equal(3)


var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)


func after_test() -> void:
	GameState.from_dict(_saved_state)


func _load_map(map_path: String) -> Node:
	var scene := (load(map_path) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	return scene


## Frees the map and puts the game state back, so arrival hooks leak into no later map or suite.
func _unload(scene: Node) -> void:
	scene.queue_free()
	await get_tree().process_frame
	GameState.from_dict(_saved_state)


## Connected open ground on the square grid, by the pathing rule (eight neighbours; a diagonal
## needs both flanking cells open).
func _square_areas(grid: IsoGrid) -> Dictionary:
	var area := {}
	var rect := grid.get_used_rect()
	var next := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var start := Vector2i(x, y)
			if area.has(start) or grid.is_blocked_for(start):
				continue
			area[start] = next
			var open: Array[Vector2i] = [start]
			while not open.is_empty():
				var cell: Vector2i = open.pop_back()
				for offset: Vector2i in IsoGrid.NEIGHBOR_OFFSETS:
					var other := cell + offset
					if area.has(other) or grid.is_blocked_for(other):
						continue
					if offset.x != 0 and offset.y != 0:
						if grid.is_blocked_for(Vector2i(other.x, cell.y)) or grid.is_blocked_for(Vector2i(cell.x, other.y)):
							continue
					area[other] = next
					open.append(other)
			next += 1
	return area


## Connected open ground on the hex grid: six neighbours, and a step's walk line stays off walls.
func _hex_areas(grid: IsoGrid) -> Dictionary:
	var area := {}
	var rect := grid.get_used_rect()
	var next := 0
	for r in range(rect.position.y, rect.end.y):
		for q in range(rect.position.x, rect.end.x):
			var start := Vector2i(q, r)
			if area.has(start) or not grid.is_in_bounds(start) or grid.is_blocked_for(start):
				continue
			area[start] = next
			var open: Array[Vector2i] = [start]
			while not open.is_empty():
				var hex: Vector2i = open.pop_back()
				for offset: Vector2i in HexMath.DIRECTIONS:
					var other := hex + offset
					if area.has(other) or grid.is_blocked_for(other) or grid._is_hex_edge_walled(hex, other):
						continue
					area[other] = next
					open.append(other)
			next += 1
	return area


func _count_areas(area: Dictionary) -> int:
	var seen := {}
	for key: Variant in area:
		seen[area[key]] = true
	return seen.size()
