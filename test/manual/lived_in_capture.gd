extends GdUnitTestSuite
## Rendered evidence for the lived-in maps (owner 2026-11-02): Kesselford at camera zoom 1 around
## its landmarks, plus a zoomed-out overview, after the generated dressing loads. Run under Xvfb:
##   CAPTURE_OUT=<dir> scripts/test.sh -a test/manual/lived_in_capture.gd
## LIVED_IN_OFF=1 hides the generated dressing, for before/after pairs.

const SCENE := "res://world/kesselford.tscn"
const SPOTS := {
	"wayhouse": Vector2(1150, 860),
	"chandlery": Vector2(1900, 860),
	"south-yards": Vector2(1500, 1400),
}

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	get_tree().root.size = Vector2i(1920, 1080)
	if GameState.party.is_empty():
		GameState._seed_demo_data()


func after_test() -> void:
	UIManager.close_all()
	GameState.from_dict(_saved_state)


func test_kesselford_lived_in_spots() -> void:
	var out_dir := OS.get_environment("CAPTURE_OUT")
	if out_dir.is_empty():
		out_dir = ProjectSettings.globalize_path("user://qa/lived-in")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var tag := "before" if OS.get_environment("LIVED_IN_OFF") == "1" else "after"
	var runner := scene_runner(SCENE)
	var root := runner.scene() as Node
	await runner.simulate_frames(10)
	var lived_in := root.find_child("LivedIn", true, false) as Node2D
	if lived_in != null and tag == "before":
		lived_in.hide()
	for hud: Node in root.find_children("*", "CanvasLayer", true, false):
		(hud as CanvasLayer).hide()
	# The title screen and autoload overlays sit beside the map under the root; hide them all.
	for child: Node in get_tree().root.get_children():
		if child == root or child.is_ancestor_of(root):
			continue
		if child is CanvasItem:
			(child as CanvasItem).hide()
		for layer: Node in child.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).hide()
		if child is CanvasLayer:
			(child as CanvasLayer).hide()
	var player := root.find_child("Player", true, false) as Node2D
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	var shots := SPOTS.duplicate()
	shots["overview"] = Vector2(1500, 900)
	for shot: String in shots:
		player.global_position = shots[shot]
		camera.enabled = true
		camera.zoom = Vector2(0.5, 0.5) if shot == "overview" else Vector2.ONE
		camera.make_current()
		camera.reset_smoothing()
		await runner.simulate_frames(8)
		camera.reset_smoothing()
		await runner.simulate_frames(2)
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var path := "%s/kesselford-%s-%s.png" % [out_dir, shot, tag]
		assert_int(get_viewport().get_texture().get_image().save_png(path)).is_equal(OK)
		# Plan acceptance: profile node and draw-call counts; the real 60 fps check is FR-904.
		print("SHOT ", path, " draw_calls=",
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			" objects=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	if lived_in != null:
		var shadows := lived_in.get_node("DressingShadows") as DressingShadows
		print("COUNTS props=", lived_in.get_node("Props").get_child_count(),
			" ground=", lived_in.get_node("GroundDetails").get_child_count(),
			" shadows=", shadows.shadow_count(),
			" blocked=", (lived_in as LivedIn).blocked_cells.size(),
			" scene_nodes=", root.get_tree().get_node_count())
