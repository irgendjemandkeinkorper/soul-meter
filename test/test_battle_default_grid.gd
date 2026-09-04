extends GdUnitTestSuite

## Catalog encounters build their tactical grid from the live field. Ad-hoc
## `start(BattleActor)` scaffold battles stay on the zone model — that plus the
## `"battlefield": "zones"` hatch keeps the FR-105 fallback live end-to-end.

const TEST_ENCOUNTER := &"default-grid-probe-test"
const FIELD_SCENE := preload("res://world/test_room.tscn")

var _field_scene: Node2D
var _field: FieldMap


func before_test() -> void:
	_field_scene = FIELD_SCENE.instantiate() as Node2D
	add_child(_field_scene)
	_field = _field_scene.get_node("FieldMap") as FieldMap
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
	Battle.controller = null
	Battle.allies.clear()
	Battle.enemies.clear()
	Battle._definition.clear()
	Battle._combat_history.clear()
	_field_scene.free()
	_field_scene = null
	_field = null


func test_catalog_start_builds_from_the_live_field_and_deploys_opposing_columns() -> void:
	Battle.start(TEST_ENCOUNTER)

	assert_bool(Battle.controller.battlefield is GridBattlefieldModel).is_true()
	var model: GridBattlefieldModel = Battle.controller.battlefield as GridBattlefieldModel
	assert_object(model._grid).is_same(_field.iso_grid())
	var snapshot: Dictionary = Battle.controller.snapshot()
	var tiles: Array = snapshot.get("tiles", []) as Array
	var used_rect: Rect2i = _field.ground().get_used_rect()
	assert_int(tiles.size()).is_equal(used_rect.size.x * used_rect.size.y)
	var ally_position: Dictionary = Battle.controller.battlefield.describe_position(
		Battle.controller.battlefield.position_of(Battle.allies[0])
	)
	var enemy_position: Dictionary = Battle.controller.battlefield.describe_position(
		Battle.controller.battlefield.position_of(Battle.enemies[0])
	)
	assert_vector(ally_position.get("cell", Vector2i(-1, -1))).is_equal(used_rect.position)
	assert_vector(enemy_position.get("cell", Vector2i(-1, -1))).is_equal(
		Vector2i(used_rect.end.x - 1, used_rect.position.y)
	)


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


func _enemy() -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = "Fallback Grid Target"
	actor.hp = 10
	actor.max_hp = 10
	return actor
