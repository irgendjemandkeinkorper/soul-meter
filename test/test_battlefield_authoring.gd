extends GdUnitTestSuite

## Wave R characterization for provisional per-encounter boards. These tests keep
## authoring data honest without changing the frozen battlefield/stage contract.

const TEST_ENCOUNTER := &"wave-r-authored-grid-test"

var _original_party: Array[PartyMember] = []


func before_test() -> void:
	_original_party.assign(GameState.party)
	_set_full_party()
	# Load the generated catalog before injecting a test-only definition.
	EncounterCatalog.definition(&"bog-wight")


func after_test() -> void:
	EncounterCatalog._definitions.erase(String(TEST_ENCOUNTER))
	_cleanup_battle()
	GameState.party.clear()
	GameState.party.assign(_original_party)


func test_authored_terrain_is_applied_clamped_and_malformed_cells_are_skipped() -> void:
	EncounterCatalog._definitions[String(TEST_ENCOUNTER)] = {
		"display_name": "Wave R Authored Grid Probe",
		"grid": {
			"dimensions": Vector2i(7, 5),
			"cover": [Vector2i(2, 2), Vector2i(8, 2), "bad-cover-cell"],
			"elevation": {
				Vector2i(3, 1): 2,
				Vector2i(4, 2): 99,
				Vector2i(-1, 1): 1,
				Vector2i(3, 3): "high",
				"bad-elevation-cell": 1,
			},
		},
		"enemies": [_enemy_row()],
	}

	await assert_error(Battle.start.bind(TEST_ENCOUNTER)).is_push_warning(
		"Encounter 'wave-r-authored-grid-test' cover cell (8, 2) is outside its 7x5 grid; skipping."
	)

	var model := Battle.controller.battlefield as GridBattlefieldModel
	assert_object(model).is_not_null()
	assert_bool(bool(_tile_at(model.tiles_snapshot(), Vector2i(2, 2)).get("cover", false))).is_true()
	assert_int(int(_tile_at(model.tiles_snapshot(), Vector2i(3, 1)).get("height_delta", -1))).is_equal(2)
	assert_int(int(_tile_at(model.tiles_snapshot(), Vector2i(4, 2)).get("height_delta", -1))).is_equal(DS.ELEVATION_MAX)
	assert_int(model.elevation_at(Vector2i(-1, 1))).is_equal(0)
	assert_dict(_tile_at(model.tiles_snapshot(), Vector2i(8, 2))).is_empty()


func test_every_catalog_encounter_fits_and_deploys_a_full_party() -> void:
	var encounter_ids: Array = EncounterCatalog._definitions.keys()
	encounter_ids.sort()
	assert_int(encounter_ids.size()).is_equal(12)

	for encounter_key: Variant in encounter_ids:
		_cleanup_battle()
		var authored_id := StringName(str(encounter_key))
		Battle.start(authored_id)

		assert_bool(Battle.controller.battlefield is GridBattlefieldModel).override_failure_message(
			"%s did not start on a grid" % authored_id
		).is_true()
		var model := Battle.controller.battlefield as GridBattlefieldModel
		assert_bool(model.tiles_snapshot().is_empty()).override_failure_message(
			"%s produced no battlefield tiles" % authored_id
		).is_false()
		assert_int(Battle.allies.size()).override_failure_message(
			"%s did not deploy all five allies" % authored_id
		).is_equal(5)

		var occupied: Dictionary = {}
		for actor: BattleActor in Battle.allies + Battle.enemies:
			var position: Dictionary = model.describe_position(model.position_of(actor))
			var cell: Vector2i = position.get("cell", Vector2i(-1, -1))
			assert_bool(cell.x >= 0 and cell.y >= 0).override_failure_message(
				"%s failed to place %s" % [authored_id, actor.display_name]
			).is_true()
			assert_bool(occupied.has(cell)).override_failure_message(
				"%s placed multiple combatants at %s" % [authored_id, cell]
			).is_false()
			occupied[cell] = true
		assert_int(occupied.size()).is_equal(Battle.allies.size() + Battle.enemies.size())


func test_authored_terrain_keeps_both_deployment_columns_clear() -> void:
	assert_int(EncounterCatalog._FIELD_GRID_DATA.size()).is_equal(12)
	for encounter_key: Variant in EncounterCatalog._FIELD_GRID_DATA:
		var grid: Dictionary = EncounterCatalog._FIELD_GRID_DATA[encounter_key]
		var dimensions: Vector2i = grid.get("dimensions", Vector2i.ZERO)
		assert_bool(dimensions.x >= 7 and dimensions.x <= 9).is_true()
		assert_bool(dimensions.y >= 5 and dimensions.y <= 6).is_true()
		# Gate r1 risk closure: battle.gd warn-skips malformed/out-of-bounds
		# authored cells at runtime, so a catalog typo would otherwise ship
		# silently — enforce the full data invariants here instead.
		var seen_cover: Dictionary = {}
		for cell: Variant in grid.get("cover", []):
			assert_bool(cell is Vector2i).is_true()
			if cell is Vector2i:
				assert_bool(cell.x == 0 or cell.x == dimensions.x - 1).override_failure_message(
					"%s authors cover in deployment column at %s" % [encounter_key, cell]
				).is_false()
				assert_bool(
					cell.x >= 0 and cell.y >= 0 and cell.x < dimensions.x and cell.y < dimensions.y
				).override_failure_message(
					"%s authors cover outside its board at %s" % [encounter_key, cell]
				).is_true()
				assert_bool(seen_cover.has(cell)).override_failure_message(
					"%s authors duplicate cover at %s" % [encounter_key, cell]
				).is_false()
				seen_cover[cell] = true
		var elevation: Dictionary = grid.get("elevation", {})
		for cell: Variant in elevation:
			assert_bool(cell is Vector2i).is_true()
			if cell is Vector2i:
				assert_bool(cell.x == 0 or cell.x == dimensions.x - 1).override_failure_message(
					"%s authors elevation in deployment column at %s" % [encounter_key, cell]
				).is_false()
				assert_bool(
					cell.x >= 0 and cell.y >= 0 and cell.x < dimensions.x and cell.y < dimensions.y
				).override_failure_message(
					"%s authors elevation outside its board at %s" % [encounter_key, cell]
				).is_true()
				var authored_height: int = int(elevation[cell])
				assert_bool(
					authored_height >= 1 and authored_height <= DS.ELEVATION_MAX
				).override_failure_message(
					"%s authors elevation %d at %s (must be 1..%d)"
					% [encounter_key, authored_height, cell, DS.ELEVATION_MAX]
				).is_true()


func test_weather_defaults_are_valid_wheel_ids_and_start_without_warnings() -> void:
	assert_bool(EncounterCatalog._WEATHER_DEFAULTS.size() >= 2).is_true()
	assert_bool(EncounterCatalog._WEATHER_DEFAULTS.size() <= 3).is_true()
	for encounter_key: Variant in EncounterCatalog._WEATHER_DEFAULTS:
		_cleanup_battle()
		var authored_id := StringName(str(encounter_key))
		var expected_element := str(EncounterCatalog._WEATHER_DEFAULTS[encounter_key])

		await assert_error(Battle.start.bind(authored_id)).is_success()

		var snapshot: Dictionary = Battle.controller.snapshot()
		var weather: Dictionary = snapshot.get("weather", {})
		assert_str(str(weather.get("element_id", ""))).is_equal(expected_element)


## Gate r1 residual closure: play a REAL authored board end-to-end — legal
## movement (the same move_query/submit path the pointer uses) closing the
## deployment gap into melee, then strikes to victory. bog-wight also carries
## the authored molm weather, so the live weather path is exercised too.
func test_bog_wight_board_supports_movement_into_melee_victory() -> void:
	Battle.start(&"bog-wight")
	assert_bool(Battle.controller.battlefield is GridBattlefieldModel).is_true()
	Battle.enemies[0].hp = 1

	var actions_taken := 0
	while not Battle.ended and actions_taken < 200:
		actions_taken += 1
		if Battle.use_action(&"strike"):
			continue
		if _step_active_ally_toward(Battle.enemies[0]):
			continue
		Battle.end_turn()

	assert_bool(Battle.ended).override_failure_message(
		"battle did not resolve within 200 actions on the authored bog-wight board"
	).is_true()
	assert_str(String(Battle.last_result.outcome_id)).is_equal("slain")


## Moves the active ally one legal move toward the target using the controller's
## movement snapshot (the pointer UI's own data). Returns false when no reachable
## destination closes the distance, so the caller ends the turn instead.
func _step_active_ally_toward(target: BattleActor) -> bool:
	var snapshot: Dictionary = Battle.controller.snapshot()
	var movement: Dictionary = snapshot.get("movement", {})
	var reachable: Array = movement.get("reachable", [])
	if reachable.is_empty():
		return false
	var model := Battle.controller.battlefield as GridBattlefieldModel
	var target_position: Dictionary = model.describe_position(model.position_of(target))
	var target_cell: Vector2i = target_position.get("cell", Vector2i.ZERO)
	var ally: BattleActor = Battle.current_ally()
	if ally == null:
		return false
	var current_position: Dictionary = model.describe_position(model.position_of(ally))
	var current_cell: Vector2i = current_position.get("cell", Vector2i.ZERO)
	var current_distance: int = (
		absi(current_cell.x - target_cell.x) + absi(current_cell.y - target_cell.y)
	)
	var best_destination: StringName = &""
	var best_distance: int = current_distance
	for entry: Variant in reachable:
		var destination: StringName = (entry as Dictionary).get("destination", &"")
		var described: Dictionary = model.describe_position(destination)
		var cell: Vector2i = described.get("cell", Vector2i.ZERO)
		var distance: int = absi(cell.x - target_cell.x) + absi(cell.y - target_cell.y)
		if distance < best_distance:
			best_distance = distance
			best_destination = destination
	if best_destination == &"":
		return false
	return Battle.use_action(&"move", -1, {"destination": best_destination})


func _set_full_party() -> void:
	GameState.party.clear()
	for index: int in 5:
		var member := PartyMember.new()
		member.display_name = "Wave R Ally %d" % (index + 1)
		member.hp = 40
		member.max_hp = 40
		member.attack = 5
		member.defense = 2
		GameState.party.append(member)


func _cleanup_battle() -> void:
	Battle._release_battlefield_ground()
	Battle.controller = null
	Battle.allies.clear()
	Battle.enemies.clear()
	Battle._definition.clear()
	Battle._combat_history.clear()


func _enemy_row() -> Dictionary:
	return {
		"id": "wave-r-authored-grid-target",
		"display_name": "Wave R Target",
		"max_hp": 10,
		"attack": 1,
		"defense": 0,
	}


func _tile_at(tiles: Array[Dictionary], cell: Vector2i) -> Dictionary:
	for tile: Dictionary in tiles:
		if int(tile.get("x", -1)) == cell.x and int(tile.get("y", -1)) == cell.y:
			return tile
	return {}
