extends Control
## In-game layout editing surface. Configured with a gameplay scene by LayoutMode.

const LayoutOverridesScript := preload("res://globals/layout_overrides.gd")
const DRESSING_LAYERS := [&"GroundDetails", &"SoftDetails", &"SolidProps"]
const PALETTE_ROOTS := [
	"res://assets/generated/sprites/world/",
	"res://assets/generated/sprites/world/objects/",
]
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

var _scene_root: Node = null
var _scene_path: String = ""
var _document: Dictionary = {}
var _selected: Node2D = null
var _selected_texture_path: String = ""
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _dirty_keys: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	for layer_name: StringName in DRESSING_LAYERS:
		_layer_picker.add_item(String(layer_name))
	_footprint_width.value = DEFAULT_COLLISION_SIZE.x
	_footprint_height.value = DEFAULT_COLLISION_SIZE.y
	_palette.item_selected.connect(_on_palette_item_selected)
	_populate_palette()
	_refresh_status()


func configure(scene_root: Node) -> void:
	_scene_root = scene_root
	_scene_path = scene_root.scene_file_path if scene_root != null else ""
	var override_path: String = LayoutOverridesScript.override_path_for_scene(_scene_path)
	_document = LayoutOverridesScript.load_file(override_path)
	if _document.is_empty():
		_document = LayoutOverridesScript.create_document(_scene_path)
	_refresh_status()
	queue_redraw()


func _process(_delta: float) -> void:
	if _selected != null and not is_instance_valid(_selected):
		_selected = null
		_refresh_status()
	queue_redraw()


func _draw() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	var world_bounds: Rect2 = _editable_bounds(_selected)
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	var top_left: Vector2 = canvas_transform * world_bounds.position
	var bottom_right: Vector2 = canvas_transform * world_bounds.end
	var screen_rect := Rect2(top_left, bottom_right - top_left).abs()
	draw_rect(screen_rect.grow(2.0), Color(1.0, 0.75, 0.18, 1.0), false, 2.0)


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
		_dragging = false
		return
	var world_position: Vector2 = _screen_to_world(event.position)
	if not _selected_texture_path.is_empty():
		_place_palette_prop(world_position, event.shift_pressed)
		get_viewport().set_input_as_handled()
		return
	_selected = _pick_editable(world_position)
	_dragging = _selected != null
	if _selected != null:
		_drag_offset = _selected.global_position - world_position
	_refresh_status()
	get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _dragging or _selected == null or not is_instance_valid(_selected):
		return
	var destination: Vector2 = _screen_to_world(event.position) + _drag_offset
	_selected.global_position = destination if event.shift_pressed else _snapped(destination)
	_record_selected_transform()
	get_viewport().set_input_as_handled()


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	var handled := true
	match event.physical_keycode:
		KEY_ESCAPE:
			_cancel_palette_selection()
		KEY_DELETE:
			_delete_selected()
		KEY_D:
			if event.ctrl_pressed:
				_duplicate_selected()
			else:
				handled = false
		KEY_LEFT:
			_nudge_selected(Vector2.LEFT)
		KEY_RIGHT:
			_nudge_selected(Vector2.RIGHT)
		KEY_UP:
			_nudge_selected(Vector2.UP)
		KEY_DOWN:
			_nudge_selected(Vector2.DOWN)
		KEY_S:
			if not event.ctrl_pressed:
				_save_overrides()
			else:
				handled = false
		_:
			handled = false
	if handled:
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
		if area < picked_area:
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


func _place_palette_prop(world_position: Vector2, free_move: bool) -> void:
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
	_selected = layer.get_node_or_null(NodePath(String(prop_name))) as Node2D
	# One click, one prop: return to select mode so drag/select works again
	# (gate r1 finding 4); re-click the palette to place another.
	_cancel_palette_selection()
	_mark_dirty("add:%s/%s" % [layer_name, prop_name])
	_refresh_status()


func _delete_selected() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	var target: Node2D = _selected
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
	_selected = null
	var parent: Node = target.get_parent()
	if parent != null:
		parent.remove_child(target)
	target.free()
	_refresh_status()


func _duplicate_selected() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	var parent: Node = _selected.get_parent()
	if parent == null or not DRESSING_LAYERS.has(parent.name):
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
	_selected = duplicate_2d
	_mark_dirty("add:%s/%s" % [parent.name, duplicate_2d.name])
	_refresh_status()


func _nudge_selected(delta: Vector2) -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	_selected.position += delta
	_record_selected_transform()


func _record_selected_transform() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	if _selected.has_meta("layout_addition"):
		_update_addition(_selected)
		var layer: Node = _selected.get_parent()
		_mark_dirty("add:%s/%s" % [layer.name if layer != null else "", _selected.name])
	else:
		var path: String = String(_scene_root.get_path_to(_selected))
		var edit := {
			"path": path,
			"position": [_selected.position.x, _selected.position.y],
			"scale": [_selected.scale.x, _selected.scale.y],
		}
		_upsert_edit(edit)
		_mark_dirty("edit:%s" % path)
	_refresh_status()


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
		addition["position"] = [node.position.x, node.position.y]
		addition["scale"] = [node.scale.x, node.scale.y]
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
	var sprite: Sprite2D = node as Sprite2D
	if sprite == null:
		sprite = _first_sprite(node)
	if sprite == null or sprite.texture == null or sprite.texture.resource_path.is_empty():
		return {}
	var collision_size: Vector2 = DEFAULT_COLLISION_SIZE
	var collision: CollisionShape2D = node.find_child("CollisionShape2D", true, false) as CollisionShape2D
	if collision != null and collision.shape is RectangleShape2D:
		collision_size = (collision.shape as RectangleShape2D).size
	return {
		"layer": String(layer_name),
		"texture": sprite.texture.resource_path,
		"name": String(node.name),
		"position": [node.position.x, node.position.y],
		"scale": [node.scale.x, node.scale.y],
		"collision": [collision_size.x, collision_size.y],
	}


func _first_sprite(node: Node) -> Sprite2D:
	for child: Node in node.get_children():
		if child is Sprite2D:
			return child as Sprite2D
		var nested: Sprite2D = _first_sprite(child)
		if nested != null:
			return nested
	return null


func _save_overrides() -> void:
	var path: String = LayoutOverridesScript.override_path_for_scene(_scene_path)
	var save_error: Error = LayoutOverridesScript.save_file(path, _document)
	if save_error == OK:
		_dirty_keys.clear()
	else:
		push_warning("Layout editor failed to save %s: %s" % [path, error_string(save_error)])
	_refresh_status()


func _populate_palette() -> void:
	var paths: Array[String] = []
	var seen: Dictionary = {}
	for root_path: String in PALETTE_ROOTS:
		_scan_palette_directory(root_path, paths, seen)
	paths.sort()
	for texture_path: String in paths:
		var texture: Texture2D = load(texture_path) as Texture2D
		if texture == null:
			continue
		var index: int = _palette.add_item(texture_path.get_file().get_basename(), texture)
		_palette.set_item_metadata(index, texture_path)
		_palette.set_item_tooltip(index, texture_path)


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
	_selected_texture_path = str(_palette.get_item_metadata(index))
	_palette.tooltip_text = "Place: %s" % _selected_texture_path


## Leave placement mode and return to select/drag (Esc, right-click, or after
## a placement lands).
func _cancel_palette_selection() -> void:
	_selected_texture_path = ""
	_palette.deselect_all()
	_palette.tooltip_text = ""
	_refresh_status()


func _find_layer(layer_name: StringName) -> Node2D:
	if _scene_root == null:
		return null
	return _scene_root.find_child(String(layer_name), true, false) as Node2D


func _unique_prop_name(layer: Node, texture_path: String) -> StringName:
	var base: String = texture_path.get_file().get_basename().to_pascal_case()
	if base.is_empty():
		base = "LayoutProp"
	return _unique_name(layer, base)


func _unique_name(parent: Node, base: String) -> StringName:
	var candidate := StringName(base)
	var suffix := 2
	while parent.get_node_or_null(NodePath(String(candidate))) != null:
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


func _refresh_status() -> void:
	if not is_node_ready():
		return
	_scene_status.text = "Scene: %s" % (_scene_path if not _scene_path.is_empty() else "none")
	var selected_path := "none"
	if _selected != null and is_instance_valid(_selected) and _scene_root != null:
		selected_path = String(_scene_root.get_path_to(_selected))
	_selection_status.text = "Selected: %s" % selected_path
	_unsaved_status.text = "%d unsaved  |  S save / F10 exit" % _dirty_keys.size()
