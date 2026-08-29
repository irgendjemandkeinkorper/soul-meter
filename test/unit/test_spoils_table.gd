extends GdUnitTestSuite

const PROTOSET_PATH := "res://data/generated/gloot_prototree.json"
const ROUTE_ENCOUNTERS: Array[StringName] = [
	&"bog-wight",
	&"loam-boar",
	&"dorthkor-vanguard",
]


func test_same_seed_and_slot_return_the_same_spoils() -> void:
	var first: Array[Dictionary] = SpoilsTable.roll(&"loam-boar", 7421, 0)
	var second: Array[Dictionary] = SpoilsTable.roll(&"loam-boar", 7421, 0)

	assert_array(first).is_equal(second)


func test_slot_index_selects_a_distinct_random_stream() -> void:
	var found_distinct_result := false
	for journey_seed: int in range(1, 128):
		var first_slot: Array[Dictionary] = SpoilsTable.roll(&"loam-boar", journey_seed, 0)
		var second_slot: Array[Dictionary] = SpoilsTable.roll(&"loam-boar", journey_seed, 1)
		if first_slot != second_slot:
			found_distinct_result = true
			break

	assert_bool(found_distinct_result).is_true()


func test_unknown_encounter_returns_no_spoils() -> void:
	var spoils: Array[Dictionary] = SpoilsTable.roll(&"unknown-encounter", 42, 0)

	assert_array(spoils).is_empty()


func test_every_spoil_item_resolves_in_generated_prototree() -> void:
	var inventory: Inventory = auto_free(Inventory.new())
	var protoset: Resource = load(PROTOSET_PATH)
	inventory.protoset = protoset
	var resolved_item_ids: Dictionary = {}

	for encounter_id: StringName in ROUTE_ENCOUNTERS:
		for journey_seed: int in range(1, 128):
			var spoils: Array[Dictionary] = SpoilsTable.roll(encounter_id, journey_seed, 0)
			for spoil: Dictionary in spoils:
				var item_id := String(spoil["item_id"])
				if resolved_item_ids.has(item_id):
					continue
				var item: InventoryItem = inventory.create_and_add_item(item_id)
				assert_object(item).is_not_null()
				# create_and_add_item falls back to the prototree's first
				# prototype for unknown ids — assert the id round-trips.
				assert_str(item.get_prototype().get_prototype_id()).is_equal(item_id)
				resolved_item_ids[item_id] = true

	assert_int(resolved_item_ids.size()).is_equal(6)
