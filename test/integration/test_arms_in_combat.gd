extends GdUnitTestSuite
## Calling and measures S3 (F3c §4.1, docs/architecture-chargen-dramgid.md): a weapon attack's
## hit chance carries the attacker's Kit ARMS skill as (ARMS % − 40) / 2. Spells carry none, and
## a unit without a Kit skill (enemies, authored companions) hits as every fight did before.


func test_the_arms_term_is_zero_at_the_baseline_and_two_percent_a_point_either_side() -> void:
	var cases := {16.0: -12, 36.0: -2, 40.0: 0, 44.0: 2, 57.0: 8, 95.0: 27}
	for percent: float in cases:
		assert_int(Resolution.arms_bonus(percent)).override_failure_message(str(percent)).is_equal(cases[percent])


func test_the_breakdown_adds_the_term_only_for_a_weapon_attack_that_carries_it() -> void:
	var context := {
		"to_hit_enabled": true,
		"unit": {"alacrity": 3, "arms_percent": 57.0, "arms_label": "Heft 57%"},
		"target": {"alacrity": 3},
		"ability": {},
	}
	var weapon := Resolution.accuracy_breakdown(context)
	assert_int(int(weapon["hit_chance"])).is_equal(70 + 8)
	assert_str(_labels(weapon)).contains("Heft 57%")
	context["ability"] = {"is_spell": true}
	assert_int(int(Resolution.accuracy_breakdown(context)["hit_chance"])).override_failure_message(
		"a spell is not a weapon").is_equal(70)
	context["ability"] = {}
	(context["unit"] as Dictionary).erase("arms_percent")
	assert_int(int(Resolution.accuracy_breakdown(context)["hit_chance"])).is_equal(70)


func test_a_kit_member_hits_by_their_arms_and_the_strike_lands_on_the_forecast() -> void:
	var controller := _controller(_member("heft", {"muster": 4, "alacrity": 3}))
	var actor := controller.active_actor()
	var target := controller.enemies[0]
	var expected := Resolution.arms_bonus(SkillCheck.preview("heft", actor.source_member))
	assert_int(expected).is_greater(0)
	var strike := controller.action_by_id(&"arms-test")
	var forecast := controller.forecast_action(strike, target)
	var accuracy: Dictionary = forecast["resolution"]["accuracy_breakdown"]
	assert_str(_labels(accuracy)).contains("Heft")
	var kitless := _member("heft", {"muster": 4, "alacrity": 3})
	kitless.kit_weapon_skill = ""
	var baseline := _controller(kitless)
	var plain: Dictionary = baseline.forecast_action(baseline.action_by_id(&"arms-test"), baseline.enemies[0])
	assert_int(int(accuracy["hit_chance"])).is_equal(
		int(plain["resolution"]["accuracy_breakdown"]["hit_chance"]) + expected)
	# Commit resolves the chance the forecast showed.
	var result := controller.submit_action(&"arms-test", target)
	assert_bool(bool(result["allowed"])).is_true()
	assert_int(int(result["resolution"]["accuracy_breakdown"]["hit_chance"])).is_equal(int(accuracy["hit_chance"]))


func test_low_arms_costs_hit_chance_and_a_companion_without_a_kit_is_unchanged() -> void:
	var weak := _controller(_member("keen", {"alacrity": 2}))
	var weak_accuracy: Dictionary = weak.forecast_action(weak.action_by_id(&"arms-test"), weak.enemies[0])["resolution"]["accuracy_breakdown"]
	var companion := PartyMember.new()
	companion.id = "authored-companion"
	companion.class_id = "ironbrand"
	var authored := _controller(companion)
	var plain := _controller(null)
	var authored_chance := int(authored.forecast_action(authored.action_by_id(&"arms-test"), authored.enemies[0])["resolution"]["accuracy_breakdown"]["hit_chance"])
	var plain_chance := int(plain.forecast_action(plain.action_by_id(&"arms-test"), plain.enemies[0])["resolution"]["accuracy_breakdown"]["hit_chance"])
	assert_int(authored_chance).override_failure_message("no attributes, no Kit term").is_equal(plain_chance)
	# Keen at Alacrity 2, Kit-trained: 16 + 20 = 36% → −2; the Alacrity term moves too.
	assert_str(_labels(weak_accuracy)).contains("Keen 36%")


func _labels(accuracy: Dictionary) -> String:
	var labels: PackedStringArray = []
	for modifier: Dictionary in accuracy.get("modifiers", []):
		labels.append("%s %+d" % [modifier["label"], int(modifier["percentage_points"])])
	return " | ".join(labels)


func _member(kit_skill: String, attributes: Dictionary) -> PartyMember:
	var member := PartyMember.new()
	member.id = "arms-%s" % kit_skill
	member.class_id = "ironbrand"
	member.kit_weapon_skill = kit_skill
	member.skill_tiers = {kit_skill: "trained"}
	member.attributes = attributes.duplicate()
	return member


func _controller(member: PartyMember) -> CombatController:
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
	ally.display_name = "Arms ally"
	ally.hp = 200
	ally.max_hp = 200
	ally.attack = 12
	ally.source_member = member
	if member != null:
		ally.attributes = member.attributes.duplicate()
	var enemy := BattleActor.new()
	enemy.display_name = "Arms target"
	enemy.hp = 200
	enemy.max_hp = 200
	# A ranged weapon attack so the four-cell strip needs no movement (as test_injuries does).
	var action := CombatAction.make(&"arms-test", "Arms test", CombatAction.Kind.ATTACK)
	action.ct_cost = 30
	action.target_profile = &"ranged"
	var actions := CombatActionCatalog.all()
	actions.append(action)
	var controller := CombatController.new()
	controller.configure(actions, grid, rules)
	controller.start([ally], [enemy], &"arms-test")
	return controller
