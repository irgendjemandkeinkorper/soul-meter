extends GdUnitTestSuite
## Rendered evidence for #281: an ambient same-map fight opened through the real path — the
## party walks into the authored Bog Wight's alert radius on test_room, the flow's field watch
## opens the session, and combat presents on the field with the log column hidden.
## Run explicitly with scripts/test.sh -a test/manual/ambient_session_capture.gd.

var _saved_state: Dictionary
var _boot_visible := true


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	get_tree().root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	var boot := get_tree().current_scene as CanvasItem
	if boot != null:
		_boot_visible = boot.visible
		boot.hide()


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	Battle._release_field_grid()
	UIManager.close_all()
	GameState.from_dict(_saved_state)
	var boot := get_tree().current_scene as CanvasItem
	if boot != null:
		boot.visible = _boot_visible


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert_object(image.get_size()).is_equal(Vector2i(1920, 1080))
	assert_int(image.save_png("user://qa/%s.png" % name)).is_equal(OK)
	print("SHOT ", name)


func test_ambient_bog_wight_fight_reads_with_the_log_hidden() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	var field := root.find_child("FieldMap", true, false) as FieldMap
	var wight := root.find_child("BogWight", true, false) as Hostile
	assert_object(wight).override_failure_message("test_room must author BogWight as a Hostile").is_not_null()
	GameState.set_flag("defeated_bog_wight", false)

	# The real edge: the flow watches the field, the party walks up to the wight.
	GameFlow.watch_field_hostiles()
	var player := field.player()
	player.global_position = wight.global_position + Vector2(-140.0, 0.0)
	wight.realert_cooldown = 0.0
	wight._set_sensor_enabled(true)
	wight._check_initial_overlap()
	await runner.simulate_frames(4)

	assert_bool(Battle.session_active) \
		.override_failure_message("walking into the wight must open an ambient session") \
		.is_true()
	assert_int(wight.state).is_equal(Hostile.State.IN_COMBAT)
	# The runner's chart is not in Active, so whatever screen the flow left up is not the fight.
	UIManager.close_all()
	var boot_scene := get_tree().current_scene as CanvasItem
	if boot_scene != null:
		boot_scene.hide()

	# Production mounts the battle screen from the chart's Battle state; the runner's chart is
	# not in Active, so mount the same screen by hand over the field's own camera.
	for layer: Node in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()
	var hud := CanvasLayer.new()
	hud.layer = 10
	root.add_child(hud)
	var screen := load("res://ui/screens/battle.tscn").instantiate() as Screen
	screen.theme = ThemeBuilder.build()
	hud.add_child(screen)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()
	camera.reset_smoothing()
	await runner.simulate_frames(5)
	var log_label := screen.get("_log_lbl") as Control
	if log_label != null:
		log_label.get_parent().hide()
	await runner.simulate_frames(2)
	await _capture("ambient-open")

	# One strike from the active ally so the action beat, damage number and HP tick render.
	var hp_before := wight.battle_actor().hp
	assert_bool(Battle.use_action(Battle.ACTION_STRIKE)).is_true()
	await runner.simulate_frames(20)
	await _capture("ambient-after-strike")
	print("WIGHT HP ", hp_before, " -> ", wight.battle_actor().hp)

	screen.free()
	Battle._end_session(null)
