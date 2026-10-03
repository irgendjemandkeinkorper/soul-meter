extends GdUnitTestSuite

const YARD := "res://world/fixtures/structure_yard.tscn"
var _snapshot: Dictionary
var _yard: Node2D


func before_test() -> void:
	_snapshot = SaveGame.capture_runtime_state()
	SaveGame.begin_runtime_sandbox()
	SaveGame.world_structures.from_dict({})
	WorldClock.reset()


func after_test() -> void:
	if is_instance_valid(_yard):
		_yard.free()
	SaveGame.restore_runtime_state(_snapshot)
	SaveGame.end_runtime_sandbox()


func _open_yard() -> void:
	var scene := load(YARD) as PackedScene
	assert_object(scene).is_not_null()
	if scene == null:
		return
	_yard = scene.instantiate()
	add_child(_yard)
	await await_idle_frame()
	await await_physics_frame()


func test_interaction_damage_updates_art_collision_and_navigation_then_survives_reentry() -> void:
	await _open_yard()
	if _yard == null:
		return
	var prop: Node = _yard.get_node("MaintainedBarricade")
	var blocking: TileMapLayer = _yard.get_node("Blocking")
	var ground: TileMapLayer = _yard.get_node("IsometricGround")
	var grid := IsoGrid.new()
	grid.build(ground, blocking)
	var cell := Vector2i(6, 5)
	var untouched := Vector2i(13, 5)
	assert_bool(grid.is_point_solid(cell)).is_true()
	assert_bool(_body_at(ground.to_global(ground.map_to_local(cell)))).is_true()
	# Normal E handler: range, pause, interaction effect and feedback all participate.
	prop._player_in_range = true
	var key := InputEventAction.new()
	key.action = &"interact"
	key.pressed = true
	prop._unhandled_input(key)
	assert_str(SaveGame.world_structures.structure(prop.structure_id).state).is_equal("damaged")
	assert_int(prop.get_node("Sprite2D").frame).is_equal(1)
	assert_bool(grid.is_point_solid(cell)).is_true()
	prop._unhandled_input(key)
	prop._unhandled_input(key)
	await await_physics_frame()
	assert_int(prop.get_node("Sprite2D").frame).is_equal(2)
	assert_int(blocking.get_cell_source_id(cell)).is_equal(-1)
	assert_bool(grid.is_point_solid(cell)).is_false()
	assert_bool(grid.is_point_solid(untouched)).is_true()
	assert_bool(_body_at(ground.to_global(ground.map_to_local(cell)))).is_false()
	var saved := SaveGame.capture_runtime_state()
	_yard.free()
	assert_bool(SaveGame.restore_runtime_state(saved)).is_true()
	await _open_yard()
	assert_int(_yard.get_node("MaintainedBarricade/Sprite2D").frame).is_equal(2)
	assert_int(_yard.get_node("Blocking").get_cell_source_id(cell)).is_equal(-1)


func test_due_repair_waits_for_body_and_follower_then_retries_without_aging_time() -> void:
	await _open_yard()
	if _yard == null:
		return
	var prop: Node = _yard.get_node("MaintainedBarricade")
	var abandoned: Node = _yard.get_node("AbandonedBarricade")
	prop.apply_structure_damage(30)
	abandoned.apply_structure_damage(30)
	var player: Player = _yard.get_node("Player")
	player.set_physics_process(false)
	player.global_position = prop.global_position
	await await_physics_frame()
	WorldClock.advance("structure-fixture")
	WorldClock.advance("structure-fixture")
	assert_str(SaveGame.world_structures.structure(prop.structure_id).state).is_equal("rebuilding")
	assert_int(prop.get_node("Sprite2D").frame).is_equal(3)
	assert_str(prop.interaction_text).contains("waiting for a clear site")
	var follower: PartyFollower = load("res://actors/party_followers/party_follower.tscn").instantiate()
	_yard.add_child(follower)
	follower.global_position = prop.global_position
	player.global_position += Vector2(300, 0)
	await await_physics_frame()
	SaveGame.advance_world_structures()
	assert_str(SaveGame.world_structures.structure(prop.structure_id).state).is_equal("rebuilding")
	follower.global_position += Vector2(300, 0)
	# The live object's retry must finish the due job without a new clock event.
	await await_millis(350)
	assert_int(WorldClock.phase_count).is_equal(2)
	assert_str(SaveGame.world_structures.structure(prop.structure_id).state).is_equal("intact")
	assert_str(SaveGame.world_structures.structure(abandoned.structure_id).state).is_equal("ruined")
	assert_int(prop.get_node("Sprite2D").frame).is_equal(0)
	await await_physics_frame()
	assert_bool(_body_at(prop.global_position)).is_true()


func test_active_field_combat_defers_rebuilding_and_suppresses_interaction() -> void:
	await _open_yard()
	if _yard == null:
		return
	var prop: Node = _yard.get_node("MaintainedBarricade")
	prop.apply_structure_damage(30)
	var field: FieldMap = _yard.get_node("FieldMap")
	field.set_combat_mode(true)
	assert_bool(prop.is_processing_unhandled_input()).is_false()
	WorldClock.advance("structure-fixture")
	WorldClock.advance("structure-fixture")
	assert_str(SaveGame.world_structures.structure(prop.structure_id).state).is_equal("rebuilding")
	field.set_combat_mode(false)
	SaveGame.advance_world_structures()
	assert_str(SaveGame.world_structures.structure(prop.structure_id).state).is_equal("intact")
	assert_bool(prop.is_processing_unhandled_input()).is_true()


func test_fixture_snapshot_restores_damage_and_returns_player_to_saved_position() -> void:
	await _open_yard()
	if _yard == null:
		return
	var prop: Node = _yard.get_node("MaintainedBarricade")
	var player: Player = _yard.get_node("Player")
	player.set_physics_process(false)
	var saved_position := player.global_position
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_F5
	_yard._unhandled_key_input(key)
	prop.apply_structure_damage(30)
	player.global_position = prop.global_position
	player._has_keyboard_step_target = true
	key.physical_keycode = KEY_F9
	_yard._unhandled_key_input(key)
	assert_vector(player.global_position).is_equal(saved_position)
	assert_bool(player._has_keyboard_step_target).is_false()
	assert_str(SaveGame.world_structures.structure(prop.structure_id).state).is_equal("intact")
	assert_int(prop.get_node("Sprite2D").frame).is_equal(0)


func await_physics_frame() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _body_at(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	return not _yard.get_world_2d().direct_space_state.intersect_point(query).is_empty()
