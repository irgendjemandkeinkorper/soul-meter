extends GdUnitTestSuite


func test_unit_plate_renders_vitals_element_and_ct_line() -> void:
	var runner := scene_runner("res://ui/hud/regions/unit_plate/unit_plate_region.tscn")
	var plate := runner.scene() as UnitPlateRegion
	var event := CombatEvent.new()
	event.data = {"active_unit": {"name": "Vex", "hp": 12, "max_hp": 20, "breath": 7, "element_id": "nul", "ct": 100, "speed": 9, "height": 2, "facing": "sw"}}
	plate.consume_event(event)
	assert_str((runner.find_child("UnitName", true, false) as Label).text).is_equal("Vex")
	assert_str((runner.find_child("HP", true, false) as Label).text).is_equal("HP 12 / 20")
	assert_str((runner.find_child("Breath", true, false) as Label).text).is_equal("BREATH 7")
	assert_str((runner.find_child("CT", true, false) as Label).text).contains("CT 100 · SPD 9 · H2 · FACING SW")


func test_plate_falls_back_to_unit_art_when_snapshot_has_no_portrait() -> void:
	var runner := scene_runner("res://ui/hud/regions/unit_plate/unit_plate_region.tscn")
	var plate := runner.scene() as UnitPlateRegion
	var event := CombatEvent.new()
	event.data = {"active_unit": {
		"id": "enemy-bog_wight-0", "display_name": "Bog Wight", "side": "enemy",
		"archetype_id": "bog_wight", "hp": 8, "max_hp": 20,
	}}
	plate.consume_event(event)
	var portrait := runner.find_child("Portrait", true, false) as TextureRect
	assert_object(portrait.texture).is_not_null()


func test_unit_plate_hides_hidden_resource_attribution() -> void:
	var runner := scene_runner("res://ui/hud/regions/unit_plate/unit_plate_region.tscn")
	var plate := runner.scene() as UnitPlateRegion
	var event := CombatEvent.new()
	event.data = {"active_unit": {
		"name": "Vex", "hp": 12, "max_hp": 20,
		"class_resource": {"label": "Attribution", "value": "thunder", "hidden": true},
	}}
	plate.consume_event(event)
	assert_str((runner.find_child("Resource", true, false) as Label).text).is_equal("ATTRIBUTION ??")
