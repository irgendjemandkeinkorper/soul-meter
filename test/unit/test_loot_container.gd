extends GdUnitTestSuite

const GameStateScript := preload("res://globals/game_state.gd")
const LootPanelScript := preload("res://ui/screens/loot_panel/loot_panel.gd")
const LOOT_ID := ItemIds.MATERIALS_LOAMROOT_SPRIG


func test_container_contents_round_trip_after_taking_only_one_row() -> void:
	var state = auto_free(GameStateScript.new())
	state.inventory = auto_free(Inventory.new())
	state.inventory.protoset = load("res://data/generated/gloot_prototree.json")
	var authored: Array[Dictionary] = [
		{"item_id": LOOT_ID, "quantity": 2},
		{"item_id": ItemIds.CONSUMABLES_LOAM_BREAD, "quantity": 1},
	]
	state.ensure_loot_container("round-trip-chest", authored)
	var remaining: Array[Dictionary] = [
		{"item_id": ItemIds.CONSUMABLES_LOAM_BREAD, "quantity": 1}
	]
	state.set_loot_container_contents("round-trip-chest", remaining)
	var snapshot: Dictionary = state.to_dict()
	state.loot_containers.clear()

	assert_bool(state.from_dict(snapshot)).is_true()
	assert_array(state.loot_container_contents("round-trip-chest")).is_equal(
		[{"item_id": ItemIds.CONSUMABLES_LOAM_BREAD, "quantity": 1}]
	)
	state.ensure_loot_container("round-trip-chest", authored)
	assert_array(state.loot_container_contents("round-trip-chest")).is_equal(
		[{"item_id": ItemIds.CONSUMABLES_LOAM_BREAD, "quantity": 1}]
	)


func test_capacity_refusal_leaves_item_in_source_container() -> void:
	var inventory: Inventory = auto_free(Inventory.new())
	inventory.protoset = load("res://data/generated/gloot_prototree.json")
	var count := ItemCountConstraint.new()
	count.capacity = 1
	inventory.add_child(count)
	inventory.create_and_add_item(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	var contents: Array[Dictionary] = [{"item_id": LOOT_ID, "quantity": 2}]

	assert_bool(LootPanelScript.take_from(contents, 0, inventory)).is_false()
	assert_array(contents).is_equal([{"item_id": LOOT_ID, "quantity": 2}])
	assert_int(inventory.get_item_count()).is_equal(1)
