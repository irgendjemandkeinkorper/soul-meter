extends GdUnitTestSuite


func test_weather_chip_renders_measure_tick() -> void:
	var runner := scene_runner("res://ui/hud/regions/weather_chip/weather_chip_region.tscn")
	var chip := runner.scene() as WeatherChipRegion
	var event := CombatEvent.new()
	event.data = {"weather": {"element_id": "terra", "tick": 15, "gains": "terra", "drains": "aqua"}}
	chip.consume_event(event)
	assert_str((runner.find_child("Value", true, false) as Label).text).contains("MEASURE 15/16")


func test_weather_chip_renders_calm_for_the_no_weather_sentinel() -> void:
	var runner := scene_runner("res://ui/hud/regions/weather_chip/weather_chip_region.tscn")
	var chip := runner.scene() as WeatherChipRegion
	var event := CombatEvent.new()
	event.data = {"weather": {"element_id": &"", "tick": 3}}
	chip.consume_event(event)
	var text := (runner.find_child("Value", true, false) as Label).text
	assert_str(text).contains("CALM · MEASURE 3/16")


func test_forecast_panel_returns_the_exact_resolution_result() -> void:
	var runner := scene_runner("res://ui/hud/regions/forecast_panel/forecast_panel_region.tscn")
	var panel := runner.scene() as ForecastPanelRegion
	var context := _context()
	panel.set_forecast_context(context)
	assert_dict(panel.forecast_result()).is_equal(Resolution.resolve(context))
	assert_int(panel.wheel.get_child_count()).is_equal(ElementWheel.ORDER.size())


func _context() -> Dictionary:
	return {"unit": {"id": "caster", "attack_scale": 1.0, "harmony": 0}, "ability": {"id": "strike", "power": 10, "element_id": &"strom", "elements": [&"strom"], "magnitude": &"note", "matrix_multiplier": 1.0}, "target": {"id": "target", "hp": 20, "element_id": &"terra", "attunements": {}}, "source_tile": {"charge_element_id": "", "charge_level": 0}, "target_tile": {"charge_element_id": "", "charge_level": 0}, "weather": {"weather_hush": false}, "facing": {"multiplier": 1.0}}
