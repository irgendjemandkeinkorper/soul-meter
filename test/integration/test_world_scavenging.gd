extends GdUnitTestSuite

# Enumerated from disk so a future world scene enters the uniqueness scan
# automatically; the count only guards against enumeration silently breaking.
const KNOWN_WORLD_SCENE_MINIMUM := 26


static func _all_world_scenes() -> Array[String]:
	var scenes: Array[String] = []
	for dir_path: String in ["res://world", "res://world/interiors"]:
		for file_name: String in DirAccess.get_files_at(dir_path):
			if file_name.ends_with(".tscn"):
				scenes.append("%s/%s" % [dir_path, file_name])
	scenes.sort()
	return scenes

const EXPECTED_PLACEMENTS := {
	"res://world/dorthkor_road.tscn": ["dorthkor-road-camp-cache"],
	"res://world/wound_lip.tscn": ["wound-lip-ledge-cache", "wound-lip-guard-kit"],
	"res://world/interiors/cask_warehouse.tscn": ["cask-warehouse-supply-crate"],
	"res://world/interiors/chefs_pantry.tscn": ["chefs-pantry-supply-crate"],
	"res://world/interiors/equipment_forge.tscn": ["equipment-forge-rivet-crate"],
	"res://world/interiors/iron_companies.tscn": ["iron-companies-supply-crate"],
	"res://world/interiors/item_shop.tscn": ["item-shop-backroom-crate"],
	"res://world/interiors/players_house.tscn": ["players-house-provisions"],
	"res://world/interiors/river_shrine.tscn": ["river-shrine-offering-box"],
	"res://world/interiors/shrine_undercroft.tscn": ["shrine-undercroft-offering-box"],
}

var _game_state_before: Dictionary = {}
var _reputation_before: Dictionary = {}


func before_test() -> void:
	_game_state_before = GameState.to_dict()
	_reputation_before = Reputation.to_dict()
	GameState.inventory.clear()
	GameState.loot_containers.clear()
	Reputation.from_dict({})


func after_test() -> void:
	UIManager.close_all()
	assert_bool(GameState.from_dict(_game_state_before)).is_true()
	Reputation.from_dict(_reputation_before)


func test_placed_containers_resolve_with_unique_repository_wide_ids() -> void:
	var all_scenes: Array[String] = _all_world_scenes()
	assert_int(all_scenes.size()).is_greater_equal(KNOWN_WORLD_SCENE_MINIMUM)
	var found_by_scene: Dictionary = {}
	var scene_for_id: Dictionary = {}
	for scene_path: String in all_scenes:
		var packed: PackedScene = load(scene_path) as PackedScene
		assert_object(packed).override_failure_message(scene_path).is_not_null()
		var scene: Node = auto_free(packed.instantiate())
		var scene_ids: Array[String] = []
		for chest: Chest in _find_chests(scene):
			assert_str(chest.container_id).override_failure_message(scene_path).is_not_empty()
			assert_bool(scene_for_id.has(chest.container_id)).override_failure_message(
				"Duplicate container id '%s' in %s and %s"
				% [chest.container_id, scene_for_id.get(chest.container_id, ""), scene_path]
			).is_false()
			scene_for_id[chest.container_id] = scene_path
			scene_ids.append(chest.container_id)
		scene_ids.sort()
		found_by_scene[scene_path] = scene_ids

	assert_int(scene_for_id.size()).is_equal(11)
	for scene_path: String in EXPECTED_PLACEMENTS:
		var expected: Array = (EXPECTED_PLACEMENTS[scene_path] as Array).duplicate()
		expected.sort()
		assert_array(found_by_scene[scene_path]).override_failure_message(scene_path).is_equal(expected)


func test_real_scene_owned_container_take_updates_inventory_and_theft_ledger() -> void:
	var runner := scene_runner("res://world/interiors/river_shrine.tscn")
	await runner.simulate_frames(3)
	var shrine: Node = runner.scene()
	var offering_box: Chest = shrine.find_child("OfferingBox", true, false) as Chest
	assert_object(offering_box).is_not_null()
	assert_str(offering_box.container_id).is_equal("river-shrine-offering-box")
	assert_str(offering_box.owned_by_faction).is_equal(FactionIds.IRONBRAND_SENTINELS)

	offering_box._apply_interaction()
	await runner.simulate_frames(2)
	var panel: LootPanel = _find_loot_panel(get_tree().root)
	assert_object(panel).is_not_null()
	assert_bool(panel.take_item(0)).is_true()

	assert_int(GameState.item_count(ItemIds.RELICS_VOTIVE_CINDER)).is_equal(1)
	var events: Array[ReputationEvent] = Reputation.events_for(FactionIds.IRONBRAND_SENTINELS)
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].cause).is_equal("Took goods from Offering Box")


func _find_chests(root: Node) -> Array[Chest]:
	var found: Array[Chest] = []
	if root is Chest:
		found.append(root as Chest)
	for child: Node in root.get_children():
		found.append_array(_find_chests(child))
	return found


func _find_loot_panel(root: Node) -> LootPanel:
	if root is LootPanel:
		return root as LootPanel
	for child: Node in root.get_children():
		var found: LootPanel = _find_loot_panel(child)
		if found != null:
			return found
	return null
