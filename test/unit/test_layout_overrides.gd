extends GdUnitTestSuite

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
