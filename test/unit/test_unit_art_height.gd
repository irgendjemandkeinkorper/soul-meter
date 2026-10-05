extends GdUnitTestSuite
## Owner decision 2026-10-05: field actors draw at a ~112 px adult height, measured from each
## texture's visible pixels, with deliberate smaller heights for ordinary animals.

const UnitArtScript := preload("res://globals/unit_art.gd")


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
