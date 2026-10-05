extends GdUnitTestSuite
## Rendered evidence for the Lower Trial Hall warden fight as the player sees it: the hall is
## loaded, the warden encounter starts, and the battle HUD mounts through GameFlow's own
## Battle-state entry handler over the field camera.
## Run explicitly with scripts/test.sh -a test/manual/trial_fight_capture.gd.

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	get_tree().root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	UIManager.close_all()
	GameState.from_dict(_saved_state)


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert_int(image.save_png("user://qa/%s.png" % name)).is_equal(OK)
	print("SHOT ", ProjectSettings.globalize_path("user://qa/%s.png" % name))


func test_trial_warden_fight_as_the_player_sees_it() -> void:
	GameState.flags.clear()
	if GameState.party.is_empty():
		GameState._seed_demo_data()
	var runner := scene_runner(GameFlow.TRIAL_SCENE)
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	# The harness leaves the boot menu in the tree; production frees it on travel.
	for child: Node in get_tree().root.get_children():
		if child is CanvasItem and child != root and child.name.to_lower().contains("boot"):
			(child as CanvasItem).hide()
	var field := root.find_child("FieldMap", true, false) as FieldMap
	var player := field.player()
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
	await runner.simulate_frames(3)
	await _capture("trial-hall-before-fight")

	root.call("request_warden_encounter")
	await runner.simulate_frames(2)
	UIManager.close_all()
	GameFlow._on_battle_entered()
	await runner.simulate_frames(60, 16)
	var boot_scene := get_tree().current_scene as CanvasItem
	if boot_scene != null and boot_scene != root:
		boot_scene.hide()
	await runner.simulate_frames(2)
	await _capture("trial-warden-fight")
	print("SESSION ", Battle.session_active, " ENDED ", Battle.ended, " ENEMIES ", Battle.enemies.size())
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := layer as CanvasLayer
		print("LAYER ", cl.get_path(), " layer=", cl.layer, " visible=", cl.visible)
	GameFlow._on_battle_exited()
