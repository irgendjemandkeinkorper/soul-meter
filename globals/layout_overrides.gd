class_name LayoutOverrides
extends RefCounted
## Shared schema, persistence, and scene-application support for layout-mode scratch files.

const SCHEMA_VERSION := 1
const OVERRIDE_DIRECTORY := "user://layout_overrides"
const DRESSING_LAYERS := [&"GroundDetails", &"SoftDetails", &"SolidProps"]
const GRAYSCALE_SHADER := preload("res://ui/debug/layout_grayscale.gdshader")


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


static func save_file(path: String, document: Dictionary, _promote_for_tests: Callable = Callable()) -> Error:
	return save_json(path, to_json(document), _promote_for_tests)


## Atomic write-then-rename, shared with the pattern library (layout_patterns.gd) so both
## document kinds get the same never-truncate-the-previous-save guarantee. Callers pass
## already-serialised content, because each kind validates its own schema on the way out.
static func save_json(path: String, content: String, _promote_for_tests: Callable = Callable()) -> Error:
	if content.is_empty():
		return ERR_INVALID_DATA
	var absolute_directory: String = ProjectSettings.globalize_path(path.get_base_dir())
	var make_error: Error = DirAccess.make_dir_recursive_absolute(absolute_directory)
	if make_error != OK and make_error != ERR_ALREADY_EXISTS:
		push_warning("Layout override directory could not be created: %s" % path.get_base_dir())
		return make_error
	# A sibling keeps promotion on the same filesystem. Never truncate the prior save.
	var destination: String = ProjectSettings.globalize_path(path)
	var temporary_base: String = "%s.tmp.%d.%d" % [destination, OS.get_process_id(), Time.get_ticks_usec()]
	var temporary: String = temporary_base
	var sequence: int = 0
	while FileAccess.file_exists(temporary) or DirAccess.dir_exists_absolute(temporary):
		sequence += 1
		temporary = "%s.%d" % [temporary_base, sequence]
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		_remove_save_temporary(temporary)
		push_warning("Layout override temporary file could not be opened: %s" % temporary)
		return open_error
	var stored: bool = file.store_string(content)
	var write_error: Error = file.get_error()
	if not stored and write_error == OK:
		write_error = ERR_FILE_CANT_WRITE
	if write_error == OK:
		file.flush()
		write_error = file.get_error()
	file.close()
	if write_error != OK:
		_remove_save_temporary(temporary)
		push_warning("Layout override write failed; previous save retained: %s" % path)
		return write_error
	var promotion_error: Error = _promote_for_tests.call(temporary, destination) if _promote_for_tests.is_valid() \
		else DirAccess.rename_absolute(temporary, destination)
	if promotion_error != OK:
		_remove_save_temporary(temporary)
		push_warning("Layout override replacement failed; previous save retained: %s" % path)
	return promotion_error


static func _remove_save_temporary(temporary: String) -> void:
	if FileAccess.file_exists(temporary):
		var remove_error: Error = DirAccess.remove_absolute(temporary)
		if remove_error != OK:
			push_warning("Layout override temporary file could not be removed: %s" % temporary)


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
		apply_properties(target as Node2D, edit)
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
		apply_properties(added, addition)
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
	if layer_name == &"SolidProps":
		var body := StaticBody2D.new()
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = texture
		body.add_child(sprite)
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(64.0, 24.0)
		collision.shape = rectangle
		collision.disabled = false
		body.add_child(collision)
		return body
	var sprite := Sprite2D.new()
	sprite.texture = texture
	return sprite


## JSON-ready local properties; omitted capabilities do not appear in the capture.
static func capture_properties(node: Node2D) -> Dictionary:
	if node == null:
		return {}
	var values := {
		"position": [node.position.x, node.position.y],
		"scale": [node.scale.x, node.scale.y],
		"rotation": node.rotation,
		"skew": node.skew,
	}
	var sprite: Sprite2D = find_sprite(node)
	if sprite != null:
		values["flip_h"] = sprite.flip_h
		values["flip_v"] = sprite.flip_v
		values["grayscale"] = is_grayscale(node)
	var collision: CollisionShape2D = _editable_collision(node)
	if collision != null:
		var size: Vector2 = (collision.shape as RectangleShape2D).size
		values["collision"] = [size.x, size.y]
	return values


## Schema-1 fields are optional, so old overrides retain all unmentioned properties.
static func apply_properties(node: Node2D, values: Dictionary) -> void:
	if node == null:
		return
	if values.get("canvas") is Dictionary:
		_apply_canvas_properties(node, values["canvas"])
	if values.has("position"):
		node.position = _array_to_vector(values["position"], node.position)
	if values.has("scale"):
		node.scale = _array_to_vector(values["scale"], node.scale)
	if _is_finite_number(values.get("rotation")):
		node.rotation = float(values["rotation"])
	if _is_finite_number(values.get("skew")):
		node.skew = float(values["skew"])
	var sprite: Sprite2D = find_sprite(node)
	if sprite != null:
		if values.get("flip_h") is bool:
			sprite.flip_h = values["flip_h"]
		if values.get("flip_v") is bool:
			sprite.flip_v = values["flip_v"]
		if values.get("grayscale") is bool:
			_apply_grayscale(sprite, bool(values["grayscale"]))
		if values.get("sprite") is Dictionary:
			_apply_sprite_geometry(sprite, values["sprite"], sprite != node)
	var editable_collision: CollisionShape2D = _editable_collision(node)
	if editable_collision != null and values.get("body") is Dictionary:
		_apply_body_properties(node as StaticBody2D, values["body"])
	if editable_collision != null and values.get("collision_transform") is Dictionary:
		var geometry: Dictionary = values["collision_transform"]
		_apply_local_transform(editable_collision, geometry)
		for field: String in ["disabled", "one_way_collision"]:
			if geometry.get(field) is bool:
				editable_collision.set(field, geometry[field])
		if _is_finite_number(geometry.get("one_way_collision_margin")) \
				and float(geometry["one_way_collision_margin"]) >= 0.0:
			editable_collision.one_way_collision_margin = float(geometry["one_way_collision_margin"])
	if values.has("collision"):
		var collision: CollisionShape2D = _editable_collision(node)
		var size: Vector2 = _array_to_vector(values["collision"], Vector2.ZERO)
		if collision != null and size.x > 0.0 and size.y > 0.0:
			var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
			if rectangle.size != size:
				# Scene instances can share this resource; resize only the selected prop.
				var owned_shape: RectangleShape2D = rectangle.duplicate() as RectangleShape2D
				owned_shape.size = size
				collision.shape = owned_shape


## The scratch format recreates these simple structures, not arbitrary node trees.
static func supports_addition(node: Node2D, layer_name: StringName) -> bool:
	if node == null or node.get_script() != null or not DRESSING_LAYERS.has(layer_name):
		return false
	if layer_name != &"SolidProps":
		return node is Sprite2D and _supported_addition_sprite(node as Sprite2D)
	if not node is StaticBody2D or node.get_child_count() != 2 or node.material != null \
			or node.use_parent_material:
		return false
	if (node as StaticBody2D).physics_material_override != null:
		return false
	var sprite: Sprite2D = null
	var collision: CollisionShape2D = null
	for child: Node in node.get_children():
		if child is Sprite2D:
			sprite = child as Sprite2D
		elif child is CollisionShape2D:
			collision = child as CollisionShape2D
		else:
			return false
	return sprite != null and _supported_addition_sprite(sprite) and collision != null \
		and collision.get_script() == null and collision.get_child_count() == 0 \
		and collision.shape is RectangleShape2D


## A complete supported duplicate payload, or an empty dictionary on refusal.
static func capture_addition(node: Node2D, layer_name: StringName) -> Dictionary:
	if not supports_addition(node, layer_name):
		return {}
	var sprite: Sprite2D = find_sprite(node)
	var addition: Dictionary = capture_properties(node)
	addition.merge({
		"layer": String(layer_name), "name": String(node.name),
		"texture": sprite.texture.resource_path,
		"canvas": _capture_canvas_properties(node),
		"sprite": _capture_sprite_geometry(sprite, sprite != node),
	})
	if node is StaticBody2D:
		addition["body"] = _capture_body_properties(node as StaticBody2D)
		var collision: CollisionShape2D = find_collision(node)
		var dimensions: Vector2 = (collision.shape as RectangleShape2D).size
		addition["collision"] = [dimensions.x, dimensions.y]
		var geometry: Dictionary = _capture_local_transform(collision)
		geometry["disabled"] = collision.disabled
		geometry["one_way_collision"] = collision.one_way_collision
		geometry["one_way_collision_margin"] = collision.one_way_collision_margin
		addition["collision_transform"] = geometry
	return addition


static func _supported_addition_sprite(sprite: Sprite2D) -> bool:
	return sprite.get_script() == null and sprite.get_child_count() == 0 \
		and sprite.texture != null and not sprite.texture.resource_path.is_empty() \
		and supports_grayscale(sprite)


static func _capture_local_transform(node: Node2D) -> Dictionary:
	return {
		"position": [node.position.x, node.position.y],
		"scale": [node.scale.x, node.scale.y], "rotation": node.rotation, "skew": node.skew,
	}


static func _apply_local_transform(node: Node2D, values: Dictionary) -> void:
	node.position = _array_to_vector(values.get("position"), node.position)
	node.scale = _array_to_vector(values.get("scale"), node.scale)
	if _is_finite_number(values.get("rotation")):
		node.rotation = float(values["rotation"])
	if _is_finite_number(values.get("skew")):
		node.skew = float(values["skew"])


static func _capture_sprite_geometry(sprite: Sprite2D, include_transform: bool) -> Dictionary:
	var geometry: Dictionary = _capture_local_transform(sprite) if include_transform else {}
	if include_transform:
		geometry["canvas"] = _capture_canvas_properties(sprite)
	geometry.merge({
		"offset": [sprite.offset.x, sprite.offset.y], "centered": sprite.centered,
		"region_enabled": sprite.region_enabled,
		"region_rect": [
			sprite.region_rect.position.x, sprite.region_rect.position.y,
			sprite.region_rect.size.x, sprite.region_rect.size.y,
		],
		"region_filter_clip_enabled": sprite.region_filter_clip_enabled,
		"hframes": sprite.hframes, "vframes": sprite.vframes, "frame": sprite.frame,
		"modulate": [sprite.modulate.r, sprite.modulate.g, sprite.modulate.b, sprite.modulate.a],
		"self_modulate": [
			sprite.self_modulate.r, sprite.self_modulate.g, sprite.self_modulate.b, sprite.self_modulate.a,
		],
	})
	return geometry


static func _apply_sprite_geometry(sprite: Sprite2D, values: Dictionary, include_transform: bool) -> void:
	if values.get("canvas") is Dictionary:
		_apply_canvas_properties(sprite, values["canvas"])
	if include_transform:
		_apply_local_transform(sprite, values)
	sprite.offset = _array_to_vector(values.get("offset"), sprite.offset)
	for field: String in ["centered", "region_enabled", "region_filter_clip_enabled"]:
		if values.get(field) is bool:
			sprite.set(field, values[field])
	if _numeric_array(values.get("region_rect"), 4):
		var rect: Array = values["region_rect"]
		var position: Vector2 = _array_to_vector(rect.slice(0, 2), sprite.region_rect.position)
		var dimensions: Vector2 = _array_to_vector(rect.slice(2, 4), sprite.region_rect.size)
		if dimensions.x >= 0.0 and dimensions.y >= 0.0:
			sprite.region_rect = Rect2(position, dimensions)
	for field: String in ["hframes", "vframes"]:
		if _is_finite_number(values.get(field)):
			var count: float = float(values[field])
			if count >= 1.0 and count <= 2147483647.0 and count == floorf(count):
				sprite.set(field, int(count))
	if _is_finite_number(values.get("frame")):
		var frame: float = float(values["frame"])
		if frame >= 0.0 and frame < sprite.hframes * sprite.vframes and frame == floorf(frame):
			sprite.frame = int(frame)
	for field: String in ["modulate", "self_modulate"]:
		if _numeric_array(values.get(field), 4):
			var color: Array = values[field]
			sprite.set(field, Color(float(color[0]), float(color[1]), float(color[2]), float(color[3])))


static func _numeric_array(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for number: Variant in value:
		if not _is_finite_number(number):
			return false
	return true


static func _capture_canvas_properties(node: Node2D) -> Dictionary:
	var values := {
		"modulate": [node.modulate.r, node.modulate.g, node.modulate.b, node.modulate.a],
		"self_modulate": [node.self_modulate.r, node.self_modulate.g, node.self_modulate.b, node.self_modulate.a],
	}
	for field: String in [
		"visible", "show_behind_parent", "top_level", "z_index", "z_as_relative", "y_sort_enabled",
		"light_mask", "visibility_layer", "texture_filter", "texture_repeat", "clip_children",
	]:
		values[field] = node.get(field)
	return values


static func _apply_canvas_properties(node: Node2D, values: Dictionary) -> void:
	# Set top_level before local transforms so parenting cannot reinterpret the saved position.
	for field: String in ["top_level", "visible", "show_behind_parent", "z_as_relative", "y_sort_enabled"]:
		if values.get(field) is bool:
			node.set(field, values[field])
	var limits := {
		"z_index": [RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX],
		"light_mask": [0, 4294967295], "visibility_layer": [0, 4294967295],
		"texture_filter": [0, CanvasItem.TEXTURE_FILTER_MAX - 1],
		"texture_repeat": [0, CanvasItem.TEXTURE_REPEAT_MAX - 1], "clip_children": [0, 2],
	}
	for field: String in limits:
		if _integer_in_range(values.get(field), limits[field][0], limits[field][1]):
			node.set(field, int(values[field]))
	for field: String in ["modulate", "self_modulate"]:
		if _numeric_array(values.get(field), 4):
			var color: Array = values[field]
			node.set(field, Color(float(color[0]), float(color[1]), float(color[2]), float(color[3])))


static func _capture_body_properties(body: StaticBody2D) -> Dictionary:
	return {
		"collision_layer": body.collision_layer, "collision_mask": body.collision_mask,
		"collision_priority": body.collision_priority,
		"constant_linear_velocity": [body.constant_linear_velocity.x, body.constant_linear_velocity.y],
		"constant_angular_velocity": body.constant_angular_velocity,
		"input_pickable": body.input_pickable,
		"disable_mode": body.disable_mode,
	}


static func _apply_body_properties(body: StaticBody2D, values: Dictionary) -> void:
	for field: String in ["collision_layer", "collision_mask"]:
		if _integer_in_range(values.get(field), 0, 4294967295):
			body.set(field, int(values[field]))
	if _integer_in_range(values.get("disable_mode"), 0, 2):
		body.set("disable_mode", int(values["disable_mode"]))
	for field: String in ["input_pickable"]:
		if values.get(field) is bool:
			body.set(field, values[field])
	if _is_finite_number(values.get("collision_priority")) and float(values["collision_priority"]) > 0.0:
		body.collision_priority = float(values["collision_priority"])
	body.constant_linear_velocity = _array_to_vector(
		values.get("constant_linear_velocity"), body.constant_linear_velocity
	)
	if _is_finite_number(values.get("constant_angular_velocity")):
		body.constant_angular_velocity = float(values["constant_angular_velocity"])


static func _integer_in_range(value: Variant, low: int, high: int) -> bool:
	if not _is_finite_number(value):
		return false
	var number: float = float(value)
	return number >= low and number <= high and number == floorf(number)


static func find_sprite(node: Node) -> Sprite2D:
	if node == null:
		return null
	if node is Sprite2D:
		return node as Sprite2D
	for child: Node in node.get_children():
		var sprite: Sprite2D = find_sprite(child)
		if sprite != null:
			return sprite
	return null


static func find_collision(node: Node) -> CollisionShape2D:
	if node == null:
		return null
	if node is CollisionShape2D:
		return node as CollisionShape2D
	for child: Node in node.get_children():
		var collision: CollisionShape2D = find_collision(child)
		if collision != null:
			return collision
	return null


static func supports_grayscale(node: Node) -> bool:
	var sprite: Sprite2D = find_sprite(node)
	return sprite != null and not sprite.use_parent_material \
		and (sprite.material == null or is_grayscale(sprite))


static func is_grayscale(node: Node) -> bool:
	var sprite: Sprite2D = find_sprite(node)
	if sprite == null or sprite.use_parent_material or not sprite.material is ShaderMaterial:
		return false
	return (sprite.material as ShaderMaterial).shader == GRAYSCALE_SHADER


static func _apply_grayscale(sprite: Sprite2D, enabled: bool) -> void:
	if not supports_grayscale(sprite):
		return
	if enabled and not is_grayscale(sprite):
		var material := ShaderMaterial.new()
		material.shader = GRAYSCALE_SHADER
		sprite.material = material
	elif not enabled and is_grayscale(sprite):
		sprite.material = null


static func _editable_collision(node: Node2D) -> CollisionShape2D:
	if not node is StaticBody2D:
		return null
	var ancestor: Node = node.get_parent()
	while ancestor != null and ancestor.name != &"SolidProps":
		ancestor = ancestor.get_parent()
	if ancestor == null:
		return null
	# A working CollisionShape2D must be directly owned by this physics body.
	for child: Node in node.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
			return child as CollisionShape2D
	return null


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
	if not _is_finite_number(values[0]) or not _is_finite_number(values[1]):
		return fallback
	var vector := Vector2(float(values[0]), float(values[1]))
	return vector if vector.is_finite() else fallback


static func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _has_valid_schema(document: Dictionary) -> bool:
	var version: Variant = document.get("schema")
	return (version is int or version is float) and version == SCHEMA_VERSION


static func _warn_missing(operation: String, path: NodePath) -> void:
	push_warning("Layout override %s skipped missing node path: %s" % [operation, path])
