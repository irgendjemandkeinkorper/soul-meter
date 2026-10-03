extends GdUnitTestSuite

const Lab := preload("res://globals/combat_lab.gd")


func test_each_visible_location_quotes_and_spends_both_authored_costs() -> void:
	for use_ct: bool in [false, true]:
		for location: String in ["torso", "arm", "throat"]:
			var controller := _controller(use_ct)
			var actor := controller.active_actor()
			var target := controller.enemies[0]
			var action := controller.action_by_id(&"aim-test")
			var options := {"aim_location": location}
			var ordinary := controller.forecast_action(action, target)
			var forecast := controller.forecast_action(action, target, options)
			var profile: Dictionary = action.aim_profiles[location]
			assert_bool(forecast["allowed"]).override_failure_message(str(forecast)).is_true()
			assert_int(forecast["ap_cost"]).is_equal(2)
			assert_int(forecast["ct_cost"]).is_equal(30 + int(profile["ct_surcharge"]))
			assert_int(forecast["resolution"]["hit_chance"]).is_equal(
				int(ordinary["resolution"]["hit_chance"]) - int(profile["accuracy_penalty"])
			)
			var before_sequence := controller._sequence
			var before_scheduler := controller.scheduler.to_dict().duplicate(true)
			for _repeat: int in 3:
				assert_dict(controller.forecast_action(action, target, options)).is_equal(forecast)
			assert_int(controller._sequence).is_equal(before_sequence)
			assert_dict(controller.scheduler.to_dict()).is_equal(before_scheduler)
			var ap_before := actor.action_points
			var hp_before := target.hp
			var result := controller.submit_action(action.id, target, options)
			assert_bool(result["allowed"]).is_true()
			assert_dict(result["resolution"]).is_equal(forecast["resolution"])
			assert_str(result["aim_location"]).is_equal(location)
			assert_int(hp_before - target.hp).is_equal(forecast["damage"])
			assert_int(result["ap_cost"]).is_equal(2)
			if use_ct:
				assert_int(result["ct_spent"]).is_equal(forecast["ct_cost"])
			else:
				assert_int(result["ap_remaining"]).is_equal(ap_before - 2)
			assert_int(action.ap_cost).is_equal(1)
			assert_int(action.ct_cost).is_equal(30)
			assert_array(target.discovered_weakness_ids).is_empty()
			assert_dict(target.defining_effects).is_empty()


func test_missing_and_covered_locations_refuse_without_spending() -> void:
	for use_ct: bool in [false, true]:
		var controller := _controller(use_ct)
		var target := controller.enemies[0]
		target.anatomy.erase("throat")
		target.anatomy["arm"]["exposed"] = false
		_assert_refused(controller, "throat", "aim_location")
		_assert_refused(controller, "arm", "aim_exposure")
		_assert_refused(controller, "invented", "aim_action")


func test_insufficient_ap_includes_the_aim_surcharge() -> void:
	var controller := _controller(false)
	controller.active_actor().action_points = 1
	assert_bool(controller.forecast_action(controller.action_by_id(&"aim-test"), controller.enemies[0])["allowed"]).is_true()
	_assert_refused(controller, "arm", "action_points")


func test_ct_actor_must_be_ready_even_for_a_supported_aim() -> void:
	var controller := _controller(true)
	# Nobody is charged, so no combatant is active. The controller gates on the active
	# actor before any aim query, so a supported aim still refuses with the turn reason
	# and neither the schedule nor the target changes.
	for combatant: BattleActor in controller.allies + controller.enemies:
		controller.scheduler._charge[combatant.combat_id] = 0
	assert_object(controller.active_actor()).is_null()
	_assert_refused(controller, "torso", "turn_state")


func test_los_blocker_cannot_be_bypassed_by_minimum_hit_chance() -> void:
	var controller := _controller(false)
	(controller.battlefield as GridBattlefieldModel).set_elevation(Vector2i(1, 0), 10)
	_assert_refused(controller, "throat", "blocked_by_elevation")


func test_solid_obstacle_blocks_aimed_and_ordinary_shots_before_any_chance() -> void:
	for use_ct: bool in [false, true]:
		var controller := _controller(use_ct)
		var grid := controller.battlefield as GridBattlefieldModel
		var between: Vector2i = (grid.cell_of(controller.enemies[0]) as Vector2i) - Vector2i(1, 0)
		grid.set_obstacle(between, true)
		_assert_refused(controller, "throat", "blocked_by_obstacle")
		var ordinary := controller.forecast_action(controller.action_by_id(&"aim-test"), controller.enemies[0])
		assert_bool(ordinary["allowed"]).is_false()
		assert_str(str(ordinary["blocked_by"])).is_equal("blocked_by_obstacle")


func test_low_cover_hides_only_cover_hidden_locations_and_high_ground_sees_over_it() -> void:
	for use_ct: bool in [false, true]:
		var controller := _controller(use_ct)
		var grid := controller.battlefield as GridBattlefieldModel
		var target := controller.enemies[0]
		var ally := controller.active_actor()
		target.anatomy["torso"]["hidden_by_cover"] = true
		var enemy_cell: Vector2i = grid.cell_of(target)
		var ally_cell: Vector2i = grid.cell_of(ally)
		var toward_ally: Vector2i = enemy_cell + (ally_cell - enemy_cell).sign()
		grid.set_cover(toward_ally, true)

		_assert_refused(controller, "torso", "aim_cover")
		var action := controller.action_by_id(&"aim-test")
		var throat := controller.forecast_action(action, target, {"aim_location": "throat"})
		assert_bool(throat["allowed"]).override_failure_message(str(throat)).is_true()
		# The ordinary attack keeps its legacy cover mitigation; exposure never adds a second
		# generic cover charge on top of it.
		var ordinary := controller.forecast_action(action, target)
		assert_bool(ordinary["allowed"]).is_true()
		assert_int(int(ordinary["positioning"]["cover_bonus"])).is_equal(controller.rules.cover_defense_bonus)
		assert_int(int(throat["positioning"]["cover_bonus"])).is_equal(controller.rules.cover_defense_bonus)
		var aim_terms: Array = []
		for modifier: Dictionary in throat["resolution"]["accuracy_breakdown"]["modifiers"]:
			aim_terms.append(str(modifier["id"]))
		assert_array(aim_terms).not_contains(["cover"])

		grid.set_elevation(ally_cell, 3)
		var over := controller.forecast_action(action, target, {"aim_location": "torso"})
		assert_bool(over["allowed"]).override_failure_message(str(over)).is_true()
		grid.set_elevation(ally_cell, 0)

		grid.set_cover(toward_ally, false)
		grid.set_cover(enemy_cell - (ally_cell - enemy_cell).sign(), true)  # cover behind the target
		var behind := controller.forecast_action(action, target, {"aim_location": "torso"})
		assert_bool(behind["allowed"]).override_failure_message(str(behind)).is_true()


func test_dim_visibility_lowers_a_ranged_shot_at_forecast_and_commit_but_not_a_spell() -> void:
	for use_ct: bool in [false, true]:
		var controller := _controller(use_ct)
		var grid := controller.battlefield as GridBattlefieldModel
		var target := controller.enemies[0]
		var action := controller.action_by_id(&"aim-test")
		var clear := controller.forecast_action(action, target, {"aim_location": "arm"})
		assert_bool(controller.configure_visibility(grid.cell_of(target), &"dim")["allowed"]).is_true()
		var dim := controller.forecast_action(action, target, {"aim_location": "arm"})
		var clear_chance := int(clear["resolution"]["accuracy_breakdown"]["hit_chance"])
		var dim_chance := int(dim["resolution"]["accuracy_breakdown"]["hit_chance"])
		assert_int(dim_chance).is_equal(clear_chance + int(Resolution.PROVISIONAL_TO_HIT["visibility_dim_pp"]))
		assert_str(str(dim["context"]["visibility"]["level"])).is_equal("dim")
		# Elemental weather is a separate system: changing it leaves the visibility term alone.
		controller.configure_weather(&"khash")
		assert_str(str(controller.forecast_action(action, target, {"aim_location": "arm"})["context"]["visibility"]["level"])).is_equal("dim")
		# A direct spell carries no visibility term until an explicit profile says so.
		var spell := action.duplicate(true) as CombatAction
		spell.id = &"aim-spell"
		spell.spell = true
		spell.aim_profiles = {}
		controller._actions[spell.id] = spell
		var spell_forecast := controller.forecast_action(spell, target)
		assert_bool(spell_forecast["allowed"]).override_failure_message(str(spell_forecast)).is_true()
		assert_bool(spell_forecast["context"]["visibility"]["applies"]).is_false()
		assert_str(str(spell_forecast["context"]["visibility"]["level"])).is_equal("dim")

		# Commit resolves with the same context the forecast quoted (the enemy round that
		# follows may move the target, so this is the last check on this controller).
		var result := controller.submit_action(action.id, target, {"aim_location": "arm"})
		assert_bool(result["allowed"]).override_failure_message(str(result)).is_true()
		assert_dict(result["resolution"]["accuracy_breakdown"]).is_equal(dim["resolution"]["accuracy_breakdown"])


func test_blinded_attacker_keeps_the_facing_restriction_and_no_visibility_penalty() -> void:
	var controller := _controller(false)
	var grid := controller.battlefield as GridBattlefieldModel
	var target := controller.enemies[0]
	var actor := controller.active_actor()
	var action := controller.action_by_id(&"aim-test")
	grid.set_visibility(grid.cell_of(target), &"dim")
	grid.set_facing(target, &"w")  # the shooter stands to the target's west: rear or side without Blinded
	var sighted := controller.forecast_action(action, target)
	LightField.apply_blinded(actor, &"test")
	var blinded := controller.forecast_action(action, target)
	var ids: Array = []
	for modifier: Dictionary in blinded["resolution"]["accuracy_breakdown"]["modifiers"]:
		ids.append(str(modifier["id"]))
	assert_array(ids).not_contains(["visibility"])
	assert_str(str(blinded["context"]["facing"]["id"])).is_equal("front")
	assert_str(str(blinded["context"]["visibility"]["reason"])).is_equal("blinded_facing_restriction")
	var sighted_ids: Array = []
	for modifier: Dictionary in sighted["resolution"]["accuracy_breakdown"]["modifiers"]:
		sighted_ids.append(str(modifier["id"]))
	assert_array(sighted_ids).contains(["visibility"])


func test_committed_aimed_miss_still_pays_the_extra_cost() -> void:
	for use_ct: bool in [false, true]:
		var controller := _controller(use_ct)
		var target := controller.enemies[0]
		target.attributes[&"alacrity"] = 100
		var options := {"aim_location": "throat"}
		var action := controller.action_by_id(&"aim-test")
		var forecast: Dictionary = {}
		for seed_value: int in 100:
			controller._sequence = seed_value
			forecast = controller.forecast_action(action, target, options)
			if not bool(forecast["resolution"]["hit"]):
				break
		assert_bool(forecast["resolution"]["hit"]).is_false()
		var hp_before := target.hp
		var result := controller.submit_action(action.id, target, options)
		assert_bool(result["resolution"]["hit"]).is_false()
		assert_int(result["ap_cost"]).is_equal(2)
		if use_ct:
			assert_int(result["ct_spent"]).is_equal(45)
		assert_int(target.hp).is_equal(hp_before)
		assert_dict(target.defining_effects).is_empty()


func test_profiles_require_explicit_valid_costs_and_cannot_be_overridden_by_options() -> void:
	var controller := _controller(false)
	var action := controller.action_by_id(&"aim-test")
	var forecast := controller.forecast_action(action, controller.enemies[0], {
		"aim_location": "arm", "ap_surcharge": 0, "accuracy_penalty": -100,
	})
	assert_int(forecast["ap_cost"]).is_equal(2)
	assert_int(forecast["context"]["aim"]["accuracy_penalty"]).is_equal(15)
	for invalid: Variant in [-1, 0, 1.5, "1", null]:
		action.aim_profiles["arm"]["ap_surcharge"] = invalid
		_assert_refused(controller, "arm", "aim_profile")
	action.aim_profiles = Lab.AIM_PROFILES.duplicate(true)
	action.ct_cost = -1
	_assert_refused(controller, "arm", "aim_profile")
	action.ct_cost = 60
	_assert_refused(controller, "arm", "aim_profile")


func test_unopted_actions_and_legacy_battlefields_keep_ordinary_behavior() -> void:
	var controller := _controller(false)
	var action := controller.action_by_id(&"aim-test")
	var target := controller.enemies[0]
	var original := controller.forecast_action(action, target)
	assert_dict(controller.forecast_action(action, target, {"aim_location": ""})).is_equal(original)
	assert_bool(original["context"].has("aim")).is_false()
	action.aim_profiles = {}
	assert_dict(controller.forecast_action(action, target)).is_equal(original)
	_assert_refused(controller, "arm", "aim_action")
	action.aim_profiles = Lab.AIM_PROFILES.duplicate(true)
	action.spell = true
	_assert_refused(controller, "arm", "aim_action")
	action.spell = false
	var legacy := preload("res://globals/combat/zone_battlefield_model.gd").new()
	legacy.configure(controller.rules)
	var legacy_actions := CombatActionCatalog.all()
	legacy_actions.append(action)
	controller.configure(legacy_actions, legacy, controller.rules)
	controller.start(controller.allies.duplicate(), controller.enemies.duplicate(), &"legacy-aim")
	_assert_refused(controller, "arm", "aim_accuracy")
	assert_int(controller.forecast_action(action, controller.enemies[0])["resolution"]["hit_chance"]).is_equal(100)


func test_aim_context_replays_after_json_round_trip_and_resources_preserve_profiles() -> void:
	var controller := _controller(false)
	var action := controller.action_by_id(&"aim-test")
	var target := controller.enemies[0]
	var context := controller.forecast_context(controller.active_actor(), target, action, {"aim_location": "arm"})
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(context))
	var before := Resolution.resolve(context)
	var replay := Resolution.resolve(decoded)
	assert_int(replay["damage"]).is_equal(before["damage"])
	assert_int(replay["hit_roll"]).is_equal(before["hit_roll"])
	assert_dict(replay["action_log"]["aim"]).is_equal(before["action_log"]["aim"])
	assert_int(ResourceSaver.save(action, "user://aim-action.tres")).is_equal(OK)
	assert_int(ResourceSaver.save(target, "user://aim-target.tres")).is_equal(OK)
	var loaded := ResourceLoader.load("user://aim-action.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as CombatAction
	var loaded_target := ResourceLoader.load("user://aim-target.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as BattleActor
	assert_dict(loaded.aim_profiles).is_equal(action.aim_profiles)
	assert_dict(loaded_target.anatomy).is_equal(target.anatomy)
	assert_dict(controller.snapshot()["enemies"][0]["anatomy"]).is_equal(target.anatomy)


func _assert_refused(controller: CombatController, location: String, reason: String) -> void:
	var action := controller.action_by_id(&"aim-test")
	var target := controller.enemies[0]
	var before := controller.scheduler.to_dict().duplicate(true)
	var hp_before := target.hp
	var forecast := controller.forecast_action(action, target, {"aim_location": location})
	var result := controller.submit_action(action.id, target, {"aim_location": location})
	assert_bool(result["allowed"]).override_failure_message(str(result)).is_false()
	assert_str(str(result["blocked_by"])).override_failure_message(str(result)).is_equal(reason)
	assert_dict(forecast).is_equal(result)
	assert_dict(controller.scheduler.to_dict()).is_equal(before)
	assert_int(target.hp).is_equal(hp_before)


func _controller(use_ct: bool) -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = use_ct
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
	var action := CombatAction.make(&"aim-test", "Aim test", CombatAction.Kind.ATTACK)
	action.ct_cost = 30
	action.target_profile = &"ranged"
	action.aim_profiles = Lab.AIM_PROFILES.duplicate(true)
	var ally := BattleActor.new()
	ally.display_name = "Aim ally"
	ally.hp = 200
	ally.max_hp = 200
	ally.attack = 12
	var enemy := BattleActor.new()
	enemy.display_name = "Aim target"
	enemy.hp = 200
	enemy.max_hp = 200
	for location: String in ["torso", "arm", "throat"]:
		enemy.anatomy[location] = {"display_name": location.capitalize(), "exposed": true}
	var controller := CombatController.new()
	var actions := CombatActionCatalog.all()
	actions.append(action)
	controller.configure(actions, grid, rules)
	controller.start([ally], [enemy], &"called-shots-test")
	return controller
