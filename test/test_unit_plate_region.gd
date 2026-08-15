extends GdUnitTestSuite


func test_unit_plate_renders_vitals_element_and_ct_line() -> void:
	var runner := scene_runner("res://ui/hud/regions/unit_plate/unit_plate_region.tscn")
	var plate := runner.scene() as UnitPlateRegion
	var event := CombatEvent.new()
	event.data = {"active_unit": {"name": "Vex", "hp": 12, "max_hp": 20, "element_id": "nul", "ct": 100, "speed": 9, "height": 2, "facing": "sw"}}
	plate.consume_event(event)
	assert_str((runner.find_child("UnitName", true, false) as Label).text).is_equal("Vex")
	assert_str((runner.find_child("HP", true, false) as Label).text).is_equal("HP 12 / 20")
	assert_str((runner.find_child("CT", true, false) as Label).text).contains("CT 100 · SPD 9 · H2 · FACING SW")
