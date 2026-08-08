extends GdUnitTestSuite
## Issue #186 (FR-802, Gate T criterion 8). `GridBattlefieldModel` used to key `_cells`,
## `_sides`, `_facings` and `_occupancy` on `actor.get_instance_id()` — process-local, not
## save-stable, not deterministic across two runs. `BattleActor.combat_id` (assigned by
## `CombatController._assign_combat_ids()` at encounter setup, before the battlefield model is
## built — see `start()`) replaces it. Proves: (1) two runs with identical inputs produce
## identical ids, (2) ids stay unique for two combatants that share BOTH `display_name` and
## `archetype_id`, and (3) `GridBattlefieldModel` actually keys on `combat_id`, not on identity.


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.move_ct_cost = 20
	return rules


func _controller() -> CombatController:
	var controller := CombatController.new()
	var rules := _rules()
	var battlefield := BattlefieldModel.create_default(rules)
	controller.configure(CombatActionCatalog.all(), battlefield, rules)
	return controller


## Two "Bog Wight" enemies (identical display_name and archetype_id) plus one ally, built fresh
## for each run so nothing but the CombatController's own derivation could make the ids agree.
func _fresh_ally() -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = "Ally"
	actor.hp = 10
	actor.max_hp = 10
	actor.attributes = {&"edge": 4}
	return actor


func _fresh_bog_wights() -> Array[BattleActor]:
	var wights: Array[BattleActor] = []
	for i in 2:
		var wight := BattleActor.new()
		wight.display_name = "Bog Wight"
		wight.archetype_id = &"bog-wight"
		wight.hp = 8
		wight.max_hp = 8
		wight.attributes = {&"edge": 2}
		wights.append(wight)
	return wights


func test_combat_ids_are_deterministic_across_two_identical_runs() -> void:
	var first_run := _controller()
	var first_ally := _fresh_ally()
	var first_enemies := _fresh_bog_wights()
	first_run.start([first_ally], first_enemies)

	var second_run := _controller()
	var second_ally := _fresh_ally()
	var second_enemies := _fresh_bog_wights()
	second_run.start([second_ally], second_enemies)

	assert_str(String(first_ally.combat_id)).is_equal(String(second_ally.combat_id))
	assert_str(String(first_enemies[0].combat_id)).is_equal(String(second_enemies[0].combat_id))
	assert_str(String(first_enemies[1].combat_id)).is_equal(String(second_enemies[1].combat_id))
	# The two enemy slots within a single run must still differ from each other.
	assert_str(String(first_enemies[0].combat_id)).is_not_equal(String(first_enemies[1].combat_id))


func test_combat_ids_are_unique_for_actors_sharing_display_name_and_archetype() -> void:
	var controller := _controller()
	var ally := _fresh_ally()
	var enemies := _fresh_bog_wights()

	controller.start([ally], enemies)

	assert_str(String(enemies[0].display_name)).is_equal(String(enemies[1].display_name))
	assert_str(String(enemies[0].archetype_id)).is_equal(String(enemies[1].archetype_id))
	assert_bool(enemies[0].combat_id.is_empty()).is_false()
	assert_bool(enemies[1].combat_id.is_empty()).is_false()
	assert_str(String(enemies[0].combat_id)).is_not_equal(String(enemies[1].combat_id))


func test_combat_ids_are_not_derived_from_instance_id() -> void:
	var controller := _controller()
	var ally := _fresh_ally()
	var enemies := _fresh_bog_wights()

	controller.start([ally], enemies)

	for actor: BattleActor in [ally, enemies[0], enemies[1]]:
		assert_bool(String(actor.combat_id).contains(str(actor.get_instance_id()))).is_false()


# ---- GridBattlefieldModel actually keys on combat_id, not on identity ----


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
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	for y in height:
		for x in width:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	return layer


func test_grid_battlefield_model_does_not_collide_actors_sharing_name_and_archetype() -> void:
	var rules := _rules()
	var model := GridBattlefieldModel.new()
	model.configure(rules)
	model.build_grid(_ground(5, 3))
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), model, rules)
	var ally := _fresh_ally()
	var enemies := _fresh_bog_wights()

	controller.start([ally], enemies)

	assert_bool(model.has_combatant(enemies[0])).is_true()
	assert_bool(model.has_combatant(enemies[1])).is_true()
	assert_object(model.occupant_of(model.position_of(enemies[0]))).is_same(enemies[0])
	assert_object(model.occupant_of(model.position_of(enemies[1]))).is_same(enemies[1])
	assert_str(String(model.position_of(enemies[0]))).is_not_equal(
		String(model.position_of(enemies[1]))
	)
