extends "res://test/helpers/scene_pick_fixture.gd"
## E3.1b (#339): the registry-driven actor palette and the schema-agnostic export inspector in
## the real dock, driven through their own controls and real pointer edges.


func _actors() -> WeftluminPlaceablePalette:
	(shell.root.find_child("TreePalette", true, false) as TabContainer).current_tab = 1
	(shell.root.find_child("PaletteTabs", true, false) as TabContainer).current_tab = 1
	return panel.actor_palette


func _entry(id: StringName) -> WeftluminPlaceable:
	for entry: WeftluminPlaceable in panel.placeables:
		if entry.id == id:
			return entry
	return null


func _place(id: StringName, offset: Vector2 = Vector2(160, 0)) -> Node2D:
	model.choose_placeable(_entry(id))
	var outcome: Dictionary = model.place_placeable(world_at(shell.viewport_surface.size / 2.0) + offset)
	assert_bool(bool(outcome["allowed"])).override_failure_message(str(outcome)).is_true()
	return model.primary()


func _inspector() -> WeftluminExportInspector:
	return panel.export_inspector


func test_palette_lists_the_registry_by_group_with_fuzzy_search() -> void:
	var palette := _actors()
	assert_bool(shell.root.find_child("Palette", true, false).is_ancestor_of(palette)).is_true()
	assert_int(panel.placeables.size()).is_equal(11)
	assert_int(palette.visible_entries().size()).is_equal(panel.placeables.size())
	palette.set_group("Doors & exits")
	var doors: Array[StringName] = []
	for entry: WeftluminPlaceable in palette.visible_entries():
		doors.append(entry.id)
	assert_array(doors).contains_exactly([&"building_door", &"travel_exit"])
	palette.set_group("")
	palette.search.text = "bdoor"
	palette.populate()
	assert_str(String(palette.visible_entries()[0].id)).is_equal("building_door")
	palette.search.text = "zzzqqq"
	palette.populate()
	assert_int(palette.list.get_root().get_child_count()).is_equal(0)


func test_choosing_an_actor_then_clicking_places_it_selected_in_the_inspector() -> void:
	var palette := _actors()
	assert_bool(palette.choose(&"chest")).is_true()
	assert_str(String(model.placeable.id)).is_equal("chest")
	assert_str(panel.status_text()).contains("Placing Chest")
	var at: Vector2 = world_at(shell.viewport_surface.size / 2.0) + Vector2(163, 5)
	click(screen_at(at))
	var placed: Node2D = model.primary()
	assert_object(placed).is_not_null()
	assert_str(placed.scene_file_path).is_equal("res://actors/chest/chest.tscn")
	# No walkable grid in the fixture, so the host snap declines and the 8 px snap applies.
	assert_vector(placed.global_position).is_equal(model.snap(at))
	assert_object(model.placeable).is_null()
	assert_object(palette.list.get_selected()).is_null()
	var exported: Array[String] = []
	for info: Dictionary in WeftluminSceneModel.exported_properties(placed):
		exported.append(str(info["name"]))
	assert_object(_inspector().target).is_same(placed)
	assert_array(Array(_inspector().keys())).contains_exactly(exported)
	assert_bool(shell.root.find_child("Inspector", true, false).is_ancestor_of(_inspector())).is_true()


func test_every_export_of_every_placeable_round_trips_through_its_inspector_editor() -> void:
	var inspector := _inspector()
	var index := 0
	for entry: WeftluminPlaceable in panel.placeables:
		var placed: Node2D = _place(entry.id, Vector2(64 * index - 256, 96))
		index += 1
		assert_object(inspector.target).is_same(placed)
		for info: Dictionary in WeftluminSceneModel.exported_properties(placed):
			var key: String = info["name"]
			assert_object(inspector.editor(key)).override_failure_message("%s.%s has no editor" % [entry.id, key]).is_not_null()
			var value: Variant = _new_value(inspector, info, placed.get(key))
			var log_size: int = model.bus.log_entries().size()
			(inspector._fields[key]["write"] as Callable).call(value)
			var outcome: Dictionary = inspector.commit_field(key)
			assert_bool(bool(outcome.get("allowed", false))).override_failure_message("%s.%s: %s" % [entry.id, key, outcome]).is_true()
			assert_str(var_to_str(placed.get(key))).override_failure_message("%s.%s" % [entry.id, key]).is_equal(var_to_str(value))
			assert_int(model.bus.log_entries().size()).is_equal(log_size + 1)
			assert_str(str(model.bus.log_entries().back()["params"]["export"])).is_equal(key)


## A valid, different value for the field: a picker option the host's validator accepts when
## the property has a picker, the range ends for an `@export_range`, otherwise a type-shaped edit.
func _new_value(inspector: WeftluminExportInspector, info: Dictionary, current: Variant) -> Variant:
	var key: String = info["name"]
	var type: int = int(info["type"])
	var choices: PackedStringArray = inspector.options(key)
	for choice: String in choices:
		var candidate: Variant = choice
		if type == TYPE_STRING_NAME:
			candidate = StringName(choice)
		elif type == TYPE_PACKED_STRING_ARRAY:
			var items: PackedStringArray = (current as PackedStringArray).duplicate()
			items.append(choice)
			candidate = items
		if var_to_str(candidate) != var_to_str(current) and inspector._validate(key, candidate).is_empty():
			return candidate
	if int(info["hint"]) == PROPERTY_HINT_RANGE:
		var parts: PackedStringArray = str(info["hint_string"]).split(",")
		var low: float = float(parts[0])
		var bound: float = low if not is_equal_approx(float(current), low) else float(parts[1])
		return int(bound) if type == TYPE_INT else bound
	match type:
		TYPE_BOOL: return not bool(current)
		TYPE_INT: return int(current) + 1
		TYPE_FLOAT: return float(current) + 1.5
		TYPE_STRING: return "%s edited" % current
		TYPE_STRING_NAME: return StringName("%s_edited" % current)
		TYPE_VECTOR2: return (current as Vector2) + Vector2(3, 5)
		TYPE_RECT2: return Rect2((current as Rect2).position + Vector2(1, 2), (current as Rect2).size + Vector2(3, 4))
		TYPE_COLOR: return Color(0.25, 0.5, 0.75, 1.0)
		TYPE_ARRAY:
			var typed: Array = (current as Array).duplicate()
			typed.clear()
			typed.assign([{"item_id": "consumables/hearthloaf", "count": 2}])
			return typed
	fail("%s has an untested type %s" % [key, type_string(type)])
	return current


func test_flag_picker_checks_grammar_live_and_refuses_an_invalid_flag() -> void:
	var pickup: Node2D = _place(&"pickup")
	var inspector := _inspector()
	assert_str(inspector.picker_for("completion_flag")).is_equal("flags")
	var line := inspector.editor("completion_flag") as LineEdit
	var log_size: int = model.bus.log_entries().size()
	line.text = "Bad.Flag"
	line.text_changed.emit(line.text)
	assert_str(inspector.message("completion_flag")).contains("lower snake case")
	line.text_submitted.emit(line.text)
	assert_str(str(pickup.get("completion_flag"))).is_empty()
	assert_int(model.bus.log_entries().size()).is_equal(log_size)
	# Picking from the menu commits a known, grammatical flag.
	var menu := inspector._fields["completion_flag"]["menu"] as MenuButton
	line.text = ""
	menu.about_to_popup.emit()
	var popup: PopupMenu = menu.get_popup()
	assert_int(popup.item_count).is_greater(0)
	var picked: String = ""
	for item: int in popup.item_count:
		if inspector._validate("completion_flag", popup.get_item_text(item)).is_empty():
			picked = popup.get_item_text(item)
			popup.index_pressed.emit(item)
			break
	assert_str(picked).is_not_empty()
	assert_str(str(pickup.get("completion_flag"))).is_equal(picked)
	assert_str(inspector.message("completion_flag")).is_empty()


func test_semantic_pickers_offer_catalog_ids_and_context_dependent_choices() -> void:
	var inspector := _inspector()
	_place(&"chest")
	assert_array(Array(inspector.options("owned_by_faction"))).contains([FactionIds.IRON_COMPANIES])
	assert_str(inspector.message("owned_by_faction")).is_empty()
	_place(&"pickup", Vector2(200, 64))
	assert_array(Array(inspector.options("item_id"))).contains([ItemIds.CONSUMABLES_HEARTHLOAF])
	var hostile: Node2D = _place(&"hostile", Vector2(240, 96))
	var units: PackedStringArray = inspector.options("unit_id")
	assert_int(units.size()).is_greater(0)
	for unit_id: String in units:
		assert_bool(EncounterCatalog.committed_archetype(unit_id).is_empty()).is_false()
	(inspector._fields["unit_id"]["write"] as Callable).call(&"no-such-unit")
	assert_str(str(inspector.commit_field("unit_id").get("message", ""))).contains("not a known id")
	assert_str(String(hostile.get("unit_id"))).is_empty()
	var door: Node2D = _place(&"building_door", Vector2(280, 128))
	assert_array(Array(inspector.options("destination_location_id"))).contains(["dom"])
	door.set("destination_location_id", &"dom")
	var spawns: PackedStringArray = inspector.options("spawn_id")
	assert_array(Array(spawns)).contains(["default"])
	for spawn: Variant in LocationRegistry.DOM.spawns:
		assert_array(Array(spawns)).contains([str(spawn)])
	var npc: Node2D = _place(&"npc", Vector2(320, 160))
	assert_array(Array(inspector.options("dialogue_path"))).contains(["res://dialogue/dom_townsfolk.dialogue"])
	assert_array(Array(inspector.options("dialogue_start"))).is_empty()
	npc.set("dialogue_path", "res://dialogue/dom_side_quests.dialogue")
	assert_array(Array(inspector.options("dialogue_start"))).contains(["dom_side_dishonest_casks"])
	(inspector._fields["dialogue_start"]["write"] as Callable).call("no_such_title")
	assert_bool(bool(inspector.commit_field("dialogue_start").get("allowed", true))).is_false()


func test_undo_reverts_an_inspector_edit_and_the_field_rereads() -> void:
	var chest: Node2D = _place(&"chest")
	var line := _inspector().editor("container_id") as LineEdit
	var before: String = str(chest.get("container_id"))
	line.text = "dom_test_cache"
	line.text_submitted.emit(line.text)
	assert_str(str(chest.get("container_id"))).is_equal("dom_test_cache")
	shell.viewport_surface.grab_focus()
	key(KEY_Z, true)
	assert_str(str(chest.get("container_id"))).is_equal(before)
	assert_str(line.text).is_equal(before)
	key(KEY_Z, true, true)
	assert_str(line.text).is_equal("dom_test_cache")


func test_viewport_motion_keeps_an_uncommitted_field_edit() -> void:
	var chest: Node2D = _place(&"chest")
	var line := _inspector().editor("container_id") as LineEdit
	var before: String = str(chest.get("container_id"))
	line.grab_focus()
	line.text = "dom_half_typed"
	motion(screen_at(chest.global_position + Vector2(40, 0)))
	assert_str(line.text).is_equal("dom_half_typed")
	assert_str(str(chest.get("container_id"))).is_equal(before)
	# Leaving the field commits it.
	shell.viewport_surface.grab_focus()
	assert_str(str(chest.get("container_id"))).is_equal("dom_half_typed")


## Rendered evidence: an NPC placed from the Actors palette by real pointer edges, then edited in
## the inspector (name typed, dialogue file and title picked). Run under Xvfb or a display with
## `SOUL_METER_WEFTLUMIN_PALETTE_CAPTURE_DIR`; writes palette and inspector crops and a half-scale
## overview.
func test_rendered_palette_and_inspector_capture() -> void:
	var directory := OS.get_environment("SOUL_METER_WEFTLUMIN_PALETTE_CAPTURE_DIR")
	if directory.is_empty():
		return
	assert_str(DisplayServer.get_name()).is_not_equal("headless")
	if DisplayServer.get_name() == "headless":
		return
	assert_int(DirAccess.make_dir_recursive_absolute(directory)).is_equal(OK)
	var palette := _actors()
	assert_bool(palette.choose(&"npc")).is_true()
	await get_tree().process_frame
	await _save_crop(directory.path_join("01-palette-armed.png"), shell.root.find_child("TreePalette", true, false) as Control)
	var at: Vector2 = world_at(shell.viewport_surface.size / 2.0) + Vector2(-120, 40)
	click(screen_at(at))
	var npc: Node2D = model.primary()
	assert_str(npc.scene_file_path).is_equal("res://actors/npc/npc.tscn")
	var inspector := _inspector()
	var name_line := inspector.editor("npc_name") as LineEdit
	name_line.text = "Aela Quietweftlumin"
	name_line.text_submitted.emit(name_line.text)
	for key_name: String in ["dialogue_path", "dialogue_start"]:
		var menu := inspector._fields[key_name]["menu"] as MenuButton
		menu.about_to_popup.emit()
		var popup: PopupMenu = menu.get_popup()
		var wanted: String = "res://dialogue/dom_townsfolk.dialogue" if key_name == "dialogue_path" else popup.get_item_text(0)
		for item: int in popup.item_count:
			if popup.get_item_text(item) == wanted:
				popup.index_pressed.emit(item)
	assert_str(str(npc.get("npc_name"))).is_equal("Aela Quietweftlumin")
	assert_str(str(npc.get("dialogue_path"))).is_equal("res://dialogue/dom_townsfolk.dialogue")
	assert_str(str(npc.get("dialogue_start"))).is_not_empty()
	var scroll := inspector.get_parent().get_parent() as ScrollContainer
	await get_tree().process_frame
	scroll.scroll_vertical = int(inspector.position.y)
	await _save_crop(directory.path_join("02-inspector-exports.png"), shell.root.find_child("Inspector", true, false) as Control)
	await _save_crop(directory.path_join("03-dock-overview.png"), shell.root, true)


func _save_crop(path: String, control: Control, halve: bool = false) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var crop: Image = frame.get_region(Rect2i(control.get_global_rect()).intersection(Rect2i(Vector2i.ZERO, frame.get_size())))
	if halve:
		crop.resize(maxi(1, crop.get_width() / 2), maxi(1, crop.get_height() / 2), Image.INTERPOLATE_LANCZOS)
	assert_int(crop.save_png(path)).is_equal(OK)
