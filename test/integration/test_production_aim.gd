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


func test_leg_is_quoted_on_humanoids_and_the_hound_but_not_the_boar() -> void:
	for charge_time: bool in [false, true]:
		var controller := _controller(&"bog-wight", charge_time)
		var strike := controller.action_by_id(&"strike")
		var forecast := controller.forecast_action(strike, controller.enemies[0], {"aim_location": "leg"})
		assert_bool(forecast["allowed"]).override_failure_message(str(forecast)).is_true()
		assert_int(int(forecast["injury_forecast"]["chance_on_hit"])).is_equal(40)
		assert_int(int(forecast["ap_cost"])).is_equal(strike.ap_cost + 1)
	var hound := _controller(&"gnaal-breach-hound", false)
	var hound_strike := hound.action_by_id(&"strike")
	assert_bool(hound.query_action(hound_strike, hound.enemies[0], {"aim_location": "leg"})["allowed"]).is_true()
	var hound_aim: Dictionary = hound._query_aim(hound.allies[0], hound.enemies[0], hound_strike, "leg")
	assert_str(str(hound_aim["display_name"])).is_equal("Foreleg")
	var boar := _controller(&"loam-maddened-boar", false)
	assert_str(str(boar.query_action(boar.action_by_id(&"strike"), boar.enemies[0], {"aim_location": "leg"})["blocked_by"])).is_equal("aim_location")


func test_an_aimed_leg_hit_hobbles_movement_under_both_schedulers_and_ends_with_the_fight() -> void:
	for charge_time: bool in [false, true]:
		var controller := _controller(&"bog-wight", charge_time)
		var strike := controller.action_by_id(&"strike")
		var wight := controller.enemies[0]
		var options := {"aim_location": "leg"}
		var hit_seed := -1
		for seed_value: int in 400:
			controller._sequence = seed_value
			var resolution: Dictionary = controller.forecast_action(strike, wight, options)["resolution"]
			if bool(resolution["hit"]) and bool(resolution["injury"]["rolled"]):
				hit_seed = seed_value
				break
		assert_int(hit_seed).is_greater_equal(0)
		controller._sequence = hit_seed
		var unhurt_ct := controller._injured_move_ct(wight, 20)
		var result := controller.submit_action(strike.id, wight, options)
		assert_bool(result["allowed"]).override_failure_message(str(result)).is_true()
		assert_str(str(wight.injuries["leg"]["injury_id"])).is_equal("leg-hobbled")
		assert_int(unhurt_ct).is_equal(20)
		assert_int(controller._injured_move_ct(wight, 20)).is_equal(30)
		assert_float(CombatInjury.move_cost_multiplier(wight)).is_equal(1.5)
		assert_dict(CombatInjury.persistent_records(wight.injuries)).is_empty()
		assert_array(CombatInjury.attack_accuracy_modifiers(wight)).is_empty()


func test_a_hobbled_ally_pays_more_ap_and_ct_for_the_same_step_and_the_forecast_names_the_leg() -> void:
	for charge_time: bool in [false, true]:
		var controller := _controller(&"bog-wight", charge_time, 3)
		var ally := controller.allies[0]
		var grid := controller.battlefield as GridBattlefieldModel
		var destination := &""
		var best_ct := 2147483647
		for candidate: StringName in grid.reachable_positions(ally, 200):
			var quote := controller.move_query(candidate)
			if bool(quote["allowed"]) and int(quote["ct_cost"]) < best_ct:
				destination = candidate
				best_ct = int(quote["ct_cost"])
		assert_str(String(destination)).is_not_empty()
		var before := controller.move_query(destination)
		assert_bool(before["allowed"]).override_failure_message(str(before)).is_true()
		assert_array(before["move_modifiers"]).is_empty()
		CombatInjury.apply(ally, {
			"id": "leg-hobbled", "location_id": "leg", "severity": "minor",
			"effects": {"move_cost_percent": 50},
		}, "test", 0)
		var after := controller.move_query(destination)
		assert_bool(after["allowed"]).override_failure_message(str(after)).is_true()
		assert_int(int(after["ct_cost"])).is_equal(int(before["ct_cost"]) * 3 / 2)
		assert_int(int(after["ap_cost"])).is_equal(int(before["ap_cost"]) * 2)
		assert_str(str(after["move_modifiers"][0]["label"])).is_equal("Injury: Leg (movement)")


func test_head_is_quoted_on_the_wight_and_hound_and_refused_behind_the_guard_helm() -> void:
	for charge_time: bool in [false, true]:
		var controller := _controller(&"bog-wight", charge_time)
		var forecast := controller.forecast_action(controller.action_by_id(&"strike"), controller.enemies[0], {"aim_location": "head"})
		assert_bool(forecast["allowed"]).override_failure_message(str(forecast)).is_true()
		assert_int(int(forecast["injury_forecast"]["chance_on_hit"])).is_equal(30)
	var hound := _controller(&"gnaal-breach-hound", false)
	assert_str(str(hound._query_aim(hound.allies[0], hound.enemies[0], hound.action_by_id(&"strike"), "head")["display_name"])).is_equal("Muzzle")
	var guard := _controller(&"cleaned-jawbrace-guard", false)
	assert_str(str(guard.query_action(guard.action_by_id(&"strike"), guard.enemies[0], {"aim_location": "head"})["blocked_by"])).is_equal("aim_exposure")
	var boar := _controller(&"loam-maddened-boar", false)
	assert_str(str(boar.query_action(boar.action_by_id(&"strike"), boar.enemies[0], {"aim_location": "head"})["blocked_by"])).is_equal("aim_location")


func test_an_aimed_head_hit_blurs_sight_for_ranged_and_aimed_shots_but_not_body_swings() -> void:
	for charge_time: bool in [false, true]:
		var controller := _controller(&"bog-wight", charge_time)
		var strike := controller.action_by_id(&"strike")
		var wight := controller.enemies[0]
		var vex := controller.allies[0]
		var options := {"aim_location": "head"}
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
		assert_str(str(wight.injuries["head"]["injury_id"])).is_equal("sight-blurred")
		assert_dict(CombatInjury.persistent_records(wight.injuries)).is_empty()
		# Mirror the record onto Vex so the attacker-side rule is observable from the player seat.
		vex.injuries["head"] = (wight.injuries["head"] as Dictionary).duplicate(true)
		var shot := CombatAction.make(&"test-shot", "Test shot", CombatAction.Kind.ATTACK)
		shot.ct_cost = 30
		shot.target_profile = &"ranged"
		controller._actions[shot.id] = shot
		assert_array(_labels(controller.forecast_context(vex, wight, shot, {}))).contains(["Injury: Head (sight)"])
		assert_array(_labels(controller.forecast_context(vex, wight, strike, {"aim_location": "torso"}))).contains(["Injury: Head (sight)"])
		assert_array(_labels(controller.forecast_context(vex, wight, strike, {}))).not_contains(["Injury: Head (sight)"])
		var forecast := controller.forecast_action(strike, wight, {"aim_location": "torso"})
		var labels: Array = []
		for modifier: Dictionary in forecast["resolution"]["accuracy_breakdown"]["modifiers"]:
			labels.append(str(modifier["label"]))
		assert_array(labels).contains(["Injury: Head (sight)"])


func _labels(context: Dictionary) -> Array:
	var labels: Array = []
	for modifier: Dictionary in context.get("attacker_injury_modifiers", []):
		labels.append(str(modifier["label"]))
	return labels


func _controller(archetype: StringName, charge_time: bool, rows: int = 1) -> CombatController:
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
		for y: int in rows:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
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
