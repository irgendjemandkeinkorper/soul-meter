extends GdUnitTestSuite
## P1.4: consume equipment through the real forecast/submit action path.

var _before: Dictionary


func before_test() -> void:
	_before = GameState.to_dict()
	GameState.inventory.clear()
	var member := PartyMember.new()
	member.id = GameState.PROTAGONIST_ID
	member.display_name = "Equipment fixture"
	member.hp = 100
	member.max_hp = 100
	member.attack = 11
	member.defense = 4
	GameState.set_party([member])


func after_test() -> void:
	GameState.from_dict(_before)


func test_hammer_changes_committed_damage_by_exactly_two_and_nothing_else() -> void:
	var bare := _strike(false, false)
	var armed := _strike(true, false)
	assert_bool(bare["hit"]).is_true()
	assert_bool(armed["hit"]).is_true()
	# The hammer's +2 lands before a critical (item 33) multiplies the mitigated hit. Both
	# strikes share the fixture's deterministic roll, so they crit together or not at all;
	# the on-hit preview never crits, so it carries the uncritted damage.
	assert_bool(armed["critical"]).is_equal(bare["critical"])
	assert_int(armed["damage_on_hit"] - bare["damage_on_hit"]).is_equal(2)
	assert_int(bare["damage"]).is_equal(Resolution.critical_damage(bare["damage_on_hit"], bare["critical"]))
	assert_int(armed["damage"]).is_equal(Resolution.critical_damage(armed["damage_on_hit"], armed["critical"]))
	assert_int(armed["hit_chance"]).is_equal(bare["hit_chance"])
	assert_int(armed["ap_spent"]).is_equal(bare["ap_spent"])
	assert_int(armed["ct_cost"]).is_equal(bare["ct_cost"])
	assert_int(GameState.protagonist().attack).is_equal(11)


func test_hammer_does_not_turn_a_miss_into_damage_or_change_accuracy() -> void:
	var bare := _strike(false, true)
	var armed := _strike(true, true)
	assert_bool(bare["hit"]).is_false()
	assert_bool(armed["hit"]).is_false()
	assert_int(bare["damage"]).is_equal(0)
	assert_int(armed["damage"]).is_equal(0)
	assert_int(armed["hit_chance"]).is_equal(bare["hit_chance"])
	assert_int(armed["ap_spent"]).is_equal(bare["ap_spent"])


func _strike(equipped: bool, force_miss: bool) -> Dictionary:
	var member := GameState.protagonist()
	GameState.unequip_item(member, &"main")
	if equipped:
		var items := GameState.inventory.get_items_with_prototype_id(ItemIds.WEAPONS_FORGE_HAMMER)
		var hammer: InventoryItem = items[0] if not items.is_empty() else GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
		assert_bool(GameState.equip_item(member, hammer, &"main")).is_true()
	var actor := BattleActor.from_party_member(member, 0)
	var defender := BattleActor.new()
	defender.display_name = "Fixed defender"
	defender.hp = 100
	defender.max_hp = 100
	defender.defense = 4
	# Fixed fixture inputs put hit chance at opposite extremes without changing
	# the production action, RNG, or the equipment's accuracy/ARMS behavior.
	actor.attributes["alacrity"] = 0 if force_miss else 100
	defender.attributes["alacrity"] = 100 if force_miss else 0
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_ground())
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	assert_bool(grid.configure_initial_cells({actor: Vector2i.ZERO, defender: Vector2i(2, 0)})["allowed"]).is_true()
	controller.start([actor], [defender], &"equipment-fixture")
	var strike := controller.action_by_id(&"strike")
	assert_bool(controller.query_action(strike, defender)["allowed"]).is_false()
	assert_bool(grid.move(defender, &"c:1,0,0")["allowed"]).is_true()
	grid.set_facing(actor, &"e")
	grid.set_facing(defender, &"w")
	assert_bool(controller.query_action(strike, defender)["allowed"]).is_true()
	var forecast := controller.forecast_action(strike, defender)
	var before_hp := defender.hp
	var before_ap := actor.action_points
	var result := controller.submit_action(&"strike", defender)
	assert_bool(result.get("allowed", false)).is_true()
	assert_int(before_hp - defender.hp).is_equal(forecast["damage"])
	assert_dict(result["resolution"]).is_equal(forecast["resolution"])
	return {
		"damage": before_hp - defender.hp,
		"damage_on_hit": int(forecast["damage_on_hit"]),
		"critical": bool(result["resolution"].get("critical", false)),
		"hit": result["resolution"]["hit"],
		"hit_chance": result["resolution"]["hit_chance"],
		"ap_spent": before_ap - actor.action_points,
		"ct_cost": rules.charge_cost_for(strike),
	}


func _ground() -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	for x: int in 3:
		layer.set_cell(Vector2i(x, 0), 0, Vector2i.ZERO)
	return layer
