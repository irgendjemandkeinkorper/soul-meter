extends GdUnitTestSuite
## WalkInBuilding (owner list item 35, 2026-11-03): a building the party walks into on the map.
## Its wall line is the footprint's outer ring of cells less the doorway ("One-cell wall line"),
## its `wall_polygons()` cover exactly those cells, and its look follows the party: the roof
## lifts when someone in the party stands on the footprint and fades when someone stands behind.

const ORIGIN := Vector2i(29, 43)
const SIZE := Vector2i(12, 9)
const DOORWAY: Array[Vector2i] = [Vector2i(9, 8), Vector2i(10, 8)]


## A stand-alone ground; `owned` leaves freeing it to its parent.
func _ground(owned := false) -> TileMapLayer:
	var ground := TileMapLayer.new()
	if not owned:
		auto_free(ground)
	ground.name = SolidFootprints.GROUND_NAME
	ground.tile_set = IsometricBlockout.GROUND_TILESET
	return ground


## A building bound to `ground` without entering the tree, as tools/paint_blocking.gd binds it.
func _building(ground: TileMapLayer) -> WalkInBuilding:
	var building: WalkInBuilding = auto_free(WalkInBuilding.new())
	building.origin_cell = ORIGIN
	building.cells = SIZE
	building.bind(ground, Transform2D.IDENTITY)
	return building


func _is_ring(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == SIZE.x - 1 or cell.y == SIZE.y - 1


func test_the_wall_line_is_the_outer_ring_less_the_doorway() -> void:
	var building := _building(_ground())
	var walls := building.wall_cells()
	# 2 × (12 + 9) − 4 corners counted twice − 2 doorway cells.
	assert_int(walls.size()).is_equal(36)
	for j in SIZE.y:
		for i in SIZE.x:
			var cell := Vector2i(i, j)
			var expected := _is_ring(cell) and not cell in DOORWAY
			assert_bool(ORIGIN + cell in walls) \
				.override_failure_message("footprint cell %s" % str(cell)).is_equal(expected)


func test_the_wall_polygons_cover_exactly_the_wall_cells() -> void:
	var ground := _ground()
	var building := _building(ground)
	var walls := building.wall_cells()
	var polygons := building.wall_polygons()
	# One strip per unbroken run: three whole sides and the front-left side either side of the door.
	assert_int(polygons.size()).is_equal(5)
	for j in range(-2, SIZE.y + 2):
		for i in range(-2, SIZE.x + 2):
			var cell := ORIGIN + Vector2i(i, j)
			var centre := ground.map_to_local(cell)
			var covered := false
			for polygon: PackedVector2Array in polygons:
				covered = covered or Geometry2D.is_point_in_polygon(centre, polygon)
			assert_bool(covered).override_failure_message("cell %s" % str(cell)).is_equal(cell in walls)


func test_corners_sit_on_the_ground_grid() -> void:
	var ground := _ground()
	var building := _building(ground)
	var back := ground.map_to_local(ORIGIN) - Vector2(0, 16)
	assert_vector(building.corner(0, 0)).is_equal_approx(back, Vector2.ONE * 0.01)
	assert_vector(building.corner(1, 0) - building.corner(0, 0)).is_equal_approx(Vector2(32, 16), Vector2.ONE * 0.01)
	assert_vector(building.corner(0, 1) - building.corner(0, 0)).is_equal_approx(Vector2(-32, 16), Vector2.ONE * 0.01)
	var outline := building.footprint_polygon()
	assert_int(outline.size()).is_equal(4)
	assert_vector(outline[2]).is_equal_approx(building.corner(SIZE.x, SIZE.y), Vector2.ONE * 0.01)


func test_a_door_on_another_side_moves_the_gap() -> void:
	var building := _building(_ground())
	building.door_side = WalkInBuilding.Side.BACK_LEFT
	building.door_start = 3
	var walls := building.wall_cells()
	assert_int(walls.size()).is_equal(36)
	assert_bool(ORIGIN + Vector2i(0, 3) in walls).is_false()
	assert_bool(ORIGIN + Vector2i(0, 4) in walls).is_false()
	assert_bool(ORIGIN + Vector2i(9, 8) in walls).is_true()
	assert_bool(building.is_doorway(WalkInBuilding.Side.BACK_LEFT, 4)).is_true()
	assert_bool(building.is_doorway(WalkInBuilding.Side.FRONT_LEFT, 9)).is_false()


## Owner ruling 2026-11-03, "Shots pass windows": a window cell stops a walk but not a shot. A
## corner cell holds a piece of two sides and lets a shot through only when both have a window.
func test_a_shot_passes_a_window_but_not_a_wall() -> void:
	var building := _building(_ground())
	var front := WalkInBuilding.Side.FRONT_LEFT
	var back_left := WalkInBuilding.Side.BACK_LEFT
	var back_right := WalkInBuilding.Side.BACK_RIGHT
	# Front cells 2 and 5; the back corner (0, 0) has a window on one of its two sides only.
	building.windows = {front: [2, 5], back_left: [0]}
	var walls := building.wall_cells()
	var fire := building.blocks_fire_cells()
	assert_int(fire.size()).is_equal(walls.size() - 2)
	for cell: Vector2i in [Vector2i(2, 8), Vector2i(5, 8)]:
		assert_bool(ORIGIN + cell in walls).override_failure_message("window %s walks" % str(cell)).is_true()
		assert_bool(ORIGIN + cell in fire).override_failure_message("window %s shoots" % str(cell)).is_false()
	assert_bool(ORIGIN in fire).override_failure_message("half-window corner").is_true()
	building.windows = {front: [2, 5], back_left: [0], back_right: [0]}
	assert_bool(ORIGIN in building.blocks_fire_cells()).override_failure_message("window corner").is_false()
	# The doorway stops neither.
	for cell: Vector2i in DOORWAY:
		assert_bool(ORIGIN + cell in building.blocks_fire_cells()).is_false()


## Item 35 polish (2026-11-04): the kit renders at a pitch where a floor cell is the 64 x 32 ground
## diamond, so a roof spanning the footprint lands on the grid at all four corners.
func test_a_kit_floor_tile_is_one_ground_cell() -> void:
	var manifest := _manifest()
	assert_float(float(manifest["spec"]["camera_pitch_degrees"])).is_equal_approx(30.0, 0.001)
	var size: Array = manifest["pieces"]["floor-planks"]["size"]
	assert_int(int(size[0])).is_equal(64)
	# The 32 px diamond plus the plank edge below it.
	assert_int(int(size[1])).is_between(32, 34)


## Item 35 polish (2026-11-04): the roof sits on the post tops, so no pixel of a front post or
## front wall shows above its outline (the corner posts used to).
func test_the_roof_covers_the_posts_and_front_walls() -> void:
	var building := _building(_ground())
	var pieces: Dictionary = _manifest()["pieces"]
	var roof_entry: Dictionary = pieces["roof-%dx%d" % [SIZE.x, SIZE.y]]
	var roof := _kit_image(roof_entry)
	var roof_at := building.corner(SIZE.x, SIZE.y) - _pivot(roof_entry)
	var roof_top := PackedInt32Array()
	for x in roof.get_width():
		roof_top.append(_first_opaque_row(roof, x))
	var placed: Array = []
	for point: Vector2 in [building.corner(SIZE.x, 0), building.corner(SIZE.x, SIZE.y), building.corner(0, SIZE.y)]:
		placed.append(["post", point])
	for i in SIZE.x:
		placed.append(["wall-x", building.corner(i + 0.5, SIZE.y)])
	for j in SIZE.y:
		placed.append(["wall-z", building.corner(SIZE.x, j + 0.5)])
	for item: Array in placed:
		var entry: Dictionary = pieces[item[0]]
		var image := _kit_image(entry)
		var at: Vector2 = (item[1] as Vector2) - _pivot(entry)
		var showing := 0
		for x in image.get_width():
			var top := _first_opaque_row(image, x)
			if top < 0:
				continue
			var roof_x := roundi(at.x + x - roof_at.x)
			var covered := roof_x >= 0 and roof_x < roof.get_width() and roof_top[roof_x] >= 0 \
				and at.y + top >= roof_at.y + roof_top[roof_x] - 0.5
			showing += 0 if covered else 1
		assert_int(showing).override_failure_message("%s at %s shows above the roof" % [item[0], item[1]]).is_equal(0)


func _manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(WalkInBuilding.KIT_MANIFEST))


func _kit_image(entry: Dictionary) -> Image:
	var image := (load(WalkInBuilding.KIT_DIR + str(entry["file"])) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	return image


func _pivot(entry: Dictionary) -> Vector2:
	var pivot: Array = entry["pivot"]
	return Vector2(float(pivot[0]), float(pivot[1]))


## The first row of column `x` with an opaque pixel, or -1.
func _first_opaque_row(image: Image, x: int) -> int:
	for y in image.get_height():
		if image.get_pixel(x, y).a > 0.0:
			return y
	return -1


func test_the_roof_lifts_for_the_party_and_fades_for_someone_behind() -> void:
	var map: Node2D = auto_free(Node2D.new())
	map.add_child(_ground(true))
	var building: WalkInBuilding = WalkInBuilding.new()
	building.origin_cell = ORIGIN
	building.cells = SIZE
	map.add_child(building)
	var walker := Node2D.new()
	walker.add_to_group(&"player")
	walker.position = Vector2(-4000, -4000)
	map.add_child(walker)
	add_child(map)
	await await_idle_frame()

	var floor_layer := building.get_node("Floor")
	assert_int(floor_layer.get_child_count()).is_equal(SIZE.x * SIZE.y)
	# Front: 10 walls and 2 lintels on the door side, 9 walls on the other, 5 posts.
	assert_int(building.get_node("FrontWalls").get_child_count()).is_equal(26)
	assert_int(building.get_node("FrontStubs").get_child_count()).is_equal(24)
	assert_int(building.get_node("BackWalls").get_child_count()).is_equal(22)
	assert_int(building.current_look()).is_equal(WalkInBuilding.Look.OUTSIDE)
	assert_bool(building.get_node("BackWalls").visible).is_false()

	var middle := building.corner(SIZE.x * 0.5, SIZE.y * 0.5)
	walker.position = building.to_global(middle)
	await _physics_frames(2)
	assert_int(building.current_look()).is_equal(WalkInBuilding.Look.INSIDE)
	assert_bool(building.get_node("FrontStubs").visible).is_true()
	assert_bool(building.get_node("BackWalls").visible).is_true()
	await get_tree().create_timer(WalkInBuilding.FADE_DURATION + 0.1).timeout
	assert_float(building.get_node("FrontWalls").modulate.a).is_equal_approx(0.0, 0.01)

	# Behind the back corner, under the roof's silhouette but off the footprint.
	walker.position = building.to_global(building.corner(0, 0) - Vector2(0, 40))
	await _physics_frames(2)
	assert_int(building.current_look()).is_equal(WalkInBuilding.Look.SEEN_THROUGH)
	await get_tree().create_timer(WalkInBuilding.FADE_DURATION + 0.1).timeout
	assert_float(building.get_node("FrontWalls").modulate.a) \
		.is_equal_approx(DS.FACADE_OCCLUDED_ALPHA, 0.01)

	walker.position = Vector2(-4000, -4000)
	await _physics_frames(2)
	assert_int(building.current_look()).is_equal(WalkInBuilding.Look.OUTSIDE)
	assert_bool(building.get_node("BackWalls").visible).is_false()


func _physics_frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame
