extends GdUnitTestSuite
## E4.2 (#346): the Spawns tab in the real dock. It edits a spawn table as a draft under user://,
## refuses invariant violations with attributed errors, places a `SpawnSlot<PascalCase>` anchor
## marker through the scene model with real pointer edges, and shows live slot state that the
## `[debug]` console verbs change.

const SHELL := preload("res://addons/weftlumin/shell/shell.tscn")
const HOST_ADAPTER := preload("res://addons/weftlumin/shell/soul_meter_adapter.gd")
const SCENE_PANEL := preload("res://weftlumin/panels/scene_panel.tscn")
const SPAWN_PANEL := preload("res://weftlumin/panels/spawn_panel.tscn")
const CONSOLE_PANEL := preload("res://weftlumin/panels/console_panel.tscn")
const Recovery := preload("res://globals/layout_recovery.gd")
## The canon table targets the Wilds test room (`wilderness`); the fixture stands in for it.
const SCENE := "res://world/test_room.tscn"
const TABLE_ID := "wilds-glade-ambient"
const CANON_FILE := "res://canon/dom/spawn_tables/wilds-glade-ambient.json"
const SCRATCH_DRAFTS := "user://gdunit-weftlumin-spawn-drafts"


class FixtureAdapter extends WeftluminGameAdapter:
	var world: Node
	var previous_paused := false

	func gameplay_scene_root() -> Node:
		return world

	func theme() -> Theme:
		return UIManager.ui_theme

	func panels() -> Array[PackedScene]:
		return [SCENE_PANEL, CONSOLE_PANEL, SPAWN_PANEL]

	func placeables() -> Array[WeftluminPlaceable]:
		return HOST_ADAPTER.new().placeables()

	func set_editor_open(open: bool) -> void:
		if open:
			previous_paused = world.get_tree().paused
			world.get_tree().paused = true
		else:
			world.get_tree().paused = previous_paused


var world: Node2D
var shell: WeftluminShell
var panel: WeftluminSpawnPanel
var _previous_scene: Node
var _previous_paused := false
var _hidden: Array[CanvasItem] = []
var _spawns_before: Dictionary
var _clock_before: Dictionary
var _game_state_before: Dictionary


func before_test() -> void:
	_spawns_before = SaveGame.spawn_director.to_dict()
	_clock_before = WorldClock.to_dict()
	_game_state_before = GameState.to_dict().duplicate(true)
	SaveGame.spawn_director.from_dict({})
	SpawnDirector.set_tables_for_testing({}, true)
	_remove_tree(SCRATCH_DRAFTS)
	_previous_scene = get_tree().current_scene
	_previous_paused = get_tree().paused
	await UIManager.close_all()
	get_tree().paused = false
	for child: Node in get_tree().root.get_children():
		if child is CanvasItem and child.visible:
			_hidden.append(child)
			child.hide()
	# The test room's own `.tscn` holds SpawnSlotGladeSouth; this live stand-in does not, so the
	# panel has an anchor to place.
	world = Node2D.new()
	world.name = "SpawnPanelFixture"
	world.scene_file_path = SCENE
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	shell = SHELL.instantiate() as WeftluminShell
	var adapter := FixtureAdapter.new()
	adapter.world = world
	shell.adapter = adapter
	add_child(shell)
	for _frame: int in 3:
		await get_tree().process_frame
	shell.camera.zoom = Vector2.ONE
	shell.camera.position = Vector2.ZERO
	shell.camera.force_update_scroll()
	panel = shell.bottom_tabs.get_node("Spawns") as WeftluminSpawnPanel
	panel.model.set("drafts_root_for_tests", SCRATCH_DRAFTS)
	shell.bottom_tabs.current_tab = shell.bottom_tabs.get_tab_idx_from_control(panel)
	panel.reload()
	await get_tree().process_frame


func after_test() -> void:
	if is_instance_valid(shell):
		shell.close()
		await get_tree().process_frame
	if is_instance_valid(world):
		world.free()
	assert_int(Recovery.clear(SCENE)).is_equal(OK)
	get_tree().current_scene = _previous_scene if is_instance_valid(_previous_scene) else null
	for item: CanvasItem in _hidden:
		if is_instance_valid(item):
			item.show()
	_hidden.clear()
	get_tree().paused = _previous_paused
	SpawnDirector.set_tables_for_testing({}, true)
	SaveGame.spawn_director.from_dict(_spawns_before)
	WorldClock.from_dict(_clock_before)
	assert_bool(GameState.from_dict(_game_state_before)).is_true()
	_remove_tree(SCRATCH_DRAFTS)


func _press(button: Button) -> void:
	await get_tree().process_frame
	var at: Vector2 = button.get_global_rect().get_center()
	_motion(at)
	for pressed: bool in [true, false]:
		_edge(at, pressed)
	await get_tree().process_frame


func _click_viewport(local: Vector2) -> void:
	var at: Vector2 = shell.viewport_surface.get_global_rect().position + local
	_motion(at)
	for pressed: bool in [true, false]:
		_edge(at, pressed)
	await get_tree().process_frame


func _motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)


func _edge(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _console() -> Node:
	return (shell.bottom_tabs.get_node("Console") as SoulMeterToolPanel).model


func test_panel_mounts_its_hosted_model_and_shows_the_canon_table() -> void:
	assert_object(panel.model.get_parent()).is_same(panel)
	assert_bool(bool(panel.model.call("is_enabled"))).is_true()
	assert_array(panel.table_ids()).contains([TABLE_ID])
	panel.select_table(TABLE_ID)
	assert_str(panel.identity_label.text).contains(SCENE).contains("canon")
	assert_str(panel.anchor_edit.text).is_equal("SpawnSlotGladeSouth")
	assert_float(panel.respawn_spin.value).is_equal(1.0)
	assert_str(panel.entries_box.text).is_equal("bog-wight = 40\nloam-maddened-boar = 40\nempty = 20")
	assert_str(panel.live_text()).contains("glade-south").contains("MISSING").contains("never rolled")


func test_placing_an_anchor_adds_a_named_marker_as_one_undo_step() -> void:
	panel.select_table(TABLE_ID)
	await _press(panel.get_node("Scroll/Content").find_child("PlaceAnchor", true, false) as Button)
	assert_str(panel.status_text()).contains("SpawnSlotGladeSouth")
	await _click_viewport(shell.viewport_surface.size / 2.0)
	var marker := world.get_node_or_null("SpawnSlotGladeSouth") as Marker2D
	assert_object(marker).is_not_null()
	assert_bool(marker.has_meta(WeftluminSceneModel.PLACED_META)).is_true()
	var session := WeftluminSceneModel.session_for(world)
	var logged: Dictionary = session.bus.log_entries().back()
	assert_str(str(logged["params"]["instance"]["name"])).is_equal("SpawnSlotGladeSouth")
	assert_str(str(logged["params"]["instance"]["placeable"])).is_equal("spawn_slot")
	assert_str(panel.live_text()).not_contains("MISSING")
	# Placing it again is refused; undo removes it and the slot reads missing again.
	assert_bool(panel.place_anchor()).is_false()
	session.undo()
	assert_object(world.get_node_or_null("SpawnSlotGladeSouth")).is_null()
	assert_str(panel.live_text()).contains("MISSING")
	# Redo re-attaches the same marker (and leaves no detached node behind).
	session.redo()
	assert_object(world.get_node_or_null("SpawnSlotGladeSouth")).is_same(marker)


func test_live_state_follows_the_debug_console_verbs() -> void:
	panel.select_table(TABLE_ID)
	await _press(panel.find_child("PlaceAnchor", true, false) as Button)
	await _click_viewport(shell.viewport_surface.size / 2.0)
	WorldClock.phase_count = 2 * WorldClock.PHASES.size()
	var key := "%s:glade-south" % TABLE_ID
	assert_bool(bool(_console().call("execute_command", "respawn now %s" % key))).is_true()
	panel.refresh_live()
	var state: Dictionary = SaveGame.spawn_director.slot_state(TABLE_ID, "glade-south")
	if (state["members"] as Array).is_empty():
		assert_str(panel.live_text()).contains("cleared day 2")
	else:
		assert_str(panel.live_text()).contains("alive").contains("%s:2" % key)
	assert_bool(bool(_console().call("execute_command", "clear slot %s" % key))).is_true()
	panel.refresh_live()
	assert_str(panel.live_text()).contains("cleared day 2")


func test_saving_writes_only_a_draft_in_the_canon_layout() -> void:
	var canon_before := FileAccess.get_file_as_string(CANON_FILE)
	panel.select_table(TABLE_ID)
	# An unchanged save is byte-identical to canon: promoting a draft is a copy.
	assert_bool(panel.save()).override_failure_message(panel.errors_text()).is_true()
	var draft_path := SCRATCH_DRAFTS.path_join("%s.json" % TABLE_ID)
	assert_str(FileAccess.get_file_as_string(draft_path)).is_equal(canon_before)
	panel.set_field("respawn_days", 2)
	panel.set_field("entries", "bog-wight = 30\nempty = 10")
	panel.set_field("max_alive", 6)
	assert_bool(panel.save()).is_true()
	var draft: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(draft_path))
	assert_int(int(draft["slots"][0]["respawn_days"])).is_equal(2)
	assert_int((draft["slots"][0]["entries"] as Array).size()).is_equal(2)
	assert_int(int(draft["caps"]["max_alive"])).is_equal(6)
	assert_str(panel.identity_label.text).contains("draft")
	assert_str(FileAccess.get_file_as_string(CANON_FILE)).is_equal(canon_before)
	panel.discard()
	assert_bool(FileAccess.file_exists(draft_path)).is_false()
	assert_str(panel.identity_label.text).contains("canon")


func test_invariant_violations_are_refused_with_attributed_errors() -> void:
	panel.select_table(TABLE_ID)
	panel.set_field("entries", "empty = 20")
	assert_bool(panel.save()).is_false()
	assert_str(panel.errors_text()).contains("slots[0].entries")
	panel.select_table(TABLE_ID)
	panel.set_field("entries", "bog-wight = lots")
	assert_bool(panel.save()).is_false()
	assert_str(panel.errors_text()).contains("slots[0].entries[0].weight")
	panel.select_table(TABLE_ID)
	panel.set_field("entries", "bog-wight")
	assert_bool(panel.save()).is_false()
	assert_str(panel.errors_text()).contains("Entries line 1")
	# A new slot's anchor must exist: refused until it is placed in the live scene.
	panel.select_table(TABLE_ID)
	assert_bool(panel.add_slot("hollow-east")).is_true()
	assert_str(panel.anchor_edit.text).is_equal("SpawnSlotHollowEast")
	panel.set_field("entries", "bog-wight = 5")
	assert_bool(panel.save()).is_false()
	assert_str(panel.errors_text()).contains("slots[1].anchor").contains("SpawnSlotHollowEast")
	assert_bool(panel.place_anchor()).is_true()
	await _click_viewport(shell.viewport_surface.size / 2.0 + Vector2(96, 48))
	assert_object(world.get_node_or_null("SpawnSlotHollowEast")).is_not_null()
	assert_bool(panel.save()).override_failure_message(panel.errors_text()).is_true()
	assert_str(panel.notes_label.text).contains("SpawnSlotHollowEast").contains("E3.5")
	assert_bool(DirAccess.dir_exists_absolute(SCRATCH_DRAFTS)).is_true()
	# Identity is read-only even through the model.
	var row: Dictionary = panel.model.call("document", TABLE_ID)
	row["scene_path"] = "res://world/wound_lip.tscn"
	var errors: Array = panel.model.call("save_draft", TABLE_ID, row)
	assert_str(String(errors[0]["code"])).is_equal("read_only_field")


## Rendered evidence: the Spawns tab with a placed SpawnSlot marker and a live pack.
## Set SOUL_METER_SPAWN_PANEL_CAPTURE_DIR and run under Xvfb (not headless).
func test_rendered_spawn_panel_capture() -> void:
	var capture_dir := OS.get_environment("SOUL_METER_SPAWN_PANEL_CAPTURE_DIR")
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	assert_int(DirAccess.make_dir_recursive_absolute(capture_dir)).is_equal(OK)
	panel.select_table(TABLE_ID)
	await _press(panel.find_child("PlaceAnchor", true, false) as Button)
	await _click_viewport(shell.viewport_surface.size / 2.0)
	assert_object(world.get_node_or_null("SpawnSlotGladeSouth")).is_not_null()
	# Find a day whose roll is a pack, so the capture shows hostiles at the anchor.
	var key := "%s:glade-south" % TABLE_ID
	for day: int in 12:
		WorldClock.phase_count = day * WorldClock.PHASES.size()
		_console().call("execute_command", "respawn now %s" % key)
		if not (SaveGame.spawn_director.slot_state(TABLE_ID, "glade-south")["members"] as Array).is_empty():
			break
	panel.refresh_live()
	assert_str(panel.live_text()).contains("alive")
	await get_tree().create_timer(0.3).timeout
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	frame.resize(frame.get_width() / 2, frame.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	assert_int(frame.save_png(capture_dir.path_join("spawn-panel-placed-slot.png"))).is_equal(OK)
	# The tab scrolled to its live slot state, at full resolution.
	var scroll := panel.get_node("Scroll") as ScrollContainer
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await get_tree().create_timer(0.2).timeout
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var full: Image = get_viewport().get_texture().get_image()
	var dock := Rect2i(shell.bottom_tabs.get_global_rect()).intersection(Rect2i(Vector2i.ZERO, full.get_size()))
	assert_int(full.get_region(dock).save_png(capture_dir.path_join("spawn-panel-live-state.png"))).is_equal(OK)


func _remove_tree(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for child: String in DirAccess.get_directories_at(absolute):
		_remove_tree(absolute.path_join(child))
	for file_name: String in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(file_name))
	DirAccess.remove_absolute(absolute)
