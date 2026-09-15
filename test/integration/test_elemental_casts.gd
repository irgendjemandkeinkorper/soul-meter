extends GdUnitTestSuite

var _controllers: Array[CombatController] = []
var _soul_before: float
var _flags_before: Dictionary


func before_test() -> void:
	_soul_before = GameState.soul_meter
	_flags_before = GameState.flags.duplicate(true)
	GameState.flags.erase(GameState.HUSKED_FLAG)
	GameState.flags.erase(GameState.HUSKED_RECOVERY_CEILING_FLAG)
	GameState.set_soul_meter(50.0)


func after_test() -> void:
	for controller: CombatController in _controllers:
		for actor: BattleActor in controller.allies + controller.enemies:
			actor.class_resource.host = null
	_controllers.clear()
	GameState.flags = _flags_before
	GameState.soul_meter = _soul_before


func test_utility_casts_preserve_zero_damage_through_both_schedulers_and_class_bonuses() -> void:
	for element: StringName in [&"khor", &"zhem"]:
		for charge_time: bool in [false, true]:
			var controller := _battle(element, charge_time, "Ofshutje")
			var owner := controller.allies[0]
			var enemy := controller.enemies[0]
			owner.aftertones = [{"element": "vel", "remaining_rounds": 3, "held": false, "anchored": false}]
			enemy.aftertones = [{"element": "khash", "remaining_rounds": 3, "held": false, "anchored": false}]
			enemy.tempo = 3
			var result := _forecast_and_cast(controller)
			assert_int(result.resolution.damage).is_equal(0)
			assert_int(enemy.hp).is_equal(100)
			assert_int((enemy.class_resource as IronbrandScars).scars).is_equal(0)
			assert_int(owner.breath).is_equal(7)
			assert_float(GameState.soul_meter).is_equal(50.0)
			if element == &"khor":
				assert_bool(owner.aftertones.any(func(a: Dictionary) -> bool: return bool(a.get("held", false)))).is_true()
			else:
				assert_int(enemy.tempo).is_equal(0)
				assert_bool(enemy.aftertones.any(func(a: Dictionary) -> bool: return a.element == "khash")).is_false()


func test_global_hush_casts_pay_costs_without_rewriting_live_tiles() -> void:
	for charge_time: bool in [false, true]:
		var controller := _battle(&"zhur", charge_time)
		var source := controller.tile_state_at(Vector2i.ZERO)
		var target := controller.tile_state_at(Vector2i(1, 0))
		source.apply_residue(&"zhur")
		target.apply_residue(&"tham")
		controller.configure_weather(&"zhur", true)
		var source_before := source.to_dict()
		var target_before := target.to_dict()
		var result := _forecast_and_cast(controller)
		assert_int(result.resolution.damage).is_greater(0)
		assert_dict(source.to_dict()).is_equal(source_before)
		assert_dict(target.to_dict()).is_equal(target_before)
		assert_int(controller.allies[0].breath).is_equal(7)
		assert_bool(source.hush).is_false()
		assert_bool(target.hush).is_false()
		controller.weather.set_hush(false)
		_forecast_and_cast(controller)
		assert_int(source.charge_level).is_greater(1)
		assert_int(target.charge_level).is_equal(0)


func test_local_hush_suppresses_only_the_affected_tiles() -> void:
	for hush_source: bool in [false, true]:
		var controller := _battle(&"zhur")
		var source := controller.tile_state_at(Vector2i.ZERO)
		var target := controller.tile_state_at(Vector2i(1, 0))
		source.apply_residue(&"zhur")
		target.apply_residue(&"tham")
		source.hush = hush_source
		target.hush = not hush_source
		_forecast_and_cast(controller)
		assert_int(source.charge_level).is_equal(1 if hush_source else 2)
		assert_int(target.charge_level).is_equal(0 if hush_source else 1)


func test_non_damaging_spells_do_not_seed_hunger_but_weapon_hits_still_do() -> void:
	var controller := _battle(&"zhem", false, "Vhorr")
	var resource := controller.allies[0].class_resource as VhorrHunger
	_forecast_and_cast(controller)
	assert_int(resource.hunger).is_equal(0)
	assert_array(resource.pending_dot_targets).is_empty()
	assert_array(controller.deferred_entries()).is_empty()
	assert_bool(controller.submit_action(&"strike", controller.enemies[0]).allowed).is_true()
	assert_int(resource.hunger).is_equal(1)


func _forecast_and_cast(controller: CombatController) -> Dictionary:
	var action := controller.action_by_id(&"cast-seam")
	var options := {"ability_id": "elemental-cast", "seed": 17}
	var forecast := controller.forecast_action(action, controller.enemies[0], options)
	assert_bool(forecast.allowed).override_failure_message(str(forecast)).is_true()
	if not bool(forecast.allowed):
		return {}
	var committed := controller.submit_action(action.id, controller.enemies[0], options)
	assert_bool(committed.allowed).is_true()
	assert_dict(committed.resolution).is_equal(forecast.resolution)
	assert_bool(committed.resolution.fizzled).is_false()
	return committed


func _battle(element: StringName, charge_time: bool = false, patron: String = "") -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = charge_time
	var owner := BattleActor.new()
	owner.hp = 100
	owner.max_hp = 100
	owner.breath = 10
	owner.attributes[&"pitch"] = 100
	owner.attributes[&"alacrity"] = 100
	owner.source_member = PartyMember.new()
	owner.source_member.id = "elemental-caster"
	owner.source_member.patron = patron
	owner.class_resource = ClassResourceRegistry.for_patron(patron)
	var enemy := BattleActor.new()
	enemy.hp = 100
	enemy.max_hp = 100
	enemy.class_resource = ClassResourceRegistry.for_patron("Kero")
	var ability := AbilityDefinition.new()
	ability.id = "elemental-cast"
	ability.element_id = element
	ability.elements = [element]
	ability.magnitude = &"note"
	ability.power = 10
	ability.breath_cost = 3
	var tables := TacticalTables.new()
	tables.abilities[ability.id] = ability
	var loadout := UnitLoadout.create(owner.source_member.id)
	loadout.action_ability_ids.append(ability.id)
	tables.loadouts[owner.source_member.id] = loadout
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_ground())
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), grid, rules, null, [ability], tables)
	controller.start([owner], [enemy], &"elemental-casts")
	_controllers.append(controller)
	return controller


func _ground() -> TileMapLayer:
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	layer.tile_set = tile_set
	layer.set_cell(Vector2i.ZERO, 0, Vector2i.ZERO)
	layer.set_cell(Vector2i(1, 0), 0, Vector2i.ZERO)
	return layer
