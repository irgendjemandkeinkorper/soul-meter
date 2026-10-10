extends "res://test/helpers/scene_pick_fixture.gd"


func after_test() -> void:
	WeftluminSceneModel.Patterns.delete_pattern(&"test-cluster")
	await super.after_test()


func test_ctrl_g_saves_group_and_stamping_recreates_arrangement_in_one_step() -> void:
	var at: Vector2 = solid.global_position
	var first: Sprite2D = add_sprite("First", at - Vector2(140, 80))
	var second: Sprite2D = add_sprite("Second", at + Vector2(60, 80))
	var spacing: Vector2 = second.global_position - first.global_position
	click(screen_at(first.global_position))
	click(screen_at(second.global_position), true)
	panel._pattern_name.text = "Test Cluster"
	(shell.root.find_child("TreePalette", true, false) as TabContainer).current_tab = 1
	panel._pattern_name.grab_focus()
	key(KEY_G, true)
	var stored: Dictionary = WeftluminSceneModel.Patterns.load_file(WeftluminSceneModel.Patterns.pattern_path_for_id(&"test-cluster"))
	assert_dict(stored).is_not_empty()
	assert_int(stored.get("nodes", []).size()).is_equal(2)
	assert_int(panel._pattern_list.get_root().get_child_count()).is_equal(1)
	model.choose_pattern(stored)
	click(screen_at(at + Vector2(180, 0)))
	var placed: Array[Node2D] = model.selection()
	assert_int(placed.size()).is_equal(2)
	if placed.size() != 2:
		return
	assert_vector(placed[1].global_position - placed[0].global_position).is_equal(spacing)
	assert_int(world.get_node("GroundDetails").get_child_count()).is_equal(4)
	model.undo()
	assert_int(world.get_node("GroundDetails").get_child_count()).is_equal(2)
	model.redo()
	assert_int(world.get_node("GroundDetails").get_child_count()).is_equal(4)


func test_ctrl_g_refuses_empty_selection_and_nameless_pattern() -> void:
	# Driven through the real Ctrl+G shortcut; the refusal reaches the owner in the dock status.
	model.clear_selection()
	panel._pattern_name.text = "Nothing selected"
	key(KEY_G, true)
	assert_str(panel.status_text()).contains("Select something first")
	model.select_only(solid)
	panel._pattern_name.text = "   "
	key(KEY_G, true)
	assert_str(panel.status_text()).contains("name")


func test_palette_filters_by_category_and_fuzzy_search() -> void:
	panel._palette_category.selected = 0
	panel._populate_palette()
	var items: Array[TreeItem] = panel._palette.get_root().get_children()
	assert_int(items.size()).is_greater(0)
	for item: TreeItem in items:
		assert_str(item.get_metadata(0)).contains("fantasy-town-kit")
	panel._palette_search.text = "zzzzqqq"
	panel._populate_palette()
	assert_int(panel._palette.get_root().get_child_count()).is_equal(0)
	panel._palette_search.text = ""
	panel._populate_palette()
	assert_int(panel._palette.get_root().get_child_count()).is_equal(items.size())


func test_delete_removes_group_in_one_step() -> void:
	var first: Sprite2D = add_sprite("First", solid.global_position - Vector2(150, 0))
	var second: Sprite2D = add_sprite("Second", solid.global_position + Vector2(150, 0))
	click(screen_at(first.global_position))
	click(screen_at(second.global_position), true)
	key(KEY_DELETE)
	assert_object(world.get_node_or_null("GroundDetails/First")).is_null()
	assert_object(world.get_node_or_null("GroundDetails/Second")).is_null()
	key(KEY_Z, true)
	assert_object(world.get_node_or_null("GroundDetails/First")).is_same(first)
	assert_object(world.get_node_or_null("GroundDetails/Second")).is_same(second)
	assert_bool(model.undo()["allowed"]).is_false()
