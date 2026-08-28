extends GdUnitTestSuite


const TERRAIN_PATH := (
	"res://assets/generated/backgrounds/world/loamroot-wilds-terrain-v1.png"
)


func test_wilds_uses_authored_full_map_terrain_instead_of_visible_blockout_tiles() -> void:
	var packed := load("res://world/test_room.tscn") as PackedScene
	var wilds: Node = auto_free(packed.instantiate())
	add_child(wilds)
	var terrain := wilds.get_node_or_null("TerrainBackdrop") as Sprite2D
	var underlay := wilds.get_node_or_null("WorldUnderlay") as Polygon2D
	var blockout := wilds.get_node("IsometricGround") as TileMapLayer

	assert_object(terrain).is_not_null()
	assert_object(underlay).is_not_null()
	if terrain == null or underlay == null:
		return
	assert_object(terrain.texture).is_not_null()
	assert_str(terrain.texture.resource_path).is_equal(TERRAIN_PATH)
	assert_vector(terrain.texture.get_size()).is_equal(Vector2(2000, 1200))
	assert_vector(terrain.position).is_equal(Vector2(1000, 780))
	assert_vector(terrain.scale).is_equal(Vector2(1.6, 1.6))
	assert_bool(blockout.visible).is_false()
	assert_int(terrain.z_index).is_less(blockout.z_index)
	assert_int(underlay.z_index).is_less(terrain.z_index)
	var underlay_bounds := _polygon_bounds(underlay.polygon)
	assert_float(underlay_bounds.size.x).is_greater_equal(6000.0)
	assert_float(underlay_bounds.size.y).is_greater_equal(5000.0)
	for node_name: String in [
		"TreelinePineA",
		"TreelineDarkA",
		"TreelinePineB",
		"TreelineThin",
		"TreelinePineC",
		"TreelineDarkB",
		"TreelinePineD",
		"EastPine",
	]:
		assert_bool((wilds.find_child(node_name, true, false) as Sprite2D).visible).is_false()


func _polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum := points[0]
	var maximum := points[0]
	for point: Vector2 in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)
