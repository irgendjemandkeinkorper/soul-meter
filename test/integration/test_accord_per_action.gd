extends GdUnitTestSuite
## #349 (E6.1, architecture §4.11): `FieldMap.accord_at()`, per-action accord sampled from the
## caster's cell, and the frozen `(day_index, phase, weather, cell)` forecast context that makes
## forecast == resolution hold even when a phase tick lands between the two.
##
## Owner ruling 2026-10-11: the spatial source is the `AccordZone` placeable, and Hush/Waning
## Loom pressure is derived from its `accord_delta`. `FieldMap.zone_delta()` sums the zones.


# ---- FieldMap.accord_at ----


func test_a_field_without_zones_has_a_neutral_zone_delta() -> void:
	var field := auto_free(FieldMap.new()) as FieldMap
	for cell: Vector2i in [Vector2i.ZERO, Vector2i(3, 7), Vector2i(-4, 12)]:
		assert_float(field.zone_delta(cell)).is_equal(0.0)


func test_accord_at_without_zones_or_variation_is_the_base_exactly() -> void:
	var field := auto_free(FieldMap.new()) as FieldMap
	for base: float in [0.0, 12.5, 63.0, 100.0]:
		assert_float(field.accord_at(Vector2i(2, 2), base)).is_equal(base)
	assert_float(field.accord_at(Vector2i(2, 2))).is_equal(field.accord_base())


func test_accord_at_composes_variation_and_clamps() -> void:
	var field := auto_free(FieldMap.new()) as FieldMap
	assert_float(field.accord_at(Vector2i(1, 1), 60.0, 7.0)).is_equal(67.0)
	assert_float(field.accord_at(Vector2i(1, 1), 60.0, -9.0)).is_equal(51.0)
	assert_float(field.accord_at(Vector2i(1, 1), 96.0, 10.0)).is_equal(100.0)
	assert_float(field.accord_at(Vector2i(1, 1), 4.0, -10.0)).is_equal(0.0)


func test_accord_base_subtracts_thinning_exactly_once() -> void:
	var path: String = LocationRegistry.WOUND_LIP.scene_path
	var location := LocationRegistry.by_scene(path)
	assert_object(location).is_not_null()
	var field := auto_free(FieldMap.new()) as FieldMap
	field.scene_file_path = path
	var once := SkillCheck.location_fizzle_integrity(location.harmonic_accord, path)
	assert_float(field.accord_base()).is_equal(once)
	assert_float(field.accord_at(Vector2i(5, 5))).is_equal(once)
	# The thinned front line must actually thin, or "once" proves nothing.
	assert_float(once).is_less(location.harmonic_accord)


# ---- Battle's sampler ----


func test_battle_sampler_freezes_clock_weather_and_cell_and_keeps_the_base() -> void:
	var field := auto_free(FieldMap.new()) as FieldMap
	var record: Dictionary = Battle._sample_accord(Vector2i(4, 2), &"mozh", field, 71.0)
	assert_int(int(record["day_index"])).is_equal(WorldClock.day_index())
	assert_str(String(record["phase"])).is_equal(String(WorldClock.phase()))
	assert_str(String(record["weather"])).is_equal("mozh")
	assert_bool(record["cell"] == Vector2i(4, 2)).is_true()
	assert_float(float(record["harmonic_accord"])).is_equal(71.0)
	var off_field: Dictionary = Battle._sample_accord(null, &"", null, 71.0)
	assert_float(float(off_field["harmonic_accord"])).is_equal(71.0)


# ---- CombatController per-action accord ----


func test_no_sampler_keeps_the_legacy_per_battle_float() -> void:
	var fixture := _cast_fixture()
	var controller: CombatController = fixture["controller"]
	controller.configure_agreement_integrity(42.0)
	var forecast := controller.forecast_action(
		fixture["cast"], fixture["target"], fixture["options"]
	)
	assert_bool(bool(forecast.get("allowed", false))).is_true()
	var fizzle: Dictionary = forecast["context"]["fizzle"]
	assert_float(float(fizzle["harmonic_accord"])).is_equal(42.0)
	assert_float(float(fizzle["agreement_integrity"])).is_equal(42.0)
	assert_bool(fizzle.has("accord_context")).is_false()


func test_accord_is_sampled_from_the_casters_cell() -> void:
	var fixture := _cast_fixture()
	var controller: CombatController = fixture["controller"]
	var seen: Array = []
	controller.configure_accord_sampler(
		func(cell: Variant, weather_id: StringName) -> Dictionary:
			seen.append(cell)
			var at := cell as Vector2i
			return {
				"day_index": 0, "phase": &"morning", "weather": weather_id,
				"harmonic_accord": 100.0 - 10.0 * float(at.x),
			}
	)
	var caster: BattleActor = fixture["caster"]
	var forecast := controller.forecast_action(
		fixture["cast"], fixture["target"], fixture["options"]
	)
	assert_bool(bool(forecast.get("allowed", false))).is_true()
	var caster_cell: Vector2i = controller.battlefield.cell_of(caster)
	assert_bool(seen.has(caster_cell)).is_true()
	var fizzle: Dictionary = forecast["context"]["fizzle"]
	assert_float(float(fizzle["harmonic_accord"])).is_equal(100.0 - 10.0 * float(caster_cell.x))
	assert_bool(fizzle["accord_context"]["cell"] == caster_cell).is_true()
	# One sample per actor per cell: repeated forecasts reuse the frozen record.
	controller.forecast_action(fixture["cast"], fixture["target"], fixture["options"])
	assert_int(seen.size()).is_equal(1)


func test_forecast_equals_resolution_when_a_phase_tick_lands_between_them() -> void:
	var fixture := _cast_fixture()
	var controller: CombatController = fixture["controller"]
	var clock := {"phase_index": 0}
	var phases: Array[StringName] = [&"morning", &"afternoon"]
	# A phase-dependent accord, standing in for E1.7's variation once it is wired.
	var sampler := func(cell: Variant, weather_id: StringName) -> Dictionary:
		var phase_index := int(clock["phase_index"])
		return {
			"day_index": 0, "phase": phases[phase_index], "weather": weather_id, "cell": cell,
			"harmonic_accord": 90.0 if phase_index == 0 else 30.0,
		}
	controller.configure_accord_sampler(sampler)

	var forecast := controller.forecast_action(
		fixture["cast"], fixture["target"], fixture["options"]
	)
	assert_bool(bool(forecast.get("allowed", false))).is_true()
	assert_float(float(forecast["context"]["fizzle"]["harmonic_accord"])).is_equal(90.0)

	clock["phase_index"] = 1 # the WorldClock ticks between forecast and commit

	# Guard: the tick really changes the number a fresh sample would give.
	var fresh := _cast_fixture()
	var fresh_controller: CombatController = fresh["controller"]
	fresh_controller.configure_accord_sampler(sampler)
	var after_tick := fresh_controller.forecast_action(
		fresh["cast"], fresh["target"], fresh["options"]
	)
	assert_float(float(after_tick["context"]["fizzle"]["harmonic_accord"])).is_equal(30.0)
	assert_float(float(after_tick["fizzle_percent"])).is_not_equal(
		float(forecast["fizzle_percent"])
	)

	var committed := controller.submit_action(
		(fixture["cast"] as CombatAction).id, fixture["target"], fixture["options"]
	)
	assert_bool(bool(committed.get("allowed", false))).is_true()
	assert_float(float(committed["resolution"]["fizzle_percent"])).is_equal(
		float(forecast["fizzle_percent"])
	)
	assert_str(String(forecast["context"]["fizzle"]["accord_context"]["phase"])).is_equal("morning")


func test_a_resolved_action_releases_its_frozen_context() -> void:
	var fixture := _cast_fixture()
	var controller: CombatController = fixture["controller"]
	var samples := {"count": 0}
	controller.configure_accord_sampler(
		func(_cell: Variant, _weather_id: StringName) -> Dictionary:
			samples["count"] = int(samples["count"]) + 1
			return {"harmonic_accord": 75.0}
	)
	var caster: BattleActor = fixture["caster"]
	assert_bool(controller.accord_context_for(caster).is_empty()).is_false()
	assert_int(int(samples["count"])).is_equal(1)
	controller.submit_action(
		(fixture["cast"] as CombatAction).id, fixture["target"], fixture["options"]
	)
	controller.accord_context_for(caster)
	assert_int(int(samples["count"])).is_equal(2)


func test_an_explicit_frozen_context_replays_exactly() -> void:
	var fixture := _cast_fixture()
	var controller: CombatController = fixture["controller"]
	controller.configure_accord_sampler(
		func(_cell: Variant, _weather_id: StringName) -> Dictionary:
			return {"harmonic_accord": 10.0}
	)
	var options: Dictionary = (fixture["options"] as Dictionary).duplicate(true)
	options["accord_context"] = {
		"day_index": 3, "phase": &"evening", "weather": &"", "cell": Vector2i(1, 1),
		"harmonic_accord": 55.0,
	}
	var forecast := controller.forecast_action(fixture["cast"], fixture["target"], options)
	assert_float(float(forecast["context"]["fizzle"]["harmonic_accord"])).is_equal(55.0)


# ---- AccordZone ----


func test_zone_delta_sums_every_zone_covering_the_cell() -> void:
	var field := _zone_field()
	_add_zone(field, Vector2i(3, 3), -20, Vector2i(1, 1))
	_add_zone(field, Vector2i(4, 3), -5, Vector2i(0, 0))
	_add_zone(field, Vector2i(8, 8), 15, Vector2i(1, 1))
	assert_float(field.zone_delta(Vector2i(3, 3))).is_equal(-20.0)
	assert_float(field.zone_delta(Vector2i(4, 3))).is_equal(-25.0) # overlap sums
	assert_float(field.zone_delta(Vector2i(2, 2))).is_equal(-20.0) # extent edge
	assert_float(field.zone_delta(Vector2i(1, 3))).is_equal(0.0) # just outside
	assert_float(field.zone_delta(Vector2i(9, 7))).is_equal(15.0)
	assert_int(field.accord_zones().size()).is_equal(3)


func test_accord_at_applies_the_zone_and_clamps() -> void:
	var field := _zone_field()
	_add_zone(field, Vector2i(3, 3), -30, Vector2i(1, 1))
	assert_float(field.accord_at(Vector2i(3, 3), 80.0)).is_equal(50.0)
	assert_float(field.accord_at(Vector2i(0, 0), 80.0)).is_equal(80.0)
	assert_float(field.accord_at(Vector2i(3, 3), 20.0)).is_equal(0.0)


func test_zone_element_default_overrides_the_location_only_inside_the_zone() -> void:
	var field := _zone_field()
	var zone := _add_zone(field, Vector2i(3, 3), 0, Vector2i(1, 1))
	zone.element_default = &"mozh"
	assert_str(String(field.element_default_at(Vector2i(4, 4)))).is_equal("mozh")
	assert_str(String(field.element_default_at(Vector2i(0, 0)))).is_equal(
		String(field.weather_default())
	)


func test_a_negative_half_extent_covers_a_single_line() -> void:
	var zone := auto_free(AccordZone.new()) as AccordZone
	zone.half_width_cells = -3
	zone.half_height_cells = 2
	assert_int(zone.covered_cells(Vector2i(5, 5)).size()).is_equal(5)
	assert_bool(zone.covers(Vector2i(5, 7), Vector2i(5, 5))).is_true()
	assert_bool(zone.covers(Vector2i(6, 5), Vector2i(5, 5))).is_false()


func test_a_placed_zone_changes_the_forecast_and_forecast_still_equals_resolution() -> void:
	var plain := _cast_fixture()
	var plain_controller: CombatController = plain["controller"]
	var plain_field := _zone_field()
	plain_controller.configure_accord_sampler(Battle._sample_accord.bind(plain_field, 90.0))
	var without_zone := plain_controller.forecast_action(plain["cast"], plain["target"], plain["options"])

	var zoned := _cast_fixture()
	var controller: CombatController = zoned["controller"]
	var field := _zone_field()
	var caster_cell: Vector2i = controller.battlefield.cell_of(zoned["caster"])
	_add_zone(field, caster_cell, -40, Vector2i(1, 1))
	controller.configure_accord_sampler(Battle._sample_accord.bind(field, 90.0))
	var forecast := controller.forecast_action(zoned["cast"], zoned["target"], zoned["options"])

	assert_float(float(without_zone["context"]["fizzle"]["harmonic_accord"])).is_equal(90.0)
	assert_float(float(forecast["context"]["fizzle"]["harmonic_accord"])).is_equal(50.0)
	assert_float(float(forecast["fizzle_percent"])).is_greater(float(without_zone["fizzle_percent"]))
	var committed := controller.submit_action(
		(zoned["cast"] as CombatAction).id, zoned["target"], zoned["options"]
	)
	assert_float(float(committed["resolution"]["fizzle_percent"])).is_equal(
		float(forecast["fizzle_percent"])
	)


# ---- Loom pressure derived from accord_delta ----


func test_loom_strength_is_the_accord_deficit_only() -> void:
	assert_float(AccordMath.loom_strength(-25.0)).is_equal(25.0)
	assert_float(AccordMath.loom_strength(0.0)).is_equal(0.0)
	assert_float(AccordMath.loom_strength(30.0)).is_equal(0.0)
	assert_float(AccordMath.loom_strength(-250.0)).is_equal(100.0)


func test_loom_penalty_follows_skill_sensitivity() -> void:
	var service: SkillCheckService = auto_free(SkillCheckService.new())
	var zone := auto_free(AccordZone.new()) as AccordZone
	zone.accord_delta = -20
	var full_share := AccordMath.loom_penalty(DramgidSchema.LoomSensitivity.FULL, -20.0)
	var partial_share := AccordMath.loom_penalty(DramgidSchema.LoomSensitivity.PARTIAL, -20.0)
	assert_int(full_share).is_equal(20)
	assert_int(partial_share).is_equal(roundi(20.0 * AccordMath.LOOM_PARTIAL_SHARE))
	for skill_id: String in DramgidSchema.SKILL_IDS:
		var loom := int(DramgidSchema.SKILLS[skill_id]["loom"])
		var expected := 0
		if loom == DramgidSchema.LoomSensitivity.FULL:
			expected = full_share
		elif loom == DramgidSchema.LoomSensitivity.PARTIAL:
			expected = partial_share
		assert_int(service.loom_penalty(skill_id, zone)).override_failure_message(skill_id).is_equal(expected)
		assert_int(service.loom_penalty(skill_id, -20.0)).is_equal(expected)
		assert_int(service.loom_penalty(skill_id, 20.0)).is_equal(0)
		assert_int(service.loom_penalty(skill_id, null)).is_equal(0)
	for skill_id: String in DramgidSchema.ARMS_SKILL_IDS:
		assert_int(service.loom_penalty(skill_id, -100.0)).is_equal(0)


# ---- fixture ----


func _cast_fixture() -> Dictionary:
	var cast := CombatActionCatalog.by_id(&"cast-seam")
	var ability := AbilityDefinition.new()
	ability.id = "accord-cell-cast"
	ability.element_id = &"zhur"
	ability.elements = [&"zhur"]
	ability.magnitude = &"note"
	ability.power = 6
	ability.breath_cost = 3
	var caster := _actor("Accord Caster", 30, 7, 2)
	caster.attributes[&"pitch"] = 2
	caster.breath = 15
	caster.source_member = PartyMember.new()
	caster.source_member.id = "accord-cell-caster"
	var target := _actor("Accord Target", 100, 1, 1)
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(
		true
	) as CombatRules
	rules.use_charge_time = false
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_sized_grid_ground(6, 6))
	var tables := TacticalTables.new()
	var loadout := UnitLoadout.create("accord-cell-caster")
	tables.abilities[ability.id] = ability
	loadout.action_ability_ids.append(ability.id)
	tables.loadouts["accord-cell-caster"] = loadout
	var controller := CombatController.new()
	controller.configure([cast], grid, rules, null, [ability], tables)
	controller.start([caster], [target], &"accord-per-action")
	assert_bool(bool(grid.move(caster, &"c:3,1,0").get("allowed", false))).is_true()
	assert_bool(bool(grid.move(target, &"c:3,4,0").get("allowed", false))).is_true()
	return {
		"controller": controller,
		"cast": cast,
		"caster": caster,
		"target": target,
		"options": {"ability_id": ability.id, "seed": 73},
	}


func _actor(name: String, hp: int, attack: int, defense: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	return actor


func _sized_grid_ground(width: int, height: int, managed: bool = true) -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer := TileMapLayer.new()
	if managed:
		auto_free(layer)
	layer.tile_set = tile_set
	for y in height:
		for x in width:
			layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	return layer


func _zone_field() -> FieldMap:
	var field := FieldMap.new()
	field.name = "ZoneField"
	var ground := _sized_grid_ground(12, 12, false)
	ground.name = "IsometricGround"
	field.add_child(ground)
	add_child(field)
	auto_free(field)
	return field


func _add_zone(field: FieldMap, anchor: Vector2i, delta: int, half_extent: Vector2i) -> AccordZone:
	var zone := (load("res://actors/accord_zone/accord_zone.tscn") as PackedScene).instantiate() as AccordZone
	zone.accord_delta = delta
	zone.half_width_cells = half_extent.x
	zone.half_height_cells = half_extent.y
	field.add_child(zone)
	zone.global_position = field.ground().to_global(field.ground().map_to_local(anchor))
	return zone
