extends GdUnitTestSuite
## InteractionFocus's rule: a threshold outranks world targets; among equals the nearest takes E.

var _player: Node2D


func before_test() -> void:
	InteractionFocus._in_range.clear()
	_player = _target(Vector2.ZERO)


func after_test() -> void:
	InteractionFocus._in_range.clear()
	InteractionFocus._player = null


func test_the_nearest_world_target_takes_interact() -> void:
	var near := _target(Vector2(30, 0))
	var far := _target(Vector2(90, 0))
	InteractionFocus.set_in_range(far, _player, true, InteractionFocus.Tier.WORLD)
	InteractionFocus.set_in_range(near, _player, true, InteractionFocus.Tier.WORLD)
	assert_bool(InteractionFocus.takes_interact(near)).is_true()
	assert_bool(InteractionFocus.takes_interact(far)).is_false()
	assert_bool(InteractionFocus.is_outranked(far)).is_false()


func test_a_threshold_outranks_a_nearer_world_target_and_hides_its_prompt() -> void:
	var townsperson := _target(Vector2(10, 0))
	var door := _target(Vector2(40, 0))
	InteractionFocus.set_in_range(townsperson, _player, true, InteractionFocus.Tier.WORLD)
	InteractionFocus.set_in_range(door, _player, true, InteractionFocus.Tier.THRESHOLD)
	assert_bool(InteractionFocus.takes_interact(door)).is_true()
	assert_bool(InteractionFocus.takes_interact(townsperson)).is_false()
	assert_bool(InteractionFocus.is_outranked(townsperson)).is_true()


func test_leaving_the_threshold_hands_interact_back() -> void:
	var townsperson := _target(Vector2(10, 0))
	var door := _target(Vector2(40, 0))
	InteractionFocus.set_in_range(townsperson, _player, true, InteractionFocus.Tier.WORLD)
	InteractionFocus.set_in_range(door, _player, true, InteractionFocus.Tier.THRESHOLD)
	InteractionFocus.set_in_range(door, _player, false, InteractionFocus.Tier.THRESHOLD)
	assert_bool(InteractionFocus.takes_interact(townsperson)).is_true()
	assert_bool(InteractionFocus.is_outranked(townsperson)).is_false()


func test_a_freed_target_drops_out() -> void:
	var townsperson := _target(Vector2(10, 0))
	var door := _target(Vector2(40, 0))
	InteractionFocus.set_in_range(townsperson, _player, true, InteractionFocus.Tier.WORLD)
	InteractionFocus.set_in_range(door, _player, true, InteractionFocus.Tier.THRESHOLD)
	remove_child(door)
	door.free()
	assert_bool(InteractionFocus.takes_interact(townsperson)).is_true()


func test_a_target_outside_the_focus_keeps_its_own_handling() -> void:
	# Not registered: an older caller or a double that sets its own in-range flag.
	assert_bool(InteractionFocus.takes_interact(_target(Vector2(5, 0)))).is_true()


func _target(at: Vector2) -> Node2D:
	var node := auto_free(Node2D.new()) as Node2D
	add_child(node)
	node.global_position = at
	return node
