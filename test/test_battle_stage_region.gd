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
