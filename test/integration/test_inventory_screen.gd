extends GdUnitTestSuite

const InventoryScreenScript := preload("res://ui/screens/inventory.gd")

var _state_before: Dictionary


func before_test() -> void:
	_state_before = GameState.to_dict()
	GameState.inventory.clear()
	var lead := PartyMember.new()
	lead.id = GameState.PROTAGONIST_ID
	lead.display_name = "Vex"
	var other := PartyMember.new()
	other.id = "iris"
	other.display_name = "Iris"
	GameState.set_party([lead, other])


func after_test() -> void:
	GameState.from_dict(_state_before)


func test_inventory_uses_three_column_gloot_layout() -> void:
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(2)

	var body_columns := runner.find_child("InventoryColumns", true, false) as HBoxContainer
	assert_object(body_columns).is_not_null()
	assert_int(body_columns.get_child_count()).is_equal(3)
	assert_object(runner.find_child("BagGrid", true, false) as CtrlInventoryGrid).is_not_null()
	assert_object(runner.find_child("Equipment_main", true, false) as CtrlInventoryGrid).is_not_null()


func test_opening_a_populated_bag_places_items_without_overlap_or_item_events() -> void:
	# New games and older saves can populate the inventory before the first UI grid exists.
	var old_grid := GameState.inventory.get_constraint(GridConstraint)
	if old_grid != null:
		old_grid.free()
	for prototype_id: String in [ItemIds.WEAPONS_FORGE_HAMMER, ItemIds.CONSUMABLES_HEARTHLOAF, ItemIds.MATERIALS_LOAMROOT_SPRIG]:
		GameState.inventory.create_and_add_item(prototype_id)
	var items := GameState.inventory.get_items().duplicate()
	var removed: Array[InventoryItem] = []
	GameState.inventory.item_removed.connect(func(item: InventoryItem) -> void: removed.append(item))
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(2)
	var grid := GameState.inventory.get_constraint(GridConstraint) as GridConstraint
	var occupied: Array[Rect2i] = []
	for item: InventoryItem in items:
		assert_bool(GameState.inventory.has_item(item)).is_true()
		var rect := grid.get_item_rect(item)
		assert_bool(Rect2i(Vector2i.ZERO, grid.size).encloses(rect)).is_true()
		for prior: Rect2i in occupied:
			assert_bool(prior.intersects(rect)).override_failure_message("Bag items overlap").is_false()
		occupied.append(rect)
	assert_array(removed).is_empty()
	# A player-arranged valid position must survive reopening and the save payload.
	assert_bool(grid.set_item_position(items[0], Vector2i(5, 4))).is_true()
	var saved := GameState.inventory.serialize()
	runner.scene().free()
	assert_bool(GameState.inventory.deserialize(saved)).is_true()
	var reopened := scene_runner("res://ui/screens/inventory.tscn")
	await reopened.simulate_frames(2)
	grid = GameState.inventory.get_constraint(GridConstraint) as GridConstraint
	var restored := GameState.inventory.get_items_with_prototype_id(ItemIds.WEAPONS_FORGE_HAMMER)[0]
	assert_vector(grid.get_item_position(restored)).is_equal(Vector2i(5, 4))


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


func test_overfull_legacy_layout_repair_is_atomic_and_keeps_every_item() -> void:
	var inventory: Inventory = auto_free(Inventory.new())
	inventory.protoset = GameState.inventory.protoset
	inventory.create_and_add_item(ItemIds.CONSUMABLES_HEARTHLOAF)
	inventory.create_and_add_item(ItemIds.MATERIALS_LOAMROOT_SPRIG)
	var grid := GridConstraint.new()
	grid.size = Vector2i.ONE
	inventory.add_child(grid)
	var before := inventory.serialize()
	assert_bool(InventoryScreenScript.repair_bag_layout(grid)).is_false()
	assert_that(inventory.serialize()).is_equal(before)
	assert_int(inventory.get_item_count()).is_equal(2)


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
	assert_bool(GameState.inventory.has_item(axe)).is_true()

	# Closing never moves the physical bag item; the member already owns the slot.
	runner.scene().free()
	assert_str(str(GameState.protagonist().equipped_slots.get("main", ""))).is_equal(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	assert_int(GameState.inventory.get_items_with_prototype_id(ItemIds.WEAPONS_TAUBSTUMMER_AXE).size()).is_equal(1)

	# ...and the record round-trips through the save payload.
	var payload := GameState.to_dict()
	GameState.protagonist().equipped_slots.clear()
	assert_bool(GameState.from_dict(payload)).is_true()
	assert_str(str(GameState.protagonist().equipped_slots.get("main", ""))).is_equal(ItemIds.WEAPONS_TAUBSTUMMER_AXE)

	# ...so a fresh screen re-seats it into the main-hand slot.
	var reopened := scene_runner("res://ui/screens/inventory.tscn")
	await reopened.simulate_frames(2)
	var second: InventoryScreen = reopened.scene()
	var slot_inventory: Inventory = second._equipment[&"main"]
	assert_int(slot_inventory.get_item_count()).is_equal(1)
	var restored: InventoryItem = slot_inventory.get_items()[0]
	assert_str((second.find_child("EquipmentLabel_main", true, false) as Label).text).is_equal(restored.get_title())
	second._drop_on_bag(Vector2.ZERO, restored)
	assert_str((second.find_child("EquipmentLabel_main", true, false) as Label).text).is_equal("EMPTY")
	assert_dict(GameState.protagonist().equipped_slots).is_empty()
	assert_int(GameState.inventory.get_items_with_prototype_id(ItemIds.WEAPONS_TAUBSTUMMER_AXE).size()).is_equal(1)


func test_rapid_selection_only_fades_details_and_keeps_last_item() -> void:
	var first := GameState.inventory.create_and_add_item(ItemIds.CONSUMABLES_HEARTHLOAF)
	var last := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(2)
	var screen := runner.scene() as InventoryScreen
	var position_before := screen.position
	for index: int in 8:
		screen._on_item_selected(first)
		screen._on_item_selected(last)
	assert_vector(screen.position).is_equal(position_before)
	assert_float(screen.modulate.a).is_equal(1.0)
	await get_tree().create_timer(DS.DUR_FAST * 2.0).timeout
	assert_float(screen._detail_column.modulate.a).is_equal_approx(1.0, 0.001)
	assert_str((screen.find_child("ItemName", true, false) as Label).text).is_equal(last.get_title())


func test_dropping_selected_item_clears_details_and_actions() -> void:
	var item := GameState.inventory.create_and_add_item(ItemIds.CONSUMABLES_HEARTHLOAF)
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(2)
	var screen := runner.scene() as InventoryScreen
	screen._on_item_selected(item)
	screen._drop_selected()
	assert_str((screen.find_child("ItemName", true, false) as Label).text).is_equal("SELECT AN ITEM")
	assert_str((screen.find_child("ItemValue", true, false) as Label).text).is_empty()
	assert_int(screen.find_child("ItemStats", true, false).get_child_count()).is_equal(0)
	assert_bool((screen.find_child("EquipButton", true, false) as Button).disabled).is_true()
	assert_bool((screen.find_child("DropButton", true, false) as Button).disabled).is_true()


func test_member_switcher_preserves_equipment_and_refuses_another_members_item() -> void:
	var hammer := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	var spear := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_ROADWARDEN_SPEAR)
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(2)
	var screen := runner.scene() as InventoryScreen
	var picker := screen.find_child("EquipmentMemberPicker", true, false) as OptionButton
	assert_int(picker.item_count).is_equal(2)
	screen._on_item_selected(hammer)
	screen._equip_selected()
	picker.select(1)
	picker.item_selected.emit(1)
	assert_str((screen.find_child("EquipmentLabel_main", true, false) as Label).text).is_equal("EMPTY")
	assert_bool((screen.find_child("EquipButton", true, false) as Button).disabled).is_true()
	assert_str((screen.find_child("ItemRequirement", true, false) as Label).text).contains("Vex")
	assert_bool(screen._can_drop_equipment(Vector2.ZERO, hammer, &"main")).is_false()
	screen._on_equipment_drop(hammer, Vector2.ZERO, &"main")
	assert_dict(GameState.party[1].equipped_slots).is_empty()
	screen._on_item_selected(spear)
	screen._equip_selected()
	assert_int(BattleActor.from_party_member(GameState.party[0], 0).attack).is_equal(GameState.party[0].attack + 2)
	assert_int(BattleActor.from_party_member(GameState.party[1], 1).defense).is_equal(GameState.party[1].defense + 1)
	# Save while the rail is open: all physical items and both owners are present.
	var saved := GameState.to_dict()
	assert_int(GameState.inventory.get_item_count()).is_equal(2)
	assert_bool(GameState.from_dict(saved)).is_true()
	assert_dict(GameState.to_dict()).is_equal(saved)
	picker.select(0)
	picker.item_selected.emit(0)
	assert_str((screen.find_child("EquipmentLabel_main", true, false) as Label).text).is_equal(hammer.get_title())


func test_each_weapon_equips_replaces_and_unequips_through_the_rail() -> void:
	var ids: Array[String] = [ItemIds.WEAPONS_FORGE_HAMMER, ItemIds.WEAPONS_ROADWARDEN_SPEAR, ItemIds.WEAPONS_TAUBSTUMMER_AXE]
	var bonuses: Array[Vector2i] = [Vector2i(2, 0), Vector2i(1, 1), Vector2i(3, -1)]
	for id: String in ids:
		GameState.inventory.create_and_add_item(id)
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(2)
	var screen := runner.scene() as InventoryScreen
	var member := GameState.protagonist()
	for index: int in ids.size():
		var item := GameState.inventory.get_items_with_prototype_id(ids[index])[0]
		assert_bool(screen._can_drop_equipment(Vector2.ZERO, item, &"off")).is_false()
		assert_bool(screen._can_drop_equipment(Vector2.ZERO, item, &"main")).is_true()
		screen._on_equipment_drop(item, Vector2.ZERO, &"main")
		var actor := BattleActor.from_party_member(member, 0)
		assert_int(actor.attack).is_equal(member.attack + bonuses[index].x)
		assert_int(actor.defense).is_equal(member.defense + bonuses[index].y)
		assert_int(GameState.inventory.get_item_count()).is_equal(3)
		screen._on_item_selected(item)
		assert_str((screen.find_child("EquipButton", true, false) as Button).text).is_equal("UNEQUIP")
		assert_bool((screen.find_child("DropButton", true, false) as Button).disabled).is_true()
	screen._equip_selected()
	assert_dict(member.equipped_slots).is_empty()
	assert_int(BattleActor.from_party_member(member, 0).attack).is_equal(member.attack)


func test_rail_selection_unequips_only_its_members_copy() -> void:
	var first := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	var second := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	GameState.equip_item(GameState.party[1], first, &"main")
	GameState.equip_item(GameState.party[0], second, &"main")
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(2)
	var screen := runner.scene() as InventoryScreen
	var rail: Inventory = screen._equipment[&"main"]
	screen._on_item_selected(rail.get_items()[0])
	assert_object(screen._selected_item).is_same(second)
	screen._equip_selected()
	assert_dict(GameState.party[0].equipped_slots).is_empty()
	assert_dict(GameState.party[1].equipped_slots).is_equal({"main": ItemIds.WEAPONS_FORGE_HAMMER})
	assert_int(GameState.inventory.get_item_count()).is_equal(2)
