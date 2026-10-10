extends GdUnitTestSuite


class FieldFixture extends FieldMap:
	var layer: TileMapLayer
	var grid: IsoGrid

	func ground() -> TileMapLayer:
		return layer

	func iso_grid() -> IsoGrid:
		return grid


class RosterField extends FieldFixture:
	var roster: Array[Hostile] = []

	func player() -> Player:
		return null

	func party_followers() -> PartyFollowers:
		return null

	func hostiles() -> Array[Hostile]:
		return roster


func test_region_forwards_frozen_payload_and_picks_transformed_field_cell() -> void:
	var ground := _ground()
	ground.position = Vector2(91, 64)
	var field := auto_free(FieldFixture.new()) as FieldFixture
	field.layer = ground
	field.grid = IsoGrid.new()
	field.grid.build(ground)
	add_child(field)
	var stage := auto_free(
		load("res://ui/hud/regions/stage/battle_stage_region.tscn").instantiate()
	) as BattleStageRegion
	add_child(stage)
	stage.position = Vector2(30, 19)
	stage.bind_field(field)
	var tile := {"x": 1, "y": 0, "height_delta": 2, "note": "unchanged"}
	var event := CombatEvent.new()
	event.type = &"battle_snapshot"
	event.data = {"snapshot": {"tiles": [tile]}}
	stage.consume_event(event)
	var selected: Array[Dictionary] = []
	stage.tile_selected.connect(func(value: Dictionary) -> void: selected.append(value))
	var cell := stage._cell_at(stage.cell_center(Vector2i(1, 0)))
	stage.select_tile(cell)
	assert_vector(cell).is_equal(Vector2i(1, 0))
	assert_array(selected).contains_exactly([tile])
	assert_bool(stage._backdrop.visible).is_false()
	assert_int(stage._unit_nodes.size()).is_equal(0)
	assert_dict(field.combat_overlay().call("tile_at", cell)).is_equal(tile)


func test_projection_uses_transformed_field_grid_and_preserves_tile_payload() -> void:
	var ground := _ground()
	ground.position = Vector2(127, 83)
	ground.scale = Vector2(1.5, 1.5)
	var grid := IsoGrid.new()
	grid.build(ground)
	var overlay := auto_free(Node2D.new()) as Node2D
	overlay.set_script(load("res://world/combat_overlay.gd"))
	add_child(overlay)
	overlay.position = Vector2(-31, 17)
	overlay.call("bind_grid", grid, ground)
	var tile := {"x": 1, "y": 0, "height_delta": 2, "note": "frozen payload"}
	var event := CombatEvent.new()
	event.data = {"snapshot": {"tiles": [tile]}}
	overlay.call("consume_event", event)
	assert_vector(overlay.to_global(overlay.call("cell_center", Vector2i(1, 0)))).is_equal(
		grid.cell_to_world(Vector2i(1, 0))
	)
	assert_dict(overlay.call("tile_at", Vector2i(1, 0))).is_equal(tile)
	var returned: Dictionary = overlay.call("tile_at", Vector2i(1, 0))
	returned["note"] = "changed"
	assert_dict(overlay.call("tile_at", Vector2i(1, 0))).is_equal(tile)


func test_snapshot_moves_existing_actor_and_does_not_create_duplicate_units() -> void:
	var ground := _ground()
	var grid := IsoGrid.new()
	grid.build(ground)
	var overlay := auto_free(Node2D.new()) as Node2D
	overlay.set_script(load("res://world/combat_overlay.gd"))
	add_child(overlay)
	overlay.call("bind_grid", grid, ground)
	var actor := auto_free(Node2D.new()) as Node2D
	add_child(actor)
	overlay.call("bind_actor", &"ally-test", actor)
	var event := CombatEvent.new()
	event.type = &"battle_snapshot"
	event.data = {"snapshot": {"allies": [
		{"id": &"ally-test", "position": &"c:1,0,0", "hp": 9, "max_hp": 10},
	]}}
	overlay.call("consume_event", event)
	assert_vector(actor.global_position).is_equal(grid.cell_to_world(Vector2i(1, 0)))
	assert_int(overlay.get_child_count()).is_equal(0)
	assert_int(actor.get_child_count()).is_equal(0)


## Field nodes are bound when the snapshot roster changes, not on every event, so a hostile
## admitted mid-session must still be bound and placed by the first snapshot that lists it.
func test_hostile_admitted_mid_session_is_bound_by_the_first_snapshot_listing_it() -> void:
	var ground := _ground()
	var field := auto_free(RosterField.new()) as RosterField
	field.layer = ground
	field.grid = IsoGrid.new()
	field.grid.build(ground)
	add_child(field)
	var root: Node2D = auto_free(Node2D.new())
	root.name = "HostileFixture"
	root.scene_file_path = "res://test/fixtures/hostile_field.tscn"
	add_child(root)
	var first := _hostile(root, "First")
	var second := _hostile(root, "Second")
	field.roster = [first]
	var overlay := auto_free(Node2D.new()) as Node2D
	overlay.set_script(load("res://world/combat_overlay.gd"))
	add_child(overlay)
	overlay.call("bind_field", field)
	var opening := CombatEvent.new()
	opening.type = &"battle_snapshot"
	opening.data = {"snapshot": {"enemies": [
		{"id": first.combat_id, "position": &"c:1,0,0", "hp": 9, "max_hp": 10},
	]}}
	overlay.call("consume_event", opening)
	field.roster = [first, second]
	var admitted := CombatEvent.new()
	admitted.type = &"battle_snapshot"
	admitted.data = {"snapshot": {"enemies": [
		{"id": first.combat_id, "position": &"c:1,0,0", "hp": 9, "max_hp": 10},
		{"id": second.combat_id, "position": &"c:0,0,0", "hp": 9, "max_hp": 10},
	]}}
	overlay.call("consume_event", admitted)
	assert_vector(first.global_position).is_equal(field.grid.cell_to_world(Vector2i(1, 0)))
	assert_vector(second.global_position).is_equal(field.grid.cell_to_world(Vector2i.ZERO))


func test_move_survives_followup_snapshot_and_overlay_cleanup_restores_actor_color() -> void:
	var ground := _ground()
	var grid := IsoGrid.new()
	grid.build(ground)
	var overlay := Node2D.new()
	overlay.set_script(load("res://world/combat_overlay.gd"))
	add_child(overlay)
	overlay.call("bind_grid", grid, ground)
	var actor := auto_free(Node2D.new()) as Node2D
	actor.modulate = Color(0.8, 0.7, 0.6, 1)
	add_child(actor)
	var original := actor.modulate
	overlay.call("bind_actor", &"ally-test", actor)
	actor.global_position = grid.cell_to_world(Vector2i.ZERO)
	var event := CombatEvent.new()
	event.type = &"action_resolved"
	event.actor_id = &"ally-test"
	event.data = {
		"path_cells": [Vector2i.ZERO, Vector2i(1, 0)],
		"snapshot": {"allies": [{"id": &"ally-test", "position": &"c:1,0,0", "hp": 9}]},
	}
	overlay.call("consume_event", event)
	var followup := CombatEvent.new()
	followup.type = &"battle_snapshot"
	followup.data = {"snapshot": event.data["snapshot"]}
	overlay.call("consume_event", followup)
	assert_vector(actor.global_position).is_equal(grid.cell_to_world(Vector2i.ZERO))
	await get_tree().create_timer(DS.DUR_FAST + 0.1).timeout
	assert_vector(actor.global_position).is_equal(grid.cell_to_world(Vector2i(1, 0)))
	followup.data["snapshot"]["allies"][0]["hp"] = 0
	overlay.call("consume_event", followup)
	await _await_presented(overlay)
	await get_tree().create_timer(DS.DUR_SLOW * 2.0 + 0.1).timeout
	assert_float(actor.modulate.a).is_less(1)
	overlay.free()
	assert_object(actor).is_not_null()
	assert_bool(actor.modulate.is_equal_approx(original)).is_true()


func test_action_feedback_uses_event_damage_without_changing_actor_state() -> void:
	var ground := _ground()
	var grid := IsoGrid.new()
	grid.build(ground)
	var overlay := auto_free(Node2D.new()) as Node2D
	overlay.set_script(load("res://world/combat_overlay.gd"))
	add_child(overlay)
	overlay.call("bind_grid", grid, ground)
	var attacker := auto_free(Node2D.new()) as Node2D
	var target := auto_free(Node2D.new()) as Node2D
	add_child(attacker)
	add_child(target)
	overlay.call("bind_actor", &"ally", attacker)
	overlay.call("bind_actor", &"enemy", target)
	var event := CombatEvent.new()
	event.type = &"action_resolved"
	event.actor_id = &"ally"
	event.target_id = &"enemy"
	event.data = {"damage": 7, "hit": true, "snapshot": {
		"allies": [{"id": &"ally", "position": &"c:0,0,0", "hp": 10}],
		"enemies": [{"id": &"enemy", "position": &"c:1,0,0", "hp": 3}],
	}}
	var before := event.data.duplicate(true)
	overlay.call("consume_event", event)
	assert_str((overlay.get_node("DamagePop/Column/Outcome") as Label).text).is_equal("7 DAMAGE")
	assert_object(overlay.get_node_or_null("HitPulse")).is_not_null()
	await get_tree().create_timer(DS.DUR_INSTANT).timeout
	assert_float(attacker.global_position.distance_to(grid.cell_to_world(Vector2i.ZERO))).is_less_equal(float(DS.SPACE_4) + 0.01)
	await get_tree().create_timer(DS.DUR_SLOW + 0.1).timeout
	assert_vector(attacker.global_position).is_equal(grid.cell_to_world(Vector2i.ZERO))
	assert_vector(target.global_position).is_equal(grid.cell_to_world(Vector2i(1, 0)))
	# The readable result outlives motion without extending the animation/input gate.
	assert_bool(overlay.call("is_animating")).is_false()
	assert_object(overlay.get_node_or_null("DamagePop")).is_not_null()
	await get_tree().create_timer(2.1).timeout
	assert_int(overlay.get_child_count()).is_equal(0)
	assert_dict(event.data).is_equal(before)
	# Reopening the HUD replays history to restore state; it must not make live
	# actors perform old attacks or lock pointer input again.
	overlay.set("animate_events", false)
	overlay.call("consume_event", event)
	assert_int(overlay.get_child_count()).is_equal(0)
	assert_bool(overlay.call("is_animating")).is_false()
	# Neither a miss nor a zero-damage hit creates the impact mark or target flash.
	overlay.set("animate_events", true)
	for hit: bool in [false, true]:
		event.data["hit"] = hit
		event.data["damage"] = 0
		await _await_presented(overlay)
		overlay.call("consume_event", event)
		assert_object(overlay.get_node_or_null("HitPulse")).is_null()
		assert_dict(overlay.get("_flashes")).is_empty()
		assert_bool(target.modulate.is_equal_approx(Color.WHITE)).is_true()
		await get_tree().create_timer(DS.DUR_SLOW + 0.1).timeout
	# Production strikes carry hit/fizzle in the nested resolution rather than a flat flag.
	event.data.erase("hit")
	for resolution: Dictionary in [{"hit": false}, {"hit": true, "fizzled": true}]:
		event.data["resolution"] = resolution
		await _await_presented(overlay)
		overlay.call("consume_event", event)
		var expected := "FIZZLE" if bool(resolution.get("fizzled", false)) else "MISS"
		assert_str((overlay.get_node("DamagePop/Column/Outcome") as Label).text).is_equal(expected)
		assert_object(overlay.get_node_or_null("HitPulse")).is_null()
		await get_tree().create_timer(DS.DUR_SLOW + 0.1).timeout
	event.data.erase("resolution")
	# A late snapshot reporting a KO cancels an in-flight flash instead of restoring opacity.
	event.data["hit"] = true
	event.data["damage"] = 7
	await _await_presented(overlay)
	overlay.call("consume_event", event)
	var defeated := CombatEvent.new()
	defeated.type = &"battle_snapshot"
	defeated.data = {"snapshot": event.data["snapshot"].duplicate(true)}
	defeated.data["snapshot"]["enemies"][0]["hp"] = 0
	overlay.call("consume_event", defeated)
	# #281 G1/G9: the KO snapshot waits for the strike's beat, then fades the body to the
	# downed tint, which stays clearly visible rather than near-invisible.
	assert_bool(overlay.call("is_presenting")).is_true()
	assert_float(target.modulate.a).is_equal(1.0)
	await _await_presented(overlay)
	await get_tree().create_timer(DS.DUR_INSTANT).timeout
	assert_float(target.modulate.a).is_less(1.0).is_greater(CombatOverlay.KO_TINT.a)
	await get_tree().create_timer(DS.DUR_SLOW * 2.0 + 0.1).timeout
	assert_float(target.modulate.a).is_equal_approx(CombatOverlay.KO_TINT.a, 0.001)
	assert_float(target.modulate.a).is_greater_equal(0.75)


## #281 G1: events behind a beat wait their turn; wait until the overlay has presented them.
func _await_presented(overlay: Node, limit_ms: int = 4000) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline and bool(overlay.call("is_presenting")):
		await get_tree().process_frame


func _ground() -> TileMapLayer:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(64, 32)
	tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = tiles.tile_size
	source.create_tile(Vector2i.ZERO)
	tiles.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tiles
	ground.set_cell(Vector2i.ZERO, 0, Vector2i.ZERO)
	ground.set_cell(Vector2i(1, 0), 0, Vector2i.ZERO)
	add_child(ground)
	return ground


## F1 step 6 camera (D6/D9): the field camera stays on the player until a turn starts for an
## actor that is off-screen; then it pans to that actor for the turn, and returns to the player
## when the fight ends. An enemy turn that begins entirely beyond one screen of margin gets no
## pan and no move tween — that actor snaps (F2 budget).
func test_camera_pans_to_off_screen_active_actor_and_returns_to_the_player_at_the_end() -> void:
	var ground := _ground()
	var grid := IsoGrid.new()
	grid.build(ground)
	var overlay := auto_free(Node2D.new()) as Node2D
	overlay.set_script(load("res://world/combat_overlay.gd"))
	add_child(overlay)
	overlay.set("animate_events", false)
	overlay.call("bind_grid", grid, ground)
	var player := auto_free(Node2D.new()) as Node2D
	add_child(player)
	var camera := Camera2D.new()
	player.add_child(camera)
	var screen := camera.get_viewport_rect().size
	var near_ally := auto_free(Node2D.new()) as Node2D
	var far_enemy := auto_free(Node2D.new()) as Node2D
	add_child(near_ally)
	add_child(far_enemy)
	player.global_position = Vector2.ZERO
	# Just off the right edge of the screen: inside the one-screen margin.
	near_ally.global_position = Vector2(screen.x * 0.8, 0)
	# Ten screens away: beyond the margin.
	far_enemy.global_position = Vector2(screen.x * 10.0, 0)
	overlay.call("bind_actor", &"lead", player)
	overlay.call("bind_actor", &"ally", near_ally)
	overlay.call("bind_actor", &"enemy", far_enemy)
	overlay.call("bind_camera", camera, player)

	var on_screen := CombatEvent.new()
	on_screen.type = &"turn_started"
	on_screen.actor_id = &"lead"
	overlay.call("consume_event", on_screen)
	assert_vector(camera.offset).override_failure_message(
		"an on-screen actor's turn must not move the camera"
	).is_equal(Vector2.ZERO)

	var ally_turn := CombatEvent.new()
	ally_turn.type = &"turn_started"
	ally_turn.actor_id = &"ally"
	overlay.call("consume_event", ally_turn)
	assert_vector(camera.offset).override_failure_message(
		"an off-screen party member's turn pans the camera onto them"
	).is_equal(near_ally.global_position - player.global_position)

	var enemy_turn := CombatEvent.new()
	enemy_turn.type = &"enemy_turn_started"
	enemy_turn.actor_id = &"enemy"
	overlay.call("consume_event", enemy_turn)
	assert_vector(camera.offset).override_failure_message(
		"an enemy turn beyond one screen of margin resolves without a pan"
	).is_equal(near_ally.global_position - player.global_position)
	assert_bool(overlay.call("pans_suppressed_for", &"enemy")).override_failure_message(
		"a far enemy's turn resolves without move tweens"
	).is_true()

	var finished := CombatEvent.new()
	finished.type = &"battle_finished"
	overlay.call("consume_event", finished)
	assert_vector(camera.offset).override_failure_message(
		"the camera returns to the player when the fight ends"
	).is_equal(Vector2.ZERO)
	assert_bool(overlay.call("pans_suppressed_for", &"enemy")).is_false()


func _hostile(root: Node, node_name: String) -> Hostile:
	var hostile := (load("res://actors/hostile/hostile.tscn") as PackedScene).instantiate() as Hostile
	hostile.name = node_name
	hostile.unit_id = &"bog-wight"
	root.add_child(hostile)
	return hostile


## #281 G1/G2/G4: the model resolves the enemy phase in the same frame as the player's strike.
## The overlay must present those events in turn: the player's result card alone (naming who
## acted on whom), the target highlight on the target during that beat, then the enemy's turn
## cue, then the enemy's card replacing the player's, then the next ally turn.
func test_enemy_phase_is_presented_beat_by_beat_after_the_players_strike() -> void:
	var fixture := _duel()
	var overlay: CombatOverlay = fixture.overlay
	var strike := _strike(&"ally", &"enemy", 11, 43, 7)
	var enemy_turn := _event(&"enemy_turn_started", &"enemy", &"", 43, 7)
	var reply := _strike(&"enemy", &"ally", 1, 42, 7)
	var ally_turn := _event(&"turn_started", &"ally", &"", 42, 7)
	for event: CombatEvent in [strike, enemy_turn, reply, ally_turn]:
		overlay.consume_event(event)
	# Beat 1: the player's strike only.
	assert_array(_cards(overlay)).contains_exactly(["Vex → Bog Wight|11 DAMAGE"])
	assert_str(String(overlay._active_id)).is_equal("ally")
	assert_str(String(overlay._target_id)).is_equal("enemy")
	assert_float(overlay._hp_target[&"ally"]).is_equal(43.0)
	assert_bool(overlay.is_presenting()).is_true()
	assert_bool(overlay.is_animating()).override_failure_message(
		"queued enemy beats keep pointer input locked"
	).is_true()
	await get_tree().create_timer(CombatOverlay.BEAT_READ_SECONDS * 0.5).timeout
	assert_array(_cards(overlay)).contains_exactly(["Vex → Bog Wight|11 DAMAGE"])
	# Beat 2: the enemy's turn cue moves the active highlight before it acts.
	await _await_event_presented(overlay, enemy_turn)
	assert_str(String(overlay._active_id)).is_equal("enemy")
	assert_str(String(overlay._target_id)).is_empty()
	assert_array(_cards(overlay)).override_failure_message(
		"a new turn retires the previous beat's card"
	).is_empty()
	# Beat 3: the reply replaces the player's card rather than stacking on it.
	await _await_event_presented(overlay, reply)
	assert_array(_cards(overlay)).contains_exactly(["Bog Wight → Vex|1 DAMAGE"])
	assert_str(String(overlay._active_id)).is_equal("enemy")
	assert_str(String(overlay._target_id)).is_equal("ally")
	assert_float(overlay._hp_target[&"ally"]).is_equal(42.0)
	await _await_presented(overlay)
	assert_str(String(overlay._active_id)).is_equal("ally")
	assert_bool(overlay.is_animating()).is_false()


## #473: the beat cursor is what the field shows now, not what the model has resolved. HUD
## regions outside the field read it (and `beat_presented`) to stay behind the field.
func test_beat_cursor_trails_the_received_stream_until_each_beat_is_presented() -> void:
	var fixture := _duel()
	var overlay: CombatOverlay = fixture.overlay
	var presented: Array[CombatEvent] = []
	overlay.beat_presented.connect(func(event: CombatEvent) -> void: presented.append(event))
	var strike := _strike(&"ally", &"enemy", 11, 43, 7)
	var enemy_turn := _event(&"enemy_turn_started", &"enemy", &"", 43, 7)
	var reply := _strike(&"enemy", &"ally", 1, 42, 7)
	for event: CombatEvent in [strike, enemy_turn, reply]:
		overlay.consume_event(event)
	assert_object(overlay.presented_event()).is_same(strike)
	assert_array(presented).contains_exactly([strike])
	await _await_event_presented(overlay, enemy_turn)
	assert_object(overlay.presented_event()).is_same(enemy_turn)
	await _await_presented(overlay)
	assert_object(overlay.presented_event()).is_same(reply)
	assert_array(presented).contains_exactly([strike, enemy_turn, reply])


## Replaying history (HUD reopen) or turning animation off presents anything still queued at
## once, in order, with no beat holds.
func test_disabling_animation_flushes_queued_beats_in_order() -> void:
	var fixture := _duel()
	var overlay: CombatOverlay = fixture.overlay
	overlay.consume_event(_strike(&"ally", &"enemy", 11, 43, 7))
	overlay.consume_event(_event(&"enemy_turn_started", &"enemy", &"", 43, 7))
	overlay.consume_event(_event(&"turn_started", &"ally", &"", 43, 7))
	assert_bool(overlay.is_presenting()).is_true()
	overlay.animate_events = false
	assert_bool(overlay.is_presenting()).is_false()
	assert_str(String(overlay._active_id)).is_equal("ally")
	assert_int(_cards(overlay).size()).is_zero()


## #281 G2: highlights, HP bar and chevron are anchored to the moving body, not to the
## destination cell the snapshot already reports.
func test_unit_overlay_rides_the_moving_body() -> void:
	var fixture := _duel()
	var overlay: CombatOverlay = fixture.overlay
	var grid: IsoGrid = fixture.grid
	var ally: Node2D = fixture.ally
	var move := _event(&"action_resolved", &"ally", &"", 43, 18)
	move.data["path_cells"] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	move.data["snapshot"]["allies"][0]["position"] = &"c:0,2,0"
	overlay.consume_event(_event(&"turn_started", &"ally", &"", 43, 18))
	overlay.consume_event(move)
	await get_tree().create_timer(DS.DUR_FAST).timeout
	var destination := overlay.cell_center(Vector2i(0, 2))
	var anchor := overlay._body_anchor(&"ally", Vector2i(0, 2))
	assert_vector(anchor).is_equal(overlay.to_local(ally.global_position))
	assert_float(anchor.distance_to(destination)).is_greater(4.0)
	await _await_presented(overlay)
	assert_vector(overlay._body_anchor(&"ally", Vector2i(0, 2))).is_equal(destination)
	assert_vector(ally.global_position).is_equal(grid.cell_to_world(Vector2i(0, 2)))


## #281 G7: facing ids are grid directions. Each chevron points at the grid neighbour it
## names, so "e" points down-right on the iso screen, not along screen +x.
func test_facing_chevron_points_along_the_iso_grid() -> void:
	var fixture := _duel()
	var overlay: CombatOverlay = fixture.overlay
	var grid: IsoGrid = fixture.grid
	var cell := Vector2i(1, 1)
	for facing: String in CombatOverlay.FACING_STEPS:
		var step: Vector2i = CombatOverlay.FACING_STEPS[facing]
		var expected := grid.cell_to_world(cell + step) - grid.cell_to_world(cell)
		assert_vector(overlay.facing_vector(cell, facing)).is_equal(expected)
	var east := overlay.facing_vector(cell, "e").normalized()
	assert_float(east.y).is_greater(0.3)
	assert_float(rad_to_deg(east.angle())).is_equal_approx(rad_to_deg(atan2(16.0, 32.0)), 0.5)
	assert_float(overlay.facing_vector(cell, "n").normalized().y).is_less(-0.3)
	assert_vector(overlay.facing_vector(cell, "")).is_equal(Vector2.ZERO)


## #281 G10: the HP bar ticks down from the old value; the lost slice lingers, then drains.
func test_hp_bar_ticks_to_the_presented_value() -> void:
	var fixture := _duel()
	var overlay: CombatOverlay = fixture.overlay
	assert_float(overlay._shown_hp[&"enemy"]).is_equal(18.0)
	overlay.consume_event(_strike(&"ally", &"enemy", 11, 43, 7))
	assert_float(overlay._hp_target[&"enemy"]).is_equal(7.0)
	await get_tree().create_timer(DS.DUR_SLOW * 0.4).timeout
	var shown: float = overlay._shown_hp[&"enemy"]
	assert_float(shown).is_less(18.0).is_greater(7.0)
	assert_float(overlay._ghost_hp[&"enemy"]).is_equal(18.0)
	await get_tree().create_timer(DS.DUR_SLOW * 3.0).timeout
	assert_float(overlay._shown_hp[&"enemy"]).is_equal(7.0)
	assert_float(overlay._ghost_hp[&"enemy"]).is_equal(7.0)


func _duel() -> Dictionary:
	var ground := _ground()
	# The shipped field tilesets (ground_tileset.tres, combat_terrain_tiles.tres) use diamond-down.
	ground.tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	for y: int in 3:
		for x: int in 2:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var grid := IsoGrid.new()
	grid.build(ground)
	var overlay := auto_free(CombatOverlay.new()) as CombatOverlay
	add_child(overlay)
	overlay.bind_grid(grid, ground)
	var ally := auto_free(Node2D.new()) as Node2D
	var enemy := auto_free(Node2D.new()) as Node2D
	add_child(ally)
	add_child(enemy)
	overlay.bind_actor(&"ally", ally)
	overlay.bind_actor(&"enemy", enemy)
	var opening := _event(&"battle_started", &"", &"", 43, 18)
	overlay.animate_events = false
	overlay.consume_event(opening)
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


func _cards(overlay: Node) -> Array[String]:
	var cards: Array[String] = []
	for child: Node in overlay.get_children():
		if child.has_meta("result_target") and not child.has_meta("retiring") \
				and not child.is_queued_for_deletion():
			cards.append("%s|%s" % [
				(child.get_node("Column/TargetName") as Label).text,
				(child.get_node("Column/Outcome") as Label).text,
			])
	return cards


func _await_event_presented(overlay: CombatOverlay, event: CombatEvent, limit_ms: int = 4000) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline and overlay._queue.has(event):
		await get_tree().process_frame
