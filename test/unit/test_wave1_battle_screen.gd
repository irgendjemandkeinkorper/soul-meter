extends GdUnitTestSuite
## Wave 1 (Fallout 2 adoption): every command label carries its AP cost and the combat
## controls declare a prominent END TURN and a confirm for the Defining Strike. Since the
## one-bar presentation (owner 2026-11-01) those live on the field HUD's CombatBar, not on a
## separate battle screen.

const COMBAT_BAR_SCRIPT := "res://ui/hud/combat_bar.gd"


func test_every_battle_command_label_includes_its_ap_cost() -> void:
	var bar_script := load(COMBAT_BAR_SCRIPT) as GDScript
	var bar: Variant = bar_script.new()
	var action := CombatAction.new()
	action.display_name = "Measured Strike"
	action.ap_cost = 3

	assert_str(bar._short_action_text(action)).is_equal("MEASURED STRIKE · 3 AP")
	bar.free()


func test_combat_bar_declares_prominent_end_turn_and_confirm_controls() -> void:
	var source := FileAccess.get_file_as_string(COMBAT_BAR_SCRIPT)
	assert_str(source).contains("EndTurnButton")
	assert_str(source).contains("Battle.end_turn")
	assert_str(source).contains("ConfirmDefiningStrike")
	assert_str(source).contains("Battle.use_defining_strike")
