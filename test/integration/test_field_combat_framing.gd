extends GdUnitTestSuite
## The Lower Trial Hall warden fight opens with the party at the hall's south wall, where the
## room camera used to leave both fighters under the battle HUD's command dock. The combat
## overlay must frame every combatant inside the stage window the HUD leaves open, hide the
## field HUD, and hand the camera's room limits back when the fight ends.

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	get_tree().root.size = Vector2i(1920, 1080)


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	UIManager.close_all()
	GameState.from_dict(_saved_state)


func test_trial_warden_fight_frames_both_sides_in_the_stage_window() -> void:
	GameState.flags.clear()
	if GameState.party.is_empty():
		GameState._seed_demo_data()
	var runner := scene_runner(GameFlow.TRIAL_SCENE)
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	var field := root.find_child("FieldMap", true, false) as FieldMap
	var player := field.player()
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()
	var room_limits := [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]

	root.call("request_warden_encounter")
	await runner.simulate_frames(2)
	assert_bool(Battle.session_active).is_true()
	UIManager.close_all()
	GameFlow._on_battle_entered()
	await runner.simulate_frames(60, 16)

	var stage := get_tree().root.find_child("Stage", true, false) as Control
	assert_object(stage).is_not_null()
	var window := stage.get_global_rect()
	assert_bool(window.has_area()).is_true()
	var combatants: Array[Node2D] = [player]
	for body: Hostile in Battle._spawned_hostiles:
		combatants.append(body)
	assert_int(combatants.size()).is_greater(1)
	for node: Node2D in combatants:
		var on_screen := node.get_global_transform_with_canvas().origin
		assert_bool(window.has_point(on_screen)) \
			.override_failure_message("%s drawn at %s, outside the stage window %s" % [node.name, on_screen, window]) \
			.is_true()
	assert_bool((root.get_node("EntranceInstruction") as CanvasItem).visible).is_false()
	for layer: Node in root.find_children("*", "CanvasLayer", true, false):
		if layer.scene_file_path == FieldMap.FIELD_HUD_SCENE:
			assert_bool((layer as CanvasLayer).visible).is_false()

	GameFlow._on_battle_exited()
	Battle._end_session(null)
	await runner.simulate_frames(30, 16)
	assert_array([camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]) \
		.is_equal(room_limits)
	assert_vector(camera.offset).is_equal(Vector2.ZERO)
