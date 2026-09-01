extends Node
## Debug-only owner overlay coordinator. In release builds or without opt-in it stays inert.

const LayoutOverridesScript := preload("res://globals/layout_overrides.gd")
const LAYOUT_EDITOR_SCENE := preload("res://ui/debug/layout_editor.tscn")
const GAMEPLAY_PATH_PREFIX := "res://world/"

var force_enabled_for_tests: bool = false:
	set(value):
		force_enabled_for_tests = value
		_refresh_activation()

var _enabled: bool = false
var _overlay_layer: CanvasLayer = null
var _previous_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_key_input(false)
	_refresh_activation()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _enabled or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != KEY_F10 and key_event.keycode != KEY_F10:
		return
	if _overlay_layer == null:
		enter_layout_mode()
	else:
		exit_layout_mode()
	get_viewport().set_input_as_handled()


func enter_layout_mode() -> void:
	if not _enabled or _overlay_layer != null:
		return
	var scene_root: Node = _find_gameplay_scene()
	if scene_root == null:
		return
	_previous_paused = get_tree().paused
	get_tree().paused = true
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "LayoutModeLayer"
	_overlay_layer.layer = 1000
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)
	var editor: Control = LAYOUT_EDITOR_SCENE.instantiate() as Control
	editor.name = "LayoutEditor"
	editor.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_layer.add_child(editor)
	editor.call("configure", scene_root)


func exit_layout_mode() -> void:
	if _overlay_layer == null:
		return
	var layer: CanvasLayer = _overlay_layer
	_overlay_layer = null
	remove_child(layer)
	layer.free()
	get_tree().paused = _previous_paused


func _refresh_activation() -> void:
	if not is_inside_tree():
		return
	var should_enable: bool = OS.is_debug_build() and (
		OS.get_environment("SOUL_METER_LAYOUT") == "1" or force_enabled_for_tests
	)
	if should_enable == _enabled:
		return
	_enabled = should_enable
	set_process_unhandled_key_input(_enabled)
	if _enabled:
		if not get_tree().node_added.is_connected(_on_tree_node_added):
			get_tree().node_added.connect(_on_tree_node_added)
		_apply_existing_gameplay_scenes()
	else:
		exit_layout_mode()
		if get_tree().node_added.is_connected(_on_tree_node_added):
			get_tree().node_added.disconnect(_on_tree_node_added)


func _on_tree_node_added(node: Node) -> void:
	if not _enabled or not _is_gameplay_scene(node):
		return
	call_deferred("_apply_override_to_scene", node)


func _apply_existing_gameplay_scenes() -> void:
	var current: Node = get_tree().current_scene
	if _is_gameplay_scene(current):
		_apply_override_to_scene(current)
	for child: Node in get_tree().root.get_children():
		var gameplay_scene: Node = _find_gameplay_descendant(child)
		if gameplay_scene != null:
			_apply_override_to_scene(gameplay_scene)


func _apply_override_to_scene(scene_root: Node) -> void:
	if not _enabled or not is_instance_valid(scene_root) or not _is_gameplay_scene(scene_root):
		return
	if scene_root.has_meta("layout_overrides_applied"):
		return
	scene_root.set_meta("layout_overrides_applied", true)
	var scene_path: String = scene_root.scene_file_path
	var override_path: String = LayoutOverridesScript.override_path_for_scene(scene_path)
	var document: Dictionary = LayoutOverridesScript.load_file(override_path)
	if document.is_empty():
		return
	if str(document.get("scene", "")) != scene_path:
		push_warning(
			"Layout override scene mismatch: expected %s, file declares %s"
			% [scene_path, str(document.get("scene", ""))]
		)
		return
	LayoutOverridesScript.apply_to_scene(scene_root, document)


func _find_gameplay_scene() -> Node:
	var current: Node = get_tree().current_scene
	if _is_gameplay_scene(current):
		return current
	for child: Node in get_tree().root.get_children():
		var result: Node = _find_gameplay_descendant(child)
		if result != null:
			return result
	return null


func _find_gameplay_descendant(node: Node) -> Node:
	if _is_gameplay_scene(node):
		return node
	for child: Node in node.get_children():
		var result: Node = _find_gameplay_descendant(child)
		if result != null:
			return result
	return null


func _is_gameplay_scene(node: Node) -> bool:
	return node != null and node.scene_file_path.begins_with(GAMEPLAY_PATH_PREFIX)
