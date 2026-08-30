extends GdUnitTestSuite

const SCENE_PATH := "res://world/wound_lip.tscn"


func test_scene_instantiates_with_gameplay_contract() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	assert_object(packed_scene).is_not_null()

	var wound_lip: Node = auto_free(packed_scene.instantiate())
	add_child(wound_lip)
	await get_tree().process_frame

	assert_bool(wound_lip.is_node_ready()).is_true()
	assert_object(wound_lip.get_node_or_null("Player")).is_not_null()
	assert_object(wound_lip.get_node_or_null("FieldHUD")).is_not_null()
	assert_object(wound_lip.get_node_or_null("LedgeCache")).is_not_null()
	assert_object(wound_lip.get_node_or_null("GuardKit")).is_not_null()
	assert_object(wound_lip.get_node_or_null("ReturnToDom")).is_not_null()
	assert_object(wound_lip.get_node_or_null("CleanedGuard")).is_not_null()
	assert_str(str(wound_lip.get("arrival_flag"))).is_equal("chapter_wound_lip_reached")
	# Walls keep the four boundary collision shapes.
	var walls := wound_lip.get_node_or_null("Walls")
	assert_object(walls).is_not_null()
	if walls != null:
		var wall_shapes := 0
		for child: Node in walls.get_children():
			if child is CollisionShape2D:
				wall_shapes += 1
		assert_int(wall_shapes).is_equal(4)


func test_wave_v_dressing_contract() -> void:
	# Gate r1 required finding: the contract test must fail against the old
	# blockout, not merely against a deleted scene. These assertions pin the
	# Wave V dressing WITHOUT coupling to individual decorative placements.
	var wound_lip: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(wound_lip)
	await get_tree().process_frame

	# Actors and props share the root's painter order (common-parent rule).
	assert_bool((wound_lip as Node2D).y_sort_enabled) \
		.override_failure_message("WoundLip root must y-sort actors with props.") \
		.is_true()
	# The player camera is clamped to the authored scene bounds.
	var player := wound_lip.get_node_or_null("Player")
	assert_object(player).is_not_null()
	if player != null:
		assert_object(player.get("camera_bounds")).is_equal(Rect2i(0, 0, 1800, 900))

	var dressing := wound_lip.get_node_or_null("WoundLipDressing")
	assert_object(dressing).is_not_null()
	if dressing == null:
		return
	for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
		var layer := dressing.get_node_or_null(layer_name)
		assert_object(layer) \
			.override_failure_message("WoundLipDressing must keep the %s layer." % layer_name) \
			.is_not_null()
		if layer != null:
			assert_int(layer.get_child_count()).is_greater_equal(1)
	# Solid props physically block movement.
	var solid_props := dressing.get_node_or_null("SolidProps")
	if solid_props != null:
		var bodies_with_shapes := 0
		for prop: Node in solid_props.get_children():
			if prop is StaticBody2D and prop.get_node_or_null("CollisionShape2D") != null:
				bodies_with_shapes += 1
		assert_int(bodies_with_shapes).is_greater_equal(5)
	# The wound breathes: at least one dressing sprite runs WOUND_BREATH and
	# its modulate departs from the base color within a bounded simulation.
	var breathing: Array[Node] = []
	_collect_breathing(dressing, breathing)
	assert_int(breathing.size()) \
		.override_failure_message("At least one seam sprite must run WOUND_BREATH.") \
		.is_greater_equal(1)
	if breathing.is_empty():
		return
	var seam := breathing[0] as Sprite2D
	var base_modulate := seam.modulate
	var moved := false
	for _frame: int in range(240):
		await get_tree().process_frame
		if seam.modulate != base_modulate:
			moved = true
			break
	assert_bool(moved) \
		.override_failure_message("WOUND_BREATH never changed the seam modulate.") \
		.is_true()


func _collect_breathing(node: Node, found: Array[Node]) -> void:
	var script := node.get_script() as GDScript
	if node is Sprite2D and script != null \
			and script.resource_path.ends_with("ambient_prop_motion.gd") \
			and int(node.get("motion_kind")) == AmbientPropMotion.MotionKind.WOUND_BREATH:
		found.append(node)
	for child: Node in node.get_children():
		_collect_breathing(child, found)
