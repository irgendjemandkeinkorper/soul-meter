extends GdUnitTestSuite
## E3.1c (#370): the pattern library re-hosted on WeftluminSceneModel. Capture and stamp are one
## undoable command each; rename/delete/promote are library commands too; a repo pattern is
## read-only. The schema-1 format itself is `test_layout_patterns.gd`'s contract and untouched.

const Patterns := preload("res://globals/layout_patterns.gd")
const LIBRARY_ROOT := "user://weftlumin_pattern_library_test"
const TEXTURE := "res://assets/generated/sprites/world/objects/dom-chest-wood--closed.png"
const OTHER_TEXTURE := "res://assets/generated/sprites/world/objects/dom-door-wood--closed.png"

var world: Node2D
var model: WeftluminSceneModel


func before_test() -> void:
	world = _world(Vector2(40, 24), Vector2(-56, 120), 1.0)
	model = _model_for(world)


func after_test() -> void:
	model.dispose()
	model = null
	if is_instance_valid(world):
		world.free()
	_remove_tree(ProjectSettings.globalize_path(LIBRARY_ROOT))


# --- fixture ---------------------------------------------------------------------------------


func _world(ground_offset: Vector2, solid_offset: Vector2, solid_scale: float) -> Node2D:
	var root := Node2D.new()
	root.name = "PatternWorld"
	add_child(root)
	for entry: Array in [["GroundDetails", ground_offset, 1.0], ["SoftDetails", Vector2.ZERO, 1.0], ["SolidProps", solid_offset, solid_scale]]:
		var layer := Node2D.new()
		layer.name = entry[0]
		layer.position = entry[1]
		layer.scale = Vector2.ONE * float(entry[2])
		root.add_child(layer)
		layer.owner = root
	return root


func _model_for(root: Node2D) -> WeftluminSceneModel:
	var scene_model := WeftluminSceneModel.new()
	scene_model.library.user_directory = LIBRARY_ROOT.path_join("user")
	scene_model.library.repo_directory = LIBRARY_ROOT.path_join("repo")
	scene_model.configure(root)
	return scene_model


func _sprite(root: Node2D, node_name: String, texture_path: String, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = load(texture_path) as Texture2D
	root.get_node("GroundDetails").add_child(sprite)
	sprite.owner = root
	sprite.global_position = at
	return sprite


func _crate(root: Node2D, node_name: String, at: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	var sprite := Sprite2D.new()
	sprite.texture = load(OTHER_TEXTURE) as Texture2D
	body.add_child(sprite)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(64, 24)
	collision.shape = rectangle
	body.add_child(collision)
	root.get_node("SolidProps").add_child(body)
	for node: Node in [body, sprite, collision]:
		node.owner = root
	body.global_position = at
	return body


func _select(nodes: Array[Node2D]) -> void:
	model.set_selection(nodes)


func _entry(id: String, source: String = WeftluminPatternLibrary.SOURCE_USER) -> Dictionary:
	for entry: Dictionary in model.library.entries():
		if str((entry["pattern"] as Dictionary)["id"]) == id and str(entry["source"]) == source:
			return entry
	return {}


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


static func _remove_tree(absolute: String) -> void:
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for directory: String in DirAccess.get_directories_at(absolute):
		_remove_tree(absolute.path_join(directory))
	for file: String in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(file))
	DirAccess.remove_absolute(absolute)


# --- capture ---------------------------------------------------------------------------------


func test_capture_is_one_undoable_command_and_resave_over_its_name_undoes_to_the_old_file() -> void:
	var first: Sprite2D = _sprite(world, "First", TEXTURE, Vector2(100, 100))
	var second: Sprite2D = _sprite(world, "Second", TEXTURE, Vector2(160, 132))
	_select([first, second] as Array[Node2D])
	var saved: Dictionary = model.save_pattern("Market Stall")
	assert_bool(saved["allowed"]).is_true()
	assert_int((saved["commands"] as PackedStringArray).size()).is_equal(1)
	var path: String = model.library.path_for(&"market-stall")
	var original: String = _read(path)
	assert_str(original).is_not_empty()
	# The file is exactly what LayoutPatterns would write: the format is the contract.
	assert_str(original).is_equal(Patterns.to_json(Patterns.capture([first, second], "Market Stall")["pattern"]))
	var logged: Dictionary = model.bus.log_entries()[-1]
	assert_str(str(logged["kind"])).is_equal(WeftluminPatternLibrary.KIND)
	assert_str(str(logged["op"])).is_equal(WeftluminPatternLibrary.OP_SAVE)

	second.global_position = Vector2(220, 132)
	_select([first, second] as Array[Node2D])
	assert_bool(model.save_pattern("Market Stall")["allowed"]).is_true()
	var revised: String = _read(path)
	assert_str(revised).is_not_equal(original)

	assert_bool(model.undo()["allowed"]).is_true()
	assert_str(_read(path)).is_equal(original)
	assert_bool(model.undo()["allowed"]).is_true()
	assert_bool(FileAccess.file_exists(path)).is_false()
	assert_bool(model.redo()["allowed"]).is_true()
	assert_str(_read(path)).is_equal(original)
	assert_bool(model.redo()["allowed"]).is_true()
	assert_str(_read(path)).is_equal(revised)


func test_capture_refusals_write_nothing_and_add_no_history() -> void:
	model.clear_selection()
	assert_str(str(model.save_pattern("Empty")["message"])).contains("Select something first")
	_select([_sprite(world, "Lone", TEXTURE, Vector2(10, 10))] as Array[Node2D])
	assert_bool(model.save_pattern("   ")["allowed"]).is_false()
	assert_bool(model.bus.has_undo()).is_false()
	assert_array(model.library.entries()).is_empty()


func test_patterns_changed_fires_for_library_writes_and_their_undo() -> void:
	var fired: Array[int] = [0]
	model.patterns_changed.connect(func() -> void: fired[0] += 1)
	_select([_sprite(world, "Lone", TEXTURE, Vector2(10, 10))] as Array[Node2D])
	model.save_pattern("Lone")
	model.undo()
	model.redo()
	assert_int(fired[0]).is_equal(3)


# --- stamp -----------------------------------------------------------------------------------


func test_stamp_of_a_repeated_texture_pattern_places_every_prop_in_one_step() -> void:
	var picks: Array[Node2D] = []
	for index: int in 3:
		picks.append(_sprite(world, "Chest%d" % index, TEXTURE, Vector2(200 + index * 48, 300)))
	# A tree-resident prop with the name the resolver derives first, so a resolver that only
	# inspected the tree would hand the next free name to every stamped prop.
	_sprite(world, "DomChestWoodClosed", TEXTURE, Vector2(-400, -400))
	_select(picks)
	assert_bool(model.save_pattern("Chest Row")["allowed"]).is_true()
	var ground: Node = world.get_node("GroundDetails")
	var before: int = ground.get_child_count()
	model.choose_pattern(_entry("chest-row")["pattern"])
	var stamped: Dictionary = model.stamp_pattern(Vector2(600, 600), true)
	assert_bool(stamped["allowed"]).is_true()
	assert_int(ground.get_child_count()).is_equal(before + 3)
	var placed: Array[Node2D] = model.selection()
	assert_int(placed.size()).is_equal(3)
	var names: Dictionary = {}
	for node: Node2D in placed:
		names[String(node.name)] = true
	assert_int(names.size()).is_equal(3)
	assert_bool(model.undo()["allowed"]).is_true()
	assert_int(ground.get_child_count()).is_equal(before)
	assert_bool(model.redo()["allowed"]).is_true()
	assert_int(ground.get_child_count()).is_equal(before + 3)


func test_stamp_spanning_two_differently_transformed_layers_reproduces_the_arrangement() -> void:
	var rug: Sprite2D = _sprite(world, "Rug", TEXTURE, Vector2(320, 240))
	var crate: StaticBody2D = _crate(world, "Crate", Vector2(388, 212))
	var spacing: Vector2 = crate.global_position - rug.global_position
	_select([rug, crate] as Array[Node2D])
	assert_bool(model.save_pattern("Stall")["allowed"]).is_true()
	var pattern: Dictionary = _entry("stall")["pattern"]

	# A second scene whose layers sit somewhere else entirely, with SolidProps scaled.
	var other: Node2D = _world(Vector2(-200, 72), Vector2(400, -96), 2.0)
	var stamping: WeftluminSceneModel = _model_for(other)
	stamping.choose_pattern(pattern)
	var at := Vector2(1000, 800)
	var stamped: Dictionary = stamping.stamp_pattern(at, true)
	assert_bool(stamped["allowed"]).is_true()
	var placed: Array[Node2D] = stamping.selection()
	assert_int(placed.size()).is_equal(2)
	var stamped_rug: Node2D = null
	var stamped_crate: Node2D = null
	for node: Node2D in placed:
		if node.get_parent().name == &"GroundDetails":
			stamped_rug = node
		else:
			stamped_crate = node
	assert_object(stamped_rug).is_not_null()
	assert_object(stamped_crate).is_not_null()
	if stamped_rug == null or stamped_crate == null:
		stamping.dispose()
		other.free()
		return
	assert_str(String(stamped_crate.get_parent().name)).is_equal("SolidProps")
	# The anchor is the selection's min corner, so the arrangement lands at the cursor.
	var anchor := Vector2(minf(rug.global_position.x, crate.global_position.x), minf(rug.global_position.y, crate.global_position.y))
	assert_vector(stamped_rug.global_position).is_equal_approx(at + rug.global_position - anchor, Vector2(0.01, 0.01))
	assert_vector(stamped_crate.global_position - stamped_rug.global_position).is_equal_approx(spacing, Vector2(0.01, 0.01))
	stamping.dispose()
	other.free()


# --- browser operations ------------------------------------------------------------------------


func test_rename_moves_the_file_keeps_the_schema_and_undoes() -> void:
	_select([_sprite(world, "Lone", TEXTURE, Vector2(10, 10))] as Array[Node2D])
	model.save_pattern("Old Name")
	var old_path: String = model.library.path_for(&"old-name")
	var before: Dictionary = Patterns.load_file(old_path)
	var _read_text_before: String = _read(old_path)
	var renamed: Dictionary = model.rename_pattern(_entry("old-name"), "Campfire Ring")
	assert_bool(renamed["allowed"]).is_true()
	assert_bool(FileAccess.file_exists(old_path)).is_false()
	var after: Dictionary = Patterns.load_file(model.library.path_for(&"campfire-ring"))
	assert_str(str(after["name"])).is_equal("Campfire Ring")
	assert_str(str(after["id"])).is_equal("campfire-ring")
	assert_array(after.keys()).contains_exactly_in_any_order(before.keys())
	assert_that(after["nodes"]).is_equal(before["nodes"])
	# Only the id and name values change; every other byte (integers included) is kept.
	assert_str(_read(model.library.path_for(&"campfire-ring"))).is_equal(
		WeftluminPatternLibrary.renamed_text(_read_text_before, &"campfire-ring", "Campfire Ring")
	)
	assert_str(_read(model.library.path_for(&"campfire-ring"))).contains('"schema": 1,')
	assert_bool(model.undo()["allowed"]).is_true()
	assert_bool(FileAccess.file_exists(old_path)).is_true()
	assert_bool(model.library.has_pattern(&"campfire-ring")).is_false()


func test_rename_refuses_a_taken_or_empty_name() -> void:
	_select([_sprite(world, "Lone", TEXTURE, Vector2(10, 10))] as Array[Node2D])
	model.save_pattern("Alpha")
	model.save_pattern("Beta")
	assert_str(str(model.rename_pattern(_entry("alpha"), "beta")["message"])).contains("already exists")
	assert_bool(model.rename_pattern(_entry("alpha"), " !! ")["allowed"]).is_false()
	assert_bool(model.library.has_pattern(&"alpha")).is_true()


func test_delete_is_one_undo_step_and_disarms_the_brush() -> void:
	_select([_sprite(world, "Lone", TEXTURE, Vector2(10, 10))] as Array[Node2D])
	model.save_pattern("Fence Run")
	var path: String = model.library.path_for(&"fence-run")
	var content: String = _read(path)
	model.choose_pattern(_entry("fence-run")["pattern"])
	assert_bool(model.delete_pattern(_entry("fence-run"))["allowed"]).is_true()
	assert_bool(FileAccess.file_exists(path)).is_false()
	assert_dict(model.pattern).is_empty()
	assert_bool(model.undo()["allowed"]).is_true()
	assert_str(_read(path)).is_equal(content)


func test_promotion_moves_a_pattern_into_the_repo_where_it_is_read_only() -> void:
	_select([_sprite(world, "Lone", TEXTURE, Vector2(10, 10))] as Array[Node2D])
	model.save_pattern("Well")
	var user_path: String = model.library.path_for(&"well")
	var content: String = _read(user_path)
	assert_bool(model.promote_pattern(_entry("well"))["allowed"]).is_true()
	var repo_path: String = model.library.path_for(&"well", WeftluminPatternLibrary.SOURCE_REPO)
	assert_str(_read(repo_path)).is_equal(content)
	assert_bool(FileAccess.file_exists(user_path)).is_false()
	var repo_entry: Dictionary = _entry("well", WeftluminPatternLibrary.SOURCE_REPO)
	assert_dict(repo_entry).is_not_empty()
	for outcome: Dictionary in [
		model.rename_pattern(repo_entry, "Deep Well"), model.delete_pattern(repo_entry),
		model.promote_pattern(repo_entry),
	]:
		assert_bool(outcome["allowed"]).is_false()
		assert_str(str(outcome["blocked_by"])).is_equal("read_only")
	assert_str(_read(repo_path)).is_equal(content)
	assert_bool(model.undo()["allowed"]).is_true()
	assert_bool(FileAccess.file_exists(repo_path)).is_false()
	assert_str(_read(user_path)).is_equal(content)
	assert_bool(model.redo()["allowed"]).is_true()
	# A repo pattern still arms as a brush.
	model.choose_pattern(_entry("well", WeftluminPatternLibrary.SOURCE_REPO)["pattern"])
	assert_bool(model.stamp_pattern(Vector2(500, 500), true)["allowed"]).is_true()
	assert_int(model.selection().size()).is_equal(1)


func test_saving_over_a_repo_name_writes_a_user_copy_and_leaves_the_repo_file() -> void:
	var lone: Sprite2D = _sprite(world, "Lone", TEXTURE, Vector2(10, 10))
	_select([lone] as Array[Node2D])
	model.save_pattern("Well")
	model.promote_pattern(_entry("well"))
	var repo_path: String = model.library.path_for(&"well", WeftluminPatternLibrary.SOURCE_REPO)
	var repo_content: String = _read(repo_path)
	var extra: Sprite2D = _sprite(world, "Extra", TEXTURE, Vector2(90, 40))
	_select([lone, extra] as Array[Node2D])
	assert_bool(model.save_pattern("Well")["allowed"]).is_true()
	assert_str(_read(repo_path)).is_equal(repo_content)
	assert_int((_entry("well")["pattern"]["nodes"] as Array).size()).is_equal(2)
	# Promoting the revision is how a repo pattern is updated.
	assert_bool(model.promote_pattern(_entry("well"))["allowed"]).is_true()
	assert_int((Patterns.load_file(repo_path)["nodes"] as Array).size()).is_equal(2)
	model.undo()
	assert_str(_read(repo_path)).is_equal(repo_content)


func test_library_commands_replay_from_the_log() -> void:
	_select([_sprite(world, "Lone", TEXTURE, Vector2(10, 10))] as Array[Node2D])
	model.save_pattern("Replay Me")
	model.rename_pattern(_entry("replay-me"), "Replayed")
	var entries: Array[Dictionary] = model.bus.log_entries()
	_remove_tree(ProjectSettings.globalize_path(LIBRARY_ROOT))
	var replayed: Dictionary = model.bus.replay(entries)
	assert_bool(replayed["allowed"]).is_true()
	assert_bool(model.library.has_pattern(&"replayed")).is_true()
	assert_bool(model.library.has_pattern(&"replay-me")).is_false()
