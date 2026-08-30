extends GdUnitTestSuite

const TOWN_SCENE_PATH := "res://world/starting_town.tscn"
const AMBIENT_VILLAGER_GROUP := &"ambient_villager"
const WAYPOINTS_PROPERTY := &"local_waypoints"
const SIMULATED_FRAME_CAP := 360
const BOUNDS_TOLERANCE := 1.0


func test_starting_town_instantiates_headless_without_errors() -> void:
	var runner := scene_runner(TOWN_SCENE_PATH)
	await runner.simulate_frames(2)

	var town: Node = runner.scene()
	assert_object(town).is_not_null()
	if town != null:
		assert_str(town.scene_file_path).is_equal(TOWN_SCENE_PATH)


func test_ambient_villagers_stay_within_authored_waypoint_bounds() -> void:
	var runner := scene_runner(TOWN_SCENE_PATH)

	var grouped_nodes: Array[Node] = get_tree().get_nodes_in_group(AMBIENT_VILLAGER_GROUP)
	assert_int(grouped_nodes.size()) \
		.override_failure_message("The starting town must contain 6-9 grouped ambient villagers.") \
		.is_between(6, 9)

	var observations: Array[Dictionary] = []
	for grouped_node: Node in grouped_nodes:
		var villager := grouped_node as Node2D
		var waypoints_value: Variant = _property_value(grouped_node, WAYPOINTS_PROPERTY)
		var has_authored_waypoints := typeof(waypoints_value) == TYPE_PACKED_VECTOR2_ARRAY
		var configured_correctly := villager != null and has_authored_waypoints
		var authored_bounds := Rect2()

		assert_object(villager) \
			.override_failure_message("Grouped ambient villager %s must be a Node2D." % grouped_node.name) \
			.is_not_null()
		assert_bool(has_authored_waypoints) \
			.override_failure_message(
				"Grouped ambient villager %s must export local_waypoints as PackedVector2Array."
				% grouped_node.name
			) \
			.is_true()

		if configured_correctly:
			var waypoints: PackedVector2Array = waypoints_value
			configured_correctly = waypoints.size() >= 2 and waypoints.size() <= 4
			assert_int(waypoints.size()) \
				.override_failure_message(
					"Ambient villager %s must have 2-4 authored waypoints." % grouped_node.name
				) \
				.is_between(2, 4)
			if not waypoints.is_empty():
				authored_bounds = _authored_world_bounds(villager.position, waypoints)

		observations.append({
			"villager": villager,
			"bounds": authored_bounds,
			"remained_in_bounds": configured_correctly,
		})

	for _frame_index: int in range(SIMULATED_FRAME_CAP):
		await runner.simulate_frames(1)
		for observation: Dictionary in observations:
			var villager: Node2D = observation["villager"] as Node2D
			var authored_bounds: Rect2 = observation["bounds"]
			var remained_in_bounds: bool = bool(observation["remained_in_bounds"])
			if not remained_in_bounds:
				continue
			observation["remained_in_bounds"] = (
				is_instance_valid(villager)
				and authored_bounds.has_point(villager.position)
			)

	# gdUnit assertions do not abort a test, so every villager receives an
	# unconditional final assertion after the capped simulation loop.
	var all_villagers_remained_in_bounds := not observations.is_empty()
	for observation: Dictionary in observations:
		var villager: Node2D = observation["villager"] as Node2D
		var villager_name := "freed ambient villager"
		if is_instance_valid(villager):
			villager_name = String(villager.name)
		all_villagers_remained_in_bounds = (
			all_villagers_remained_in_bounds
			and bool(observation["remained_in_bounds"])
		)
		assert_bool(bool(observation["remained_in_bounds"])) \
			.override_failure_message(
				"%s left its authored waypoint bounds within %d simulated frames."
				% [villager_name, SIMULATED_FRAME_CAP]
			) \
			.is_true()
	assert_bool(all_villagers_remained_in_bounds) \
		.override_failure_message(
			"Every grouped ambient villager must remain within its authored bounds."
		) \
		.is_true()


func _authored_world_bounds(
		instance_origin: Vector2,
		waypoints: PackedVector2Array,
) -> Rect2:
	var minimum := instance_origin + waypoints[0]
	var maximum := minimum
	for waypoint: Vector2 in waypoints:
		var world_waypoint := instance_origin + waypoint
		minimum = minimum.min(world_waypoint)
		maximum = maximum.max(world_waypoint)
	return Rect2(minimum, maximum - minimum).grow(BOUNDS_TOLERANCE)


func _property_value(node: Node, property_name: StringName) -> Variant:
	for property: Dictionary in node.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return node.get(property_name)
	return null
