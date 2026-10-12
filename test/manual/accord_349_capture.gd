extends GdUnitTestSuite
## Rendered evidence for #349: a live same-map session on the Wilds field; an AccordZone is
## placed over the caster and the frozen per-action accord and fizzle forecast change with it.
## Run explicitly with scripts/test.sh -a test/manual/accord_349_capture.gd (Xvfb).
## The caption is capture-only evidence, not shipped UI; the accord overlay is E6.2.

var _saved_state: Dictionary
var _boot_visible := true
var _boot_scene: Node


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	get_tree().root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	_boot_scene = get_tree().current_scene
	var boot := _boot_scene as CanvasItem
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
	if is_instance_valid(_boot_scene):
		get_tree().current_scene = _boot_scene
	var main_menu := get_tree().root.get_node_or_null("MainMenu") as CanvasItem
	if main_menu != null:
		main_menu.visible = _boot_visible
	var boot := _boot_scene as CanvasItem
	if boot != null:
		boot.visible = _boot_visible


func test_live_field_session_accord_context() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	var field := root.find_child("FieldMap", true, false) as FieldMap
	# Production runs the field as the current scene; Battle reads the location base from it.
	get_tree().current_scene = root
	var hostile := load("res://actors/hostile/hostile.tscn").instantiate() as Hostile
	hostile.name = "AccordCaptureWight"
	hostile.unit_id = &"bog-wight"
	hostile.alert_radius = 0.0
	root.add_child(hostile)
	hostile.global_position = field.iso_grid().cell_to_world(Vector2i(30, 30))
	hostile.sync_cell()
	var opened := Battle.start_session(field, hostile)
	assert_bool(opened.get("allowed", false)).override_failure_message(str(opened)).is_true()

	var actor := Battle.controller.active_actor()
	assert_object(actor).is_not_null()
	var frozen := Battle.controller.accord_context_for(actor)
	assert_bool(frozen.is_empty()).is_false()
	var cell: Vector2i = frozen["cell"]
	# Wilds authors no zone, so the cell's accord is the battle's base exactly.
	var base_accord := float(frozen["harmonic_accord"])
	assert_float(base_accord).is_equal(Battle.controller.agreement_integrity)
	assert_float(base_accord).is_equal(field.accord_base())
	var intuition := actor.attribute_value(&"intuition")
	var fizzle_before := SkillCheck.fizzle_percent(base_accord, "chord", 0, "phrase", intuition)

	# Place an AccordZone over the caster, as Weftlumin's palette would, and re-forecast.
	var zone := load("res://actors/accord_zone/accord_zone.tscn").instantiate() as AccordZone
	zone.accord_delta = -40
	zone.half_width_cells = 2
	zone.half_height_cells = 2
	field.add_child(zone)
	zone.global_position = field.iso_grid().cell_to_world(cell)
	Battle.controller.release_accord_context(actor)
	var zoned := Battle.controller.accord_context_for(actor)
	var zoned_accord := float(zoned["harmonic_accord"])
	assert_float(zoned_accord).is_equal(base_accord - 40.0)
	var fizzle_after := SkillCheck.fizzle_percent(zoned_accord, "chord", 0, "phrase", intuition)
	assert_float(fizzle_after).is_greater(fizzle_before)
	_draw_zone_cells(root, field, zone)

	var caption_text := (
		"#349 AccordZone (accord_delta -40, 5x5 cells) placed over %s at %s\n"
		+ "harmonic_accord %.0f -> %.0f   |   Chord-Phrase fizzle forecast %.0f%% -> %.0f%%"
		+ "   |   frozen: day %d, %s, weather '%s'   |   Loom strength %.0f (FULL skills -%d pp)"
	) % [
		actor.display_name, str(cell), base_accord, zoned_accord, fizzle_before, fizzle_after,
		int(zoned["day_index"]), String(zoned["phase"]), String(zoned["weather"]),
		AccordMath.loom_strength(field.zone_delta(cell)),
		SkillCheck.loom_penalty("sounding", field.zone_delta(cell)),
	]
	print("ACCORD ", caption_text)

	for layer: Node in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()
	UIManager.close_all()
	# Handing current_scene to the field leaves the boot menu drawn; keep it out of the shot.
	var main_menu := get_tree().root.get_node_or_null("MainMenu") as CanvasItem
	if main_menu != null:
		main_menu.hide()
	if is_instance_valid(_boot_scene):
		# CanvasLayers do not inherit the hidden boot scene's visibility.
		for layer: Node in _boot_scene.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).hide()
	var hud := CanvasLayer.new()
	hud.layer = 10
	root.add_child(hud)
	var screen := load("res://ui/screens/battle.tscn").instantiate() as Screen
	screen.theme = ThemeBuilder.build()
	hud.add_child(screen)
	var caption := PanelContainer.new()
	caption.theme = ThemeBuilder.build()
	caption.position = Vector2(32, 620)
	var label := Label.new()
	label.text = caption_text
	caption.add_child(label)
	hud.add_child(caption)
	var camera := field.player().get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()
	camera.reset_smoothing()
	await runner.simulate_frames(5)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	assert_int(image.save_jpg("user://qa/accord-349-zone-forecast.jpg", 0.82)).is_equal(OK)
	print("SHOT accord-349-zone-forecast ", ProjectSettings.globalize_path("user://qa"))
	screen.free()
	Battle._end_session(null)


## Capture-only highlight of the zone's covered cells (the shipped overlay is E6.2).
func _draw_zone_cells(root: Node2D, field: FieldMap, zone: AccordZone) -> void:
	var grid := field.iso_grid()
	var anchor := field.zone_anchor_cell(zone)
	var probe_x := grid.cell_to_world(anchor + Vector2i(1, 0)) - grid.cell_to_world(anchor)
	var probe_y := grid.cell_to_world(anchor + Vector2i(0, 1)) - grid.cell_to_world(anchor)
	for covered: Vector2i in zone.covered_cells(anchor):
		var center := grid.cell_to_world(covered)
		var tile := Polygon2D.new()
		tile.polygon = PackedVector2Array([
			center - (probe_x + probe_y) * 0.5, center + (probe_x - probe_y) * 0.5,
			center + (probe_x + probe_y) * 0.5, center - (probe_x - probe_y) * 0.5,
		])
		tile.color = Color(0.35, 0.55, 0.95, 0.35)
		tile.z_index = 1
		root.add_child(tile)
