extends GdUnitTestSuite

const EnemyScript := preload("res://actors/enemy/enemy.gd")
const NpcScript := preload("res://actors/npc/npc.gd")


func test_enemy_presentation_is_scene_configured_not_encounter_configured() -> void:
	var enemy: Enemy = auto_free(EnemyScript.new())
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	enemy.add_child(sprite)
	enemy.visual_region = Rect2(34, 68, 16, 16)
	enemy.visual_modulate = Color(0.2, 0.4, 0.8, 1.0)
	enemy.visual_scale = Vector2(5.0, 5.0)

	enemy._apply_visual_identity()

	assert_bool(sprite.region_rect == Rect2(34, 68, 16, 16)).is_true()
	assert_bool(sprite.modulate == Color(0.2, 0.4, 0.8, 1.0)).is_true()
	assert_bool(sprite.scale == Vector2(5.0, 5.0)).is_true()


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
