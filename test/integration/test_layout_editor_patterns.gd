extends GdUnitTestSuite
## Multi-select and the pattern library, driven through the live editor.
##
## The document format has its own suite (test_layout_patterns.gd); this one covers what only
## the editor can be wrong about — that Shift+click builds a group rather than replacing the
## selection, that a group move is ONE undo step and keeps its internal spacing, and that
## Ctrl+G round-trips a group out to the library and back onto the map.

const EditorScene := preload("res://ui/debug/layout_editor.tscn")
const Patterns := preload("res://globals/layout_patterns.gd")

var world: Node2D
var editor: Control
var _saved_ids: Array[StringName] = []


func before_test() -> void:
	world = Node2D.new()
	world.scene_file_path = "res://layout_patterns_test_fixture.tscn"
	add_child(world)
	for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
		var layer := Node2D.new()
		layer.name = layer_name
		world.add_child(layer)
	editor = EditorScene.instantiate()
	add_child(editor)
	editor.configure(world)
	await get_tree().process_frame


func after_test() -> void:
	editor.free()
	assert_int(preload("res://globals/layout_recovery.gd").clear(world.scene_file_path)).is_equal(OK)
	world.free()
	# The library is real user:// state; a suite that leaves patterns behind would leak into
	# the editor's own list on the next run.
	for id: StringName in _saved_ids:
		Patterns.delete_pattern(id)
	_saved_ids.clear()


func _sprite(node_name: String, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = load("res://icon.svg")
	world.get_node("GroundDetails").add_child(sprite)
	sprite.global_position = at
	return sprite


func _click(at: Vector2, shift: bool = false) -> void:
	var press := InputEventMouseButton.new()
	press.pressed = true
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = at
	press.shift_pressed = shift
	editor._handle_mouse_button(press)


func test_shift_click_builds_a_group_and_clicking_again_removes_from_it() -> void:
	var first := _sprite("First", Vector2(100.0, 100.0))
	var second := _sprite("Second", Vector2(200.0, 100.0))

	_click(first.global_position)
	assert_int((editor.get("_selection") as Array).size()).is_equal(1)

	_click(second.global_position, true)
	var selection: Array = editor.get("_selection")
	assert_int(selection.size()).override_failure_message(
		"shift+click must ADD to the selection, not replace it"
	).is_equal(2)
	assert_object(editor.get("_selected")).override_failure_message(
		"the primary follows the most recent addition"
	).is_same(second)

	# Shift+click on a member takes it back out, and the primary falls back to what is left.
	_click(second.global_position, true)
	assert_int((editor.get("_selection") as Array).size()).is_equal(1)
	assert_object(editor.get("_selected")).is_same(first)

	# A plain click elsewhere collapses the group back to one.
	_click(first.global_position)
	assert_int((editor.get("_selection") as Array).size()).is_equal(1)


func test_a_group_drag_moves_everything_rigidly_in_one_undo_step() -> void:
	var first := _sprite("First", Vector2(100.0, 100.0))
	# 200px apart: the icons are 128px, so each click point falls inside exactly one of them.
	var second := _sprite("Second", Vector2(300.0, 100.0))
	var spacing: Vector2 = second.global_position - first.global_position

	_click(first.global_position)
	_click(second.global_position, true)
	# Grab the primary and drag the group.
	_click(second.global_position)

	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = second.global_position + Vector2(80.0, 40.0)
	editor._handle_mouse_motion(motion)

	var release := InputEventMouseButton.new()
	release.pressed = false
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	editor._handle_mouse_button(release)

	assert_vector(second.global_position - first.global_position).override_failure_message(
		"a group drag must preserve the group's internal spacing, not collapse it on the cursor"
	).is_equal(spacing)
	var moved_to: Vector2 = first.global_position

	var session: Node = editor.get("_session")
	assert_bool(session.history.has_undo()).is_true()
	editor._undo()
	assert_vector(first.global_position).override_failure_message(
		"one undo must put the whole group back, not just the primary"
	).is_equal(Vector2(100.0, 100.0))
	assert_vector(second.global_position).is_equal(Vector2(300.0, 100.0))
	# One step, not two: a second undo must not exist for this drag.
	editor._redo()
	assert_vector(first.global_position).is_equal(moved_to)


func test_delete_removes_the_whole_group_in_one_step() -> void:
	var first := _sprite("First", Vector2(100.0, 100.0))
	var second := _sprite("Second", Vector2(200.0, 100.0))
	_click(first.global_position)
	_click(second.global_position, true)

	editor._delete_selected()
	assert_object(world.get_node_or_null("GroundDetails/First")).is_null()
	assert_object(world.get_node_or_null("GroundDetails/Second")).is_null()

	editor._undo()
	assert_object(world.get_node_or_null("GroundDetails/First")).is_same(first)
	assert_object(world.get_node_or_null("GroundDetails/Second")).is_same(second)


func test_ctrl_g_saves_the_group_and_stamping_it_recreates_the_arrangement() -> void:
	var first := _sprite("First", Vector2(100.0, 100.0))
	var second := _sprite("Second", Vector2(300.0, 260.0))
	var spacing: Vector2 = second.global_position - first.global_position
	_click(first.global_position)
	_click(second.global_position, true)

	editor.get_node("%PatternName").text = "Test Cluster"
	editor._save_selection_as_pattern()
	_saved_ids.append(&"test-cluster")

	var stored: Dictionary = Patterns.load_file(Patterns.pattern_path_for_id(&"test-cluster"))
	assert_dict(stored).override_failure_message("Ctrl+G must write the pattern to disk").is_not_empty()
	assert_int((stored["nodes"] as Array).size()).is_equal(2)
	# The library list is refreshed in place, so the new pattern is immediately stampable.
	assert_int((editor.get_node("%PatternList") as ItemList).item_count).is_equal(1)

	var before_count: int = world.get_node("GroundDetails").get_child_count()
	editor.set("_selected_pattern", stored)
	_click(Vector2(600.0, 400.0))

	var added: int = world.get_node("GroundDetails").get_child_count() - before_count
	assert_int(added).override_failure_message("stamping must place every prop in the pattern").is_equal(2)
	var stamped: Array[Node2D] = editor.get("_selection")
	assert_int(stamped.size()).override_failure_message(
		"a stamped pattern stays selected so it can be rearranged and re-saved"
	).is_equal(2)
	assert_vector(stamped[1].global_position - stamped[0].global_position).override_failure_message(
		"a stamped pattern must reproduce the arrangement it was captured from"
	).is_equal(spacing)

	# One undo step for the whole stamp, and redo puts the whole stamp back.
	editor._undo()
	assert_int(world.get_node("GroundDetails").get_child_count()).is_equal(before_count)
	editor._redo()
	assert_int(world.get_node("GroundDetails").get_child_count()).override_failure_message(
		"redo must restore every prop the stamp placed"
	).is_equal(before_count + 2)


func test_ctrl_g_refuses_an_empty_selection_and_a_nameless_pattern() -> void:
	editor.get_node("%PatternName").text = "Nothing Selected"
	editor._save_selection_as_pattern()
	assert_str(str(editor.get("_message"))).contains("Select something first")

	var prop := _sprite("Prop", Vector2(100.0, 100.0))
	_click(prop.global_position)
	editor.get_node("%PatternName").text = "   "
	editor._save_selection_as_pattern()
	assert_str(str(editor.get("_message"))).override_failure_message(
		"a nameless pattern must be refused with the format's own message"
	).contains("name")


func test_the_palette_filters_by_category_and_fuzzy_search() -> void:
	var palette: ItemList = editor.get_node("%Palette")
	var search: LineEdit = editor.get_node("%PaletteSearch")
	var category: OptionButton = editor.get_node("%PaletteCategory")

	# Category 0 is the fantasy town kit; every result must come from it.
	category.selected = 0
	editor._populate_palette()
	assert_int(palette.item_count).override_failure_message(
		"the town category must find the fantasy-town-kit assets"
	).is_greater(0)
	for index in palette.item_count:
		assert_str(str(palette.get_item_metadata(index))).contains("fantasy-town-kit")

	var unfiltered: int = palette.item_count
	search.text = "zzzzqqq"
	editor._populate_palette()
	assert_int(palette.item_count).override_failure_message(
		"a query matching nothing must empty the list, not fall back to everything"
	).is_equal(0)

	search.text = ""
	editor._populate_palette()
	assert_int(palette.item_count).is_equal(unfiltered)
