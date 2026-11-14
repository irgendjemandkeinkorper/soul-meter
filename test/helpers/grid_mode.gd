extends RefCounted
## Test-only switch for the grid a suite is written for (hex slice H3b, owner item 34).
##
## The game runs on hexes (`soul_meter/grid/hex` in project.godot). A suite written in square
## cells and square distances on a made-up board keeps testing the square grid, which is still
## a supported mode: it calls `use_squares()` in `before()` and `restore()` in `after()`. Each
## rule such a suite covers has its hex counterpart in a hex suite (test_iso_grid_hex,
## test_grid_battlefield_hex, test_hex_rules and test_hex_combat).
##
## Tests on the real maps do not pin: they name authored ground cells and convert them with
## `IsoGrid.cell_at_square()`, so they run on whichever grid the game uses.

static func use_squares() -> Variant:
	var before: Variant = ProjectSettings.get_setting(IsoGrid.HEX_SETTING, false)
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, false)
	return before


static func use_hexes() -> Variant:
	var before: Variant = ProjectSettings.get_setting(IsoGrid.HEX_SETTING, false)
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, true)
	return before


static func restore(before: Variant) -> void:
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, before)
