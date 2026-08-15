extends GdUnitTestSuite

const InventoryScreenScript := preload("res://ui/screens/inventory.gd")

var _inventory_before: Dictionary
var _equipped_before: Dictionary


func before_test() -> void:
	_inventory_before = GameState.inventory.serialize()
	_equipped_before = GameState.equipped_slots.duplicate(true)
	GameState.inventory.clear()
	GameState.equipped_slots.clear()


func after_test() -> void:
	GameState.inventory.deserialize(_inventory_before)
	GameState.equipped_slots = _equipped_before


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


func test_pandora_equip_slot_values_resolve_to_rail_slots() -> void:
	var source: Inventory = auto_free(Inventory.new())
	source.protoset = load("res://data/generated/gloot_prototree.json")
	var axe: InventoryItem = source.create_and_add_item(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	# Seeded prototypes carry equip_slot="main_hand", not slot="main".
	assert_str(String(InventoryScreenScript.slot_of(axe))).is_equal("main")


func test_equipped_item_survives_screen_close_and_reopen() -> void:
	var axe: InventoryItem = GameState.inventory.create_and_add_item(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(2)
	var screen: InventoryScreen = runner.scene()
	screen._on_item_selected(axe)
	screen._equip_selected()
	assert_bool(GameState.inventory.has_item(axe)).is_false()

	# Closing the screen returns the item to the bag but records the equipped slot...
	runner.scene().free()
	assert_str(str(GameState.equipped_slots.get("main", ""))).is_equal(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	assert_int(GameState.inventory.get_items_with_prototype_id(ItemIds.WEAPONS_TAUBSTUMMER_AXE).size()).is_equal(1)

	# ...and the record round-trips through the save payload.
	var payload := GameState.to_dict()
	GameState.equipped_slots.clear()
	assert_bool(GameState.from_dict(payload)).is_true()
	assert_str(str(GameState.equipped_slots.get("main", ""))).is_equal(ItemIds.WEAPONS_TAUBSTUMMER_AXE)

	# ...so a fresh screen re-seats it into the main-hand slot.
	var reopened := scene_runner("res://ui/screens/inventory.tscn")
	await reopened.simulate_frames(2)
	var second: InventoryScreen = reopened.scene()
	var slot_inventory: Inventory = second._equipment[&"main"]
	assert_int(slot_inventory.get_item_count()).is_equal(1)
