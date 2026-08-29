extends GdUnitTestSuite

## Catalog encounters synthesize a default tactical grid when they author none
## (owner ruling, 2026-08-29). Ad-hoc `start(BattleActor)` scaffold battles stay
## on the zone model — that plus the `"battlefield": "zones"` hatch keeps the
## FR-105 zone fallback live end-to-end.

const TEST_ENCOUNTER := &"default-grid-probe-test"


func before_test() -> void:
	EncounterCatalog._definitions[String(TEST_ENCOUNTER)] = {
		"display_name": "Default Grid Probe",
		"enemies": [
			{
				"id": "default-grid-probe",
				"display_name": "Fallback Grid Target",
				"max_hp": 10,
				"attack": 1,
				"defense": 0,
			},
		],
	}


func after_test() -> void:
	EncounterCatalog._definitions.erase(String(TEST_ENCOUNTER))
	Battle._release_battlefield_ground()
	Battle.controller = null
	Battle.allies.clear()
	Battle.enemies.clear()
	Battle._definition.clear()
	Battle._combat_history.clear()


func test_catalog_start_without_authored_grid_builds_default_grid_and_deploys_opposing_columns() -> void:
	Battle.start(TEST_ENCOUNTER)

	assert_bool(Battle.controller.battlefield is GridBattlefieldModel).is_true()
	var snapshot: Dictionary = Battle.controller.snapshot()
	var tiles: Array = snapshot.get("tiles", []) as Array
	assert_int(tiles.size()).is_equal(35)
	var ally_position: Dictionary = Battle.controller.battlefield.describe_position(
		Battle.controller.battlefield.position_of(Battle.allies[0])
	)
	var enemy_position: Dictionary = Battle.controller.battlefield.describe_position(
		Battle.controller.battlefield.position_of(Battle.enemies[0])
	)
	assert_vector(ally_position.get("cell", Vector2i(-1, -1))).is_equal(Vector2i(0, 0))
	assert_vector(enemy_position.get("cell", Vector2i(-1, -1))).is_equal(Vector2i(6, 0))


func test_stage_renders_tiles_from_replayed_production_start_event() -> void:
	var runner := scene_runner("res://ui/hud/regions/stage/battle_stage_region.tscn")
	var stage := runner.scene() as BattleStageRegion
	Battle.start(TEST_ENCOUNTER)

	Battle.replay_combat_events(stage.consume_event)
	await runner.simulate_frames(1)

	assert_int(stage.rendered_tile_count()).is_greater(0)


func test_ad_hoc_actor_start_stays_on_the_zone_model() -> void:
	Battle.start(_enemy())

	assert_bool(Battle.controller.battlefield is GridBattlefieldModel).is_false()
	var snapshot: Dictionary = Battle.controller.snapshot()
	var tiles: Array = snapshot.get("tiles", []) as Array
	assert_int(tiles.size()).is_equal(0)


func test_explicit_zone_battlefield_keeps_zone_model_reachable() -> void:
	Battle.allies.append(BattleActor.new())
	Battle.enemies.append(_enemy())
	Battle._definition = {"battlefield": "zones"}

	var model: BattlefieldModel = Battle._battlefield_for_definition(CombatRules.new())

	assert_bool(model is GridBattlefieldModel).is_false()
	assert_bool(bool(model.capabilities().get("cells", false))).is_false()


func test_authored_grid_dimensions_win_over_default() -> void:
	Battle.allies.append(BattleActor.new())
	Battle.enemies.append(_enemy())
	Battle._definition = {"grid": {"dimensions": Vector2i(9, 6)}}

	var model: BattlefieldModel = Battle._battlefield_for_definition(CombatRules.new())

	assert_bool(model is GridBattlefieldModel).is_true()
	assert_int(model.tiles_snapshot().size()).is_equal(54)


func test_empty_and_invalid_grids_fall_back_to_default_dimensions() -> void:
	Battle.allies.append(BattleActor.new())
	Battle.enemies.append(_enemy())
	var definitions: Array[Dictionary] = [
		{"grid": {}},
		{"grid": {"dimensions": "7x5"}},
		{"grid": {"dimensions": Vector2i(1, 1)}},
	]
	for definition: Dictionary in definitions:
		Battle._release_battlefield_ground()
		Battle._definition = definition
		var model: BattlefieldModel = Battle._battlefield_for_definition(CombatRules.new())
		assert_bool(model is GridBattlefieldModel).is_true()
		assert_int(model.tiles_snapshot().size()).is_equal(35)


func test_default_grid_height_grows_to_fit_the_larger_combatant_side() -> void:
	Battle.allies.append(BattleActor.new())
	for index: int in 6:
		Battle.enemies.append(_enemy())
	Battle._definition = {"display_name": "Default Grid Probe"}

	var model: BattlefieldModel = Battle._battlefield_for_definition(CombatRules.new())
	model.setup(Battle.allies, Battle.enemies)

	assert_int(model.tiles_snapshot().size()).is_equal(42)
	var final_enemy_position: Dictionary = model.describe_position(
		model.position_of(Battle.enemies[5])
	)
	assert_vector(final_enemy_position.get("cell", Vector2i(-1, -1))).is_equal(Vector2i(6, 5))


func _enemy() -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = "Fallback Grid Target"
	actor.hp = 10
	actor.max_hp = 10
	return actor
