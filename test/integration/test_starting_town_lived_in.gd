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


func test_ambient_villagers_actually_wander_and_props_actually_move() -> void:
	# Gate r1 risk: containment alone would pass with movement disabled. This
	# pins that at least one villager displaces and ambient prop motion mutates
	# rotation or modulate within a bounded simulation.
	var runner := scene_runner(TOWN_SCENE_PATH)
	await runner.simulate_frames(2)

	var grouped_nodes: Array[Node] = get_tree().get_nodes_in_group(AMBIENT_VILLAGER_GROUP)
	assert_int(grouped_nodes.size()).is_greater_equal(1)
	var start_positions: Dictionary = {}
	for grouped_node: Node in grouped_nodes:
		var villager := grouped_node as Node2D
		if villager != null:
			start_positions[villager] = villager.position

	var motion_sprites: Array[Node] = []
	_collect_ambient_motion(runner.scene(), motion_sprites)
	assert_int(motion_sprites.size()) \
		.override_failure_message("The town must contain AmbientPropMotion sprites.") \
		.is_greater_equal(2)
	var motion_start: Dictionary = {}
	for sprite_node: Node in motion_sprites:
		var sprite := sprite_node as Sprite2D
		motion_start[sprite] = {"rotation": sprite.rotation, "modulate": sprite.modulate}

	# Pauses are staggered up to ~6s; 600 physics frames (~10s at 60fps) is a
	# budget, not a wait-until — the asserts below are unconditional.
	var any_villager_moved := false
	var any_prop_animated := false
	for _frame_index: int in range(600):
		await runner.simulate_frames(1)
		for villager: Node2D in start_positions:
			if is_instance_valid(villager) \
					and villager.position.distance_to(start_positions[villager]) > 2.0:
				any_villager_moved = true
		for sprite: Sprite2D in motion_start:
			if not is_instance_valid(sprite):
				continue
			var start: Dictionary = motion_start[sprite]
			if absf(sprite.rotation - float(start["rotation"])) > 0.0005 \
					or sprite.modulate != start["modulate"]:
				any_prop_animated = true
		if any_villager_moved and any_prop_animated:
			break
	assert_bool(any_villager_moved) \
		.override_failure_message("No ambient villager displaced within the frame budget.") \
		.is_true()
	assert_bool(any_prop_animated) \
		.override_failure_message("No AmbientPropMotion sprite changed rotation/modulate.") \
		.is_true()


func _collect_ambient_motion(node: Node, found: Array[Node]) -> void:
	if node is Sprite2D and node.get_script() is GDScript \
			and (node.get_script() as GDScript).resource_path.ends_with("ambient_prop_motion.gd"):
		found.append(node)
	for child: Node in node.get_children():
		_collect_ambient_motion(child, found)
