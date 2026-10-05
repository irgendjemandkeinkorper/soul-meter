extends GdUnitTestSuite

const SpellCastScript := preload("res://ui/hud/spell_cast_effect.gd")
const StageScene := preload("res://ui/hud/regions/stage/battle_stage_region.tscn")

var _controllers: Array[CombatController] = []
var _reduced_before: bool
var _soul_before: float
var _flags_before: Dictionary


func before_test() -> void:
	_reduced_before = bool(GameState.get_setting("accessibility", "reduced_motion", false))
	GameState.set_setting("accessibility", "reduced_motion", false)
	_soul_before = GameState.soul_meter
	_flags_before = GameState.flags.duplicate(true)
	GameState.flags.erase(GameState.HUSKED_FLAG)
	GameState.flags.erase(GameState.HUSKED_RECOVERY_CEILING_FLAG)
	GameState.set_soul_meter(50.0)


func after_test() -> void:
	GameState.set_setting("accessibility", "reduced_motion", _reduced_before)
	GameState.flags = _flags_before
	GameState.soul_meter = _soul_before
	for controller: CombatController in _controllers:
		for actor: BattleActor in controller.allies + controller.enemies:
			actor.class_resource.host = null
	_controllers.clear()


func test_live_cast_reaches_both_views_and_reports_damage_at_impact() -> void:
	var fixture := _views()
	var controller: CombatController = fixture.controller
	var stage: BattleStageRegion = fixture.stage
	var overlay: CombatOverlay = fixture.overlay
	var target: BattleActor = controller.enemies[0]
	var options := {"ability_id": "presentation-cast", "seed": 17}
	var quote := controller.forecast_action(controller.action_by_id(&"cast-seam"), target, options)
	assert_bool(quote.allowed).is_true()
	assert_int(stage.get_node("FxLayer").get_child_count()).is_zero()
	assert_int(overlay.get_child_count()).is_zero()
	var captured: Array[Dictionary] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void: captured.append(event.to_dict()))
	var result := controller.submit_action(&"cast-seam", target, options)
	assert_bool(result.allowed).is_true()
	assert_bool(result.resolution.fizzled).is_false()
	assert_dict(result.resolution).is_equal(quote.resolution)
	assert_int(controller.allies[0].breath).is_equal(7)
	var fx := stage.get_node("FxLayer")
	assert_object(fx.get_node_or_null("SpellCast")).is_not_null()
	assert_object(overlay.get_node_or_null("SpellCast")).is_not_null()
	assert_object(fx.get_node_or_null("DamagePop")).is_null()
	assert_object(overlay.get_node_or_null("DamagePop")).is_null()
	assert_bool(stage.pointer_input_available()).is_false()
	assert_bool(overlay.is_animating()).is_true()
	var saved := captured.duplicate(true)
	await await_millis(450)
	assert_str((fx.get_node("DamagePop/Column/Outcome") as Label).text).is_equal("%d DAMAGE" % result.damage)
	assert_str((overlay.get_node("DamagePop/Column/Outcome") as Label).text).is_equal("%d DAMAGE" % result.damage)
	await _await_settled(stage, overlay, 1500)
	assert_bool(stage.pointer_input_available()).is_true()
	assert_bool(overlay.is_animating()).is_false()
	assert_object(fx.get_node_or_null("SpellCast")).is_null()
	assert_object(overlay.get_node_or_null("SpellCast")).is_null()
	assert_array(captured).is_equal(saved)
	await await_millis(1700)
	assert_int(fx.get_child_count()).is_zero()
	assert_int(overlay.get_child_count()).is_zero()


func test_move_survives_followup_snapshot_and_replay_cancels_motion() -> void:
	var fixture := _views()
	var stage: BattleStageRegion = fixture.stage
	var overlay: CombatOverlay = fixture.overlay
	var controller: CombatController = fixture.controller
	var id := controller.allies[0].combat_id
	var unit := stage.get_node("UnitsLayer/Unit_%s" % id) as TextureRect
	var actor: Node2D = fixture.ally_node
	var board_home := unit.position
	var field_home := actor.global_position
	var snapshot := controller.snapshot()
	snapshot.allies[0]["position"] = Vector2i(3, 0)
	var event := CombatEvent.new()
	event.type = &"action_resolved"
	event.actor_id = id
	event.data = {"snapshot": snapshot, "path_cells": [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]}
	stage.consume_event(event)
	overlay.consume_event(event)
	var update := CombatEvent.new()
	update.type = &"turn_started"
	update.data = {"snapshot": snapshot}
	stage.consume_event(update)
	overlay.consume_event(update)
	assert_vector(unit.position).is_equal(board_home)
	assert_vector(actor.global_position).is_equal(field_home)
	await await_millis(100)
	assert_float(unit.position.distance_to(board_home)).is_greater(0.01)
	assert_float(actor.global_position.distance_to(field_home)).is_greater(0.01)
	stage.set_replaying(true)
	overlay.animate_events = false
	var board_final := unit.position
	var field_final := actor.global_position
	await await_millis(450)
	assert_vector(unit.position).is_equal(board_final)
	assert_vector(actor.global_position).is_equal(field_final)
	assert_vector(actor.global_position).is_equal(overlay._grid.cell_to_world(Vector2i(3, 0)))
	assert_bool(stage.pointer_input_available()).is_true()
	assert_bool(overlay.is_animating()).is_false()
	# Replaying a path must not start another tween or lock input.
	stage.consume_event(event)
	overlay.consume_event(event)
	assert_bool(stage.pointer_input_available()).is_true()
	assert_bool(overlay.is_animating()).is_false()


func test_reduced_motion_toggle_settles_moves_and_keeps_cast_information() -> void:
	var fixture := _views()
	var stage: BattleStageRegion = fixture.stage
	var overlay: CombatOverlay = fixture.overlay
	var event := _cast_event(fixture)
	stage.consume_event(event)
	overlay.consume_event(event)
	GameState.set_setting("accessibility", "reduced_motion", true)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(stage.pointer_input_available()).is_true()
	assert_bool(overlay.is_animating()).is_false()
	assert_object(stage.get_node_or_null("FxLayer/DamagePop")).is_not_null()
	assert_object(overlay.get_node_or_null("DamagePop")).is_not_null()
	assert_object(stage.get_node_or_null("FxLayer/HitPulse")).is_null()
	var actor: Node2D = fixture.ally_node
	var before := actor.position
	await await_millis(200)
	assert_vector(actor.position).is_equal(before)


func test_lethal_spell_waits_for_impact_and_survives_resource_snapshots() -> void:
	var fixture := _views()
	var stage: BattleStageRegion = fixture.stage
	var overlay: CombatOverlay = fixture.overlay
	var event := _cast_event(fixture)
	event.data.snapshot.enemies[0]["hp"] = 0
	stage.consume_event(event)
	overlay.consume_event(event)
	var update := CombatEvent.new()
	update.data = {"snapshot": event.data.snapshot}
	stage.consume_event(update)
	overlay.consume_event(update)
	var target := stage.get_node("UnitsLayer/Unit_%s" % event.target_id) as TextureRect
	var field_target: Node2D = fixture.enemy_node
	await await_millis(100)
	assert_float(target.rotation).is_zero()
	assert_float(target.modulate.a).is_equal(1.0)
	assert_float(field_target.modulate.a).is_equal(1.0)
	await await_millis(650)
	assert_float(absf(target.rotation)).is_greater(1.0)
	assert_float(target.modulate.a).is_less(1.0)
	assert_float(field_target.modulate.a).is_less(1.0)


func test_fizzle_miss_and_cell_working_have_separate_feedback_lifetimes() -> void:
	var fixture := _views()
	var stage: BattleStageRegion = fixture.stage
	var overlay: CombatOverlay = fixture.overlay
	for outcome: String in ["fizzle", "miss", "cells"]:
		var event := _cast_event(fixture)
		event.data["damage"] = 0
		event.data.resolution["hit"] = outcome != "miss"
		event.data.resolution["fizzled"] = outcome == "fizzle"
		if outcome == "cells":
			event.target_id = &""
			event.data["cells"] = [{"x": 1, "y": 0}, {"x": 2, "y": 0}, {"x": 3, "y": 0}]
		var before := event.to_dict()
		stage.consume_event(event)
		overlay.consume_event(event)
		var fx := stage.get_node("FxLayer")
		assert_object(fx.get_node_or_null("SpellCast")).is_not_null()
		assert_object(overlay.get_node_or_null("SpellCast")).is_not_null()
		await await_millis(450)
		assert_object(fx.get_node_or_null("HitPulse")).is_null()
		if outcome != "cells":
			assert_str((fx.get_node("DamagePop/Column/Outcome") as Label).text).is_equal(outcome.to_upper())
		else:
			assert_object(fx.get_node_or_null("DamagePop")).is_null()
		assert_dict(event.to_dict()).is_equal(before)
		await await_millis(2100)
		assert_int(fx.get_child_count()).is_zero()
		assert_int(overlay.get_child_count()).is_zero()


func test_leaving_battle_during_lunge_restores_borrowed_actor_position() -> void:
	var fixture := _views()
	var overlay: CombatOverlay = fixture.overlay
	var actor: Node2D = fixture.ally_node
	var home := actor.global_position
	var event := _cast_event(fixture)
	event.data["verb"] = CombatAction.Verb.ATTACK
	overlay.consume_event(event)
	await await_millis(80)
	assert_float(actor.global_position.distance_to(home)).is_greater(0.0)
	remove_child(overlay)
	assert_vector(actor.global_position).is_equal(home)
	await await_millis(300)
	assert_vector(actor.global_position).is_equal(home)


## Effects run on frame deltas, which delta smoothing can hold behind the wall clock after a
## slow frame, so a fixed sleep just past DURATION fails depending on what ran before. Wait on
## the views themselves, bounded so a release that never comes still fails.
func _await_settled(stage: BattleStageRegion, overlay: CombatOverlay, limit_ms: int) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline \
			and (not stage.pointer_input_available() or overlay.is_animating()):
		await get_tree().process_frame


func _cast_event(fixture: Dictionary) -> CombatEvent:
	var controller: CombatController = fixture.controller
	var event := CombatEvent.new()
	event.type = &"action_resolved"
	event.actor_id = controller.allies[0].combat_id
	event.target_id = controller.enemies[0].combat_id
	event.data = {"verb": CombatAction.Verb.CAST, "damage": 7, "resolution": {
		"hit": true, "fizzled": false, "composition": {"elements": ["khash"]},
	}, "snapshot": controller.snapshot()}
	return event


func _views() -> Dictionary:
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = TileSet.new()
	ground.tile_set.tile_size = Vector2i(64, 32)
	ground.tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	ground.tile_set.add_source(source, 0)
	for x: int in 4:
		for y: int in 3:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	add_child(ground)
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var model := GridBattlefieldModel.new()
	model.configure(rules)
	model.build_grid(ground)
	var owner := BattleActor.new()
	owner.display_name = "Vex"
	owner.hp = 100
	owner.max_hp = 100
	owner.breath = 10
	owner.attributes[&"pitch"] = 100
	owner.source_member = PartyMember.new()
	owner.source_member.id = "presentation-caster"
	var enemy := BattleActor.new()
	enemy.display_name = "Bog Wight"
	enemy.hp = 100
	enemy.max_hp = 100
	var ability := AbilityDefinition.new()
	ability.id = "presentation-cast"
	ability.element_id = &"zhur"
	ability.elements = [&"zhur"]
	ability.power = 10
	ability.breath_cost = 3
	var tables := TacticalTables.new()
	tables.abilities[ability.id] = ability
	var loadout := UnitLoadout.create(owner.source_member.id)
	loadout.action_ability_ids.append(ability.id)
	tables.loadouts[owner.source_member.id] = loadout
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), model, rules, null, [ability], tables)
	controller.start([owner], [enemy], &"presentation-test")
	_controllers.append(controller)
	assert_bool(model.displace(owner, Vector2i.ZERO).allowed).is_true()
	assert_bool(model.displace(enemy, Vector2i(1, 0)).allowed).is_true()
	var stage := auto_free(StageScene.instantiate()) as BattleStageRegion
	stage.theme = ThemeBuilder.build()
	stage.size = Vector2(960, 480)
	add_child(stage)
	var overlay := auto_free(CombatOverlay.new()) as CombatOverlay
	add_child(overlay)
	var grid := IsoGrid.new()
	grid.build(ground)
	overlay.bind_grid(grid, ground)
	var ally_node := auto_free(Node2D.new()) as Node2D
	var enemy_node := auto_free(Node2D.new()) as Node2D
	add_child(ally_node)
	add_child(enemy_node)
	overlay.bind_actor(owner.combat_id, ally_node)
	overlay.bind_actor(enemy.combat_id, enemy_node)
	controller.event_emitted.connect(stage.consume_event)
	controller.event_emitted.connect(overlay.consume_event)
	var initial := CombatEvent.new()
	initial.data = {"snapshot": controller.snapshot()}
	stage.consume_event(initial)
	overlay.consume_event(initial)
	return {"stage": stage, "overlay": overlay, "controller": controller, "ally_node": ally_node, "enemy_node": enemy_node}
