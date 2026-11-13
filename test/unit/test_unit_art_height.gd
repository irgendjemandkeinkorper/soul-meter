extends GdUnitTestSuite
## Owner decision 2026-10-05: field actors draw at a ~112 px adult height, measured from each
## texture's visible pixels, with deliberate smaller heights for ordinary animals.

const UnitArtScript := preload("res://globals/unit_art.gd")

var _saved_units: Dictionary[String, Dictionary]
var _fixture_textures: Array[Texture2D] = []

func before_test() -> void:
	UnitFrames._ensure_loaded()
	_saved_units = UnitFrames._units.duplicate(true)

func after_test() -> void:
	UnitFrames._units = _saved_units
	_fixture_textures.clear()


func _sprite_for(unit_id: String) -> Sprite2D:
	var sprite := auto_free(Sprite2D.new()) as Sprite2D
	sprite.texture = load(UnitArtScript.texture_path(unit_id)) as Texture2D
	sprite.offset = UnitArtScript.PIVOT_OFFSET
	return sprite


func _drawn(sprite: Sprite2D) -> float:
	return UnitArtScript._drawn_height(sprite) * sprite.scale.y


func test_adult_actors_draw_at_the_target_height_whatever_their_canvas_fill() -> void:
	for unit_id: String in ["vex", "crowd-dockworker-b", "bog-wight"]:
		var sprite := _sprite_for(unit_id)
		UnitArtScript.apply_world_scale(sprite)
		assert_float(_drawn(sprite)) \
			.override_failure_message("%s draws at %.1f px" % [unit_id, _drawn(sprite)]) \
			.is_equal_approx(UnitArtScript.TARGET_ACTOR_HEIGHT_PX, 0.5)
		assert_bool(sprite.offset.is_equal_approx(UnitArtScript.PIVOT_OFFSET * sprite.scale.y)).is_true()


func test_ordinary_animals_keep_their_own_smaller_height() -> void:
	var rat := _sprite_for("fauna-rat")
	UnitArtScript.apply_world_scale(rat)
	assert_float(_drawn(rat)).is_equal_approx(float(UnitArtScript.UNIT_HEIGHT_PX["fauna-rat"]), 0.5)
	assert_float(_drawn(rat)).is_less(UnitArtScript.TARGET_ACTOR_HEIGHT_PX * 0.5)


func test_repeat_calls_do_not_compound_and_a_texture_swap_rederives_the_factor() -> void:
	var sprite := _sprite_for("vex")
	var shadow := auto_free(Node2D.new()) as Node2D
	UnitArtScript.apply_world_scale(sprite, shadow)
	var first_scale := sprite.scale
	UnitArtScript.apply_world_scale(sprite, shadow)
	assert_vector(sprite.scale).is_equal(first_scale)
	assert_vector(shadow.scale).is_equal(Vector2.ONE * first_scale.y)

	sprite.texture = load(UnitArtScript.texture_path("crowd-dockworker-b")) as Texture2D
	UnitArtScript.apply_world_scale(sprite, shadow)
	assert_float(_drawn(sprite)).is_equal_approx(UnitArtScript.TARGET_ACTOR_HEIGHT_PX, 0.5)
	assert_bool(sprite.offset.is_equal_approx(UnitArtScript.PIVOT_OFFSET * sprite.scale.y)).is_true()

func test_player_resolver_prefers_class_then_ancestry_then_likeness() -> void:
	_add_unit("player-vael", {"drawn_height_px": 224, "height_factor": 1.0})
	assert_str(UnitArtScript.player_unit_id("vael", "ironbrand", "likeness_01")).is_equal("player-vael")
	_add_unit("player-vael-ironbrand")
	assert_str(UnitArtScript.player_unit_id("vael", "ironbrand", "likeness_01")).is_equal("player-vael-ironbrand")
	assert_str(UnitArtScript.player_unit_id("vael", "", "likeness_01")).is_equal("player-vael")
	assert_str(UnitArtScript.player_unit_id("kaan", "ironbrand", "likeness_03")).is_equal("crowd-laborer-a")
	assert_str(UnitArtScript.player_unit_id("", "ironbrand", "likeness_01")).is_equal("crowd-acolyte-a")

func test_player_resolver_keeps_legacy_units_and_deterministic_crowd_fallback() -> void:
	assert_str(UnitArtScript.player_unit_id("vael", "ironbrand", "crowd-guard-a")).is_equal("crowd-guard-a")
	for likeness: String in ["", "missing-likeness"]:
		assert_str(UnitArtScript.player_unit_id("unknown", "unknown", likeness)).is_equal(
			UnitArtScript.fallback_for(likeness)
		)
	UnitFrames._units.erase("crowd-acolyte-a")
	assert_str(UnitArtScript.player_unit_id("vael", "ironbrand", "likeness_01")).is_equal(
		UnitArtScript.fallback_for("crowd-acolyte-a")
	)

func test_all_current_likenesses_resolve_to_their_existing_field_art() -> void:
	for ancestry: Dictionary in ChargenData.ANCESTRIES:
		for patron: Dictionary in ChargenData.PATRONS:
			for likeness: Dictionary in ChargenData.LIKENESSES:
				assert_str(UnitArtScript.player_unit_id(str(ancestry["id"]), str(patron["id"]), str(likeness["id"]))) \
					.is_equal(str(likeness["unit"]))

func test_manifest_height_is_used_without_changing_the_ratified_adult_target() -> void:
	_add_unit("player-vael", {"drawn_height_px": 224, "height_factor": 1.0})
	var sprite := _sprite_for("player-vael")
	UnitArtScript.apply_world_scale(sprite)
	assert_float(sprite.scale.y).is_equal_approx(0.5, 0.0001)
	assert_float(UnitArtScript.target_height_for(sprite.texture)).is_equal(112.0)
	# Cropped regions still measure their own pixels, not the whole-unit manifest.
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 2, 2)
	assert_float(UnitArtScript._drawn_height(sprite)).is_equal(2.0)

func _add_unit(unit_id: String, metadata: Dictionary = {}) -> void:
	var path := "%s/%s/%s--idle--se--f00.png" % [UnitArtScript.ROOT, unit_id, unit_id]
	# In-memory resources exercise ResourceLoader/export resolution without adding art.
	var texture := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	texture.take_over_path(path)
	_fixture_textures.append(texture)
	var row := metadata.duplicate(true)
	row.merge({"presentation_id": unit_id, "output_paths": [path], "direction": "se", "state": "idle", "frame": 0})
	UnitFrames._units.merge(UnitFrames._index_manifest({"assets": [row]}), true)
