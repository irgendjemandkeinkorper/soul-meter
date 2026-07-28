extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

func test_open_inventory_screen() -> void:
	# Load the world/test_room.tscn (the field room scene)
	var runner := scene_runner("res://world/test_room.tscn")
	assert_object(runner).is_not_null()

	# Wait for a few frames to let everything initialize
	await runner.simulate_frames(10)

	# Assert that no screens are initially open
	assert_bool(UIManager.is_open()).is_false()

	# Open the inventory screen programmatically (as UI InputEvents are disabled in headless mode)
	UIManager.open(UIManager.INVENTORY, true)
	await runner.simulate_frames(10)

	# Assert that the inventory screen is now open
	assert_bool(UIManager.is_open()).is_true()

	# Find the inventory screen instance
	var inventory_screen: Node = null
	for child in UIManager.get_children():
		if child.name.to_lower().contains("inventory"):
			inventory_screen = child
			break

	assert_object(inventory_screen).is_not_null()

	# Find the ItemList inside the screen to verify items are visible
	var item_list: ItemList = _find_child_by_type(inventory_screen, "ItemList")
	assert_object(item_list).is_not_null()

	# Assert that all 6 starting items are visible in the ItemList
	assert_int(item_list.item_count).is_equal(6)

	# Verify specific item names are in the ItemList
	var expected_titles := [
		"Taubstummer Axe",
		"Captured Reflection",
		"Soul Gauge",
		"Loam Bread  ×5",
		"Cinder-Ink Vial  ×2",
		"QUINE Shard"
	]

	for i in range(6):
		assert_str(item_list.get_item_text(i)).is_equal(expected_titles[i])

	# Programmatically close the screen
	UIManager.back()
	await runner.simulate_frames(10)

	# Assert that it is closed
	assert_bool(UIManager.is_open()).is_false()


func _find_child_by_type(parent: Node, type_name: String) -> Node:
	for child in parent.get_children():
		if child.get_class() == type_name:
			return child
		var res := _find_child_by_type(child, type_name)
		if res != null:
			return res
	return null
