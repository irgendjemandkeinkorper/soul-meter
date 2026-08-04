extends GdUnitTestSuite
## Mechanical acceptance coverage for the one-way 3D -> 2D art pipeline.

const RenderGenerator := preload("res://tools/render_isometric_sprites.gd")
const GROUND_ATLAS_PATH := "res://assets/generated/sprites/ground/ground_tiles.png"
const GROUND_TILESET_PATH := "res://assets/generated/sprites/ground/ground_tileset.tres"


func test_camera_contract_is_fixed_dimetric_orthographic() -> void:
	assert_float(RenderGenerator.CAMERA_YAW_DEGREES).is_equal_approx(45.0, 0.000001)
	assert_float(RenderGenerator.CAMERA_PITCH_RADIANS).is_equal_approx(atan(0.5), 0.000001)
	assert_int(RenderGenerator.CAMERA_PROJECTION).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
	assert_float(RenderGenerator.WORLD_UNITS_PER_TILE).is_equal(1.0)
	assert_bool(RenderGenerator.TILE_SIZE == Vector2i(64, 32)).is_true()


func test_committed_sprite_manifest_matches_all_572_source_models() -> void:
	var result: Dictionary = RenderGenerator.check_drift()
	assert_array(Array(result["errors"])).is_empty()
	assert_bool(result["drift"]).is_false()
	assert_int(result["count"]).is_equal(572)


func test_generated_ground_tileset_uses_64_by_32_diamond_cells() -> void:
	var tile_set := load(GROUND_TILESET_PATH) as TileSet
	assert_object(tile_set).is_not_null()
	assert_int(tile_set.tile_shape).is_equal(TileSet.TILE_SHAPE_ISOMETRIC)
	assert_int(tile_set.tile_layout).is_equal(TileSet.TILE_LAYOUT_DIAMOND_DOWN)
	assert_bool(tile_set.tile_size == Vector2i(64, 32)).is_true()

	var source := tile_set.get_source(0) as TileSetAtlasSource
	assert_object(source).is_not_null()
	assert_bool(source.texture_region_size == Vector2i(64, 32)).is_true()
	assert_int(source.get_tiles_count()).is_equal(4)


func test_each_ground_render_fills_one_exact_atlas_cell() -> void:
	var atlas := Image.load_from_file(GROUND_ATLAS_PATH)
	assert_object(atlas).is_not_null()
	assert_bool(atlas.get_size() == Vector2i(256, 32)).is_true()
	for tile_index in 4:
		var tile := atlas.get_region(Rect2i(tile_index * 64, 0, 64, 32))
		assert_bool(tile.get_used_rect() == Rect2i(0, 0, 64, 32)).is_true()
