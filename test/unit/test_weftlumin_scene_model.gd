extends GdUnitTestSuite
## E3.1a (#338): WeftluminSceneModel — pick, multi-select, both snaps, ownership boundaries, the
## node -> command mapping, and live apply == replay through LayoutOverrides.apply_to_scene.
##
## The layout tool's pinned behaviours (test_layout_editor_patterns.gd, and the #338 port notes:
## topmost-on-tie pick, rigid one-step group drag, whole-selection delete/duplicate/nudge) are
## driven here through the model. The fixture is a real saved scene with real instanced
## sub-scenes, because the ownership boundary is only meaningful on `Node.owner` as a loaded
## scene sets it.

const FIXTURE_DIR := "user://weftlumin_scene_model_test"
const FOUNTAIN_PATH := FIXTURE_DIR + "/fountain.tscn"
const FIXTURE_PATH := FIXTURE_DIR + "/fixture.tscn"
const ICON := "res://icon.svg"

var world: Node2D
var model: WeftluminSceneModel
var _extra: Array[Node] = []


func before_test() -> void:
	assert_int(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))).is_equal(OK)
	_save_fixture()
	world = _instantiate_fixture()
	model = WeftluminSceneModel.new()
	model.configure(world)


func after_test() -> void:
	model.dispose()
	model = null
	for node: Node in _extra:
		if is_instance_valid(node):
			node.free()
	_extra.clear()
	if is_instance_valid(world):
		world.free()
	for path: String in [FOUNTAIN_PATH, FIXTURE_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))


# --- fixture ---------------------------------------------------------------------------------


func _sprite(node_name: String, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = load(ICON)
	sprite.position = at
	return sprite


func _crate(node_name: String, at: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = at
	var sprite := _sprite("Sprite2D", Vector2.ZERO)
	body.add_child(sprite)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(64.0, 24.0)
	collision.shape = rectangle
	body.add_child(collision)
	return body


static func _own(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		if child.scene_file_path.is_empty():
			_own(child, owner_node)


func _save_fixture() -> void:
	var fountain := Node2D.new()
	fountain.name = "Fountain"
	fountain.add_child(_sprite("Basin", Vector2.ZERO))
	_own(fountain, fountain)
	var fountain_scene := PackedScene.new()
	assert_int(fountain_scene.pack(fountain)).is_equal(OK)
	fountain.free()
	assert_int(ResourceSaver.save(fountain_scene, FOUNTAIN_PATH)).is_equal(OK)

	var root := Node2D.new()
	root.name = "Fixture"
	var dressing := Node2D.new()
	dressing.name = "Dressing"
	root.add_child(dressing)
	var layers: Dictionary = {}
	for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
		var layer := Node2D.new()
		layer.name = layer_name
		dressing.add_child(layer)
		layers[layer_name] = layer
	(layers["GroundDetails"] as Node).add_child(_sprite("Rock", Vector2(100.0, 100.0)))
	(layers["GroundDetails"] as Node).add_child(_sprite("Bush", Vector2(400.0, 100.0)))
	(layers["SolidProps"] as Node).add_child(_crate("Crate", Vector2(700.0, 100.0)))
	var spawn := Marker2D.new()
	spawn.name = "SpawnDefault"
	spawn.position = Vector2(1000.0, 100.0)
	root.add_child(spawn)
	var loaded: PackedScene = ResourceLoader.load(FOUNTAIN_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	for instance_name: String in ["Fountain", "Well"]:
		var instance: Node2D = loaded.instantiate() as Node2D
		instance.name = instance_name
		instance.position = Vector2(100.0 if instance_name == "Fountain" else 400.0, 500.0)
		(layers["SolidProps"] as Node).add_child(instance)
	_own(root, root)
	# Only the Fountain instance exposes its children (an `editable path=` line in the file).
	root.set_editable_instance(root.get_node("Dressing/SolidProps/Fountain"), true)
	var packed := PackedScene.new()
	assert_int(packed.pack(root)).is_equal(OK)
	root.free()
	assert_int(ResourceSaver.save(packed, FIXTURE_PATH)).is_equal(OK)


func _instantiate_fixture() -> Node2D:
	var packed: PackedScene = ResourceLoader.load(FIXTURE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	var instance := packed.instantiate() as Node2D
	add_child(instance)
	return instance


func _node(path: String) -> Node2D:
	return world.get_node(path) as Node2D


func _owned_sprite(node_name: String, at: Vector2, layer: String = "Dressing/GroundDetails") -> Sprite2D:
	var sprite := _sprite(node_name, at)
	world.get_node(layer).add_child(sprite)
	sprite.owner = world
	return sprite


# --- pick ------------------------------------------------------------------------------------


func test_pick_prefers_the_smallest_hit_and_the_topmost_on_a_tie() -> void:
	var backdrop := _owned_sprite("Backdrop", Vector2(1500.0, 800.0))
	backdrop.scale = Vector2(6.0, 6.0)
	var small := _owned_sprite("Pebble", Vector2(1500.0, 800.0))
	assert_object(model.pick(Vector2(1500.0, 800.0))).override_failure_message(
		"a prop inside a big backdrop must stay reachable"
	).is_same(small)
	var on_top := _owned_sprite("PebbleOnTop", Vector2(1500.0, 800.0))
	assert_object(model.pick(Vector2(1500.0, 800.0))).override_failure_message(
		"on an area tie the LAST candidate — the one drawn on top — wins"
	).is_same(on_top)
	assert_object(model.pick(Vector2(1500.0 + 300.0, 800.0))).is_same(backdrop)
	assert_object(model.pick(Vector2(-5000.0, -5000.0))).is_null()


func test_bounds_follow_the_sprite_and_fall_back_to_a_marker_box() -> void:
	var rock := _node("Dressing/GroundDetails/Rock")
	assert_that(model.bounds(rock)).is_equal(Rect2(Vector2(36.0, 36.0), Vector2(128.0, 128.0)))
	var crate := _node("Dressing/SolidProps/Crate")
	assert_that(model.bounds(crate)).is_equal(Rect2(Vector2(636.0, 36.0), Vector2(128.0, 128.0)))
	var spawn := _node("SpawnDefault")
	assert_that(model.bounds(spawn)).is_equal(Rect2(Vector2(988.0, 88.0), Vector2(24.0, 24.0)))
	# The marker is editable through the layout predicate and pickable with padding.
	assert_object(model.pick(Vector2(1018.0, 100.0))).is_same(spawn)


# --- selection --------------------------------------------------------------------------------


func test_multi_select_toggles_membership_and_the_primary_follows_the_last_addition() -> void:
	var rock := _node("Dressing/GroundDetails/Rock")
	var bush := _node("Dressing/GroundDetails/Bush")
	assert_object(model.pick_select(rock.global_position)).is_same(rock)
	assert_int(model.selection().size()).is_equal(1)
	model.pick_select(bush.global_position, true)
	assert_array(model.selection()).contains_exactly([rock, bush])
	assert_object(model.primary()).is_same(bush)
	# Additive pick on a member takes it out; the primary falls back.
	model.pick_select(bush.global_position, true)
	assert_array(model.selection()).contains_exactly([rock])
	assert_object(model.primary()).is_same(rock)
	# A plain click on a group member keeps the group and makes it primary.
	model.pick_select(bush.global_position, true)
	model.pick_select(rock.global_position)
	assert_int(model.selection().size()).is_equal(2)
	assert_object(model.primary()).is_same(rock)
	# A plain click elsewhere collapses the group; empty space clears it.
	model.pick_select(_node("SpawnDefault").global_position)
	assert_int(model.selection().size()).is_equal(1)
	model.pick_select(Vector2(-5000.0, -5000.0))
	assert_bool(model.selection().is_empty()).is_true()
	assert_object(model.primary()).is_null()


# --- snaps and gestures -----------------------------------------------------------------------


func test_grid_snapped_group_drag_is_rigid_and_one_undo_step() -> void:
	var rock := _node("Dressing/GroundDetails/Rock")
	var bush := _node("Dressing/GroundDetails/Bush")
	var spacing: Vector2 = bush.global_position - rock.global_position
	model.select_only(rock)
	model.toggle(bush)
	model.pick_select(bush.global_position)
	assert_bool(model.begin_drag(bush.global_position)).is_true()
	model.drag_to(bush.global_position + Vector2(83.0, 37.0))
	assert_bool(bool(model.end_drag()["allowed"])).is_true()

	assert_vector(bush.global_position).override_failure_message(
		"the primary snaps to the 8 px grid"
	).is_equal(Vector2(480.0, 136.0))
	assert_vector(bush.global_position - rock.global_position).override_failure_message(
		"the group keeps its spacing: members follow the primary's delta, not their own snap"
	).is_equal(spacing)
	var entries: Array[Dictionary] = model.bus.log_entries()
	assert_int(entries.size()).is_equal(2)
	for entry: Dictionary in entries:
		assert_str(str(entry["op"])).is_equal(WeftluminSceneModel.OP_SET)
		assert_str(str(entry["params"]["key"])).is_equal("position")

	model.undo()
	assert_vector(rock.global_position).is_equal(Vector2(100.0, 100.0))
	assert_vector(bush.global_position).is_equal(Vector2(400.0, 100.0))
	assert_bool(model.bus.has_undo()).override_failure_message(
		"one drag is one undo step"
	).is_false()
	model.redo()
	assert_vector(rock.global_position).is_equal(Vector2(180.0, 136.0))
	assert_vector(bush.global_position).is_equal(Vector2(480.0, 136.0))


func test_free_drag_skips_the_snap() -> void:
	var rock := _node("Dressing/GroundDetails/Rock")
	model.select_only(rock)
	model.begin_drag(rock.global_position)
	model.drag_to(rock.global_position + Vector2(3.0, 5.0), true)
	model.end_drag()
	assert_vector(rock.global_position).is_equal(Vector2(103.0, 105.0))


func test_cell_snap_lands_the_primary_on_an_iso_cell_centre() -> void:
	var grid := IsoGrid.new()
	grid.build(_iso_ground())
	model.grid = grid
	model.snap_mode = WeftluminSceneModel.Snap.CELL
	var probe := Vector2(170.0, 133.0)
	var centre: Vector2 = grid.cell_to_world(grid.world_to_cell(probe))
	assert_vector(model.snap(probe)).is_equal(centre)
	assert_vector(model.snap(probe)).is_not_equal(model.snap(probe, WeftluminSceneModel.Snap.GRID))

	var rock := _node("Dressing/GroundDetails/Rock")
	var bush := _node("Dressing/GroundDetails/Bush")
	var spacing: Vector2 = bush.global_position - rock.global_position
	model.select_only(bush)
	model.toggle(rock)
	model.begin_drag(rock.global_position)
	model.drag_to(probe)
	model.end_drag()
	assert_vector(rock.global_position).is_equal(centre)
	assert_vector(grid.cell_to_world(grid.world_to_cell(rock.global_position))).is_equal(rock.global_position)
	assert_vector(bush.global_position - rock.global_position).is_equal(spacing)


func test_cell_snap_without_a_grid_falls_back_to_the_8px_grid() -> void:
	model.snap_mode = WeftluminSceneModel.Snap.CELL
	assert_vector(model.snap(Vector2(13.0, 21.0))).is_equal(Vector2(16.0, 24.0))
	assert_vector(model.snap(Vector2(13.0, 21.0), WeftluminSceneModel.Snap.OFF)).is_equal(Vector2(13.0, 21.0))


func test_delete_nudge_and_duplicate_act_on_the_whole_selection_in_one_step() -> void:
	var rock := _node("Dressing/GroundDetails/Rock")
	var crate := _node("Dressing/SolidProps/Crate")
	model.select_only(rock)
	model.toggle(crate)

	model.nudge(Vector2(1.0, 0.0))
	assert_vector(rock.position).is_equal(Vector2(101.0, 100.0))
	assert_vector(crate.position).is_equal(Vector2(701.0, 100.0))
	model.undo()
	assert_vector(rock.position).is_equal(Vector2(100.0, 100.0))
	assert_vector(crate.position).is_equal(Vector2(700.0, 100.0))
	assert_bool(model.bus.has_undo()).is_false()

	var duplicated: Dictionary = model.duplicate_selection()
	assert_bool(bool(duplicated["allowed"])).is_true()
	var rock_copy := world.get_node_or_null("Dressing/GroundDetails/RockCopy") as Node2D
	var crate_copy := world.get_node_or_null("Dressing/SolidProps/CrateCopy") as Node2D
	assert_object(rock_copy).is_not_null()
	assert_object(crate_copy).is_not_null()
	assert_vector(rock_copy.position).is_equal(Vector2(108.0, 108.0))
	assert_bool(rock_copy.has_meta(WeftluminSceneModel.ADDITION_META)).is_true()
	assert_array(model.selection()).override_failure_message(
		"the copies replace the selection, so the next gesture moves them"
	).contains_exactly([rock_copy, crate_copy])
	assert_object(model.primary()).is_same(crate_copy)
	assert_int((model.document["additions"] as Array).size()).is_equal(2)

	model.delete_selection()
	assert_object(world.get_node_or_null("Dressing/GroundDetails/RockCopy")).is_null()
	assert_object(world.get_node_or_null("Dressing/SolidProps/CrateCopy")).is_null()
	assert_int((model.document["additions"] as Array).size()).is_equal(0)
	model.undo()
	assert_object(world.get_node_or_null("Dressing/GroundDetails/RockCopy")).is_same(rock_copy)
	assert_object(world.get_node_or_null("Dressing/SolidProps/CrateCopy")).is_same(crate_copy)
	assert_int((model.document["additions"] as Array).size()).is_equal(2)
	# Undo the duplicate: one step removes both copies.
	model.undo()
	assert_object(world.get_node_or_null("Dressing/GroundDetails/RockCopy")).is_null()
	assert_object(world.get_node_or_null("Dressing/SolidProps/CrateCopy")).is_null()
	assert_bool(model.bus.has_undo()).is_false()

	model.select_only(rock)
	model.toggle(crate)
	model.delete_selection()
	assert_object(world.get_node_or_null("Dressing/GroundDetails/Rock")).is_null()
	assert_object(world.get_node_or_null("Dressing/SolidProps/Crate")).is_null()
	assert_array(model.document["deletions"] as Array).contains_exactly([
		"Dressing/GroundDetails/Rock", "Dressing/SolidProps/Crate",
	])
	model.undo()
	assert_object(world.get_node_or_null("Dressing/GroundDetails/Rock")).is_same(rock)
	assert_object(world.get_node_or_null("Dressing/SolidProps/Crate")).is_same(crate)
	assert_int(rock.get_index()).is_equal(0)
	assert_bool((model.document["deletions"] as Array).is_empty()).is_true()
	# The undone copies are detached, not freed; dispose() is what releases them.
	model.dispose()
	assert_bool(is_instance_valid(rock_copy)).is_false()
	assert_bool(is_instance_valid(crate_copy)).is_false()


# --- ownership --------------------------------------------------------------------------------


func test_scene_ownership_boundaries_refuse_with_attributed_reasons() -> void:
	# Widen through the adapter hook: every Node2D under Dressing, which reaches instance children.
	var dressing := _node("Dressing")
	model.editable_roots_provider = func(_root: Node) -> Array[Node]: return [dressing]
	var fountain := _node("Dressing/SolidProps/Fountain")
	var basin := _node("Dressing/SolidProps/Fountain/Basin")
	var well_basin := _node("Dressing/SolidProps/Well/Basin")
	var stray := Sprite2D.new()
	stray.name = "Stray"
	stray.texture = load(ICON)
	world.get_node("Dressing/GroundDetails").add_child(stray)

	assert_int(int(model.boundary(fountain)["kind"])).is_equal(WeftluminSceneModel.Boundary.SCENE)
	var basin_info: Dictionary = model.boundary(basin)
	assert_int(int(basin_info["kind"])).is_equal(WeftluminSceneModel.Boundary.INSTANCE)
	assert_object(basin_info["instance_root"]).is_same(fountain)
	assert_bool(bool(basin_info["editable_instance"])).override_failure_message(
		"the scene file's `editable path=` line marks Fountain editable at runtime"
	).is_true()
	assert_bool(bool(model.boundary(well_basin)["editable_instance"])).is_false()
	assert_int(int(model.boundary(stray)["kind"])).is_equal(WeftluminSceneModel.Boundary.RUNTIME)

	# Scene-owned: every op, including removing a whole instance.
	for op: String in [WeftluminSceneModel.OP_SET, WeftluminSceneModel.OP_REMOVE, WeftluminSceneModel.OP_ADD]:
		assert_bool(bool(model.check(op, fountain)["allowed"])).override_failure_message(op).is_true()
	# Editable instance: property overrides and adds below it; never a remove.
	assert_bool(bool(model.check(WeftluminSceneModel.OP_SET, basin)["allowed"])).is_true()
	assert_bool(bool(model.check(WeftluminSceneModel.OP_ADD, basin)["allowed"])).is_true()
	var remove_basin: Dictionary = model.check(WeftluminSceneModel.OP_REMOVE, basin)
	assert_bool(bool(remove_basin["allowed"])).is_false()
	assert_str(String(remove_basin["blocked_by"])).is_equal("instance_boundary")
	assert_str(str(remove_basin["message"])).contains("Fountain")
	# Non-editable instance: nothing, and the refusal names the unblock.
	for op: String in [WeftluminSceneModel.OP_SET, WeftluminSceneModel.OP_ADD]:
		var refusal: Dictionary = model.check(op, well_basin)
		assert_bool(bool(refusal["allowed"])).is_false()
		assert_str(String(refusal["nearest_unblock"])).is_equal("editable_children")
	# Runtime-spawned: no scene file carries it.
	var runtime_refusal: Dictionary = model.check(WeftluminSceneModel.OP_SET, stray)
	assert_str(String(runtime_refusal["blocked_by"])).is_equal("scene_ownership")
	assert_bool(bool(model.check(WeftluminSceneModel.OP_REMOVE, world)["allowed"])).is_false()

	# Pick and selection respect the boundary.
	assert_bool(model.is_editable(basin)).is_true()
	assert_bool(model.is_editable(well_basin)).is_false()
	assert_bool(model.is_editable(stray)).is_false()
	assert_bool(model.select_only(well_basin)).is_false()
	assert_object(model.pick(stray.global_position)).is_not_same(stray)

	# A gesture that would remove an instance child is refused whole and leaves no history.
	model.select_only(_node("Dressing/GroundDetails/Rock"))
	model.toggle(basin)
	var deleted: Dictionary = model.delete_selection()
	assert_bool(bool(deleted["allowed"])).is_false()
	assert_object(world.get_node_or_null("Dressing/GroundDetails/Rock")).is_not_null()
	assert_object(basin.get_parent()).is_same(fountain)
	assert_bool(model.bus.has_undo()).is_false()
	assert_bool(model.bus.log_entries().is_empty()).is_true()

	# A property override inside the editable instance is allowed and lands live.
	model.select_only(basin)
	assert_bool(bool(model.nudge(Vector2(0.0, 4.0))["allowed"])).is_true()
	assert_vector(basin.position).is_equal(Vector2(0.0, 4.0))
	# A key outside the replay schema is refused rather than silently dropped by replay.
	var outside: Dictionary = model.set_selection_property("modulate", [1, 0, 0, 1])
	assert_str(String(outside["blocked_by"])).is_equal("property_schema")
	stray.free()


# --- node -> command mapping and replay -------------------------------------------------------


func test_commands_target_nodes_by_scene_path_with_bus_captured_pre_state() -> void:
	var rock := _node("Dressing/GroundDetails/Rock")
	var command: WeftluminCommand = model.command_for(
		rock, WeftluminSceneModel.OP_SET, {"key": "position", "value": [1, 2]}
	)
	assert_str(command.kind).is_equal("scene")
	assert_dict(command.target).is_equal({"scene": FIXTURE_PATH, "node": "Dressing/GroundDetails/Rock"})
	model.select_only(rock)
	model.nudge(Vector2(0.0, -2.0))
	var entry: Dictionary = model.bus.log_entries()[0]
	assert_str(str(entry["target"]["node"])).is_equal("Dressing/GroundDetails/Rock")
	assert_array(entry["params"]["value"] as Array).is_equal([100.0, 98.0])
	assert_array(entry["pre_state"]["value"] as Array).is_equal([100.0, 100.0])


func test_live_apply_equals_replay_of_the_document_through_apply_to_scene() -> void:
	var rock := _node("Dressing/GroundDetails/Rock")
	var bush := _node("Dressing/GroundDetails/Bush")
	var crate := _node("Dressing/SolidProps/Crate")
	var dressing := _node("Dressing")
	model.editable_roots_provider = func(_root: Node) -> Array[Node]: return [dressing]

	model.select_only(rock)
	model.toggle(bush)
	model.begin_drag(bush.global_position)
	model.drag_to(bush.global_position + Vector2(29.0, -11.0))
	model.end_drag()
	model.nudge(Vector2(1.0, 0.0))
	model.select_only(crate)
	model.set_selection_property("scale", [1.5, 1.5])
	model.set_selection_property("collision", [80.0, 30.0])
	model.set_selection_property("flip_h", true)
	model.select_only(bush)
	model.delete_selection()
	model.select_only(rock)
	model.toggle(crate)
	model.duplicate_selection()
	model.nudge(Vector2(0.0, 8.0))
	model.select_only(_node("Dressing/SolidProps/Fountain/Basin"))
	model.set_selection_property("position", [5.0, 6.0])
	model.undo()
	model.redo()
	model.select_only(_node("SpawnDefault"))
	model.nudge(Vector2(-3.0, 0.0))
	model.undo()

	# The document survives its own text format before replay.
	var document: Dictionary = LayoutOverrides.from_json(LayoutOverrides.to_json(model.document))
	var fresh := _instantiate_fixture()
	_extra.append(fresh)
	var summary: Dictionary = LayoutOverrides.apply_to_scene(fresh, document)
	assert_int(int(summary["skipped_paths"])).is_equal(0)
	assert_int(int(summary["additions_applied"])).is_equal(2)
	assert_str(JSON.stringify(_snapshot(fresh), "  ")).is_equal(JSON.stringify(_snapshot(world), "  "))
	model.dispose()
	assert_bool(is_instance_valid(bush)).override_failure_message(
		"dispose() frees the detached deletion"
	).is_false()


func _snapshot(root: Node) -> Dictionary:
	var output: Dictionary = {}
	_snapshot_into(root, root, output)
	return output


func _snapshot_into(root: Node, node: Node, output: Dictionary) -> void:
	for child: Node in node.get_children():
		var entry := {"class": child.get_class(), "index": child.get_index()}
		if child is Node2D:
			entry["properties"] = LayoutOverrides.capture_properties(child as Node2D)
			entry["z_index"] = (child as Node2D).z_index
			entry["y_sort"] = (child as Node2D).y_sort_enabled
			entry["addition"] = child.has_meta(WeftluminSceneModel.ADDITION_META)
		output[String(root.get_path_to(child))] = entry
		_snapshot_into(root, child, output)


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
	world.add_child(ground)
	return ground
