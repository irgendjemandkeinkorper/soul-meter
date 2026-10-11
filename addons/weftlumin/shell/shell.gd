class_name WeftluminShell
extends CanvasLayer
## One modal dock. The host adapter owns pause policy; this node only owns editor UI/input.

signal viewport_input(event: InputEvent, world_position: Vector2)
signal viewport_released
signal viewport_draw(surface: Control)
signal viewport_shortcut(event: InputEventKey)
signal closing

const TOGGLE_ACTION := &"weftlumin_toggle"
const ZOOM_STEP := 1.1
const MIN_ZOOM := 0.1
const MAX_ZOOM := 8.0
## Bottom tabs the dock always offers (§4.5.5), placeholders until a host panel fills them.
const BOTTOM_TABS: Array[String] = ["Console", "Command log", "Consequence timeline", "Validation"]
## Left-dock slot a host panel with this title takes over (E3.1a's scene panel); the built-in
## read-only tree stays as the fallback when no host panel claims it.
const SCENE_TREE_TAB := "Scene tree"
## #478 (owner ruling 2026-10-10): the bottom dock opens at this share of the screen height. A
## layout ratio, not a size token; the clamps on either side of the handle are the DS
## `dock_height` constant, so neither the bottom tab bar nor the viewport can be squeezed shut.
const DEFAULT_DOCK_FRACTION := 0.3

## Bottom-dock height the person dragged to, kept for the session across editor close and reopen
## (in memory: the project has no editor-preferences store). Negative means "use the default".
static var _remembered_dock_height := -1.0

var adapter: WeftluminGameAdapter
var root: Control
var camera: Camera2D
var viewport_surface: Control
var bottom_tabs: TabContainer
## Viewport / bottom-dock boundary; its drag handle resizes the bottom dock.
var dock_split: VSplitContainer
var scene_tree: Tree
var inspector: Label
var _previous_camera: Camera2D
var _previous_canvas_transform: Transform2D
var _previous_focus: Control
var _sandbox_panel: WeftluminPanel
var _opened := false
var _panning := false
var _selected_tab := 0
var _drag_start_offset := 0


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	if adapter == null:
		adapter = WeftluminGameAdapter.new()
	root = $Root
	root.theme = adapter.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.focus_mode = Control.FOCUS_ALL
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey:
			viewport_shortcut.emit(event as InputEventKey)
		root.accept_event()
	)
	_previous_focus = get_viewport().gui_get_focus_owner()
	_build_dock()
	_open_camera()
	_opened = true
	adapter.set_editor_open(true)
	root.grab_focus()


func _exit_tree() -> void:
	_release()


func _release() -> void:
	if not _opened:
		return
	_opened = false
	closing.emit()
	_end_owned_sandbox()
	camera.enabled = false
	if is_instance_valid(_previous_camera) and _previous_camera.is_inside_tree():
		_previous_camera.make_current()
		_previous_camera.force_update_scroll()
	else:
		get_viewport().canvas_transform = _previous_canvas_transform
	adapter.set_editor_open(false)
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()


func close() -> void:
	# Commit focused numeric text while the dock is still visible and owns GUI focus.
	_release()
	hide()
	set_process_input(false)
	set_process_shortcut_input(false)
	set_process_unhandled_key_input(false)
	set_process_unhandled_input(false)
	if get_parent() == get_node_or_null("/root/WeftluminBootstrap"):
		# Bootstrap frees synchronously; it must run after this shell's call returns.
		get_parent().call_deferred("close")
	else:
		queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_MIDDLE and not button.pressed:
			_panning = false
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			# Finish even if the pointer now lies over a dock or outside the centre surface.
			viewport_released.emit()
	if InputMap.has_action(TOGGLE_ACTION) and event.is_action(TOGGLE_ACTION):
		get_viewport().set_input_as_handled()
		if event.is_action_pressed(TOGGLE_ACTION) and not event.is_echo():
			close.call_deferred()


## Let focused dock controls receive GUI input first, then stop every remaining event
## before the host's unhandled-input shortcuts or physics picking can receive it.
func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey:
		viewport_shortcut.emit(event as InputEventKey)
	get_viewport().set_input_as_handled()


func _unhandled_key_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _build_dock() -> void:
	var layout := VBoxContainer.new()
	layout.name = "Dock"
	layout.theme_type_variation = &"EditorColumn"
	root.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var toolbar := HBoxContainer.new()
	toolbar.theme_type_variation = &"EditorRow"
	layout.add_child(toolbar)
	var title_label := Label.new()
	title_label.text = "WEFTLUMIN"
	title_label.theme_type_variation = &"EditorHeading"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title_label)
	var close_button := Button.new()
	close_button.name = "Close"
	close_button.text = "Close editor"
	close_button.theme_type_variation = &"EditorButton"
	close_button.pressed.connect(func() -> void: close.call_deferred())
	toolbar.add_child(close_button)

	var vertical := VSplitContainer.new()
	vertical.name = "VerticalDock"
	vertical.theme_type_variation = &"EditorVSplitContainer"
	vertical.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(vertical)
	var left_split := HSplitContainer.new()
	left_split.theme_type_variation = &"EditorHSplitContainer"
	left_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Max clamp: the viewport side keeps at least one dock height, however far the handle goes.
	left_split.custom_minimum_size.y = root.get_theme_constant(&"dock_height", &"EditorTabContainer")
	vertical.add_child(left_split)
	var left := TabContainer.new()
	left.name = "TreePalette"
	left.theme_type_variation = &"EditorTabContainer"
	left.custom_minimum_size.x = root.get_theme_constant(&"dock_width", &"EditorPanel")
	left_split.add_child(left)
	var hosted: Array[WeftluminPanel] = _instantiate_host_panels()
	var tree_index := hosted.find_custom(
		func(candidate: WeftluminPanel) -> bool: return candidate.title == SCENE_TREE_TAB
	)
	if tree_index >= 0:
		_mount(hosted.pop_at(tree_index), left)
	else:
		_build_scene_tree(_panel(SCENE_TREE_TAB, left))
	var palette_panel := _panel("Palette", left)
	var palette := Tree.new()
	palette.theme_type_variation = &"EditorTree"
	palette_panel.add_child(palette)
	palette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var palette_root := palette.create_item()
	palette_root.set_text(0, "Placeables")

	var right_split := HSplitContainer.new()
	right_split.theme_type_variation = &"EditorHSplitContainer"
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_split.add_child(right_split)
	viewport_surface = Control.new()
	viewport_surface.name = "Viewport"
	viewport_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	viewport_surface.focus_mode = Control.FOCUS_ALL
	viewport_surface.clip_contents = true
	viewport_surface.gui_input.connect(_on_viewport_input)
	viewport_surface.draw.connect(func() -> void: viewport_draw.emit(viewport_surface))
	right_split.add_child(viewport_surface)
	var hint := Label.new()
	hint.text = "Click / drag · Ctrl/Shift select · Middle-drag pan · Wheel zoom"
	hint.theme_type_variation = &"EditorLabel"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_surface.add_child(hint)
	var inspector_frame := PanelContainer.new()
	inspector_frame.name = "Inspector"
	inspector_frame.theme_type_variation = &"EditorPanel"
	inspector_frame.custom_minimum_size.x = root.get_theme_constant(&"dock_width", &"EditorPanel")
	right_split.add_child(inspector_frame)
	inspector = Label.new()
	inspector.text = "INSPECTOR\nSelect a scene node."
	inspector.theme_type_variation = &"EditorLabel"
	inspector.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	inspector.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_frame.add_child(inspector)

	bottom_tabs = TabContainer.new()
	bottom_tabs.name = "BottomTabs"
	bottom_tabs.theme_type_variation = &"EditorTabContainer"
	bottom_tabs.custom_minimum_size.y = root.get_theme_constant(&"dock_height", &"EditorTabContainer")
	vertical.add_child(bottom_tabs)
	# A host panel whose title names one of the fixed bottom tabs (§4.5.5) takes that slot;
	# the rest follow in the order the host lists them.
	for panel_title: String in BOTTOM_TABS:
		var index := hosted.find_custom(
			func(candidate: WeftluminPanel) -> bool: return candidate.title == panel_title
		)
		if index < 0:
			_panel(panel_title, bottom_tabs)
		else:
			_mount(hosted.pop_at(index), bottom_tabs)
	for panel: WeftluminPanel in hosted:
		_mount(panel, bottom_tabs)
	bottom_tabs.tab_changed.connect(_on_tab_changed)
	_build_dock_splitter(vertical)


## #478: the VSplitContainer's own handle is the viewport / bottom-dock boundary. Its child
## minimums are the clamps (`dock_height` on both sides); it opens at the remembered height or
## the default share of the screen, and a double-click on the handle restores the default.
func _build_dock_splitter(vertical: VSplitContainer) -> void:
	dock_split = vertical
	_apply_dock_height(_preferred_dock_height())
	vertical.resized.connect(func() -> void: _apply_dock_height(_preferred_dock_height()))
	vertical.drag_started.connect(func() -> void: _drag_start_offset = vertical.split_offset)
	vertical.drag_ended.connect(_on_dock_drag_ended)
	vertical.get_drag_area_control().gui_input.connect(_on_dock_handle_input)


## The bottom dock's laid-out height.
func dock_height() -> float:
	return bottom_tabs.size.y


## About 30% of the screen, never below the bottom dock's minimum.
func default_dock_height() -> float:
	return maxf(roundf(root.size.y * DEFAULT_DOCK_FRACTION), bottom_tabs.get_combined_minimum_size().y)


## Resizes the bottom dock within its clamps and remembers it for the rest of the session.
func set_dock_height(height: float) -> void:
	_remembered_dock_height = _clamp_dock_height(height)
	_apply_dock_height(_remembered_dock_height)


## Returns the dock to the default height and forgets the remembered one.
func reset_dock_height() -> void:
	_remembered_dock_height = -1.0
	_apply_dock_height(default_dock_height())


func _preferred_dock_height() -> float:
	return _remembered_dock_height if _remembered_dock_height > 0.0 else default_dock_height()


## Smallest and largest bottom-dock heights: each side of the handle keeps its minimum size
## (`dock_height` for both the bottom tabs and the viewport side).
func dock_height_limits() -> Vector2:
	var low := bottom_tabs.get_combined_minimum_size().y
	var room := dock_split.size.y - float(dock_split.get_theme_constant(&"separation"))
	var high := room - (dock_split.get_child(0) as Control).get_combined_minimum_size().y
	return Vector2(low, maxf(low, high))


## With the viewport side expanding, the split offset counts up from the bottom edge: the bottom
## dock is `-split_offset` tall. Opening and resizing store the preferred height unclamped and let
## the container clamp the layout, since panel minimums settle a frame or two after the resize.
func _apply_dock_height(height: float) -> void:
	dock_split.split_offset = -roundi(height)


func _clamp_dock_height(height: float) -> float:
	if dock_split.size.y <= 0.0:
		return height
	var limits := dock_height_limits()
	return clampf(height, limits.x, limits.y)


func _clamped_dock_height() -> float:
	return _clamp_dock_height(float(-dock_split.split_offset))


func _on_dock_drag_ended() -> void:
	# A click without movement (including the first half of a double-click) leaves the size alone.
	if dock_split.split_offset != _drag_start_offset:
		_remembered_dock_height = _clamped_dock_height()


func _on_dock_handle_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed and button.double_click:
		reset_dock_height()
		# Handled here, so the handle does not also begin a drag from the reset position.
		dock_split.get_drag_area_control().accept_event()
	elif button.pressed:
		# Start the drag from the laid-out boundary, never from an offset the layout clamped.
		dock_split.split_offset = -roundi(dock_height())


func _instantiate_host_panels() -> Array[WeftluminPanel]:
	var hosted: Array[WeftluminPanel] = []
	for packed: PackedScene in adapter.panels():
		var instance: Node = packed.instantiate()
		var panel := instance as WeftluminPanel
		if panel == null:
			push_warning("Weftlumin panels must implement WeftluminPanel.")
			instance.free()
			continue
		hosted.append(panel)
	return hosted


func _build_scene_tree(tree_panel: WeftluminPanel) -> void:
	scene_tree = Tree.new()
	scene_tree.theme_type_variation = &"EditorTree"
	tree_panel.add_child(scene_tree)
	scene_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scene_root: Node = adapter.gameplay_scene_root()
	if scene_root != null:
		_append_scene_node(scene_root, null)
	scene_tree.item_selected.connect(_on_scene_selected)


func _mount(panel: WeftluminPanel, tabs: TabContainer) -> void:
	panel.name = panel.title
	tabs.add_child(panel)
	panel.configure(self)


func _panel(panel_title: String, tabs: TabContainer) -> WeftluminPanel:
	var panel := WeftluminPanel.new()
	panel.title = panel_title
	_mount(panel, tabs)
	return panel


func _append_scene_node(node: Node, parent_item: TreeItem) -> void:
	var item := scene_tree.create_item(parent_item)
	item.set_text(0, String(node.name))
	item.set_metadata(0, weakref(node))
	item.collapsed = parent_item != null
	for child: Node in node.get_children():
		_append_scene_node(child, item)


func _on_scene_selected() -> void:
	var item := scene_tree.get_selected()
	var reference: WeakRef = item.get_metadata(0)
	var node := reference.get_ref() as Node
	if node != null:
		inspector.text = "INSPECTOR\n%s\n%s" % [node.name, node.get_class()]


func _open_camera() -> void:
	_previous_camera = get_viewport().get_camera_2d()
	_previous_canvas_transform = get_viewport().canvas_transform
	camera = Camera2D.new()
	camera.name = "FreeCamera"
	root.add_child(camera)
	camera.set_as_top_level(true)
	if is_instance_valid(_previous_camera):
		camera.position = _previous_camera.get_screen_center_position()
		camera.zoom = _previous_camera.zoom
	camera.make_current()
	camera.force_update_scroll()


func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventKey:
		viewport_shortcut.emit(event as InputEventKey)
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			viewport_surface.grab_focus()
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = button.pressed
		elif button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP
			camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	elif event is InputEventMouseMotion and _panning:
		camera.position -= (event as InputEventMouseMotion).relative / camera.zoom
	camera.force_update_scroll()
	if event is InputEventMouse and not _panning:
		var position: Vector2 = (event as InputEventMouse).position
		if Rect2(Vector2.ZERO, viewport_surface.size).has_point(position):
			viewport_input.emit(event, viewport_to_world(position))
	viewport_surface.queue_redraw()
	viewport_surface.accept_event()


func viewport_to_world(position: Vector2) -> Vector2:
	var screen: Vector2 = viewport_surface.get_global_transform_with_canvas() * position
	return get_viewport().canvas_transform.affine_inverse() * screen


func production_owner_live() -> bool:
	return adapter.production_owner_live()


## Authoring never runs inside a replay sandbox. Other tools retain their own ownership.
func activate_panel(panel: WeftluminPanel) -> bool:
	var sandbox := WeftluminSandbox.shared()
	if sandbox.is_armed() and (
		_sandbox_panel == null or sandbox.owner() != _sandbox_token(_sandbox_panel)
	):
		push_warning("Weftlumin: end the sandbox held by %s first." % sandbox.owner())
		return false
	if panel.needs_sandbox and _sandbox_panel == null and production_owner_live():
		push_warning("Weftlumin: end the production battle or dialogue before starting a sandbox.")
		return false
	if panel != _sandbox_panel:
		_end_owned_sandbox()
	if panel.needs_sandbox and _sandbox_panel == null:
		var result: Dictionary = sandbox.arm(_sandbox_token(panel))
		if not bool(result.get("allowed", false)):
			push_warning(String(result.get("message", "Sandbox refused.")))
			return false
		_sandbox_panel = panel
	panel.refresh({"scene_root": adapter.gameplay_scene_root()})
	return true


func _on_tab_changed(index: int) -> void:
	var panel := bottom_tabs.get_tab_control(index) as WeftluminPanel
	if activate_panel(panel):
		_selected_tab = index
	else:
		bottom_tabs.set_current_tab(_selected_tab)


## Owner token the shell arms the shared sandbox under for `panel`. A sandbox panel hands it to
## its model so the model's own session restarts under the holder rather than competing with it.
func sandbox_token(panel: WeftluminPanel) -> StringName:
	return _sandbox_token(panel)


func _sandbox_token(panel: WeftluminPanel) -> StringName:
	return StringName("weftlumin:%d" % panel.get_instance_id())


func _end_owned_sandbox() -> void:
	if _sandbox_panel == null:
		return
	var sandbox := WeftluminSandbox.shared()
	if sandbox.is_armed() and sandbox.owner() == _sandbox_token(_sandbox_panel):
		_abandon_sandbox_session()
		var result: Dictionary = sandbox.disarm()
		if not bool(result.get("allowed", false)):
			push_warning(String(result.get("message", "Sandbox restore failed.")))
	_sandbox_panel = null


func _abandon_sandbox_session() -> void:
	pass
