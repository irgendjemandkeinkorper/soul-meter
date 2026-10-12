extends GdUnitTestSuite
## E6.2 (#350, architecture §4.11): the read-only accord / weather / charge / walkability overlay
## in the real shell over the Wilds field, with `AccordZone`s placed on it and, where a test needs
## charge, a live same-map battle. The overlay must read `FieldMap` and the live controller only
## and change nothing. With `SOUL_METER_ACCORD_OVERLAY_CAPTURE_DIR` set (under Xvfb or a
## display) the capture test writes the rendered heatmap.

const SHELL := preload("res://addons/weftlumin/shell/shell.tscn")
const PANEL := preload("res://weftlumin/panels/accord_overlay.tscn")
const FIELD_SCENE := "res://world/test_room.tscn"
const ZONE_SCENE := preload("res://actors/accord_zone/accord_zone.tscn")
const DOM_FIXTURE_LOG := "res://test/fixtures/weftlumin/dom_scene_bake/commands.jsonl"
const BAKE_TARGET := "user://weftlumin_accord_lint_test"

class FixtureAdapter extends WeftluminGameAdapter:
	var world: Node
	var previous_paused := false

	func gameplay_scene_root() -> Node:
		return world

	func theme() -> Theme:
		return UIManager.ui_theme

	func panels() -> Array[PackedScene]:
		return [PANEL]

	func set_editor_open(open: bool) -> void:
		if open:
			previous_paused = world.get_tree().paused
			world.get_tree().paused = true
		else:
			world.get_tree().paused = previous_paused

var world: Node2D
var field: FieldMap
var shell: WeftluminShell
var panel: WeftluminAccordOverlayPanel
var _previous_scene: Node
var _previous_paused := false
var _hidden: Array[CanvasItem] = []
var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	_previous_scene = get_tree().current_scene
	_previous_paused = get_tree().paused
	await UIManager.close_all()
	get_tree().paused = false
	for child: Node in get_tree().root.get_children():
		if child is CanvasItem and child.visible:
			_hidden.append(child)
			child.hide()
	world = (load(FIELD_SCENE) as PackedScene).instantiate() as Node2D
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await get_tree().process_frame
	await get_tree().process_frame
	field = world.find_child("FieldMap", true, false) as FieldMap
	for layer: Node in world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()


func after_test() -> void:
	if is_instance_valid(shell):
		shell.close()
		await get_tree().process_frame
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	Battle._release_field_grid()
	if is_instance_valid(world):
		world.free()
	get_tree().current_scene = _previous_scene if is_instance_valid(_previous_scene) else null
	for item: CanvasItem in _hidden:
		if is_instance_valid(item):
			item.show()
	_hidden.clear()
	get_tree().paused = _previous_paused
	GameState.from_dict(_saved_state)
	_remove_tree(BAKE_TARGET)


func test_overlay_mounts_off_and_states_what_it_shows() -> void:
	await _open_shell()
	assert_object(panel).is_not_null()
	assert_str(panel.title).is_equal("Accord overlay")
	assert_bool(panel.needs_sandbox).is_false()
	assert_bool(panel.overlay_visible()).is_false()
	var sampled: Dictionary = panel.current_sample()
	assert_object(sampled["field"]).is_same(field)
	assert_str(str(sampled["location_id"])).is_equal("wilds")
	assert_float(float(sampled["base"])).is_equal(field.accord_base())
	assert_str(panel.summary_label.text).contains("variation not applied")
	assert_str(panel.weather_label.text).contains("location default")


func test_heatmap_reads_field_accord_and_zone_deltas() -> void:
	var player_cell: Vector2i = _player_cell()
	var thinned := _zone(player_cell, -40, 2, &"")
	var blessed := _zone(player_cell + Vector2i(3, 0), 15, 1, &"mozh")
	var sampled: Dictionary = WeftluminAccordOverlayPanel.sample(world)
	assert_object(thinned).is_not_null()
	assert_object(blessed).is_not_null()
	for cell: Vector2i in [player_cell, player_cell + Vector2i(2, 2), player_cell + Vector2i(3, 0), player_cell + Vector2i(4, 1)]:
		assert_float(WeftluminAccordOverlayPanel.accord_in(sampled, cell)).override_failure_message(str(cell)).is_equal(field.accord_at(cell))
	var far := player_cell + Vector2i(9, 9)
	assert_float(WeftluminAccordOverlayPanel.accord_in(sampled, far)).is_equal(field.accord_at(far))
	# The overlap of the two zones sums, as FieldMap.zone_delta() does.
	assert_float(float((sampled["zone_deltas"] as Dictionary)[player_cell + Vector2i(2, 0)])).is_equal(-25.0)
	assert_vector(sampled["zone_range"] as Vector2).is_equal(Vector2(-40, 15))
	assert_int((sampled["zones"] as Array).size()).is_equal(2)
	var readout: String = WeftluminAccordOverlayPanel.cell_text(sampled, player_cell + Vector2i(4, 0))
	assert_str(readout).contains("element default Mozh")
	assert_str(readout).contains("zone delta +15")


func test_heatmap_colours_are_ds_stops() -> void:
	assert_bool(WeftluminAccordOverlayPanel.accord_color(0.0).is_equal_approx(Color(DS.VIOLET_2, DS.FACADE_OCCLUDED_ALPHA))).is_true()
	assert_bool(WeftluminAccordOverlayPanel.accord_color(50.0).is_equal_approx(Color(DS.GILD_2, DS.FACADE_OCCLUDED_ALPHA))).is_true()
	assert_bool(WeftluminAccordOverlayPanel.accord_color(100.0).is_equal_approx(Color(DS.STATE_CONSTANT, DS.FACADE_OCCLUDED_ALPHA))).is_true()
	assert_bool(WeftluminAccordOverlayPanel.accord_color(140.0).is_equal_approx(WeftluminAccordOverlayPanel.accord_color(100.0))).is_true()


func test_saturation_warnings_match_the_bake_lint() -> void:
	var player_cell: Vector2i = _player_cell()
	_zone(player_cell, 30, 1, &"")
	var sampled: Dictionary = WeftluminAccordOverlayPanel.sample(world)
	var base: float = field.accord_base()
	assert_float(base + 30.0 + 10.0).is_greater(100.0)
	var warnings: PackedStringArray = sampled["warnings"]
	assert_int(warnings.size()).is_equal(1)
	assert_str(warnings[0]).contains("wilds saturates high")
	await _open_shell()
	panel.refresh({"scene_root": world})
	assert_bool(panel.warnings_label.visible).is_true()
	assert_str(panel.warnings_label.text).contains("WARNING: wilds saturates high")


func test_live_battle_supplies_weather_and_charge_without_mutating_tiles() -> void:
	var controller := _start_battle()
	# Seeding is the test's own write (as Combat Lab's tile seed does); the overlay never calls
	# `tile_state_at()`, which creates tiles.
	var cell: Vector2i = _player_cell()
	var seeded: TileState = controller.tile_state_at(cell)
	assert_object(seeded).is_not_null()
	assert_bool(bool(seeded.apply_residue(&"khash").get("allowed", false))).is_true()
	assert_bool(bool(seeded.apply_residue(&"khash").get("allowed", false))).is_true()
	assert_bool(bool(controller.configure_weather(&"mozh").get("allowed", false))).is_true()
	var tiles_before: int = controller.tile_states.size()
	var snapshot: Array = controller.tile_states.map(func(tile: TileState) -> Dictionary: return tile.to_dict())
	var weather_before: Dictionary = controller.weather.to_dict()
	assert_object(WeftluminAccordOverlayPanel.live_controller(world)).is_same(controller)
	var sampled: Dictionary = WeftluminAccordOverlayPanel.sample(world, controller)
	assert_float(float(sampled["base"])).is_equal(controller.agreement_integrity)
	assert_str(String((sampled["weather"] as Dictionary)["element"])).is_equal("mozh")
	assert_str(WeftluminAccordOverlayPanel.weather_text(sampled)).is_equal("Weather: Mozh (live battle)")
	var charges: Array = sampled["charges"]
	assert_int(charges.size()).is_equal(1)
	assert_bool(charges[0]["cell"] == cell).is_true()
	assert_int(int(charges[0]["level"])).is_equal(2)
	assert_str(String(charges[0]["element"])).is_equal("khash")
	# Drawing and hovering read only; no TileState is created or changed.
	await _open_shell()
	panel.set_overlay_visible(true)
	_motion(_screen(cell))
	await _render()
	assert_str(panel.hover_label.text).contains("charge Khash 2")
	assert_int(controller.tile_states.size()).is_equal(tiles_before)
	assert_array(controller.tile_states.map(func(tile: TileState) -> Dictionary: return tile.to_dict())).is_equal(snapshot)
	assert_dict(controller.weather.to_dict()).is_equal(weather_before)


func test_walkability_reads_the_players_own_grid() -> void:
	await _open_shell()
	var sampled: Dictionary = panel.current_sample()
	assert_object(sampled["walk_grid"]).is_same(field.iso_grid())
	var grid: IsoGrid = field.iso_grid()
	var region: Rect2i = grid.get_used_rect()
	var blocked: Variant = null
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if blocked == null and grid.is_blocked_for(Vector2i(x, y)):
				blocked = Vector2i(x, y)
	assert_object(blocked).is_not_null()
	assert_str(WeftluminAccordOverlayPanel.cell_text(sampled, blocked as Vector2i)).ends_with("blocked")


func test_overlay_never_consumes_viewport_clicks() -> void:
	await _open_shell()
	panel.set_overlay_visible(true)
	var zones_before: int = field.accord_zones().size()
	var at: Vector2 = shell.viewport_surface.get_global_rect().get_center()
	_button(at, true)
	_button(at, false)
	await get_tree().process_frame
	assert_int(field.accord_zones().size()).is_equal(zones_before)
	assert_bool(panel.overlay_visible()).is_true()


func test_dom_bake_reports_saturation_as_a_warning_and_still_writes() -> void:
	var kind := WeftluminScenesKind.new()
	var errors: Array[Dictionary] = []
	var entries: Array[Dictionary] = kind.validate(WeftluminScenesKind.load_log(DOM_FIXTURE_LOG, errors), errors)
	assert_array(errors).is_empty()
	var report: Dictionary = kind.bake(entries, BAKE_TARGET, true, false)
	assert_array(report["errors"]).override_failure_message(JSON.stringify(report["errors"], "  ")).is_empty()
	# Dom authors 95 at tier 0: 95 + 0 + 10 > 100.
	var warnings: Array = report["warnings"]
	assert_int(warnings.size()).is_equal(1)
	assert_str(str(warnings[0]["code"])).is_equal("accord_saturation")
	assert_str(str(warnings[0]["message"])).contains("dom saturates high")
	assert_int(int((report["lint"] as Dictionary)["warnings"])).is_equal(1)
	assert_array(report["written"]).is_equal([BAKE_TARGET.path_join("world/starting_town.tscn")])


func test_rendered_heatmap_over_an_accord_zone_capture() -> void:
	var directory := OS.get_environment("SOUL_METER_ACCORD_OVERLAY_CAPTURE_DIR")
	if directory.is_empty():
		return
	assert_str(DisplayServer.get_name()).is_not_equal("headless")
	if DisplayServer.get_name() == "headless":
		return
	get_tree().root.size = Vector2i(1920, 1080)
	assert_int(DirAccess.make_dir_recursive_absolute(directory)).is_equal(OK)
	var controller := _start_battle()
	var centre: Vector2i = _player_cell()
	_zone(centre + Vector2i(-2, 0), -40, 2, &"")
	_zone(centre + Vector2i(4, 0), 15, 1, &"mozh")
	var charged: TileState = controller.tile_state_at(centre + Vector2i(1, 3))
	if charged != null:
		charged.apply_residue(&"khash")
		charged.apply_residue(&"khash")
	controller.configure_weather(&"mozh")
	await _open_shell()
	shell.bottom_tabs.current_tab = panel.get_index()
	panel.set_overlay_visible(true)
	panel.refresh({"scene_root": world})
	_motion(_screen(centre + Vector2i(-2, 0)))
	var image: Image = await _render()
	# The thinned zone reads violet-ward of the field's own accord around it.
	var inside: Color = image.get_pixelv(Vector2i(_screen(centre + Vector2i(-3, -1))))
	var outside: Color = image.get_pixelv(Vector2i(_screen(centre + Vector2i(-3, -5))))
	assert_float(inside.b - inside.g).override_failure_message("inside %s outside %s" % [inside, outside]).is_greater(outside.b - outside.g)
	image.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	assert_int(image.save_jpg(directory.path_join("accord-heatmap-wilds.jpg"), 0.82)).is_equal(OK)


# --- helpers -----------------------------------------------------------------------------------


func _open_shell() -> void:
	shell = SHELL.instantiate() as WeftluminShell
	var adapter := FixtureAdapter.new()
	adapter.world = world
	shell.adapter = adapter
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	panel = shell.bottom_tabs.find_child("Accord overlay", false, false) as WeftluminAccordOverlayPanel
	var focus: Vector2 = field.iso_grid().cell_to_world(_player_cell())
	shell.camera.zoom = Vector2.ONE
	shell.camera.position = focus - (shell.viewport_surface.get_global_rect().get_center() - get_viewport().get_visible_rect().size / 2.0)
	shell.camera.force_update_scroll()


func _player_cell() -> Vector2i:
	var player := world.find_child("Player", true, false) as Node2D
	return field.iso_grid().world_to_cell(player.global_position)


func _zone(cell: Vector2i, delta: int, half: int, element: StringName) -> AccordZone:
	var zone := ZONE_SCENE.instantiate() as AccordZone
	zone.name = "AccordZone%s" % ("Thinned" if delta < 0 else "Blessed")
	zone.accord_delta = delta
	zone.half_width_cells = half
	zone.half_height_cells = half
	zone.element_default = element
	field.add_child(zone)
	zone.global_position = field.iso_grid().cell_to_world(cell)
	return zone


func _start_battle() -> CombatController:
	var hostile := load("res://actors/hostile/hostile.tscn").instantiate() as Hostile
	hostile.name = "AccordOverlayWight"
	hostile.unit_id = &"bog-wight"
	hostile.alert_radius = 0.0
	world.add_child(hostile)
	hostile.global_position = field.iso_grid().cell_to_world(_player_cell() + Vector2i(3, 3))
	hostile.sync_cell()
	var opened := Battle.start_session(field, hostile)
	assert_bool(opened.get("allowed", false)).override_failure_message(str(opened)).is_true()
	return Battle.controller


func _screen(cell: Vector2i) -> Vector2:
	return get_viewport().canvas_transform * field.iso_grid().cell_to_world(cell)


func _render() -> Image:
	panel._redraw()
	await get_tree().process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)


func _button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)


func _remove_tree(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for directory: String in DirAccess.get_directories_at(absolute):
		_remove_tree(path.path_join(directory))
	for file: String in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(file))
	DirAccess.remove_absolute(absolute)
