extends "res://test/integration/test_gate_t1_clearability.gd"
## Hex grid H2 (owner item 34; docs/design/hex-grid-plan-2026-11-03.md): Gate T-1 on hexes. Every
## clearability case of the square suite runs again with `soul_meter/grid/hex` on: each build must
## still win at least 80% of 40 seeded fights per encounter.

var _hex_setting_before: Variant


func before_test() -> void:
	_hex_setting_before = ProjectSettings.get_setting(IsoGrid.HEX_SETTING, false)
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, true)


func after_test() -> void:
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, _hex_setting_before)
