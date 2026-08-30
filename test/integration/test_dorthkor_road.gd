extends GdUnitTestSuite

const SCENE_PATH := "res://world/dorthkor_road.tscn"
const SIMULATED_FRAME_CAP := 360
const MOTION_FRAME_CAP := 240


func test_wave_aa_dorthkor_road_dressing_contract() -> void:
	var runner := scene_runner(SCENE_PATH)
	await runner.simulate_frames(2)

	var road := runner.scene() as Node2D
	assert_object(road).is_not_null()
	if road == null:
		return
	assert_bool(road.y_sort_enabled) \
		.override_failure_message("DorthkorRoad root must y-sort actors with props.") \
		.is_true()

	var dressing := road.get_node_or_null("DorthkorRoadDressing")
	assert_object(dressing).is_not_null()
	var solid_props: Node = null
	if dressing != null:
		assert_int(dressing.get_child_count()) \
			.override_failure_message("DorthkorRoadDressing must contain exactly three layers.") \
			.is_equal(3)
		for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
			var layer := dressing.get_node_or_null(layer_name)
			assert_object(layer) \
				.override_failure_message(
					"DorthkorRoadDressing must keep the %s layer." % layer_name
				) \
				.is_not_null()
			if layer != null:
				assert_int(layer.get_child_count()).is_greater_equal(1)
		solid_props = dressing.get_node_or_null("SolidProps")
		var ground_details := dressing.get_node_or_null("GroundDetails") as Node2D
		var soft_details := dressing.get_node_or_null("SoftDetails") as Node2D
		var solid_layer := solid_props as Node2D
		if ground_details != null:
			assert_int(ground_details.z_index).is_equal(-2)
			assert_bool(ground_details.y_sort_enabled).is_false()
		if soft_details != null:
			assert_bool(soft_details.y_sort_enabled).is_true()
		if solid_layer != null:
			assert_bool(solid_layer.y_sort_enabled).is_true()

	var bodies_with_shapes := 0
	if solid_props != null:
		for prop: Node in solid_props.get_children():
			if prop is StaticBody2D and prop.get_node_or_null("CollisionShape2D") != null:
				bodies_with_shapes += 1
	assert_int(bodies_with_shapes) \
		.override_failure_message("Dorthkor Road must contain at least four collidable solid props.") \
		.is_greater_equal(4)

	var breathing: Array[Node] = []
	if dressing != null:
		_collect_breathing(dressing, breathing)
	assert_int(breathing.size()) \
		.override_failure_message("At least two memorial props must run WOUND_BREATH.") \
		.is_greater_equal(2)
	var breathing_sprite := breathing[0] as Sprite2D if not breathing.is_empty() else null
	var base_modulate := breathing_sprite.modulate if breathing_sprite != null else Color.WHITE

	var travelers: Array[Node2D] = []
	_collect_travelers(road, travelers)
	assert_int(travelers.size()) \
		.override_failure_message("Dorthkor Road must contain exactly two ambient travelers.") \
		.is_equal(2)
	var observations: Array[Dictionary] = []
	for traveler: Node2D in travelers:
		var has_bounds_method := traveler.has_method("authored_world_bounds")
		assert_bool(has_bounds_method) \
			.override_failure_message("%s must expose authored waypoint bounds." % traveler.name) \
			.is_true()
		var bounds := Rect2()
		if has_bounds_method:
			bounds = (traveler.call("authored_world_bounds") as Rect2).grow(1.0)
		observations.append({
			"traveler": traveler,
			"start": traveler.position,
			"bounds": bounds,
			"remained_in_bounds": has_bounds_method and bounds.has_point(traveler.position),
		})

	var any_traveler_moved := false
	var prop_animated := false
	for frame_index: int in range(SIMULATED_FRAME_CAP):
		await runner.simulate_frames(1)
		if frame_index < MOTION_FRAME_CAP and breathing_sprite != null \
				and breathing_sprite.modulate != base_modulate:
			prop_animated = true
		for observation: Dictionary in observations:
			var traveler := observation["traveler"] as Node2D
			if not is_instance_valid(traveler):
				observation["remained_in_bounds"] = false
				continue
			var bounds: Rect2 = observation["bounds"]
			observation["remained_in_bounds"] = (
				bool(observation["remained_in_bounds"])
				and bounds.has_point(traveler.position)
			)
			if traveler.position.distance_to(observation["start"]) > 2.0:
				any_traveler_moved = true

	assert_bool(prop_animated) \
		.override_failure_message("WOUND_BREATH did not change modulate within 240 frames.") \
		.is_true()
	assert_bool(any_traveler_moved) \
		.override_failure_message("Neither Dorthkor traveler moved within 360 frames.") \
		.is_true()
	for observation: Dictionary in observations:
		var traveler := observation["traveler"] as Node2D
		var traveler_name := String(traveler.name) if is_instance_valid(traveler) else "freed traveler"
		assert_bool(bool(observation["remained_in_bounds"])) \
			.override_failure_message(
				"%s left its authored waypoint bounds within 360 frames." % traveler_name
			) \
			.is_true()


func _collect_breathing(node: Node, found: Array[Node]) -> void:
	var script := node.get_script() as GDScript
	if node is Sprite2D and script != null \
			and script.resource_path.ends_with("ambient_prop_motion.gd") \
			and int(node.get("motion_kind")) == AmbientPropMotion.MotionKind.WOUND_BREATH:
		found.append(node)
	for child: Node in node.get_children():
		_collect_breathing(child, found)


func _collect_travelers(node: Node, found: Array[Node2D]) -> void:
	if node is Node2D and node.is_in_group(&"ambient_villager"):
		found.append(node as Node2D)
	for child: Node in node.get_children():
		_collect_travelers(child, found)
