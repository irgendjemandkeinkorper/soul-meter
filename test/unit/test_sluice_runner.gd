extends GdUnitTestSuite
## Luth restoration cards (Second Breath, Turning Tide, Great Confluence) and the Sluice
## Runner kit on the Jam (Opened Sluice, Wash the Gears, Floodgate).

const NO_FIZZLE := {"fizzle": {"harmonic_accord": 100.0, "pitch": 10}}


# ─── Luth cards ─────────────────────────────────────────────────────────────


func test_second_breath_restores_at_most_six_and_never_more_than_paid() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(1, 1), "enemy": Vector2i(6, 1)})
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	ally.breath = 20
	var runner_before: int = battle["runner"].breath
	var outcome := controller.submit_action(&"second-breath", ally, NO_FIZZLE)
	assert_bool(outcome["allowed"]).is_true()
	if bool((outcome["resolution"] as Dictionary)["fizzled"]):
		return
	assert_int(int(outcome["restored"])).is_equal(6)
	assert_int(ally.breath).is_equal(26)
	assert_int(battle["runner"].breath).is_equal(runner_before - 6)
	assert_bool(_saw(battle, &"breath_restored")).is_true()


func test_second_breath_is_refused_on_a_full_ally_before_payment() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(1, 1), "enemy": Vector2i(6, 1)})
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	ally.breath = ally.source_member.breath_max
	var refused := controller.query_action(controller.action_by_id(&"second-breath"), ally, NO_FIZZLE)
	assert_str(String(refused["blocked_by"])).is_equal("no_effect")
	assert_int(battle["runner"].breath).is_equal(30)


func test_second_breath_is_capped_by_the_recipients_capacity() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(1, 1), "enemy": Vector2i(6, 1)})
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	ally.breath = 28
	var outcome := controller.submit_action(&"second-breath", ally, NO_FIZZLE)
	if bool((outcome["resolution"] as Dictionary)["fizzled"]):
		return
	assert_int(int(outcome["restored"])).is_equal(2)
	assert_int(ally.breath).is_equal(30)


func test_turning_tide_mode_a_splits_one_paid_budget_among_allies_in_the_refuge() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(2, 1), "enemy": Vector2i(6, 1)})
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	ally.breath = 10
	var options := _with_cells([[2, 1]], NO_FIZZLE)
	var forecast := controller.forecast_action(controller.action_by_id(&"turning-tide"), null, options)
	assert_bool(forecast["allowed"]).is_true()
	var outcome := controller.submit_action(&"turning-tide", null, options)
	assert_bool(outcome["allowed"]).is_true()
	if bool((outcome["resolution"] as Dictionary)["fizzled"]):
		return
	assert_str(str(outcome["mode"])).is_equal("A")
	assert_int(int((outcome["restored"] as Dictionary)[String(ally.combat_id)])).is_equal(12)
	assert_int(ally.breath).is_equal(22)


func test_turning_tide_mode_a_is_refused_with_no_ally_to_fill() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(2, 1), "enemy": Vector2i(6, 1)})
	var controller: CombatController = battle["controller"]
	battle["ally"].breath = 30
	var refused := controller.query_action(controller.action_by_id(&"turning-tide"), null, _with_cells([[2, 1]], NO_FIZZLE))
	assert_str(String(refused["blocked_by"])).is_equal("no_effect")


func test_turning_tide_mode_b_quenches_the_refuge_and_soaks_allies_only() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(2, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	var enemy: BattleActor = battle["enemy"]
	var options := _with_cells([[2, 1]], NO_FIZZLE)
	options["mode"] = "B"
	var outcome := controller.submit_action(&"turning-tide", null, options)
	assert_bool(outcome["allowed"]).is_true()
	if bool((outcome["resolution"] as Dictionary)["fizzled"]):
		return
	assert_bool(FireField.is_soaked(ally)).is_true()
	assert_bool(FireField.is_soaked(enemy)).is_false()
	assert_bool(outcome.has("restored")).is_false()


func test_turning_tide_mode_b_quenches_a_burning_enemy() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(2, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	FireField.apply_burning(enemy, &"someone")
	var options := _with_cells([[2, 1]], NO_FIZZLE)
	options["mode"] = "B"
	var outcome := controller.submit_action(&"turning-tide", null, options)
	if bool((outcome["resolution"] as Dictionary)["fizzled"]):
		return
	assert_bool(FireField.is_burning(enemy)).is_false()
	assert_bool(FireField.is_soaked(enemy)).is_true()


func test_great_confluence_restores_up_to_twenty_four_and_quenches_and_spends_the_refrain() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(2, 1), "enemy": Vector2i(3, 1)})
	var controller: CombatController = battle["controller"]
	var runner: BattleActor = battle["runner"]
	var ally: BattleActor = battle["ally"]
	runner.breath = 40
	ally.breath = 2
	FireField.apply_burning(ally, &"someone")
	var options := _with_cells([[2, 1]], NO_FIZZLE)
	var outcome := controller.submit_action(&"great-confluence", null, options)
	assert_bool(outcome["allowed"]).is_true()
	if bool((outcome["resolution"] as Dictionary)["fizzled"]):
		return
	assert_int(int((outcome["restored"] as Dictionary)[String(ally.combat_id)])).is_equal(24)
	assert_int(ally.breath).is_equal(26)
	assert_bool(FireField.is_burning(ally)).is_false()
	assert_bool(FireField.is_soaked(ally)).is_true()
	runner.action_points = 8
	var again := controller.query_action(controller.action_by_id(&"great-confluence"), null, options)
	assert_str(String(again["blocked_by"])).is_equal("refrain_spent")


# ─── Sluice Runner kit ──────────────────────────────────────────────────────


func test_opened_sluice_needs_a_jam_that_landed_within_a_checkpoint() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(1, 0), "enemy": Vector2i(6, 1)})
	var controller: CombatController = battle["controller"]
	var ally: BattleActor = battle["ally"]
	ally.breath = 10
	var no_jam := controller.query_action(controller.action_by_id(&"opened-sluice"), ally, NO_FIZZLE)
	assert_str(String(no_jam["blocked_by"])).is_equal("jam_window")
	_arm_enemy_deferred(battle)
	var jam := controller.submit_action(&"jam-the-gears", battle["enemy"])
	assert_bool(jam["allowed"]).is_true()
	assert_bool(_saw(battle, &"action_cancelled")).is_true()
	var opened := controller.query_action(controller.action_by_id(&"opened-sluice"), ally, NO_FIZZLE)
	assert_bool(opened["allowed"]).is_true()
	var outcome := controller.submit_action(&"opened-sluice", ally, NO_FIZZLE)
	if bool((outcome["resolution"] as Dictionary)["fizzled"]):
		return
	# Cap 9, but never more than the 6 Breath the Runner paid.
	assert_int(int(outcome["restored"])).is_equal(6)


func test_opened_sluice_window_closes_after_a_checkpoint() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(1, 0), "enemy": Vector2i(6, 1)})
	var controller: CombatController = battle["controller"]
	battle["ally"].breath = 10
	battle["enemy"].attack = 0
	_arm_enemy_deferred(battle)
	controller.submit_action(&"jam-the-gears", battle["enemy"])
	_end_round(battle)
	assert_bool(controller.query_action(controller.action_by_id(&"opened-sluice"), battle["ally"], NO_FIZZLE)["allowed"]).is_true()
	_end_round(battle)
	var closed := controller.query_action(controller.action_by_id(&"opened-sluice"), battle["ally"], NO_FIZZLE)
	assert_str(String(closed["blocked_by"])).is_equal("jam_window")


func test_opened_sluice_and_wash_need_the_fickah_kit() -> void:
	var stranger := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(1, 1), "enemy": Vector2i(6, 1)}, "Kero")
	var controller: CombatController = stranger["controller"]
	stranger["ally"].breath = 10
	var refused: Dictionary = controller.query_action(controller.action_by_id(&"opened-sluice"), stranger["ally"], NO_FIZZLE)
	assert_str(String(refused["blocked_by"])).is_equal("class_resource")
	var wash: Dictionary = controller.query_action(controller.action_by_id(&"wash-the-gears"), null, _with_cells([[2, 1]], NO_FIZZLE))
	assert_str(String(wash["blocked_by"])).is_equal("class_resource")


func test_wash_the_gears_soaks_only_the_enemy_the_jam_cancelled_this_round() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(2, 0), "enemy": Vector2i(3, 1)}, "Fickah", 0, true)
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	var bystander: BattleActor = battle["bystander"]
	_arm_enemy_deferred(battle)
	assert_bool(controller.submit_action(&"jam-the-gears", enemy)["allowed"]).is_true()
	var outcome := controller.submit_action(&"wash-the-gears", null, _with_cells([[2, 1]], NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	if bool((outcome["resolution"] as Dictionary)["fizzled"]):
		return
	assert_bool(FireField.is_soaked(enemy)).is_true()
	assert_bool(FireField.is_soaked(bystander)).is_false()
	assert_bool(FireField.is_soaked(battle["ally"])).is_true()
	assert_int(enemy.hp).is_equal(enemy.max_hp)


func test_floodgate_discharges_an_armed_jam_on_the_nearest_enemy_in_the_refuge() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(2, 0), "enemy": Vector2i(3, 1)}, "Fickah", 2)
	var controller: CombatController = battle["controller"]
	var runner: BattleActor = battle["runner"]
	var enemy: BattleActor = battle["enemy"]
	runner.breath = 40
	battle["ally"].breath = 5
	# Nothing to cancel yet: the Jam arms a retry instead of landing.
	assert_bool(controller.submit_action(&"jam-the-gears", enemy)["allowed"]).is_true()
	var breaker := runner.class_resource as FickahRuleBreaker
	assert_bool(breaker.has_armed_jam()).is_true()
	_arm_enemy_deferred(battle)
	var outcome := controller.submit_action(&"floodgate", null, _with_cells([[2, 1]], NO_FIZZLE))
	assert_bool(outcome["allowed"]).is_true()
	if bool((outcome["resolution"] as Dictionary)["fizzled"]):
		return
	var discharged: Dictionary = outcome["discharged"]
	assert_str(str(discharged["target_id"])).is_equal(String(enemy.combat_id))
	assert_bool(bool(discharged["allowed"])).is_true()
	assert_bool(breaker.has_armed_jam()).is_false()
	assert_int(controller.deferred_entries().size()).is_equal(0)
	assert_int(battle["ally"].breath).is_equal(29)


func test_floodgate_needs_the_triad_gate() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(2, 0), "enemy": Vector2i(3, 1)}, "Fickah", 0)
	var controller: CombatController = battle["controller"]
	battle["ally"].breath = 5
	var gated := controller.query_action(controller.action_by_id(&"floodgate"), null, _with_cells([[2, 1]], NO_FIZZLE))
	assert_str(String(gated["blocked_by"])).is_equal("var_harmony")


func test_jam_log_round_trips_through_save_data() -> void:
	var battle := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(1, 0), "enemy": Vector2i(6, 1)})
	var controller: CombatController = battle["controller"]
	_arm_enemy_deferred(battle)
	controller.submit_action(&"jam-the-gears", battle["enemy"])
	var json := JSON.parse_string(JSON.stringify(controller.class_resources_to_dict())) as Dictionary
	assert_bool(json.has(CombatController.JAMS_SAVE_KEY)).is_true()
	var restored := _battle({"runner": Vector2i(0, 1), "ally": Vector2i(1, 0), "enemy": Vector2i(6, 1)})
	restored["ally"].breath = 10
	restored["controller"].restore_class_resources(json)
	var opened: Dictionary = restored["controller"].query_action(restored["controller"].action_by_id(&"opened-sluice"), restored["ally"], NO_FIZZLE)
	assert_bool(opened["allowed"]).is_true()


# ─── Helpers ────────────────────────────────────────────────────────────────


## Gives the enemy something a Jam can cancel: a queued deferred effect of its own.
func _arm_enemy_deferred(battle: Dictionary) -> void:
	var controller: CombatController = battle["controller"]
	var enemy: BattleActor = battle["enemy"]
	var queued := controller.enqueue_deferred({
		"source_id": String(enemy.combat_id),
		"delay_rounds": 3,
		"effect": {"writes": [{"kind": "hp", "target_id": String(battle["runner"].combat_id), "amount": 1}]},
	})
	assert_bool(queued["allowed"]).is_true()


func _battle(cells: Dictionary, patron: String = "Fickah", harmony: int = 0, bystander: bool = false) -> Dictionary:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	rules.base_action_points = 8
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_grid_ground())
	var runner := _actor("Runner", 60, 12, 0)
	runner.breath = 30
	runner.attributes = {"harmony": harmony, "alacrity": 4}
	runner.defining_effects = {"hit": true}
	runner.source_member = _member("runner-test", patron, 60)
	var ally := _actor("Second", 60, 8, 0)
	ally.breath = 30
	ally.source_member = _member("second-test", "Kero", 30)
	var enemy := _actor("Dummy", 60, 1, 0)
	var placements := {runner: cells["runner"], ally: cells["ally"], enemy: cells["enemy"]}
	var enemies: Array[BattleActor] = [enemy]
	var extra: BattleActor = null
	if bystander:
		extra = _actor("Bystander", 60, 1, 0)
		placements[extra] = Vector2i(3, 0)
		enemies.append(extra)
	assert_bool(grid.configure_initial_cells(placements)["allowed"]).is_true()
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	var events: Array[StringName] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void: events.append(event.type))
	controller.start([runner, ally], enemies, &"sluice-runner-test")
	return {"controller": controller, "runner": runner, "ally": ally, "enemy": enemy, "bystander": extra, "grid": grid, "events": events}


func _member(id: String, patron: String, breath_max: int) -> PartyMember:
	var member := PartyMember.new()
	member.id = id
	member.patron = patron
	member.breath_max = breath_max
	return member


## The runner acts first each round; ending the runner's turn passes to the ally, whose
## turn is ended too, then the enemy acts and the round closes (one checkpoint).
func _end_round(battle: Dictionary) -> void:
	var controller: CombatController = battle["controller"]
	var guard := 0
	while guard < 4:
		guard += 1
		assert_bool(controller.end_turn()).is_true()
		if controller.active_actor() == battle["runner"]:
			return
	assert_bool(false).override_failure_message("Round did not return to the runner.").is_true()


func _saw(battle: Dictionary, type: StringName) -> bool:
	return (battle["events"] as Array[StringName]).has(type)


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
