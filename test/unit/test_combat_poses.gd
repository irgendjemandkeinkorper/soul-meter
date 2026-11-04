extends GdUnitTestSuite
## Poses on the current art (combat polish slice 4, owner 2026-11-02 "motion on current art"):
## the overlay moves a body's Sprite2D, never the body, and every pose but the slump ends on
## the sprite's resting transform. Reduced motion poses nothing.

const BASE_POSITION := Vector2(0, -12)
const BASE_SCALE := Vector2(0.44, 0.44)

var _reduced_before: Variant = false


func before_test() -> void:
	_reduced_before = GameState.get_setting("accessibility", "reduced_motion", false)
	GameState.set_setting("accessibility", "reduced_motion", false)


func after_test() -> void:
	GameState.set_setting("accessibility", "reduced_motion", _reduced_before)


func test_a_strike_leans_the_attacker_and_knocks_the_target_back_then_both_rest() -> void:
	var duel := _duel()
	var overlay := duel["overlay"] as CombatOverlay
	var attacker_sprite := _sprite(duel["ally"])
	var target_sprite := _sprite(duel["enemy"])
	overlay.consume_event(_strike(&"ally", &"enemy", 5, 44, 13))
	# Track the peak over the beat rather than one instant: under a loaded test run a frame can
	# step past a short tween, so a single sample is timing luck.
	var lean := 0.0
	var recoil := 0.0
	var deadline := Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < deadline:
		lean = maxf(lean, absf(attacker_sprite.rotation))
		recoil = maxf(recoil, target_sprite.position.distance_to(BASE_POSITION))
		await get_tree().process_frame
	assert_float(lean).override_failure_message("the attacker leans").is_greater(0.02)
	assert_float(recoil).override_failure_message("the target recoils").is_greater(1.0)
	await _await_presented(overlay)
	await get_tree().create_timer(DS.DUR_SLOW * 2.0).timeout
	_assert_at_rest(attacker_sprite)
	_assert_at_rest(target_sprite)
	assert_vector((duel["ally"] as Node2D).global_position).is_equal((duel["grid"] as IsoGrid).cell_to_world(Vector2i(0, 0)))
	assert_vector((duel["enemy"] as Node2D).global_position).is_equal((duel["grid"] as IsoGrid).cell_to_world(Vector2i(1, 0)))


func test_a_walk_hops_once_per_cell_and_lands_at_rest() -> void:
	var duel := _duel()
	var overlay := duel["overlay"] as CombatOverlay
	var sprite := _sprite(duel["ally"])
	var walk := _event(&"action_resolved", &"ally", &"", 44, 18)
	walk.data["snapshot"]["allies"][0]["position"] = &"c:0,2,0"
	walk.data["path_cells"] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	overlay.consume_event(walk)
	var highest := 0.0
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline:
		highest = maxf(highest, BASE_POSITION.y - sprite.position.y)
		await get_tree().process_frame
	assert_float(highest).override_failure_message("the sprite hops").is_greater(2.0)
	_assert_at_rest(sprite)


func test_a_downed_body_slumps_and_stands_again_when_revived() -> void:
	var duel := _duel()
	var overlay := duel["overlay"] as CombatOverlay
	var sprite := _sprite(duel["enemy"])
	overlay.consume_event(_strike(&"ally", &"enemy", 18, 44, 0))
	await _await_presented(overlay)
	await get_tree().create_timer(DS.DUR_SLOW + 0.1).timeout
	assert_float(absf(sprite.rotation)).override_failure_message("the body slumps").is_greater(0.2)
	assert_float(sprite.position.y).is_greater(BASE_POSITION.y)

	overlay.consume_event(_event(&"battle_snapshot", &"", &"", 44, 6))
	await _await_presented(overlay)
	_assert_at_rest(sprite)


func test_reduced_motion_poses_nothing() -> void:
	GameState.set_setting("accessibility", "reduced_motion", true)
	var duel := _duel()
	var overlay := duel["overlay"] as CombatOverlay
	var attacker_sprite := _sprite(duel["ally"])
	var target_sprite := _sprite(duel["enemy"])
	overlay.consume_event(_strike(&"ally", &"enemy", 18, 44, 0))
	for _frame: int in 20:
		_assert_at_rest(attacker_sprite)
		_assert_at_rest(target_sprite)
		await get_tree().process_frame


func test_leaving_the_fight_stands_every_body_back_up() -> void:
	var duel := _duel()
	var overlay := duel["overlay"] as CombatOverlay
	var sprite := _sprite(duel["enemy"])
	overlay.consume_event(_strike(&"ally", &"enemy", 18, 44, 0))
	await _await_presented(overlay)
	await get_tree().create_timer(DS.DUR_SLOW + 0.1).timeout
	assert_float(absf(sprite.rotation)).is_greater(0.2)
	remove_child(overlay)
	_assert_at_rest(sprite)


func _assert_at_rest(sprite: Sprite2D) -> void:
	assert_vector(sprite.position).is_equal_approx(BASE_POSITION, Vector2(0.01, 0.01))
	assert_float(sprite.rotation).is_equal_approx(0.0, 0.001)
	assert_vector(sprite.scale).is_equal_approx(BASE_SCALE, Vector2(0.001, 0.001))


func _sprite(body: Node2D) -> Sprite2D:
	return body.get_node("Sprite2D") as Sprite2D


func _body() -> Node2D:
	var body := auto_free(Node2D.new()) as Node2D
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.position = BASE_POSITION
	sprite.scale = BASE_SCALE
	body.add_child(sprite)
	add_child(body)
	return body


func _duel() -> Dictionary:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(64, 32)
	tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tiles.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = tiles.tile_size
	source.create_tile(Vector2i.ZERO)
	tiles.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tiles
	for y: int in 3:
		for x: int in 2:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	add_child(ground)
	var grid := IsoGrid.new()
	grid.build(ground)
	var overlay := auto_free(CombatOverlay.new()) as CombatOverlay
	add_child(overlay)
	overlay.bind_grid(grid, ground)
	var ally := _body()
	var enemy := _body()
	overlay.bind_actor(&"ally", ally)
	overlay.bind_actor(&"enemy", enemy)
	overlay.animate_events = false
	overlay.consume_event(_event(&"battle_started", &"", &"", 44, 18))
	overlay.animate_events = true
	return {"overlay": overlay, "grid": grid, "ally": ally, "enemy": enemy}


func _event(type: StringName, actor: StringName, target: StringName, ally_hp: int, enemy_hp: int) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = type
	event.actor_id = actor
	event.target_id = target
	event.data = {"snapshot": {
		"allies": [{"id": &"ally", "display_name": "Vex", "position": &"c:0,0,0", "hp": ally_hp,
			"max_hp": 44, "facing": "e"}],
		"enemies": [{"id": &"enemy", "display_name": "Bog Wight", "position": &"c:1,0,0",
			"hp": enemy_hp, "max_hp": 18, "facing": "w"}],
	}}
	return event


func _strike(actor: StringName, target: StringName, damage: int, ally_hp: int, enemy_hp: int) -> CombatEvent:
	var event := _event(&"action_resolved", actor, target, ally_hp, enemy_hp)
	event.data["damage"] = damage
	event.data["hit"] = true
	return event


func _await_presented(overlay: CombatOverlay, limit_ms: int = 4000) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline and overlay.is_presenting():
		await get_tree().process_frame
