extends GdUnitTestSuite
## #223 — the ClassResource seam: registry, null resource, the Ironbrand Scars example,
## controller dispatch at the real commit points, and the additive save round-trip.


class HookSpy:
	extends ClassResource

	var calls: Array[String] = []
	var damage_amounts: Array[int] = []
	var kills: Array[String] = []
	var damage_sources: Array[String] = []
	var forecast_override: Dictionary = {}

	func on_action(event: CombatEvent) -> void:
		calls.append("action:%s" % str(event.data.get("action_id", "")))

	func on_damage_taken(amount: int, source_id: StringName) -> void:
		calls.append("damage")
		damage_amounts.append(amount)
		damage_sources.append(String(source_id))

	func on_fizzle(_resolution: Dictionary) -> void:
		calls.append("fizzle")

	func on_kill(target_id: StringName, cause: StringName) -> void:
		calls.append("kill")
		kills.append("%s:%s" % [String(target_id), String(cause)])

	func on_turn_start() -> void:
		calls.append("turn")

	func on_cast_forecast(_context: Dictionary) -> Dictionary:
		return forecast_override.duplicate(true)


# ─── Registry ───────────────────────────────────────────────────────────────


func test_registry_resolves_kero_to_ironbrand_scars_from_display_patron() -> void:
	var resource: ClassResource = ClassResourceRegistry.for_patron("Kero")
	assert_bool(resource is IronbrandScars).is_true()
	assert_str(String(resource.patron_id)).is_equal("kero")
	assert_bool(resource.is_null()).is_false()


func test_registry_normalizes_diacritics_and_case() -> void:
	assert_str(String(ClassResourceRegistry.normalize_patron("Ofshütje"))).is_equal("ofshutje")
	assert_str(String(ClassResourceRegistry.normalize_patron(" MAIIAM "))).is_equal("maiiam")
	for patron_id: StringName in ClassResourceRegistry.PATRON_IDS:
		assert_bool(ClassResourceRegistry.is_known_patron(patron_id)).is_true()


func test_registry_returns_null_resource_for_unknown_or_empty_patron() -> void:
	var unknown: ClassResource = ClassResourceRegistry.for_patron("nobody")
	assert_bool(unknown.is_null()).is_true()
	assert_str(String(unknown.patron_id)).is_empty()
	assert_bool(unknown.snapshot().is_empty()).is_true()
	assert_bool(ClassResourceRegistry.for_patron("").is_null()).is_true()
	assert_bool(ClassResourceRegistry.for_patron("Pazzah") is PazzahLedger).is_true()


func test_registry_resolves_stuid_to_clarity_from_display_patron() -> void:
	var resource: ClassResource = ClassResourceRegistry.for_patron("Stuid")
	assert_bool(resource is StuidClarity).is_true()
	assert_str(String(resource.patron_id)).is_equal("stuid")


# ─── Ironbrand Scars (worked example) ───────────────────────────────────────


func test_scars_bank_per_hit_up_to_the_cap() -> void:
	var scars := IronbrandScars.new()
	for _i in IronbrandScars.MAX_SCARS + 3:
		scars.on_damage_taken(4, &"enemy-0")
	assert_int(scars.scars).is_equal(IronbrandScars.MAX_SCARS)
	scars.on_damage_taken(0, &"enemy-0")
	assert_int(scars.scars).is_equal(IronbrandScars.MAX_SCARS)


func test_spend_scar_arms_one_guaranteed_hit_and_consumes_on_action() -> void:
	var scars := IronbrandScars.new()
	assert_bool(scars.spend_scar()).is_false()
	scars.on_damage_taken(1, &"enemy-0")
	scars.on_damage_taken(1, &"enemy-0")
	assert_bool(scars.spend_scar()).is_true()
	assert_bool(scars.spend_scar()).is_false()  # already armed: do not waste a Scar
	assert_int(scars.scars).is_equal(1)
	assert_bool(scars.on_cast_forecast({}).get("to_hit_enabled", true)).is_false()
	var move_event := CombatEvent.new()
	move_event.data = {"action_id": "move"}
	scars.on_action(move_event)
	assert_bool(scars.guaranteed_hit_armed).is_true()  # a move does not spend the window
	var strike_event := CombatEvent.new()
	strike_event.data = {"action_id": "strike", "resolution": {"allowed": true}}
	scars.on_action(strike_event)
	assert_bool(scars.guaranteed_hit_armed).is_false()
	assert_bool(scars.on_cast_forecast({}).is_empty()).is_true()


func test_scars_round_trip_through_registry_from_dict() -> void:
	var scars := IronbrandScars.new()
	scars.patron_id = &"kero"
	scars.owner_id = &"ally-0"
	scars.on_damage_taken(2, &"enemy-0")
	scars.on_damage_taken(2, &"enemy-0")
	scars.spend_scar()
	var restored: ClassResource = ClassResourceRegistry.from_dict(scars.to_dict())
	assert_bool(restored is IronbrandScars).is_true()
	var restored_scars := restored as IronbrandScars
	assert_int(restored_scars.scars).is_equal(1)
	assert_bool(restored_scars.guaranteed_hit_armed).is_true()
	assert_str(String(restored_scars.owner_id)).is_equal("ally-0")
	assert_dict(restored_scars.snapshot()).contains_key_value("label", "Scars")


func test_clarity_spend_reveals_one_forecast_and_consumes_on_resolved_action() -> void:
	var clarity := StuidClarity.new()
	assert_bool(clarity.spend_clarity()).is_true()
	assert_bool(clarity.spend_clarity()).is_false()
	assert_int(clarity.clarity).is_equal(StuidClarity.MAX_CLARITY - 1)
	assert_bool(clarity.on_cast_forecast({}).get("reveal", false)).is_true()
	var move_event := CombatEvent.new()
	move_event.data = {"action_id": "move"}
	clarity.on_action(move_event)
	assert_bool(clarity.reveal_armed).is_true()
	var cast_event := CombatEvent.new()
	cast_event.data = {"action_id": "cast", "resolution": {"allowed": true}}
	clarity.on_action(cast_event)
	assert_bool(clarity.reveal_armed).is_false()
	assert_bool(clarity.on_cast_forecast({}).is_empty()).is_true()


func test_clarity_round_trip_through_registry_from_dict() -> void:
	var clarity := StuidClarity.new()
	clarity.patron_id = &"stuid"
	clarity.owner_id = &"ally-0"
	clarity.clarity = 1
	clarity.reveal_armed = true
	var restored: ClassResource = ClassResourceRegistry.from_dict(clarity.to_dict())
	assert_bool(restored is StuidClarity).is_true()
	var restored_clarity := restored as StuidClarity
	assert_int(restored_clarity.clarity).is_equal(1)
	assert_bool(restored_clarity.reveal_armed).is_true()
	assert_str(String(restored_clarity.owner_id)).is_equal("ally-0")
	assert_dict(restored_clarity.snapshot()).contains_key_value("label", "Clarity")


func test_registry_resolves_all_wave_b_resources() -> void:
	assert_bool(ClassResourceRegistry.for_patron("Pazzah") is PazzahLedger).is_true()
	assert_bool(ClassResourceRegistry.for_patron("Fickah") is FickahRuleBreaker).is_true()
	assert_bool(ClassResourceRegistry.for_patron("Ofshütje") is OfshutjeAttribution).is_true()
	assert_bool(ClassResourceRegistry.for_patron("Izhakel") is IzhakelThreads).is_true()


func test_ledger_queues_and_resolves_entries_on_turn_hook() -> void:
	var ledger := PazzahLedger.new()
	assert_bool(ledger.queue_effect(&"verdict", 1, {"amount": 4})).is_true()
	assert_int(ledger.entries.size()).is_equal(1)
	ledger.on_turn_start()
	assert_int(ledger.entries.size()).is_equal(0)
	assert_int(ledger.ready.size()).is_equal(1)
	var resolved: Array[Dictionary] = ledger.drain_ready()
	assert_int(resolved.size()).is_equal(1)
	assert_str(str(resolved[0].get("effect_id", ""))).is_equal("verdict")
	assert_array(ledger.drain_ready()).is_empty()


func test_ledger_round_trip_through_registry_from_dict() -> void:
	var ledger := PazzahLedger.new()
	ledger.patron_id = &"pazzah"
	ledger.owner_id = &"ally-0"
	ledger.queue_effect(&"verdict", 4, {"amount": 4})
	var restored := ClassResourceRegistry.from_dict(ledger.to_dict()) as PazzahLedger
	assert_int(restored.entries.size()).is_equal(1)
	assert_int(restored.entries[0].get("turns_remaining", 0)).is_equal(4)
	assert_str(String(restored.owner_id)).is_equal("ally-0")


func test_fickah_keeps_a_pending_jam_request_until_matching_action() -> void:
	var breaker := FickahRuleBreaker.new()
	assert_bool(breaker.jam_the_gears(&"enemy-0")).is_true()
	assert_bool(breaker.jam_the_gears(&"enemy-1")).is_false()
	var unrelated := CombatEvent.new()
	unrelated.target_id = &"enemy-1"
	breaker.on_action(unrelated)
	assert_str(String(breaker.jam_target_id)).is_equal("enemy-0")
	var matching := CombatEvent.new()
	matching.target_id = &"enemy-0"
	breaker.on_action(matching)
	assert_str(String(breaker.jam_target_id)).is_empty()
	assert_float(FickahRuleBreaker.FIZZLE_FLOOR_PERCENT).is_equal(5.0)


func test_fickah_round_trip_through_registry_from_dict() -> void:
	var breaker := FickahRuleBreaker.new()
	breaker.patron_id = &"fickah"
	breaker.jam_the_gears(&"enemy-0")
	var restored := ClassResourceRegistry.from_dict(breaker.to_dict()) as FickahRuleBreaker
	assert_str(String(restored.jam_target_id)).is_equal("enemy-0")
	assert_dict(restored.snapshot()).contains_key_value("label", "Jam")


func test_attribution_draw_is_seeded_and_recorded_by_action_hook() -> void:
	var attribution := OfshutjeAttribution.new()
	var first := attribution.attribution_for(17)
	assert_bool(first.has("id")).is_true()
	assert_dict(attribution.attribution_for(17)).is_equal(first)
	var event := CombatEvent.new()
	event.data = {"resolution": {"allowed": true, "seed": 17}}
	attribution.on_action(event)
	assert_str(String(attribution.last_effect_id)).is_equal(str(first["id"]))
	assert_int(attribution.last_effect_floor).is_equal(int(first["floor"]))


func test_attribution_round_trip_through_registry_from_dict() -> void:
	var attribution := OfshutjeAttribution.new()
	attribution.patron_id = &"ofshutje"
	attribution.last_effect_id = &"fork"
	attribution.last_effect_floor = 2
	var restored := ClassResourceRegistry.from_dict(attribution.to_dict()) as OfshutjeAttribution
	assert_str(String(restored.last_effect_id)).is_equal("fork")
	assert_int(restored.last_effect_floor).is_equal(2)


func test_threads_bind_and_trigger_matching_hidden_condition() -> void:
	var threads := IzhakelThreads.new()
	assert_bool(threads.bind_thread(&"enemy-0", {"action_id": "strike"}, {"effect_id": "payoff"})).is_true()
	var other := CombatEvent.new()
	other.actor_id = &"enemy-0"
	other.data = {"action_id": "move"}
	threads.on_action(other)
	assert_bool(threads.threads[0].get("triggered", false)).is_false()
	var strike := CombatEvent.new()
	strike.actor_id = &"enemy-0"
	strike.data = {"action_id": "strike"}
	threads.on_action(strike)
	assert_bool(threads.threads[0].get("triggered", false)).is_true()


func test_threads_round_trip_through_registry_from_dict() -> void:
	var threads := IzhakelThreads.new()
	threads.patron_id = &"izhakel"
	threads.bind_thread(&"enemy-0", {"action_id": "strike"}, {"effect_id": "payoff"})
	var restored := ClassResourceRegistry.from_dict(threads.to_dict()) as IzhakelThreads
	assert_int(restored.threads.size()).is_equal(1)
	assert_str(str(restored.threads[0].get("target_id", ""))).is_equal("enemy-0")


# ─── Controller dispatch ────────────────────────────────────────────────────


func test_controller_attaches_from_party_member_patron_and_null_for_enemies() -> void:
	var battle := _battle()
	var ally: BattleActor = battle["ally"]
	var enemy: BattleActor = battle["enemy"]
	assert_bool(ally.class_resource is IronbrandScars).is_true()
	assert_str(String(ally.class_resource.owner_id)).is_equal(String(ally.combat_id))
	assert_bool(enemy.class_resource.is_null()).is_true()
	var controller: CombatController = battle["controller"]
	var snapshot: Dictionary = controller.snapshot()
	var ally_snapshot: Dictionary = (snapshot["allies"] as Array)[0]
	assert_dict(ally_snapshot["class_resource"]).contains_key_value("label", "Scars")


func test_controller_fires_turn_action_damage_and_kill_hooks_at_commit_points() -> void:
	var ally_spy := HookSpy.new()
	var enemy_spy := HookSpy.new()
	var battle := _battle(ally_spy, enemy_spy)
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	assert_array(ally_spy.calls).contains(["turn"])

	var first := controller.submit_action(&"strike", enemy)
	assert_bool(first.get("allowed", false)).is_true()
	assert_array(ally_spy.calls).contains(["action:strike"])
	assert_array(enemy_spy.calls).contains(["damage"])
	assert_int(enemy_spy.damage_amounts[0]).is_greater(0)
	assert_str(enemy_spy.damage_sources[0]).is_equal(String((battle["ally"] as BattleActor).combat_id))
	assert_bool(ally_spy.calls.has("kill")).is_false()

	# Bring the enemy to the brink and finish it: the killer's on_kill fires with the cause.
	enemy.hp = 1
	for _round in 6:
		if not enemy.is_alive():
			break
		var again := controller.submit_action(&"strike", enemy)
		if not bool(again.get("allowed", false)):
			controller.end_turn()
	assert_bool(enemy.is_alive()).is_false()
	assert_array(ally_spy.kills).contains(["%s:attack" % String(enemy.combat_id)])


func test_cast_forecast_override_reaches_the_shared_resolution_context() -> void:
	var ally_spy := HookSpy.new()
	var battle := _battle(ally_spy)
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	var enemy: BattleActor = battle["enemy"]
	var strike: CombatAction = controller.action_by_id(&"strike")
	var plain: Dictionary = controller.forecast_context(ally, enemy, strike)
	assert_bool(plain.get("to_hit_enabled", false)).is_true()
	ally_spy.forecast_override = {"to_hit_enabled": false}
	var armed: Dictionary = controller.forecast_context(ally, enemy, strike)
	assert_bool(armed.get("to_hit_enabled", true)).is_false()
	# Forecast and commit read the same context, so the committed resolution carries the override.
	var forecast := controller.forecast_action(strike, enemy)
	var result := controller.submit_action(&"strike", enemy)
	assert_bool(result.get("allowed", false)).is_true()
	var committed: Dictionary = result.get("resolution", {})
	assert_bool(bool(committed.get("hit", false))).is_true()
	assert_int(int(committed.get("hit_chance", 0))).is_equal(int(forecast["resolution"]["hit_chance"]))


func test_controller_class_resources_round_trip_by_combat_id() -> void:
	var battle := _battle()
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	var scars := ally.class_resource as IronbrandScars
	scars.on_damage_taken(3, &"enemy-0")
	scars.on_damage_taken(3, &"enemy-0")
	var saved: Dictionary = controller.class_resources_to_dict()
	assert_bool(saved.has(String(ally.combat_id))).is_true()
	assert_int(saved.size()).is_equal(1)  # the Null enemy resource is not persisted
	scars.scars = 0
	controller.restore_class_resources(saved.duplicate(true))
	assert_int((ally.class_resource as IronbrandScars).scars).is_equal(2)
	assert_str(String(ally.class_resource.owner_id)).is_equal(String(ally.combat_id))


func test_battle_restore_is_deferred_until_a_controller_exists() -> void:
	assert_bool(Battle.class_resources_to_dict().is_empty()).is_true()
	Battle.restore_class_resources({"ally-x": {"patron_id": "kero", "scars": 1}})
	assert_bool(Battle._pending_class_resources.has("ally-x")).is_true()
	Battle._pending_class_resources.clear()


# ─── Helpers ────────────────────────────────────────────────────────────────


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
	controller.start([ally], [enemy], &"class-resource-test")
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
