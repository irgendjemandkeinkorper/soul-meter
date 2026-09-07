extends Control
## In-game layout editing surface. Configured with a gameplay scene by LayoutMode.

const LayoutOverridesScript := preload("res://globals/layout_overrides.gd")
const LayoutSession := preload("res://ui/debug/layout_session.gd")
const LayoutRecovery := preload("res://globals/layout_recovery.gd")
const LayoutPatterns := preload("res://globals/layout_patterns.gd")
const DRESSING_LAYERS := [&"GroundDetails", &"SoftDetails", &"SolidProps"]

## Every generated sprite root the editor can place from, grouped the way the art is actually
## organised on disk. Before this the palette scanned `world/` only and showed 97 of roughly
## 800 assets as one flat list, which made most of the art unreachable from inside the game.
##
## There is deliberately no "Enemies" category: enemy art is not separable from NPC or
## companion art by directory — everything lives side by side under `units/<unit-id>/`. Which
## of those is an enemy is EncounterCatalog data, not a folder, so inventing the folder here
## would be a lie the search box already solves ("wight", "gnaal", "boar").
const PALETTE_CATEGORIES := [
	{"label": "Town (fantasy kit)", "roots": ["res://assets/generated/sprites/fantasy-town-kit/"]},
	{"label": "Castle", "roots": ["res://assets/generated/sprites/castle-kit/"]},
	{"label": "Nature", "roots": ["res://assets/generated/sprites/nature-kit/"]},
	{"label": "Terrain & ground", "roots": [
		"res://assets/generated/sprites/terrain/", "res://assets/generated/sprites/ground/",
	]},
	{"label": "World objects", "roots": ["res://assets/generated/sprites/world/objects/"]},
	{"label": "World locations", "roots": ["res://assets/generated/sprites/world/"]},
	{"label": "Units & NPCs", "roots": ["res://assets/generated/sprites/units/"]},
	{"label": "Mini characters", "roots": ["res://assets/generated/sprites/mini-characters/"]},
	{"label": "Items", "roots": ["res://assets/generated/sprites/items/"]},
]
## Icons are loaded eagerly, so an unfiltered "All" over ~800 textures would stall the frame
## F10 opens on. The search box is the intended way to reach past this; the count label says
## when it is truncating. PROVISIONAL owner surface.
const PALETTE_RESULT_LIMIT := 240
# PROVISIONAL owner surface: tune after hands-on map-editing review.
const SNAP_GRID := 8.0
# PROVISIONAL owner surface: tune per the common prop footprint review.
const DEFAULT_COLLISION_SIZE := Vector2(64.0, 24.0)
# NOT provisional: the interior dressing contract's SolidProps footprint cap
# (test_building_interiors.gd MAX_SOLID_PROP_FOOTPRINT_SIZE) — palette output
# must always conform.
const MAX_FOOTPRINT := Vector2(120.0, 48.0)
# PROVISIONAL owner surface: selection forgiveness for markers and small props.
const PICK_PADDING := 8.0

@onready var _layer_picker: OptionButton = %LayerPicker
@onready var _footprint_width: SpinBox = %FootprintWidth
@onready var _footprint_height: SpinBox = %FootprintHeight
@onready var _palette: ItemList = %Palette
@onready var _scene_status: Label = %SceneStatus
@onready var _selection_status: Label = %SelectionStatus
@onready var _unsaved_status: Label = %UnsavedStatus
@onready var _inspector: PanelContainer = $PalettePanel
@onready var _footprint_hint: Label = %FootprintHint
@onready var _palette_category: OptionButton = %PaletteCategory
@onready var _palette_search: LineEdit = %PaletteSearch
@onready var _pattern_name: LineEdit = %PatternName
@onready var _pattern_save: Button = %PatternSave
@onready var _pattern_list: ItemList = %PatternList
@onready var _pattern_hint: Label = %PatternHint

var _scene_root: Node = null
var _scene_path: String = ""
var _document: Dictionary = {}
## The PRIMARY selection: the node the inspector, footprint spinboxes and Duplicate act on.
## Always the last node added to `_selection`, and always present in it when non-null. Keeping
## a distinguished primary is what lets single-target commands stay single-target while move,
## delete, nudge and Ctrl+G act on the whole group.
var _selected: Node2D = null
var _selection: Array[Node2D] = []
var _selected_texture_path: String = ""
var _selected_pattern: Dictionary = {}
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
## node -> grab offset, so a multi-node drag moves the group rigidly instead of collapsing it
## onto the cursor.
var _drag_offsets: Dictionary = {}
var _drag_befores: Dictionary = {}
var _dirty_keys: Dictionary = {}
var _session: Node
var _drag_before: Dictionary = {}
var _drag_document: Dictionary = {}
var _message: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	for layer_name: StringName in DRESSING_LAYERS:
		_layer_picker.add_item(String(layer_name))
	_footprint_width.value = DEFAULT_COLLISION_SIZE.x
	_footprint_height.value = DEFAULT_COLLISION_SIZE.y
	_palette.item_selected.connect(_on_palette_item_selected)
	_inspector.properties_changed.connect(_apply_selected_properties)
	_inspector.command_requested.connect(_run_command)
	_footprint_width.value_changed.connect(_change_footprint.bind(0))
	_footprint_height.value_changed.connect(_change_footprint.bind(1))
	_layer_picker.item_selected.connect(func(_index: int) -> void: _refresh_status())
	%Save.pressed.connect(_save_overrides)
	for category: Dictionary in PALETTE_CATEGORIES:
		_palette_category.add_item(str(category["label"]))
	_palette_category.item_selected.connect(func(_index: int) -> void: _populate_palette())
	_palette_search.text_changed.connect(func(_text: String) -> void: _populate_palette())
	_pattern_save.pressed.connect(_save_selection_as_pattern)
	_pattern_list.item_selected.connect(_on_pattern_item_selected)
	_populate_palette()
	_refresh_pattern_list()
	_refresh_status()


func configure(scene_root: Node) -> void:
	_scene_root = scene_root
	_scene_path = scene_root.scene_file_path if scene_root != null else ""
	_session = scene_root.get_node_or_null("_LayoutSession")
	if _session == null:
		var restored: Dictionary = LayoutRecovery.load_scene(_scene_path)
		_session = LayoutSession.new()
		_session.name = "_LayoutSession"
		scene_root.add_child(_session)
		_session.initialize(restored["saved"], restored["working"])
		if restored["recovered"]:
			_message = "Recovered unsaved changes from the previous session."
	_document = _session.document
	_session.changed.connect(_refresh_status)
	if _session.panel_position.is_finite():
		_inspector.set("_initial_placement", false)
		_inspector.position = _session.panel_position
	_refresh_status()
	queue_redraw()


func _exit_tree() -> void:
	_finish_drag()
	if is_instance_valid(_session):
		_session.panel_position = _inspector.position


func _finish_drag() -> void:
	if _dragging and is_instance_valid(_session):
		var entries: Array = []
		for node: Variant in _drag_befores:
			if is_instance_valid(node):
				entries.append({"node": node, "before": _drag_befores[node]})
		if not entries.is_empty():
			# One undo step for the whole group, per the editor's "a drag is one undo step".
			_session.record_many("Move", entries, _drag_document)
	_dragging = false
	_drag_before = {}
	_drag_befores.clear()
	_drag_offsets.clear()
	_drag_document = {}


func _process(_delta: float) -> void:
	if _prune_selection():
		_refresh_status()
	queue_redraw()


## Gameplay can free a selected actor while F10 is open. Returns true when anything was
## dropped, so the caller can refresh rather than redrawing a dangling outline.
func _prune_selection() -> bool:
	var removed := false
	for index in range(_selection.size() - 1, -1, -1):
		if not is_instance_valid(_selection[index]):
			_selection.remove_at(index)
			removed = true
	if _selected != null and not is_instance_valid(_selected):
		_selected = null
		removed = true
	if _selected == null and not _selection.is_empty():
		_selected = _selection.back()
	return removed


## The group the multi-node commands act on. `_selected` can be assigned directly — by a test
## fixture, or by any single-target path that predates multi-select — so an empty `_selection`
## with a live primary means "a group of one", not "nothing selected". Reading through here
## keeps the two representations from ever disagreeing.
func _active_selection() -> Array[Node2D]:
	var active: Array[Node2D] = []
	for node: Node2D in _selection:
		if is_instance_valid(node):
			active.append(node)
	if active.is_empty() and is_instance_valid(_selected):
		active.append(_selected)
	return active


func _select_only(node: Node2D) -> void:
	_selection.clear()
	if node != null:
		_selection.append(node)
	_selected = node


## Shift+click semantics: an unselected node joins the group, a selected one leaves it. The
## primary follows the most recent addition so the inspector always reflects the last thing
## touched.
func _toggle_selection(node: Node2D) -> void:
	if node == null:
		return
	var index := _selection.find(node)
	if index >= 0:
		_selection.remove_at(index)
		_selected = _selection.back() if not _selection.is_empty() else null
		return
	_selection.append(node)
	_selected = node


func _draw() -> void:
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	# Secondary members of the group get a dimmer outline, so "what will move" and "what the
	# inspector is editing" stay visually distinct.
	for node: Node2D in _selection:
		if node == _selected or not is_instance_valid(node):
			continue
		var bounds: Rect2 = _editable_bounds(node)
		var corner: Vector2 = canvas_transform * bounds.position
		var far: Vector2 = canvas_transform * bounds.end
		draw_rect(Rect2(corner, far - corner).abs().grow(2.0), Color(1.0, 0.75, 0.18, 0.45), false, 2.0)
	if _selected == null or not is_instance_valid(_selected):
		return
	var world_bounds: Rect2 = _editable_bounds(_selected)
	var top_left: Vector2 = canvas_transform * world_bounds.position
	var bottom_right: Vector2 = canvas_transform * world_bounds.end
	var screen_rect := Rect2(top_left, bottom_right - top_left).abs()
	draw_rect(screen_rect.grow(2.0), Color(1.0, 0.75, 0.18, 1.0), false, 2.0)
	var collision: CollisionShape2D = _selected_solid_collision()
	if collision != null:
		var half_size: Vector2 = (collision.shape as RectangleShape2D).size / 2.0
		var points := PackedVector2Array()
		for corner: Vector2 in [-half_size, Vector2(half_size.x, -half_size.y), half_size, Vector2(-half_size.x, half_size.y)]:
			points.append(canvas_transform * (collision.global_transform * corner))
		draw_colored_polygon(points, Color(0.2, 0.9, 1.0, 0.15))
		points.append(points[0])
		draw_polyline(points, Color(0.2, 0.9, 1.0), 2.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if _scene_root == null:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# Right-click cancels a pending palette placement (gate r1 finding 4).
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_palette_selection()
		get_viewport().set_input_as_handled()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		_finish_drag()
		return
	# GUI fields retain focus on clicks through an IGNORE root; return keys to the map.
	get_viewport().gui_release_focus()
	var world_position: Vector2 = _screen_to_world(event.position)
	if not _selected_pattern.is_empty():
		_stamp_pattern(world_position, event.alt_pressed, event.shift_pressed)
		get_viewport().set_input_as_handled()
		return
	if not _selected_texture_path.is_empty():
		_place_palette_prop(world_position, event.alt_pressed, event.shift_pressed)
		get_viewport().set_input_as_handled()
		return
	_finish_drag()
	var picked: Node2D = _pick_editable(world_position)
	if event.shift_pressed:
		# Additive pick. Deliberately does NOT begin a drag: Shift already means "no snap"
		# while the mouse is moving, and one modifier cannot mean both at once on one gesture.
		_toggle_selection(picked)
		_refresh_status()
		get_viewport().set_input_as_handled()
		return
	if picked == null:
		_select_only(null)
	elif not _selection.has(picked):
		_select_only(picked)
	else:
		# Clicking a node that is already in the group keeps the group and drags all of it.
		_selected = picked
	_begin_drag(world_position)
	_refresh_status()
	get_viewport().set_input_as_handled()


func _begin_drag(world_position: Vector2) -> void:
	_drag_offsets.clear()
	_drag_befores.clear()
	var targets: Array[Node2D] = _active_selection()
	_dragging = not targets.is_empty()
	if not _dragging:
		return
	for node: Node2D in targets:
		_drag_offsets[node] = node.global_position - world_position
		_drag_befores[node] = _session.capture(node)
	_drag_offset = _drag_offsets.get(_selected, Vector2.ZERO)
	_drag_before = _drag_befores.get(_selected, {})
	_drag_document = _document.duplicate(true)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_finish_drag()
	if not _dragging or _drag_offsets.is_empty():
		return
	# The primary decides the snap, and every other member keeps its offset from it, so a
	# snapped group drag preserves the group's internal spacing exactly.
	var cursor: Vector2 = _screen_to_world(event.position)
	var primary_destination: Vector2 = cursor + _drag_offset
	if not event.shift_pressed:
		primary_destination = _snapped(primary_destination)
	var applied_delta: Vector2 = primary_destination - (cursor + _drag_offset)
	for node: Variant in _drag_offsets:
		if not is_instance_valid(node):
			continue
		(node as Node2D).global_position = cursor + _drag_offsets[node] + applied_delta
		_record_transform(node as Node2D)
	_refresh_status()
	get_viewport().set_input_as_handled()


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if key == KEY_F10:
		return # The host owns the exit toggle.
	if get_viewport().gui_get_focus_owner() is LineEdit:
		# Native text editing has already seen this unhandled event. Do not leak it to gameplay.
		if key == KEY_S and event.ctrl_pressed:
			_save_overrides()
		elif key == KEY_G and event.ctrl_pressed:
			# Reachable while the pattern-name field still has focus, which is exactly where
			# the cursor is after typing a name.
			_save_selection_as_pattern()
		get_viewport().set_input_as_handled()
		return
	match key:
		KEY_ESCAPE:
			_cancel_palette_selection()
		KEY_DELETE:
			_delete_selected()
		KEY_D:
			if event.ctrl_pressed:
				_duplicate_selected()
		KEY_G:
			if event.ctrl_pressed:
				_save_selection_as_pattern()
		KEY_LEFT:
			_nudge_selected(Vector2.LEFT)
		KEY_RIGHT:
			_nudge_selected(Vector2.RIGHT)
		KEY_UP:
			_nudge_selected(Vector2.UP)
		KEY_DOWN:
			_nudge_selected(Vector2.DOWN)
		KEY_S:
			_save_overrides()
		KEY_Z:
			if event.ctrl_pressed:
				if event.shift_pressed:
					_redo()
				else:
					_undo()
		KEY_Y:
			if event.ctrl_pressed:
				_redo()
	# Unknown keys must not reach always-processing inventory/party/journal menus.
	get_viewport().set_input_as_handled()


func _pick_editable(world_position: Vector2) -> Node2D:
	var candidates: Array[Node2D] = []
	_collect_editable(_scene_root, candidates)
	var picked: Node2D = null
	var picked_area := INF
	for candidate: Node2D in candidates:
		var bounds: Rect2 = _editable_bounds(candidate).grow(PICK_PADDING)
		if not bounds.has_point(world_position):
			continue
		var area: float = bounds.size.x * bounds.size.y
		# Smallest hit wins so a prop inside a big backdrop is reachable; on a tie the LAST
		# candidate wins, which is the one drawn on top — a click picks what you can see.
		if area <= picked_area:
			picked = candidate
			picked_area = area
	return picked


func _collect_editable(node: Node, output: Array[Node2D]) -> void:
	for child: Node in node.get_children():
		if child is Node2D and _is_editable(child):
			output.append(child as Node2D)
		_collect_editable(child, output)


func _is_editable(node: Node) -> bool:
	var parent: Node = node.get_parent()
	if parent != null and DRESSING_LAYERS.has(parent.name):
		return true
	if node is NPC or node is BuildingDoor or node is TravelExit:
		return true
	if node is Marker2D:
		var marker_name: String = String(node.name)
		return marker_name.begins_with("Spawn") or "Anchor" in marker_name \
			or node.name == &"VendorSpot" or node.name == &"NpcSpot"
	if node is Sprite2D:
		var sprite := node as Sprite2D
		return sprite.texture != null and "building-facade" in sprite.texture.resource_path
	return false


func _editable_bounds(node: Node2D) -> Rect2:
	if node is Sprite2D:
		return _sprite_world_bounds(node as Sprite2D)
	var sprite: Sprite2D = _first_sprite(node)
	if sprite != null:
		return _sprite_world_bounds(sprite)
	return Rect2(node.global_position - Vector2(12.0, 12.0), Vector2(24.0, 24.0))


func _sprite_world_bounds(sprite: Sprite2D) -> Rect2:
	var local_rect: Rect2 = sprite.get_rect()
	var corners := PackedVector2Array([
		sprite.global_transform * local_rect.position,
		sprite.global_transform * Vector2(local_rect.end.x, local_rect.position.y),
		sprite.global_transform * local_rect.end,
		sprite.global_transform * Vector2(local_rect.position.x, local_rect.end.y),
	])
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for index: int in range(1, corners.size()):
		bounds = bounds.expand(corners[index])
	return bounds


func _place_palette_prop(world_position: Vector2, free_move: bool, keep_placing: bool = false) -> void:
	_finish_drag()
	var previous_document: Dictionary = _document.duplicate(true)
	var layer_name := StringName(_layer_picker.get_item_text(_layer_picker.selected))
	var layer: Node2D = _find_layer(layer_name)
	if layer == null:
		push_warning("Layout editor cannot place a prop: layer %s is missing." % layer_name)
		return
	var prop_name: StringName = _unique_prop_name(layer, _selected_texture_path)
	var local_position: Vector2 = layer.to_local(world_position)
	if not free_move:
		local_position = _snapped(local_position)
	# Clamp to the interior SolidProps footprint cap (gate r1 finding 3): the
	# spinboxes are capped in the scene too, but the contract must hold even
	# if the .tscn limits drift.
	var footprint := Vector2(
		minf(_footprint_width.value, MAX_FOOTPRINT.x),
		minf(_footprint_height.value, MAX_FOOTPRINT.y)
	)
	var addition := {
		"layer": String(layer_name),
		"texture": _selected_texture_path,
		"name": String(prop_name),
		"position": [local_position.x, local_position.y],
		"scale": [1.0, 1.0],
		"collision": [footprint.x, footprint.y],
	}
	var addition_document: Dictionary = LayoutOverridesScript.create_document(_scene_path)
	addition_document["additions"] = [addition]
	var summary: Dictionary = LayoutOverridesScript.apply_to_scene(_scene_root, addition_document)
	if int(summary["additions_applied"]) != 1:
		return
	var additions: Array = _document["additions"] as Array
	additions.append(addition)
	_select_only(layer.get_node_or_null(NodePath(String(prop_name))) as Node2D)
	# Shift keeps the brush active; a normal click returns to selection.
	if not keep_placing:
		_cancel_palette_selection()
	_mark_dirty("add:%s/%s" % [layer_name, prop_name])
	_session.record("Place", _selected, {}, previous_document)
	_refresh_status()


func _delete_selected() -> void:
	var targets: Array[Node2D] = _active_selection()
	if targets.is_empty():
		return
	_finish_drag()
	var previous_document: Dictionary = _document.duplicate(true)
	var entries: Array = []
	for target: Node2D in targets:
		if not is_instance_valid(target):
			continue
		entries.append({"node": target, "before": _session.capture(target)})
		var path: String = String(_scene_root.get_path_to(target))
		if target.has_meta("layout_addition"):
			_remove_addition(target)
			_mark_dirty("add:%s" % path)
		else:
			var deletions: Array = _document["deletions"] as Array
			if not deletions.has(path):
				deletions.append(path)
			_remove_edit(path)
			_mark_dirty("delete:%s" % path)
		var parent: Node = target.get_parent()
		if parent != null:
			parent.remove_child(target)
	_select_only(null)
	if not entries.is_empty():
		_session.record_many("Delete", entries, previous_document)
	_refresh_status()


func _duplicate_selected() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	_finish_drag()
	var previous_document: Dictionary = _document.duplicate(true)
	var parent: Node = _selected.get_parent()
	if parent == null or not DRESSING_LAYERS.has(parent.name):
		return
	if not LayoutOverridesScript.supports_addition(_selected, StringName(parent.name)):
		_message = "Cannot duplicate this compound or scripted asset safely."
		_refresh_status()
		return
	var duplicate_node: Node = _selected.duplicate()
	if not duplicate_node is Node2D:
		duplicate_node.free()
		return
	var duplicate_2d := duplicate_node as Node2D
	duplicate_2d.name = _unique_name(parent, "%sCopy" % _selected.name)
	parent.add_child(duplicate_2d)
	duplicate_2d.position += Vector2(SNAP_GRID, SNAP_GRID)
	var addition: Dictionary = _addition_from_node(duplicate_2d, StringName(parent.name))
	if addition.is_empty():
		parent.remove_child(duplicate_2d)
		duplicate_2d.free()
		return
	duplicate_2d.set_meta("layout_addition", addition.duplicate(true))
	var additions: Array = _document["additions"] as Array
	additions.append(addition)
	_select_only(duplicate_2d)
	_mark_dirty("add:%s/%s" % [parent.name, duplicate_2d.name])
	_session.record("Duplicate", duplicate_2d, {}, previous_document)
	_refresh_status()


func _nudge_selected(delta: Vector2) -> void:
	var targets: Array[Node2D] = _active_selection()
	if targets.is_empty():
		return
	_finish_drag()
	var previous_document: Dictionary = _document.duplicate(true)
	var entries: Array = []
	for node: Node2D in targets:
		if not is_instance_valid(node):
			continue
		entries.append({"node": node, "before": _session.capture(node)})
		node.position += delta
		_record_transform(node)
	if not entries.is_empty():
		_session.record_many("Nudge", entries, previous_document)
	_refresh_status()


func _record_selected_transform() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	_record_transform(_selected)
	_refresh_status()


func _record_transform(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta("layout_addition"):
		_update_addition(node)
		var layer: Node = node.get_parent()
		_mark_dirty("add:%s/%s" % [layer.name if layer != null else "", node.name])
	else:
		var path: String = String(_scene_root.get_path_to(node))
		var edit: Dictionary = LayoutOverridesScript.capture_properties(node)
		edit["path"] = path
		_upsert_edit(edit)
		_mark_dirty("edit:%s" % path)


func _upsert_edit(edit: Dictionary) -> void:
	var edits: Array = _document["edits"] as Array
	for index: int in range(edits.size()):
		var existing: Dictionary = edits[index] as Dictionary
		if str(existing.get("path", "")) == str(edit["path"]):
			edits[index] = edit
			return
	edits.append(edit)


func _remove_edit(path: String) -> void:
	var edits: Array = _document["edits"] as Array
	for index: int in range(edits.size() - 1, -1, -1):
		var edit: Dictionary = edits[index] as Dictionary
		if str(edit.get("path", "")) == path:
			edits.remove_at(index)


func _update_addition(node: Node2D) -> void:
	var parent: Node = node.get_parent()
	if parent == null:
		return
	var additions: Array = _document["additions"] as Array
	for index: int in range(additions.size()):
		var addition: Dictionary = additions[index] as Dictionary
		if str(addition.get("layer", "")) != String(parent.name):
			continue
		if str(addition.get("name", "")) != String(node.name):
			continue
		addition.merge(LayoutOverridesScript.capture_properties(node), true)
		additions[index] = addition
		node.set_meta("layout_addition", addition.duplicate(true))
		return


func _remove_addition(node: Node2D) -> void:
	var parent: Node = node.get_parent()
	if parent == null:
		return
	var additions: Array = _document["additions"] as Array
	for index: int in range(additions.size() - 1, -1, -1):
		var addition: Dictionary = additions[index] as Dictionary
		if str(addition.get("layer", "")) == String(parent.name) \
			and str(addition.get("name", "")) == String(node.name):
			additions.remove_at(index)


func _addition_from_node(node: Node2D, layer_name: StringName) -> Dictionary:
	return LayoutOverridesScript.capture_addition(node, layer_name)


func _apply_selected_properties(values: Dictionary) -> void:
	if not is_instance_valid(_selected):
		return
	_finish_drag()
	var before: Dictionary = _session.capture(_selected)
	var previous_document: Dictionary = _document.duplicate(true)
	LayoutOverridesScript.apply_properties(_selected, values)
	if before["properties"] == LayoutOverridesScript.capture_properties(_selected):
		return
	_record_selected_transform()
	_session.record("Edit property", _selected, before, previous_document)


func _undo() -> void:
	_finish_drag()
	if is_instance_valid(_session) and _session.history.has_undo():
		_session.history.undo()
	_refresh_status()


func _redo() -> void:
	_finish_drag()
	if is_instance_valid(_session) and _session.history.has_redo():
		_session.history.redo()
	_refresh_status()


func _run_command(command: String) -> void:
	match command:
		"undo": _undo()
		"redo": _redo()
		"duplicate": _duplicate_selected()
		"delete": _delete_selected()


func _selected_solid_collision() -> CollisionShape2D:
	if not is_instance_valid(_selected) or not _selected is StaticBody2D:
		return null
	var layer: Node = _selected.get_parent()
	if layer == null or layer.name != &"SolidProps":
		return null
	var collision: CollisionShape2D = LayoutOverridesScript.find_collision(_selected)
	return collision if collision != null and collision.shape is RectangleShape2D else null


func _change_footprint(value: float, axis: int) -> void:
	var collision := _selected_solid_collision()
	if collision != null and _selected_texture_path.is_empty():
		var dimensions: Vector2 = collision.shape.size
		dimensions[axis] = value
		_apply_selected_properties({"collision": [dimensions.x, dimensions.y]})


func _first_sprite(node: Node) -> Sprite2D:
	for child: Node in node.get_children():
		if child is Sprite2D:
			return child as Sprite2D
		var nested: Sprite2D = _first_sprite(child)
		if nested != null:
			return nested
	return null


func _save_overrides() -> void:
	commit_pending_input()
	_finish_drag()
	var path: String = LayoutOverridesScript.override_path_for_scene(_scene_path)
	var save_error: Error = LayoutOverridesScript.save_file(path, _document)
	if save_error == OK:
		_dirty_keys.clear()
		_session.mark_saved()
		_message = "Saved scratch changes."
	else:
		_message = "Save failed: %s. Changes are still unsaved." % error_string(save_error)
		push_warning("Layout editor failed to save %s: %s" % [path, error_string(save_error)])
	_refresh_status()


func commit_pending_input() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit and is_ancestor_of(focused) and focused.get_parent() is SpinBox:
		(focused.get_parent() as SpinBox).apply()


## Rebuilds the palette for the current category and search text. Fuzzy matching runs over the
## path relative to the category root, not just the file name, so "dom door" finds
## `world/objects/dom-door-wood--closed.png` and "loam" finds everything in that location's
## folder without the author having to know the folder layout.
func _populate_palette() -> void:
	_palette.clear()
	var category: Dictionary = PALETTE_CATEGORIES[
		clampi(_palette_category.selected, 0, PALETTE_CATEGORIES.size() - 1)
	]
	var paths: Array[String] = []
	var seen: Dictionary = {}
	for root_path: String in category["roots"] as Array:
		_scan_palette_directory(root_path, paths, seen)
	var query: String = _palette_search.text.strip_edges()
	var scored: Array = []
	for texture_path: String in paths:
		var haystack: String = texture_path.trim_prefix("res://assets/generated/sprites/")
		var score: int = LayoutPatterns.fuzzy_score(query, haystack)
		if score < 0:
			continue
		scored.append({"path": texture_path, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) < int(b["score"])
		return str(a["path"]) < str(b["path"])
	)
	var shown: int = mini(scored.size(), PALETTE_RESULT_LIMIT)
	for rank in shown:
		var texture_path: String = str(scored[rank]["path"])
		var texture: Texture2D = load(texture_path) as Texture2D
		if texture == null:
			continue
		var index: int = _palette.add_item(texture_path.get_file().get_basename(), texture)
		_palette.set_item_metadata(index, texture_path)
		_palette.set_item_tooltip(index, texture_path)
	_palette_search.placeholder_text = (
		"Search %d assets" % scored.size()
		if shown >= scored.size()
		else "Showing %d of %d — keep typing" % [shown, scored.size()]
	)


func _scan_palette_directory(path: String, output: Array[String], seen: Dictionary) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var entry_path: String = path.path_join(entry)
		if directory.current_is_dir():
			if entry != "." and entry != "..":
				_scan_palette_directory(entry_path, output, seen)
		elif entry.get_extension().to_lower() == "png" and not seen.has(entry_path):
			seen[entry_path] = true
			output.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()


func _on_palette_item_selected(index: int) -> void:
	_finish_drag()
	_selected_texture_path = str(_palette.get_item_metadata(index))
	_palette.tooltip_text = "Place: %s" % _selected_texture_path
	_selected_pattern = {}
	_pattern_list.deselect_all()
	_select_only(null)
	_refresh_status()


## Leave placement mode and return to select/drag (Esc, right-click, or after
## a placement lands).
func _cancel_palette_selection() -> void:
	_selected_texture_path = ""
	_selected_pattern = {}
	_palette.deselect_all()
	_pattern_list.deselect_all()
	_palette.tooltip_text = ""
	_refresh_status()


# ---- pattern library ----


## Ctrl+G. Saves the current selection as a reusable pattern under the name in the field.
## Re-saving under an existing name overwrites that pattern, which is how a group is edited:
## stamp it, rearrange it, select it again, and save it back over the same name.
func _save_selection_as_pattern() -> void:
	_finish_drag()
	var targets: Array[Node2D] = _active_selection()
	if targets.is_empty():
		_message = "Select something first, then Ctrl+G."
		_refresh_status()
		return
	var result: Dictionary = LayoutPatterns.capture(targets, _pattern_name.text)
	if not bool(result.get("allowed", false)):
		_message = str(result.get("message", "That selection cannot be saved as a pattern."))
		_refresh_status()
		return
	var pattern: Dictionary = result["pattern"]
	var path: String = LayoutPatterns.pattern_path_for_id(StringName(str(pattern["id"])))
	var existed: bool = FileAccess.file_exists(path)
	var error: Error = LayoutPatterns.save_file(path, pattern)
	if error != OK:
		_message = "Pattern could not be saved (error %d)." % error
		_refresh_status()
		return
	var refused: Array = result.get("refused", [])
	_message = "%s pattern '%s' (%d props)%s" % [
		"Updated" if existed else "Saved",
		str(pattern["name"]),
		(pattern["nodes"] as Array).size(),
		"; skipped %s" % ", ".join(refused) if not refused.is_empty() else "",
	]
	_pattern_name.text = ""
	_refresh_pattern_list()
	_refresh_status()


func _refresh_pattern_list() -> void:
	_pattern_list.clear()
	var patterns: Array[Dictionary] = LayoutPatterns.list_patterns()
	for pattern: Dictionary in patterns:
		var index: int = _pattern_list.add_item(
			"%s (%d)" % [str(pattern["name"]), (pattern["nodes"] as Array).size()]
		)
		_pattern_list.set_item_metadata(index, pattern)
	_pattern_hint.text = (
		"Shift+click to multi-select, then Ctrl+G."
		if patterns.is_empty()
		else "%d saved. Click one, then click the map to stamp it." % patterns.size()
	)


func _on_pattern_item_selected(index: int) -> void:
	_finish_drag()
	_selected_texture_path = ""
	_palette.deselect_all()
	_selected_pattern = _pattern_list.get_item_metadata(index) as Dictionary
	_select_only(null)
	_refresh_status()


## Stamps the chosen pattern as a group of additions, in one undo step.
func _stamp_pattern(world_position: Vector2, free_move: bool, keep_placing: bool) -> void:
	_finish_drag()
	var previous_document: Dictionary = _document.duplicate(true)
	var result: Dictionary = LayoutPatterns.stamp(
		_selected_pattern,
		world_position,
		func(layer_name: StringName) -> Node2D: return _find_layer(layer_name),
		func(layer: Node2D, texture_path: String, reserved: PackedStringArray) -> String:
			return String(_unique_prop_name(layer, texture_path, reserved)),
		0.0 if free_move else SNAP_GRID,
	)
	if not bool(result.get("allowed", false)):
		_message = str(result.get("message", "That pattern could not be stamped here."))
		_refresh_status()
		return
	var additions: Array = result["additions"]
	var stamp_document: Dictionary = LayoutOverridesScript.create_document(_scene_path)
	stamp_document["additions"] = additions
	var summary: Dictionary = LayoutOverridesScript.apply_to_scene(_scene_root, stamp_document)
	if int(summary["additions_applied"]) != additions.size():
		_message = "Pattern stamped only %d of %d props." % [
			int(summary["additions_applied"]), additions.size()
		]
	var document_additions: Array = _document["additions"] as Array
	var placed: Array[Node2D] = []
	var entries: Array = []
	for addition: Dictionary in additions:
		document_additions.append(addition)
		var layer: Node2D = _find_layer(StringName(str(addition["layer"])))
		var node: Node2D = (
			layer.get_node_or_null(NodePath(str(addition["name"]))) as Node2D
			if layer != null else null
		)
		if node == null:
			continue
		placed.append(node)
		entries.append({"node": node, "before": {}})
		_mark_dirty("add:%s/%s" % [str(addition["layer"]), str(addition["name"])])
	# Selecting what was just stamped is what makes a pattern editable: rearrange it, then
	# Ctrl+G back over the same name.
	_selection = placed
	_selected = placed.back() if not placed.is_empty() else null
	if not entries.is_empty():
		_session.record_many("Stamp pattern", entries, previous_document)
	var skipped: Array = result.get("skipped_layers", [])
	if not skipped.is_empty():
		_message = "Stamped without %s (this scene has no such layer)." % ", ".join(skipped)
	if not keep_placing:
		_selected_pattern = {}
		_pattern_list.deselect_all()
	_refresh_status()


func _find_layer(layer_name: StringName) -> Node2D:
	if _scene_root == null:
		return null
	return _scene_root.find_child(String(layer_name), true, false) as Node2D


func _unique_prop_name(
	layer: Node, texture_path: String, reserved: PackedStringArray = PackedStringArray()
) -> StringName:
	var base: String = texture_path.get_file().get_basename().to_pascal_case()
	if base.is_empty():
		base = "LayoutProp"
	return _unique_name(layer, base, reserved)


## `reserved` names are ones a caller is about to add but has not parented yet, so they are not
## findable in the tree — a multi-prop stamp needs them or it hands out the same name twice.
func _unique_name(
	parent: Node, base: String, reserved: PackedStringArray = PackedStringArray()
) -> StringName:
	var candidate := StringName(base)
	var suffix := 2
	while (
		parent.get_node_or_null(NodePath(String(candidate))) != null
		or reserved.has(String(candidate))
	):
		candidate = StringName("%s%d" % [base, suffix])
		suffix += 1
	return candidate


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _snapped(value: Vector2) -> Vector2:
	return Vector2(
		roundf(value.x / SNAP_GRID) * SNAP_GRID,
		roundf(value.y / SNAP_GRID) * SNAP_GRID,
	)


func _mark_dirty(key: String) -> void:
	_dirty_keys[key] = true
	_message = ""


func _refresh_status() -> void:
	if not is_node_ready():
		return
	# A detached node is no longer editable; drop it from the group as well as the primary.
	for index in range(_selection.size() - 1, -1, -1):
		var member: Node2D = _selection[index]
		if not is_instance_valid(member) or member.get_parent() == null:
			_selection.remove_at(index)
	if is_instance_valid(_selected) and _selected.get_parent() == null:
		_selected = null
	if _selected == null and not _selection.is_empty():
		_selected = _selection.back()
	_scene_status.text = "Scene: %s" % (_scene_path if not _scene_path.is_empty() else "none")
	var selected_path := "none"
	if _selected != null and is_instance_valid(_selected) and _scene_root != null:
		selected_path = String(_scene_root.get_path_to(_selected))
	_selection_status.text = "Selected: %s" % selected_path
	if _selection.size() > 1:
		_selection_status.text = "Selected: %d props (primary %s)" % [
			_selection.size(), selected_path
		]
	_unsaved_status.text = "%s  |  %s" % [
		"Unsaved changes" if is_instance_valid(_session) and _session.is_dirty() else "Saved",
		_message if not _message.is_empty() else "S save / F10 exit / Ctrl+Z undo",
	]
	if not _selected_texture_path.is_empty():
		_selection_status.text = "Placing: %s (Shift keeps placing)" % _selected_texture_path.get_file()
	if not _selected_pattern.is_empty():
		_selection_status.text = "Stamping pattern: %s (Shift keeps stamping)" % str(
			_selected_pattern.get("name", "")
		)
	_inspector.inspect(_selected if is_instance_valid(_selected) else null)
	_inspector.get("_commands")["undo"].disabled = not is_instance_valid(_session) or not _session.history.has_undo()
	_inspector.get("_commands")["redo"].disabled = not is_instance_valid(_session) or not _session.history.has_redo()
	if is_instance_valid(_session) and _session.recovery_error != OK:
		_unsaved_status.text = "Recovery checkpoint failed. Save your changes: %s" % error_string(_session.recovery_error)
	_unsaved_status.tooltip_text = _unsaved_status.text
	var collision: CollisionShape2D = _selected_solid_collision()
	var placing_solid: bool = _layer_picker.selected >= 0 and _layer_picker.get_item_text(_layer_picker.selected) == "SolidProps"
	var editing_solid: bool = collision != null and _selected_texture_path.is_empty()
	_footprint_width.editable = editing_solid or placing_solid
	_footprint_height.editable = editing_solid or placing_solid
	# Existing solids can be edited; new placements retain the interior footprint cap.
	_footprint_width.max_value = 4096.0 if editing_solid else MAX_FOOTPRINT.x
	_footprint_height.max_value = 4096.0 if editing_solid else MAX_FOOTPRINT.y
	if editing_solid:
		var footprint: Vector2 = (collision.shape as RectangleShape2D).size
		_footprint_width.set_value_no_signal(footprint.x)
		_footprint_height.set_value_no_signal(footprint.y)
	_footprint_hint.text = "Cyan = selected collision. Edits apply now." if editing_solid else (
		"Next solid prop only (maximum 120 × 48)." if placing_solid else "Choose SolidProps to place collision-bearing props."
	)
