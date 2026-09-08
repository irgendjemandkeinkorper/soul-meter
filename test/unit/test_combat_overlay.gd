extends GdUnitTestSuite


class FieldFixture extends FieldMap:
	var layer: TileMapLayer
	var grid: IsoGrid

	func ground() -> TileMapLayer:
		return layer

	func iso_grid() -> IsoGrid:
		return grid


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
	assert_str((overlay.get_child(0) as Label).text).is_equal("7")
	await get_tree().create_timer(DS.DUR_SLOW + 0.1).timeout
	assert_vector(attacker.global_position).is_equal(grid.cell_to_world(Vector2i.ZERO))
	assert_vector(target.global_position).is_equal(grid.cell_to_world(Vector2i(1, 0)))
	assert_int(overlay.get_child_count()).is_equal(0)
	assert_dict(event.data).is_equal(before)
	# Reopening the HUD replays history to restore state; it must not make live
	# actors perform old attacks or lock pointer input again.
	overlay.set("animate_events", false)
	overlay.call("consume_event", event)
	assert_int(overlay.get_child_count()).is_equal(0)
	assert_bool(overlay.call("is_animating")).is_false()


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
