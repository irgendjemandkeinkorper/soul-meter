extends GdUnitTestSuite
## Rendered evidence for #464: Dom set-dressing props beside the 112 px adult at camera zoom 1.
## Places the player beside the gate, lanterns, a cart, banners, the bench and the south wall, then saves
## the full 1920x1080 frame and a 1000x640 crop around the player to user://qa/.
## Run explicitly under Xvfb with scripts/test.sh -a test/manual/town_prop_scale_capture.gd.

const CROP_SIZE := Vector2i(1000, 640)
const SPOTS := {
	"gate-lantern": Vector2(1075, 575),
	"cart-banner-lantern": Vector2(3050, 1565),
	"town-hall-banner-lanterns": Vector2(2400, 1185),
	"bench": Vector2(1665, 600),
	"players-house-spawn-wall": Vector2(2400, 2132),
}

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


func test_town_prop_scale_spots() -> void:
	var runner := scene_runner(GameFlow.TOWN_SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(10)
	var player := root.find_child("Player", true, false) as Node2D
	assert_object(player).is_not_null()
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	for shot: String in SPOTS:
		for child: Node in get_tree().root.get_children():
			if child is CanvasItem and child != root and child == get_tree().current_scene:
				(child as CanvasItem).hide()
		player.global_position = SPOTS[shot]
		if camera != null:
			camera.enabled = true
			camera.zoom = Vector2.ONE
			camera.make_current()
			camera.reset_smoothing()
		await runner.simulate_frames(10)
		if camera != null:
			camera.reset_smoothing()
		await runner.simulate_frames(2)
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var full_path := "user://qa/town-prop-scale-%s.png" % shot
		assert_int(image.save_png(full_path)).is_equal(OK)
		var screen := Vector2i(player.get_global_transform_with_canvas().origin)
		var corner := (screen - CROP_SIZE / 2).clamp(Vector2i.ZERO, image.get_size() - CROP_SIZE)
		var crop := image.get_region(Rect2i(corner, CROP_SIZE))
		assert_int(crop.save_png("user://qa/town-prop-scale-%s-crop.png" % shot)).is_equal(OK)
		print("SHOT ", ProjectSettings.globalize_path(full_path), " player_screen=", screen)
