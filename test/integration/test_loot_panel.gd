extends GdUnitTestSuite

const LOOT_PANEL_SCENE_PATH := "res://ui/screens/loot_panel/loot_panel.tscn"
const FIRST_ID := ItemIds.MATERIALS_LOAMROOT_SPRIG
const SECOND_ID := ItemIds.CONSUMABLES_LOAM_BREAD

var _inventory_before: Dictionary


func before_test() -> void:
	_inventory_before = GameState.inventory.serialize()
	GameState.inventory.clear()


func after_test() -> void:
	GameState.inventory.deserialize(_inventory_before)


func test_take_then_take_all_updates_rows_and_inventory() -> void:
	var runner := scene_runner(LOOT_PANEL_SCENE_PATH)
	await runner.simulate_frames(2)
	var panel: LootPanel = runner.scene()
	panel.configure("FIELD SPOILS", [
		{"item_id": FIRST_ID, "quantity": 2},
		{"item_id": SECOND_ID, "quantity": 1},
	])
	await runner.simulate_frames(1)

	var first_take := runner.find_child("TakeButton_0", true, false) as Button
	assert_object(first_take).is_not_null()
	first_take.pressed.emit()
	await runner.simulate_frames(1)
	assert_int(GameState.item_count(FIRST_ID)).is_equal(2)
	assert_int(panel.remaining_items().size()).is_equal(1)

	var take_all := runner.find_child("TakeAllButton", true, false) as Button
	assert_object(take_all).is_not_null()
	take_all.pressed.emit()
	await runner.simulate_frames(1)
	assert_int(GameState.item_count(SECOND_ID)).is_equal(1)
	assert_array(panel.remaining_items()).is_empty()
