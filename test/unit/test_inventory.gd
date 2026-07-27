extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const ProtosetPath := "res://data/generated/gloot_prototree.json"

func test_protoset_loads_without_error() -> void:
	var inventory: Inventory = auto_free(Inventory.new())
	var protoset = load(ProtosetPath)
	assert_object(protoset).is_not_null()
	inventory.protoset = protoset
	assert_object(inventory.protoset).is_not_null()


func test_create_and_add_item_succeeds_for_every_item_id() -> void:
	var inventory: Inventory = auto_free(Inventory.new())
	inventory.protoset = load(ProtosetPath)

	var items_to_test := [
		ItemIds.CONSUMABLES_LOAM_BREAD,
		ItemIds.MATERIALS_CINDER_INK_VIAL,
		ItemIds.RELICS_CAPTURED_REFLECTION,
		ItemIds.RELICS_QUINE_SHARD,
		ItemIds.TOOLS_SOUL_GAUGE,
		ItemIds.WEAPONS_TAUBSTUMMER_AXE
	]

	for item_id in items_to_test:
		var item := inventory.create_and_add_item(item_id)
		assert_object(item).is_not_null()
		assert_str(item.get_prototype().get_prototype_id()).is_equal(item_id)


func test_stacking_behavior_for_loam_bread() -> void:
	var inventory: Inventory = auto_free(Inventory.new())
	inventory.protoset = load(ProtosetPath)

	var item := inventory.create_and_add_item(ItemIds.CONSUMABLES_LOAM_BREAD)
	assert_object(item).is_not_null()

	# Initial stack size is 1
	assert_int(item.get_stack_size()).is_equal(1)

	# Set stack size to 5
	item.set_stack_size(5)
	assert_int(item.get_stack_size()).is_equal(5)

	# Max stack size is 10 for Loam Bread
	assert_int(item.get_max_stack_size()).is_equal(10)

	# Check set_stack_size returns true for valid sizes
	var success := item.set_stack_size(10)
	assert_bool(success).is_true()
	assert_int(item.get_stack_size()).is_equal(10)


func test_serialize_deserialize_round_trip() -> void:
	var inventory: Inventory = auto_free(Inventory.new())
	inventory.protoset = load(ProtosetPath)

	# Add some items
	var axe := inventory.create_and_add_item(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	var bread := inventory.create_and_add_item(ItemIds.CONSUMABLES_LOAM_BREAD)
	if bread:
		bread.set_stack_size(5)

	# Serialize
	var data := inventory.serialize()
	assert_dict(data).is_not_empty()

	# Deserialize into a fresh instance
	var fresh_inventory: Inventory = auto_free(Inventory.new())
	var success := fresh_inventory.deserialize(data)
	assert_bool(success).is_true()

	# Verify items and properties are preserved
	assert_int(fresh_inventory.get_item_count()).is_equal(2)

	var fresh_axe := fresh_inventory.get_item_with_prototype_id(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	assert_object(fresh_axe).is_not_null()

	var fresh_bread := fresh_inventory.get_item_with_prototype_id(ItemIds.CONSUMABLES_LOAM_BREAD)
	assert_object(fresh_bread).is_not_null()
	assert_int(fresh_bread.get_stack_size()).is_equal(5)
