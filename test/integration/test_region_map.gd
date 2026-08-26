extends GdUnitTestSuite

const RegionMapScript := preload("res://ui/screens/region_map.gd")

var _game_state_before: Dictionary
var _target_scene_before := ""
var _waiting_for_level_before := false
var _pending_cost_before := 0
var _fallback_scene_before := ""
var _loader_debug_before := false
var _loader_status_before: ResourceLoader.ThreadLoadStatus


func before_test() -> void:
	_game_state_before = GameState.to_dict()
	_target_scene_before = GameFlow._target_scene
	_waiting_for_level_before = GameFlow._waiting_for_level
	_pending_cost_before = GameFlow._pending_fast_travel_cost
	_fallback_scene_before = GameFlow._loading_fallback_scene
	_loader_debug_before = SceneLoader.debug_enabled
	_loader_status_before = SceneLoader.debug_lock_status
	UIManager.close_all()
	get_tree().paused = false
	GameState.flags.clear()
	GameState.set_gp(250)
	GameFlow._pending_fast_travel_cost = 0


func after_test() -> void:
	UIManager.close_all()
	get_tree().paused = false
	GameState.from_dict(_game_state_before)
	GameFlow._target_scene = _target_scene_before
	GameFlow._waiting_for_level = _waiting_for_level_before
	GameFlow._pending_fast_travel_cost = _pending_cost_before
	GameFlow._loading_fallback_scene = _fallback_scene_before
	SceneLoader.debug_enabled = _loader_debug_before
	SceneLoader.debug_lock_status = _loader_status_before


func test_region_map_lists_only_discovered_hubs() -> void:
	assert_array(RegionMapScript.destinations_for(GameFlow.WILDS_SCENE)).is_empty()
	GameState.discover_fast_travel_hub(&"dom")
	var destinations := RegionMapScript.destinations_for(GameFlow.WILDS_SCENE)
	assert_int(destinations.size()).is_equal(1)
	assert_str(destinations[0]["id"]).is_equal("dom")


func test_region_map_marks_current_and_disables_current_or_unaffordable_destination() -> void:
	GameState.discover_fast_travel_hub(&"dom")
	GameState.set_gp(0)
	var runner := scene_runner("res://ui/screens/region_map.tscn")
	await runner.simulate_frames(2)
	var button := runner.find_child("Hub_dom", true, false) as Button
	assert_object(button).is_not_null()
	assert_bool(button.disabled).is_true()
	assert_str(button.text).contains("SILVER")

	var rows := RegionMapScript.destinations_for(GameFlow.TOWN_SCENE)
	assert_bool(rows[0]["is_current"]).is_true()


func test_pause_menu_opens_region_map_through_ui_manager() -> void:
	var runner := scene_runner("res://ui/screens/pause_menu.tscn")
	await runner.simulate_frames(2)
	var button := runner.find_child("RegionMapButton", true, false) as Button
	assert_object(button).is_not_null()
	button.pressed.emit()
	await runner.simulate_frames(2)
	assert_bool(UIManager.is_open()).is_true()
	assert_str(UIManager._stack.back().scene_file_path).is_equal("res://ui/screens/region_map.tscn")


func test_failed_purchase_reports_error_without_spending_gp() -> void:
	GameState.discover_fast_travel_hub(&"dom")
	GameState.set_gp(0)
	var runner := scene_runner("res://ui/screens/region_map.tscn")
	await runner.simulate_frames(2)
	var screen := runner.scene() as RegionMapScreen
	screen._on_destination_pressed(&"dom")
	var status := runner.find_child("TravelStatus", true, false) as Label
	assert_str(status.text).contains("enough silver")
	assert_int(GameState.gp).is_equal(0)


func test_successfully_loaded_hub_is_marked_discovered() -> void:
	var runner := scene_runner(GameFlow.TOWN_SCENE)
	await runner.simulate_frames(2)
	var town := runner.scene()
	assert_object(town).is_not_null()
	if town == null:
		return
	var previous_current_scene := get_tree().current_scene
	get_tree().current_scene = previous_current_scene
	GameFlow._target_scene = GameFlow.TOWN_SCENE
	GameFlow._waiting_for_level = true
	SceneLoader.debug_enabled = true
	SceneLoader.debug_lock_status = ResourceLoader.THREAD_LOAD_LOADED
	GameFlow._on_scene_loaded()
	assert_bool(GameState.is_fast_travel_hub_discovered(&"dom")).is_false()
	get_tree().current_scene = town
	await get_tree().process_frame
	assert_bool(GameState.is_fast_travel_hub_discovered(&"dom")).is_true()
	get_tree().current_scene = previous_current_scene


func test_failed_async_load_refunds_fast_travel_cost() -> void:
	GameState.discover_fast_travel_hub(&"dom")
	var cost: int = FastTravelRegistry.by_id(&"dom")["base_cost_gp"]
	GameState.set_gp(cost + 7)
	var result := GameFlow.fast_travel(&"dom", GameFlow.WILDS_SCENE)
	assert_bool(result["ok"]).is_true()
	assert_int(GameState.gp).is_equal(7)

	GameFlow._waiting_for_level = true
	GameFlow._loading_fallback_scene = ""
	SceneLoader.debug_enabled = true
	SceneLoader.debug_lock_status = ResourceLoader.THREAD_LOAD_FAILED
	GameFlow._process(0.0)

	assert_int(GameState.gp).is_equal(cost + 7)
	assert_int(GameFlow._pending_fast_travel_cost).is_equal(0)
