extends GdUnitTestSuite
## Bounded rendered evidence for #633, following test/manual/screenshot_sweep.gd.
## Run: xvfb-run -a -s "-screen 0 1920x1080x24" bash scripts/test.sh -a test/manual/hub_portraits_capture.gd
## Captures land in user://qa/hub-portraits/; the reviewed set is copied to docs/qa/hub-portraits-2026-11-09/.

const CAPTURE_SIZE := Vector2i(1920, 1080)
const OUTPUT := "user://qa/hub-portraits/"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	get_tree().root.size = CAPTURE_SIZE
	get_tree().paused = false


func after_test() -> void:
	get_tree().paused = false


func test_kesselford_dialogue() -> void:
	await _capture("kesselford", "kesselford-bell-ringer", "hesk_waterward")


func test_ashlaren_dialogue() -> void:
	await _capture("ashlaren", "ashlaren-ghorr-steward", "ilse_furrowgood")


func test_long_verge_dialogue() -> void:
	await _capture("long_verge", "long-verge-recruit", "tessaly_brack")


func test_hollowmere_dialogue() -> void:
	await _capture("hollowmere", "hollowmere-watcher", "ysolde_marrow")


func _capture(hub: String, npc_id: String, stem: String) -> void:
	for node: Node in get_tree().root.find_children("*", "Camera2D", true, false):
		(node as Camera2D).enabled = false
	get_viewport().canvas_transform = Transform2D.IDENTITY
	var runner := scene_runner("res://world/%s.tscn" % hub)
	var town := runner.scene() as Node2D
	await runner.simulate_frames(40)
	var target: NPC = null
	for node: Node in get_tree().get_nodes_in_group(&"generated_townsfolk"):
		if town.is_ancestor_of(node) and str(node.get_meta(&"npc_id", "")) == npc_id:
			target = node as NPC
			break
	assert_object(target).is_not_null()
	if target == null:
		return
	var player := town.find_child("Player", true, false) as Node2D
	assert_object(player).is_not_null()
	if player == null:
		return
	player.global_position = target.global_position + Vector2(0, 96)
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
		camera.force_update_scroll()
	await runner.simulate_frames(3)
	var boot_scene := get_tree().current_scene
	if boot_scene is CanvasItem and boot_scene != town:
		(boot_scene as CanvasItem).hide()
	var balloon: Node = load("res://ui/dialogue/dialogue_balloon.tscn").instantiate()
	town.add_child(balloon)
	balloon.call("start", load(target.dialogue_path), target.dialogue_start)
	await runner.simulate_frames(35)
	var portrait := balloon.get("_portrait") as SMPortrait
	var portrait_image := portrait.get("_image") as TextureRect
	var placeholder := portrait.get("_placeholder") as Control
	var expected := "res://assets/generated/portraits/%s_portrait_neutral.png" % stem
	assert_object(portrait_image.texture).is_not_null()
	if portrait_image.texture != null:
		assert_str(portrait_image.texture.resource_path).is_equal(expected)
	assert_bool(portrait_image.is_visible_in_tree()).is_true()
	assert_bool(placeholder.visible).is_false()
	var reveal := UIManager.get_node_or_null("RewardReveal") as CanvasItem
	if reveal != null:
		reveal.hide()
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var captured := town.get_viewport().get_texture().get_image()
	assert_object(captured.get_size()).is_equal(CAPTURE_SIZE)
	var destination := OUTPUT + hub + "_dialogue.png"
	assert_int(captured.save_png(destination)).is_equal(OK)
	print("HUB-PORTRAIT CAPTURE: %s %s, asset=%s, monogram=false" % [hub, captured.get_size(), expected])
	balloon.free()
	town.hide()
	for layer: Node in town.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()
	if boot_scene is CanvasItem and boot_scene != town:
		(boot_scene as CanvasItem).show()
