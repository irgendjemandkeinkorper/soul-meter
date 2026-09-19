extends GdUnitTestSuite
## Task 7: bounded location injuries, combat-local slice.

const Lab := preload("res://globals/combat_lab.gd")


func test_injury_needs_a_hit_and_the_authored_damage_and_applies_once_per_commit() -> void:
	var controller := _controller()
	var target := controller.enemies[0]
	var action := controller.action_by_id(&"aim-test")
	var options := {"aim_location": "arm"}
	# Find a seed whose commit both hits and rolls the injury, and one that misses.
	var hit_seed := -1
	var miss_seed := -1
	for seed_value: int in 200:
		controller._sequence = seed_value
		var forecast := controller.forecast_action(action, target, options)
		var resolution: Dictionary = forecast["resolution"]
		if hit_seed < 0 and bool(resolution["hit"]) and bool(resolution["injury"]["rolled"]):
			hit_seed = seed_value
		if miss_seed < 0 and not bool(resolution["hit"]):
			miss_seed = seed_value
		if hit_seed >= 0 and miss_seed >= 0:
			break
	assert_int(hit_seed).is_greater_equal(0)
	assert_int(miss_seed).is_greater_equal(0)

	# A miss never injures, whatever the injury roll said.
	controller._sequence = miss_seed
	var miss := controller.submit_action(action.id, target, options)
	assert_bool(miss["resolution"]["hit"]).is_false()
	assert_bool(miss["resolution"]["injury"]["applies"]).is_false()
	assert_dict(target.injuries).is_empty()

	# A rolled hit applies exactly one record, and the cached commit replays without refreshing.
	var replay_controller := _controller()
	var replay_target := replay_controller.enemies[0]
	replay_controller._sequence = hit_seed
	var forecast := replay_controller.forecast_action(action, replay_target, options)
	assert_bool(forecast["resolution"]["injury"]["applies"]).is_true()
	assert_dict(replay_target.injuries).is_empty()  # previewing never applies
	var result := replay_controller.submit_action(action.id, replay_target, options)
	assert_bool(result["resolution"]["injury"]["applies"]).is_true()
	assert_dict(result["resolution"]["injury"]).is_equal(forecast["resolution"]["injury"])
	assert_int(replay_target.injuries.size()).is_equal(1)
	var record: Dictionary = replay_target.injuries["arm"]
	assert_str(str(record["injury_id"])).is_equal("arm-strained")
	assert_int(int(record["applications"])).is_equal(1)
	assert_str(str(record["recovery"])).is_equal("untreated")
	replay_controller._apply_resolution_writes(replay_controller.active_actor(), replay_target, result["resolution"])
	assert_int(int((replay_target.injuries["arm"] as Dictionary)["applications"])).is_equal(1)


func test_second_qualifying_hit_refreshes_the_record_without_escalating() -> void:
	var controller := _controller()
	var target := controller.enemies[0]
	var applied := {"id": "arm-strained", "location_id": "arm", "severity": "minor", "effects": {"attack_accuracy_pp": -10}}
	assert_bool(CombatInjury.apply(target, applied, "b|1|a|x", 1)["applied"]).is_true()
	var second := CombatInjury.apply(target, applied, "b|7|a|x", 7)
	assert_bool(second["refreshed"]).is_true()
	assert_int(target.injuries.size()).is_equal(1)
	var record: Dictionary = target.injuries["arm"]
	assert_int(int(record["applications"])).is_equal(2)
	assert_str(str(record["severity"])).is_equal("minor")
	assert_int(int(record["effects"]["attack_accuracy_pp"])).is_equal(-10)
	assert_int(int(record["refreshed_at_tick"])).is_equal(7)
	# Same provenance again is a replay, not a third application.
	assert_bool(CombatInjury.apply(target, applied, "b|7|a|x", 7).get("replayed", false)).is_true()
	assert_int(int((target.injuries["arm"] as Dictionary)["applications"])).is_equal(2)


func test_arm_injury_penalizes_attacks_but_not_alacrity_or_spells() -> void:
	var controller := _controller()
	var target := controller.enemies[0]
	var actor := controller.active_actor()
	var action := controller.action_by_id(&"aim-test")
	var alacrity_before := actor.attribute_value(&"alacrity")
	var healthy := controller.forecast_action(action, target)
	CombatInjury.apply(actor, {"id": "arm-strained", "location_id": "arm", "effects": {"attack_accuracy_pp": -10}}, "k", 1)
	var injured := controller.forecast_action(action, target)
	assert_int(actor.attribute_value(&"alacrity")).is_equal(alacrity_before)
	assert_int(int(injured["resolution"]["accuracy_breakdown"]["hit_chance"])).is_equal(
		int(healthy["resolution"]["accuracy_breakdown"]["hit_chance"]) - 10
	)
	var labels: Array = []
	for modifier: Dictionary in injured["resolution"]["accuracy_breakdown"]["modifiers"]:
		labels.append(str(modifier["label"]))
	assert_array(labels).contains(["Injury: Arm"])
	var spell := action.duplicate(true) as CombatAction
	spell.id = &"injury-spell"
	spell.spell = true
	spell.aim_profiles = {}
	controller._actions[spell.id] = spell
	var spell_labels: Array = []
	for modifier: Dictionary in controller.forecast_action(spell, target)["resolution"]["accuracy_breakdown"]["modifiers"]:
		spell_labels.append(str(modifier["label"]))
	assert_array(spell_labels).not_contains(["Injury: Arm"])


func test_forecast_labels_hit_on_hit_and_overall_chances_and_threshold() -> void:
	var controller := _controller()
	var target := controller.enemies[0]
	var action := controller.action_by_id(&"aim-test")
	var forecast := controller.forecast_action(action, target, {"aim_location": "arm"})
	var injury: Dictionary = forecast["injury_forecast"]
	var hit := int(forecast["resolution"]["accuracy_breakdown"]["effective_hit_chance"])
	assert_int(int(injury["hit_chance"])).is_equal(hit)
	assert_int(int(injury["chance_on_hit"])).is_equal(50)
	assert_int(int(injury["overall_chance"])).is_equal(int(floor(float(hit * 50) / 100.0)))
	assert_bool(injury["eligible"]).is_true()
	assert_dict(controller.forecast_action(action, target, {"aim_location": "arm"})).is_equal(forecast)
	# Torso authors no injury; a threshold above the quoted damage makes the injury ineligible.
	assert_dict(controller.forecast_action(action, target, {"aim_location": "torso"})["injury_forecast"]).is_empty()
	action.aim_profiles["arm"]["injury"]["min_damage"] = 999
	var ineligible: Dictionary = controller.forecast_action(action, target, {"aim_location": "arm"})["injury_forecast"]
	assert_bool(ineligible["eligible"]).is_false()
	assert_int(int(ineligible["overall_chance"])).is_equal(0)
	assert_dict(target.injuries).is_empty()


func _controller() -> CombatController:
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
	controller.start([ally], [enemy], &"injury-test")
	return controller
