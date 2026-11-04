extends GdUnitTestSuite
## WalkInBuilding (owner list item 35, 2026-11-03; layouts and "Your room opens", 2026-11-04): a
## building the party walks into on the map, laid out from a `BuildingLayout` on the ground cells.
## Its solid shapes cover exactly the plan's solid cells, a turn moves them with the grid, the roof
## covers every wall piece, and its look follows the party room by room.

const ORIGIN := Vector2i(29, 43)
const SHOP := "res://world/buildings/layouts/shop.tres"
const LAYOUTS: Array[String] = [
	"res://world/buildings/layouts/tavern.tres", SHOP,
	"res://world/buildings/layouts/cottage.tres", "res://world/buildings/layouts/warehouse.tres",
]


## A stand-alone ground; `owned` leaves freeing it to its parent.
func _ground(owned := false) -> TileMapLayer:
	var ground := TileMapLayer.new()
	if not owned:
		auto_free(ground)
	ground.name = SolidFootprints.GROUND_NAME
	ground.tile_set = IsometricBlockout.GROUND_TILESET
	return ground


## A building bound to `ground` without entering the tree, as tools/paint_blocking.gd binds it.
func _building(ground: TileMapLayer, layout_path := SHOP, turns := 0) -> WalkInBuilding:
	var building: WalkInBuilding = auto_free(WalkInBuilding.new())
	building.layout = load(layout_path)
	building.quarter_turns = turns
	building.origin_cell = ORIGIN
	building.bind(ground, Transform2D.IDENTITY)
	return building


func test_the_solid_polygons_cover_exactly_the_solid_cells() -> void:
	var ground := _ground()
	for layout_path: String in LAYOUTS:
		var building := _building(ground, layout_path)
		var solid := building.solid_cells()
		var polygons := building.solid_polygons()
		var size := building.plan().size
		for j in range(-1, size.y + 1):
			for i in range(-1, size.x + 1):
				var cell := ORIGIN + Vector2i(i, j)
				var centre := ground.map_to_local(cell)
				var covered := false
				for polygon: PackedVector2Array in polygons:
					covered = covered or Geometry2D.is_point_in_polygon(centre, polygon)
				assert_bool(covered).override_failure_message("%s cell %s" % [layout_path.get_file(), cell]) \
					.is_equal(cell in solid)


func test_corners_sit_on_the_ground_grid() -> void:
	var ground := _ground()
	var building := _building(ground)
	var back := ground.map_to_local(ORIGIN) - Vector2(0, 16)
	assert_vector(building.corner(0, 0)).is_equal_approx(back, Vector2.ONE * 0.01)
	assert_vector(building.corner(1, 0) - building.corner(0, 0)).is_equal_approx(Vector2(32, 16), Vector2.ONE * 0.01)
	assert_vector(building.corner(0, 1) - building.corner(0, 0)).is_equal_approx(Vector2(-32, 16), Vector2.ONE * 0.01)
	assert_vector(Vector2(building.layout_cell_at(ground.map_to_local(ORIGIN + Vector2i(3, 5))))).is_equal(Vector2(3, 5))


## A quarter turn lays the turned grid from the same origin: the front row runs down the right.
func test_a_turn_lays_the_turned_plan_on_the_map() -> void:
	var ground := _ground()
	var building := _building(ground, "res://world/buildings/layouts/warehouse.tres", 1)
	var plan := building.plan()
	assert_vector(Vector2(plan.size)).is_equal(Vector2(6, 14))
	var footprint := building.footprint_cells()
	assert_int(footprint.size()).is_equal(6 * 14)
	for cell: Vector2i in footprint:
		assert_bool(plan.is_footprint(cell - ORIGIN)).is_true()
	# The front doorway (front row cells 4 and 5) is open in the right-hand column.
	for z: int in [8, 9]:
		assert_bool(ORIGIN + Vector2i(5, z) in building.solid_cells()).override_failure_message("door %d" % z).is_false()
	assert_str(building.roof_piece()).is_equal("roof-warehouse-t1")


## Owner ruling 2026-11-03, "Shots pass windows": a window stops a walk but not a shot; furniture
## and doorways stop neither shot.
func test_a_shot_passes_windows_doorways_and_furniture() -> void:
	var building := _building(_ground())
	var fire := building.blocks_fire_cells()
	var walls := building.wall_cells()
	for cell: Vector2i in fire:
		assert_bool(cell in walls).is_true()
	for local: Vector2i in [Vector2i(0, 5), Vector2i(9, 5), Vector2i(7, 7)]:
		assert_bool(ORIGIN + local in walls).override_failure_message("window %s walks" % local).is_true()
		assert_bool(ORIGIN + local in fire).override_failure_message("window %s shoots" % local).is_false()
	assert_bool(ORIGIN + Vector2i(1, 3) in building.solid_cells()).is_true()
	assert_bool(ORIGIN + Vector2i(1, 3) in fire).is_false()
	assert_bool(ORIGIN + Vector2i(3, 7) in fire).is_false()


## Item 35 polish (2026-11-04): the kit renders at a pitch where a floor cell is the 64 x 32 ground
## diamond, so a roof spanning the footprint lands on the grid at all its corners.
func test_a_kit_floor_tile_is_one_ground_cell() -> void:
	var manifest := _manifest()
	assert_float(float(manifest["spec"]["camera_pitch_degrees"])).is_equal_approx(30.0, 0.001)
	var size: Array = manifest["pieces"]["floor-planks"]["size"]
	assert_int(int(size[0])).is_equal(64)
	# The 32 px diamond plus the plank edge below it.
	assert_int(int(size[1])).is_between(32, 34)


## The roof sits over every wall piece: no opaque pixel of a full-height wall, window, lintel, post
## or pillar shows above the roof's outline, for every layout and turn the kit has a roof for.
func test_the_roof_covers_every_wall_piece() -> void:
	var roofs: Array[String] = []
	for piece: String in _manifest()["pieces"]:
		if piece.begins_with("roof-"):
			roofs.append(piece)
	assert_int(roofs.size()).is_greater_equal(4)
	for roof_name: String in roofs:
		var parts := roof_name.split("-")
		var layout_path := "res://world/buildings/layouts/%s.tres" % parts[1]
		var turns := int(parts[2].trim_prefix("t"))
		var map := await _map(layout_path, turns)
		var building: WalkInBuilding = map.get_node("Building")
		var roof := building.get_node("Roof") as Sprite2D
		var roof_image := _image(roof.texture)
		var roof_at := roof.position + roof.offset
		var roof_top := PackedInt32Array()
		for x in roof_image.get_width():
			roof_top.append(_first_opaque_row(roof_image, x))
		for sprite: Node in building.get_node("Walls").get_children():
			var piece := sprite as Sprite2D
			var image := _image(piece.texture)
			var at := piece.position + piece.offset
			var showing := 0
			for x in image.get_width():
				var top := _first_opaque_row(image, x)
				if top < 0:
					continue
				var roof_x := roundi(at.x + x - roof_at.x)
				var covered := roof_x >= 0 and roof_x < roof_image.get_width() and roof_top[roof_x] >= 0 \
					and at.y + top >= roof_at.y + roof_top[roof_x] - 0.5
				showing += 0 if covered else 1
			assert_int(showing).override_failure_message("%s t%d: %s at %s shows above the roof" % [
				layout_path.get_file(), turns, piece.name, piece.position,
			]).is_equal(0)
		map.free()


## "Your room opens" (owner ruling 2026-11-04). Outside, the roof is on and every wall whole. In the
## shop's front room the roof goes, its front walls drop to stubs, the storeroom's front wall fades
## and the back wall stays; in the storeroom its own front wall drops instead. Behind the building
## the roof fades.
func test_the_look_follows_the_party_room_by_room() -> void:
	var map := await _map(SHOP, 0)
	var building: WalkInBuilding = map.get_node("Building")
	var walker: Node2D = map.get_node("Walker")
	var plan := building.plan()
	var roof := building.get_node("Roof") as Sprite2D
	assert_int(building.current_look()).is_equal(WalkInBuilding.Look.OUTSIDE)
	assert_float(roof.modulate.a).is_equal_approx(1.0, 0.01)
	var walls := building.get_node("Walls").get_children()
	assert_int(walls.size()).is_equal(plan.pieces.size())
	assert_int(building.get_node("Floor").get_child_count()).is_equal(plan.footprint_cells().size())
	assert_int(building.get_node("Furniture").get_child_count()).is_equal(plan.furniture.size())

	var front_room := Vector2i(3, 5)
	walker.position = building.to_global(building.corner(front_room.x + 0.5, front_room.y + 0.5))
	await _settle()
	assert_int(building.current_look()).is_equal(WalkInBuilding.Look.INSIDE)
	assert_array(building.open_rooms()).is_equal(plan.rooms_of(front_room))
	assert_float(roof.modulate.a).is_equal_approx(0.0, 0.01)
	var front_wall := walls[_piece_at(plan, Vector2i(2, 7))] as Sprite2D
	assert_bool(_is_stub(front_wall)).is_true()
	var store_front := walls[_piece_at(plan, Vector2i(7, 4))] as Sprite2D
	assert_float(store_front.modulate.a).is_equal_approx(DS.FACADE_OCCLUDED_ALPHA, 0.01)
	var back_wall := walls[_piece_at(plan, Vector2i(2, 0))] as Sprite2D
	assert_float(back_wall.modulate.a).is_equal_approx(1.0, 0.01)
	assert_bool(_is_stub(back_wall)).is_false()

	var store := Vector2i(7, 2)
	walker.position = building.to_global(building.corner(store.x + 0.5, store.y + 0.5))
	await _settle()
	assert_array(building.open_rooms()).is_equal(plan.rooms_of(store))
	assert_bool(_is_stub(store_front)).is_true()
	assert_float(store_front.modulate.a).is_equal_approx(1.0, 0.01)
	assert_bool(_is_stub(front_wall)).is_false()

	# Behind the back corner, under the roof's silhouette but off the footprint.
	walker.position = building.to_global(building.corner(0, 0) - Vector2(0, 40))
	await _settle()
	assert_int(building.current_look()).is_equal(WalkInBuilding.Look.SEEN_THROUGH)
	assert_float(roof.modulate.a).is_equal_approx(DS.FACADE_OCCLUDED_ALPHA, 0.01)

	walker.position = Vector2(-4000, -4000)
	await _settle()
	assert_int(building.current_look()).is_equal(WalkInBuilding.Look.OUTSIDE)
	assert_float(roof.modulate.a).is_equal_approx(1.0, 0.01)
	map.free()


## A shop's vendor stands on its vendor cell, behind the counter, and trades across it.
func test_a_vendor_keeps_shop_behind_the_counter() -> void:
	var map := await _map(SHOP, 0, PackedStringArray(["ford-chandlery"]), Vector2i(2, 2))
	var building: WalkInBuilding = map.get_node("Building")
	var vendors: Array[NPC] = []
	for child: Node in building.get_children():
		if child is NPC:
			vendors.append(child as NPC)
	assert_int(vendors.size()).is_equal(1)
	var vendor := vendors[0]
	assert_str(vendor.vendor_id).is_equal("ford-chandlery")
	assert_bool(vendor.is_in_group(&"indoor_vendor")).is_true()
	# NPCs snap to the walk grid on arrival; the vendor stays on its cell.
	assert_vector(Vector2(building.layout_cell_at(vendor.global_position))).is_equal(Vector2(2, 2))
	# A customer in front of the counter, two cells away, is in reach.
	var customer := building.corner(2.5, 4.5)
	assert_float(vendor.position.distance_to(customer)).is_less(vendor.interaction_radius)
	map.free()


func _map(layout_path: String, turns: int, vendor_ids := PackedStringArray(), vendor_cell := Vector2i.ZERO) -> Node2D:
	var map := Node2D.new()
	map.add_child(_ground(true))
	var building := WalkInBuilding.new()
	building.name = "Building"
	building.layout = load(layout_path)
	building.quarter_turns = turns
	building.origin_cell = ORIGIN
	building.vendor_ids = vendor_ids
	building.vendor_cell = vendor_cell
	map.add_child(building)
	var walker := Node2D.new()
	walker.name = "Walker"
	walker.add_to_group(&"player")
	walker.position = Vector2(-4000, -4000)
	map.add_child(walker)
	add_child(map)
	await await_idle_frame()
	return map


func _settle() -> void:
	for index in 2:
		await get_tree().physics_frame
	await get_tree().create_timer(WalkInBuilding.FADE_DURATION + 0.1).timeout


func _is_stub(sprite: Sprite2D) -> bool:
	return sprite.texture.resource_path.get_file().contains("-stub")


func _piece_at(plan: BuildingPlan, cell: Vector2i) -> int:
	for index in plan.pieces.size():
		if plan.pieces[index]["cell"] == cell:
			return index
	return -1


func _manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(WalkInBuilding.KIT_MANIFEST))


func _image(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	return image


## The first row of column `x` with an opaque pixel, or -1.
func _first_opaque_row(image: Image, x: int) -> int:
	for y in image.get_height():
		if image.get_pixel(x, y).a > 0.0:
			return y
	return -1
