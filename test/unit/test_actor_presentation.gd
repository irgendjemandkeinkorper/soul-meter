extends GdUnitTestSuite

const NpcScript := preload("res://actors/npc/npc.gd")
const UnitArtScript := preload("res://globals/unit_art.gd")


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
	# Authored visual_scale, then the global field-actor shrink on top.
	assert_bool(sprite.scale == Vector2(4.0, 4.0) * UnitArtScript.WORLD_SCALE).is_true()
