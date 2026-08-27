extends GdUnitTestSuite


func test_stage_projects_event_tiles_and_emits_cursor_state() -> void:
	var runner := scene_runner("res://ui/hud/regions/stage/battle_stage_region.tscn")
	var stage := runner.scene() as BattleStageRegion
	var event := CombatEvent.new()
	event.data = {"tiles": [{"x": 2, "y": 1, "height_delta": 3, "charge_element_id": "khor", "charge_level": 3}]}
	stage.consume_event(event)
	assert_int(stage.rendered_tile_count()).is_equal(1)
	var received: Array[Dictionary] = []
	stage.tile_selected.connect(func(tile: Dictionary) -> void: received.append(tile))
	stage.select_tile(Vector2i(2, 1))
	assert_int(received.size()).is_equal(1)
	assert_int(int(received[0]["height_delta"])).is_equal(3)


func test_stage_renders_units_from_snapshot_and_plays_action_beat() -> void:
	var runner := scene_runner("res://ui/hud/regions/stage/battle_stage_region.tscn")
	var stage := runner.scene() as BattleStageRegion
	var snapshot := {
		"active_actor_id": "ally-vex-0",
		"allies": [{
			"id": "ally-vex-0", "display_name": "Vex", "side": "ally", "archetype_id": "",
			"hp": 20, "max_hp": 20, "position": Vector2i(0, 0), "facing": "e",
		}],
		"enemies": [{
			"id": "enemy-bog_wight-0", "display_name": "Bog Wight", "side": "enemy",
			"archetype_id": "bog_wight", "hp": 0, "max_hp": 20,
			"position": Vector2i(2, 1), "facing": "",
		}],
		"tiles": [
			{"x": 0, "y": 0, "height_delta": 0},
			{"x": 2, "y": 1, "height_delta": 1},
		],
	}
	var turn := CombatEvent.new()
	turn.type = &"turn_started"
	turn.actor_id = &"ally-vex-0"
	turn.data = {"snapshot": snapshot}
	stage.consume_event(turn)
	await runner.simulate_frames(2)

	var units := stage.get_node("UnitsLayer")
	assert_int(units.get_child_count()).is_equal(2)
	var wight := units.get_node("Unit_enemy-bog_wight-0") as TextureRect
	assert_object(wight).is_not_null()
	assert_object(wight.texture).is_not_null()
	# KO'd (hp 0) renders faded, never hidden — the body stays legible on the board.
	assert_float(wight.modulate.a).is_less(1.0)

	var strike := CombatEvent.new()
	strike.type = &"action_resolved"
	strike.actor_id = &"ally-vex-0"
	strike.target_id = &"enemy-bog_wight-0"
	strike.data = {"snapshot": snapshot, "hit": true, "damage": 6}
	stage.consume_event(strike)
	await runner.simulate_frames(2)
	var fx := stage.get_node("FxLayer")
	assert_int(fx.get_child_count()).is_greater_equal(1)
	assert_str((fx.get_child(0) as Label).text).is_equal("6")
