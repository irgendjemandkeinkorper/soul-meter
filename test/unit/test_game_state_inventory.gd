extends GdUnitTestSuite

const GameStateScript := preload("res://globals/game_state.gd")

var state


func before_test() -> void:
	state = auto_free(GameStateScript.new())
	state.inventory = auto_free(Inventory.new())
	state.inventory.protoset = load("res://data/generated/gloot_prototree.json")


func test_item_count_sums_matching_stacks() -> void:
	var first: InventoryItem = state.inventory.create_and_add_item(ItemIds.MATERIALS_LOAMROOT_SPRIG)
	first.set_stack_size(2)
	state.inventory.create_and_add_item(ItemIds.MATERIALS_LOAMROOT_SPRIG)

	assert_int(state.item_count(ItemIds.MATERIALS_LOAMROOT_SPRIG)).is_equal(3)


func test_remove_items_consumes_across_stacks() -> void:
	var first: InventoryItem = state.inventory.create_and_add_item(ItemIds.MATERIALS_LOAMROOT_SPRIG)
	first.set_stack_size(2)
	state.inventory.create_and_add_item(ItemIds.MATERIALS_LOAMROOT_SPRIG)

	assert_bool(state.remove_items(ItemIds.MATERIALS_LOAMROOT_SPRIG, 3)).is_true()
	assert_int(state.item_count(ItemIds.MATERIALS_LOAMROOT_SPRIG)).is_equal(0)


func test_remove_items_is_atomic_when_inventory_is_short() -> void:
	state.inventory.create_and_add_item(ItemIds.MATERIALS_LOAMROOT_SPRIG)

	assert_bool(state.remove_items(ItemIds.MATERIALS_LOAMROOT_SPRIG, 3)).is_false()
	assert_int(state.item_count(ItemIds.MATERIALS_LOAMROOT_SPRIG)).is_equal(1)
