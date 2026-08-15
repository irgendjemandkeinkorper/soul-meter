extends GdUnitTestSuite

const InventoryScreenScript := preload("res://ui/screens/inventory.gd")

var _inventory_before: Dictionary


func before_test() -> void:
	_inventory_before = GameState.inventory.serialize()
	GameState.inventory.clear()


func after_test() -> void:
	GameState.inventory.deserialize(_inventory_before)


func test_inventory_uses_three_column_gloot_layout() -> void:
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(2)

	var body_columns := runner.find_child("InventoryColumns", true, false) as HBoxContainer
	assert_object(body_columns).is_not_null()
	assert_int(body_columns.get_child_count()).is_equal(3)
	assert_object(runner.find_child("BagGrid", true, false) as CtrlInventoryGrid).is_not_null()
	assert_object(runner.find_child("Equipment_main", true, false) as CtrlInventoryGrid).is_not_null()


func test_equipment_transfer_accepts_matching_slot_and_rejects_mismatch() -> void:
	var source: Inventory = auto_free(Inventory.new())
	source.protoset = load("res://data/generated/gloot_prototree.json")
	var equipment: Inventory = auto_free(InventoryScreenScript.make_equipment_inventory(source.protoset))
	var axe: InventoryItem = source.create_and_add_item(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	axe.set_property("slot", "main")

	assert_bool(InventoryScreenScript.transfer_to_equipment(axe, equipment, &"off")).is_false()
	assert_bool(source.has_item(axe)).is_true()
	assert_bool(InventoryScreenScript.transfer_to_equipment(axe, equipment, &"main")).is_true()
	assert_bool(equipment.has_item(axe)).is_true()
	assert_bool(source.has_item(axe)).is_false()
	assert_bool(InventoryScreenScript.transfer_from_equipment(axe, source)).is_true()
	assert_bool(source.has_item(axe)).is_true()
