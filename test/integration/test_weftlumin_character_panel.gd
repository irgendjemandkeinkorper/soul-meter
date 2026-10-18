extends GdUnitTestSuite
## E5.1 (#347): the Characters panel in the Weftlumin shell. One form for every declared kind,
## built from the kind's contract; stats rendered from their schema; portrait/sprite pickers;
## drafts under user:// only; the vault_id rules (required on create for recruits, never
## renamed, never generated); runtime state untouched.

const FIELD := preload("res://world/test_room.tscn")
const PLAYING := "StateChart/Root/Playing/"
const CharacterModelScript := preload("res://weftlumin/panels/models/character_roster.gd")
const SCRATCH_DRAFTS := "user://gdunit-weftlumin-character-drafts"
const SCRATCH_VAULT := "user://gdunit-weftlumin-character-vault"
const ROSTER_PATH := "res://data/generated/dom_npc_roster.json"
const CAPTURE_WIDTH := 1100

var _field_scene: Node2D
var _force_before := false
var _loading_connected := false
var _title_connected := false


func before_test() -> void:
	_force_before = WeftluminBootstrap.force_enabled_for_tests
	WeftluminBootstrap.close()
	_remove_tree(SCRATCH_DRAFTS)
	_remove_tree(SCRATCH_VAULT)
	DirAccess.make_dir_recursive_absolute(SCRATCH_VAULT)
	var index := FileAccess.open(SCRATCH_VAULT.path_join("index.json"), FileAccess.WRITE)
	index.store_string(JSON.stringify({"entities": [
		{"id": "serai-lun", "name": "Serai-Lun", "type": "character"},
		{"id": "themka-gaath", "name": "Themka Gaath", "type": "character"},
	]}))
	index.close()
	var loading: Node = GameFlow.get_node(PLAYING + "Loading")
	_loading_connected = loading.state_entered.is_connected(GameFlow._on_loading_entered)
	if _loading_connected:
		loading.state_entered.disconnect(GameFlow._on_loading_entered)
	var title: Node = GameFlow.get_node("StateChart/Root/Menus/Title")
	_title_connected = title.state_entered.is_connected(GameFlow._on_title_entered)
	if _title_connected:
		title.state_entered.disconnect(GameFlow._on_title_entered)
	GameState._seed_demo_data()
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
	_remove_tree(SCRATCH_VAULT)


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


func _open_panel() -> WeftluminCharacterPanel:
	WeftluminBootstrap.open()
	var shell := WeftluminBootstrap.get_child(0) as WeftluminShell
	var panel := shell.bottom_tabs.get_node("Characters") as WeftluminCharacterPanel
	panel.model.set("drafts_root_for_tests", SCRATCH_DRAFTS)
	panel.model.set("vault_index_path_for_tests", SCRATCH_VAULT.path_join("index.json"))
	panel.reload()
	shell.bottom_tabs.current_tab = shell.bottom_tabs.get_tab_idx_from_control(panel)
	return panel


func _canon_bytes() -> Dictionary:
	var bytes: Dictionary = {}
	for file_name: String in DirAccess.get_files_at("res://canon/dom/characters"):
		bytes[file_name] = FileAccess.get_file_as_bytes("res://canon/dom/characters".path_join(file_name))
	bytes[ROSTER_PATH] = FileAccess.get_file_as_bytes(ROSTER_PATH)
	return bytes


func test_panel_mounts_and_builds_each_kind_from_its_contract() -> void:
	var panel := _open_panel()
	assert_object(panel.model.get_parent()).is_same(panel)
	assert_bool(panel.model.call("is_enabled")).is_true()
	assert_bool(panel.needs_sandbox).is_false()
	# Sixty Dom, six Kesselford (C1 / #238), six Ashlaren (C2 / #239) and five Long Verge
	# (C3 / #240) npcs plus the six archetypes.
	assert_int(panel.character_ids().size()).is_equal(83)
	assert_int(panel.character_ids("archetype").size()).is_equal(6)
	panel.select_character("sella-varn")
	assert_str(panel.identity_label.text).contains("sella-varn · npc")
	# The npc form is the npc contract: no stats, routine as structured text, the offset as a pair.
	assert_array(panel.field_names()).contains(["role", "placement_offset", "routine", "phase_agnostic"])
	assert_array(panel.field_names()).not_contains(["stats", "element_id"])
	assert_array(panel.stat_keys()).is_empty()
	assert_str(String(panel.portrait_option.get_item_metadata(panel.portrait_option.selected))) \
		.is_equal("res://assets/generated/portraits/sella_varn_portrait_neutral.png")
	assert_object(panel.portrait_preview.texture).is_not_null()
	assert_object(panel.sprite_preview.texture).is_not_null()
	assert_dict(panel.edits()).is_empty()
	# The archetype form renders its stats from the schema, in DramgidSchema's order.
	panel.select_character("bog-wight")
	assert_array(panel.field_names()).contains(["element_id", "attribute_note", "anatomy"])
	assert_array(panel.field_names()).not_contains(["role"])
	var keys: Array[String] = panel.stat_keys()
	for index: int in DramgidSchema.ATTRIBUTE_IDS.size():
		assert_str(keys[index]).is_equal(DramgidSchema.ATTRIBUTE_IDS[index])
	assert_str(String(panel.stat_schema_option.get_item_metadata(panel.stat_schema_option.selected))).is_equal("dramgid.v1")
	assert_dict(panel.edits()).is_empty()


func test_saving_writes_only_a_draft_and_the_bake_preview_plans_it() -> void:
	var committed: Dictionary = _canon_bytes()
	var state_before: Dictionary = GameState.to_dict().duplicate(true)
	var panel := _open_panel()
	var clean: Dictionary = panel.preview_bake()
	assert_bool(WeftluminCharactersKind.report_is_clean(clean)).is_true()
	panel.select_character("sella-varn")
	panel.set_field("role", "Bell keeper")
	panel.set_field("sprite_unit_id", "bog-wight")
	assert_dict(panel.edits()).is_equal({"role": "Bell keeper", "sprite_unit_id": "bog-wight"})
	assert_bool(panel.save()).is_true()
	assert_str(panel.errors_text()).is_empty()
	var draft_path := SCRATCH_DRAFTS.path_join("sella-varn.json")
	var draft: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(draft_path))
	assert_str(String(draft["role"])).is_equal("Bell keeper")
	assert_str(String(draft["sprite_unit_id"])).is_equal("bog-wight")
	assert_str(panel.identity_label.text).contains("draft")
	assert_bool(panel.notes_label.visible).is_true()
	assert_str(panel.notes_label.text).contains("sprite_unit_id")
	var report: Dictionary = panel.preview_bake()
	var changed: Array[String] = []
	for entry: Dictionary in report["planned"]:
		if entry["action"] != "unchanged":
			changed.append(String(entry["path"]))
	assert_array(changed).contains_exactly(["res://canon/dom/characters/sella-varn.json"])
	assert_str(panel.report_box.text).contains("regenerate  %s" % ROSTER_PATH)
	# Editing a stat writes the block back whole, untouched keys included.
	panel.select_character("bog-wight")
	panel.set_stat("grit", "3")
	assert_bool(panel.save()).is_true()
	var wight: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH_DRAFTS.path_join("bog-wight.json")))
	assert_int(int(wight["stats"]["grit"])).is_equal(3)
	assert_int(int(wight["stats"]["balance_pressure"])).is_equal(18)
	# Nothing under res:// moved, and no runtime state changed.
	assert_bool(_canon_bytes() == committed).is_true()
	assert_dict(GameState.to_dict()).is_equal(state_before)
	panel.select_character("sella-varn")
	panel.discard()
	assert_bool(FileAccess.file_exists(draft_path)).is_false()
	assert_str(panel.identity_label.text).contains("canon")


func test_invalid_edits_and_identity_changes_are_refused() -> void:
	var panel := _open_panel()
	panel.select_character("bog-wight")
	panel.set_stat("grit", "1.5")
	assert_bool(panel.save()).is_false()
	assert_str(panel.errors_text()).contains("grit")
	panel.select_character("sella-varn")
	panel.set_field("routine", "{not json")
	assert_bool(panel.save()).is_false()
	assert_str(panel.errors_text()).contains("routine")
	var identity: Array = panel.model.call("save_draft", "sella-varn", {"kind": "archetype"})
	assert_str(String(identity[0]["code"])).is_equal("read_only_field")
	var renamed: Array = panel.model.call("save_draft", "themka-gaath", {"vault_id": "serai-lun"})
	assert_str(String(renamed[0]["code"])).is_equal("vault_id_rename")
	panel.select_character("themka-gaath")
	assert_bool((panel.get_node("Scroll/Content/Fields").find_child("VaultId", true, false) as LineEdit).editable).is_false()
	assert_bool(DirAccess.dir_exists_absolute(SCRATCH_DRAFTS) and not DirAccess.get_files_at(SCRATCH_DRAFTS).is_empty()).is_false()


func test_a_recruit_needs_a_vault_character_to_be_created() -> void:
	var panel := _open_panel()
	panel.set_create("recruit", "probe-recruit", "Probe Recruit", "")
	assert_bool(panel.create()).is_false()
	assert_str(panel.errors_text()).contains("vault_id")
	panel.set_create("recruit", "probe-recruit", "Probe Recruit", "not-in-the-vault")
	assert_bool(panel.create()).is_false()
	assert_str(panel.errors_text()).contains("not a character in the lore-vault index")
	assert_bool(FileAccess.file_exists(SCRATCH_DRAFTS.path_join("probe-recruit.json"))).is_false()
	panel.set_create("recruit", "probe-recruit", "Probe Recruit", "serai-lun")
	assert_bool(panel.create()).is_true()
	assert_str(panel.selected_character()).is_equal("probe-recruit")
	assert_str(panel.identity_label.text).contains("vault serai-lun · new draft")
	assert_array(panel.field_names()).contains(["recruit", "vault_id"])
	panel.set_field("recruit.patron", "Maiiam")
	panel.set_field("recruit.min_reputation", "5")
	assert_bool(panel.save()).is_true()
	var draft: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH_DRAFTS.path_join("probe-recruit.json")))
	assert_str(String(draft["vault_id"])).is_equal("serai-lun")
	assert_str(String(draft["recruit"]["patron"])).is_equal("Maiiam")
	assert_int(int(draft["recruit"]["min_reputation"])).is_equal(5)
	var report: Dictionary = panel.preview_bake()
	assert_str(panel.report_box.text).contains("create  res://canon/dom/characters/probe-recruit.json")
	assert_array(report["regenerated"]).is_empty()
	panel.discard()
	assert_array(panel.character_ids()).not_contains(["probe-recruit"])


func test_hosting_seam_refuses_a_detached_model() -> void:
	var detached: Node = auto_free(CharacterModelScript.new()) as Node
	assert_bool(bool(detached.call("host_in_panel"))).is_false()
	assert_array(detached.call("character_ids", "")).is_empty()
	assert_str(String((detached.call("create", "recruit", "x", "X", "serai-lun") as Array)[0]["code"])).is_equal("not_hosted")


## Rendered evidence: the Characters tab for an archetype (schema-rendered stats) and a new
## recruit draft with its bake preview. Set SOUL_METER_CHARACTER_PANEL_CAPTURE_DIR, run under Xvfb.
func test_rendered_character_panel_capture() -> void:
	var capture_dir := OS.get_environment("SOUL_METER_CHARACTER_PANEL_CAPTURE_DIR")
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	assert_int(DirAccess.make_dir_recursive_absolute(capture_dir)).is_equal(OK)
	var panel := _open_panel()
	var shell := WeftluminBootstrap.get_child(0) as WeftluminShell
	panel.select_character("sella-varn")
	await _capture(shell, panel, capture_dir.path_join("character-panel-npc.png"))
	panel.select_character("bog-wight")
	var scroll := panel.get_node("Scroll") as ScrollContainer
	await get_tree().process_frame
	scroll.scroll_vertical = int((panel.get_node("Scroll/Content/Stats") as Control).position.y) - 8
	await _capture(shell, panel, capture_dir.path_join("character-panel-archetype-stats.png"))
	panel.set_create("recruit", "probe-recruit", "Probe Recruit", "")
	assert_bool(panel.create()).is_false()
	scroll.scroll_vertical = 0
	await _capture(shell, panel, capture_dir.path_join("character-panel-recruit-refused.png"))


func _capture(shell: WeftluminShell, panel: WeftluminCharacterPanel, path: String) -> void:
	await get_tree().create_timer(0.3).timeout
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var dock := Rect2i(shell.bottom_tabs.get_global_rect())
	# The form's content sits on the left; cropping keeps the evidence under the size budget.
	dock.size.x = mini(dock.size.x, CAPTURE_WIDTH)
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
