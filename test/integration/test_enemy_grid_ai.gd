extends GdUnitTestSuite


func test_enemy_ai_uses_high_ground_and_faces_the_party() -> void:
	var rules := CombatRules.new()
	rules.move_ct_cost = 20
	var battlefield := GridBattlefieldModel.new()
	battlefield.configure(rules)
	battlefield.build_grid(_ground(5, 3))
	for x in range(1, 4):
		battlefield.set_elevation(Vector2i(x, 1), 2)

	var ally := _actor("ally", 30, 5, 2)
	var enemy := _actor("enemy", 30, 5, 2)
	var controller := CombatController.new()
	var events: Array[CombatEvent] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event))
	controller.configure(CombatActionCatalog.all(), battlefield, rules)
	controller.start([ally], [enemy], &"gate-t2-enemy-ai")
	controller.end_turn()

	var highest_used := 0
	for event in events:
		if event.actor_id != enemy.combat_id or event.data.get("action_id") != &"__enemy_grid_move__":
			continue
		var moved_to: Dictionary = battlefield.describe_position(event.data.get("to", &""))
		highest_used = maxi(highest_used, int(moved_to.get("elevation", 0)))
	assert_int(highest_used).is_equal(2)
	assert_str(String(battlefield.facing_of(enemy))).is_not_empty()


func _ground(width: int, height: int) -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer: TileMapLayer = auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	for y in height:
		for x in width:
			layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	return layer


func _actor(id: String, hp: int, attack: int, defense: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = id
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	actor.attributes = {&"edge": 0}
	return actor
