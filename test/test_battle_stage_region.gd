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


func test_stage_emits_tile_hovered_on_mouse_motion() -> void:
	var runner := scene_runner("res://ui/hud/regions/stage/battle_stage_region.tscn")
	var stage := runner.scene() as BattleStageRegion
	var event := CombatEvent.new()
	event.data = {"tiles": [{"x": 0, "y": 0, "height_delta": 0, "note": "mossy"}]}
	stage.consume_event(event)
	await runner.simulate_frames(1)
	var hovered: Array[Dictionary] = []
	stage.tile_hovered.connect(func(tile: Dictionary) -> void: hovered.append(tile))
	# A single tile lays out at the region's center, so a motion event there hits it.
	var motion := InputEventMouseMotion.new()
	motion.position = stage.size * 0.5
	stage._gui_input(motion)
	assert_int(hovered.size()).is_equal(1)
	assert_str(str(hovered[0]["note"])).is_equal("mossy")
	# Re-hovering the same cell is not a new emission.
	stage._gui_input(motion)
	assert_int(hovered.size()).is_equal(1)


func test_move_with_payload_path_slides_without_damage_pop() -> void:
	var runner := scene_runner("res://ui/hud/regions/stage/battle_stage_region.tscn")
	var stage := runner.scene() as BattleStageRegion
	var tiles := [
		{"x": 0, "y": 0, "height_delta": 0},
		{"x": 1, "y": 0, "height_delta": 0},
		{"x": 2, "y": 0, "height_delta": 0},
	]
	var before := {
		"active_actor_id": "ally-vex-0",
		"allies": [{
			"id": "ally-vex-0", "display_name": "Vex", "side": "ally", "archetype_id": "",
			"hp": 20, "max_hp": 20, "position": "c:0,0,0", "facing": "e",
		}],
		"enemies": [],
		"tiles": tiles,
	}
	var turn := CombatEvent.new()
	turn.type = &"turn_started"
	turn.actor_id = &"ally-vex-0"
	turn.data = {"snapshot": before}
	stage.consume_event(turn)
	await runner.simulate_frames(2)

	var after: Dictionary = before.duplicate(true)
	(after["allies"][0] as Dictionary)["position"] = "c:2,0,0"
	var move := CombatEvent.new()
	move.type = &"action_resolved"
	move.actor_id = &"ally-vex-0"
	move.data = {
		"snapshot": after,
		"damage": 0,
		"path": [&"c:0,0,0", &"c:1,0,0", &"c:2,0,0"],
		"path_cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	}
	stage.consume_event(move)
	await runner.simulate_frames(2)
	# A move is a slide, not a hit: no damage pop spawns.
	assert_int(stage.get_node("FxLayer").get_child_count()).is_equal(0)
	# The slide is animated — the sprite has not teleported to the destination...
	var vex := stage.get_node("UnitsLayer/Unit_ally-vex-0") as TextureRect
	var start_position := vex.position
	await await_millis(700)
	# ...but it settles away from where it started once the tween finishes.
	assert_bool(vex.position.distance_to(start_position) > 1.0).is_true()


func test_unit_plays_ko_fall_when_hp_reaches_zero() -> void:
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
			"archetype_id": "bog_wight", "hp": 8, "max_hp": 20,
			"position": Vector2i(2, 1), "facing": "",
		}],
		"tiles": [
			{"x": 0, "y": 0, "height_delta": 0},
			{"x": 2, "y": 1, "height_delta": 0},
		],
	}
	var turn := CombatEvent.new()
	turn.type = &"turn_started"
	turn.actor_id = &"ally-vex-0"
	turn.data = {"snapshot": snapshot}
	stage.consume_event(turn)
	await runner.simulate_frames(2)
	var wight := stage.get_node("UnitsLayer/Unit_enemy-bog_wight-0") as TextureRect
	assert_float(wight.rotation).is_equal(0.0)

	var killed: Dictionary = snapshot.duplicate(true)
	(killed["enemies"][0] as Dictionary)["hp"] = 0
	var strike := CombatEvent.new()
	strike.type = &"action_resolved"
	strike.actor_id = &"ally-vex-0"
	strike.target_id = &"enemy-bog_wight-0"
	strike.data = {"snapshot": killed, "hit": true, "damage": 8}
	stage.consume_event(strike)
	await await_millis(500)
	# The felled unit tips over at its feet and fades, but stays on the board.
	assert_bool(absf(wight.rotation) > 0.5).is_true()
	assert_float(wight.modulate.a).is_less(1.0)

func test_cover_theme_maps_every_catalog_prefix_and_texture_resolution_never_crashes() -> void:
	var runner := scene_runner("res://ui/hud/regions/stage/battle_stage_region.tscn")
	var stage := runner.scene() as BattleStageRegion
	var expectations := {
		&"dorthkor-vanguard": "road",
		&"bog-wight": "bog",
		&"loam-boar": "bog",
		&"jawbrace-empty-post": "barricade",
		&"trial-warden": "pillar",
		&"phase2-demon": "generic",
		&"": "generic",
	}
	for encounter_id: StringName in expectations:
		stage._encounter_id = encounter_id
		stage._cover_texture_cache.clear()
		assert_str(stage._cover_theme()).is_equal(str(expectations[encounter_id]))
		# Resolution must return a Texture2D or null (badge fallback) — never
		# crash — whether or not the generated prop art is present on disk.
		var texture: Texture2D = stage._cover_texture()
		if texture != null:
			assert_bool(texture.get_width() > 0).is_true()


func test_painter_order_updates_when_a_unit_slides_past_cover() -> void:
	var runner := scene_runner("res://ui/hud/regions/stage/battle_stage_region.tscn")
	var stage := runner.scene() as BattleStageRegion
	var tiles := [
		{"x": 0, "y": 0, "height_delta": 0},
		{"x": 1, "y": 0, "height_delta": 0, "cover": true},
		{"x": 2, "y": 0, "height_delta": 0},
	]
	var before := {
		"active_actor_id": "ally-vex-0",
		"allies": [{
			"id": "ally-vex-0", "display_name": "Vex", "side": "ally", "archetype_id": "",
			"hp": 20, "max_hp": 20, "position": "c:0,0,0", "facing": "e",
		}],
		"enemies": [],
		"tiles": tiles,
	}
	var turn := CombatEvent.new()
	turn.type = &"turn_started"
	turn.actor_id = &"ally-vex-0"
	turn.data = {"snapshot": before}
	stage.consume_event(turn)
	await runner.simulate_frames(2)
	var vex := stage.get_node("UnitsLayer/Unit_ally-vex-0") as TextureRect
	var prop := stage.get_node_or_null("UnitsLayer/Cover_1_0") as TextureRect
	# The generated prop art is committed — a null here means the asset or its
	# import broke, which is exactly what this suite should catch.
	assert_object(prop).is_not_null()
	# On the iso projection the unit at (0,0) stands above/behind the prop at
	# (1,0): it must draw first (lower child index).
	assert_bool(vex.get_index() < prop.get_index()).is_true()

	var after: Dictionary = before.duplicate(true)
	(after["allies"][0] as Dictionary)["position"] = "c:2,0,0"
	var move := CombatEvent.new()
	move.type = &"action_resolved"
	move.actor_id = &"ally-vex-0"
	move.data = {
		"snapshot": after,
		"damage": 0,
		"path": [&"c:0,0,0", &"c:1,0,0", &"c:2,0,0"],
		"path_cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	}
	stage.consume_event(move)
	# Let the slide tweens finish; their callbacks re-sort the layer (gate r2).
	await await_millis(900)
	assert_bool(vex.get_index() > prop.get_index()).is_true()


func test_prop_only_snapshot_sorts_cover_by_screen_depth() -> void:
	var runner := scene_runner("res://ui/hud/regions/stage/battle_stage_region.tscn")
	var stage := runner.scene() as BattleStageRegion
	var event := CombatEvent.new()
	# Deliberately inserted far-cell-first: without the early-return sort the
	# nodes would keep tile insertion order (gate r2).
	event.data = {"tiles": [
		{"x": 2, "y": 2, "height_delta": 0, "cover": true},
		{"x": 0, "y": 0, "height_delta": 0, "cover": true},
	]}
	stage.consume_event(event)
	await runner.simulate_frames(2)
	var near := stage.get_node_or_null("UnitsLayer/Cover_0_0") as TextureRect
	var far := stage.get_node_or_null("UnitsLayer/Cover_2_2") as TextureRect
	assert_object(near).is_not_null()
	assert_object(far).is_not_null()
	assert_bool(near.get_index() < far.get_index()).is_true()


func test_backdrop_theme_maps_every_catalog_prefix_and_resolution_never_crashes() -> void:
	var runner := scene_runner("res://ui/hud/regions/stage/battle_stage_region.tscn")
	var stage := runner.scene() as BattleStageRegion
	var expectations := {
		&"dorthkor-vanguard": "dorthkor-road",
		&"bog-wight": "bog-marsh",
		&"loam-boar": "bog-marsh",
		&"jawbrace-empty-post": "jawbrace-ledge",
		&"trial-warden": "trial-hall",
		&"phase2-demon": "wound-touched-field",
		&"": "wound-touched-field",
	}
	# Sequential transitions WITHOUT clearing the cache: all five themed
	# backdrops are committed art and must resolve non-null through the cache
	# exactly as a running battle would hit them (gate r1 risk closure).
	for encounter_id: StringName in expectations:
		stage._encounter_id = encounter_id
		var theme_name: String = str(expectations[encounter_id])
		assert_str(stage._backdrop_theme()).is_equal(theme_name)
		stage._sync_background()
		var texture: Texture2D = stage._backdrop_texture(theme_name)
		assert_object(texture) \
			.override_failure_message("Committed backdrop for %s failed to resolve." % theme_name) \
			.is_not_null()
		if texture != null:
			assert_bool(texture.get_width() > 0).is_true()
			assert_str(stage.background_texture_path()) \
				.ends_with("%s-battlefield-v1.png" % theme_name)
	# The dorthkor backdrop keeps its pinned path.
	stage._encounter_id = &"dorthkor-muster"
	stage._sync_background()
	assert_str(stage.background_texture_path()).ends_with("dorthkor-road-battlefield-v1.png")
