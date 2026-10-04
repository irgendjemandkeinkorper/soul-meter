extends GdUnitTestSuite

const BattleStageScene := preload("res://ui/screens/battle_stage.tscn")
const KIT_NAMES := ["castle-kit", "fantasy-town-kit", "nature-kit", "kenney3d"]


func test_all_environments_have_no_kit_scenery() -> void:
	var stage := auto_free(BattleStageScene.instantiate()) as Control
	stage.size = Vector2(1280, 720)
	add_child(stage)
	var environments := {
		&"bog-wight": "nature",
		&"mustered-bloodbellow": "fantasy-town",
		&"cleaned-jawbrace-guard": "castle",
	}
	for archetype: StringName in environments:
		var event := CombatEvent.new()
		event.type = &"battle_started"
		event.data = {"snapshot": {"enemies": [{"archetype_id": archetype}]}}
		stage.consume_event(event, false)
		assert_str(stage.environment_id()).is_equal(environments[archetype])
		assert_object(stage.get_node_or_null("BattleArt/EnvironmentSprites")).is_null()
		var sprites := stage.get_node("BattleArt").find_children("*", "Sprite2D", true, false)
		assert_int(sprites.size()).is_greater_equal(30)
		for sprite: Sprite2D in sprites:
			var texture: Texture2D = sprite.texture
			assert_object(texture).is_not_null()
			if texture is AtlasTexture:
				texture = (texture as AtlasTexture).atlas
			for kit_name: String in KIT_NAMES:
				assert_bool(texture.resource_path.contains(kit_name)) \
					.override_failure_message("Kit scenery at %s: %s" % [sprite.get_path(), texture.resource_path]) \
					.is_false()
