extends GdUnitTestSuite

const CHEST_SCENE := preload("res://actors/chest/chest.tscn")
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


func test_chest_grants_loot_once_and_persists_open_flag() -> void:
	var chest: Chest = auto_free(CHEST_SCENE.instantiate())
	add_child(chest)
	chest.loot = [{"item_id": LOOT_ID, "quantity": 2}]

	chest._apply_interaction()
	assert_int(GameState.item_count(LOOT_ID)).is_equal(2)
	assert_bool(GameState.get_flag("chest_opened", false)).is_true()

	var saved_state := GameState.to_dict()
	GameState.flags.clear()
	GameState.inventory.clear()
	assert_bool(GameState.from_dict(saved_state)).is_true()
	assert_bool(GameState.get_flag("chest_opened", false)).is_true()

	chest._used = true
	chest._player_in_range = true
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	chest._unhandled_input(interact)
	assert_int(GameState.item_count(LOOT_ID)).is_equal(2)


func test_switch_toggles_flag_and_emits_observable_signal() -> void:
	var switch: InteractiveSwitch = auto_free(SWITCH_SCENE.instantiate())
	add_child(switch)
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
