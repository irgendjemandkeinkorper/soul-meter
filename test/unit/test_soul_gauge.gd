extends GdUnitTestSuite


func test_condition_bands_cover_the_full_gauge() -> void:
	assert_str(SoulGauge.condition_for(100.0)).is_equal("bright")
	assert_str(SoulGauge.condition_for(75.0)).is_equal("bright")
	assert_str(SoulGauge.condition_for(74.9)).is_equal("whole")
	assert_str(SoulGauge.condition_for(50.0)).is_equal("whole")
	assert_str(SoulGauge.condition_for(49.9)).is_equal("frayed")
	assert_str(SoulGauge.condition_for(25.0)).is_equal("frayed")
	assert_str(SoulGauge.condition_for(24.9)).is_equal("guttering")
	assert_str(SoulGauge.condition_for(0.1)).is_equal("guttering")
	assert_str(SoulGauge.condition_for(0.0)).is_equal("husked")


func test_condition_clamps_values_outside_the_gauge_range() -> void:
	assert_str(SoulGauge.condition_for(140.0)).is_equal("bright")
	assert_str(SoulGauge.condition_for(-10.0)).is_equal("husked")


func test_every_condition_has_diegetic_explanation() -> void:
	for condition in ["bright", "whole", "frayed", "guttering", "husked"]:
		assert_str(SoulGauge.condition_description(condition)).is_not_empty()
