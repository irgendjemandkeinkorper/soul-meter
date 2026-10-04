extends GdUnitTestSuite
## Light substrate (Exposed, Veiled, Witness Light fields, Noonday), the Sul/Vekh and fist
## cards on it, and the Witness Weaver kit (Term of Witness, Term of Daylight, Noon Contract).

const NO_FIZZLE := {"fizzle": {"harmonic_accord": 100.0, "pitch": 10}}


# ─── LightField unit ────────────────────────────────────────────────────────


func test_exposed_tears_a_veil_and_a_veil_cannot_cover_exposed() -> void:
	var actor := _actor("Wisp", 20, 1, 0)
	assert_bool(bool(LightField.apply_veiled(actor, &"a")["applied"])).is_true()
	var exposed: Dictionary = LightField.apply_exposed(actor, &"b")
	assert_bool(bool(exposed["applied"])).is_true()
	assert_bool(bool(exposed["unveiled"])).is_true()
	assert_bool(LightField.is_veiled(actor)).is_false()
	var refused: Dictionary = LightField.apply_veiled(actor, &"a")
	assert_bool(bool(refused["applied"])).is_false()
	assert_str(str(refused["reason"])).is_equal("exposed")
	assert_bool(LightField.age(actor, LightField.IMPOSITION_EXPOSED)).is_false()
	assert_bool(LightField.age(actor, LightField.IMPOSITION_EXPOSED)).is_true()
	assert_bool(LightField.is_exposed(actor)).is_false()


func test_fields_cover_a_radius_and_expire() -> void:
	var field := LightField.new()
	var created: Dictionary = field.create_field(&"a", Vector2i(3, 1), 1, 1)
	assert_bool(bool(created["allowed"])).is_true()
	assert_bool(field.is_lit_cell(Vector2i(2, 0))).is_true()
	assert_bool(field.is_lit_cell(Vector2i(4, 2))).is_true()
	assert_bool(field.is_lit_cell(Vector2i(5, 1))).is_false()
	assert_int(field.advance_checkpoint().size()).is_equal(0)
	assert_int(field.advance_checkpoint().size()).is_equal(1)
	assert_bool(field.is_empty()).is_true()


# ─── Sul / Vekh cards ───────────────────────────────────────────────────────


func test_unveil_exposes_and_reveals_a_veiled_signature_without_damage() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	LightField.apply_veiled(enemy, &"someone")
	enemy.last_cast_element = &"vekh"
	var hp_before := enemy.hp
	var outcome := controller.submit_action(&"unveil", enemy, NO_FIZZLE)
	assert_bool(outcome["allowed"]).is_true()
	assert_int(enemy.hp).is_equal(hp_before)
	assert_bool(LightField.is_exposed(enemy)).is_true()
	assert_bool(LightField.is_veiled(enemy)).is_false()
	assert_bool(bool((outcome["revealed"] as Dictionary)["was_veiled"])).is_true()
	assert_str(str((outcome["revealed"] as Dictionary)["last_cast_element"])).is_equal("vekh")
	assert_bool(_saw(battle, &"signature_revealed")).is_true()
	var row := _snapshot_row(controller, enemy)
	assert_bool(bool(row["exposed"])).is_true()
	assert_bool(bool(row["discord_signatures_visible"])).is_true()
	_end_round(battle)
	_end_round(battle)
	assert_bool(LightField.is_exposed(enemy)).is_false()


func test_exposed_negates_cover() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	battle["grid"].set_cover(Vector2i(2, 1), true)
	var covered := controller._positional_terms(battle["ally"], enemy)
	assert_int(int(covered["cover_bonus"])).is_greater(0)
	LightField.apply_exposed(enemy, battle["ally"].combat_id)
	var exposed := controller._positional_terms(battle["ally"], enemy)
	assert_int(int(exposed["cover_bonus"])).is_equal(0)


func test_veil_hides_an_ally_and_is_refused_over_exposed() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	var outcome := controller.submit_action(&"veil", ally, NO_FIZZLE)
	assert_bool(outcome["allowed"]).is_true()
	assert_bool(LightField.is_veiled(ally)).is_true()
	assert_bool(bool(_snapshot_row(controller, ally)["discord_signatures_visible"])).is_false()
	LightField.apply_exposed(ally, &"enemy")
	var refused := controller.submit_action(&"veil", ally, NO_FIZZLE)
	assert_bool(refused["allowed"]).is_true()
	assert_str(str((refused["veiled"] as Dictionary)["reason"])).is_equal("exposed")


func test_witness_light_exposes_occupants_only_while_inside() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	var outcome := controller.submit_action(&"witness-light", null, _with_cells([[3, 1]], NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	assert_int(controller.light.fields.size()).is_equal(1)
	assert_bool(bool(_snapshot_row(controller, enemy)["exposed"])).is_true()
	assert_bool(LightField.is_exposed(enemy)).is_false()
	battle["grid"].displace(enemy, Vector2i(5, 1))
	assert_bool(bool(_snapshot_row(controller, enemy)["exposed"])).is_false()
	assert_int((controller.snapshot()["light"]["fields"] as Array).size()).is_equal(1)
	_end_round(battle)
	_end_round(battle)
	assert_bool(controller.light.is_empty()).is_true()
	assert_bool(_saw(battle, &"light_field_expired")).is_true()


func test_noonday_reveals_everyone_in_the_radius_for_one_checkpoint() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(4, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	enemy.attack = 0
	enemy.discovered_weakness_ids = [&"old-wound"]
	var outcome := controller.submit_action(&"noonday-revelation", null, _with_cells([[3, 1]], NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	assert_array(outcome["revealed"]).contains([String(enemy.combat_id)])
	assert_bool(LightField.is_exposed(enemy)).is_true()
	assert_bool(_saw(battle, &"noonday_revelation")).is_true()
	var again := controller.query_action(controller.action_by_id(&"noonday-revelation"), null, _with_cells([[3, 1]], NO_FIZZLE))
	assert_str(String(again["blocked_by"])).is_equal("refrain_spent")
	_end_round(battle)
	assert_bool(LightField.is_exposed(enemy)).is_false()


# ─── Fists ──────────────────────────────────────────────────────────────────


func test_close_strike_needs_adjacency() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(2, 1)})
	var controller: CombatController = battle["controller"]
	var far := controller.query_action(controller.action_by_id(&"close-strike"), battle["enemy"])
	assert_bool(far["allowed"]).is_false()
	battle["grid"].displace(battle["enemy"], Vector2i(1, 1))
	var hp_before: int = battle["enemy"].hp
	assert_bool(controller.submit_action(&"close-strike", battle["enemy"])["allowed"]).is_true()
	assert_int(battle["enemy"].hp).is_less(hp_before)


func test_shove_pushes_one_cell_away_for_zero_damage() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(1, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	var hp_before := enemy.hp
	var outcome := controller.submit_action(&"shove", enemy)
	assert_bool(outcome["allowed"]).is_true()
	assert_bool(bool(outcome["pushed"])).is_true()
	assert_int(enemy.hp).is_equal(hp_before)
	assert_object(battle["grid"].cell_of(enemy)).is_equal(Vector2i(2, 1))
	assert_bool(_saw(battle, &"combatant_pushed")).is_true()


func test_shove_is_refused_when_the_cell_behind_is_blocked() -> void:
	var battle := _battle({"ally": Vector2i(5, 1), "enemy": Vector2i(6, 1)})
	var controller: CombatController = battle["controller"]
	var refused := controller.query_action(controller.action_by_id(&"shove"), battle["enemy"])
	assert_str(String(refused["blocked_by"])).is_equal("push_destination")


func test_unseat_ends_a_guard_and_needs_one() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(1, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	var no_guard := controller.query_action(controller.action_by_id(&"unseat"), enemy)
	assert_str(String(no_guard["blocked_by"])).is_equal("no_response")
	enemy.guarding = true
	var outcome := controller.submit_action(&"unseat", enemy)
	assert_bool(outcome["allowed"]).is_true()
	assert_bool(bool(outcome["unseated"])).is_true()
	assert_bool(enemy.guarding).is_false()


# ─── Witness Weaver kit ─────────────────────────────────────────────────────


func test_term_of_witness_pays_information_on_the_targets_next_attack() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(1, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	LightField.apply_veiled(enemy, &"someone")
	var threads := battle["ally"].class_resource as IzhakelThreads
	var outcome := controller.submit_action(&"term-of-witness", enemy)
	assert_bool(outcome["allowed"]).is_true()
	assert_int(threads.threads.size()).is_equal(1)
	assert_str(str(threads.threads[0]["kind"])).is_equal("witness")
	var duplicate := controller.query_action(controller.action_by_id(&"term-of-witness"), enemy)
	assert_str(String(duplicate["blocked_by"])).is_equal("class_resource_duplicate")
	var ally_hp: int = battle["ally"].hp
	# The enemy's turn: adjacent, it strikes — the contract triggers and pays in revelation.
	_end_round(battle)
	assert_bool(LightField.is_exposed(enemy)).is_true()
	assert_bool(LightField.is_veiled(enemy)).is_false()
	assert_bool(_saw(battle, &"signature_revealed")).is_true()
	assert_int(threads.threads.size()).is_equal(0)
	# No damage payoff: the only HP the enemy lost is none; the ally took the ordinary strike.
	assert_int(enemy.hp).is_equal(enemy.max_hp)
	assert_int(battle["ally"].hp).is_less_equal(ally_hp)


func test_term_of_witness_needs_the_izhakel_kit() -> void:
	var stranger := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(1, 1)}, "Kero")
	var refused: Dictionary = stranger["controller"].query_action(stranger["controller"].action_by_id(&"term-of-witness"), stranger["enemy"])
	assert_str(String(refused["blocked_by"])).is_equal("class_resource")


func test_term_of_daylight_binds_a_move_into_the_field_and_the_light_follows() -> void:
	# The enemy touches the Weaver diagonally, off the sight line to the field center.
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(1, 0)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	enemy.attack = 0
	var threads := battle["ally"].class_resource as IzhakelThreads
	var far := controller.query_action(controller.action_by_id(&"term-of-daylight"), null, _with_cells([[3, 1]], NO_FIZZLE))
	assert_str(String(far["blocked_by"])).is_equal("no_target")
	var outcome := controller.submit_action(&"term-of-daylight", enemy, _with_cells([[3, 1]], NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	assert_bool(bool(outcome["bound"])).is_true()
	assert_int(controller.light.fields.size()).is_equal(1)
	assert_int(threads.threads.size()).is_equal(1)
	battle["ally"].action_points = 8  # affordability is gated first; this asks about the contract
	var second := controller.query_action(controller.action_by_id(&"term-of-daylight"), enemy, _with_cells([[3, 1]], NO_FIZZLE))
	assert_str(String(second["blocked_by"])).is_equal("class_resource_duplicate")
	# The enemy walks into the field on its own turn: the light attaches to it.
	battle["grid"].displace(battle["ally"], Vector2i(5, 1))
	_end_round(battle)
	assert_bool(LightField.is_lit(enemy)).is_true()
	assert_int(threads.threads.size()).is_equal(0)
	assert_bool(_saw(battle, &"lit_applied")).is_true()
	var at: Variant = battle["grid"].cell_of(enemy)
	assert_bool(controller.light.is_lit_cell(at)).is_true()
	# Lit outlasts standing in the field by exactly one checkpoint.
	battle["grid"].displace(enemy, Vector2i(6, 0))
	assert_bool(bool(_snapshot_row(controller, enemy)["exposed"])).is_true()
	_end_round(battle)
	assert_bool(LightField.is_lit(enemy)).is_false()


func test_term_of_daylight_needs_the_chord_gate() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(1, 1)}, "Izhakel", -1)
	var controller: CombatController = battle["controller"]
	var gated := controller.query_action(controller.action_by_id(&"term-of-daylight"), battle["enemy"], _with_cells([[3, 1]], NO_FIZZLE))
	assert_str(String(gated["blocked_by"])).is_equal("var_harmony")


func test_noon_contract_triggers_witness_contracts_inside_and_frees_the_threads() -> void:
	var discordant := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(1, 1)}, "Izhakel", 0)
	var gated: Dictionary = discordant["controller"].query_action(discordant["controller"].action_by_id(&"noon-contract"), null, _with_cells([[2, 1]], NO_FIZZLE))
	assert_str(String(gated["blocked_by"])).is_equal("var_harmony")
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(1, 0)}, "Izhakel", 2)
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	var threads := battle["ally"].class_resource as IzhakelThreads
	LightField.apply_veiled(enemy, &"someone")
	controller.submit_action(&"term-of-witness", enemy)
	assert_int(threads.threads.size()).is_equal(1)
	var outcome := controller.submit_action(&"noon-contract", null, _with_cells([[2, 1]], NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	assert_array(outcome["triggered"]).contains([String(enemy.combat_id)])
	assert_int(threads.threads.size()).is_equal(0)
	assert_bool(LightField.is_exposed(enemy)).is_true()
	assert_bool(LightField.is_veiled(enemy)).is_false()
	assert_bool(_saw(battle, &"contract_triggered")).is_true()
	# Term of Witness Exposed lasts two checkpoints, outliving Noonday's one.
	_end_round(battle)
	assert_bool(LightField.is_exposed(enemy)).is_true()


func test_light_and_threads_round_trip_through_save_data() -> void:
	var battle := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(1, 0)})
	var controller: CombatController = battle["controller"]
	controller.submit_action(&"witness-light", null, _with_cells([[3, 1]], NO_FIZZLE))
	controller.submit_action(&"term-of-witness", battle["enemy"])
	var json := JSON.parse_string(JSON.stringify(controller.class_resources_to_dict())) as Dictionary
	assert_bool(json.has(CombatController.LIGHT_SAVE_KEY)).is_true()
	var restored := _battle({"ally": Vector2i(0, 1), "enemy": Vector2i(1, 0)})
	var restored_controller: CombatController = restored["controller"]
	restored_controller.restore_class_resources(json)
	assert_bool(restored_controller.light.is_lit_cell(Vector2i(4, 2))).is_true()
	var threads := restored["ally"].class_resource as IzhakelThreads
	assert_int(threads.threads.size()).is_equal(1)
	assert_str(str(threads.threads[0]["kind"])).is_equal("witness")


# ─── Helpers ────────────────────────────────────────────────────────────────


func _battle(cells: Dictionary, patron: String = "Izhakel", harmony: int = 0) -> Dictionary:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	rules.base_action_points = 8
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_grid_ground())
	var ally := _actor("Weaver", 60, 12, 0)
	ally.breath = 60
	ally.attributes = {"harmony": harmony, "alacrity": 4}
	ally.defining_effects = {"hit": true}
	ally.source_member = PartyMember.new()
	ally.source_member.id = "weaver-test"
	ally.source_member.patron = patron
	var enemy := _actor("Dummy", 60, 1, 0)
	assert_bool(grid.configure_initial_cells({ally: cells["ally"], enemy: cells["enemy"]})["allowed"]).is_true()
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	var events: Array[StringName] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event.type))
	controller.start([ally], [enemy], &"witness-weaver-test")
	return {"controller": controller, "ally": ally, "enemy": enemy, "grid": grid, "events": events}


func _end_round(battle: Dictionary) -> void:
	var controller: CombatController = battle["controller"]
	assert_bool(controller.end_turn()).is_true()
	assert_int(controller.state).is_equal(CombatController.State.ALLY_TURN)


func _saw(battle: Dictionary, type: StringName) -> bool:
	return (battle["events"] as Array[StringName]).has(type)


func _snapshot_row(controller: CombatController, actor: BattleActor) -> Dictionary:
	var snapshot := controller.snapshot()
	for group: String in ["allies", "enemies"]:
		for row: Dictionary in snapshot.get(group, []):
			if StringName(str(row.get("id", ""))) == actor.combat_id:
				return row
	return {}


func _with_cells(cells: Array, extra: Dictionary = {}) -> Dictionary:
	var data: Array[Dictionary] = []
	for pair: Array in cells:
		data.append({"x": int(pair[0]), "y": int(pair[1])})
	var options := {"cells": data}
	options.merge(extra)
	return options


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
