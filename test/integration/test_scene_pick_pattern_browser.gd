extends "res://test/helpers/scene_pick_fixture.gd"
## E3.1c (#370): the pattern browser in the Weftlumin dock, driven through real GUI input —
## save, arm-as-brush, stamp (stamped props stay selected), rearrange and re-save over the same
## name, rename, delete, promote, and the read-only repo row. Every library write is one undo
## step on the scene's history.
##
## Rendered evidence: set SOUL_METER_PATTERN_CAPTURE_DIR and run under Xvfb or a display.

const LIBRARY_ROOT := "user://scene_pick_pattern_browser"

var browser: WeftluminPatternBrowser


func before_test() -> void:
	await super.before_test()
	model.library.user_directory = LIBRARY_ROOT.path_join("user")
	model.library.repo_directory = LIBRARY_ROOT.path_join("repo")
	browser = panel.pattern_browser
	panel._refresh_patterns()
	(shell.root.find_child("TreePalette", true, false) as TabContainer).current_tab = 1
	await _frames()


func after_test() -> void:
	_remove_tree(ProjectSettings.globalize_path(LIBRARY_ROOT))
	await super.after_test()


static func _remove_tree(absolute: String) -> void:
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for directory: String in DirAccess.get_directories_at(absolute):
		_remove_tree(absolute.path_join(directory))
	for file: String in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(file))
	DirAccess.remove_absolute(absolute)


func _frames(count: int = 2) -> void:
	for _index: int in count:
		await get_tree().process_frame


## Press and release the left button on a Control-space point (fresh event per edge).
func gui_click(at: Vector2) -> void:
	motion(at)
	for pressed: bool in [true, false]:
		edge(at, pressed)


func press_button(button: Button) -> void:
	assert_bool(button.is_visible_in_tree()).is_true()
	gui_click(button.get_global_transform_with_canvas() * (button.size / 2.0))
	await _frames(1)


func choose_row(index: int) -> void:
	var item: TreeItem = browser.list.get_root().get_child(index)
	browser.list.scroll_to_item(item)
	await _frames(1)
	var area: Rect2 = browser.list.get_item_area_rect(item)
	gui_click(browser.list.get_global_transform_with_canvas() * area.get_center())
	await _frames(1)


func row_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for item: TreeItem in browser.list.get_root().get_children():
		texts.append(item.get_text(0))
	return texts


func drag(from: Vector2, to: Vector2) -> void:
	motion(screen_at(from))
	edge(screen_at(from), true)
	motion(screen_at((from + to) / 2.0), true)
	motion(screen_at(to), true)
	edge(screen_at(to), false)


func _save_pair(display_name: String) -> Array[Sprite2D]:
	var at: Vector2 = solid.global_position
	var first: Sprite2D = add_sprite("First", at - Vector2(140, 80))
	var second: Sprite2D = add_sprite("Second", at + Vector2(60, 80))
	click(screen_at(first.global_position))
	click(screen_at(second.global_position), true)
	browser.name_field.text = display_name
	await press_button(browser.save_button)
	return [first, second] as Array[Sprite2D]


func test_stamped_props_stay_selected_and_resave_over_their_own_name() -> void:
	var pair: Array[Sprite2D] = await _save_pair("Stall Pair")
	var path: String = model.library.path_for(&"stall-pair")
	assert_bool(FileAccess.file_exists(path)).is_true()
	assert_array(Array(row_texts())).contains_exactly(["Stall Pair (2)"])
	await choose_row(0)
	assert_str(str(model.pattern.get("id", ""))).is_equal("stall-pair")
	assert_str(browser.name_field.text).is_equal("Stall Pair")
	var target: Vector2 = solid.global_position + Vector2(0, 200)
	click(screen_at(target))
	await _frames(1)
	var placed: Array[Node2D] = model.selection()
	assert_int(placed.size()).is_equal(2)
	if placed.size() != 2:
		return
	assert_vector(placed[1].global_position - placed[0].global_position).is_equal(pair[1].global_position - pair[0].global_position)
	assert_dict(model.pattern).is_empty()
	# Rearrange one stamped prop, select the pair again, and save straight back over the name.
	var lead: Node2D = placed[0]
	var moved: Node2D = placed[1]
	click(screen_at(moved.global_position))
	drag(moved.global_position, moved.global_position + Vector2(64, 0))
	click(screen_at(lead.global_position))
	click(screen_at(moved.global_position), true)
	assert_int(model.selection().size()).is_equal(2)
	key(KEY_G, true)
	await _frames(1)
	var revised: Dictionary = WeftluminSceneModel.Patterns.load_file(path)
	var offsets: Array = []
	for record: Dictionary in revised["nodes"]:
		offsets.append(Vector2(record["offset"][0], record["offset"][1]))
	assert_vector((offsets[1] - offsets[0]).abs()).is_equal((moved.global_position - lead.global_position).abs())
	assert_array(Array(row_texts())).contains_exactly(["Stall Pair (2)"])
	# The re-save is one undo step that restores the first version.
	key(KEY_Z, true)
	var restored: Dictionary = WeftluminSceneModel.Patterns.load_file(path)
	var first_offsets: Array = []
	for record: Dictionary in restored["nodes"]:
		first_offsets.append(Vector2(record["offset"][0], record["offset"][1]))
	assert_vector((first_offsets[1] - first_offsets[0]).abs()).is_equal((pair[1].global_position - pair[0].global_position).abs())


func test_rename_delete_and_promote_from_the_browser_are_each_one_undo_step() -> void:
	await _save_pair("Fence Run")
	await choose_row(0)
	browser.name_field.text = "Long Fence"
	await press_button(browser.rename_button)
	assert_array(Array(row_texts())).contains_exactly(["Long Fence (2)"])
	assert_bool(model.library.has_pattern(&"fence-run")).is_false()
	key(KEY_Z, true)
	assert_array(Array(row_texts())).contains_exactly(["Fence Run (2)"])

	await choose_row(0)
	await press_button(browser.delete_button)
	assert_int(browser.list.get_root().get_child_count()).is_equal(0)
	key(KEY_Z, true)
	assert_array(Array(row_texts())).contains_exactly(["Fence Run (2)"])

	await choose_row(0)
	await press_button(browser.promote_button)
	assert_array(Array(row_texts())).contains_exactly(["Fence Run (2) · %s" % WeftluminPatternBrowser.REPO_TAG])
	assert_bool(model.library.has_pattern(&"fence-run", WeftluminPatternLibrary.SOURCE_REPO)).is_true()
	await choose_row(0)
	for button: Button in [browser.rename_button, browser.delete_button, browser.promote_button]:
		assert_bool(button.disabled).is_true()
	# The read-only row still arms as a brush.
	assert_str(str(model.pattern.get("id", ""))).is_equal("fence-run")
	key(KEY_Z, true)
	assert_array(Array(row_texts())).contains_exactly(["Fence Run (2)"])
	assert_bool(model.library.has_pattern(&"fence-run", WeftluminPatternLibrary.SOURCE_REPO)).is_false()


func test_rendered_pattern_library_capture() -> void:
	var directory := OS.get_environment("SOUL_METER_PATTERN_CAPTURE_DIR")
	if directory.is_empty():
		return
	assert_str(DisplayServer.get_name()).is_not_equal("headless")
	if DisplayServer.get_name() == "headless":
		return
	assert_int(DirAccess.make_dir_recursive_absolute(directory)).is_equal(OK)
	var pair: Array[Sprite2D] = await _save_pair("Market Stall")
	await choose_row(0)
	await press_button(browser.promote_button)
	click(screen_at(pair[0].global_position))
	click(screen_at(pair[1].global_position), true)
	browser.name_field.text = "Crate Pair"
	await press_button(browser.save_button)
	await choose_row(1)
	click(screen_at(solid.global_position + Vector2(-260, 40)))
	await _frames(1)
	assert_int(model.selection().size()).is_equal(2)
	await _capture(directory, "01-stamped-from-repo")


## Save a half-size full frame and a 1:1 crop of the dock's Palette slot.
func _capture(directory: String, stem: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var dock: Rect2 = browser.get_parent_control().get_global_rect()
	var crop: Image = frame.get_region(Rect2i(dock.grow(8.0).intersection(Rect2(Vector2.ZERO, frame.get_size()))))
	assert_int(crop.save_png(directory.path_join("%s-browser.png" % stem))).is_equal(OK)
	frame.resize(frame.get_width() / 2, frame.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	assert_int(frame.save_png(directory.path_join("%s-frame.png" % stem))).is_equal(OK)
