extends GdUnitTestSuite
## Headless art contracts for Dom batch 1. Rendered readability is a separate QA gate.

const TOWN_PATH := "res://world/starting_town.tscn"
const MANIFEST_PATH := "res://assets/generated/sprites/manifest.json"
const BATCH_ID := "dom-batch1-2026-10-09"
const FORBIDDEN_KITS := ["castle-kit", "fantasy-town-kit", "nature-kit", "kenney3d"]
const SPRITE_DIR := "res://assets/generated/sprites/world/"
## Drawn alpha-bounds height (px at zoom 1) per rescaled prop; absent textures keep their
## #305 footprint. See docs/qa/town-prop-scale-464-2026-10-10/README.md.
const PROP_DRAWN_HEIGHT_PX := {
	SPRITE_DIR + "dom-gate--arched.png": 160.0,
	SPRITE_DIR + "dom-lantern--street.png": 160.0,
	SPRITE_DIR + "dom-cart--high.png": 88.0,
	SPRITE_DIR + "dom-banner--green.png": 80.0,
	SPRITE_DIR + "dom-banner--red.png": 80.0,
	SPRITE_DIR + "dom-stall-bench--plank.png": 50.0,
}


func _batch() -> Dictionary:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return manifest.get("painted_batches", {}).get(BATCH_ID, {})


func _town() -> Node2D:
	var packed := load(TOWN_PATH) as PackedScene
	return auto_free(packed.instantiate()) as Node2D


func test_scene_has_no_remaining_kit_references() -> void:
	var source := FileAccess.get_file_as_string(TOWN_PATH)
	for kit: String in FORBIDDEN_KITS:
		assert_bool(source.contains(kit)) \
			.override_failure_message("Dom still references %s" % kit).is_false()


func test_all_seven_painted_replacements_are_used_by_the_scene() -> void:
	var batch := _batch()
	assert_bool(batch.is_empty()).is_false()
	var records: Array = batch.get("sprites", [])
	assert_int(records.size()).is_equal(7)
	var town := _town()
	var used_paths: Array[String] = []
	for sprite: Sprite2D in town.find_children("*", "Sprite2D", true, false):
		if sprite.texture != null:
			used_paths.append(sprite.texture.resource_path)
	for record: Dictionary in records:
		assert_array(used_paths).contains([str(record["output"])])


func test_painted_sprites_have_clean_alpha_and_manifest_hashes() -> void:
	var records: Array = _batch().get("sprites", [])
	assert_int(records.size()).is_equal(7)
	for record: Dictionary in records:
		var path := str(record["output"])
		var image := Image.new()
		var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		assert_int(error).is_equal(OK)
		if error != OK:
			continue
		assert_bool(image.get_size() == Vector2i(256, 256)).is_true()
		assert_int(image.detect_alpha()).is_equal(Image.ALPHA_BLEND)
		var bounds := image.get_used_rect()
		assert_int(bounds.size.x).is_greater(16)
		assert_int(bounds.size.y).is_greater(32)
		assert_bool(Rect2i(3, 3, 250, 250).encloses(bounds)).is_true()
		assert_str(FileAccess.get_sha256(path)).is_equal(str(record["output_sha256"]))
		var chroma_pixels := 0
		for y in image.get_height():
			for x in image.get_width():
				var color := image.get_pixel(x, y)
				if color.a > 0.1 and color.g > 0.55 and color.g - maxf(color.r, color.b) > 0.22:
					chroma_pixels += 1
		assert_int(chroma_pixels).override_failure_message("Chroma residue in %s" % path).is_equal(0)


func _drawn_rect(sprite: Sprite2D) -> Rect2:
	var bounds := sprite.texture.get_image().get_used_rect()
	var half := sprite.texture.get_size() * 0.5
	var top_left := (Vector2(bounds.position) - half + sprite.offset) * sprite.scale
	return Rect2(sprite.position + top_left, Vector2(bounds.size) * sprite.scale)


func test_props_are_drawn_at_adult_relative_sizes_on_their_original_anchors() -> void:
	# #464: alpha-bounds heights at zoom 1 beside the 112 px adult (UnitArt.TARGET_ACTOR_HEIGHT_PX),
	# with uniform scale so the painted proportions are kept. The bottom anchor and horizontal
	# center of every placement stay where #305 left them.
	var records: Array = _batch().get("sprites", [])
	assert_int(records.size()).is_equal(7)
	var town := _town()
	for record: Dictionary in records:
		var output := str(record["output"])
		var target_height: float = PROP_DRAWN_HEIGHT_PX.get(output, -1.0)
		var previous_size := Vector2(record["previous_drawn_size_px"][0], record["previous_drawn_size_px"][1])
		for placement: Dictionary in record["placements"]:
			var sprite := town.get_node(str(placement["node_path"])) as Sprite2D
			assert_str(sprite.texture.resource_path).is_equal(output)
			var bounds := sprite.texture.get_image().get_used_rect()
			var drawn_size := Vector2(bounds.size) * sprite.scale
			if target_height > 0.0:
				assert_float(drawn_size.y).override_failure_message("%s height" % placement["node_path"]) \
					.is_equal_approx(target_height, 0.1)
				assert_float(sprite.scale.x).is_equal_approx(sprite.scale.y, 0.000001)
			else:
				assert_float(drawn_size.x).is_equal_approx(previous_size.x, 0.1)
				assert_float(drawn_size.y).is_equal_approx(previous_size.y, 0.1)
			var bottom := (float(bounds.end.y) - sprite.texture.get_height() * 0.5 + sprite.offset.y) * sprite.scale.y
			assert_float(bottom).is_equal_approx(float(placement["previous_bottom_y"]), 0.1)
			var center_x := (bounds.position.x + bounds.size.x * 0.5 - sprite.texture.get_width() * 0.5 + sprite.offset.x) * sprite.scale.x
			assert_float(center_x).is_equal_approx(0.0, 0.1)


func test_border_walls_stay_clear_of_the_players_house_door_and_spawn() -> void:
	# The south wall row stands 97 px below Vex's spawn; a taller wall would draw over the
	# player's house door and the spawned player (#464 keeps the walls at their #305 size).
	var town := _town()
	var spawn := (town.get_node("SpawnFromPlayersHouse") as Node2D).position
	var door := (town.get_node("PlayersHouseEntrance") as Node2D).position
	for sprite: Sprite2D in town.get_node("BorderDressing").get_children():
		var rect := _drawn_rect(sprite)
		for point: Vector2 in [spawn, door]:
			assert_bool(rect.has_point(point)) \
				.override_failure_message("%s draws over %s" % [sprite.name, point]).is_false()


func test_dom_uses_the_full_size_painted_terrain_plate() -> void:
	var town := _town()
	var terrain := town.get_node("TerrainBackdrop") as Sprite2D
	assert_object(terrain.texture).is_not_null()
	assert_bool(terrain.visible).is_true()
	assert_bool(terrain.texture.get_size() == Vector2(2000, 1200)).is_true()
	assert_bool(terrain.texture.get_size() * terrain.scale == Vector2(3600, 2160)).is_true()
	assert_int(terrain.z_index).is_less(0)
	var record: Dictionary = _batch().get("terrain", {})
	assert_str(terrain.texture.resource_path).is_equal(str(record.get("output", "")))
	assert_str(FileAccess.get_sha256(terrain.texture.resource_path)).is_equal(str(record.get("output_sha256", "")))
