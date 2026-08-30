extends GdUnitTestSuite

const RegionMapScript := preload("res://ui/screens/region_map.gd")

var _game_state_before: Dictionary = {}
var _travel_plan_before: TravelPlan
var _target_scene_before := ""
var _target_spawn_before: StringName = &"default"
var _flow_was_active := false


func before_test() -> void:
	_game_state_before = GameState.to_dict()
	_travel_plan_before = GameFlow.travel_plan
	_target_scene_before = GameFlow._target_scene
	_target_spawn_before = GameFlow._target_spawn_id
	_flow_was_active = bool(GameFlow.get_node("StateChart/Root/Playing/Active").get("active"))
	UIManager.close_all()
	get_tree().paused = false
	GameState.flags.clear()
	GameState.travel_plan = {}
	GameState.party = [_traveler()]
	GameFlow.travel_plan = null


func after_test() -> void:
	_restore_flow_after_battle_test()
	_clear_test_battle()
	UIManager.close_all()
	get_tree().paused = false
	GameState.from_dict(_game_state_before)
	GameFlow.travel_plan = _travel_plan_before
	GameFlow._target_scene = _target_scene_before
	GameFlow._target_spawn_id = _target_spawn_before


func test_map_builds_one_marker_per_registry_location_at_normalized_coordinate() -> void:
	_discover_all_locations()
	var runner = scene_runner("res://ui/screens/region_map.tscn")
	await runner.simulate_frames(3)
	var canvas: Control = runner.find_child("MapCanvas", true, false) as Control
	var marks: Control = runner.find_child("MapMarkers", true, false) as Control
	assert_object(canvas).is_not_null()
	assert_int(marks.get_child_count()).is_equal(WorldMapRegistry.all_locations().size())

	for location: Dictionary in WorldMapRegistry.all_locations():
		var marker: Button = runner.find_child(
			"Location_%s" % String(location["id"]), true, false
		) as Button
		assert_object(marker).is_not_null()
		var expected: Vector2 = Vector2(location["map_coordinate"]) * canvas.size
		var actual: Vector2 = marker.position + marker.size * 0.5
		assert_float(actual.x).is_equal_approx(expected.x, 1.0)
		assert_float(actual.y).is_equal_approx(expected.y, 1.0)


func test_undiscovered_markers_remain_visible_but_gated() -> void:
	GameState.discover_world_location(&"dom")
	var rows: Array[Dictionary] = RegionMapScript.locations_for(GameFlow.TOWN_SCENE)
	assert_int(rows.size()).is_equal(WorldMapRegistry.all_locations().size())
	assert_bool(bool(rows[0]["is_current"])).is_true()
	assert_bool(bool(rows[1]["is_discovered"])).is_false()

	var runner = scene_runner("res://ui/screens/region_map.tscn")
	await runner.simulate_frames(3)
	var marker: Button = runner.find_child("Location_wilds", true, false) as Button
	assert_object(marker).is_not_null()
	assert_bool(marker.disabled).is_true()
	assert_str(marker.text).is_equal("UNDISCOVERED")


func test_selecting_connected_destination_and_committing_creates_plan() -> void:
	GameState.discover_world_location(&"dom")
	GameState.discover_world_location(&"dorthkor-road")
	var runner = scene_runner("res://ui/screens/region_map.tscn")
	await runner.simulate_frames(3)
	var screen: RegionMapScreen = runner.scene() as RegionMapScreen
	screen._select_location(&"dorthkor-road")
	screen._travel_selected()

	assert_object(GameFlow.travel_plan).is_not_null()
	assert_str(GameFlow.travel_plan.origin_id).is_equal("dom")
	assert_str(GameFlow.travel_plan.destination_id).is_equal("dorthkor-road")
	assert_bool((runner.find_child("CancelJourneyButton", true, false) as Button).visible).is_true()


func test_manual_tick_surfaces_seeded_encounter_prompt_without_numeric_chance() -> void:
	_install_plan(_prompt_plan(7421, TravelPlan.State.EN_ROUTE, 1))
	var runner = scene_runner("res://ui/screens/region_map.tscn")
	await runner.simulate_frames(3)
	var screen: RegionMapScreen = runner.scene() as RegionMapScreen
	screen._on_journey_tick()

	assert_int(int(GameFlow.travel_plan.state)).is_equal(TravelPlan.State.AVOID_PROMPT)
	var prompt: Control = runner.find_child("EncounterPrompt", true, false) as Control
	var risk: Label = runner.find_child("EncounterRisk", true, false) as Label
	assert_bool(prompt.visible).is_true()
	assert_str(risk.text).contains("MODERATE")
	assert_bool(risk.text.contains("%") or risk.text.contains("15")).is_false()


func test_avoid_and_stand_ground_buttons_call_game_flow() -> void:
	var chance: float = _avoidance_chance()
	_install_plan(_prompt_plan(_seed_for_avoidance(chance, true), TravelPlan.State.AVOID_PROMPT, 2))
	var runner = scene_runner("res://ui/screens/region_map.tscn")
	await runner.simulate_frames(3)
	var avoid_button: Button = runner.find_child("AvoidEncounterButton", true, false) as Button
	avoid_button.pressed.emit()
	assert_int(int(GameFlow.travel_plan.state)).is_equal(TravelPlan.State.EN_ROUTE)

	_install_plan(_prompt_plan(41, TravelPlan.State.AVOID_PROMPT, 2))
	var screen: RegionMapScreen = runner.scene() as RegionMapScreen
	screen._sync_live_plan()
	var stand_button: Button = runner.find_child("StandGroundButton", true, false) as Button
	stand_button.pressed.emit()
	assert_int(int(GameFlow.travel_plan.state)).is_equal(TravelPlan.State.IN_BATTLE)
	assert_str(Battle.encounter_id).is_equal("loam-boar")


func test_cancel_button_clears_live_plan() -> void:
	_install_plan(_prompt_plan(17, TravelPlan.State.EN_ROUTE, 3))
	var runner = scene_runner("res://ui/screens/region_map.tscn")
	await runner.simulate_frames(3)
	var cancel_button: Button = runner.find_child("CancelJourneyButton", true, false) as Button
	cancel_button.pressed.emit()
	assert_object(GameFlow.travel_plan).is_null()


func test_reopening_live_plan_shows_continue_and_restores_party_progress() -> void:
	_install_plan(_prompt_plan(19, TravelPlan.State.EN_ROUTE, 4))
	var runner = scene_runner("res://ui/screens/region_map.tscn")
	await runner.simulate_frames(3)
	var continue_button: Button = runner.find_child("ContinueJourneyButton", true, false) as Button
	var party_marker: Control = runner.find_child("PartyMarker", true, false) as Control
	assert_bool(continue_button.visible).is_true()
	assert_bool(party_marker.visible).is_true()
	assert_float(float(party_marker.get_meta("route_progress", -1.0))).is_equal_approx(
		4.0 / 12.0, 0.001
	)


func test_pause_menu_opens_region_map_through_ui_manager() -> void:
	var runner = scene_runner("res://ui/screens/pause_menu.tscn")
	await runner.simulate_frames(2)
	var button: Button = runner.find_child("RegionMapButton", true, false) as Button
	assert_object(button).is_not_null()
	button.pressed.emit()
	await runner.simulate_frames(2)
	assert_bool(UIManager.is_open()).is_true()
	assert_str(UIManager._stack.back().scene_file_path).is_equal("res://ui/screens/region_map.tscn")


func _discover_all_locations() -> void:
	for location: Dictionary in WorldMapRegistry.all_locations():
		GameState.discover_world_location(StringName(location["id"]))


func _traveler() -> PartyMember:
	var member := PartyMember.new()
	member.id = "region-map-test"
	member.display_name = "Traveler"
	member.hp = 20
	member.max_hp = 20
	member.attributes = {"anchor": 8.0}
	member.skill_percentages = {"survival": 20.0}
	member.skill_tiers = {"survival": "untrained"}
	return member


func _prompt_plan(seed: int, state: TravelPlan.State, progress: int) -> TravelPlan:
	var plan := TravelPlan.new()
	plan.origin_id = &"dom"
	plan.destination_id = &"dorthkor-road"
	plan.progress_step = progress
	plan.total_steps = 12
	plan.rng_seed = seed
	plan.state = state
	plan.encounter_schedule = [{
		"at_step": 2,
		"encounter_id": &"loam-boar",
		"resolved": false,
		"spoils_granted": false,
	}]
	return plan


func _install_plan(plan: TravelPlan) -> void:
	GameFlow.travel_plan = plan
	GameState.travel_plan = plan.to_dict()


func _avoidance_chance() -> float:
	var route: Dictionary = WorldMapRegistry.route_between(&"dom", &"dorthkor-road")
	return EncounterDirector.avoidance_chance(route, GameState.party)


func _seed_for_avoidance(chance: float, succeeds: bool) -> int:
	for seed: int in range(1, 10000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		if (rng.randf_range(0.0, 100.0) < chance) == succeeds:
			return seed
	fail("Could not find deterministic avoidance seed")
	return 0


func _restore_flow_after_battle_test() -> void:
	if not _flow_was_active:
		return
	for event: StringName in [
		&"level_ready",
		&"deployment_next",
		&"deployment_next",
		&"deployment_next",
		&"accept_slate",
		&"battle_end",
	]:
		GameFlow.send_event(event)


func _clear_test_battle() -> void:
	if Battle.encounter_id.is_empty():
		return
	Battle._release_battlefield_ground()
	Battle.allies.clear()
	Battle.enemies.clear()
	Battle._definition.clear()
	Battle._combat_history.clear()
	Battle.controller = null
	Battle.encounter_id = &""
	Battle.last_result = null
	Battle.ended = true


## Wave AF: the map field carries the painterly Waning Marches atlas plate
## UNDER the route canvas, stretched (not cover-cropped) so the plate's
## painted landmarks warp with the same normalized coordinates the markers
## use. Backdrop must never intercept mouse input.
func test_atlas_backdrop_sits_under_the_canvas_stretched_to_the_field() -> void:
	var runner = scene_runner("res://ui/screens/region_map.tscn")
	await runner.simulate_frames(3)
	var texture_path := RegionMapScript.ATLAS_TEXTURE_PATH
	var exists_for_export := (
		ResourceLoader.exists(texture_path) or FileAccess.file_exists(texture_path)
	)
	assert_bool(exists_for_export) \
		.override_failure_message("Atlas plate is missing: %s" % texture_path) \
		.is_true()
	var backdrop: TextureRect = runner.find_child("AtlasBackdrop", true, false) as TextureRect
	assert_object(backdrop).is_not_null()
	if backdrop == null:
		return
	assert_object(backdrop.texture).is_not_null()
	if backdrop.texture != null:
		assert_str(backdrop.texture.resource_path).is_equal(texture_path)
	assert_int(backdrop.stretch_mode).is_equal(TextureRect.STRETCH_SCALE)
	assert_int(backdrop.expand_mode).is_equal(TextureRect.EXPAND_IGNORE_SIZE)
	assert_int(backdrop.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var canvas: Control = runner.find_child("MapCanvas", true, false) as Control
	assert_object(canvas).is_not_null()
	if canvas != null:
		assert_bool(backdrop.get_index() < canvas.get_index()) \
			.override_failure_message("AtlasBackdrop must render beneath MapCanvas.") \
			.is_true()
		assert_bool(backdrop.size.is_equal_approx(canvas.size)) \
			.override_failure_message("AtlasBackdrop must fill the map field.") \
			.is_true()
	var route_canvas: Control = runner.find_child("MapCanvas", true, false) as Control
	assert_bool(bool(route_canvas.get("has_backdrop"))) \
		.override_failure_message("MapCanvas must scrim (not opaque-fill) over the atlas.") \
		.is_true()
