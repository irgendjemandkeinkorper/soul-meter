extends GdUnitTestSuite
## Party followers are presentation-only actors driven by the player's sampled
## route. These tests load the real field scenes and step real physics frames.

var _original_party: Array[PartyMember] = []


func before_test() -> void:
	_original_party = GameState.party.duplicate()


func after_test() -> void:
	GameState.set_party(_original_party)
	get_tree().paused = false


func test_field_scene_spawns_followers_and_tracks_the_players_breadcrumbs() -> void:
	_set_companion_count(2)
	var runner := scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(2)
	var manager := runner.find_child("PartyFollowers", true, false) as PartyFollowers
	var player := runner.find_child("Player", true, false) as Node2D

	assert_object(manager).is_not_null()
	assert_int(manager.follower_count()).is_equal(2)
	assert_str(manager.followers()[0].party_member.id).is_equal("serai-lun")
	assert_str(manager.followers()[1].party_member.id).is_equal("old-grumbrand")
	var follower_node: Node = manager.followers()[0]
	assert_bool(follower_node is CollisionObject2D).is_false()
	assert_object(follower_node.find_child("CollisionShape2D", true, false)).is_null()

	var start := player.global_position
	runner.simulate_action_press("move_right")
	await _wait_physics_frames(40)
	runner.simulate_action_release("move_right")
	runner.simulate_action_press("move_down")
	await _wait_physics_frames(8)
	runner.simulate_action_release("move_down")
	await _wait_physics_frames(1)

	# The second target is old enough to remain on the horizontal leg instead
	# of cutting diagonally across the right-angle route.
	var corner_target := manager.trail_target_for(1)
	assert_float(corner_target.y).is_equal_approx(start.y, 12.0)
	assert_float(corner_target.x).is_greater(start.x)
	assert_float(corner_target.x).is_less(player.global_position.x)

	var follower := manager.followers()[1]
	follower.global_position = corner_target + Vector2(0, 120)
	var distance_before := follower.global_position.distance_to(corner_target)
	await _wait_physics_frames(24)
	var distance_after := follower.global_position.distance_to(manager.trail_target_for(1))
	assert_float(distance_after).is_less(distance_before)
	assert_float(distance_after).is_less_equal(2.0)


func test_party_changed_adds_and_removes_followers_without_reloading() -> void:
	_set_companion_count(1)
	var runner := scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(2)
	var manager := runner.find_child("PartyFollowers", true, false) as PartyFollowers
	assert_int(manager.follower_count()).is_equal(1)

	var candidates: Array[PartyMember] = GameState.recruitable_candidates()
	GameState.set_party([_lead(), candidates[0], candidates[1]])
	await runner.simulate_frames(2)
	assert_int(manager.follower_count()).is_equal(2)

	GameState.set_party([_lead(), candidates[1]])
	await runner.simulate_frames(2)
	assert_int(manager.follower_count()).is_equal(1)
	assert_str(manager.followers()[0].party_member.id).is_equal("old-grumbrand")

	# Replacing party data for the same identity keeps the field actor but
	# refreshes the resource and its shared portrait.
	var retained_follower := manager.followers()[0]
	var replacement := PartyMember.new()
	replacement.id = candidates[1].id
	replacement.display_name = candidates[1].display_name
	var replacement_portrait := GradientTexture1D.new()
	replacement.portrait = replacement_portrait
	GameState.set_party([_lead(), replacement])
	await runner.simulate_frames(2)
	assert_bool(manager.followers()[0] == retained_follower).is_true()
	assert_bool(manager.followers()[0].party_member == replacement).is_true()
	var sprite := manager.followers()[0].get_node("Visual/Sprite2D") as Sprite2D
	assert_bool(sprite.texture == replacement_portrait).is_true()


func test_sway_is_tunable_and_phase_offset_per_follower() -> void:
	_set_companion_count(2)
	var runner := scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(2)
	var manager := runner.find_child("PartyFollowers", true, false) as PartyFollowers
	var first := manager.followers()[0]
	var second := manager.followers()[1]

	assert_float(first.sway_amplitude).is_equal(1.5)
	assert_float(first.sway_period).is_equal(1.25)
	assert_float(first.sway_rotation_degrees).is_equal(0.75)
	assert_float(first.sway_phase).is_not_equal(second.sway_phase)
	var first_sprite := first.get_node("Visual/Sprite2D") as Sprite2D
	first.follow_trail(first.global_position + Vector2.LEFT * 10.0, 1.0)
	assert_float(first.facing_direction.x).is_less(0.0)
	assert_bool(first_sprite.flip_h).is_true()
	first.follow_trail(first.global_position + Vector2.RIGHT * 10.0, 1.0)
	assert_float(first.facing_direction.x).is_greater(0.0)
	assert_bool(first_sprite.flip_h).is_false()
	await runner.simulate_frames(1)
	var first_visual := first.get_node("Visual") as Node2D
	var second_visual := second.get_node("Visual") as Node2D
	assert_float(first_visual.position.y).is_not_equal(second_visual.position.y)


func test_starting_town_wires_the_same_party_followers() -> void:
	_set_companion_count(2)
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(2)
	var manager := runner.find_child("PartyFollowers", true, false) as PartyFollowers
	assert_object(manager).is_not_null()
	assert_int(manager.follower_count()).is_equal(2)


func _set_companion_count(count: int) -> void:
	var members: Array[PartyMember] = [_lead()]
	var candidates: Array[PartyMember] = GameState.recruitable_candidates()
	for index in mini(count, candidates.size()):
		members.append(candidates[index])
	GameState.set_party(members)


func _lead() -> PartyMember:
	var lead: PartyMember = GameState.protagonist()
	if lead != null:
		return lead
	lead = PartyMember.new()
	lead.id = GameState.PROTAGONIST_ID
	lead.display_name = GameState.PROTAGONIST_NAME
	return lead


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().physics_frame
