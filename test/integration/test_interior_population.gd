extends GdUnitTestSuite

const NpcPlacementsData: JSON = preload("res://data/generated/dom_npc_placements.json")
const NpcRosterScript := preload("res://globals/npc_roster.gd")
const VendorData := preload("res://globals/vendor_registry.gd")
const VendorIdsData := preload("res://data/generated/vendor_ids.gd")

var _game_state_before: Dictionary = {}
var _reputation_before: Dictionary = {}


func before_test() -> void:
	_game_state_before = GameState.to_dict()
	_reputation_before = Reputation.to_dict()
	UIManager.close_all()


func after_test() -> void:
	UIManager.close_all()
	GameState.from_dict(_game_state_before)
	Reputation.from_dict(_reputation_before)


func test_all_thirty_indoor_npcs_use_generated_positions_and_dialogue_titles() -> void:
	var root: Dictionary = NpcPlacementsData.data
	var placements: Dictionary = root["placements"]
	var placed_ids := {}
	for entry: BuildingTransitionDefinition in BuildingTransitionRegistry.ENTRIES:
		var interior := _instantiate_interior(entry.destination_scene)
		var expected_ids := _npc_ids_for_scene(placements, entry.destination_scene)
		var npcs := _indoor_npcs(interior)
		assert_int(npcs.size()).is_equal(expected_ids.size())
		for npc_id: String in expected_ids:
			var npc := _npc_by_id(npcs, npc_id)
			assert_object(npc).is_not_null()
			if npc == null:
				continue
			var placement: Dictionary = placements[npc_id]
			var anchor := interior.find_child(str(placement["anchor"]), true, false) as Marker2D
			assert_object(anchor).is_not_null()
			if anchor == null:
				continue
			var expected_position := anchor.position + _offset(placement["offset"])
			var row := NpcRosterScript.get_npc(npc_id)
			var dialogue: Dictionary = row["dialogue"]
			assert_vector(npc.position).is_equal(expected_position)
			assert_str(npc.npc_name).is_equal(row["display_name"])
			assert_str(npc.dialogue_path).is_equal(dialogue["path"])
			assert_str(npc.dialogue_start).is_equal(dialogue["title"])
			assert_object(load(npc.dialogue_path) as DialogueResource).is_not_null()
			assert_bool(npc.is_in_group(&"indoor_npc")).is_true()
			placed_ids[npc_id] = true
		_free_interior(interior)
	assert_int(placed_ids.size()).is_equal(30)


func test_marshal_uses_story_dialogue_and_generated_isometric_model() -> void:
	var interior := _instantiate_interior("res://world/interiors/trial_hall.tscn")
	var marshal := _npc_by_id(_indoor_npcs(interior), "branek-coiljaw")
	assert_object(marshal).is_not_null()
	if marshal == null:
		_free_interior(interior)
		return
	var route: Dictionary = QuestRegistry.dialogue_route_for_actor(
		marshal.npc_id, marshal.dialogue_path, marshal.dialogue_start
	)
	var dialogue: DialogueResource = route.get("resource") as DialogueResource
	var expected_dialogue: DialogueResource = ResourceLoader.load(
		QuestRegistry.MARSHAL_DIALOGUE_PATH
	) as DialogueResource
	assert_bool(dialogue == expected_dialogue).is_true()
	assert_str(str(route["title"])).is_equal("start")
	var sprite := marshal.get_node("Sprite2D") as Sprite2D
	assert_bool(sprite.region_enabled).is_false()
	assert_str(sprite.texture.resource_path).starts_with(
		"res://assets/generated/sprites/units/"
	)
	assert_bool(sprite.offset.is_equal_approx(
		preload("res://globals/unit_art.gd").PIVOT_OFFSET
		* preload("res://globals/unit_art.gd").WORLD_SCALE
	)).is_true()
	_free_interior(interior)


func test_npc_body_collision_matches_the_character_feet_footprint() -> void:
	var npc_scene := load("res://actors/npc/npc.tscn") as PackedScene
	var npc := npc_scene.instantiate() as NPC
	add_child(npc)
	var shape_node := npc.get_node("CollisionShape2D") as CollisionShape2D
	var shape := shape_node.shape as RectangleShape2D
	assert_vector(shape.size).is_equal(Vector2(18, 10))
	assert_vector(shape_node.position).is_equal(Vector2(0, -4))
	npc.queue_free()


func test_all_twelve_generated_vendors_are_reachable_in_interiors() -> void:
	var placed_ids := {}
	for entry: BuildingTransitionDefinition in BuildingTransitionRegistry.ENTRIES:
		var interior := _instantiate_interior(entry.destination_scene)
		var marker := interior.find_child("VendorSpot", true, false) as Marker2D
		for npc: NPC in _indoor_vendors(interior):
			var row := VendorData.vendor(npc.vendor_id)
			assert_bool(row.is_empty()).is_false()
			assert_bool(placed_ids.has(npc.vendor_id)).is_false()
			assert_str(npc.npc_id).is_equal(row["npc_id"])
			assert_str(npc.npc_name).is_equal(row["display_name"])
			assert_float(npc.position.distance_to(marker.position)).is_less_equal(64.0)
			assert_float(npc.interaction_radius).is_greater(0.0)
			placed_ids[npc.vendor_id] = true
		_free_interior(interior)
	assert_int(placed_ids.size()).is_equal(12)
	for row: Dictionary in VendorData.all_vendors():
		assert_bool(placed_ids.has(str(row["id"]))).is_true()


func test_indoor_vendor_opens_existing_shop_and_buy_sell_leave_round_trip() -> void:
	GameState.inventory.clear()
	GameState.vendor_stock.clear()
	GameState.gp = 500
	var interior := _instantiate_interior("res://world/interiors/item_shop.tscn")
	var vendor := _vendor_by_id(_indoor_vendors(interior), VendorIdsData.LOAM_AND_LANTERN)
	var player := interior.find_child("Player", true, false) as Player
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	var gp_before := GameState.gp
	var item_id := ItemIds.CONSUMABLES_LOAM_BREAD
	var item_before := GameState.item_count(item_id)
	var stock_before := GameState.vendor_item_quantity(vendor.vendor_id, item_id)

	vendor._on_body(player, true)
	vendor._unhandled_input(interact)
	assert_bool(UIManager.is_open()).is_true()
	var shop := UIManager._stack.back() as ShopScreen
	assert_object(shop).is_not_null()
	assert_str(shop.vendor_id()).is_equal(vendor.vendor_id)
	var bread_entry: Dictionary = {}
	for entry: Dictionary in shop.catalog_entries():
		if str(entry["id"]) == item_id:
			bread_entry = entry
			break
	assert_bool(bread_entry.is_empty()).is_false()

	shop._buy(bread_entry)
	assert_int(GameState.item_count(item_id)).is_equal(item_before + 1)
	assert_int(GameState.vendor_item_quantity(vendor.vendor_id, item_id)).is_equal(stock_before - 1)
	shop._sell(bread_entry)
	assert_int(GameState.item_count(item_id)).is_equal(item_before)
	assert_int(GameState.vendor_item_quantity(vendor.vendor_id, item_id)).is_equal(stock_before)
	assert_int(GameState.gp).is_equal(
		gp_before - int(bread_entry["buy_price"]) + int(bread_entry["sell_price"])
	)
	UIManager.close_all()
	assert_bool(UIManager.is_open()).is_false()
	_free_interior(interior)


func _instantiate_interior(scene_path: String) -> Node2D:
	var packed := load(scene_path) as PackedScene
	assert_object(packed).is_not_null()
	var interior := packed.instantiate() as Node2D
	add_child(interior)
	return interior


func _free_interior(interior: Node2D) -> void:
	remove_child(interior)
	interior.free()


func _npc_ids_for_scene(placements: Dictionary, scene_path: String) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in placements.keys():
		var npc_id := str(value)
		var placement: Dictionary = placements[npc_id]
		if str(placement.get("scene", "")) == scene_path:
			result.append(npc_id)
	result.sort()
	return result


func _indoor_npcs(interior: Node2D) -> Array[NPC]:
	var result: Array[NPC] = []
	for child: Node in interior.find_children("*", "", true, false):
		if child is NPC and child.is_in_group(&"indoor_npc"):
			result.append(child as NPC)
	return result


func _indoor_vendors(interior: Node2D) -> Array[NPC]:
	var result: Array[NPC] = []
	for child: Node in interior.find_children("*", "", true, false):
		if child is NPC and child.is_in_group(&"indoor_vendor"):
			result.append(child as NPC)
	return result


func _npc_by_id(npcs: Array[NPC], npc_id: String) -> NPC:
	for npc: NPC in npcs:
		if npc.npc_id == npc_id:
			return npc
	return null


func _vendor_by_id(vendors: Array[NPC], vendor_id: String) -> NPC:
	for npc: NPC in vendors:
		if npc.vendor_id == vendor_id:
			return npc
	return null


func _offset(value: Variant) -> Vector2:
	var values: Array = value
	return Vector2(float(values[0]), float(values[1]))
