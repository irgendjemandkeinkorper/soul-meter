extends GdUnitTestSuite

var _game_state_before: Dictionary
var _target_scene_before := ""
var _pending_cost_before := 0
var _in_progress_before := false


func before_test() -> void:
	_game_state_before = GameState.to_dict()
	_target_scene_before = GameFlow._target_scene
	_pending_cost_before = GameFlow._pending_fast_travel_cost
	_in_progress_before = GameFlow._fast_travel_in_progress
	GameFlow._pending_fast_travel_cost = 0
	GameFlow._fast_travel_in_progress = false
	GameState.flags.clear()
	GameState.set_gp(250)


func after_test() -> void:
	GameState.from_dict(_game_state_before)
	GameFlow._target_scene = _target_scene_before
	GameFlow._pending_fast_travel_cost = _pending_cost_before
	GameFlow._fast_travel_in_progress = _in_progress_before


func test_registry_contains_only_valid_ratified_hubs() -> void:
	assert_array(FastTravelRegistry.validate()).is_empty()
	assert_int(FastTravelRegistry.all().size()).is_equal(1)
	var dom := FastTravelRegistry.by_id(&"dom")
	assert_str(dom["scene_path"]).is_equal("res://world/starting_town.tscn")
	assert_str(dom["display_name"]).is_equal("Dom")
	assert_int(dom["base_cost_gp"]).is_greater(0)


func test_discovery_survives_game_state_round_trip() -> void:
	assert_bool(GameState.discover_fast_travel_hub(&"dom")).is_true()
	assert_bool(GameState.discover_fast_travel_hub(&"dom")).is_false()
	var saved := GameState.to_dict()
	GameState.flags.clear()
	assert_bool(GameState.is_fast_travel_hub_discovered(&"dom")).is_false()
	assert_bool(GameState.from_dict(saved)).is_true()
	assert_bool(GameState.is_fast_travel_hub_discovered(&"dom")).is_true()


func test_unknown_hub_cannot_be_discovered() -> void:
	assert_bool(GameState.discover_fast_travel_hub(&"unratified-hub")).is_false()
	assert_bool(GameState.is_fast_travel_hub_discovered(&"unratified-hub")).is_false()


func test_fast_travel_routes_and_deducts_exact_cost() -> void:
	GameState.discover_fast_travel_hub(&"dom")
	var cost: int = FastTravelRegistry.by_id(&"dom")["base_cost_gp"]
	GameState.set_gp(cost + 7)
	GameFlow._target_scene = GameFlow.WILDS_SCENE

	var result := GameFlow.fast_travel(&"dom", GameFlow.WILDS_SCENE)

	assert_bool(result["ok"]).is_true()
	assert_int(GameState.gp).is_equal(7)
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TOWN_SCENE)
	assert_int(GameFlow._pending_fast_travel_cost).is_equal(cost)


func test_failed_fast_travel_never_deducts_gp_or_changes_route() -> void:
	GameState.discover_fast_travel_hub(&"dom")
	GameState.set_gp(0)
	GameFlow._target_scene = GameFlow.WILDS_SCENE

	var unaffordable := GameFlow.fast_travel(&"dom", GameFlow.WILDS_SCENE)
	assert_bool(unaffordable["ok"]).is_false()
	assert_str(unaffordable["error"]).is_equal("insufficient_gp")
	assert_int(GameState.gp).is_equal(0)
	assert_str(GameFlow._target_scene).is_equal(GameFlow.WILDS_SCENE)

	var undiscovered := GameFlow.fast_travel(&"unratified-hub", GameFlow.WILDS_SCENE)
	assert_bool(undiscovered["ok"]).is_false()
	assert_int(GameState.gp).is_equal(0)
	assert_str(GameFlow._target_scene).is_equal(GameFlow.WILDS_SCENE)
