extends GdUnitTestSuite
## The ground blend (world/ground_blend.gd, owner ruling 2026-11-03, item 35): which ground art
## blends, that each slab's face table fits its file, and what `apply()` gives a map's layers.
## The look itself is judged on rendered frames (docs/qa/ground-blend-2026-11-03/), not here.

const WATER := GroundBlend.WORLD + "loamroot-grove/loamroot-grove--water.png"
const PUDDLE := GroundBlend.WORLD + "dom-puddle--shallow.png"
const TUFT := GroundBlend.WORLD + "dom-grass-tuft--decorative.png"
const MEMORIAL := GroundBlend.WORLD + "dorthkor-road/dorthkor-road--memorial.png"


func _root(with_backdrop: bool) -> Node2D:
	var root := auto_free(Node2D.new()) as Node2D
	add_child(root)
	if with_backdrop:
		var backdrop := Sprite2D.new()
		backdrop.name = GroundBlend.BACKDROP
		backdrop.texture = load(
			"res://assets/generated/backgrounds/world/loamroot-wilds-terrain-v1.png"
		) as Texture2D
		backdrop.position = Vector2(1500, 900)
		backdrop.scale = Vector2(1.6, 1.6)
		root.add_child(backdrop)
	var dressing := Node2D.new()
	dressing.name = "Dressing"
	root.add_child(dressing)
	var ground := Node2D.new()
	ground.name = GroundBlend.LAYER
	dressing.add_child(ground)
	var soft := Node2D.new()
	soft.name = "SoftDetails"
	dressing.add_child(soft)
	return root


func _sprite(parent: Node, path: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(path) as Texture2D
	parent.add_child(sprite)
	return sprite


func test_every_face_fits_its_file_and_runs_left_front_right_back() -> void:
	for path: String in GroundBlend.FACES:
		var texture := load(path) as Texture2D
		assert_object(texture).override_failure_message("%s does not load" % path).is_not_null()
		var face: Array = GroundBlend.FACES[path]
		assert_int(face.size()).override_failure_message("%s: four corners" % path).is_equal(4)
		var frame := Rect2(Vector2.ZERO, texture.get_size())
		var area := 0.0
		for index in face.size():
			var corner: Vector2 = face[index]
			assert_bool(frame.has_point(corner)).override_failure_message(
				"%s: corner %s lies outside the file" % [path, corner]
			).is_true()
			area += corner.cross(face[(index + 1) % face.size()])
		# Left, front, right, back runs counter-clockwise on screen (y down): a negative shoelace
		# sum. The shader's edge distances are positive inside only in that order.
		assert_float(area).override_failure_message(
			"%s: the corners must run left, front, right, back" % path
		).is_less(0.0)


func test_slabs_and_flat_ground_blend_but_standing_art_keeps_its_colours() -> void:
	assert_bool(GroundBlend.blends(load(WATER) as Texture2D)).is_true()
	assert_bool(GroundBlend.blends(load(PUDDLE) as Texture2D)).is_true()
	assert_bool(GroundBlend.blends(load(MEMORIAL) as Texture2D)).is_true()
	assert_bool(GroundBlend.blends(load(TUFT) as Texture2D)).is_false()
	assert_bool(GroundBlend.blends(null)).is_false()


func test_apply_masks_slabs_tones_flat_ground_and_leaves_other_layers() -> void:
	var root := _root(true)
	var ground := root.get_node("Dressing/" + GroundBlend.LAYER)
	var water := _sprite(ground, WATER)
	var water_again := _sprite(ground, WATER)
	var puddle := _sprite(ground, PUDDLE)
	var memorial := _sprite(ground, MEMORIAL)
	var tuft := _sprite(ground, TUFT)
	var soft_water := _sprite(root.get_node("Dressing/SoftDetails"), WATER)

	assert_int(GroundBlend.apply(root)).is_equal(4)

	var slab := water.material as ShaderMaterial
	assert_object(slab).is_not_null()
	assert_object(water_again.material).override_failure_message(
		"sprites of one file share one material"
	).is_same(slab)
	assert_bool(slab.get_shader_parameter("mask_face")).is_true()
	assert_bool(slab.get_shader_parameter("has_backdrop")).is_true()
	assert_float(slab.get_shader_parameter("tone")).is_equal(GroundBlend.TONE)
	var flat := puddle.material as ShaderMaterial
	assert_bool(flat.get_shader_parameter("mask_face")).is_false()
	assert_float(flat.get_shader_parameter("tone")).is_equal(GroundBlend.FLAT_TONE)
	# A shrine stands on the memorial slab: it takes the tone but keeps its whole picture.
	assert_bool((memorial.material as ShaderMaterial).get_shader_parameter("mask_face")).is_false()
	assert_object(tuft.material).is_null()
	assert_object(soft_water.material).is_null()


func test_without_a_backdrop_only_the_masks_apply() -> void:
	var root := _root(false)
	var water := _sprite(root.get_node("Dressing/" + GroundBlend.LAYER), WATER)
	GroundBlend.apply(root)
	var material := water.material as ShaderMaterial
	assert_bool(material.get_shader_parameter("mask_face")).is_true()
	assert_bool(material.get_shader_parameter("has_backdrop")).is_false()


func test_backdrop_uv_maps_the_backdrop_corners_to_zero_and_one() -> void:
	var root := _root(true)
	var backdrop := root.get_node(GroundBlend.BACKDROP) as Sprite2D
	var to_uv := GroundBlend.backdrop_uv(backdrop)
	var rect := backdrop.global_transform * backdrop.get_rect()
	assert_vector(to_uv * rect.position).is_equal_approx(Vector2.ZERO, Vector2(0.0001, 0.0001))
	assert_vector(to_uv * rect.end).is_equal_approx(Vector2.ONE, Vector2(0.0001, 0.0001))
