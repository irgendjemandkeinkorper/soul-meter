extends GdUnitTestSuite


## This suite calls Battle.start() five times and had no teardown, so it left a
## LIVE global Battle (controller set, ended false) behind for every suite that
## ran after it. That went unnoticed until Combat Lab added a guard that reads
## exactly that predicate. Mirrors the teardown idiom in test_travel_flow and
## test_region_map: there is no Battle.abandon(), and flee() would run the
## production flee path.
func after_test() -> void:
	Battle.controller = null
	Battle.ended = true


func test_chart_routes_enter_battle_through_all_four_deployment_states() -> void:
	var chart := FileAccess.get_file_as_string("res://ui/flow/game_flow.tscn")
	for state: String in ["DeploymentSlate", "DeploymentAttune", "DeploymentLoadout", "DeploymentPlace"]:
		assert_str(chart).contains("name=\"%s\"" % state)
	assert_str(chart).contains("event = &\"enter_battle\"")
	assert_str(chart).contains("event = &\"accept_slate\"")
	assert_str(chart).not_contains("change_scene_to_file")


func test_deployment_screen_has_ordered_steps_and_final_accept_copy() -> void:
	var runner := scene_runner("res://ui/screens/deployment/deployment.tscn")
	var deployment := runner.scene() as DeploymentScreen
	for step: int in DeploymentScreen.Step.values():
		deployment.configure_step(step)
		assert_int(deployment.current_step).is_equal(step)
	deployment.configure_step(DeploymentScreen.Step.PLACE)
	assert_str((runner.find_child("Advance", true, false) as Button).text).is_equal("ACCEPT THE SLATE")


func test_production_field_encounters_build_grid_battlefields() -> void:
	for encounter_id: StringName in [EncounterIds.BOG_WIGHT, EncounterIds.LOAM_BOAR]:
		Battle.start(encounter_id)
		assert_bool(Battle.controller.battlefield is GridBattlefieldModel)\
			.override_failure_message("%s did not build a grid battlefield" % encounter_id).is_true()
		assert_bool(bool(Battle.controller.battlefield.capabilities().get("cells", false))).is_true()
		assert_str(String(Battle.controller.battlefield.position_of(Battle.current_ally()))).is_not_empty()
		assert_bool(Battle.controller.rules.use_charge_time)\
			.override_failure_message("%s unexpectedly changed from the AP fallback" % encounter_id)\
			.is_false()


func test_gate_t1_encounters_use_grid_and_ap_scheduler_in_production() -> void:
	var encounter_ids: Array[StringName] = [
		EncounterIds.PHASE2_DEMON,
		EncounterIds.PHASE2_UNDEAD,
		EncounterIds.PHASE2_MIXED_WHIPSAW,
		EncounterIds.PHASE2_SPEECH_WINNABLE,
		EncounterIds.PHASE2_STABILIZER_SHOWCASE,
	]
	for encounter_id: StringName in encounter_ids:
		Battle.start(encounter_id)
		assert_bool(Battle.controller.battlefield is GridBattlefieldModel)\
			.override_failure_message("%s did not build a grid battlefield" % encounter_id).is_true()
		# Gate-T criterion 10 amendment (docs/fallout2-adoption-spec.md Wave 1): AP is the
		# shipped default for every encounter; the five CT overrides were removed with
		# balance evidence (docs/qa/wave1-ap-balance-evidence.md).
		assert_bool(Battle.controller.rules.use_charge_time)\
			.override_failure_message("%s should run the AP scheduler per the Gate-T c10 amendment" % encounter_id).is_false()


func test_production_encounter_place_writes_a_spawn_position() -> void:
	Battle.start(EncounterIds.BOG_WIGHT)
	GameFlow._on_deployment_entered(DeploymentScreen.Step.PLACE)

	var screen: DeploymentScreen = null
	for child in UIManager.get_children():
		if child is DeploymentScreen:
			screen = child
	assert_object(screen).is_not_null()
	assert_object(screen.battlefield_model).is_same(Battle.controller.battlefield)

	var ally: BattleActor = Battle.current_ally()
	var before: StringName = Battle.controller.battlefield.position_of(ally)
	var options: Array[StringName] = Battle.controller.battlefield.reachable_positions(ally, 100)
	assert_bool(options.is_empty()).is_false()
	var placed: Dictionary = screen.place_unit(options[0], &"e")
	assert_bool(bool(placed.get("allowed", false)))\
		.override_failure_message("place_unit refused: %s" % str(placed.get("blocked_by", ""))).is_true()
	assert_str(String(Battle.controller.battlefield.position_of(ally))).is_not_equal(String(before))

	UIManager.close_all()
	get_tree().paused = false


func test_place_step_receives_the_live_battlefield_and_writes_a_spawn_position() -> void:
	# Mirrors the real order of operations: the Enemy trigger calls Battle.start()
	# BEFORE the chart enters deployment, so the model exists when PLACE opens (#202).
	Battle.start(&"bog-wight")
	assert_bool(Battle.ended).is_false()

	# Keep this as the focused seam test for configure_placement -> place_unit. The production
	# encounter path is covered above; replacing its model here isolates the deployment UI from
	# encounter catalog/build behavior, just as test_wavec_tactical_gates.gd's helper does.
	Battle.controller.battlefield = _grid_model(6, 4)
	Battle.controller.battlefield.setup(Battle.allies, Battle.enemies)

	GameFlow._on_deployment_entered(DeploymentScreen.Step.PLACE)
	var screen: DeploymentScreen = null
	for child in UIManager.get_children():
		if child is DeploymentScreen:
			screen = child
	assert_object(screen).is_not_null()
	assert_object(screen.battlefield_model).is_same(Battle.controller.battlefield)
	assert_object(screen.placement_actor).is_same(Battle.current_ally())

	var ally := Battle.current_ally()
	var before := Battle.controller.battlefield.position_of(ally)
	var options := Battle.controller.battlefield.reachable_positions(ally, 100)
	assert_bool(options.is_empty()).is_false()
	var placed: Dictionary = screen.place_unit(options[0], &"e")
	assert_bool(bool(placed.get("allowed", false)))\
		.override_failure_message("place_unit refused: %s" % str(placed.get("blocked_by", ""))).is_true()
	assert_str(String(Battle.controller.battlefield.position_of(ally))).is_equal(String(options[0]))
	assert_str(String(Battle.controller.battlefield.position_of(ally))).is_not_equal(String(before))

	UIManager.close_all()
	get_tree().paused = false


## Mirrors test/integration/test_wavec_tactical_gates.gd's `_grid_model()` -- a synthetic
## TileMapLayer-backed GridBattlefieldModel, built in code so this suite does not depend on
## a real map scene. See the comment above for why this test builds its own grid rather than
## relying on Battle.start()'s production default.
func _grid_model(width: int, height: int) -> GridBattlefieldModel:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tile_set
	for y in height:
		for x in width:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var model := GridBattlefieldModel.new()
	model.configure(CombatRules.new())
	model.build_grid(ground)
	return model
