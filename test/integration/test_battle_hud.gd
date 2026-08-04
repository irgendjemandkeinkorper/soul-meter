extends GdUnitTestSuite


func test_hud_renders_all_fr_603_values_from_one_combat_event() -> void:
	var runner := scene_runner("res://ui/hud/battle_hud.tscn")
	var margin := runner.find_child("Margin", true, false) as MarginContainer
	var hud := margin.get_parent() as BattleHUD
	assert_object(hud).is_not_null()
	hud.consume_event(_complete_event())
	await runner.simulate_frames(1)

	var initiative := runner.find_child("Initiative", true, false) as Label
	var balance := runner.find_child("BalanceValue", true, false) as Label
	var ap := runner.find_child("APValue", true, false) as Label
	var pips := runner.find_child("APPips", true, false) as EclipsePips
	var zones := runner.find_child("Zones", true, false) as Label
	var weaknesses := runner.find_child("Weaknesses", true, false) as Label
	assert_str(initiative.text).contains("VEX")
	assert_str(initiative.text).contains("Mustered Bloodbellow")
	assert_str(balance.text).contains("-35")
	assert_str(ap.text).contains("2 / 4")
	assert_int(pips.current_ap).is_equal(2)
	assert_int(pips.maximum_ap).is_equal(4)
	assert_str(zones.text).contains("FRONT  Vex")
	assert_str(zones.text).contains("FLANK  Mustered Bloodbellow")
	assert_str(weaknesses.text).contains("The Oath That Binds It")


func test_check_math_tooltip_shows_required_numbers_and_toggles_off() -> void:
	var runner := scene_runner("res://ui/hud/battle_hud.tscn")
	var margin := runner.find_child("Margin", true, false) as MarginContainer
	var hud := margin.get_parent() as BattleHUD
	hud.consume_event(_complete_event())
	await runner.simulate_frames(1)
	var check_label := runner.find_child("CheckMath", true, false) as Label

	assert_bool(check_label.visible).is_true()
	assert_str(check_label.tooltip_text).contains("Skill 65%")
	assert_str(check_label.tooltip_text).contains("Roll 42")
	assert_str(check_label.tooltip_text).contains("Modifiers +10 Lore, -5 Cover")
	hud.set_check_math_enabled(false)
	assert_bool(check_label.visible).is_false()
	assert_str(check_label.tooltip_text).is_empty()


func test_hud_sources_have_no_domain_reads_or_per_node_theme_overrides() -> void:
	var hud_paths := [
		"res://ui/hud/battle_hud.gd",
		"res://ui/hud/balance_arcs.gd",
		"res://ui/hud/eclipse_pips.gd",
		"res://ui/hud/battle_hud.tscn",
	]
	for path: String in hud_paths:
		var hud_source := FileAccess.get_file_as_string(path)
		assert_bool(hud_source.contains("Battle.")).is_false()
	for path: String in hud_paths + ["res://ui/screens/battle.gd"]:
		var themed_source := FileAccess.get_file_as_string(path)
		assert_bool(themed_source.contains("add_theme_")).is_false()
		assert_bool(themed_source.contains("theme_override")).is_false()


func _complete_event() -> CombatEvent:
	var event := CombatEvent.new()
	event.type = &"check_resolved"
	event.data = {
		"snapshot": {
			"round": 2,
			"balance": -35,
			"active_actor_id": &"ally-0",
			"allies": [
				{
					"id": &"ally-0",
					"display_name": "Vex",
					"hp": 18,
					"max_hp": 20,
					"ap": 2,
					"max_ap": 4,
					"position": &"front",
					"side": &"ally",
				}
			],
			"enemies": [
				{
					"id": &"enemy-0",
					"display_name": "Mustered Bloodbellow",
					"hp": 24,
					"max_hp": 32,
					"ap": 1,
					"max_ap": 3,
					"position": &"flank",
					"side": &"enemy",
				}
			],
		},
		"initiative": [
			{"id": &"ally-0", "display_name": "Vex"},
			{"id": &"enemy-0", "display_name": "Mustered Bloodbellow"},
		],
		"discovered_weaknesses": [
			{
				"id": &"binding-oath",
				"display_name": "The Oath That Binds It",
				"target_id": &"enemy-0",
			}
		],
		"check_math": {
			"skill_percent": 65,
			"roll": 42,
			"modifiers": [
				{"label": "lore", "value": 10},
				{"label": "cover", "value": -5},
			],
		},
	}
	return event
