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

var adapter: WeftluminGameAdapter
var root: Control
var camera: Camera2D
var viewport_surface: Control
var bottom_tabs: TabContainer
var scene_tree: Tree
var inspector: Label
var _previous_camera: Camera2D
var _previous_canvas_transform: Transform2D
var _previous_focus: Control
var _sandbox_panel: WeftluminPanel
var _opened := false
var _panning := false
var _selected_tab := 0


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
