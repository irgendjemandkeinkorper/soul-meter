extends GdUnitTestSuite


func test_every_battle_command_label_includes_its_ap_cost() -> void:
	var screen_script := load("res://ui/screens/battle.gd") as GDScript
	var screen: Variant = screen_script.new()
	var action := CombatAction.new()
	action.display_name = "Measured Strike"
	action.ap_cost = 3

	assert_str(screen._short_action_text(action)).is_equal("MEASURED STRIKE · 3 AP")
	screen.free()


func test_battle_screen_declares_prominent_end_turn_and_confirm_controls() -> void:
	var source := FileAccess.get_file_as_string("res://ui/screens/battle.gd")
	assert_str(source).contains("EndTurnButton")
	assert_str(source).contains("Battle.end_turn")
	assert_str(source).contains("ConfirmDefiningStrike")
	assert_str(source).contains("Battle.use_defining_strike")
