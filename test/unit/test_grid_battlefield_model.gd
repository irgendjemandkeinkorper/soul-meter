extends GdUnitTestSuite
## FR-105a grid seam (issue #137, architecture doc §1.6, amendment §2.1/§2.3).
##
## Proves GridBattlefieldModel: owns one IsoGrid, flood-fills movement range bounded by CT
## budget, scales elevation as path weight while keeping cliffs strictly impassable, updates
## occupancy after move/death, and separates the three line_of_sight refusal reasons FR-606
## requires (blocked_by_elevation / blocked_by_occupancy / blocked_by_range — never a single
## &"no_los"). No test here authors grid content; the grids built below exist only to exercise
## the model's mechanism (amendment §8.1).


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.move_ct_cost = 20
	return rules


func _actor(id: String) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = id
	actor.combat_id = StringName(id)
	actor.hp = 10
	actor.max_hp = 10
	actor.attributes = {&"edge": 4}
	return actor


## Builds a bare ground TileMapLayer in code (no scene, no authored content) so the model has
## an IsoGrid to own. width x height cells, all passable until a test marks otherwise.
func _ground(width: int, height: int) -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i(0, 0))
	tile_set.add_source(source, 0)
	# auto_free() so the fixture does not leak. TileMapLayer is a Node: without
	# this each test leaves an orphan, invisible in a single-suite run and only
	# visible as a rising orphan count across the full suite.
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	for y in height:
		for x in width:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	return layer


func _model(width: int, height: int) -> GridBattlefieldModel:
	var model := GridBattlefieldModel.new()
	model.configure(_rules())
	model.build_grid(_ground(width, height))
	return model


func _handle(x: int, y: int, elevation: int = 0) -> StringName:
	return StringName("c:%d,%d,%d" % [x, y, elevation])


# ---- opaque handles, capabilities, describe_position ----


func test_capabilities_report_full_spatial_support() -> void:
	var caps := _model(4, 4).capabilities()
	assert_bool(caps.get("cells", false)).is_true()
	assert_bool(caps.get("elevation", false)).is_true()
	assert_bool(caps.get("facing", false)).is_true()
	assert_bool(caps.get("occupancy", false)).is_true()
	assert_bool(caps.get("line_of_sight", false)).is_true()
	assert_bool(caps.get("path_cost", false)).is_true()


func test_describe_position_reports_cell_and_elevation() -> void:
	var model := _model(4, 4)
	model.set_elevation(Vector2i(2, 1), 3)
	var described := model.describe_position(_handle(2, 1, 3))
	assert_str(String(described.get("kind", &""))).is_equal("cell")
	assert_vector(described.get("cell", Vector2i(-9, -9))).is_equal(Vector2i(2, 1))
	assert_int(described.get("elevation", -1)).is_equal(3)


func test_describe_position_rejects_malformed_handle() -> void:
	assert_dict(_model(4, 4).describe_position(&"front")).is_empty()


# ---- composition parity with the zone model's contract ----


func test_setup_places_allies_and_enemies_on_opposite_columns() -> void:
	var model := _model(5, 3)
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	model.setup(allies, enemies)

	assert_bool(model.has_combatant(ally)).is_true()
	assert_str(String(model.side_of(ally))).is_equal("ally")
	assert_str(String(model.side_of(enemy))).is_equal("enemy")
	assert_object(model.occupant_of(model.position_of(ally))).is_same(ally)
	assert_object(model.occupant_of(model.position_of(enemy))).is_same(enemy)
	assert_object(model.occupant_of(model.position_of(ally))).is_not_same(enemy)


func test_remove_combatant_frees_occupancy() -> void:
	var model := _model(4, 4)
	var ally := _actor("ally")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = []
	model.setup(allies, enemies)
	var position := model.position_of(ally)

	var result := model.remove_combatant(ally)

	assert_bool(result.get("allowed", false)).is_true()
	assert_bool(model.has_combatant(ally)).is_false()
	assert_object(model.occupant_of(position)).is_null()


func test_transfer_combatant_changes_side_not_position() -> void:
	var model := _model(4, 4)
	var ally := _actor("ally")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = []
	model.setup(allies, enemies)
	var before := model.position_of(ally)

	var result := model.transfer_combatant(ally, GridBattlefieldModel.ENEMY)

	assert_bool(result.get("allowed", false)).is_true()
	assert_str(String(model.side_of(ally))).is_equal("enemy")
	assert_str(String(model.position_of(ally))).is_equal(String(before))


func test_target_query_self_profile_only_allows_self() -> void:
	var model := _model(4, 4)
	var ally := _actor("ally")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = []
	model.setup(allies, enemies)

	assert_bool(model.target_query(ally, ally, &"self").get("allowed", false)).is_true()


func test_target_query_melee_requires_adjacency() -> void:
	var model := _model(6, 1)
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	model.setup(allies, enemies)  # ally at (0,0), enemy at (5,0): far apart

	var result := model.target_query(ally, enemy, &"melee")

	assert_bool(result.get("allowed", true)).is_false()
	assert_str(String(result.get("blocked_by", &""))).is_equal("position")

	model.move(ally, _handle(4, 0))  # now adjacent to enemy at (5,0)
	assert_bool(model.target_query(ally, enemy, &"melee").get("allowed", false)).is_true()


func test_target_query_melee_refuses_height_beyond_jump() -> void:
	var model := _model(2, 1)
	model.set_elevation(Vector2i(1, 0), 2)
	var ally := _actor("ally")
	ally.attributes[&"jump"] = 1
	var enemy := _actor("enemy")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	model.setup(allies, enemies)

	var result := model.target_query(ally, enemy, &"melee")

	assert_bool(result.get("allowed", true)).is_false()
	assert_str(String(result.get("blocked_by", &""))).is_equal("blocked_by_elevation")


func test_target_query_ranged_ignores_distance() -> void:
	var model := _model(6, 1)
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	model.setup(allies, enemies)

	assert_bool(model.target_query(ally, enemy, &"ranged").get("allowed", false)).is_true()


func test_target_query_ranged_requires_line_of_sight_clearance() -> void:
	var model := _model(5, 1)
	model.set_elevation(Vector2i(2, 0), 10)
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	model.setup(allies, enemies)

	var result := model.target_query(ally, enemy, &"ranged")

	assert_bool(result.get("allowed", true)).is_false()
	assert_str(String(result.get("blocked_by", &""))).is_equal("blocked_by_elevation")


# ---- movement range: flood fill bounded by CT budget ----


func test_reachable_positions_excludes_cells_beyond_budget() -> void:
	var model := _model(10, 1)
	var ally := _actor("ally")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = []
	model.setup(allies, enemies)  # ally at (0,0)

	var reachable := model.reachable_positions(ally, 20)  # exactly one 20-CT step

	assert_array(reachable).contains(_handle(1, 0))
	assert_bool(reachable.has(_handle(2, 0))).is_false()


func test_reachable_positions_grows_with_larger_budget() -> void:
	var model := _model(10, 1)
	var ally := _actor("ally")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = []
	model.setup(allies, enemies)

	var small := model.reachable_positions(ally, 20)
	var large := model.reachable_positions(ally, 60)

	assert_int(large.size()).is_greater(small.size())
	assert_bool(large.has(_handle(3, 0))).is_true()


# ---- elevation scales cost; cliffs are impassable, not merely expensive ----


func test_elevation_increases_path_ct_cost() -> void:
	var flat_model := _model(3, 1)
	var flat_ally := _actor("ally")
	var flat_allies: Array[BattleActor] = [flat_ally]
	var no_enemies: Array[BattleActor] = []
	flat_model.setup(flat_allies, no_enemies)
	var flat_cost := int(flat_model.path_query(flat_ally, _handle(1, 0)).get("ct_cost", 0))

	var hill_model := _model(3, 1)
	hill_model.set_elevation(Vector2i(1, 0), 4)
	var hill_ally := _actor("ally")
	var hill_allies: Array[BattleActor] = [hill_ally]
	hill_model.setup(hill_allies, no_enemies)
	var hill_query := hill_model.path_query(hill_ally, _handle(1, 0, 4))
	var hill_cost := int(hill_query.get("ct_cost", 0))

	assert_bool(hill_query.get("allowed", false)).is_true()
	assert_int(hill_cost).is_greater(flat_cost)


func test_cliff_is_impassable_not_merely_expensive() -> void:
	var model := _model(3, 1)
	model.set_cliff(Vector2i(1, 0), true)
	var ally := _actor("ally")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = []
	model.setup(allies, enemies)

	var query := model.path_query(ally, _handle(1, 0))
	assert_bool(query.get("allowed", true)).is_false()

	# Even a lavish budget must not reach a cliff cell, and must not reach past it either
	# (the model can only route around, and there is no way around on a 1-row strip).
	var reachable := model.reachable_positions(ally, 1000)
	assert_bool(reachable.has(_handle(1, 0))).is_false()
	assert_bool(reachable.has(_handle(2, 0))).is_false()


# ---- occupancy updates after each move and each death ----


func test_occupancy_updates_after_move() -> void:
	var model := _model(4, 1)
	var ally := _actor("ally")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = []
	model.setup(allies, enemies)
	var origin := model.position_of(ally)

	var result := model.move(ally, _handle(1, 0))

	assert_bool(result.get("allowed", false)).is_true()
	assert_object(model.occupant_of(origin)).is_null()
	assert_object(model.occupant_of(_handle(1, 0))).is_same(ally)


func test_occupancy_frees_after_death_via_remove_combatant() -> void:
	var model := _model(4, 1)
	var ally := _actor("ally")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = []
	model.setup(allies, enemies)
	var position := model.position_of(ally)
	ally.hp = 0  # dies

	model.remove_combatant(ally)

	assert_object(model.occupant_of(position)).is_null()
	# The vacated cell is passable again for a fresh occupant.
	var other := _actor("other")
	var only_other: Array[BattleActor] = [other]
	var no_enemies: Array[BattleActor] = []
	model.setup(only_other, no_enemies)
	assert_bool(model.has_combatant(other)).is_true()


# ---- line of sight: three distinct refusal reasons, never a bare "no_los" ----


func test_line_of_sight_blocked_by_range() -> void:
	var model := _model(40, 1)
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	model.setup(allies, enemies)  # far corners of a wide strip

	var result := model.line_of_sight(ally, enemy)

	assert_bool(result.get("allowed", true)).is_false()
	assert_str(String(result.get("blocked_by", &""))).is_equal("blocked_by_range")


func test_line_of_sight_blocked_by_elevation() -> void:
	var model := _model(5, 1)
	model.set_elevation(Vector2i(2, 0), 10)  # a ridge between actor and target
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	model.setup(allies, enemies)  # ally (0,0), enemy (4,0), ridge at (2,0)

	var result := model.line_of_sight(ally, enemy)

	assert_bool(result.get("allowed", true)).is_false()
	assert_str(String(result.get("blocked_by", &""))).is_equal("blocked_by_elevation")


func test_line_of_sight_blocked_by_occupancy_at_equal_height() -> void:
	var model := _model(5, 2)  # two rows so ally and bystander get distinct starting cells
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	var bystander := _actor("bystander")
	var allies: Array[BattleActor] = [ally, bystander]
	var enemies: Array[BattleActor] = [enemy]
	model.setup(allies, enemies)  # ally (0,0), bystander (0,1)... reposition bystander onto the line
	model.move(bystander, _handle(2, 0))  # now stands between ally (0,0) and enemy (4,0)

	var result := model.line_of_sight(ally, enemy)

	assert_bool(result.get("allowed", true)).is_false()
	assert_str(String(result.get("blocked_by", &""))).is_equal("blocked_by_occupancy")


func test_line_of_sight_from_high_ground_sees_over_low_cover() -> void:
	var model := _model(5, 2)  # two rows so ally and bystander get distinct starting cells
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	var bystander := _actor("bystander")
	var allies: Array[BattleActor] = [ally, bystander]
	var enemies: Array[BattleActor] = [enemy]
	model.setup(allies, enemies)
	model.set_elevation(Vector2i(0, 0), 5)  # ally's own cell is high ground
	model.move(bystander, _handle(2, 0))  # low cover between ally and enemy, elevation 0

	var result := model.line_of_sight(ally, enemy)

	assert_bool(result.get("allowed", false)).is_true()


func test_line_of_sight_allowed_on_open_flat_ground() -> void:
	var model := _model(4, 1)
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	model.setup(allies, enemies)

	assert_bool(model.line_of_sight(ally, enemy).get("allowed", false)).is_true()


# ---- elevation_delta, facing ----


func test_elevation_delta_is_target_minus_actor() -> void:
	var model := _model(3, 1)
	model.set_elevation(Vector2i(1, 0), 6)
	var ally := _actor("ally")
	var enemy := _actor("enemy")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = [enemy]
	model.setup(allies, enemies)
	model.move(enemy, _handle(1, 0, 6))

	assert_int(model.elevation_delta(ally, enemy)).is_equal(6)
	assert_int(model.elevation_delta(enemy, ally)).is_equal(-6)


func test_set_facing_rejects_unknown_direction() -> void:
	var model := _model(3, 1)
	var ally := _actor("ally")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = []
	model.setup(allies, enemies)

	var result := model.set_facing(ally, &"up")

	assert_bool(result.get("allowed", true)).is_false()
	assert_str(String(result.get("blocked_by", &""))).is_equal("facing")


func test_set_facing_accepts_a_valid_direction() -> void:
	var model := _model(3, 1)
	var ally := _actor("ally")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = []
	model.setup(allies, enemies)

	var result := model.set_facing(ally, &"n")

	assert_bool(result.get("allowed", false)).is_true()
	assert_str(String(model.facing_of(ally))).is_equal("n")


# ---- determinism: no RNG, equal-cost paths resolve the same way every time ----


func test_path_query_is_deterministic_across_repeated_calls() -> void:
	var model := _model(6, 6)
	var ally := _actor("ally")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = []
	model.setup(allies, enemies)

	var first := model.path_query(ally, _handle(4, 4))
	var second := model.path_query(ally, _handle(4, 4))

	assert_array(first.get("path", [])).is_equal(second.get("path", []))
	assert_int(first.get("ct_cost", -1)).is_equal(second.get("ct_cost", -2))


func test_reachable_positions_is_deterministic_across_repeated_calls() -> void:
	var model := _model(6, 6)
	var ally := _actor("ally")
	var allies: Array[BattleActor] = [ally]
	var enemies: Array[BattleActor] = []
	model.setup(allies, enemies)

	var first := model.reachable_positions(ally, 60)
	var second := model.reachable_positions(ally, 60)

	assert_array(first).is_equal(second)
