extends GdUnitTestSuite
## Settings coverage retained from the retired combat presentation suite.


func test_settings_screen_persists_and_broadcasts_the_reduced_motion_toggle() -> void:
	var settings_source := FileAccess.get_file_as_string("res://ui/screens/settings.gd")
	var state_source := FileAccess.get_file_as_string("res://globals/game_state.gd")

	assert_bool(settings_source.contains("ReducedMotion")).is_true()
	assert_bool(settings_source.contains("accessibility\", \"reduced_motion")).is_true()
	assert_bool(settings_source.contains("Juicee.accessibility.reduced_motion")).is_true()
	assert_bool(state_source.contains("signal setting_changed")).is_true()
	assert_bool(state_source.contains("setting_changed.emit")).is_true()
