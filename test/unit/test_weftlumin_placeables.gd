extends GdUnitTestSuite
## E3.1b (#339): the scene model places registry entries and sets exported script properties as
## `scene` commands — every export of every Soul Meter placeable round-trips through
## `set_property` (live, undo/redo, and replay of the log onto a fresh scene).

const HOST_ADAPTER := preload("res://addons/weftlumin/shell/soul_meter_adapter.gd")
const ICON := "res://icon.svg"

var world: Node2D
var model: WeftluminSceneModel
var _extra: Array[Node] = []
var _previous_scene: Node


func before_test() -> void:
	_previous_scene = get_tree().current_scene
	world = _world("PlaceableFixture")
	model = WeftluminSceneModel.new()
	model.configure(world)
	model.snap_mode = WeftluminSceneModel.Snap.OFF


func after_test() -> void:
	model.dispose()
	model = null
	for node: Node in _extra:
		if is_instance_valid(node):
			node.free()
	_extra.clear()
	if is_instance_valid(world):
		world.free()
	get_tree().current_scene = _previous_scene if is_instance_valid(_previous_scene) else null


func _world(node_name: String) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	get_tree().root.add_child(root)
	return root


func _registry() -> Array[WeftluminPlaceable]:
	return HOST_ADAPTER.new().placeables()


func _place(entry: WeftluminPlaceable, at: Vector2 = Vector2(64, 32)) -> Node2D:
	model.choose_placeable(entry)
	var outcome: Dictionary = model.place_placeable(at)
	assert_bool(bool(outcome["allowed"])).override_failure_message(str(outcome)).is_true()
	return model.primary()


## A value of the declared type that differs from `current`. Fails on a type no placeable
## export may carry yet, so a new export type cannot slip past this suite unedited.
func _distinct(info: Dictionary, current: Variant) -> Variant:
	var type: int = int(info["type"])
	match type:
		TYPE_BOOL: return not bool(current)
		TYPE_INT: return int(current) + 1
		TYPE_FLOAT: return float(current) + 1.5
		TYPE_STRING: return str(current) + "_edited"
		TYPE_STRING_NAME: return StringName(str(current) + "_edited")
		TYPE_VECTOR2: return (current as Vector2) + Vector2(3, 5)
		TYPE_RECT2: return Rect2((current as Rect2).position + Vector2(1, 2), (current as Rect2).size + Vector2(3, 4))
		TYPE_COLOR: return Color(0.25, 0.5, 0.75, 1.0) if current != Color(0.25, 0.5, 0.75, 1.0) else Color.RED
		TYPE_PACKED_STRING_ARRAY:
			var items: PackedStringArray = (current as PackedStringArray).duplicate()
			items.append("dom_edited_flag")
			return items
		TYPE_ARRAY:
			var typed: Array = (current as Array).duplicate()
			typed.clear()
			typed.assign([{"item_id": "consumables/hearthloaf", "count": 2}])
			return typed
		TYPE_DICTIONARY: return {"edited": 1}
	fail("Export %s has untested type %s." % [info["name"], type_string(type)])
	return current


func test_the_registry_is_the_existing_actor_types_and_every_entry_places() -> void:
	var ids: Array[StringName] = []
	for entry: WeftluminPlaceable in _registry():
		ids.append(entry.id)
		assert_str(entry.group).is_not_empty()
		var placed: Node2D = _place(entry)
		assert_bool(placed.has_meta(WeftluminSceneModel.PLACED_META)).is_true()
		assert_bool(model.is_editable(placed)).is_true()
		if entry.scene != null:
			assert_str(placed.scene_file_path).is_equal(entry.scene_path())
	assert_array(ids).contains_exactly([
		&"npc", &"hostile", &"building_door", &"travel_exit", &"interactable", &"chest",
		&"pickup", &"switch", &"spawn_marker", &"accord_zone",
	])
	# Placements are command-log content only; the dressing scratch document is untouched.
	assert_array(model.document["additions"] as Array).is_empty()
	assert_array(model.document["edits"] as Array).is_empty()


func test_every_export_on_every_placeable_round_trips_through_set_property() -> void:
	var expected: Dictionary = {}
	var count := 0
	for entry: WeftluminPlaceable in _registry():
		var placed: Node2D = _place(entry, Vector2(64 * count, 32))
		var values: Dictionary = {}
		for info: Dictionary in WeftluminSceneModel.exported_properties(placed):
			var key: String = info["name"]
			var before: Variant = placed.get(key)
			var value: Variant = _distinct(info, before)
			var outcome: Dictionary = model.set_primary_export(key, value)
			assert_bool(bool(outcome["allowed"])).override_failure_message("%s.%s: %s" % [entry.id, key, outcome]).is_true()
			assert_str(var_to_str(placed.get(key))).override_failure_message("%s.%s" % [entry.id, key]).is_equal(var_to_str(value))
			var logged: Dictionary = model.bus.log_entries().back()
			assert_str(str(logged["params"]["export"])).is_equal(key)
			assert_str(str(logged["pre_state"]["value_text"])).is_equal(var_to_str(before))
			# Undo restores, redo reapplies, both through the same command.
			model.undo()
			assert_str(var_to_str(placed.get(key))).is_equal(var_to_str(before))
			model.redo()
			assert_str(var_to_str(placed.get(key))).is_equal(var_to_str(value))
			values[key] = var_to_str(value)
		expected[String(placed.name)] = values
		count += 1
	assert_int(count).is_equal(_registry().size())

	# The log alone rebuilds the placements and every edit on a fresh scene.
	var fresh := _world("PlaceableReplay")
	_extra.append(fresh)
	var replay := WeftluminSceneModel.new()
	replay.configure(fresh)
	var result: Dictionary = replay.bus.replay(model.bus.log_entries())
	assert_bool(bool(result["allowed"])).override_failure_message(str(result)).is_true()
	for node_name: String in expected:
		var copy: Node = fresh.get_node_or_null(node_name)
		assert_object(copy).override_failure_message(node_name).is_not_null()
		for key: String in expected[node_name]:
			assert_str(var_to_str(copy.get(key))).override_failure_message("%s.%s" % [node_name, key]).is_equal(expected[node_name][key])
	replay.dispose()


func test_export_edits_refuse_unknown_untyped_and_wrong_typed_values() -> void:
	var chest: Node2D = _place(_registry().filter(func(e: WeftluminPlaceable) -> bool: return e.id == &"chest")[0])
	var missing: Dictionary = model.set_primary_export("no_such_export", 1)
	assert_str(String(missing["blocked_by"])).is_equal("property_schema")
	var wrong: Dictionary = model.set_primary_export("repeatable", "yes")
	assert_str(String(wrong["blocked_by"])).is_equal("property_type")
	var untyped: Dictionary = model.set_primary_export("loot", [{"item_id": "x"}])
	assert_str(String(untyped["blocked_by"])).is_equal("property_type")
	assert_bool(bool(model.set_primary_export("marker_color", Color.BLUE)["allowed"])).is_true()
	assert_bool(bool(chest.get("marker_color") == Color.BLUE)).is_true()
	# An int widens to a float export.
	assert_bool(bool(model.set_primary_export("lock_modifier", 2)["allowed"])).is_true()
	assert_float(float(chest.get("lock_modifier"))).is_equal(2.0)


func test_placement_snaps_to_the_hosts_open_cell_and_alt_or_snap_off_keeps_the_cursor() -> void:
	get_tree().current_scene = world
	world.add_child(_iso_ground())
	model.snap_mode = WeftluminSceneModel.Snap.GRID
	model.placement_snap = func(at: Vector2) -> Variant: return GridPlacement.open_cell_center_near(world, at)
	var npc: WeftluminPlaceable = _registry()[0]
	var cursor := Vector2(70, 40)
	var expected: Variant = GridPlacement.open_cell_center_near(world, cursor)
	assert_bool(expected is Vector2).is_true()
	var first: Node2D = _place(npc, cursor)
	assert_vector(first.global_position).is_equal(expected as Vector2)
	# The first NPC now occupies that cell, so the next one lands on a different open cell.
	var second: Node2D = _place(npc, cursor)
	assert_bool(second.global_position.is_equal_approx(first.global_position)).is_false()
	# Alt keeps the cursor. (An NPC re-snaps itself on _ready — Wave Q — so use a marker.)
	var marker: WeftluminPlaceable = _registry().back()
	model.choose_placeable(marker)
	assert_bool(bool(model.place_placeable(cursor + Vector2(0.5, 0.25), true)["allowed"])).is_true()
	assert_vector(model.primary().global_position).is_equal(cursor + Vector2(0.5, 0.25))
	model.snap_mode = WeftluminSceneModel.Snap.OFF
	assert_bool(bool(model.place_placeable(cursor + Vector2(1.5, 0.25))["allowed"])).is_true()
	assert_vector(model.primary().global_position).is_equal(cursor + Vector2(1.5, 0.25))


func test_placement_is_one_undo_step_and_a_placed_actor_deletes_and_restores() -> void:
	var door: WeftluminPlaceable = _registry()[2]
	var placed: Node2D = _place(door)
	assert_object(placed.get_parent()).is_same(world)
	model.undo()
	assert_object(placed.get_parent()).is_null()
	model.redo()
	assert_object(placed.get_parent()).is_same(world)
	model.select_only(placed)
	assert_bool(bool(model.delete_selection()["allowed"])).is_true()
	assert_object(placed.get_parent()).is_null()
	model.undo()
	assert_object(placed.get_parent()).is_same(world)
	assert_array(model.document["deletions"] as Array).is_empty()
	# The model refuses a duplicate name and an engine class that is not a Node2D.
	var clash: Dictionary = model.add_instance(world, {"placeable": "x", "scene": "", "type": "Marker2D", "name": String(placed.name), "position": [0, 0], "exports": {}})
	assert_str(String(clash["blocked_by"])).is_equal("name")
	var bad: Dictionary = model.add_instance(world, {"placeable": "x", "scene": "", "type": "Timer", "name": "T", "position": [0, 0], "exports": {}})
	assert_str(String(bad["blocked_by"])).is_equal("placeable")


func _iso_ground() -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = Vector2i(64, 32)
	var source := TileSetAtlasSource.new()
	source.texture = load(ICON)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := TileMapLayer.new()
	ground.name = "IsometricGround"
	ground.tile_set = tile_set
	for x: int in range(-4, 16):
		for y: int in range(-4, 16):
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	return ground
