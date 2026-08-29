extends GdUnitTestSuite

const LOOT_PANEL_SCENE_PATH := "res://ui/screens/loot_panel/loot_panel.tscn"
const PICKUP_SCENE := preload("res://actors/pickup/pickup.tscn")
const NOTICE_SCENE := preload("res://ui/hud/consequence_notices.tscn")
const OWNED_FACTION := FactionIds.IRON_COMPANIES
const FIRST_ID := ItemIds.MATERIALS_LOAMROOT_SPRIG
const SECOND_ID := ItemIds.CONSUMABLES_LOAM_BREAD
const CONTAINER_ID := "test-owned-supply-chest"

var _game_state_before: Dictionary = {}
var _reputation_before: Dictionary = {}


func before_test() -> void:
	_game_state_before = GameState.to_dict()
	_reputation_before = Reputation.to_dict()
	GameState.inventory.clear()
	GameState.loot_containers.clear()
	Reputation.from_dict({})


func after_test() -> void:
	assert_bool(GameState.from_dict(_game_state_before)).is_true()
	Reputation.from_dict(_reputation_before)


func test_owned_take_marks_rows_and_records_only_the_first_take_in_session() -> void:
	var runner := scene_runner(LOOT_PANEL_SCENE_PATH)
	await runner.simulate_frames(2)
	var panel: LootPanel = runner.scene()
	var items: Array[Dictionary] = _two_items()
	GameState.ensure_loot_container(CONTAINER_ID, items)
	GameState.begin_loot_container_session(CONTAINER_ID)
	panel.configure("SUPPLY CHEST", items, CONTAINER_ID, OWNED_FACTION)
	await runner.simulate_frames(1)

	var title: Label = runner.find_child("ScreenTitle", true, false) as Label
	var first_label: Label = runner.find_child("ItemLabel_0", true, false) as Label
	assert_str(title.text).is_equal("OWNED — SUPPLY CHEST")
	assert_str(title.theme_type_variation).is_equal("DangerLabel")
	assert_str(first_label.theme_type_variation).is_equal("DangerLabel")

	assert_bool(panel.take_item(0)).is_true()
	assert_bool(panel.take_item(0)).is_true()

	var events: Array[ReputationEvent] = Reputation.events_for(OWNED_FACTION)
	assert_int(events.size()).is_equal(1)
	assert_float(events[0].delta).is_equal_approx(-5.0, 0.001)
	assert_str(events[0].cause).is_equal("Took goods from SUPPLY CHEST")
	assert_str(events[0].scene).is_equal(get_tree().current_scene.scene_file_path)


func test_owned_take_all_records_one_event_for_multiple_rows() -> void:
	var runner := scene_runner(LOOT_PANEL_SCENE_PATH)
	await runner.simulate_frames(2)
	var panel: LootPanel = runner.scene()
	var items: Array[Dictionary] = _two_items()
	GameState.ensure_loot_container(CONTAINER_ID, items)
	GameState.begin_loot_container_session(CONTAINER_ID)
	panel.configure("SUPPLY CHEST", items, CONTAINER_ID, OWNED_FACTION)

	assert_int(panel.take_all()).is_equal(2)
	assert_int(Reputation.events_for(OWNED_FACTION).size()).is_equal(1)


func test_unowned_take_records_no_reputation_event() -> void:
	var runner := scene_runner(LOOT_PANEL_SCENE_PATH)
	await runner.simulate_frames(2)
	var panel: LootPanel = runner.scene()
	panel.configure("ABANDONED CACHE", _two_items())

	assert_bool(panel.take_item(0)).is_true()
	assert_int(Reputation.event_count()).is_equal(0)


func test_reopening_owned_container_starts_a_new_theft_session() -> void:
	var runner := scene_runner(LOOT_PANEL_SCENE_PATH)
	await runner.simulate_frames(2)
	var panel: LootPanel = runner.scene()
	var items: Array[Dictionary] = _two_items()
	GameState.ensure_loot_container(CONTAINER_ID, items)

	GameState.begin_loot_container_session(CONTAINER_ID)
	panel.configure("SUPPLY CHEST", GameState.loot_container_contents(CONTAINER_ID), CONTAINER_ID, OWNED_FACTION)
	assert_bool(panel.take_item(0)).is_true()

	GameState.begin_loot_container_session(CONTAINER_ID)
	panel.configure("SUPPLY CHEST", GameState.loot_container_contents(CONTAINER_ID), CONTAINER_ID, OWNED_FACTION)
	assert_bool(panel.take_item(0)).is_true()

	assert_int(Reputation.events_for(OWNED_FACTION).size()).is_equal(2)


func test_save_load_preserves_theft_written_marker_during_active_session() -> void:
	var runner := scene_runner(LOOT_PANEL_SCENE_PATH)
	await runner.simulate_frames(2)
	var panel: LootPanel = runner.scene()
	var items: Array[Dictionary] = _two_items()
	GameState.ensure_loot_container(CONTAINER_ID, items)
	GameState.begin_loot_container_session(CONTAINER_ID)
	panel.configure("SUPPLY CHEST", items, CONTAINER_ID, OWNED_FACTION)
	assert_bool(panel.take_item(0)).is_true()
	assert_int(Reputation.events_for(OWNED_FACTION).size()).is_equal(1)
	var snapshot: Dictionary = GameState.to_dict()
	GameState.loot_containers.clear()

	assert_bool(GameState.from_dict(snapshot)).is_true()
	assert_bool(GameState.loot_container_theft_recorded(CONTAINER_ID)).is_true()
	panel.configure(
		"SUPPLY CHEST",
		GameState.loot_container_contents(CONTAINER_ID),
		CONTAINER_ID,
		OWNED_FACTION,
	)
	assert_bool(panel.take_item(0)).is_true()
	assert_int(Reputation.events_for(OWNED_FACTION).size()).is_equal(1)

	GameState.begin_loot_container_session(CONTAINER_ID)
	assert_bool(GameState.mark_loot_container_theft_recorded(CONTAINER_ID)).is_true()


func test_owned_take_surfaces_existing_consequence_notice() -> void:
	var notices: ConsequenceNotices = auto_free(NOTICE_SCENE.instantiate()) as ConsequenceNotices
	notices.hold_seconds = 10.0
	notices.slide_seconds = 0.01
	notices.fade_seconds = 0.01
	get_tree().root.add_child(notices)
	var runner := scene_runner(LOOT_PANEL_SCENE_PATH)
	await runner.simulate_frames(2)
	var panel: LootPanel = runner.scene()
	var items: Array[Dictionary] = _two_items()
	GameState.ensure_loot_container(CONTAINER_ID, items)
	GameState.begin_loot_container_session(CONTAINER_ID)
	panel.configure("SUPPLY CHEST", items, CONTAINER_ID, OWNED_FACTION)

	assert_bool(panel.take_item(0)).is_true()
	assert_array(notices.visible_notice_texts()).contains_exactly([
		"IRON COMPANIES WILL REMEMBER — Took goods from SUPPLY CHEST",
	])


func test_owned_pickup_records_once_and_unowned_pickup_records_nothing() -> void:
	var owned: Pickup = PICKUP_SCENE.instantiate() as Pickup
	owned.item_id = FIRST_ID
	owned.owned_by_faction = OWNED_FACTION
	get_tree().root.add_child(owned)
	owned._apply_interaction()
	await get_tree().process_frame

	assert_int(Reputation.events_for(OWNED_FACTION).size()).is_equal(1)

	var unowned: Pickup = PICKUP_SCENE.instantiate() as Pickup
	unowned.item_id = SECOND_ID
	get_tree().root.add_child(unowned)
	unowned._apply_interaction()
	await get_tree().process_frame

	assert_int(Reputation.event_count()).is_equal(1)


func _two_items() -> Array[Dictionary]:
	return [
		{"item_id": FIRST_ID, "quantity": 1},
		{"item_id": SECOND_ID, "quantity": 1},
	]
