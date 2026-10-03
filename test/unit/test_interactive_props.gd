extends GdUnitTestSuite

const CHEST_SCENE := preload("res://actors/chest/chest.tscn")
const PICKUP_SCENE := preload("res://actors/pickup/pickup.tscn")
const SWITCH_SCENE := preload("res://actors/switch/switch.tscn")
const LOOT_ID := "materials/loamroot_sprig"

var _game_state_before: Dictionary


func before_test() -> void:
	_game_state_before = GameState.to_dict()
	if GameState.flag_changed.is_connected(QuestRegistry._on_flag_changed):
		GameState.flag_changed.disconnect(QuestRegistry._on_flag_changed)
	if GameState.inventory_changed.is_connected(QuestRegistry._on_inventory_changed):
		GameState.inventory_changed.disconnect(QuestRegistry._on_inventory_changed)
	GameState.flags.clear()
	GameState.inventory.clear()


func after_test() -> void:
	GameState.from_dict(_game_state_before)


func test_chest_opens_persistent_container_without_granting_everything() -> void:
	var chest: Chest = auto_free(CHEST_SCENE.instantiate())
	chest.container_id = "unit-test-chest"
	chest.loot = [{"item_id": LOOT_ID, "quantity": 2}]
	add_child(chest)
	assert_str(chest.get_node("ClosedSprite").texture.resource_path).is_equal(Chest.CLOSED_TEXTURE_PATH)
	assert_str(chest.get_node("OpenSprite").texture.resource_path).is_equal(Chest.OPEN_TEXTURE_PATH)

	chest._apply_interaction()
	assert_int(GameState.item_count(LOOT_ID)).is_equal(0)
	assert_bool(GameState.get_flag("chest_opened", false)).is_true()
	assert_array(GameState.loot_container_contents(chest.container_id)).is_equal(chest.loot)
	assert_bool(chest.get_node("OpenSprite").visible).is_true()
	assert_bool(chest.get_node("ClosedSprite").visible).is_false()
	UIManager.close_all()


func test_pickup_is_an_interaction_and_only_completes_after_item_is_added() -> void:
	var pickup: Pickup = auto_free(PICKUP_SCENE.instantiate())
	pickup.item_id = LOOT_ID
	pickup.amount = 2
	pickup.completion_flag = "unit_pickup_taken"
	add_child(pickup)
	assert_str(pickup.get_node("ItemSprite").texture.resource_path).is_equal(
		"res://assets/generated/sprites/items/loamroot_sprig--icon.png"
	)
	assert_str(pickup.get_node("Sign").text).is_equal("Loamroot Sprig")
	assert_bool(pickup.get_node("Marker").visible).is_false()

	assert_int(GameState.item_count(LOOT_ID)).is_equal(0)
	assert_bool(GameState.flag_is_true("unit_pickup_taken")).is_false()
	pickup._apply_interaction()
	assert_int(GameState.item_count(LOOT_ID)).is_equal(2)
	assert_bool(GameState.flag_is_true("unit_pickup_taken")).is_true()
	assert_bool(pickup.is_queued_for_deletion()).is_true()


func test_unknown_pickup_keeps_a_visible_fallback() -> void:
	var pickup: Pickup = auto_free(PICKUP_SCENE.instantiate())
	pickup.item_id = "missing-item"
	add_child(pickup)
	assert_bool(pickup.get_node("Marker").visible).is_true()
	assert_object(pickup.get_node("ItemSprite").texture).is_null()
	assert_int(GameState.inventory.get_items().size()).is_equal(0)


func test_switch_toggles_flag_and_emits_observable_signal() -> void:
	var switch: InteractiveSwitch = auto_free(SWITCH_SCENE.instantiate())
	add_child(switch)
	assert_str(switch.get_node("OffSprite").texture.resource_path).is_equal(InteractiveSwitch.OFF_TEXTURE_PATH)
	assert_str(switch.get_node("OnSprite").texture.resource_path).is_equal(InteractiveSwitch.ON_TEXTURE_PATH)
	var flag_events: Array[Array] = []
	GameState.flag_changed.connect(func(flag: String, value: Variant) -> void:
		flag_events.append([flag, value])
	)

	switch._apply_interaction()
	assert_bool(GameState.get_flag("lever_on", false)).is_true()
	assert_int(flag_events.size()).is_equal(1)
	assert_str(flag_events[0][0]).is_equal("lever_on")
	assert_bool(flag_events[0][1]).is_true()

	switch._apply_interaction()
	assert_bool(GameState.get_flag("lever_on", true)).is_false()
	assert_int(flag_events.size()).is_equal(2)
	assert_str(flag_events[1][0]).is_equal("lever_on")
	assert_bool(flag_events[1][1]).is_false()
