extends GdUnitTestSuite
## Checkpoint D cost probe: `choose_enemy_aim` for 100 enemies against 100 allies on one
## grid, versus the ordinary forecast alone. Prints timings; asserts only sanity bounds.


func test_aim_choice_cost_on_a_hundred_actor_grid() -> void:
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
	for x: int in 20:
		for y: int in 20:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(ground)
	var allies: Array[BattleActor] = []
	var enemies: Array[BattleActor] = []
	for index: int in 100:
		var ally := BattleActor.new()
		ally.display_name = "Ally %d" % index
		ally.hp = 50
		ally.max_hp = 50
		ally.defense = 1
		ally.attributes = {&"alacrity": 3}
		ally.anatomy = EncounterCatalog.make_actor(&"bog-wight").anatomy
		allies.append(ally)
		var enemy := EncounterCatalog.make_actor(&"bog-wight")
		enemies.append(enemy)
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules)
	controller.start(allies, enemies, &"aim-cost-probe")
	var strike := controller.action_by_id(&"enemy-strike")
	var baseline_usec := 0
	var aimed_usec := 0
	var aimed_count := 0
	for index: int in 100:
		var enemy := enemies[index]
		var target := allies[index]
		var t0 := Time.get_ticks_usec()
		controller._enemy_attack_value(enemy, target, strike, {})
		baseline_usec += Time.get_ticks_usec() - t0
		var t1 := Time.get_ticks_usec()
		var choice := controller.choose_enemy_aim(enemy, target, strike)
		aimed_usec += Time.get_ticks_usec() - t1
		if not choice.is_empty():
			aimed_count += 1
	print("AIM-COST-PROBE actors=100 baseline_forecast_total_ms=%.2f aim_choice_total_ms=%.2f per_actor_ms=%.3f aimed=%d cpu=%s" % [
		baseline_usec / 1000.0, aimed_usec / 1000.0, aimed_usec / 100000.0, aimed_count, OS.get_processor_name()])
	assert_int(aimed_usec).is_less(5_000_000)
