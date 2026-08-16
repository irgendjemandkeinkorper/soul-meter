extends GdUnitTestSuite

const EnemyScript := preload("res://actors/enemy/enemy.gd")
const NpcScript := preload("res://actors/npc/npc.gd")
const UnitArtScript := preload("res://globals/unit_art.gd")


func test_enemy_presentation_uses_the_encounter_unit_art_resolver() -> void:
	var enemy: Enemy = auto_free(EnemyScript.new())
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	enemy.add_child(sprite)
	enemy.encounter_id = &"bog-wight"
	sprite.region_enabled = true
	sprite.modulate = Color(0.2, 0.4, 0.8, 1.0)
	sprite.scale = Vector2(5.0, 5.0)

	enemy._apply_visual_identity()

	# The old atlas-region expectation was stale after the painterly UnitArt retarget.
	var resolved_id := UnitArtScript.resolve("bog-wight")
	assert_str(sprite.texture.resource_path).is_equal(UnitArtScript.texture_path(resolved_id))
	assert_bool(sprite.region_enabled).is_false()
	assert_vector(sprite.offset).is_equal(UnitArtScript.PIVOT_OFFSET)
	assert_vector(sprite.scale).is_equal(Vector2.ONE)
	assert_bool(sprite.modulate == Color.WHITE).is_true()


func test_npc_presentation_is_scene_configured_not_name_configured() -> void:
	var npc: NPC = auto_free(NpcScript.new())
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	npc.add_child(sprite)
	npc.npc_name = "A Future NPC"
	npc.visual_region = Rect2(17, 102, 16, 16)
	npc.visual_modulate = Color(0.8, 0.6, 0.2, 1.0)
	npc.visual_scale = Vector2(4.0, 4.0)

	npc._apply_visual_identity()

	assert_bool(sprite.region_rect == Rect2(17, 102, 16, 16)).is_true()
	assert_bool(sprite.modulate == Color(0.8, 0.6, 0.2, 1.0)).is_true()
	assert_bool(sprite.scale == Vector2(4.0, 4.0)).is_true()
