extends GdUnitTestSuite
## Wave C tactical gate proofs. These tests intentionally compose the public tactical seams;
## they do not author encounter/map content.


func test_gate_t10_ap_compatibility_paths_are_characterized_and_documented() -> void:
	var rules := CombatRules.new()
	rules.base_action_points = 4
	rules.attribute_points_per_ap = 2
	var actor := _actor("legacy", 4)
	actor.side = &"ally"
	var scheduler: TurnScheduler = preload("res://globals/combat/ap_round_scheduler.gd").new()
	scheduler.configure(rules)
	scheduler.setup([actor])
	assert_bool(scheduler.advance()["allowed"]).is_true()
	assert_int(actor.action_points).is_equal(6)

	var action := CombatAction.new()
	action.ap_cost = 3
	assert_int(scheduler.quote(actor, action)).is_equal(3)
	assert_bool(scheduler.commit(actor, action)["allowed"]).is_true()
	assert_int(actor.action_points).is_equal(3)
	assert_int(scheduler.cancel_committed(actor, true)["ct_refunded"]).is_equal(3)
	assert_int(actor.action_points).is_equal(6)
	assert_bool(scheduler.yield_turn(actor)["allowed"]).is_true()
	assert_int(actor.action_points).is_equal(0)

	var roots: Array[String] = ["res://globals", "res://ui"]
	for path in _gdscript_files(roots):
		var source := FileAccess.get_file_as_string(path)
		if not source.contains("action_points") and not source.contains("ap_cost"):
			continue
		assert_bool(
			source.contains("AP COMPATIBILITY SHIM")
			or source.contains("AP compatibility")
			or source.contains("AP round economy")
			or source.contains("AP block above is retained")
		).override_failure_message("Undocumented AP reference in %s" % path).is_true()


func test_force_pass_has_a_bounded_zero_refund_exit_when_action_gates_are_closed() -> void:
	var rules := _ct_rules()
	var ally := _actor("ally")
	ally.side = &"ally"
	var enemy := _actor("enemy")
	enemy.side = &"enemy"
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), BattlefieldModel.create_default(rules), rules)
	controller.start([ally], [enemy])
	var actor := controller.active_actor()
	var before := controller.scheduler.charge_of(actor)
	assert_int(before).is_greater_equal(TurnScheduler.READY_AT)
	assert_bool(controller.scheduler.interrupt(&"paused") ["allowed"]).is_true()

	controller._force_pass(actor)

	assert_int(controller.scheduler.charge_of(actor)).is_equal(0)
	assert_int(controller.scheduler.to_dict()["consecutive_waits"][actor.combat_id]).is_equal(0)


func test_gate_t4_queue_integrity_across_three_large_battles() -> void:
	var reference_log: Array[StringName] = []
	for battle_index in 3:
		var actors: Array[BattleActor] = []
		for index in 9:
			actors.append(_actor("unit_%d" % index))
		var scheduler := _ct_scheduler(actors)
		var log: Array[StringName] = []
		var counts: Dictionary = {}
		var action := CombatAction.new()
		action.ct_cost = 30
		var interrupt_count := 0
		var removed := actors[8]
		for turn_index in 72:
			var advanced := scheduler.advance()
			assert_bool(advanced["allowed"]).is_true()
			var actor: BattleActor = advanced["actor"]
			if turn_index > 18:
				assert_object(actor).is_not_same(removed)
			if turn_index == 18:
				removed.hp = 0
				scheduler.remove_participant(removed)
			if turn_index % 11 == 5:
				assert_bool(scheduler.interrupt(&"speech") ["allowed"]).is_true()
				assert_str(String(scheduler.advance()["blocked_by"])).is_equal("interrupted")
				scheduler.resume()
				assert_object(scheduler.active_actor()).is_same(actor)
				interrupt_count += 1
			log.append(actor.combat_id)
			counts[actor.combat_id] = int(counts.get(actor.combat_id, 0)) + 1
			assert_bool(scheduler.commit(actor, action)["allowed"]).is_true()
			scheduler.release(actor)
		assert_int(interrupt_count).is_equal(7)
		for actor in actors.slice(0, 8):
			assert_int(int(counts.get(actor.combat_id, 0))).is_greater(0)
		assert_int(int(counts.get(removed.combat_id, 0))).is_less_equal(2)
		if battle_index == 0:
			reference_log = log.duplicate()
		else:
			assert_array(log).is_equal(reference_log)

	# Wait exactly twice, refuse the cap boundary, then prove a real action resets it.
	var waiter := _actor("waiter")
	var capped := _ct_scheduler([waiter])
	for expected_waits in [1, 2]:
		assert_bool(capped.advance()["allowed"]).is_true()
		var waited := capped.yield_turn(waiter)
		assert_int(waited["consecutive_waits"]).is_equal(expected_waits)
	assert_bool(capped.advance()["allowed"]).is_true()
	assert_str(String(capped.yield_turn(waiter)["blocked_by"])).is_equal("consecutive_wait_cap")
	var real_action := CombatAction.new()
	real_action.ct_cost = 30
	assert_bool(capped.commit(waiter, real_action)["allowed"]).is_true()
	assert_int(capped.to_dict()["consecutive_waits"][waiter.combat_id]).is_equal(0)


func test_gate_t7_resolution_and_tactical_round_trip_are_byte_deterministic() -> void:
	var context := _resolution_context()
	var first := Resolution.resolve(context)
	var second := Resolution.resolve(context.duplicate(true))
	assert_array(var_to_bytes(first)).contains_exactly(var_to_bytes(second))

	var actor := _actor("round-trip")
	var scheduler := _ct_scheduler([actor])
	var scheduler_state := scheduler.to_dict()
	scheduler_state["charge"][actor.combat_id] = 137
	scheduler_state["consecutive_waits"][actor.combat_id] = 2
	scheduler.from_dict(scheduler_state)
	var tile := TileState.create(&"wave-c", 4, 7, 3)
	tile.apply_residue(&"strom")
	tile.apply_residue(&"strom")
	var weather := Weather.create(&"strom")
	for _tick in 19:
		weather.tick([tile])
	var tactical := {
		"grid": {"position": Vector2i(4, 7), "facing": &"nw", "elevation": 3},
		"scheduler": scheduler.to_dict(),
		"tiles": [tile.to_dict()],
		"weather": weather.to_dict(),
		"skill_check": {"expert_rerolls_used": {"wave-c/round-trip": 1}},
	}
	var restored: Dictionary = bytes_to_var(var_to_bytes(tactical))
	assert_bool(restored == tactical).is_true()
	var restored_scheduler := _ct_scheduler([actor])
	restored_scheduler.from_dict(restored["scheduler"])
	assert_int(restored_scheduler.charge_of(actor)).is_equal(137)
	assert_int(restored_scheduler.to_dict()["consecutive_waits"][actor.combat_id]).is_equal(2)
	assert_bool(TileState.from_dict(restored["tiles"][0]).to_dict() == tile.to_dict()).is_true()
	assert_bool(Weather.from_dict(restored["weather"]).to_dict() == weather.to_dict()).is_true()


func test_gate_t3_defining_strike_weather_bias_and_mid_queue_speech_victory() -> void:
	var rules := _ct_rules()
	var ally := _actor("ally", 8)
	ally.side = &"ally"
	ally.source_member = _skilled_member()
	var enemy_a := _actor("enemy-a")
	var enemy_b := _actor("enemy-b")
	enemy_a.side = &"enemy"
	enemy_b.side = &"enemy"
	enemy_a.archetype_id = &"loam-maddened-boar"
	enemy_a.discovered_weakness_ids = [&"loam-maddened-boar/knee"]
	var events: Array[CombatEvent] = []
	var controller := CombatController.new()
	controller.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event))
	controller.configure(CombatActionCatalog.all(), BattlefieldModel.create_default(rules), rules)
	controller.start([ally], [enemy_a, enemy_b])
	var definition := CombatActionCatalog.by_id(&"definition")
	var charge_before := controller.scheduler.charge_of(ally)
	var defining_price := controller.scheduler.quote(ally, definition)
	var strike := controller.submit_action(
		definition.id, enemy_a,
		{"weakness_id": &"loam-maddened-boar/knee", "forced_rolls": [1], "seed": 170}
	)
	assert_bool(strike["allowed"]).is_true()
	assert_int(defining_price).is_greater(0)
	assert_int(strike["ct_spent"]).is_equal(defining_price)
	assert_int(strike["charge_remaining"]).is_equal(charge_before - defining_price)

	var ordered := TileState.create(&"weather", 0, 0)
	ordered.apply_residue(&"strom")
	var chaotic := TileState.from_dict(ordered.to_dict())
	var order_weather := Weather.create(&"strom")
	var chaos_weather := Weather.create(&"strom")
	for tick_index in TurnScheduler.TICKS_PER_MEASURE:
		order_weather.tick([ordered], 100)
		chaos_weather.tick([chaotic], -100)
	assert_int(ordered.charge_level).is_greater(chaotic.charge_level)

	# Bank CT on both enemies to make this genuinely mid-queue, then end the encounter by speech.
	var state := controller.scheduler.to_dict()
	state["charge"][enemy_a.combat_id] = 140
	state["charge"][enemy_b.combat_id] = 130
	controller.scheduler.from_dict(state)
	var hp_before := [enemy_a.hp, enemy_b.hp]
	var option := CombatSpeechOption.from_dict({
		"id": "wave-c-end", "skill": "persuasion", "outcome": "end", "outcome_id": "spared"
	})
	var speech := controller.submit_speech(&"speech-seam", {"success": true}, option)
	assert_bool(speech["allowed"]).is_true()
	assert_int(controller.state).is_equal(CombatController.State.FINISHED)
	assert_array([enemy_a.hp, enemy_b.hp]).contains_exactly(hp_before)
	var finish_index := -1
	for index in events.size():
		if events[index].type == &"battle_finished":
			finish_index = index
	assert_int(finish_index).is_greater_equal(0)
	for index in range(finish_index + 1, events.size()):
		assert_str(String(events[index].type)).is_not_equal("action_resolved")
	var final_state := {"snapshot": controller.snapshot(), "events": events.map(
		func(event: CombatEvent) -> Dictionary: return event.to_dict()
	)}
	assert_bool(bytes_to_var(var_to_bytes(final_state)) == final_state).is_true()


func test_gate_t7_whole_encounter_and_equal_cost_path_are_repeatable() -> void:
	var first := _scripted_encounter_log(173)
	var second := _scripted_encounter_log(173)
	assert_array(var_to_bytes(first)).contains_exactly(var_to_bytes(second))

	var model := _grid_model(5, 4)
	var actor := _actor("path")
	var actors: Array[BattleActor] = [actor]
	model.setup(actors, [])
	var query := model.path_query(actor, &"c:2,1,0")
	assert_bool(query["allowed"]).is_true()
	assert_str(String(query["path"][1])).is_equal("c:1,0,0")


func _actor(id: String, edge: int = 0) -> BattleActor:
	var actor := BattleActor.new()
	actor.combat_id = StringName(id)
	actor.display_name = id
	actor.hp = 100
	actor.max_hp = 100
	actor.attack = 8
	actor.defense = 2
	actor.attributes = {&"edge": edge}
	return actor


func _ct_rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.use_charge_time = true
	rules.base_charge_speed = 25
	rules.attribute_points_per_speed = 2
	return rules


func _ct_scheduler(actors: Array[BattleActor]) -> TurnScheduler:
	var scheduler: TurnScheduler = preload("res://globals/combat/charge_time_scheduler.gd").new()
	scheduler.configure(_ct_rules())
	scheduler.setup(actors)
	return scheduler


func _resolution_context() -> Dictionary:
	return {
		"battle_id": "wave-c", "tick": 12, "seed": 173,
		"unit": {"id": "caster", "attack_scale": 1.25, "ct": 137, "harmony": 0},
		"ability": {"id": "strike", "power": 24, "element_id": &"strom", "elements": [&"strom"], "magnitude": &"note", "ct_cost": 30},
		"target": {"id": "target", "hp": 100, "element_id": &"terra"},
		"source_tile": TileState.create(&"wave-c", 0, 0).to_dict(),
		"target_tile": TileState.create(&"wave-c", 1, 0).to_dict(),
		"weather": Weather.create(&"strom").to_dict(),
		"facing": {"id": &"front", "multiplier": 1.0},
	}


func _skilled_member() -> PartyMember:
	var member := PartyMember.new()
	member.id = "wave-c-definer"
	member.attributes = {"spark": 5, "pitch": 5}
	member.skill_tiers = {"lore": "untrained", "insight": "untrained"}
	return member


func _scripted_encounter_log(seed: int) -> Array[Dictionary]:
	var rules := _ct_rules()
	var ally := _actor("ally", 4)
	ally.side = &"ally"
	var enemy := _actor("enemy")
	enemy.side = &"enemy"
	enemy.hp = 35
	enemy.max_hp = 35
	var events: Array[Dictionary] = []
	var controller := CombatController.new()
	controller.event_emitted.connect(
		func(event: CombatEvent) -> void: events.append(event.to_dict())
	)
	controller.configure(CombatActionCatalog.all(), BattlefieldModel.create_default(rules), rules)
	controller.start([ally], [enemy])
	var guard := 0
	while controller.state != CombatController.State.FINISHED and guard < 20:
		if controller.state == CombatController.State.ALLY_TURN:
			controller.submit_action(&"strike", enemy, {"seed": seed})
		guard += 1
	assert_int(controller.state).is_equal(CombatController.State.FINISHED)
	return events


func _grid_model(width: int, height: int) -> GridBattlefieldModel:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tile_set
	for y in height:
		for x in width:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var model := GridBattlefieldModel.new()
	model.configure(_ct_rules())
	model.build_grid(ground)
	return model


func _gdscript_files(roots: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for root in roots:
		_collect_gdscript_files(root, result)
	return result


func _collect_gdscript_files(root: String, result: Array[String]) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if directory.current_is_dir():
			_collect_gdscript_files(path, result)
		elif entry.get_extension() == "gd":
			result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
