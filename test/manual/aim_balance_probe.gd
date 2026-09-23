extends GdUnitTestSuite
## Balance probe (called-shots balance pass): the starting party and recruitable companions
## against every production archetype, and every archetype's enemy-strike against them, with
## the production aim profiles. Prints one BAL line per pairing and aim; asserts nothing but
## sanity. Party anatomy is whatever PartyMember carries (the provisional humanoid default).

const ARCHETYPES: Array[StringName] = [
	&"bog-wight", &"loam-maddened-boar", &"gnaal-breach-hound", &"gnaal-rift-scavenger",
	&"mustered-bloodbellow", &"cleaned-jawbrace-guard",
]


func test_print_balance_matrix() -> void:
	var members: Array[PartyMember] = [GameState._make_vex()]
	members.append_array(GameState.recruitable_candidates())
	for charge_time: bool in [false]:
		for member: PartyMember in members:
			for archetype: StringName in ARCHETYPES:
				var controller := _controller(member, archetype, charge_time)
				var vex := controller.allies[0]
				var enemy := controller.enemies[0]
				var strike := controller.action_by_id(&"strike")
				var enemy_strike := controller.action_by_id(&"enemy-strike")
				_report("PARTY", member.display_name, String(archetype), controller, vex, enemy, strike)
				# Outside its turn the enemy holds no AP; grant what the AP round would.
				enemy.action_points = controller.rules.base_action_points + int(enemy.attribute_value(&"alacrity") / controller.rules.attribute_points_per_ap)
				_report_enemy(String(archetype), member.display_name, controller, enemy, vex, enemy_strike)
				var choice := controller.choose_enemy_aim(enemy, vex, enemy_strike)
				print("BAL AI %s vs %s -> %s" % [archetype, member.display_name, str(choice.get("aim_location", "ordinary")) if not choice.is_empty() else "ordinary"])
	assert_bool(true).is_true()


func _report(side: String, attacker: String, defender: String, controller: CombatController, actor: BattleActor, target: BattleActor, action: CombatAction) -> void:
	var ordinary := controller.forecast_action(action, target, {})
	print("BAL %s %s vs %s ordinary hit=%d dmg=%d hp=%d" % [side, attacker, defender,
		int(ordinary["resolution"]["accuracy_breakdown"]["effective_hit_chance"]), int(ordinary["damage_on_hit"]), target.max_hp])
	for location: String in ["torso", "arm", "leg", "head", "throat"]:
		var quote := controller.query_action(action, target, {"aim_location": location})
		if not bool(quote["allowed"]):
			print("BAL %s %s vs %s %s refused=%s" % [side, attacker, defender, location, str(quote["blocked_by"])])
			continue
		var forecast := controller.forecast_action(action, target, {"aim_location": location})
		var injury: Dictionary = forecast["injury_forecast"]
		print("BAL %s %s vs %s %s hit=%d dmg=%d cost=%d injury=%s on_hit=%d overall=%d serious=%s serious_at=%d" % [
			side, attacker, defender, location,
			int(forecast["resolution"]["accuracy_breakdown"]["effective_hit_chance"]), int(forecast["damage_on_hit"]),
			int(forecast["ap_cost"]), str(injury.get("id", "-")), int(injury.get("chance_on_hit", 0)),
			int(injury.get("overall_chance", 0)), str(injury.get("serious_eligible", false)), int(injury.get("serious_min_damage", 0)),
		])


func _report_enemy(attacker: String, defender: String, controller: CombatController, actor: BattleActor, target: BattleActor, action: CombatAction) -> void:
	var ordinary := controller.forecast_context(actor, target, action, {})
	var ordinary_hit := int(Resolution.accuracy_breakdown(ordinary)["effective_hit_chance"])
	var ordinary_dmg := controller._forecast_damage_on_hit(ordinary, target)
	print("BAL ENEMY %s vs %s ordinary hit=%d dmg=%d hp=%d ap=%d value=%.2f" % [attacker, defender, ordinary_hit, ordinary_dmg, target.max_hp, actor.action_points, controller._enemy_attack_value(actor, target, action, {})])
	for location: String in ["torso", "arm", "leg", "head", "throat"]:
		var aim: Dictionary = controller._query_aim(actor, target, action, location)
		if not bool(aim.get("allowed", false)):
			print("BAL ENEMY %s vs %s %s refused=%s" % [attacker, defender, location, str(aim.get("blocked_by", "?"))])
			continue
		var context := controller.forecast_context(actor, target, action, {"aim_location": location})
		var hit := int(Resolution.accuracy_breakdown(context)["effective_hit_chance"])
		var dmg := controller._forecast_damage_on_hit(context, target)
		var injury: Dictionary = context.get("injury", {})
		var eligible := not injury.is_empty() and dmg >= int(injury.get("min_damage", 1))
		var serious: Dictionary = injury.get("serious", {})
		var serious_eligible := eligible and not serious.is_empty() and dmg >= int(serious.get("min_damage", 999))
		var priced := CalledShot.priced_action(action, location)
		print("BAL ENEMY %s vs %s %s hit=%d dmg=%d cost=%d payable=%s injury=%s on_hit=%d serious=%s serious_at=%d value=%.2f" % [
			attacker, defender, location, hit, dmg, priced.ap_cost, str(controller._enemy_can_pay(actor, priced)),
			str(injury.get("id", "-")), int(injury.get("chance_on_hit", 0)) if eligible else 0, str(serious_eligible), int(serious.get("min_damage", 0)),
			controller._enemy_attack_value(actor, target, action, {"aim_location": location}),
		])


func _controller(member: PartyMember, archetype: StringName, charge_time: bool) -> CombatController:
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
	var ally := BattleActor.from_party_member(member, 0)
	var enemy := EncounterCatalog.make_actor(archetype)
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	controller.start([ally], [enemy], &"balance-probe")
	assert_bool(grid.displace(enemy, grid.cell_of(ally) + Vector2i(1, 0))["allowed"]).is_true()
	return controller
