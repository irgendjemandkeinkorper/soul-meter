extends GdUnitTestSuite
## E3.3a (#341): the Locations panel in the Weftlumin shell. It edits a location's hidden
## state as a draft under user://, refuses invalid edits with attributed errors, previews the
## bake without writing res://, and never touches runtime state.

const FIELD := preload("res://world/test_room.tscn")
const PLAYING := "StateChart/Root/Playing/"
const LocationModelScript := preload("res://weftlumin/panels/models/location_metadata.gd")
const SCRATCH_DRAFTS := "user://gdunit-weftlumin-location-drafts"

var _field_scene: Node2D
var _force_before := false
var _loading_connected := false
var _title_connected := false
var _game_state_before: Dictionary


func before_test() -> void:
	_force_before = WeftluminBootstrap.force_enabled_for_tests
	WeftluminBootstrap.close()
	_remove_tree(SCRATCH_DRAFTS)
	var loading: Node = GameFlow.get_node(PLAYING + "Loading")
	_loading_connected = loading.state_entered.is_connected(GameFlow._on_loading_entered)
	if _loading_connected:
		loading.state_entered.disconnect(GameFlow._on_loading_entered)
	var title: Node = GameFlow.get_node("StateChart/Root/Menus/Title")
	_title_connected = title.state_entered.is_connected(GameFlow._on_title_entered)
	if _title_connected:
		title.state_entered.disconnect(GameFlow._on_title_entered)
	GameState._seed_demo_data()
	_game_state_before = GameState.to_dict().duplicate(true)
	_field_scene = FIELD.instantiate() as Node2D
	add_child(_field_scene)
	await _enter_active()
	UIManager.close_all()
	get_tree().paused = false
	WeftluminBootstrap.force_enabled_for_tests = true


func after_test() -> void:
	WeftluminBootstrap.close()
	WeftluminBootstrap.force_enabled_for_tests = _force_before
	await _enter_active()
	GameFlow.send_event(&"pause")
	GameFlow.send_event(&"to_main_menu")
	await get_tree().process_frame
	var loading: Node = GameFlow.get_node(PLAYING + "Loading")
	if _loading_connected:
		loading.state_entered.connect(GameFlow._on_loading_entered)
	var title: Node = GameFlow.get_node("StateChart/Root/Menus/Title")
	if _title_connected:
		title.state_entered.connect(GameFlow._on_title_entered)
	UIManager.close_all()
	get_tree().paused = false
	_field_scene.free()
	_remove_tree(SCRATCH_DRAFTS)


func _enter_active() -> void:
	GameFlow.set_editor_open(false)
	if _active("Paused"):
		GameFlow.chart.set_expression_property(&"resume_to_battle", false)
		GameFlow.send_event(&"resume")
	if _active("Battle"):
		GameFlow.send_event(&"battle_end")
	if _active("ChapterComplete"):
		GameFlow.send_event(&"continue_exploring")
	GameFlow.send_event(&"boot_done")
	GameFlow.send_event(&"new_game")
	GameFlow.send_event(&"intro_done")
	GameFlow.send_event(&"level_ready")
	await get_tree().process_frame
	assert_bool(_active("Active")).is_true()


func _active(state: String) -> bool:
	return bool(GameFlow.get_node(PLAYING + state).get("active"))


func _open_panel() -> WeftluminLocationPanel:
	WeftluminBootstrap.open()
	var shell := WeftluminBootstrap.get_child(0) as WeftluminShell
	var panel := shell.bottom_tabs.get_node("Locations") as WeftluminLocationPanel
	panel.model.set("drafts_root_for_tests", SCRATCH_DRAFTS)
	panel.reload()
	shell.bottom_tabs.current_tab = shell.bottom_tabs.get_tab_idx_from_control(panel)
	return panel


func _committed_bytes() -> Dictionary:
	var bytes: Dictionary = {}
	for definition: LocationDefinition in LocationRegistry.ALL:
		bytes[definition.resource_path] = FileAccess.get_file_as_bytes(definition.resource_path)
	bytes[WeftluminLocationsKind.INDEX_PATH] = FileAccess.get_file_as_bytes(WeftluminLocationsKind.INDEX_PATH)
	return bytes


func test_panel_mounts_with_a_private_hosted_model_listing_every_scene_location() -> void:
	var panel := _open_panel()
	assert_object(panel.model).is_not_null()
	assert_object(panel.model.get_parent()).is_same(panel)
	assert_bool(panel.model.call("is_enabled")).is_true()
	assert_bool(panel.needs_sandbox).is_false()
	assert_int(panel.location_ids().size()).is_equal(LocationRegistry.ALL.size())
	for definition: LocationDefinition in LocationRegistry.ALL:
		assert_array(panel.location_ids()).contains([String(definition.id)])
	panel.select_location("wound_lip")
	assert_float(panel.accord_spin.value).is_equal(LocationRegistry.WOUND_LIP.harmonic_accord)
	assert_float(panel.tier_spin.value).is_equal(float(LocationRegistry.WOUND_LIP.thinning_tier))
	assert_str(String(panel.weather_option.get_item_metadata(panel.weather_option.selected))).is_equal("khash")
	assert_str(panel.arrival_flag_edit.text).is_equal(LocationRegistry.WOUND_LIP.arrival_flag)
	assert_bool(panel.no_combat_check.button_pressed).is_false()
	panel.select_location("bell_house_interior")
	assert_bool(panel.no_combat_check.button_pressed).is_true()
	assert_str(panel.spawns_box.text).is_equal("entry = entry\nfrom_bell_loft = from_bell_loft")


func test_hosting_seam_refuses_a_detached_model() -> void:
	var detached: Node = auto_free(LocationModelScript.new()) as Node
	assert_bool(bool(detached.call("host_in_panel"))).is_false()
	assert_bool(bool(detached.call("is_enabled"))).is_false()
	assert_array(detached.call("location_ids")).is_empty()
	assert_str(String((detached.call("save_draft", "wilds", {"harmonic_accord": 80.0}) as Array)[0]["code"])) \
		.is_equal("not_hosted")


func test_saving_writes_only_a_draft_and_the_bake_preview_plans_that_definition() -> void:
	var committed: Dictionary = _committed_bytes()
	var canon_before := FileAccess.get_file_as_string("res://canon/dom/locations/wilds.json")
	var state_before: Dictionary = GameState.to_dict().duplicate(true)
	var panel := _open_panel()
	panel.select_location("wilds")
	var clean: Dictionary = panel.preview_bake()
	assert_bool(WeftluminLocationsKind.report_is_clean(clean)).is_true()
	panel.set_field("harmonic_accord", 80.0)
	panel.set_field("spawns", "from_dom = from_dom\nfrom_road = from_dom")
	assert_bool(panel.save()).is_true()
	assert_str(panel.errors_text()).is_empty()
	var draft_path := SCRATCH_DRAFTS.path_join("wilds.json")
	assert_bool(FileAccess.file_exists(draft_path)).is_true()
	var draft: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(draft_path))
	assert_float(float(draft["harmonic_accord"])).is_equal(80.0)
	assert_dict(draft["spawns"]).is_equal({"from_dom": "from_dom", "from_road": "from_dom"})
	assert_str(String(draft["scene_path"])).is_equal("res://world/test_room.tscn")
	assert_str(panel.identity_label.text).contains("draft")
	var report: Dictionary = panel.preview_bake()
	var changed: Array[String] = []
	for entry: Dictionary in report["planned"]:
		if entry["action"] != "unchanged":
			changed.append(String(entry["path"]))
	# Accord and spawns live in the definition only; the index row is unchanged.
	assert_array(changed).contains_exactly(["res://world/locations/wilds.tres"])
	assert_str(panel.report_box.text).contains("update  res://world/locations/wilds.tres")
	# Nothing under res:// moved, and no runtime state changed.
	assert_bool(_committed_bytes() == committed).is_true()
	assert_str(FileAccess.get_file_as_string("res://canon/dom/locations/wilds.json")).is_equal(canon_before)
	assert_float(LocationRegistry.WILDS.harmonic_accord).is_equal(85.0)
	assert_dict(GameState.to_dict()).is_equal(state_before)
	# Discarding returns the form to canon.
	panel.discard()
	assert_bool(FileAccess.file_exists(draft_path)).is_false()
	assert_float(panel.accord_spin.value).is_equal(85.0)
	assert_str(panel.identity_label.text).contains("canon")


func test_invalid_edits_are_refused_with_attributed_errors_and_write_nothing() -> void:
	var panel := _open_panel()
	panel.select_location("dorthkor_road")
	panel.set_field("default_spawn_id", "")
	assert_bool(panel.save()).is_false()
	assert_str(panel.errors_text()).contains("default_spawn_id")
	panel.select_location("dorthkor_road")
	panel.set_field("spawns", "from_dom from_dom")
	assert_bool(panel.save()).is_false()
	assert_str(panel.errors_text()).contains("spawns")
	# Identity is not metadata: the model refuses it even when called directly.
	var errors: Array = panel.model.call("save_draft", "dorthkor_road", {"scene_path": "res://world/wound_lip.tscn"})
	assert_str(String(errors[0]["code"])).is_equal("read_only_field")
	# Field values are validated by the kind before anything is written.
	var collide: Array = panel.model.call("save_draft", "dorthkor_road", {"weather_default": "storm"})
	assert_str(String(collide[0]["code"])).is_equal("unknown_weather")
	assert_bool(DirAccess.dir_exists_absolute(SCRATCH_DRAFTS) and not DirAccess.get_files_at(SCRATCH_DRAFTS).is_empty()).is_false()


func test_a_no_combat_value_the_runtime_ignores_shows_a_note() -> void:
	var panel := _open_panel()
	panel.select_location("wilds")
	assert_bool(panel.notes_label.visible).is_false()
	panel.set_field("no_combat_zone", true)
	assert_bool(panel.save()).is_true()
	assert_bool(panel.notes_label.visible).is_true()
	assert_str(panel.notes_label.text).contains("E3.3b")


## Rendered evidence: the Locations tab for a macro location with a draft and its bake preview.
## Set SOUL_METER_LOCATION_PANEL_CAPTURE_DIR and run under Xvfb (not headless).
func test_rendered_location_panel_capture() -> void:
	var capture_dir := OS.get_environment("SOUL_METER_LOCATION_PANEL_CAPTURE_DIR")
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	assert_int(DirAccess.make_dir_recursive_absolute(capture_dir)).is_equal(OK)
	var panel := _open_panel()
	var shell := WeftluminBootstrap.get_child(0) as WeftluminShell
	panel.select_location("dorthkor_road")
	await _capture(shell, panel, capture_dir.path_join("location-panel-canon.png"))
	panel.set_field("harmonic_accord", 68.0)
	assert_bool(panel.save()).is_true()
	panel.preview_bake()
	var scroll := panel.get_node("Scroll") as ScrollContainer
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _capture(shell, panel, capture_dir.path_join("location-panel-draft-bake.png"))


func _capture(shell: WeftluminShell, panel: WeftluminLocationPanel, path: String) -> void:
	await get_tree().create_timer(0.3).timeout
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var dock := Rect2i(shell.bottom_tabs.get_global_rect())
	assert_bool(panel.is_visible_in_tree()).is_true()
	assert_int(frame.get_region(dock).save_png(path)).is_equal(OK)


func _remove_tree(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for child: String in DirAccess.get_directories_at(absolute):
		_remove_tree(absolute.path_join(child))
	for file_name: String in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(file_name))
	DirAccess.remove_absolute(absolute)
