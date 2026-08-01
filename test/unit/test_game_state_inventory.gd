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


func test_save_round_trip_restores_inventory_flags_soul_and_party() -> void:
	state.flags = {"bog_wight_defeated": true}
	state.soul_meter = 27.5
	var member := PartyMember.new()
	member.display_name = "Vex"
	member.hp = 17
	state.party.append(member)
	var sprigs: InventoryItem = state.inventory.create_and_add_item(
		ItemIds.MATERIALS_LOAMROOT_SPRIG
	)
	sprigs.set_stack_size(3)
	var snapshot: Dictionary = state.to_dict()

	state.flags.clear()
	state.soul_meter = 100.0
	state.party.clear()
	state.inventory.clear()

	assert_bool(state.from_dict(snapshot)).is_true()
	assert_bool(state.get_flag("bog_wight_defeated")).is_true()
	assert_float(state.soul_meter).is_equal_approx(27.5, 0.001)
	assert_int(state.party.size()).is_equal(1)
	assert_str(state.party[0].display_name).is_equal("Vex")
	assert_int(state.party[0].hp).is_equal(17)
	assert_int(state.item_count(ItemIds.MATERIALS_LOAMROOT_SPRIG)).is_equal(3)
