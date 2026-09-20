extends GdUnitTestSuite
## Task 11B: production aim profiles on `strike` against real catalog archetypes, under
## both schedulers. PROVISIONAL numbers mirror the lab fixture until the balance pass.


func test_strike_offers_torso_arm_and_throat_against_the_bog_wight_under_both_schedulers() -> void:
	for charge_time: bool in [false, true]:
		var controller := _controller(&"bog-wight", charge_time)
		var strike := controller.action_by_id(&"strike")
		var wight := controller.enemies[0]
		for location: String in ["torso", "arm", "throat"]:
			var quoted := controller.query_action(strike, wight, {"aim_location": location})
			assert_bool(quoted["allowed"]).override_failure_message("%s under ct=%s: %s" % [location, charge_time, quoted]).is_true()
			var forecast := controller.forecast_action(strike, wight, {"aim_location": location})
			assert_int(int(forecast["ap_cost"])).is_equal(strike.ap_cost + 1)
			var labels: Array = []
			for modifier: Dictionary in forecast["resolution"]["accuracy_breakdown"]["modifiers"]:
				labels.append(str(modifier["label"]))
			assert_array(labels).contains(["Aim: %s" % location.capitalize()])
		assert_dict(controller.forecast_action(strike, wight, {"aim_location": "torso"})["injury_forecast"]).is_empty()
		assert_int(int(controller.forecast_action(strike, wight, {"aim_location": "arm"})["injury_forecast"]["chance_on_hit"])).is_equal(50)
		assert_int(int(controller.forecast_action(strike, wight, {"aim_location": "throat"})["injury_forecast"]["chance_on_hit"])).is_equal(35)


func test_absent_and_covered_parts_are_refused_on_real_archetypes() -> void:
	var boar := _controller(&"loam-maddened-boar", false)
	var strike := boar.action_by_id(&"strike")
	var refused := boar.query_action(strike, boar.enemies[0], {"aim_location": "throat"})
	assert_str(str(refused["blocked_by"])).is_equal("aim_location")
	assert_str(str(boar.query_action(strike, boar.enemies[0], {"aim_location": "arm"})["blocked_by"])).is_equal("aim_location")
	assert_bool(boar.query_action(strike, boar.enemies[0], {"aim_location": "torso"})["allowed"]).is_true()
	var guard := _controller(&"cleaned-jawbrace-guard", false)
	assert_str(str(guard.query_action(guard.action_by_id(&"strike"), guard.enemies[0], {"aim_location": "throat"})["blocked_by"])).is_equal("aim_exposure")


func test_an_aimed_arm_hit_on_the_wight_applies_a_minor_injury_that_ends_with_the_fight() -> void:
	var controller := _controller(&"bog-wight", false)
	var strike := controller.action_by_id(&"strike")
	var wight := controller.enemies[0]
	var options := {"aim_location": "arm"}
	var hit_seed := -1
	for seed_value: int in 400:
		controller._sequence = seed_value
		var resolution: Dictionary = controller.forecast_action(strike, wight, options)["resolution"]
		if bool(resolution["hit"]) and bool(resolution["injury"]["rolled"]):
			hit_seed = seed_value
			break
	assert_int(hit_seed).is_greater_equal(0)
	controller._sequence = hit_seed
	var result := controller.submit_action(strike.id, wight, options)
	assert_bool(result["allowed"]).override_failure_message(str(result)).is_true()
	assert_bool(result["resolution"]["injury"]["applies"]).is_true()
	assert_str(str(wight.injuries["arm"]["injury_id"])).is_equal("arm-strained")
	assert_dict(CombatInjury.persistent_records(wight.injuries)).is_empty()
	assert_array(CombatInjury.attack_accuracy_modifiers(wight)).is_not_empty()


func _controller(archetype: StringName, charge_time: bool) -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = charge_time
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
	ally.attack = 12
	ally.attributes = {&"alacrity": 4, &"muster": 3}
	var enemy := EncounterCatalog.make_actor(archetype)
	enemy.hp = 200
	enemy.max_hp = 200
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	controller.start([ally], [enemy], &"production-aim")
	# Strike is melee: seat the enemy beside the ally.
	assert_bool(grid.displace(enemy, grid.cell_of(ally) + Vector2i(1, 0))["allowed"]).is_true()
	return controller
