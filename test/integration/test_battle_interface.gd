extends GdUnitTestSuite


func test_battle_interface_renders_all_six_regions_from_scripted_state() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var event := CombatEvent.new()
	event.type = &"battle_snapshot"
	event.data = {"snapshot": {
		"active_unit": {"id": "sera", "name": "Sera", "hp": 31, "max_hp": 40, "element_id": "strom", "ct": 88, "speed": 9, "height": 1, "facing": "ne"},
		"tiles": [{"x": 0, "y": 0, "height_delta": 2, "charge_element_id": "strom", "charge_level": 2, "element_color": "#7BDFF2"}],
		"weather": {"element_id": "aqua", "tick": 7, "gains": "aqua", "drains": "scor"},
	}}
	interface.consume_event(event)
	await runner.simulate_frames(1)

	for node_name: String in ["ActiveUnitPlate", "Stage", "WeatherChip", "ActTargetPanel", "TurnTimeline", "HotbarSoulGauge"]:
		assert_object(runner.find_child(node_name, true, false)).is_not_null()
	assert_str((runner.find_child("HP", true, false) as Label).text).contains("31")
	assert_int((runner.find_child("Stage", true, false) as BattleStageRegion).rendered_tile_count()).is_equal(1)
	assert_str((runner.find_child("Value", true, false) as Label).text).contains("AQUA")


func test_region_e_renders_additive_ap_round_snapshot_payload() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var event := CombatEvent.new()
	event.type = &"battle_snapshot"
	event.data = {"snapshot": {
		"scheduler_mode": "ap_round",
		"turn_order": [
			{
				"actor_id": &"ally-0",
				"display_name": "Vex",
				"scheduler_mode": &"ap_round",
				"ap_remaining": 2,
				"max_ap": 4,
				"acted": false,
				"pending": true,
				"active": true,
			},
			{
				"actor_id": &"enemy-0",
				"display_name": "Wight",
				"scheduler_mode": &"ap_round",
				"ap_remaining": 0,
				"max_ap": 3,
				"acted": true,
				"pending": false,
				"active": false,
			},
		],
	}}
	interface.consume_event(event)
	await runner.simulate_frames(1)

	var timeline := runner.find_child("TurnTimeline", true, false) as CTTimelineRegion
	assert_int(timeline.marker_count()).is_equal(2)
	assert_str((timeline.markers.get_child(0) as Label).text).contains("ACTIVE")
	assert_str((timeline.markers.get_child(0) as Label).text).contains("●●○○")
	assert_str((timeline.markers.get_child(1) as Label).text).contains("ACTED")


func test_production_battle_instantiates_the_overlay() -> void:
	var source := FileAccess.get_file_as_string("res://ui/screens/battle.gd")
	assert_str(source).contains("battle_interface.tscn")
	assert_str(source).contains("Battle.combat_event.connect(_battle_interface.consume_event)")


func test_dorthkor_grid_battle_uses_its_authored_environment_background() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var event := CombatEvent.new()
	event.type = &"battle_started"
	event.data = {"snapshot": {
		"encounter_id": &"dorthkor-vanguard",
		"tiles": [{"x": 0, "y": 0, "height_delta": 0}],
		"allies": [{
			"id": &"ally-vex-0",
			"display_name": "Vex",
			"position": Vector2i.ZERO,
			"side": &"ally",
		}],
		"enemies": [{
			"id": &"enemy-gnaal-0",
			"display_name": "Gnaal Breach-Hound",
			"position": Vector2i.ONE,
			"side": &"enemy",
		}],
	}}
	interface.consume_event(event)
	await runner.simulate_frames(1)

	var stage := runner.find_child("Stage", true, false) as BattleStageRegion
	assert_str(stage.background_texture_path()).ends_with(
		"dorthkor-road-battlefield-v1.png"
	)


func test_cast_command_is_visible_and_submits_selected_target_through_interface() -> void:
	var cast := CombatActionCatalog.by_id(&"cast-seam")
	assert_object(cast).is_not_null()
	assert_bool(cast.player_available).is_true()
	assert_bool(cast.requires_enemy_target()).is_true()

	var rules := load("res://data/combat/combat_rules.tres") as CombatRules
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_two_cell_ground())
	var actor := _cast_actor("Caster", 30, 8)
	actor.breath = 2
	var target := _cast_actor("Target", 30, 1)
	var ability := AbilityDefinition.new()
	ability.id = "interface-cast"
	ability.element_id = &"strom"
	ability.elements = [&"strom"]
	ability.power = 8
	ability.breath_cost = 1
	var controller := CombatController.new()
	controller.configure([cast], grid, rules, null, [ability])
	controller.start([actor], [target], &"interface-cast")
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	interface.bind_controller(controller)
	interface.select_pointer_action(&"cast-seam")
	var hp_before := target.hp

	interface._on_pointer_pressed({"x": 1, "y": 0}, target.combat_id)

	assert_int(target.hp).is_less(hp_before)


func _cast_actor(name: String, hp: int, attack: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.attributes = {&"edge": 2, &"pitch": 2}
	return actor


func _two_cell_ground() -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = tile_set.tile_size
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	layer.set_cell(Vector2i(0, 0), 0, Vector2i.ZERO)
	layer.set_cell(Vector2i(1, 0), 0, Vector2i.ZERO)
	return layer
