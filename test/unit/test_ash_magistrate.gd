extends GdUnitTestSuite
## Fire substrate (Burning, Soaked, Firebreak lines, delayed releases), the Khash and polearm
## cards that ride on it, and the Ash Magistrate kit (Sentence of Ash, Herd, Verdict by Fire).

const NO_FIZZLE := {"fizzle": {"harmonic_accord": 100.0, "pitch": 10}}


# ─── FireField unit ─────────────────────────────────────────────────────────


func test_burning_refreshes_instead_of_stacking_and_soaked_refuses_it() -> void:
	var actor := _actor("Wick", 20, 1, 0)
	var first: Dictionary = FireField.apply_burning(actor, &"a")
	assert_bool(first["applied"]).is_true()
	assert_bool(first["refreshed"]).is_false()
	FireField.consume_burn_tick(actor)
	var second: Dictionary = FireField.apply_burning(actor, &"b")
	assert_bool(second["refreshed"]).is_true()
	assert_int(int((actor.impositions["burning"] as Dictionary)["remaining_ticks"])).is_equal(FireField.BURNING_TICKS)
	assert_str(String(FireField.burn_source_id(actor))).is_equal("b")
	FireField.clear_burning(actor)
	FireField.apply_soaked(actor)
	var refused: Dictionary = FireField.apply_burning(actor, &"a")
	assert_bool(refused["applied"]).is_false()
	assert_str(str(refused["reason"])).is_equal("soaked")
	assert_bool(FireField.age_soaked(actor)).is_false()
	assert_bool(FireField.age_soaked(actor)).is_true()
	assert_bool(FireField.is_soaked(actor)).is_false()


func test_cardinal_line_shape_and_line_expiry() -> void:
	assert_bool(FireField.is_cardinal_line(_cells([[1, 1], [2, 1], [3, 1]]))).is_true()
	assert_bool(FireField.is_cardinal_line(_cells([[3, 1], [1, 1], [2, 1]]))).is_true()
	assert_bool(FireField.is_cardinal_line(_cells([[1, 1], [2, 2], [3, 3]]))).is_false()
	assert_bool(FireField.is_cardinal_line(_cells([[1, 1], [2, 1], [4, 1]]))).is_false()
	var field := FireField.new()
	var created: Dictionary = field.create_line(&"a", _cells([[1, 1], [2, 1], [3, 1]]), 1)
	assert_bool(created["allowed"]).is_true()
	assert_bool(field.is_burning_cell(Vector2i(2, 1))).is_true()
	assert_int(field.advance_checkpoint().size()).is_equal(0)
	assert_int(field.advance_checkpoint().size()).is_equal(1)
	assert_bool(field.is_empty()).is_true()


# ─── Khash cards ────────────────────────────────────────────────────────────


func test_kindle_is_range_gated_and_sets_burning_on_hit() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(5, 1)})
	var controller: CombatController = battle["controller"]
	var kindle := controller.action_by_id(&"kindle")
	var far := controller.query_action(kindle, battle["enemy"], NO_FIZZLE)
	assert_bool(far["allowed"]).is_false()
	assert_str(String(far["blocked_by"])).is_equal("blocked_by_range")
	battle["grid"].displace(battle["enemy"], Vector2i(3, 1))
	var near := controller.query_action(kindle, battle["enemy"], NO_FIZZLE)
	assert_bool(near["allowed"]).is_true()
	assert_int(int(near["breath_cost"])).is_equal(3)
	var breath_before: int = battle["ally"].breath
	var hp_before: int = battle["enemy"].hp
	var outcome := controller.submit_action(&"kindle", battle["enemy"], NO_FIZZLE)
	assert_bool(outcome["allowed"]).is_true()
	assert_bool(bool((outcome["resolution"] as Dictionary)["fizzled"])).is_false()
	assert_bool(bool(outcome["hit"])).is_true()
	assert_int(battle["enemy"].hp).is_less(hp_before)
	assert_int(battle["ally"].breath).is_equal(breath_before - 3)
	assert_bool(FireField.is_burning(battle["enemy"])).is_true()
	assert_bool(_saw(battle, &"burning_applied")).is_true()


func test_burning_ticks_three_hp_at_the_next_two_checkpoints_then_ends() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	enemy.attack = 0
	controller.submit_action(&"kindle", enemy, NO_FIZZLE)
	var after_strike := enemy.hp
	_end_round(battle)
	assert_int(enemy.hp).is_equal(after_strike - FireField.BURN_TICK_DAMAGE)
	assert_bool(FireField.is_burning(enemy)).is_true()
	_end_round(battle)
	assert_int(enemy.hp).is_equal(after_strike - 2 * FireField.BURN_TICK_DAMAGE)
	assert_bool(FireField.is_burning(enemy)).is_false()
	_end_round(battle)
	assert_int(enemy.hp).is_equal(after_strike - 2 * FireField.BURN_TICK_DAMAGE)
	assert_int(_count(battle, &"burn_tick")).is_equal(2)


func test_firebreak_needs_a_cardinal_line_within_range_and_burns_its_occupant() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	enemy.attack = 0
	var firebreak := controller.action_by_id(&"firebreak")
	var bent := controller.query_action(firebreak, null, _with_cells([[2, 0], [3, 1], [4, 2]]))
	assert_str(String(bent["blocked_by"])).is_equal("line_shape")
	var far := controller.query_action(firebreak, null, _with_cells([[5, 0], [5, 1], [5, 2]]))
	assert_str(String(far["blocked_by"])).is_equal("blocked_by_range")
	var forecast := controller.forecast_action(firebreak, null, _with_cells([[3, 0], [3, 1], [3, 2]]))
	assert_bool(forecast["allowed"]).is_true()
	assert_bool(bool(forecast["cell_working"])).is_true()
	assert_int((forecast["cells"] as Array).size()).is_equal(3)
	var hp_before := enemy.hp
	var outcome := controller.submit_action(&"firebreak", null, _with_cells([[3, 0], [3, 1], [3, 2]]))
	assert_bool(outcome["allowed"]).is_true()
	assert_bool(controller.fire.is_burning_cell(Vector2i(3, 2))).is_true()
	# Standing in a new Firebreak is a hazard event: 3 HP and Burning at once.
	assert_int(enemy.hp).is_equal(hp_before - FireField.HAZARD_DAMAGE)
	assert_bool(FireField.is_burning(enemy)).is_true()
	assert_int((controller.snapshot()["fire"]["lines"] as Array).size()).is_equal(1)
	_end_round(battle)
	assert_int(controller.fire.lines.size()).is_equal(1)
	_end_round(battle)
	assert_int(controller.fire.lines.size()).is_equal(0)
	assert_bool(_saw(battle, &"fire_line_expired")).is_true()


func test_hazard_fires_once_per_creature_per_round() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	controller.submit_action(&"firebreak", null, _with_cells([[3, 0], [3, 1], [3, 2]]))
	var after_first := enemy.hp
	# A second hazard inside the same round is refused; the checkpoint then ticks Burning only.
	var again := controller._apply_hazard(enemy, Vector2i(3, 1))
	assert_bool(bool(again["applied"])).is_false()
	assert_int(enemy.hp).is_equal(after_first)


func test_douse_clears_burning_and_soaked_refuses_a_new_kindle() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	controller.submit_action(&"kindle", enemy, NO_FIZZLE)
	assert_bool(FireField.is_burning(enemy)).is_true()
	var hp_before := enemy.hp
	var douse := controller.submit_action(&"douse", enemy, NO_FIZZLE)
	assert_bool(douse["allowed"]).is_true()
	assert_int(enemy.hp).is_equal(hp_before)
	assert_bool(FireField.is_burning(enemy)).is_false()
	assert_bool(FireField.is_soaked(enemy)).is_true()
	_end_round(battle)
	var rekindle := controller.submit_action(&"kindle", enemy, NO_FIZZLE)
	assert_bool(rekindle["allowed"]).is_true()
	assert_bool(FireField.is_burning(enemy)).is_false()
	assert_str(str((rekindle["burning"] as Dictionary)["reason"])).is_equal("soaked")


func test_douse_can_target_an_ally() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	FireField.apply_burning(ally, &"enemy")
	var douse := controller.query_action(controller.action_by_id(&"douse"), ally, NO_FIZZLE)
	assert_bool(douse["allowed"]).is_true()


# ─── Polearm cards ──────────────────────────────────────────────────────────


func test_thrust_reaches_two_cells_and_not_three() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var thrust := controller.action_by_id(&"thrust")
	var far := controller.query_action(thrust, battle["enemy"])
	assert_str(String(far["blocked_by"])).is_equal("blocked_by_range")
	battle["grid"].displace(battle["enemy"], Vector2i(2, 1))
	assert_bool(controller.query_action(thrust, battle["enemy"])["allowed"]).is_true()
	var hp_before: int = battle["enemy"].hp
	controller.submit_action(&"thrust", battle["enemy"])
	assert_int(battle["enemy"].hp).is_less(hp_before)


func test_hook_and_draw_pulls_one_cell_for_zero_damage() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(2, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	var hook := controller.action_by_id(&"hook-and-draw")
	var hp_before := enemy.hp
	var outcome := controller.submit_action(&"hook-and-draw", enemy)
	assert_bool(outcome["allowed"]).is_true()
	assert_int(enemy.hp).is_equal(hp_before)
	assert_bool(bool(outcome["pulled"])).is_true()
	assert_object(battle["grid"].cell_of(enemy)).is_equal(Vector2i(1, 1))
	assert_bool(_saw(battle, &"combatant_pulled")).is_true()
	# Now adjacent: the geometry gate refuses.
	var adjacent := controller.query_action(hook, enemy)
	assert_str(String(adjacent["blocked_by"])).is_equal("pull_geometry")


func test_hook_and_draw_refuses_a_burning_destination_but_herd_allows_it() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(2, 1)}, "Pazzah", 0)
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	enemy.attack = 0
	controller.submit_action(&"firebreak", null, _with_cells([[1, 0], [1, 1], [1, 2]]))
	var hook := controller.query_action(controller.action_by_id(&"hook-and-draw"), enemy)
	assert_str(String(hook["blocked_by"])).is_equal("pull_destination")
	var herd := controller.query_action(controller.action_by_id(&"herd"), enemy)
	assert_bool(herd["allowed"]).is_true()
	var hp_before := enemy.hp
	var outcome := controller.submit_action(&"herd", enemy)
	assert_bool(bool(outcome["pulled"])).is_true()
	assert_object(battle["grid"].cell_of(enemy)).is_equal(Vector2i(1, 1))
	# Dragged into fire: the hazard lands immediately.
	assert_int(enemy.hp).is_equal(hp_before - FireField.HAZARD_DAMAGE)
	assert_bool(FireField.is_burning(enemy)).is_true()


func test_herd_needs_the_pazzah_kit_and_the_chord_gate() -> void:
	var stranger := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(2, 1)}, "Kero")
	var refused: Dictionary = stranger["controller"].query_action(stranger["controller"].action_by_id(&"herd"), stranger["enemy"])
	assert_str(String(refused["blocked_by"])).is_equal("class_resource")
	var discordant := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(2, 1)}, "Pazzah", -1)
	var gated: Dictionary = discordant["controller"].query_action(discordant["controller"].action_by_id(&"herd"), discordant["enemy"])
	assert_bool(gated["allowed"]).is_false()
	assert_str(String(gated["blocked_by"])).is_equal("var_harmony")


# ─── Ash Magistrate kit ─────────────────────────────────────────────────────


func test_sentence_of_ash_files_a_ledger_entry_and_ignites_two_rounds_later() -> void:
	# Adjacent to the party, the enemy AI strikes instead of walking off the marked cells.
	var battle := _battle({"ally": Vector2i(2, 1), "enemy": Vector2i(3, 1)}, "Pazzah", 0)
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	enemy.attack = 0
	var cells := _with_cells([[3, 0], [3, 1], [3, 2]])
	cells.merge(NO_FIZZLE)
	var outcome := controller.submit_action(&"sentence-of-ash", null, cells)
	assert_bool(outcome["allowed"]).is_true()
	assert_bool(bool(outcome["filed"])).is_true()
	var ledger := battle["ally"].class_resource as PazzahLedger
	assert_int(ledger.entries.size()).is_equal(1)
	assert_bool(controller.fire.is_empty()).is_true()
	var marks: Array = controller.snapshot()["fire"]["marks"]
	assert_int(marks.size()).is_equal(1)
	assert_int((marks[0]["cells"] as Array).size()).is_equal(3)
	var hp_before := enemy.hp
	_end_round(battle)
	_end_round(battle)
	assert_bool(controller.fire.is_burning_cell(Vector2i(3, 1))).is_true()
	assert_int(ledger.entries.size()).is_equal(0)
	assert_int(enemy.hp).is_equal(hp_before - FireField.HAZARD_DAMAGE)
	assert_bool(FireField.is_burning(enemy)).is_true()
	assert_int((controller.snapshot()["fire"]["marks"] as Array).size()).is_equal(0)


func test_sentence_of_ash_needs_the_ledger_and_a_free_entry_and_the_jam_cancels_it() -> void:
	var stranger := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(5, 1)}, "Kero")
	var stranger_cells := _with_cells([[3, 0], [3, 1], [3, 2]])
	stranger_cells.merge(NO_FIZZLE)
	var refused: Dictionary = stranger["controller"].query_action(stranger["controller"].action_by_id(&"sentence-of-ash"), null, stranger_cells)
	assert_str(String(refused["blocked_by"])).is_equal("class_resource")
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(5, 1)}, "Pazzah", 0)
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	ally.breath = 100
	var ledger := ally.class_resource as PazzahLedger
	for _i: int in PazzahLedger.MAX_ENTRIES:
		ledger.queue_effect(&"filler", 3, {"writes": [{"kind": "hp", "target_id": String(battle["enemy"].combat_id), "amount": 1}]})
	assert_int(ledger.entries.size()).is_equal(PazzahLedger.MAX_ENTRIES)
	var full := controller.query_action(controller.action_by_id(&"sentence-of-ash"), null, stranger_cells)
	assert_str(String(full["blocked_by"])).is_equal("ledger_full")
	var cancelled := controller.request_cancel(battle["enemy"].combat_id, ally.combat_id, &"deferred")
	assert_bool(cancelled["allowed"]).is_true()
	assert_int(ledger.entries.size()).is_equal(0)
	controller.submit_action(&"sentence-of-ash", null, stranger_cells)
	assert_int((controller.snapshot()["fire"]["marks"] as Array).size()).is_equal(1)
	controller.request_cancel(battle["enemy"].combat_id, ally.combat_id, &"deferred")
	assert_int((controller.snapshot()["fire"]["marks"] as Array).size()).is_equal(0)
	_end_round(battle)
	_end_round(battle)
	assert_bool(controller.fire.is_empty()).is_true()


func test_crown_of_embers_releases_at_the_casters_next_turn_and_spends_the_refrain() -> void:
	var battle := _battle({"ally": Vector2i(2, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	enemy.attack = 0
	var cells := _with_cells([[3, 0], [3, 1], [3, 2]])
	cells.merge(NO_FIZZLE)
	var outcome := controller.submit_action(&"crown-of-embers", null, cells)
	assert_bool(outcome["allowed"]).is_true()
	assert_bool(bool(outcome["queued"])).is_true()
	var hp_before := enemy.hp
	var again := controller.query_action(controller.action_by_id(&"crown-of-embers"), null, cells)
	assert_str(String(again["blocked_by"])).is_equal("refrain_spent")
	_end_round(battle)
	assert_bool(_saw(battle, &"crown_released")).is_true()
	assert_int(enemy.hp).is_less(hp_before)
	assert_bool(FireField.is_burning(enemy)).is_true()
	assert_int(controller.deferred_entries().size()).is_equal(0)


func test_crown_of_embers_breaks_when_the_caster_moves() -> void:
	var battle := _battle({"ally": Vector2i(2, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	enemy.attack = 0
	var cells := _with_cells([[3, 0], [3, 1], [3, 2]])
	cells.merge(NO_FIZZLE)
	controller.submit_action(&"crown-of-embers", null, cells)
	battle["grid"].displace(battle["ally"], Vector2i(2, 0))
	var hp_before := enemy.hp
	_end_round(battle)
	assert_bool(_saw(battle, &"crown_interrupted")).is_true()
	assert_bool(_saw(battle, &"crown_released")).is_false()
	assert_int(enemy.hp).is_equal(hp_before)


func test_verdict_by_fire_needs_the_triad_gate_and_fires_at_the_ledger_beat_untethered() -> void:
	var discordant := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)}, "Pazzah", 0)
	var cells := _with_cells([[3, 0], [3, 1], [3, 2]])
	cells.merge(NO_FIZZLE)
	var gated: Dictionary = discordant["controller"].query_action(discordant["controller"].action_by_id(&"verdict-by-fire"), null, cells)
	assert_str(String(gated["blocked_by"])).is_equal("var_harmony")
	var battle := _battle({"ally": Vector2i(2, 1), "enemy": Vector2i(3, 1)}, "Pazzah", 2)
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	enemy.attack = 0
	var outcome := controller.submit_action(&"verdict-by-fire", null, cells)
	assert_bool(outcome["allowed"]).is_true()
	assert_bool(bool(outcome["filed"])).is_true()
	var ledger := battle["ally"].class_resource as PazzahLedger
	assert_int(ledger.entries.size()).is_equal(1)
	battle["grid"].displace(battle["ally"], Vector2i(2, 0))
	var hp_before := enemy.hp
	_end_round(battle)
	assert_int(enemy.hp).is_equal(hp_before)
	_end_round(battle)
	assert_bool(_saw(battle, &"crown_released")).is_true()
	assert_int(enemy.hp).is_less(hp_before)
	assert_int(ledger.entries.size()).is_equal(0)


func test_a_checkpoint_kill_of_the_next_actor_does_not_lose_the_battle() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	enemy.hp = 2
	enemy.attack = 0
	FireField.apply_burning(enemy, battle["ally"].combat_id)
	# The enemy is alive through its own turn; the round-end burn tick kills it.
	controller.end_turn()
	assert_bool(enemy.is_alive()).is_false()
	assert_int(controller.state).is_equal(CombatController.State.FINISHED)


func test_fire_and_impositions_round_trip_through_class_resource_save_data() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)}, "Pazzah", 0)
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	controller.submit_action(&"firebreak", null, _with_cells([[3, 0], [3, 1], [3, 2]]))
	var data := controller.class_resources_to_dict()
	assert_bool(data.has(CombatController.FIRE_SAVE_KEY)).is_true()
	assert_bool(data.has(CombatController.IMPOSITIONS_SAVE_KEY)).is_true()
	var json := JSON.parse_string(JSON.stringify(data)) as Dictionary
	var restored := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)}, "Pazzah", 0)
	var restored_controller: CombatController = restored["controller"]
	restored_controller.restore_class_resources(json)
	assert_bool(restored_controller.fire.is_burning_cell(Vector2i(3, 2))).is_true()
	assert_int(int((restored_controller.fire.lines[0] as Dictionary)["remaining_checkpoints"])).is_equal(FireField.LINE_DURATION_CHECKPOINTS)
	assert_bool(FireField.is_burning(restored["enemy"])).is_true()
	assert_str(String(FireField.burn_source_id(restored["enemy"]))).is_equal(String(battle["ally"].combat_id))


# ─── Helpers ────────────────────────────────────────────────────────────────


func _battle(cells: Dictionary, patron: String = "Pazzah", harmony: int = 0) -> Dictionary:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	# Eight AP a turn so a card and a follow-up fit in one party turn.
	rules.base_action_points = 8
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_grid_ground())
	var ally := _actor("Magistrate", 60, 12, 0)
	ally.breath = 60
	ally.attributes = {"harmony": harmony, "alacrity": 4}
	ally.defining_effects = {"hit": true}
	ally.source_member = PartyMember.new()
	ally.source_member.id = "magistrate-test"
	ally.source_member.patron = patron
	var enemy := _actor("Dummy", 60, 1, 0)
	assert_bool(grid.configure_initial_cells({ally: cells["ally"], enemy: cells["enemy"]})["allowed"]).is_true()
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	var events: Array[StringName] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event.type))
	controller.start([ally], [enemy], &"ash-magistrate-test")
	return {"controller": controller, "ally": ally, "enemy": enemy, "grid": grid, "events": events}


## Ends the party turn; the AP scheduler then runs the enemy and closes the round, which is
## one fire checkpoint. Returns once the party is back in control.
func _end_round(battle: Dictionary) -> void:
	var controller: CombatController = battle["controller"]
	assert_bool(controller.end_turn()).is_true()
	assert_int(controller.state).is_equal(CombatController.State.ALLY_TURN)


func _saw(battle: Dictionary, type: StringName) -> bool:
	return (battle["events"] as Array[StringName]).has(type)


func _count(battle: Dictionary, type: StringName) -> int:
	return (battle["events"] as Array[StringName]).count(type)


func _with_cells(cells: Array) -> Dictionary:
	var data: Array[Dictionary] = []
	for pair: Array in cells:
		data.append({"x": int(pair[0]), "y": int(pair[1])})
	return {"cells": data}


func _cells(pairs: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pair: Array in pairs:
		out.append(Vector2i(int(pair[0]), int(pair[1])))
	return out


func _actor(name: String, hp: int, attack: int, defense: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	return actor


## Seven by three cells, flat.
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
	for x: int in 7:
		for y: int in 3:
			layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	return layer
