extends GdUnitTestSuite
## Calling and measures S4: the three Combat Disciplines act in a fight through seams combat
## already has (DisciplineProfile; numbers PROVISIONAL, owner-decisions item 51). A unit with no
## member Discipline — enemies, authored companions — plays exactly as before.


func test_chordblade_footwork_prices_every_path_lower_and_reaches_further() -> void:
	var plain := _controller(_member(""))
	var footed := _controller(_member("chordblade"))
	var walker := footed.allies[0]
	assert_int(footed._injured_move_ct(walker, 30)).is_equal(24)
	assert_int(plain._injured_move_ct(plain.allies[0], 30)).is_equal(30)
	var labels: PackedStringArray = []
	for modifier: Dictionary in footed._move_cost_modifiers(walker):
		labels.append(str(modifier["label"]))
	assert_str(", ".join(labels)).contains("Chordblade footwork")
	assert_int(footed.reachable_for(walker).size()).is_greater(plain.reachable_for(plain.allies[0]).size())


func test_thamshaper_footing_counts_from_the_high_ground_both_ways() -> void:
	var plain := _controller(_member(""))
	var shaper := _controller(_member("thamshaper"))
	for controller: CombatController in [plain, shaper]:
		var grid := controller.battlefield as GridBattlefieldModel
		grid.set_elevation(grid.cell_of(controller.allies[0]) as Vector2i, 2)
	var up_plain := _chance(plain)
	var up_shaper := _chance(shaper)
	assert_int(up_shaper).is_equal(up_plain + 4)

	# A foe attacking up at a Thamshaper pays the same term.
	var defended := _controller(_member(""), _member("thamshaper"))
	var open := _controller(_member(""), _member(""))
	for controller: CombatController in [defended, open]:
		var grid := controller.battlefield as GridBattlefieldModel
		grid.set_elevation(grid.cell_of(controller.enemies[0]) as Vector2i, 2)
	assert_int(_chance(defended)).is_equal(_chance(open) - 4)
	assert_str(_labels(defended)).contains("Thamshaper footing (target)")


func test_a_hushwarden_hushes_the_cells_around_them_and_no_further() -> void:
	var controller := _controller(_member("hushwarden"))
	var grid := controller.battlefield as GridBattlefieldModel
	var warden_cell := grid.cell_of(controller.allies[0]) as Vector2i
	assert_bool(bool(controller._tile_context(warden_cell).get("hush", false))).is_true()
	assert_bool(bool(controller._tile_context(warden_cell + Vector2i(1, 0)).get("hush", false))).is_true()
	assert_bool(bool(controller._tile_context(warden_cell + Vector2i(3, 0)).get("hush", false))).is_false()
	# The board's own tile is never written.
	assert_bool(controller.tile_state_at(warden_cell).hush).is_false()
	var plain := _controller(_member(""))
	assert_bool(bool(plain._tile_context(warden_cell).get("hush", false))).is_false()


func test_an_enemy_without_a_member_has_no_discipline() -> void:
	var enemy := BattleActor.new()
	assert_str(DisciplineProfile.of(enemy)).is_empty()
	assert_array(DisciplineProfile.move_cost_modifiers(enemy)).is_empty()
	assert_int(DisciplineProfile.hush_radius(enemy)).is_equal(0)
	for id: String in ["chordblade", "thamshaper", "hushwarden"]:
		assert_str(DisciplineProfile.summary(id)).override_failure_message(id).starts_with("In a fight:")


func _chance(controller: CombatController) -> int:
	var forecast := controller.forecast_action(controller.action_by_id(&"discipline-test"), controller.enemies[0])
	return int(forecast["resolution"]["accuracy_breakdown"]["hit_chance"])


func _labels(controller: CombatController) -> String:
	var forecast := controller.forecast_action(controller.action_by_id(&"discipline-test"), controller.enemies[0])
	var labels: PackedStringArray = []
	for modifier: Dictionary in forecast["resolution"]["accuracy_breakdown"]["modifiers"]:
		labels.append(str(modifier["label"]))
	return " | ".join(labels)


func _member(discipline: String) -> PartyMember:
	var member := PartyMember.new()
	member.id = "discipline-%s" % discipline
	member.discipline = discipline
	return member


func _controller(ally_member: PartyMember, enemy_member: PartyMember = null) -> CombatController:
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
	for x: int in 12:
		ground.set_cell(Vector2i(x, 0), 0, Vector2i.ZERO)
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(ground)
	var action := CombatAction.make(&"discipline-test", "Discipline test", CombatAction.Kind.ATTACK)
	action.ct_cost = 30
	action.target_profile = &"ranged"
	var actions := CombatActionCatalog.all()
	actions.append(action)
	var ally := BattleActor.new()
	ally.display_name = "Discipline ally"
	ally.hp = 200
	ally.max_hp = 200
	ally.attack = 12
	ally.source_member = ally_member
	var enemy := BattleActor.new()
	enemy.display_name = "Discipline target"
	enemy.hp = 200
	enemy.max_hp = 200
	enemy.source_member = enemy_member
	var controller := CombatController.new()
	controller.configure(actions, grid, rules)
	controller.start([ally], [enemy], &"discipline-test")
	return controller
