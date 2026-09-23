extends GdUnitTestSuite
## Task 12: the enemy compares its ordinary strike with the bounded set of legal aimed shots
## using forecast data only, and commits the chosen aim through the same priced path.

var _events: Array[CombatEvent] = []


func test_enemy_prefers_a_useful_arm_shot_when_ordinary_damage_is_small() -> void:
	var controller := _controller(4)
	var enemy := controller.enemies[0]
	var ally := controller.allies[0]
	var strike := controller.action_by_id(&"enemy-strike")
	var choice := controller.choose_enemy_aim(enemy, ally, strike)
	assert_dict(choice).is_equal({"aim_location": "arm"})
	# Forecast-only: a different RNG position gives the same answer and nothing advanced.
	var sequence_before: int = controller._sequence
	controller._sequence = sequence_before + 977
	assert_dict(controller.choose_enemy_aim(enemy, ally, strike)).is_equal(choice)
	assert_int(controller._sequence).is_equal(sequence_before + 977)


func test_enemy_keeps_ordinary_damage_when_it_is_worth_more_than_the_injury() -> void:
	var controller := _controller(60)
	assert_dict(controller.choose_enemy_aim(controller.enemies[0], controller.allies[0], controller.action_by_id(&"enemy-strike"))).is_empty()


func test_enemy_skips_an_already_injured_limb_and_hidden_or_absent_parts() -> void:
	var controller := _controller(4)
	var ally := controller.allies[0]
	var strike := controller.action_by_id(&"enemy-strike")
	CombatInjury.apply(ally, {"id": "arm-strained", "location_id": "arm", "effects": {}}, "k", 1)
	var choice := controller.choose_enemy_aim(controller.enemies[0], ally, strike)
	assert_str(str(choice.get("aim_location", ""))).is_not_equal("arm")
	# Only a covered arm and no throat: nothing an aim can gain over the ordinary hit.
	ally.injuries.clear()
	ally.anatomy = {"torso": {"display_name": "Torso", "exposed": true}, "arm": {"display_name": "Arm", "exposed": false}}
	assert_dict(controller.choose_enemy_aim(controller.enemies[0], ally, strike)).is_empty()


func test_enemy_never_aims_when_the_shot_would_sit_at_the_minimum_chance() -> void:
	var controller := _controller(4)
	var ally := controller.allies[0]
	ally.attributes[&"alacrity"] = 40
	var strike := controller.action_by_id(&"enemy-strike")
	var breakdown := Resolution.accuracy_breakdown(controller.forecast_context(controller.enemies[0], ally, strike, {"aim_location": "arm"}))
	assert_int(int(breakdown["clamp_adjustment"])).is_greater(0)
	assert_dict(controller.choose_enemy_aim(controller.enemies[0], ally, strike)).is_empty()


func test_enemy_round_commits_the_aimed_strike_with_its_surcharge() -> void:
	var controller := _controller(4)
	var enemy := controller.enemies[0]
	controller.event_emitted.connect(func(event: CombatEvent) -> void: _events.append(event))
	var ap_before := enemy.action_points
	controller.end_turn()
	var resolved: Dictionary = {}
	for event: CombatEvent in _events:
		if event.type == &"action_resolved" and event.actor_id == enemy.combat_id:
			resolved = event.data
			break
	assert_dict(resolved).is_not_empty()
	assert_str(str(resolved.get("aim_location", ""))).is_equal("arm")
	assert_int(int(resolved["ap_cost"])).is_equal(5)
	assert_int(int(resolved["ap_remaining"])).is_equal(ap_before - 5)
	assert_bool(resolved["resolution"].has("injury")).is_true()


func _controller(enemy_attack: int) -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var tile_set := TileSet.new()
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tile_set
	for x: int in 4:
		ground.set_cell(Vector2i(x, 0), 0, Vector2i.ZERO)
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(ground)
	var ally := BattleActor.new()
	ally.display_name = "Vex"
	ally.hp = 200
	ally.max_hp = 200
	ally.defense = 1
	ally.attributes = {&"alacrity": 3}
	ally.anatomy = {
		"torso": {"display_name": "Torso", "exposed": true, "hidden_by_cover": true},
		"arm": {"display_name": "Arm", "exposed": true},
		"throat": {"display_name": "Throat", "exposed": true},
	}
	var enemy := EncounterCatalog.make_actor(&"bog-wight")
	enemy.attack = enemy_attack
	enemy.hp = 200
	enemy.max_hp = 200
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	controller.start([ally], [enemy], &"enemy-aim")
	assert_bool(grid.displace(enemy, grid.cell_of(ally) + Vector2i(1, 0))["allowed"]).is_true()
	return controller
