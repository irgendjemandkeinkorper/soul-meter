class_name WeftluminScenePanel
extends WeftluminPanel
## The dock's left "Scene tree" slot (architecture §4.5.5) over the scene model (§4.6.1, E3.1a).
##
## The tree lists the live gameplay scene and marks each node's ownership boundary; only nodes
## the model can edit are selectable, and the tree's multi-selection IS the model's selection
## set. Every effect goes through `WeftluminSceneModel` and its command bus; this panel only
## presents. Chrome uses the `Editor*` theme variations.

const SNAP_LABELS: Array[String] = ["No snap", "8 px snap", "Cell snap"]
const BOUNDARY_TAGS := {
	WeftluminSceneModel.Boundary.INSTANCE: "instanced",
	WeftluminSceneModel.Boundary.RUNTIME: "runtime",
}

var model: WeftluminSceneModel = null
var tree: Tree = null
var status: Label = null
var snap_option: OptionButton = null
var _host: WeftluminShell = null
var _items: Dictionary = {}
var _syncing := false
var _sync_queued := false
var _last_selected: Node2D = null
var _message := ""
var _fields: Dictionary = {}
var _toggles: Dictionary = {}
var _properties: VBoxContainer
var _palette: Tree
var _palette_category: OptionButton
var _palette_search: LineEdit
var _pattern_name: LineEdit
var _pattern_list: Tree
var _layer_picker: OptionButton
var _syncing_properties := false


func _init() -> void:
	title = "Scene tree"
	needs_sandbox = false
	hotkey_hint = ""


func configure(host: WeftluminShell) -> void:
	_host = host
	if model != null:
		return
	model = WeftluminSceneModel.new()
	var adapter: WeftluminGameAdapter = host.adapter if host != null else null
	if adapter != null:
		# The adapter owns the editable-roots list; the panel only forwards to it.
		model.editable_roots_provider = func(scene_root: Node) -> Array[Node]:
			return adapter.editable_roots(scene_root)
	_build()
	model.selection_changed.connect(_sync_to_tree)
	model.scene_changed.connect(_rebuild)
	refresh({"scene_root": adapter.gameplay_scene_root() if adapter != null else null})
	if host != null:
		host.viewport_input.connect(_on_viewport_input)
		host.viewport_released.connect(_finish_pointer)
		host.viewport_draw.connect(_draw_selection)
		host.viewport_shortcut.connect(_on_shortcut)
		host.closing.connect(commit_pending_input)
		_mount_tools.call_deferred()


func refresh(payload: Dictionary) -> void:
	var scene_root: Node = payload.get("scene_root", model.scene_root) as Node
	if scene_root != model.scene_root or model.bus == null:
		if is_instance_valid(model.scene_root) and model.scene_root.tree_exiting.is_connected(_on_scene_exiting):
			model.scene_root.tree_exiting.disconnect(_on_scene_exiting)
		model.selection_changed.disconnect(_sync_to_tree)
		model.scene_changed.disconnect(_rebuild)
		if not _is_session():
			model.dispose()
		var provider: Callable = model.editable_roots_provider
		model = WeftluminSceneModel.session_for(scene_root) if scene_root != null and _host != null else WeftluminSceneModel.new()
		if model.bus == null:
			model.configure(scene_root)
		model.editable_roots_provider = provider
		model.selection_changed.connect(_sync_to_tree)
		model.scene_changed.connect(_rebuild)
		if scene_root != null and not scene_root.tree_exiting.is_connected(_on_scene_exiting):
			scene_root.tree_exiting.connect(_on_scene_exiting)
		model.grid = _grid_for(scene_root)
		snap_option.set_item_disabled(WeftluminSceneModel.Snap.CELL, model.grid == null)
		if model.grid == null and model.snap_mode == WeftluminSceneModel.Snap.CELL:
			set_snap_mode(WeftluminSceneModel.Snap.GRID)
		snap_option.select(model.snap_mode)
	_rebuild()


func commands() -> Array[Callable]:
	return model.command_constructors()


func _exit_tree() -> void:
	if model != null:
		commit_pending_input()
		if model.selection_changed.is_connected(_sync_to_tree):
			model.selection_changed.disconnect(_sync_to_tree)
		if model.scene_changed.is_connected(_rebuild):
			model.scene_changed.disconnect(_rebuild)
		if not _is_session():
			model.dispose()


func _is_session() -> bool:
	return is_instance_valid(model.scene_root) and model.scene_root.get_meta(WeftluminSceneModel.SESSION_META, null) == model


func _on_scene_exiting() -> void:
	commit_pending_input()
	if is_instance_valid(_host):
		_host.close()


func commit_pending_input() -> void:
	if not is_inside_tree():
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit and focused.get_parent() in _fields.values():
		(focused.get_parent() as SpinBox).apply()
	_finish_pointer()


func _finish_pointer() -> void:
	model.finish_pointer()
	_redraw()


func _on_viewport_input(event: InputEvent, world_position: Vector2) -> void:
	_report(model.pointer_input(event, world_position))
	_refresh_inspector()
	_redraw()


func _redraw() -> void:
	if is_instance_valid(_host) and is_instance_valid(_host.viewport_surface):
		_host.viewport_surface.queue_redraw()


## Rectangles use model bounds and the exact inverse of the input route. The centre control
## clips them at dock edges; line width remains constant under camera zoom.
func selection_rects() -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	if _host == null or _host.viewport_surface == null:
		return rectangles
	var transform: Transform2D = _host.viewport_surface.get_global_transform_with_canvas().affine_inverse() * get_viewport().canvas_transform
	for node: Node2D in model.selection():
		rectangles.append((transform * model.bounds(node)).grow(DS.SPACE_1))
	return rectangles


func _draw_selection(surface: Control) -> void:
	var members: Array[Node2D] = model.selection()
	var rectangles: Array[Rect2] = selection_rects()
	for index: int in rectangles.size():
		surface.draw_rect(rectangles[index], DS.BRONZE_4 if members[index] == model.primary() else DS.BRONZE_2, false, DS.BORDER_TRIM_W)


func _on_shortcut(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	var focused: Control = get_viewport().gui_get_focus_owner()
	if event.ctrl_pressed and key == KEY_S:
		_save()
		return
	if event.ctrl_pressed and key == KEY_G:
		_save_pattern()
		return
	if focused is LineEdit or focused is TextEdit:
		return
	match key:
		KEY_ESCAPE:
			model.cancel_drag()
			model.cancel_placement()
		KEY_DELETE: _report(model.delete_selection())
		KEY_D:
			if event.ctrl_pressed: _report(model.duplicate_selection())
		KEY_Z:
			if event.ctrl_pressed: _report(model.redo() if event.shift_pressed else model.undo())
		KEY_Y:
			if event.ctrl_pressed: _report(model.redo())
		KEY_S: _save()
		KEY_LEFT: _report(model.nudge(Vector2.LEFT))
		KEY_RIGHT: _report(model.nudge(Vector2.RIGHT))
		KEY_UP: _report(model.nudge(Vector2.UP))
		KEY_DOWN: _report(model.nudge(Vector2.DOWN))
	_redraw()


## A viewport click in world space: Shift-style `additive` toggles membership.
func pick_at(world_position: Vector2, additive: bool = false) -> Node2D:
	return model.pick_select(world_position, additive)


func set_snap_mode(mode: WeftluminSceneModel.Snap) -> void:
	model.snap_mode = mode
	snap_option.select(mode)
	_refresh_status()


func status_text() -> String:
	return status.text if status != null else ""


func _build() -> void:
	var content := VBoxContainer.new()
	content.name = "Content"
	content.theme_type_variation = &"EditorColumn"
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var snap_row := SoulMeterToolPanel._row()
	content.add_child(snap_row)
	snap_option = SoulMeterToolPanel._option("Snap")
	snap_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label: String in SNAP_LABELS:
		snap_option.add_item(label)
	snap_option.select(model.snap_mode)
	snap_option.item_selected.connect(func(index: int) -> void:
		set_snap_mode(index as WeftluminSceneModel.Snap)
	)
	snap_row.add_child(snap_option)
	snap_row.add_child(SoulMeterToolPanel._button("Undo", "Undo", func() -> void: _report(model.undo())))
	snap_row.add_child(SoulMeterToolPanel._button("Redo", "Redo", func() -> void: _report(model.redo())))
	var edit_row := SoulMeterToolPanel._row()
	content.add_child(edit_row)
	edit_row.add_child(SoulMeterToolPanel._button(
		"Duplicate", "Duplicate", func() -> void: _report(model.duplicate_selection())
	))
	edit_row.add_child(SoulMeterToolPanel._button(
		"Delete", "Delete", func() -> void: _report(model.delete_selection())
	))
	status = SoulMeterToolPanel._label("", &"EditorLabel", true)
	status.name = "Status"
	content.add_child(status)
	tree = Tree.new()
	tree.name = "SceneTree"
	tree.theme_type_variation = &"EditorTree"
	tree.select_mode = Tree.SELECT_MULTI
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.multi_selected.connect(_on_tree_multi_selected)
	content.add_child(tree)


func _rebuild() -> void:
	if tree == null:
		return
	_syncing = true
	tree.clear()
	_items.clear()
	if model.scene_root != null:
		_append(model.scene_root, null)
	_syncing = false
	_sync_to_tree()


func _append(node: Node, parent_item: TreeItem) -> void:
	var item := tree.create_item(parent_item)
	var info: Dictionary = model.boundary(node)
	var editable: bool = model.is_editable(node)
	var tag: String = BOUNDARY_TAGS.get(int(info["kind"]), "")
	if int(info["kind"]) == WeftluminSceneModel.Boundary.INSTANCE and bool(info["editable_instance"]):
		tag = "override"
	item.set_text(0, String(node.name) if tag.is_empty() else "%s  · %s" % [node.name, tag])
	item.set_tooltip_text(0, "%s (%s)" % [node.get_class(), "editable" if editable else "locked"])
	item.set_selectable(0, editable)
	item.set_metadata(0, weakref(node))
	item.collapsed = parent_item != null
	_items[node] = item
	for child: Node in node.get_children():
		# The model's own dormant session holder is editor plumbing, not scene content.
		if not child is WeftluminSceneModel.SessionLifetime:
			_append(child, item)


func _on_tree_multi_selected(item: TreeItem, _column: int, selected: bool) -> void:
	if _syncing:
		return
	var node := (item.get_metadata(0) as WeakRef).get_ref() as Node2D
	if selected and node != null:
		_last_selected = node
	# Tree emits once per changed row; read the settled set once.
	if not _sync_queued:
		_sync_queued = true
		_sync_from_tree.call_deferred()


func _sync_from_tree() -> void:
	_sync_queued = false
	var nodes: Array[Node2D] = []
	var item: TreeItem = tree.get_next_selected(null)
	while item != null:
		var node := (item.get_metadata(0) as WeakRef).get_ref() as Node2D
		if node != null:
			nodes.append(node)
		item = tree.get_next_selected(item)
	model.set_selection(nodes, _last_selected)


func _sync_to_tree() -> void:
	if tree == null:
		return
	_syncing = true
	tree.deselect_all()
	var lead: Node2D = model.primary()
	for node: Node2D in model.selection():
		var item: TreeItem = _items.get(node)
		if item == null:
			continue
		var ancestor: TreeItem = item.get_parent()
		while ancestor != null:
			ancestor.collapsed = false
			ancestor = ancestor.get_parent()
		item.select(0)
	if lead != null and _items.has(lead):
		tree.scroll_to_item(_items[lead] as TreeItem)
	_syncing = false
	_refresh_status()
	_refresh_inspector()
	_redraw()


func _report(outcome: Dictionary) -> void:
	_message = "" if bool(outcome.get("allowed", false)) else str(outcome.get("message", ""))
	_refresh_status()


func _refresh_status() -> void:
	if status == null:
		return
	var members: Array[Node2D] = model.selection()
	var lines: PackedStringArray = []
	if model.scene_root == null:
		lines.append("No gameplay scene.")
	elif members.is_empty():
		lines.append("Select a scene node.")
	else:
		lines.append("%d selected · primary %s" % [members.size(), model.primary().name])
	lines.append(SNAP_LABELS[model.snap_mode])
	lines.append("Unsaved changes" if model.is_dirty() else "Saved")
	if not model.texture_path.is_empty():
		lines.append("Placing %s · Shift repeats" % model.texture_path.get_file())
	elif not model.pattern.is_empty():
		lines.append("Stamping %s · Shift repeats" % model.pattern.get("name", "pattern"))
	if model.recovery_error != OK:
		lines.append("Recovery failed: %s" % error_string(model.recovery_error))
	if not _message.is_empty():
		lines.append(_message)
	status.text = "\n".join(lines)


func _refresh_inspector() -> void:
	if _host == null or _host.inspector == null:
		return
	var lead: Node2D = model.primary()
	_sync_properties(lead)
	if lead == null:
		_host.inspector.text = "INSPECTOR\nSelect a scene node."
		return
	var info: Dictionary = model.boundary(lead)
	var ownership := "scene-owned"
	if int(info["kind"]) == WeftluminSceneModel.Boundary.INSTANCE:
		ownership = "instance override (%s)" % (info["instance_root"] as Node).name
	_host.inspector.text = "INSPECTOR\n%s\n%s · %s\nposition %s" % [
		lead.name, lead.get_class(), ownership, lead.position,
	]


## Populate the existing Inspector and Palette slots; shell chrome stays shell-owned.
func _mount_tools() -> void:
	if not is_instance_valid(_host) or not is_inside_tree():
		return
	var frame: Node = _host.inspector.get_parent()
	var column := VBoxContainer.new()
	column.theme_type_variation = &"EditorColumn"
	frame.remove_child(_host.inspector)
	frame.add_child(column)
	column.add_child(_host.inspector)
	column.add_child(SoulMeterToolPanel._button("Save scratch (Ctrl+S)", "SaveScratch", _save))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_properties = VBoxContainer.new()
	_properties.theme_type_variation = &"EditorColumn"
	_properties.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_properties)
	_add_fields("Position", ["x", "y"], -100000, 100000)
	_add_fields("Scale", ["scale_x", "scale_y"], 0.01, 20)
	_add_fields("Rotation / skew (degrees)", ["rotation", "skew"], -360, 360)
	_fields["skew"].min_value = -80
	_fields["skew"].max_value = 80
	_add_fields("Solid footprint", ["width", "height"], 1, WeftluminSceneModel.MAX_FOOTPRINT.x)
	_fields["height"].max_value = WeftluminSceneModel.MAX_FOOTPRINT.y
	var resize := SoulMeterToolPanel._row()
	_properties.add_child(resize)
	for entry: Array in [["Shrink", 0.8], ["Enlarge", 1.25]]:
		resize.add_child(SoulMeterToolPanel._button(entry[0], entry[0], _resize.bind(float(entry[1]))))
	for entry: Array in [["flip_h", "Flip horizontally"], ["flip_v", "Flip vertically"], ["grayscale", "Grayscale"]]:
		var toggle := CheckBox.new()
		toggle.text = entry[1]
		toggle.theme_type_variation = &"EditorCheckBox"
		toggle.toggled.connect(_toggle_property.bind(String(entry[0])))
		_properties.add_child(toggle)
		_toggles[entry[0]] = toggle
	var palette_slot: Node = _host.root.find_child("Palette", true, false)
	if palette_slot != null:
		for child: Node in palette_slot.get_children():
			child.free()
		_build_palette(palette_slot)
	_refresh_inspector()


func _add_fields(label: String, keys: Array, low: float, high: float) -> void:
	_properties.add_child(SoulMeterToolPanel._label(label))
	var row := SoulMeterToolPanel._row()
	_properties.add_child(row)
	for key: String in keys:
		var field := SpinBox.new()
		field.name = key.to_pascal_case()
		field.theme_type_variation = &"EditorSpinBox"
		field.min_value = low
		field.max_value = high
		field.step = 0.001
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.value_changed.connect(_property_changed.bind(key))
		row.add_child(field)
		_fields[key] = field


func _sync_properties(lead: Node2D) -> void:
	if _fields.is_empty():
		return
	_syncing_properties = true
	for field: SpinBox in _fields.values():
		field.editable = lead != null
	if lead != null:
		var values := {"x": lead.position.x, "y": lead.position.y, "scale_x": absf(lead.scale.x), "scale_y": absf(lead.scale.y), "rotation": lead.rotation_degrees, "skew": rad_to_deg(lead.skew)}
		for key: String in values:
			(_fields[key] as SpinBox).set_value_no_signal(float(values[key]))
	var collision: CollisionShape2D = LayoutOverrides.find_collision(lead) if lead is StaticBody2D else null
	var dimensions: Vector2 = (collision.shape as RectangleShape2D).size if collision != null and collision.shape is RectangleShape2D else model.footprint
	for axis: int in 2:
		var field := _fields["width" if axis == 0 else "height"] as SpinBox
		field.editable = collision != null or not model.texture_path.is_empty()
		field.set_value_no_signal(dimensions[axis])
	var sprite: Sprite2D = LayoutOverrides.find_sprite(lead) if lead != null else null
	for key: String in _toggles:
		var toggle := _toggles[key] as CheckBox
		toggle.disabled = sprite == null if key != "grayscale" else lead == null or not LayoutOverrides.supports_grayscale(lead)
		var value: bool = bool(sprite.get(key)) if sprite != null and key != "grayscale" else lead != null and LayoutOverrides.is_grayscale(lead)
		toggle.set_pressed_no_signal(value)
	_syncing_properties = false


func _property_changed(value: float, key: String) -> void:
	if _syncing_properties:
		return
	var lead: Node2D = model.primary()
	if key in ["width", "height"]:
		var axis := 0 if key == "width" else 1
		if not model.texture_path.is_empty():
			model.footprint[axis] = value
			return
		var collision: CollisionShape2D = LayoutOverrides.find_collision(lead) if lead != null else null
		if collision != null and collision.shape is RectangleShape2D:
			var dimensions: Vector2 = collision.shape.size
			dimensions[axis] = value
			_report(model.set_primary_properties({"collision": [dimensions.x, dimensions.y]}))
		return
	if lead == null:
		return
	var values: Dictionary = {}
	match key:
		"x": values["position"] = [value, lead.position.y]
		"y": values["position"] = [lead.position.x, value]
		"scale_x": values["scale"] = [value * signf(lead.scale.x), lead.scale.y]
		"scale_y": values["scale"] = [lead.scale.x, value * signf(lead.scale.y)]
		"rotation", "skew": values[key] = deg_to_rad(value)
	_report(model.set_primary_properties(values))


func _toggle_property(value: bool, key: String) -> void:
	if not _syncing_properties:
		_report(model.set_primary_properties({key: value}))


func _resize(factor: float) -> void:
	var lead: Node2D = model.primary()
	if lead != null:
		_report(model.set_primary_properties({"scale": [signf(lead.scale.x) * clampf(absf(lead.scale.x) * factor, 0.01, 20), signf(lead.scale.y) * clampf(absf(lead.scale.y) * factor, 0.01, 20)]}))


func _build_palette(slot: Node) -> void:
	var content := VBoxContainer.new()
	content.theme_type_variation = &"EditorColumn"
	slot.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer_picker = SoulMeterToolPanel._option("Layer")
	for layer_name: StringName in LayoutOverrides.DRESSING_LAYERS:
		_layer_picker.add_item(String(layer_name))
	_layer_picker.select(LayoutOverrides.DRESSING_LAYERS.find(model.placement_layer))
	_layer_picker.item_selected.connect(func(index: int) -> void:
		model.placement_layer = LayoutOverrides.DRESSING_LAYERS[index]
	)
	content.add_child(_layer_picker)
	_palette_category = SoulMeterToolPanel._option("Category")
	for category: Dictionary in WeftluminSceneModel.PALETTE_CATEGORIES:
		_palette_category.add_item(category["label"])
	_palette_category.item_selected.connect(func(_index: int) -> void: _populate_palette())
	content.add_child(_palette_category)
	_palette_search = LineEdit.new()
	_palette_search.theme_type_variation = &"EditorLineEdit"
	_palette_search.text_changed.connect(func(_text: String) -> void: _populate_palette())
	content.add_child(_palette_search)
	_palette = _list_tree(content)
	_palette.item_selected.connect(func() -> void:
		model.choose_texture(str(_palette.get_selected().get_metadata(0)))
		_pattern_list.deselect_all()
	)
	_pattern_name = LineEdit.new()
	_pattern_name.theme_type_variation = &"EditorLineEdit"
	_pattern_name.placeholder_text = "Pattern name"
	content.add_child(_pattern_name)
	content.add_child(SoulMeterToolPanel._button("Save pattern (Ctrl+G)", "SavePattern", _save_pattern))
	_pattern_list = _list_tree(content)
	_pattern_list.item_selected.connect(func() -> void:
		model.choose_pattern(_pattern_list.get_selected().get_metadata(0) as Dictionary)
		_palette.deselect_all()
	)
	_populate_palette()
	_refresh_patterns()


func _list_tree(parent: Node) -> Tree:
	var list := Tree.new()
	list.theme_type_variation = &"EditorTree"
	list.hide_root = true
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(list)
	return list


func _populate_palette() -> void:
	_palette.clear()
	var root_item: TreeItem = _palette.create_item()
	var entries: Array[Dictionary] = WeftluminSceneModel.palette_entries(_palette_category.selected, _palette_search.text)
	var count: int = mini(entries.size(), WeftluminSceneModel.PALETTE_RESULT_LIMIT)
	for index: int in count:
		var path: String = entries[index]["path"]
		var item: TreeItem = _palette.create_item(root_item)
		item.set_text(0, path.get_file().get_basename())
		item.set_tooltip_text(0, path)
		item.set_metadata(0, path)
		item.set_icon(0, load(path) as Texture2D)
		item.set_icon_max_width(0, DS.SLOT_SIZE_SM)
	_palette_search.placeholder_text = "Search %d assets (%d shown)" % [entries.size(), count]


func _refresh_patterns() -> void:
	if _pattern_list == null:
		return
	_pattern_list.clear()
	var root_item: TreeItem = _pattern_list.create_item()
	for pattern: Dictionary in WeftluminSceneModel.Patterns.list_patterns():
		var item: TreeItem = _pattern_list.create_item(root_item)
		item.set_text(0, "%s (%d)" % [pattern["name"], (pattern["nodes"] as Array).size()])
		item.set_metadata(0, pattern)


func _save_pattern() -> void:
	commit_pending_input()
	_report(model.save_pattern(_pattern_name.text if _pattern_name != null else ""))
	_refresh_patterns()


func _save() -> void:
	commit_pending_input()
	_report(model.save())


static func _grid_for(scene_root: Node) -> IsoGrid:
	if scene_root == null:
		return null
	var pending: Array[Node] = [scene_root]
	while not pending.is_empty():
		var node: Node = pending.pop_front()
		if node is FieldMap:
			return (node as FieldMap).iso_grid()
		pending.append_array(node.get_children())
	return null
