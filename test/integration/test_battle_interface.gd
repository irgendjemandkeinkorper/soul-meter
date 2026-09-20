extends GdUnitTestSuite


func test_battle_interface_renders_all_six_regions_from_scripted_state() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var event := CombatEvent.new()
	event.type = &"battle_snapshot"
	event.data = {"snapshot": {
		"active_unit": {"id": "sera", "name": "Sera", "hp": 31, "max_hp": 40, "element_id": "zhur", "ct": 88, "speed": 9, "height": 1, "facing": "ne"},
		"tiles": [{"x": 0, "y": 0, "height_delta": 2, "charge_element_id": "zhur", "charge_level": 2, "element_color": "#7BDFF2"}],
		"weather": {"element_id": "luth", "tick": 7, "gains": "luth", "drains": "khash"},
	}}
	interface.consume_event(event)
	await runner.simulate_frames(1)

	for node_name: String in ["ActiveUnitPlate", "Stage", "WeatherChip", "ActTargetPanel", "TurnTimeline", "HotbarSoulGauge"]:
		assert_object(runner.find_child(node_name, true, false)).is_not_null()
	assert_str((runner.find_child("HP", true, false) as Label).text).contains("31")
	assert_int((runner.find_child("Stage", true, false) as BattleStageRegion).rendered_tile_count()).is_equal(1)
	assert_str((runner.find_child("Value", true, false) as Label).text).contains("LUTH")


func test_region_e_renders_additive_ap_round_snapshot_payload() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var event := CombatEvent.new()
	event.type = &"battle_snapshot"
	event.data = {"snapshot": {
		"scheduler_mode": "ap_round",
		"turn_order": [
			{
				"actor_id": &"ally-0",
				"display_name": "Vex",
				"scheduler_mode": &"ap_round",
				"ap_remaining": 2,
				"max_ap": 4,
				"acted": false,
				"pending": true,
				"active": true,
			},
			{
				"actor_id": &"enemy-0",
				"display_name": "Wight",
				"scheduler_mode": &"ap_round",
				"ap_remaining": 0,
				"max_ap": 3,
				"acted": true,
				"pending": false,
				"active": false,
			},
		],
	}}
	interface.consume_event(event)
	await runner.simulate_frames(1)

	var timeline := runner.find_child("TurnTimeline", true, false) as CTTimelineRegion
	assert_int(timeline.marker_count()).is_equal(2)
	assert_str((timeline.markers.get_child(0) as Label).text).contains("ACTIVE")
	assert_str((timeline.markers.get_child(0) as Label).text).contains("●●○○")
	assert_str((timeline.markers.get_child(1) as Label).text).contains("ACTED")


func test_production_battle_instantiates_the_overlay() -> void:
	var source := FileAccess.get_file_as_string("res://ui/screens/battle.gd")
	assert_str(source).contains("battle_interface.tscn")
	assert_str(source).contains("Battle.combat_event.connect(_battle_interface.consume_event)")


func test_dorthkor_grid_battle_uses_its_authored_environment_background() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var event := CombatEvent.new()
	event.type = &"battle_started"
	event.data = {"snapshot": {
		"encounter_id": &"dorthkor-vanguard",
		"tiles": [{"x": 0, "y": 0, "height_delta": 0}],
		"allies": [{
			"id": &"ally-vex-0",
			"display_name": "Vex",
			"position": Vector2i.ZERO,
			"side": &"ally",
		}],
		"enemies": [{
			"id": &"enemy-gnaal-0",
			"display_name": "Gnaal Breach-Hound",
			"position": Vector2i.ONE,
			"side": &"enemy",
		}],
	}}
	interface.consume_event(event)
	await runner.simulate_frames(1)

	var stage := runner.find_child("Stage", true, false) as BattleStageRegion
	assert_str(stage.background_texture_path()).ends_with(
		"dorthkor-road-battlefield-v1.png"
	)


func test_cast_command_is_visible_and_submits_selected_target_through_interface() -> void:
	var cast := CombatActionCatalog.by_id(&"cast-seam")
	assert_object(cast).is_not_null()
	assert_bool(cast.player_available).is_true()
	assert_bool(cast.requires_enemy_target()).is_true()

	var rules := load("res://data/combat/combat_rules.tres") as CombatRules
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_two_cell_ground())
	var actor := _cast_actor("Caster", 30, 8)
	actor.breath = 2
	var target := _cast_actor("Target", 30, 1)
	var ability := AbilityDefinition.new()
	ability.id = "interface-cast"
	ability.element_id = &"zhur"
	ability.elements = [&"zhur"]
	ability.power = 8
	ability.breath_cost = 1
	actor.source_member = PartyMember.new()
	actor.source_member.id = "interface-caster"
	var tables := TacticalTables.new()
	tables.abilities[ability.id] = ability
	var loadout := UnitLoadout.create(actor.source_member.id)
	loadout.action_ability_ids = PackedStringArray([ability.id])
	tables.loadouts[loadout.unit_id] = loadout
	var controller := CombatController.new()
	controller.configure([cast], grid, rules, null, [ability], tables)
	controller.start([actor], [target], &"interface-cast")
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	interface.bind_controller(controller)
	interface.select_pointer_action(&"cast-seam", ability.id)
	var forecast := controller.forecast_action(cast, target, {"ability_id": ability.id})
	interface.act_target_panel.show_action_forecast(forecast, forecast["context"])
	interface._append_cast_forecast(cast, forecast)
	var forecast_text := interface.act_target_panel.forecast.text
	assert_str(forecast_text).contains(
		"BREATH %d · SOUL %d" % [int(forecast["breath_cost"]), int(forecast["soul_cost"])]
	)
	assert_int(forecast_text.count("FIZZLE")).is_equal(1)
	var hp_before := target.hp

	interface._on_pointer_pressed({"x": 1, "y": 0}, target.combat_id)

	assert_int(target.hp).is_less(hp_before)


func test_aim_row_arms_a_location_and_submits_it_through_the_interface() -> void:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = false
	var grid := GridBattlefieldModel.new()
	grid.configure(rules)
	grid.build_grid(_two_cell_ground())
	var action := CombatAction.make(&"aim-strike", "Aim strike", CombatAction.Kind.ATTACK, 0, 0, 0.0, 1)
	action.ct_cost = 30
	action.aim_profiles = preload("res://globals/combat_lab.gd").AIM_PROFILES.duplicate(true)
	var actor := _cast_actor("Aimer", 30, 8)
	var target := _cast_actor("Mark", 30, 1)
	target.anatomy = {
		"torso": {"display_name": "Torso", "exposed": true},
		"arm": {"display_name": "Shield arm", "exposed": false},
		"throat": {"display_name": "Throat", "exposed": true},
	}
	var controller := CombatController.new()
	var actions := CombatActionCatalog.all()
	actions.append(action)
	controller.configure(actions, grid, rules)
	controller.start([actor], [target], &"interface-aim")
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	interface.bind_controller(controller)
	var snapshot := CombatEvent.new()
	snapshot.type = &"battle_snapshot"
	snapshot.data = {"snapshot": controller.snapshot()}
	interface.consume_event(snapshot)
	await runner.simulate_frames(1)
	var panel := interface.act_target_panel

	# An action without authored aim profiles shows no aim row (strike now authors them,
	# task 11B, so guard is the unaimable control here).
	interface.select_pointer_action(&"guard")
	interface._on_tile_hovered({"x": 1, "y": 0})
	assert_bool(panel.aim_row.visible).is_false()

	# Hovering the mark with the aimed action offers every authored location; the covered
	# arm stays visible but disabled with the controller's reason.
	interface.select_pointer_action(&"aim-strike")
	interface._on_tile_hovered({"x": 1, "y": 0})
	assert_bool(panel.aim_row.visible).is_true()
	assert_int(panel.aim_row.get_child_count()).is_equal(4)
	assert_str(panel.aim_button(&"arm").text).is_equal("SHIELD ARM")
	assert_bool(panel.aim_button(&"arm").disabled).is_true()
	assert_str(panel.aim_button(&"arm").tooltip_text).is_equal("That location is not exposed.")
	assert_bool(panel.aim_button(&"throat").disabled).is_false()
	assert_bool(panel.aim_button(&"").disabled).is_false()
	var ordinary_text := panel.forecast.text
	assert_str(ordinary_text).not_contains("AIM THROAT")

	# Selecting the throat arms the aim and the next hover quotes it: penalty, priced cost,
	# and the (absent) consequence all come from the controller payload.
	panel.aim_button(&"throat").pressed.emit()
	assert_str(String(interface.aim_location())).is_equal("throat")
	interface._on_tile_hovered({"x": 1, "y": 0})
	var aimed := controller.forecast_action(action, target, {"aim_location": "throat"})
	assert_str(panel.forecast.text).contains("Aim: Throat -25 pp")
	var injury_forecast: Dictionary = aimed["injury_forecast"]
	assert_str(panel.forecast.text).contains("AIM THROAT · COST %d AP · INJURY %d%% ON HIT · %d%% OVERALL" % [
		int(aimed["ap_cost"]), int(injury_forecast["chance_on_hit"]), int(injury_forecast["overall_chance"]),
	])
	assert_str(panel.aim_button(&"throat").theme_type_variation).is_equal("BronzeButton")

	# Pressing the mark submits the armed aim and pays the surcharged AP.
	var ap_before := actor.action_points
	interface._on_pointer_pressed({"x": 1, "y": 0}, target.combat_id)
	assert_int(actor.action_points).is_equal(ap_before - int(aimed["ap_cost"]))
	assert_int(int(aimed["ap_cost"])).is_equal(action.ap_cost + 1)

	# A visibility change mid-battle refreshes the forecast panel through the event stream.
	var before_text := panel.forecast.text
	var forecast_clear := panel.forecast_result()
	var visibility_event := CombatEvent.new()
	visibility_event.type = &"visibility_changed"
	visibility_event.data = {
		"forecast_context": controller.forecast_context(actor, target, action, {"aim_location": "throat"}),
	}
	action.target_profile = &"ranged"
	assert_bool(controller.configure_visibility(grid.cell_of(target), &"dim")["allowed"]).is_true()
	visibility_event.data["forecast_context"] = controller.forecast_context(actor, target, action, {"aim_location": "throat"})
	interface.consume_event(visibility_event)
	assert_str(panel.forecast.text).contains("Visibility: dim -10 pp")
	assert_int(int(panel.forecast_result()["accuracy_breakdown"]["hit_chance"])).is_equal(int(forecast_clear["accuracy_breakdown"]["hit_chance"]) - 10)
	assert_str(panel.forecast.text).is_not_equal(before_text)

	# Cancel through the ordinary button, then re-arming a different action clears the row.
	panel.aim_button(&"").pressed.emit()
	assert_str(String(interface.aim_location())).is_equal("")
	panel.aim_button(&"throat").pressed.emit()
	interface.select_pointer_action(&"strike")
	assert_str(String(interface.aim_location())).is_equal("")
	assert_bool(panel.aim_row.visible).is_false()


func _cast_actor(name: String, hp: int, attack: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.attributes = {&"edge": 2, &"pitch": 2}
	return actor


func _two_cell_ground() -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = tile_set.tile_size
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer := auto_free(TileMapLayer.new()) as TileMapLayer
	layer.tile_set = tile_set
	layer.set_cell(Vector2i(0, 0), 0, Vector2i.ZERO)
	layer.set_cell(Vector2i(1, 0), 0, Vector2i.ZERO)
	return layer
