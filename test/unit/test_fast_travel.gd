extends GdUnitTestSuite

# Verbatim pre-index _HUBS fixture. Values and runtime types stay fixed; order is tested separately.
const _EXPECTED_HUBS: Array[Dictionary] = [
	{
		"id": &"dom",
		"scene_path": "res://world/starting_town.tscn",
		"display_name": "Dom",
		# Provisional economy tuning, not lore. Centralized for a later balance pass.
		"base_cost_gp": 25,
	},
	{
		# Hub 2 (C1 / #238; vault proposal approved 2026-10-16). The id is the `canon/<hub>/`
		# directory and the location id; NpcRoster and TownNpcSpawner key the hub's townsfolk on it.
		"id": &"kesselford",
		"scene_path": "res://world/kesselford.tscn",
		"display_name": "Kesselford",
		# PROVISIONAL: a longer road than Dom's local routes; balance pass owns the number.
		"base_cost_gp": 40,
	},
	{
		# Hub 3 (C2 / #239; vault proposal approved 2026-10-16): the grain-road market town past
		# Kesselford. Same contract as Kesselford's row.
		"id": &"ashlaren",
		"scene_path": "res://world/ashlaren.tscn",
		"display_name": "Ashlaren",
		# PROVISIONAL: two roads out from Dom; balance pass owns the number.
		"base_cost_gp": 60,
	},
]

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
	# Dom, Kesselford (hub 2, C1 / #238) and Ashlaren (hub 3, C2 / #239).
	assert_int(FastTravelRegistry.all().size()).is_equal(3)
	var dom := FastTravelRegistry.by_id(&"dom")
	assert_str(dom["scene_path"]).is_equal("res://world/starting_town.tscn")
	assert_str(dom["display_name"]).is_equal("Dom")
	assert_int(dom["base_cost_gp"]).is_greater(0)
	var kesselford := FastTravelRegistry.by_id(&"kesselford")
	assert_str(kesselford["scene_path"]).is_equal("res://world/kesselford.tscn")
	assert_str(kesselford["display_name"]).is_equal("Kesselford")
	assert_int(kesselford["base_cost_gp"]).is_greater(int(dom["base_cost_gp"]))
	assert_str(str(FastTravelRegistry.by_scene("res://world/kesselford.tscn").get("id", ""))).is_equal("kesselford")


func test_index_matches_the_pre_migration_hubs_field_by_field() -> void:
	var actual: Array[Dictionary] = FastTravelRegistry.all()
	var expected: Array[Dictionary] = _EXPECTED_HUBS.duplicate(true)
	assert_int(actual.size()).is_equal(expected.size())
	# Normalize only order here so value identity is independent of the dom-first contract.
	actual.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	expected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	for index: int in expected.size():
		_assert_hub_values(actual[index], expected[index])
		_assert_hub_values(FastTravelRegistry.by_id(expected[index]["id"]), expected[index])
		_assert_hub_values(FastTravelRegistry.by_scene(expected[index]["scene_path"]), expected[index])


func test_hubs_list_dom_first_then_the_remaining_ids_in_order() -> void:
	var ids: Array[StringName] = []
	for hub: Dictionary in FastTravelRegistry.all():
		ids.append(hub["id"])
	assert_array(ids).contains_exactly([&"dom", &"ashlaren", &"kesselford"])


func test_registry_returns_defensive_copies() -> void:
	var hubs: Array[Dictionary] = FastTravelRegistry.all()
	hubs[0].clear()
	hubs.clear()
	var by_id: Dictionary = FastTravelRegistry.by_id(&"dom")
	by_id.clear()
	var by_scene: Dictionary = FastTravelRegistry.by_scene("res://world/starting_town.tscn")
	by_scene.clear()
	assert_int(FastTravelRegistry.all().size()).is_equal(_EXPECTED_HUBS.size())
	_assert_hub_values(FastTravelRegistry.all()[0], _EXPECTED_HUBS[0])
	_assert_hub_values(FastTravelRegistry.by_id(&"dom"), _EXPECTED_HUBS[0])
	_assert_hub_values(FastTravelRegistry.by_scene("res://world/starting_town.tscn"), _EXPECTED_HUBS[0])


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


func _assert_hub_values(actual: Dictionary, expected: Dictionary) -> void:
	assert_int(actual.size()).is_equal(expected.size())
	for field: String in expected:
		var context := "%s.%s" % [expected["id"], field]
		assert_int(typeof(actual.get(field))).override_failure_message(context).is_equal(typeof(expected[field]))
		assert_bool(actual.get(field) == expected[field]).override_failure_message(context).is_true()
