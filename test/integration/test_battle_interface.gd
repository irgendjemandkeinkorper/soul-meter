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


func test_production_battle_instantiates_the_overlay() -> void:
	var source := FileAccess.get_file_as_string("res://ui/screens/battle.gd")
	assert_str(source).contains("battle_interface.tscn")
	assert_str(source).contains("Battle.combat_event.connect(_battle_interface.consume_event)")
