extends GdUnitTestSuite
## Rendered evidence for actor scale against environment art: Dom's street and the Four Arms
## tavern at 1920x1080 around the player. Run on two builds to compare scale passes.
## Run explicitly with scripts/test.sh -a test/manual/actor_scale_capture.gd.

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	get_tree().root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	if GameState.party.is_empty():
		GameState._seed_demo_data()


func after_test() -> void:
	UIManager.close_all()
	GameState.from_dict(_saved_state)


func _shoot(scene_path: String, shot: String) -> void:
	var runner := scene_runner(scene_path)
	var root := runner.scene() as Node
	await runner.simulate_frames(10)
	for child: Node in get_tree().root.get_children():
		if child is CanvasItem and child != root and child == get_tree().current_scene:
			(child as CanvasItem).hide()
	var player := root.find_child("Player", true, false) as Node2D
	var camera := player.get_node_or_null("Camera2D") as Camera2D if player != null else null
	if camera != null:
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
	await runner.simulate_frames(10)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert_int(image.save_png("user://qa/%s.png" % shot)).is_equal(OK)
	print("SHOT ", ProjectSettings.globalize_path("user://qa/%s.png" % shot))


func test_dom_street_and_tavern() -> void:
	await _shoot(GameFlow.TOWN_SCENE, "scale-dom-street")
	await _shoot(GameFlow.TAVERN_SCENE, "scale-four-arms")
