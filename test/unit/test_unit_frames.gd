extends GdUnitTestSuite

var _saved_units: Dictionary[String, Dictionary]


func before_test() -> void:
	UnitFrames._ensure_loaded()
	_saved_units = UnitFrames._units


func after_test() -> void:
	UnitFrames._units = _saved_units


func test_every_legacy_unit_preserves_its_path_and_all_eight_mirror_choices() -> void:
	var manifest := load(UnitFrames.MANIFEST_PATH) as JSON
	assert_int(manifest.data["assets"].size()).is_equal(88)
	for row: Dictionary in manifest.data["assets"]:
		var unit_id := str(row["presentation_id"])
		var expected := "res://" + str(row["output_paths"][0])
		assert_str(UnitArt.texture_path(unit_id)).is_equal(expected)
		assert_bool(UnitArt.has_unit(unit_id)).is_true()
		assert_array(Array(UnitFrames.directions_for(unit_id))).contains_exactly(["se"])
		for dir: String in UnitFrames.DIRECTIONS:
			var frame := UnitFrames.lookup(unit_id, "idle", dir, 0)
			assert_str(frame.path).is_equal(expected)
			assert_bool(frame.flip).is_equal(dir.contains("w"))


func test_direction_queries_report_authored_frames_and_return_independent_arrays() -> void:
	assert_bool(UnitFrames.has_direction("vex", "se")).is_true()
	assert_bool(UnitFrames.has_direction("vex", "w")).is_false()
	var directions := UnitFrames.directions_for("vex")
	directions.append("w")
	assert_bool(UnitFrames.has_direction("vex", "w")).is_false()
	assert_array(Array(UnitFrames.directions_for("missing-unit"))).is_empty()


func test_multi_direction_states_return_only_the_explicit_frame_paths() -> void:
	var paths: Array[String] = []
	for dir: String in UnitFrames.DIRECTIONS:
		paths.append(_path("player-vael", "idle", dir, 0))
		for frame: int in 2:
			paths.append(_path("player-vael", "walk", dir, frame))
	UnitFrames._units = UnitFrames._index_manifest({"assets": [{
		"presentation_id": "player-vael", "output_paths": paths,
		"directions": Array(UnitFrames.DIRECTIONS), "states": {"idle": 1, "walk": 2},
		"race_id": "vael", "class_id": "ironbrand", "role": "player", "variant": "a",
		"drawn_height_px": 224, "height_factor": 1.0,
	}]})
	for dir: String in UnitFrames.DIRECTIONS:
		assert_bool(UnitFrames.has_direction("player-vael", dir)).is_true()
		var frame := UnitFrames.lookup("player-vael", "walk", dir, 1)
		assert_str(frame.path).is_equal("res://" + _path("player-vael", "walk", dir, 1))
		assert_bool(frame.flip).is_false()
	assert_str(UnitFrames.texture_path("player-vael", "walk", "w", 2)).is_empty()
	assert_str(UnitFrames.texture_path("player-vael", "attack", "w", 0)).is_empty()
	var metadata := UnitFrames.metadata_for("player-vael")
	assert_str(str(metadata["class_id"])).is_equal("ironbrand")
	metadata["race_id"] = "ghorr"
	assert_array(Array(UnitFrames.unit_ids_for_race("vael"))).contains_exactly(["player-vael"])
	assert_array(Array(UnitFrames.unit_ids_for_race("ghorr"))).is_empty()


func test_partial_direction_sets_do_not_invent_or_mirror_missing_frames() -> void:
	UnitFrames._units = UnitFrames._index_manifest({"assets": [{
		"presentation_id": "partial", "directions": ["se", "w", "n"], "states": {"idle": 1},
		"output_paths": [_path("partial", "idle", "se", 0), _path("partial", "idle", "w", 0)],
	}]})
	assert_bool(UnitFrames.lookup("partial", "idle", "w", 0).flip).is_false()
	assert_str(UnitFrames.texture_path("partial", "idle", "sw", 0)).is_empty()
	assert_str(UnitFrames.texture_path("partial", "idle", "n", 0)).is_empty()
	assert_bool(UnitFrames.has_direction("partial", "n")).is_false()


func test_se_only_animation_mirrors_the_requested_frame() -> void:
	UnitFrames._units = UnitFrames._index_manifest({"assets": [{
		"presentation_id": "painted", "directions": ["se"], "states": {"idle": 1, "walk": 2},
		"output_paths": [_path("painted", "idle", "se", 0), _path("painted", "walk", "se", 1)],
	}]})
	var frame := UnitFrames.lookup("painted", "walk", "nw", 1)
	assert_str(frame.path).is_equal("res://" + _path("painted", "walk", "se", 1))
	assert_bool(frame.flip).is_true()
	assert_str(UnitFrames.texture_path("painted", "walk", "w", 0)).is_empty()


func test_missing_units_invalid_requests_and_unlisted_outputs_return_empty_paths() -> void:
	assert_str(UnitFrames.texture_path("missing")).is_empty()
	assert_str(UnitFrames.texture_path("vex", "idle", "west", 0)).is_empty()
	assert_str(UnitFrames.texture_path("vex", "idle", "se", -1)).is_empty()
	assert_str(UnitFrames.texture_path("vex", "idle", "se", 1)).is_empty()
	assert_str(UnitFrames.texture_path("vex", "walk", "se", 0)).is_empty()
	UnitFrames._units = UnitFrames._index_manifest({"assets": [null, {
		"presentation_id": "bad", "directions": ["se"], "states": {"idle": 1},
		"output_paths": [
			"assets/generated/sprites/units/bad/../vex/vex--idle--se--f00.png",
			_path("bad", "idle", "w", 0), _path("bad", "idle", "se", 1),
			_path("bad", "dance", "se", 0), 4,
		],
	}]})
	assert_str(UnitFrames.texture_path("bad")).is_empty()
	assert_array(Array(UnitFrames.directions_for("bad"))).is_empty()


func test_idle_facing_keeps_existing_texture_scale_pivot_and_region() -> void:
	var sprite := auto_free(Sprite2D.new()) as Sprite2D
	sprite.texture = load(UnitArt.texture_path("vex")) as Texture2D
	sprite.offset = UnitArt.PIVOT_OFFSET
	UnitArt.apply_world_scale(sprite)
	var texture := sprite.texture
	var scale := sprite.scale
	var offset := sprite.offset
	for dir: String in UnitFrames.DIRECTIONS:
		UnitArt.apply_idle_facing(sprite, dir)
		assert_object(sprite.texture).is_same(texture)
		assert_vector(sprite.scale).is_equal(scale)
		assert_vector(sprite.offset).is_equal(offset)
		assert_bool(sprite.region_enabled).is_false()
		assert_bool(sprite.flip_h).is_equal(dir.contains("w"))


func _path(unit_id: String, state: String, dir: String, frame: int) -> String:
	return "assets/generated/sprites/units/%s/%s--%s--%s--f%02d.png" % [unit_id, unit_id, state, dir, frame]
