extends GdUnitTestSuite
## Rendered evidence for #652 gap 5, the mock NG+ rollover. Run explicitly under Xvfb at 1920x1080:
##   SOUL_METER_HEADLESS=0 scripts/test.sh -a test/manual/mock_ng_plus_capture.gd
## Frames land in user://qa/mock-ng-plus/*.png:
##   01 the chapter-complete screen: the STYLE POINTS line and Begin Mock NG+
##   02 the title after the real button press: the armed notice
##   03 Hadrik Vale's hub after the rollover applies: his NG+ echo line is offered

const OUT_DIR := "user://qa/mock-ng-plus"
const CAPTURE_SIZE := Vector2i(1920, 1080)
const SaveGameScript := preload("res://globals/save_game.gd")

var _state_before: Dictionary
var _ng_plus_before: Dictionary


func before_test() -> void:
	get_tree().root.size = CAPTURE_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_state_before = GameState.to_dict().duplicate(true)
	_ng_plus_before = SaveGame.ng_plus.duplicate(true)


func after_test() -> void:
	UIManager.close_all()
	SaveGame._armed_ng_plus = {}
	SaveGame.ng_plus = _ng_plus_before
	GameState.from_dict(_state_before)


## GameFlow's boot load of the title can finish after a scene runner starts and lands as a later
## root sibling, drawing over the capture, so the boot scene is hidden right before each shot.
func _capture(scene: Node, name: String) -> void:
	_hide_boot_scene(scene)
	var viewport := scene.get_viewport()
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	assert_int(image.save_png(path)).is_equal(OK)
	print("SHOT ", ProjectSettings.globalize_path(path))


## The boot scene is the title: hiding its root Control leaves its CanvasLayers drawing, so
## hide those too or the title photobombs the next capture.
func _hide_boot_scene(scene: Node) -> void:
	var boot_scene := scene.get_tree().current_scene
	if boot_scene == null or boot_scene == scene:
		return
	if boot_scene is CanvasItem:
		(boot_scene as CanvasItem).hide()
	for layer: Node in boot_scene.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()


func test_the_mock_rollover_from_chapter_end_to_an_echo_line() -> void:
	if GameState.party.is_empty():
		GameState._seed_demo_data()
	SaveGame.ng_plus = NGPlus.default_block()
	SaveGame.ng_plus["style_points"] = 37

	# 1. The chapter-complete screen, as GameFlow opens it.
	var complete_runner := scene_runner("res://ui/screens/chapter_complete.tscn")
	var complete := complete_runner.scene()
	_hide_boot_scene(complete)
	await complete_runner.simulate_frames(10)
	var button := complete.find_child("BeginMockNgPlus", true, false) as Button
	assert_object(button).is_not_null()
	await _capture(complete, "01-chapter-complete")

	# 2. The real button: it saves, arms the block and asks the chart for the title.
	button.pressed.emit()
	assert_bool(SaveGame.ng_plus_armed()).is_true()
	print("ARMED ", SaveGame.armed_ng_plus())
	(complete as CanvasItem).hide()
	var title_runner := scene_runner("res://ui/screens/main_menu.tscn")
	var title := title_runner.scene()
	_hide_boot_scene(title)
	await title_runner.simulate_frames(10)
	var notice := title.find_child("MockNgPlusNotice", true, false) as Label
	assert_object(notice).is_not_null()
	print("NOTICE ", notice.text)
	await _capture(title, "02-title-armed")

	# 3. New Game applies the block. A private SaveGame runs it so no Dom load starts here; the
	# block it produces is exactly what the autoload would hold.
	var saves = auto_free(SaveGameScript.new())
	saves.arm_ng_plus(SaveGame.armed_ng_plus())
	saves.new_game()
	SaveGame._armed_ng_plus = {}
	SaveGame.ng_plus = saves.ng_plus
	print("APPLIED active=", NGPlus.is_active(SaveGame.ng_plus), " block=", SaveGame.ng_plus)
	assert_bool(NGPlus.is_active(SaveGame.ng_plus)).is_true()
	(title as CanvasItem).hide()
	for layer: Node in title.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()
	var archive_runner := scene_runner("res://world/interiors/registry_archive.tscn")
	var archive := archive_runner.scene()
	_hide_boot_scene(archive)
	await archive_runner.simulate_frames(40)
	var balloon: Node = load("res://ui/dialogue/dialogue_balloon.tscn").instantiate()
	archive.add_child(balloon)
	balloon.call("start", load("res://dialogue/hadrik_vale.dialogue"), "hub")
	await archive_runner.simulate_frames(60)
	await _capture(archive, "03-hadrik-echo-line")
	balloon.free()
