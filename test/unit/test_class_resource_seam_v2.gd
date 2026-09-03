extends GdUnitTestSuite
## #223 follow-up — ClassResource seam v2: broadcast, deferred execution, cancellation, reveal,
## hidden draw, `soul_refund`/`dot` write kinds, `fizzle_percent_override`, and the key-level
## merge of `on_cast_forecast` overrides. One unit test per channel plus one controller-level
## integration test per channel.


class V2Spy:
	extends ClassResource

	var any_actions: Array[String] = []
	var fired: Array[Dictionary] = []
	var cancelled: Array[Dictionary] = []
	var kills: Array[String] = []
	var forecast_override: Dictionary = {}
	var enqueue_on_any_action: Dictionary = {}
	var cancel_on_any_action: StringName = &""
	var last_cancel: Dictionary = {}

	func on_any_action(actor_id: StringName, action_id: StringName, target_id: StringName, _outcome: Dictionary) -> void:
		any_actions.append("%s:%s:%s" % [String(actor_id), String(action_id), String(target_id)])
		if not enqueue_on_any_action.is_empty():
			enqueue_deferred(enqueue_on_any_action, {"delay_rounds": 2})
		if not cancel_on_any_action.is_empty():
			last_cancel = request_cancel(cancel_on_any_action, &"committed")

	func on_deferred_fired(entry: Dictionary) -> void:
		fired.append(entry)

	func on_deferred_cancelled(entry: Dictionary, _by_id: StringName) -> void:
		cancelled.append(entry)

	func on_kill(target_id: StringName, cause: StringName) -> void:
		kills.append("%s:%s" % [String(target_id), String(cause)])

	func on_cast_forecast(_context: Dictionary) -> Dictionary:
		return forecast_override.duplicate(true)


func before_test() -> void:
	GameState.set_soul_meter(50.0)


# ─── Unit: base class + Resolution ──────────────────────────────────────────


func test_base_hooks_are_noops_and_requests_refuse_without_a_host() -> void:
	var resource := ClassResource.new()
	resource.on_any_action(&"a", &"strike", &"b", {})
	resource.on_deferred_fired({})
	resource.on_deferred_cancelled({}, &"x")
	var queued := resource.enqueue_deferred({"writes": [{"kind": "hp", "amount": 1}]}, {"delay_rounds": 1})
	assert_bool(queued.get("allowed", true)).is_false()
	assert_str(str(queued.get("blocked_by", ""))).is_equal("no_host")
	assert_bool(resource.request_cancel(&"anyone").get("allowed", true)).is_false()


func test_deep_merge_keeps_untouched_nested_keys() -> void:
	var base := {"unit": {"id": "ally-0", "edge": 2, "attack_scale": 1.0}, "fizzle": {"patron": "Kero", "pitch": 3}, "flag": 1}
	CombatController.deep_merge(base, {"unit": {"attack_scale": 1.25}, "fizzle": {"mastery": true}, "flag": 2})
	assert_dict(base["unit"]).contains_key_value("id", "ally-0")
	assert_dict(base["unit"]).contains_key_value("edge", 2)
	assert_float(float(base["unit"]["attack_scale"])).is_equal(1.25)
	assert_dict(base["fizzle"]).contains_key_value("patron", "Kero")
	assert_dict(base["fizzle"]).contains_key_value("pitch", 3)
	assert_bool(bool(base["fizzle"]["mastery"])).is_true()
	assert_int(int(base["flag"])).is_equal(2)


func test_resolution_fizzle_percent_override_pins_the_chance() -> void:
	var context := _spell_context()
	var open := Resolution.resolve(context)
	assert_bool(open.get("allowed", false)).is_true()
	context["fizzle_percent_override"] = 0.0
	var pinned := Resolution.resolve(context)
	assert_float(float(pinned["fizzle_percent"])).is_equal(0.0)
	assert_bool(bool(pinned["fizzled"])).is_false()
	assert_bool(bool(pinned["fizzle_overridden"])).is_true()
	context["fizzle_percent_override"] = 100.0
	var doomed := Resolution.resolve(context)
	assert_bool(bool(doomed["fizzled"])).is_true()


func test_resolution_hidden_draw_is_deterministic_and_adds_the_row_bonus() -> void:
	var context := _spell_context()
	context["fizzle_percent_override"] = 0.0
	var plain := Resolution.resolve(context)
	context["hidden_draw"] = {
		"table_id": "attribution",
		"seed_key": "ofshutje",
		"rows": [{"id": "surge", "bonus_damage": 1}, {"id": "fork", "bonus_damage": 2}, {"id": "thunder", "bonus_damage": 3}],
	}
	var first := Resolution.resolve(context)
	var second := Resolution.resolve(context)
	var draw: Dictionary = first["hidden_draw"]
	assert_bool(draw.is_empty()).is_false()
	assert_str(str(draw["row_id"])).is_equal(str((second["hidden_draw"] as Dictionary)["row_id"]))
	assert_int(int(first["damage"])).is_equal(int(plain["damage"]) + int((draw["row"] as Dictionary)["bonus_damage"]))
	# A different seed key decorrelates the draw from the fizzle roll's key space.
	context["hidden_draw"]["seed_key"] = "other"
	var third := Resolution.resolve(context)
	assert_int(int(third["hidden_draw"]["roll"])).is_not_equal(int(draw["roll"]))


func test_resolution_reveal_exposes_the_hidden_terms_without_changing_the_numbers() -> void:
	var context := _spell_context()
	context["target"]["attunements"] = {"scor": 2}
	var closed := Resolution.resolve(context)
	assert_bool(bool(closed["reveal"])).is_false()
	assert_bool(closed.has("revealed")).is_false()
	context["reveal"] = true
	var opened := Resolution.resolve(context)
	assert_bool(bool(opened["reveal"])).is_true()
	var revealed: Dictionary = opened["revealed"]
	assert_float(float(revealed["fizzle_percent"])).is_equal(float(closed["fizzle_percent"]))
	assert_dict(revealed["attunements"]).contains_key_value("scor", 2)
	assert_int(int(opened["damage"])).is_equal(int(closed["damage"]))


# ─── Integration: controller dispatch ───────────────────────────────────────


func test_controller_broadcasts_every_resolved_action_to_every_resource() -> void:
	var ally_spy := V2Spy.new()
	var enemy_spy := V2Spy.new()
	var battle := _battle(ally_spy, enemy_spy)
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	var enemy: BattleActor = battle["enemy"]
	var result := controller.submit_action(&"strike", enemy)
	assert_bool(result.get("allowed", false)).is_true()
	var expected := "%s:strike:%s" % [String(ally.combat_id), String(enemy.combat_id)]
	assert_array(ally_spy.any_actions).contains([expected])
	assert_array(enemy_spy.any_actions).contains([expected])


func test_deferred_effect_fires_at_the_due_round_through_the_write_path() -> void:
	var ally_spy := V2Spy.new()
	var battle := _battle(ally_spy)
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	var hp_before := enemy.hp
	var queued := ally_spy.enqueue_deferred(
		{"writes": [{"kind": "hp", "target_id": String(enemy.combat_id), "amount": 5}]},
		{"delay_rounds": 1},
		&"oath",
	)
	assert_bool(queued.get("allowed", false)).is_true()
	assert_int((controller.snapshot()["deferred"] as Array).size()).is_equal(1)
	assert_int(enemy.hp).is_equal(hp_before)  # nothing fires at queue time
	controller.end_turn()  # enemy acts, round rolls, the entry is due
	assert_int(enemy.hp).is_less(hp_before)
	assert_int(ally_spy.fired.size()).is_equal(1)
	var applied: Array = ally_spy.fired[0]["applied"]
	assert_dict(applied[0]).contains_key_value("kind", "hp")
	assert_int(int((applied[0] as Dictionary)["delta"])).is_equal(-5)
	assert_int((controller.snapshot()["deferred"] as Array).size()).is_equal(0)


func test_deferred_dot_write_kills_with_cause_dot_and_soul_refund_raises_the_meter() -> void:
	var ally_spy := V2Spy.new()
	var battle := _battle(ally_spy)
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	var enemy: BattleActor = battle["enemy"]
	enemy.hp = 2
	var before := GameState.soul_meter
	var queued := ally_spy.enqueue_deferred(
		{"writes": [
			{"kind": "dot", "target_id": String(enemy.combat_id), "amount": 3},
			{"kind": "soul_refund", "target_id": String(ally.combat_id), "amount": 1.5},
		]},
		{"delay_rounds": 1},
	)
	assert_bool(queued.get("allowed", false)).is_true()
	controller.end_turn()
	assert_bool(enemy.is_alive()).is_false()
	assert_array(ally_spy.kills).contains(["%s:dot" % String(enemy.combat_id)])
	assert_float(GameState.soul_meter).is_equal(before + 1.5)


func test_request_cancel_removes_deferred_entries_and_voids_a_committed_action() -> void:
	var ally_spy := V2Spy.new()
	var enemy_spy := V2Spy.new()
	var battle := _battle(ally_spy, enemy_spy)
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	var enemy: BattleActor = battle["enemy"]
	# Nothing in flight yet: an honest refusal, not a silent no-op.
	var nothing := enemy_spy.request_cancel(ally.combat_id)
	assert_bool(nothing.get("allowed", true)).is_false()
	assert_str(str(nothing.get("blocked_by", ""))).is_equal("nothing_to_cancel")
	ally_spy.enqueue_deferred({"writes": [{"kind": "hp", "target_id": String(enemy.combat_id), "amount": 1}]}, {"delay_rounds": 3})
	var events: Array[StringName] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event.type))
	var jammed := enemy_spy.request_cancel(ally.combat_id, &"deferred")
	assert_bool(jammed.get("allowed", false)).is_true()
	assert_int((jammed["cancelled"] as Array).size()).is_equal(1)
	assert_int(ally_spy.cancelled.size()).is_equal(1)
	assert_array(events).contains([&"action_cancelled"])
	assert_int(controller.deferred_entries().size()).is_equal(0)
	# A committed-but-unresolved scheduler action is voided the same way (a charging Song).
	var strike: CombatAction = controller.action_by_id(&"strike")
	assert_bool(controller.scheduler.commit(ally, strike).get("allowed", false)).is_true()
	var voided := enemy_spy.request_cancel(ally.combat_id, &"committed")
	assert_bool(voided.get("allowed", false)).is_true()
	assert_bool(controller.scheduler.cancel_committed(ally, false).get("allowed", true)).is_false()


func test_partial_unit_and_fizzle_overrides_keep_the_untouched_context_keys() -> void:
	var ally_spy := V2Spy.new()
	var battle := _battle(ally_spy)
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	var enemy: BattleActor = battle["enemy"]
	var strike: CombatAction = controller.action_by_id(&"strike")
	ally_spy.forecast_override = {"unit": {"attack_scale": 1.25}, "fizzle": {"mastery": true}}
	var context: Dictionary = controller.forecast_context(ally, enemy, strike)
	assert_str(str(context["unit"]["id"])).is_equal(String(ally.combat_id))
	assert_bool(context["unit"].has("breath")).is_true()
	assert_float(float(context["unit"]["attack_scale"])).is_equal(1.25)
	assert_bool(context["fizzle"].has("patron")).is_true()
	assert_bool(context["fizzle"].has("pitch")).is_true()
	assert_bool(bool(context["fizzle"]["mastery"])).is_true()
	assert_bool(bool(context["reveal"])).is_false()


func test_reveal_and_hidden_draw_overrides_reach_forecast_and_commit_identically() -> void:
	var ally_spy := V2Spy.new()
	var battle := _battle(ally_spy)
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	var strike: CombatAction = controller.action_by_id(&"strike")
	var grid: GridBattlefieldModel = battle["grid"]
	grid.set_cover(Vector2i(0, 0), true)
	var covered := controller.forecast_action(strike, enemy)
	assert_int(int((covered["positioning"] as Dictionary)["cover_bonus"])).is_equal(
		controller.rules.cover_defense_bonus
	)
	ally_spy.forecast_override = {
		"reveal": true,
		"to_hit_enabled": false,
		"hidden_draw": {"table_id": "attribution", "seed_key": "ofshutje", "rows": [{"id": "surge", "bonus_damage": 4}]},
	}
	var forecast := controller.forecast_action(strike, enemy)
	assert_bool(forecast.get("allowed", false)).is_true()
	var forecast_resolution: Dictionary = forecast["resolution"]
	assert_bool(bool(forecast_resolution["reveal"])).is_true()
	assert_bool(forecast_resolution.has("revealed")).is_true()
	assert_int(int((forecast["positioning"] as Dictionary)["cover_bonus"])).is_equal(0)
	assert_str(str((forecast_resolution["hidden_draw"] as Dictionary)["row_id"])).is_equal("surge")
	var result := controller.submit_action(&"strike", enemy)
	assert_bool(result.get("allowed", false)).is_true()
	var committed: Dictionary = result["resolution"]
	assert_str(str((committed["hidden_draw"] as Dictionary)["row_id"])).is_equal("surge")
	assert_int(int(committed["damage"])).is_equal(int(forecast_resolution["damage"]))
	assert_bool(committed.has("revealed")).is_true()


func test_child_events_from_hooks_are_delivered_after_their_parent_in_sequence_order() -> void:
	var ally_spy := V2Spy.new()
	var battle := _battle(ally_spy)
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	ally_spy.enqueue_on_any_action = {"writes": [{"kind": "hp", "target_id": String(enemy.combat_id), "amount": 1}]}
	var delivered: Array[Dictionary] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void:
		delivered.append({"type": event.type, "sequence": event.sequence}))
	assert_bool(controller.submit_action(&"strike", enemy).get("allowed", false)).is_true()
	var types: Array[StringName] = []
	var last := -1
	for item: Dictionary in delivered:
		types.append(item["type"])
		assert_int(int(item["sequence"])).is_greater(last)
		last = int(item["sequence"])
	assert_int(types.find(&"action_resolved")).is_less(types.find(&"deferred_queued"))


func test_committed_cancel_of_the_acting_actor_is_refused_while_resolving() -> void:
	var ally_spy := V2Spy.new()
	var enemy_spy := V2Spy.new()
	var battle := _battle(ally_spy, enemy_spy)
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	var enemy: BattleActor = battle["enemy"]
	enemy_spy.cancel_on_any_action = ally.combat_id
	var result := controller.submit_action(&"strike", enemy)
	assert_bool(result.get("allowed", false)).is_true()
	assert_bool(enemy_spy.last_cancel.get("allowed", true)).is_false()
	assert_str(str(enemy_spy.last_cancel.get("blocked_by", ""))).is_equal("resolving")
	# The scheduler released cleanly: the ally can still act on its next turn.
	controller.end_turn()
	assert_bool(controller.query_action(controller.action_by_id(&"strike"), enemy).get("allowed", false)).is_true()


func test_deferred_queue_round_trips_inside_the_class_resources_save_dict() -> void:
	var ally_spy := V2Spy.new()
	var battle := _battle(ally_spy)
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	var enemy: BattleActor = battle["enemy"]
	assert_bool(controller.class_resources_to_dict().has(CombatController.DEFERRED_SAVE_KEY)).is_false()
	ally_spy.enqueue_deferred({"writes": [{"kind": "hp", "target_id": String(enemy.combat_id), "amount": 2}]}, {"delay_rounds": 1}, &"oath")
	var saved: Dictionary = controller.class_resources_to_dict()
	assert_bool(saved.has(CombatController.DEFERRED_SAVE_KEY)).is_true()
	controller.request_cancel(&"", ally.combat_id, &"deferred")
	assert_int(controller.deferred_entries().size()).is_equal(0)
	controller.restore_class_resources(saved.duplicate(true))
	var restored := controller.deferred_entries()
	assert_int(restored.size()).is_equal(1)
	assert_str(str(restored[0]["label"])).is_equal("oath")
	# A save without the key (older save) restores an empty queue.
	controller.restore_class_resources({})
	assert_int(controller.deferred_entries().size()).is_equal(0)
	# Restored entries fire like fresh ones.
	controller.restore_class_resources(saved.duplicate(true))
	var hp_before := enemy.hp
	controller.end_turn()
	assert_int(enemy.hp).is_less(hp_before)


# ─── Helpers ────────────────────────────────────────────────────────────────


func _spell_context() -> Dictionary:
	return {
		"battle_id": "seam-v2",
		"tick": 3,
		"seed": 11,
		"unit": {"id": "ally-0", "attack_scale": 1.0, "edge": 0, "breath": 20, "harmony": 0},
		"ability": {"id": "note-scor", "element_id": "scor", "elements": ["scor"], "magnitude": "note", "power": 6, "is_spell": true, "breath_cost": 3},
		"target": {"id": "enemy-0", "hp": 30, "element_id": "aqua", "edge": 0, "height": 0, "attunements": {}},
		"soul_meter": 50.0,
		"fizzle": {"agreement_integrity": 80.0, "pitch": 3},
		"caster_context": {},
	}


func _battle(ally_resource: ClassResource = null, enemy_resource: ClassResource = null) -> Dictionary:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_grid_ground())
	var ally := _actor("Ironbrand", 60, 12, 0)
	ally.source_member = PartyMember.new()
	ally.source_member.id = "ironbrand-test"
	ally.source_member.patron = "Kero"
	ally.class_resource = ally_resource
	var enemy := _actor("Dummy", 60, 1, 0)
	enemy.class_resource = enemy_resource
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	controller.start([ally], [enemy], &"seam-v2-test")
	return {"controller": controller, "ally": ally, "enemy": enemy, "grid": grid}


func _actor(name: String, hp: int, attack: int, defense: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	return actor


func _grid_ground() -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	layer.set_cell(Vector2i(0, 0), 0, Vector2i.ZERO)
	layer.set_cell(Vector2i(1, 0), 0, Vector2i.ZERO)
	return layer
