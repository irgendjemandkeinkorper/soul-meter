class_name LayoutOverrides
extends RefCounted
## Shared schema, persistence, and scene-application support for layout-mode scratch files.

const SCHEMA_VERSION := 1
const OVERRIDE_DIRECTORY := "user://layout_overrides"
const DRESSING_LAYERS := [&"GroundDetails", &"SoftDetails", &"SolidProps"]


static func create_document(scene_path: String) -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"scene": scene_path,
		"edits": [],
		"deletions": [],
		"additions": [],
	}


static func to_json(document: Dictionary) -> String:
	if not _has_valid_schema(document):
		push_warning("Layout override document has an unsupported schema.")
		return ""
	return JSON.stringify(document, "  ") + "\n"


static func from_json(content: String) -> Dictionary:
	var json := JSON.new()
	var parse_error: Error = json.parse(content)
	if parse_error != OK:
		push_warning("Layout override JSON could not be parsed: %s" % json.get_error_message())
		return {}
	if not json.data is Dictionary:
		push_warning("Layout override root must be a dictionary.")
		return {}
	var document: Dictionary = json.data as Dictionary
	if not _has_valid_schema(document):
		push_warning(
			"Layout override schema must be %d; got %s."
			% [SCHEMA_VERSION, str(document.get("schema", "missing"))]
		)
		return {}
	document["schema"] = int(document["schema"])
	for field: String in ["edits", "deletions", "additions"]:
		if not document.get(field, null) is Array:
			push_warning("Layout override field '%s' must be an array." % field)
			return {}
	return document


static func override_path_for_scene(scene_path: String) -> String:
	return OVERRIDE_DIRECTORY.path_join("%s.json" % scene_path.get_file().get_basename())


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Layout override file could not be opened: %s" % path)
		return {}
	var content: String = file.get_as_text()
	file.close()
	return from_json(content)


static func save_file(path: String, document: Dictionary) -> Error:
	var content: String = to_json(document)
	if content.is_empty():
		return ERR_INVALID_DATA
	var absolute_directory: String = ProjectSettings.globalize_path(path.get_base_dir())
	var make_error: Error = DirAccess.make_dir_recursive_absolute(absolute_directory)
	if make_error != OK and make_error != ERR_ALREADY_EXISTS:
		push_warning("Layout override directory could not be created: %s" % path.get_base_dir())
		return make_error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Layout override file could not be written: %s" % path)
		return FileAccess.get_open_error()
	file.store_string(content)
	file.close()
	return OK


static func apply_to_scene(
	scene_root: Node,
	document: Dictionary,
	assign_addition_owners: bool = false,
) -> Dictionary:
	var summary := {
		"edits_applied": 0,
		"deletions_applied": 0,
		"additions_applied": 0,
		"skipped_paths": 0,
	}
	if scene_root == null or not _has_valid_schema(document):
		push_warning("Layout override application skipped an invalid document or scene root.")
		return summary

	var edits: Array = document.get("edits", []) as Array
	for raw_edit: Variant in edits:
		if not raw_edit is Dictionary:
			summary["skipped_paths"] = int(summary["skipped_paths"]) + 1
			continue
		var edit: Dictionary = raw_edit as Dictionary
		var path := NodePath(str(edit.get("path", "")))
		var target: Node = scene_root.get_node_or_null(path)
		if not target is Node2D:
			_warn_missing("edit", path)
			summary["skipped_paths"] = int(summary["skipped_paths"]) + 1
			continue
		var target_2d := target as Node2D
		target_2d.position = _array_to_vector(edit.get("position", []), target_2d.position)
		target_2d.scale = _array_to_vector(edit.get("scale", []), target_2d.scale)
		summary["edits_applied"] = int(summary["edits_applied"]) + 1

	var deletions: Array = document.get("deletions", []) as Array
	for raw_path: Variant in deletions:
		var path := NodePath(str(raw_path))
		var target: Node = scene_root.get_node_or_null(path)
		if target == null or target == scene_root:
			_warn_missing("deletion", path)
			summary["skipped_paths"] = int(summary["skipped_paths"]) + 1
			continue
		var parent: Node = target.get_parent()
		if parent != null:
			parent.remove_child(target)
		target.free()
		summary["deletions_applied"] = int(summary["deletions_applied"]) + 1

	var additions: Array = document.get("additions", []) as Array
	for raw_addition: Variant in additions:
		if not raw_addition is Dictionary:
			summary["skipped_paths"] = int(summary["skipped_paths"]) + 1
			continue
		var addition: Dictionary = raw_addition as Dictionary
		var layer_name := StringName(str(addition.get("layer", "")))
		var layer: Node2D = _find_layer(scene_root, layer_name)
		if layer == null:
			push_warning("Layout override addition skipped missing layer: %s" % layer_name)
			summary["skipped_paths"] = int(summary["skipped_paths"]) + 1
			continue
		var node_name := StringName(str(addition.get("name", "LayoutProp")))
		if layer.get_node_or_null(NodePath(String(node_name))) != null:
			continue
		var added: Node2D = _create_addition(addition, layer_name)
		if added == null:
			summary["skipped_paths"] = int(summary["skipped_paths"]) + 1
			continue
		added.name = node_name
		layer.add_child(added)
		_conform_layer(layer, layer_name)
		if assign_addition_owners:
			# Baking: the prop becomes CANONICAL scene content. Do not tag it —
			# pack() would serialize the meta and a later layout session would
			# mistake the baked prop for a scratch addition (gate r1 finding 2).
			_assign_owner_recursive(added, scene_root)
		else:
			added.set_meta("layout_addition", addition.duplicate(true))
		summary["additions_applied"] = int(summary["additions_applied"]) + 1
	return summary


static func _create_addition(addition: Dictionary, layer_name: StringName) -> Node2D:
	var texture_path: String = str(addition.get("texture", ""))
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		push_warning("Layout override addition skipped invalid texture: %s" % texture_path)
		return null
	var position := _array_to_vector(addition.get("position", []), Vector2.ZERO)
	var scale := _array_to_vector(addition.get("scale", []), Vector2.ONE)
	if layer_name == &"SolidProps":
		var body := StaticBody2D.new()
		body.position = position
		body.scale = scale
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = texture
		body.add_child(sprite)
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var rectangle := RectangleShape2D.new()
		rectangle.size = _array_to_vector(addition.get("collision", []), Vector2(64.0, 24.0))
		collision.shape = rectangle
		collision.disabled = false
		body.add_child(collision)
		return body
	var sprite := Sprite2D.new()
	sprite.position = position
	sprite.scale = scale
	sprite.texture = texture
	return sprite


static func _find_layer(scene_root: Node, layer_name: StringName) -> Node2D:
	if not DRESSING_LAYERS.has(layer_name):
		return null
	if scene_root is Node2D and scene_root.name == layer_name:
		return scene_root as Node2D
	return scene_root.find_child(String(layer_name), true, false) as Node2D


static func _conform_layer(layer: Node2D, layer_name: StringName) -> void:
	if layer_name == &"GroundDetails":
		layer.z_index = -2
		layer.y_sort_enabled = false
	else:
		layer.y_sort_enabled = true


static func _assign_owner_recursive(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	for child: Node in node.get_children():
		_assign_owner_recursive(child, scene_root)


static func _array_to_vector(value: Variant, fallback: Vector2) -> Vector2:
	if not value is Array:
		return fallback
	var values: Array = value as Array
	if values.size() < 2:
		return fallback
	return Vector2(float(values[0]), float(values[1]))


static func _has_valid_schema(document: Dictionary) -> bool:
	return int(document.get("schema", -1)) == SCHEMA_VERSION


static func _warn_missing(operation: String, path: NodePath) -> void:
	push_warning("Layout override %s skipped missing node path: %s" % [operation, path])
