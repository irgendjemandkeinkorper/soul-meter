extends GdUnitTestSuite


func test_schema_requires_exact_numeric_version_without_conversion_errors() -> void:
	for value: Variant in [1.5, true, "1", {}, []]:
		var document: Dictionary = LayoutOverrides.create_document("res://world/schema_fixture.tscn")
		document["schema"] = value
		assert_dict(LayoutOverrides.from_json(JSON.stringify(document))).is_empty()

const LayoutOverridesScript := preload("res://globals/layout_overrides.gd")
const TEST_TEXTURE := "res://assets/generated/sprites/world/dom-crate-wood--stacked.png"


func test_serialization_round_trip_preserves_the_schema() -> void:
	var document: Dictionary = LayoutOverridesScript.create_document("res://world/test_room.tscn")
	document["edits"] = [{
		"path": "Dressing/SoftDetails/Lantern",
		"position": [24.0, 40.0],
		"scale": [0.5, 0.75],
	}]
	document["deletions"] = ["Dressing/GroundDetails/Scuff"]
	document["additions"] = [{
		"layer": "SolidProps",
		"texture": TEST_TEXTURE,
		"name": "AddedCrate",
		"position": [88.0, 112.0],
		"scale": [0.4, 0.4],
		"collision": [64.0, 24.0],
	}]

	var encoded: String = LayoutOverridesScript.to_json(document)
	var decoded: Dictionary = LayoutOverridesScript.from_json(encoded)

	assert_dict(decoded).is_equal(document)


func test_application_edits_deletes_and_adds_a_contract_conformant_solid_prop() -> void:
	var root: Node2D = auto_free(_build_scene()) as Node2D
	var document: Dictionary = LayoutOverridesScript.create_document("res://world/test_room.tscn")
	document["edits"] = [{
		"path": "Dressing/SoftDetails/MoveMe",
		"position": [96.0, 48.0],
		"scale": [1.5, 0.5],
	}]
	document["deletions"] = ["Dressing/GroundDetails/DeleteMe"]
	document["additions"] = [{
		"layer": "SolidProps",
		"texture": TEST_TEXTURE,
		"name": "AddedCrate",
		"position": [128.0, 144.0],
		"scale": [0.5, 0.5],
		"collision": [72.0, 20.0],
	}]

	var summary: Dictionary = LayoutOverridesScript.apply_to_scene(root, document)
	var moved: Sprite2D = root.get_node("Dressing/SoftDetails/MoveMe") as Sprite2D
	var solid_layer: Node2D = root.get_node("Dressing/SolidProps") as Node2D
	var added: StaticBody2D = solid_layer.get_node("AddedCrate") as StaticBody2D
	var sprite: Sprite2D = added.get_node("Sprite2D") as Sprite2D
	var collision: CollisionShape2D = added.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D

	assert_vector(moved.position).is_equal(Vector2(96.0, 48.0))
	assert_vector(moved.scale).is_equal(Vector2(1.5, 0.5))
	assert_object(root.get_node_or_null("Dressing/GroundDetails/DeleteMe")).is_null()
	assert_bool(solid_layer.y_sort_enabled).is_true()
	assert_vector(added.position).is_equal(Vector2(128.0, 144.0))
	assert_object(sprite.texture).is_not_null()
	assert_vector(added.scale).is_equal(Vector2(0.5, 0.5))
	assert_vector(sprite.scale).is_equal(Vector2.ONE)
	assert_vector(rectangle.size).is_equal(Vector2(72.0, 20.0))
	assert_bool(collision.disabled).is_false()
	assert_int(int(summary["edits_applied"])).is_equal(1)
	assert_int(int(summary["deletions_applied"])).is_equal(1)
	assert_int(int(summary["additions_applied"])).is_equal(1)


func test_missing_paths_are_skipped_and_reapplying_does_not_duplicate_additions() -> void:
	var root: Node2D = auto_free(_build_scene()) as Node2D
	var document: Dictionary = LayoutOverridesScript.create_document("res://world/test_room.tscn")
	document["edits"] = [{
		"path": "Missing/Node",
		"position": [1.0, 2.0],
		"scale": [1.0, 1.0],
	}]
	document["additions"] = [{
		"layer": "SoftDetails",
		"texture": TEST_TEXTURE,
		"name": "OneOnly",
		"position": [8.0, 16.0],
		"scale": [1.0, 1.0],
		"collision": [64.0, 24.0],
	}]

	var first: Dictionary = LayoutOverridesScript.apply_to_scene(root, document)
	var second: Dictionary = LayoutOverridesScript.apply_to_scene(root, document)
	var soft_layer: Node2D = root.get_node("Dressing/SoftDetails") as Node2D

	assert_int(int(first["skipped_paths"])).is_equal(1)
	assert_int(int(second["additions_applied"])).is_equal(0)
	assert_int(soft_layer.get_child_count()).is_equal(2)


func test_unknown_schema_is_rejected() -> void:
	var decoded: Dictionary = LayoutOverridesScript.from_json(
		'{"schema":2,"scene":"res://world/test_room.tscn","edits":[],"deletions":[],"additions":[]}'
	)

	assert_bool(decoded.is_empty()).is_true()


func test_extended_properties_reload_for_existing_and_added_solid_props() -> void:
	var document: Dictionary = LayoutOverridesScript.create_document("res://world/test_room.tscn")
	var properties := {
		"position": [12.0, 24.0], "scale": [1.25, 0.75], "rotation": 0.25, "skew": 0.125,
		"flip_h": true, "flip_v": true, "grayscale": true, "collision": [160.0, 64.0],
	}
	var edit: Dictionary = properties.duplicate(true)
	edit["path"] = "Dressing/SolidProps/Existing"
	document["edits"] = [edit]
	var addition: Dictionary = properties.duplicate(true)
	addition.merge({"layer": "SolidProps", "name": "Added", "texture": TEST_TEXTURE})
	document["additions"] = [addition]
	var decoded: Dictionary = LayoutOverridesScript.from_json(LayoutOverridesScript.to_json(document))
	assert_int(int(decoded["schema"])).is_equal(1)

	for _reload: int in range(2):
		var root: Node2D = auto_free(_build_scene()) as Node2D
		var existing: StaticBody2D = _make_solid("Existing")
		root.get_node("Dressing/SolidProps").add_child(existing)
		var summary: Dictionary = LayoutOverridesScript.apply_to_scene(root, decoded)
		assert_int(int(summary["edits_applied"])).is_equal(1)
		assert_int(int(summary["additions_applied"])).is_equal(1)
		for path: String in ["Dressing/SolidProps/Existing", "Dressing/SolidProps/Added"]:
			var target: Node2D = root.get_node(path) as Node2D
			var captured: Dictionary = LayoutOverridesScript.capture_properties(target)
			assert_dict(captured).is_equal(properties)
			assert_bool(LayoutOverridesScript.is_grayscale(target)).is_true()
			assert_bool(LayoutOverridesScript.find_sprite(target).flip_h).is_true()
			assert_bool(LayoutOverridesScript.find_sprite(target).flip_v).is_true()


func test_partial_properties_leave_omitted_values_unchanged() -> void:
	var sprite: Sprite2D = auto_free(Sprite2D.new()) as Sprite2D
	sprite.position = Vector2(8, 16)
	sprite.scale = Vector2(2, 3)
	sprite.rotation = 0.25
	sprite.skew = 0.125
	sprite.flip_h = true
	LayoutOverridesScript.apply_properties(sprite, {"flip_v": true})
	assert_vector(sprite.position).is_equal(Vector2(8, 16))
	assert_vector(sprite.scale).is_equal(Vector2(2, 3))
	assert_float(sprite.rotation).is_equal_approx(0.25, 0.0001)
	assert_float(sprite.skew).is_equal_approx(0.125, 0.0001)
	assert_bool(sprite.flip_h).is_true()
	assert_bool(sprite.flip_v).is_true()
	assert_object(LayoutOverridesScript.find_sprite(sprite)).is_same(sprite)


func test_collision_resize_duplicates_shared_shape_and_refuses_non_props() -> void:
	var root: Node2D = auto_free(_build_scene()) as Node2D
	var first: StaticBody2D = _make_solid("First")
	var second: StaticBody2D = _make_solid("Second")
	root.get_node("Dressing/SolidProps").add_child(first)
	root.get_node("Dressing/SolidProps").add_child(second)
	var first_collision: CollisionShape2D = LayoutOverridesScript.find_collision(first)
	var second_collision: CollisionShape2D = LayoutOverridesScript.find_collision(second)
	var shared: RectangleShape2D = first_collision.shape as RectangleShape2D
	second_collision.shape = shared
	LayoutOverridesScript.apply_properties(first, {"collision": [100.0, 40.0]})
	assert_vector((first_collision.shape as RectangleShape2D).size).is_equal(Vector2(100, 40))
	assert_vector(shared.size).is_equal(Vector2(64, 24))
	assert_object(second_collision.shape).is_same(shared)
	assert_object(first_collision.shape).is_not_same(shared)

	var actor: CharacterBody2D = CharacterBody2D.new()
	actor.name = "Actor"
	root.get_node("Dressing/SolidProps").add_child(actor)
	var actor_collision := CollisionShape2D.new()
	actor_collision.shape = shared
	actor.add_child(actor_collision)
	LayoutOverridesScript.apply_properties(actor, {"collision": [100.0, 40.0]})
	assert_object(actor_collision.shape).is_same(shared)
	assert_bool(LayoutOverridesScript.capture_properties(actor).has("collision")).is_false()

	var outside: StaticBody2D = _make_solid("NotDressing")
	root.add_child(outside)
	LayoutOverridesScript.apply_properties(outside, {"collision": [100.0, 40.0]})
	assert_vector((LayoutOverridesScript.find_collision(outside).shape as RectangleShape2D).size).is_equal(
		Vector2(64, 24)
	)
	second_collision.shape = CircleShape2D.new()
	LayoutOverridesScript.apply_properties(second, {"collision": [100.0, 40.0]})
	assert_bool(second_collision.shape is CircleShape2D).is_true()


func test_invalid_collision_dimensions_are_ignored() -> void:
	var root: Node2D = auto_free(_build_scene()) as Node2D
	var target: StaticBody2D = _make_solid("Prop")
	root.get_node("Dressing/SolidProps").add_child(target)
	var original: Shape2D = LayoutOverridesScript.find_collision(target).shape
	for invalid: Array in [[-1, 12], [12, 0], [INF, 12], [NAN, 12], [1.0e100, 12], [12, "wide"], [12]]:
		LayoutOverridesScript.apply_properties(target, {"collision": invalid})
		assert_object(LayoutOverridesScript.find_collision(target).shape).is_same(original)
	assert_vector((original as RectangleShape2D).size).is_equal(Vector2(64, 24))


func test_grayscale_toggle_preserves_texture_modulate_and_custom_materials() -> void:
	var sprite: Sprite2D = auto_free(Sprite2D.new()) as Sprite2D
	var texture: Texture2D = load(TEST_TEXTURE) as Texture2D
	sprite.texture = texture
	sprite.modulate = Color(0.5, 0.75, 1.0, 0.4)
	assert_bool(LayoutOverridesScript.supports_grayscale(sprite)).is_true()
	LayoutOverridesScript.apply_properties(sprite, {"grayscale": true})
	assert_bool(LayoutOverridesScript.is_grayscale(sprite)).is_true()
	assert_object(sprite.texture).is_same(texture)
	assert_bool(sprite.modulate == Color(0.5, 0.75, 1.0, 0.4)).is_true()
	LayoutOverridesScript.apply_properties(sprite, {"grayscale": false})
	assert_bool(LayoutOverridesScript.is_grayscale(sprite)).is_false()
	assert_object(sprite.material).is_null()

	var custom := ShaderMaterial.new()
	sprite.material = custom
	assert_bool(LayoutOverridesScript.supports_grayscale(sprite)).is_false()
	LayoutOverridesScript.apply_properties(sprite, {"grayscale": true})
	assert_object(sprite.material).is_same(custom)
	LayoutOverridesScript.apply_properties(sprite, {"grayscale": false})
	assert_object(sprite.material).is_same(custom)
	sprite.material = null
	sprite.use_parent_material = true
	assert_bool(LayoutOverridesScript.supports_grayscale(sprite)).is_false()


func _make_solid(node_name: String) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	body.add_child(sprite)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(64, 24)
	collision.shape = rectangle
	body.add_child(collision)
	return body


func test_duplicate_solid_reload_preserves_sprite_and_collision_geometry() -> void:
	var original_root: Node2D = auto_free(_build_scene()) as Node2D
	var original: StaticBody2D = _make_solid("Copy")
	original_root.get_node("Dressing/SolidProps").add_child(original)
	var sprite: Sprite2D = LayoutOverridesScript.find_sprite(original)
	sprite.texture = load(TEST_TEXTURE) as Texture2D
	sprite.position = Vector2(3, -4)
	sprite.scale = Vector2(0.5, 0.75)
	sprite.rotation = 0.25
	sprite.skew = 0.125
	sprite.offset = Vector2(0, -115)
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(4, 8, 32, 24)
	sprite.region_filter_clip_enabled = true
	sprite.hframes = 2
	sprite.vframes = 2
	sprite.frame = 3
	sprite.modulate = Color(0.5, 0.75, 1, 0.5)
	var collision: CollisionShape2D = LayoutOverridesScript.find_collision(original)
	collision.position = Vector2(0, -10)
	collision.rotation = 0.125
	collision.scale = Vector2(0.75, 1.25)

	assert_bool(LayoutOverridesScript.supports_addition(original, &"SolidProps")).is_true()
	var addition: Dictionary = LayoutOverridesScript.capture_addition(original, &"SolidProps")
	var document: Dictionary = LayoutOverridesScript.create_document("res://world/test_room.tscn")
	document["additions"] = [addition]
	document = LayoutOverridesScript.from_json(LayoutOverridesScript.to_json(document))
	var fresh: Node2D = auto_free(_build_scene()) as Node2D
	LayoutOverridesScript.apply_to_scene(fresh, document)
	var restored: Node2D = fresh.get_node("Dressing/SolidProps/Copy") as Node2D
	var restored_sprite: Sprite2D = LayoutOverridesScript.find_sprite(restored)
	var restored_collision: CollisionShape2D = LayoutOverridesScript.find_collision(restored)
	assert_bool(restored_sprite.transform.is_equal_approx(sprite.transform)).is_true()
	assert_vector(restored_sprite.offset).is_equal(sprite.offset)
	assert_bool(restored_sprite.centered).is_equal(sprite.centered)
	assert_bool(restored_sprite.region_enabled).is_equal(sprite.region_enabled)
	assert_bool(restored_sprite.region_rect == sprite.region_rect).is_true()
	assert_bool(restored_sprite.region_filter_clip_enabled).is_true()
	assert_int(restored_sprite.hframes).is_equal(2)
	assert_int(restored_sprite.vframes).is_equal(2)
	assert_int(restored_sprite.frame).is_equal(3)
	assert_bool(restored_sprite.modulate == sprite.modulate).is_true()
	assert_bool(restored_collision.transform.is_equal_approx(collision.transform)).is_true()


func test_duplicate_sprite_geometry_applies_equally_to_edits_and_additions() -> void:
	var original: Sprite2D = auto_free(Sprite2D.new()) as Sprite2D
	original.name = "AddedSprite"
	original.texture = load(TEST_TEXTURE) as Texture2D
	original.position = Vector2(12, 24)
	original.scale = Vector2(0.5, 0.75)
	original.rotation = 0.25
	original.skew = 0.125
	original.offset = Vector2(8, -12)
	original.centered = false
	original.hframes = 2
	original.vframes = 2
	original.frame = 2
	original.flip_h = true
	LayoutOverridesScript.apply_properties(original, {"grayscale": true})
	var addition: Dictionary = LayoutOverridesScript.capture_addition(original, &"SoftDetails")
	var edit: Dictionary = addition.duplicate(true)
	edit["path"] = "Dressing/SoftDetails/MoveMe"
	var document: Dictionary = LayoutOverridesScript.create_document("res://world/test_room.tscn")
	document["edits"] = [edit]
	document["additions"] = [addition]
	document = LayoutOverridesScript.from_json(LayoutOverridesScript.to_json(document))
	var root: Node2D = auto_free(_build_scene()) as Node2D
	LayoutOverridesScript.apply_to_scene(root, document)
	for path: String in ["Dressing/SoftDetails/MoveMe", "Dressing/SoftDetails/AddedSprite"]:
		var sprite: Sprite2D = root.get_node(path) as Sprite2D
		assert_bool(sprite.transform.is_equal_approx(original.transform)).is_true()
		assert_vector(sprite.offset).is_equal(original.offset)
		assert_bool(sprite.centered).is_false()
		assert_int(sprite.hframes).is_equal(2)
		assert_int(sprite.vframes).is_equal(2)
		assert_int(sprite.frame).is_equal(2)
		assert_bool(sprite.flip_h).is_true()
		assert_bool(LayoutOverridesScript.is_grayscale(sprite)).is_true()


func test_duplicate_capture_refuses_structures_that_cannot_round_trip() -> void:
	var root: Node2D = auto_free(_build_scene()) as Node2D
	var multi: StaticBody2D = _make_solid("Multi")
	root.get_node("Dressing/SolidProps").add_child(multi)
	LayoutOverridesScript.find_sprite(multi).texture = load(TEST_TEXTURE) as Texture2D
	multi.add_child(Sprite2D.new())
	assert_bool(LayoutOverridesScript.supports_addition(multi, &"SolidProps")).is_false()
	assert_bool(LayoutOverridesScript.capture_addition(multi, &"SolidProps").is_empty()).is_true()
	var circular: StaticBody2D = _make_solid("Circular")
	root.get_node("Dressing/SolidProps").add_child(circular)
	LayoutOverridesScript.find_sprite(circular).texture = load(TEST_TEXTURE) as Texture2D
	LayoutOverridesScript.find_collision(circular).shape = CircleShape2D.new()
	assert_bool(LayoutOverridesScript.capture_addition(circular, &"SolidProps").is_empty()).is_true()
	var custom: Sprite2D = auto_free(Sprite2D.new()) as Sprite2D
	custom.texture = load(TEST_TEXTURE) as Texture2D
	custom.material = ShaderMaterial.new()
	assert_bool(LayoutOverridesScript.capture_addition(custom, &"SoftDetails").is_empty()).is_true()
	var wrapper: Node2D = auto_free(Node2D.new()) as Node2D
	var child := Sprite2D.new()
	child.texture = load(TEST_TEXTURE) as Texture2D
	wrapper.add_child(child)
	assert_bool(LayoutOverridesScript.capture_addition(wrapper, &"SoftDetails").is_empty()).is_true()


func test_atomic_save_preserves_previous_bytes_when_promotion_fails() -> void:
	var path: String = "user://layout_overrides/unit_atomic_save_%d.json" % Time.get_ticks_usec()
	var original: Dictionary = LayoutOverridesScript.create_document("res://world/test_room.tscn")
	original["edits"] = [{"path": "Dressing/SoftDetails/MoveMe", "position": [1.0, 2.0]}]
	assert_int(LayoutOverridesScript.save_file(path, original)).is_equal(OK)
	var previous_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var updated: Dictionary = original.duplicate(true)
	updated["edits"][0]["position"] = [30.0, 40.0]
	var attempted_paths: Array[String] = []
	var reject_promotion: Callable = func(temporary: String, destination: String) -> Error:
		attempted_paths.append(temporary)
		assert_str(destination).is_equal(ProjectSettings.globalize_path(path))
		assert_str(temporary.get_base_dir()).is_equal(destination.get_base_dir())
		assert_dict(LayoutOverridesScript.load_file(temporary)).is_equal(updated)
		assert_array(FileAccess.get_file_as_bytes(destination)).is_equal(previous_bytes)
		return ERR_CANT_CREATE

	assert_int(LayoutOverridesScript.save_file(path, updated, reject_promotion)).is_equal(ERR_CANT_CREATE)
	assert_array(FileAccess.get_file_as_bytes(path)).is_equal(previous_bytes)
	assert_int(attempted_paths.size()).is_equal(1)
	assert_bool(FileAccess.file_exists(attempted_paths[0])).is_false()
	assert_int(LayoutOverridesScript.save_file(path, updated)).is_equal(OK)
	assert_dict(LayoutOverridesScript.load_file(path)).is_equal(updated)
	assert_str(FileAccess.get_file_as_string(path)).is_equal(LayoutOverridesScript.to_json(updated))
	assert_int(DirAccess.remove_absolute(ProjectSettings.globalize_path(path))).is_equal(OK)


func test_duplicate_reload_preserves_root_and_child_canvas_settings() -> void:
	var root: Node2D = auto_free(_build_scene()) as Node2D
	for layer: StringName in [&"SoftDetails", &"SolidProps"]:
		var original: Node2D = Sprite2D.new() if layer == &"SoftDetails" else _make_solid("CanvasCopy")
		original.name = "CanvasCopy"
		root.get_node("Dressing/" + String(layer)).add_child(original)
		var sprite: Sprite2D = LayoutOverridesScript.find_sprite(original)
		sprite.texture = load(TEST_TEXTURE) as Texture2D
		var canvas_settings := {
			"modulate": Color(0.5, 0.75, 1.0, 0.5), "self_modulate": Color(1.0, 0.5, 0.25, 0.75),
			"visible": false, "z_index": -7, "z_as_relative": false, "show_behind_parent": true,
			"y_sort_enabled": true, "light_mask": 5, "visibility_layer": 3,
			"texture_filter": CanvasItem.TEXTURE_FILTER_NEAREST,
			"texture_repeat": CanvasItem.TEXTURE_REPEAT_ENABLED,
		}
		for field: String in canvas_settings:
			original.set(field, canvas_settings[field])
		if sprite != original:
			sprite.z_index = 11
			sprite.z_as_relative = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.modulate = Color(0.75, 0.5, 0.25, 1.0)
		var document: Dictionary = LayoutOverridesScript.create_document("res://world/test_room.tscn")
		document["additions"] = [LayoutOverridesScript.capture_addition(original, layer)]
		document = LayoutOverridesScript.from_json(LayoutOverridesScript.to_json(document))
		var fresh: Node2D = auto_free(_build_scene()) as Node2D
		LayoutOverridesScript.apply_to_scene(fresh, document)
		var restored: Node2D = fresh.get_node("Dressing/" + String(layer) + "/CanvasCopy") as Node2D
		for field: String in canvas_settings:
			assert_bool(restored.get(field) == original.get(field)) \
				.override_failure_message("Root canvas property lost: %s (%s)" % [field, layer]).is_true()
		var restored_sprite: Sprite2D = LayoutOverridesScript.find_sprite(restored)
		assert_int(restored_sprite.z_index).is_equal(sprite.z_index)
		assert_bool(restored_sprite.z_as_relative).is_equal(sprite.z_as_relative)
		assert_int(restored_sprite.texture_filter).is_equal(sprite.texture_filter)
		assert_bool(restored_sprite.modulate == sprite.modulate).is_true()


func test_duplicate_reload_preserves_static_body_collision_settings() -> void:
	var root: Node2D = auto_free(_build_scene()) as Node2D
	var original: StaticBody2D = _make_solid("BodyCopy")
	root.get_node("Dressing/SolidProps").add_child(original)
	LayoutOverridesScript.find_sprite(original).texture = load(TEST_TEXTURE) as Texture2D
	original.collision_layer = 8
	original.collision_mask = 16
	original.collision_priority = 2.0
	original.constant_linear_velocity = Vector2(4, -8)
	original.constant_angular_velocity = 0.5
	original.input_pickable = false
	original.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	var document: Dictionary = LayoutOverridesScript.create_document("res://world/test_room.tscn")
	document["additions"] = [LayoutOverridesScript.capture_addition(original, &"SolidProps")]
	document = LayoutOverridesScript.from_json(LayoutOverridesScript.to_json(document))
	var fresh: Node2D = auto_free(_build_scene()) as Node2D
	LayoutOverridesScript.apply_to_scene(fresh, document)
	var restored: StaticBody2D = fresh.get_node("Dressing/SolidProps/BodyCopy") as StaticBody2D
	assert_int(restored.collision_layer).is_equal(8)
	assert_int(restored.collision_mask).is_equal(16)
	assert_float(restored.collision_priority).is_equal(2.0)
	assert_vector(restored.constant_linear_velocity).is_equal(Vector2(4, -8))
	assert_float(restored.constant_angular_velocity).is_equal(0.5)
	assert_bool(restored.input_pickable).is_false()
	assert_int(restored.disable_mode).is_equal(CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE)
	original.physics_material_override = PhysicsMaterial.new()
	assert_bool(LayoutOverridesScript.supports_addition(original, &"SolidProps")).is_false()
	assert_bool(LayoutOverridesScript.capture_addition(original, &"SolidProps").is_empty()).is_true()


func _build_scene() -> Node2D:
	var root := Node2D.new()
	root.name = "TestScene"
	var dressing := Node2D.new()
	dressing.name = "Dressing"
	root.add_child(dressing)

	var ground := Node2D.new()
	ground.name = "GroundDetails"
	ground.z_index = -2
	dressing.add_child(ground)
	var delete_me := Sprite2D.new()
	delete_me.name = "DeleteMe"
	ground.add_child(delete_me)

	var soft := Node2D.new()
	soft.name = "SoftDetails"
	soft.y_sort_enabled = true
	dressing.add_child(soft)
	var move_me := Sprite2D.new()
	move_me.name = "MoveMe"
	soft.add_child(move_me)

	var solid := Node2D.new()
	solid.name = "SolidProps"
	solid.y_sort_enabled = true
	dressing.add_child(solid)
	return root
