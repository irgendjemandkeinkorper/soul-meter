extends GdUnitTestSuite
## Wave 1 (Fallout 2 adoption): every command label carries its AP cost and the combat
## controls declare a prominent END TURN and a confirm for the Defining Strike. Since the
## one-bar presentation (owner 2026-11-01) those live on the field HUD's CombatBar, not on a
## separate battle screen.

const COMBAT_BAR_SCRIPT := "res://ui/hud/combat_bar.gd"


## Since the icon tiles (owner 2026-11-02, item 33 follow-up) the AP sits on the tile's badge
## and leads its hover card.
func test_every_battle_command_label_includes_its_ap_cost() -> void:
	var bar_script := load(COMBAT_BAR_SCRIPT) as GDScript
	var bar: Variant = bar_script.new()
	var action := CombatAction.new()
	action.display_name = "Measured Strike"
	action.ap_cost = 3

	var tile: Button = bar._command_tile(action)
	assert_str(tile.text).is_equal("MEASURED STRIKE")
	assert_str((tile.get_node("TileCost") as Label).text).is_equal("3 AP")
	assert_str(str(bar._card_for(action, "", "", {}, -1)["stats"])).starts_with("3 AP")
	tile.free()
	bar.free()


func test_combat_bar_declares_prominent_end_turn_and_confirm_controls() -> void:
	var source := FileAccess.get_file_as_string(COMBAT_BAR_SCRIPT)
	assert_str(source).contains("EndTurnButton")
	assert_str(source).contains("Battle.end_turn")
	assert_str(source).contains("ConfirmDefiningStrike")
	assert_str(source).contains("Battle.use_defining_strike")
