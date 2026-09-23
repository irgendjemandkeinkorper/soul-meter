extends GdUnitTestSuite


func test_weather_chip_renders_measure_tick() -> void:
	var runner := scene_runner("res://ui/hud/regions/weather_chip/weather_chip_region.tscn")
	var chip := runner.scene() as WeatherChipRegion
	var event := CombatEvent.new()
	event.data = {"weather": {"element_id": "tham", "tick": 15, "gains": "tham", "drains": "luth"}}
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


func test_forecast_panel_shows_the_resolved_fizzle_percentage_for_a_cast() -> void:
	var runner := scene_runner("res://ui/hud/regions/forecast_panel/forecast_panel_region.tscn")
	var panel := runner.scene() as ForecastPanelRegion
	var context := _context()
	context["ability"]["is_spell"] = true
	context["ability"]["breath_cost"] = 3
	context["unit"]["breath"] = 15
	context["fizzle"] = {"agreement_integrity": 40.0, "pitch": 2}

	panel.set_forecast_context(context)

	var expected: Dictionary = Resolution.resolve(context)
	assert_str(panel.forecast.text).contains(
		"FIZZLE %.0f%%" % float(expected["fizzle_percent"])
	)


func _context() -> Dictionary:
	return {"unit": {"id": "caster", "attack_scale": 1.0, "harmony": 0}, "ability": {"id": "strike", "power": 10, "element_id": &"zhur", "elements": [&"zhur"], "magnitude": &"note", "matrix_multiplier": 1.0}, "target": {"id": "target", "hp": 20, "element_id": &"tham", "attunements": {}}, "source_tile": {"charge_element_id": "", "charge_level": 0}, "target_tile": {"charge_element_id": "", "charge_level": 0}, "weather": {"weather_hush": false}, "facing": {"multiplier": 1.0}}


func test_forecast_shows_actual_hit_chance_and_modifiers_without_the_roll() -> void:
	var runner := scene_runner("res://ui/hud/regions/forecast_panel/forecast_panel_region.tscn")
	var panel := runner.scene() as ForecastPanelRegion
	var context := _context()
	context["to_hit_enabled"] = true
	context["unit"]["alacrity"] = 4
	context["target"]["alacrity"] = 2
	context["facing"] = {"id": &"side"}
	context["height_advantage_steps"] = -1
	panel.set_forecast_context(context)
	assert_str(panel.forecast.text).contains("HIT 78%")
	assert_str(panel.accuracy_details.text).contains("Alacrity +4 pp")
	assert_str(panel.accuracy_details.text).contains("Facing +8 pp")
	assert_str(panel.accuracy_details.text).contains("Height -4 pp")
	assert_str(panel.accuracy_details.text).contains("Final hit chance 78%")
	assert_str(panel.accuracy_summary.text).is_equal("Accuracy: Height -4 pp · Facing +8 pp · 1 more in details")
	assert_bool(panel.accuracy_details.visible).is_false()
	panel.aim_details.button_pressed = true
	assert_bool(panel.accuracy_details.visible).is_true()
	assert_bool(panel.forecast.text.contains("rolled")).is_false()


func test_legacy_auto_hit_forecast_does_not_claim_ninety_percent() -> void:
	var runner := scene_runner("res://ui/hud/regions/forecast_panel/forecast_panel_region.tscn")
	var panel := runner.scene() as ForecastPanelRegion
	panel.set_forecast_context(_context())
	assert_str(panel.forecast.text).contains("HIT 100%")
	assert_str(panel.accuracy_summary.text).is_equal("Guaranteed hit")


func test_aim_summary_quotes_ct_and_clears_stale_probabilities_on_refusal() -> void:
	var runner := scene_runner("res://ui/hud/regions/forecast_panel/forecast_panel_region.tscn")
	var panel := runner.scene() as ForecastPanelRegion
	var context := _context()
	panel.set_forecast_context(context)
	panel.aim_row.show()
	panel.show_aim_forecast({
		"allowed": true, "ap_cost": 3, "ct_cost": 45, "damage_on_hit": 8,
		"resolution": Resolution.resolve(context),
		"injury_forecast": {"eligible": true, "chance_on_hit": 50, "overall_chance": 50},
	}, &"arm", true)
	assert_str(panel.aim_stats.text).contains("COST 45 CT")
	assert_str(panel.aim_consequence.text).contains("50% ON HIT")
	panel.show_aim_forecast({"allowed": false, "message": "That location is not exposed."}, &"arm", true)
	assert_str(panel.aim_stats.text).is_equal("UNAVAILABLE")
	assert_str(panel.aim_consequence.text).is_equal("That location is not exposed.")
	assert_bool(panel.accuracy_summary.visible).is_false()
	assert_str(panel.accuracy_details.text).is_empty()
	panel.clear_aim_options()
	assert_bool(panel.aim_summary.visible).is_false()
	assert_bool(panel.forecast.visible).is_true()


func test_aim_summary_masks_hidden_damage_on_both_future_hits_and_misses() -> void:
	var runner := scene_runner("res://ui/hud/regions/forecast_panel/forecast_panel_region.tscn")
	var panel := runner.scene() as ForecastPanelRegion
	var context := _context()
	context["to_hit_enabled"] = true
	context["hidden_draw"] = {"table_id": "test", "rows": [{"id": "secret", "weight": 1, "damage_bonus": 7}]}
	var hit_seen := false
	var miss_seen := false
	var expected := ""
	for seed_value: int in 50:
		context["seed"] = seed_value
		var resolution := Resolution.resolve(context)
		hit_seen = hit_seen or bool(resolution["hit"])
		miss_seen = miss_seen or not bool(resolution["hit"])
		panel.set_forecast_context(context)
		panel.aim_row.show()
		panel.show_aim_forecast({
			"allowed": true, "damage_on_hit": int(Resolution.preview_on_hit(context)["damage"]),
			"resolution": resolution, "ap_cost": 3,
		}, &"arm", false)
		assert_str(panel.aim_stats.text).contains("DAMAGE ? ON HIT")
		if expected.is_empty():
			expected = panel.aim_stats.text
		assert_str(panel.aim_stats.text).is_equal(expected)
	assert_bool(hit_seen).is_true()
	assert_bool(miss_seen).is_true()


func test_forecast_damage_does_not_reveal_the_upcoming_hit_or_fizzle() -> void:
	var runner := scene_runner("res://ui/hud/regions/forecast_panel/forecast_panel_region.tscn")
	var panel := runner.scene() as ForecastPanelRegion
	var context := _context()
	context["to_hit_enabled"] = true
	context["ability"]["is_spell"] = true
	context["fizzle_percent_override"] = 50.0
	var observed_hit := false
	var observed_miss := false
	var observed_fizzle := false
	var expected_text := ""
	for seed_value: int in 50:
		context["seed"] = seed_value
		var before := context.duplicate(true)
		panel.set_forecast_context(context)
		var result := panel.forecast_result()
		observed_hit = observed_hit or bool(result["hit"])
		observed_miss = observed_miss or not bool(result["hit"])
		observed_fizzle = observed_fizzle or bool(result["fizzled"])
		if expected_text.is_empty():
			expected_text = panel.forecast.text
		assert_str(panel.forecast.text).is_equal(expected_text)
		assert_dict(context).is_equal(before)
	assert_bool(observed_hit).is_true()
	assert_bool(observed_miss).is_true()
	assert_bool(observed_fizzle).is_true()
	assert_str(expected_text).contains("ON HIT")
	assert_str(expected_text).contains("FIZZLE 50%")


func test_forecast_masks_hidden_draw_rows_until_revealed_even_on_a_miss() -> void:
	var runner := scene_runner("res://ui/hud/regions/forecast_panel/forecast_panel_region.tscn")
	var panel := runner.scene() as ForecastPanelRegion
	var context := _context()
	context["hidden_draw"] = {
		"table_id": "attribution", "seed_key": "forecast",
		"rows": [{"id": "secret_surge", "bonus_damage": 4}],
	}
	context["to_hit_enabled"] = true
	context["target"]["alacrity"] = 100
	for seed_value: int in 100:
		context["seed"] = seed_value
		if not bool(Resolution.resolve(context)["hit"]):
			break
	assert_bool(Resolution.resolve(context)["hit"]).is_false()
	panel.set_forecast_context(context)
	assert_str(panel.forecast.text).contains("FORECAST ? ON HIT")
	assert_bool(panel.forecast.text.contains("secret_surge")).is_false()
	context["reveal"] = true
	panel.set_forecast_context(context)
	assert_bool(panel.forecast.text.contains("FORECAST ?")).is_false()
	assert_str(panel.forecast.text).contains("TRUE")


func test_accuracy_explains_visibility_injuries_and_limits_without_mutating_the_quote() -> void:
	var runner := scene_runner("res://ui/hud/regions/forecast_panel/forecast_panel_region.tscn")
	var panel := runner.scene() as ForecastPanelRegion
	var context := _context()
	context["to_hit_enabled"] = true
	context["visibility"] = {"applies": true, "level": "obscured"}
	context["attacker_injury_modifiers"] = [{"label": "Injury: Arm", "percentage_points": -60}]
	var resolution := Resolution.resolve(context)
	var original := resolution.duplicate(true)
	panel.show_action_forecast({"allowed": true, "damage_on_hit": 10, "damage": 0, "resolution": resolution}, context)
	assert_str(panel.accuracy_summary.text).contains("Injury: Arm -60 pp · Visibility: obscured -25 pp")
	assert_str(panel.accuracy_summary.text).contains("Chance limited to 5%")
	assert_str(panel.accuracy_summary.text).not_contains("+0 pp")
	assert_str(panel.accuracy_details.text).contains("Base 70%")
	assert_str(panel.accuracy_details.text).contains("Chance limits (5–95%) +20 pp")
	assert_str(panel.accuracy_details.text).contains("Final hit chance 5%")
	assert_dict(resolution).is_equal(original)
	# A new, clear forecast replaces all previous causes without resetting the open toggle.
	panel.aim_details.button_pressed = true
	context["visibility"] = {"applies": true, "level": "clear"}
	context.erase("attacker_injury_modifiers")
	panel.set_forecast_context(context)
	assert_str(panel.accuracy_summary.text).is_equal("No accuracy modifiers")
	assert_str(panel.accuracy_details.text).contains("Final hit chance 70%")
	assert_str(panel.accuracy_details.text).not_contains("Injury")
	assert_bool(panel.accuracy_details.visible).is_true()
	context["unit"]["alacrity"] = 30
	panel.set_forecast_context(context)
	assert_str(panel.accuracy_details.text).contains("Chance limits (5–95%) -35 pp")
	assert_str(panel.accuracy_summary.text).contains("Chance limited to 95%")
	context["unit"]["hit"] = true
	panel.set_forecast_context(context)
	assert_str(panel.accuracy_summary.text).is_equal("Guaranteed hit")
	assert_str(panel.accuracy_details.text).contains("Guaranteed hit overrides accuracy modifiers")
	assert_str(panel.accuracy_details.text).contains("Final hit chance 100%")


func test_accuracy_clears_on_refusal_class_command_and_action_reset() -> void:
	var runner := scene_runner("res://ui/hud/regions/forecast_panel/forecast_panel_region.tscn")
	var panel := runner.scene() as ForecastPanelRegion
	var context := _context()
	context["to_hit_enabled"] = true
	for reset: String in ["refusal", "pulse", "class_command", "clear"]:
		panel.set_forecast_context(context)
		panel.aim_details.button_pressed = true
		assert_bool(panel.accuracy_details.visible).is_true()
		match reset:
			"refusal":
				panel.show_action_forecast({"allowed": false, "message": "A wall blocks line of fire."})
				assert_str(panel.forecast.text).is_equal("A wall blocks line of fire.")
			"pulse":
				panel.pulse_refusal("Out of range.")
			"class_command":
				panel.show_action_forecast({"allowed": true, "class_command": true, "description": "Guard"})
			"clear":
				panel.clear_aim_options()
		assert_bool(panel.accuracy_summary.visible).is_false()
		assert_bool(panel.accuracy_details.visible).is_false()
		assert_str(panel.accuracy_details.text).is_empty()
