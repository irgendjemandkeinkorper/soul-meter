extends GdUnitTestSuite
## E2.5a (#336): the five re-hosted tool models behind the WeftluminPanel contract.
## Each test drives a pinned behaviour from docs/weftlumin-test-migration.md through the
## panel the shell mounted, never through the legacy autoload.

const FIELD := preload("res://world/test_room.tscn")
const PLAYING := "StateChart/Root/Playing/"
const DevConsoleScript := preload("res://globals/dev_console.gd")
const CombatLabScript := preload("res://globals/combat_lab.gd")
const DialogueLabScript := preload("res://globals/dialogue_lab.gd")
const DOCK_ORDER: Array[String] = [
	"Console", "Command log", "Consequence timeline", "Validation",
	"Combat lab", "Dialogue lab", "Quest editor",
]
const REGISTRY := "the-registry"
const CAMPAIGN_ID := "gdunit-weftlumin-panel"
const SCRATCH_CAMPAIGNS_ROOT := "user://gdunit-weftlumin-panel-campaigns"

var _field_scene: Node2D
var _field: FieldMap
var _snapshot: Dictionary
var _game_state_before: Dictionary
var _reputation_before: Dictionary
var _renown_before: Dictionary
var _quests_before: Dictionary
var _rng_seed: int
var _rng_state: int
var _loading_connected := false
var _title_connected := false
var _force_before := false
var _recorder_force_before := false
var _recorder_root_before := ""


func before_test() -> void:
	_snapshot = SaveGame.capture_runtime_state()
	_game_state_before = GameState.to_dict().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)
	_quests_before = QuestRegistry.to_dict().duplicate(true)
	_rng_seed = SkillCheck.random_number_generator.seed
	_rng_state = SkillCheck.random_number_generator.state
	_force_before = WeftluminBootstrap.force_enabled_for_tests
	_recorder_force_before = bool(PlaytestRecorder.force_enabled_for_tests)
	_recorder_root_before = PlaytestRecorder.session_root_override
	PlaytestRecorder.force_enabled_for_tests = false
	WeftluminBootstrap.close()
	Battle.abandon()
	QuestRegistry.clear_runtime_quests()
	_remove_tree(SCRATCH_CAMPAIGNS_ROOT)
	var loading: Node = GameFlow.get_node(PLAYING + "Loading")
	_loading_connected = loading.state_entered.is_connected(GameFlow._on_loading_entered)
	if _loading_connected:
		loading.state_entered.disconnect(GameFlow._on_loading_entered)
	var title: Node = GameFlow.get_node("StateChart/Root/Menus/Title")
	_title_connected = title.state_entered.is_connected(GameFlow._on_title_entered)
	if _title_connected:
		title.state_entered.disconnect(GameFlow._on_title_entered)
	GameState._seed_demo_data()
	GameState.set_flag("defeated_bog_wight", false)
	_field_scene = FIELD.instantiate() as Node2D
	add_child(_field_scene)
	_field = _field_scene.get_node("FieldMap") as FieldMap
	await _enter_active()
	UIManager.close_all()
	get_tree().paused = false
	WeftluminBootstrap.force_enabled_for_tests = true


func after_test() -> void:
	WeftluminBootstrap.close()
	WeftluminBootstrap.force_enabled_for_tests = _force_before
	WeftluminSandbox.shared().disarm()
	Battle.abandon()
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
	QuestRegistry.clear_runtime_quests()
	_remove_tree(SCRATCH_CAMPAIGNS_ROOT)
	PlaytestRecorder.force_enabled_for_tests = false
	PlaytestRecorder.session_root_override = _recorder_root_before
	PlaytestRecorder.force_enabled_for_tests = _recorder_force_before
	assert_bool(SaveGame.restore_runtime_state(_snapshot)).is_true()
	assert_bool(GameState.from_dict(_game_state_before)).is_true()
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)
	QuestRegistry.from_dict(_quests_before)
	SkillCheck.random_number_generator.seed = _rng_seed
	SkillCheck.random_number_generator.state = _rng_state


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


func _open() -> WeftluminShell:
	WeftluminBootstrap.open()
	return WeftluminBootstrap.get_child(0) as WeftluminShell


func _panel(shell: WeftluminShell, panel_title: String) -> SoulMeterToolPanel:
	return shell.bottom_tabs.get_node(panel_title) as SoulMeterToolPanel


func _select(shell: WeftluminShell, panel_title: String) -> void:
	shell.bottom_tabs.current_tab = DOCK_ORDER.find(panel_title)


func test_five_tool_panels_mount_in_their_dock_slots_with_private_models() -> void:
	var console_autoload_enabled: bool = bool(DevConsole.get("_enabled"))
	var shell := _open()
	var titles: Array[String] = []
	for index: int in shell.bottom_tabs.get_tab_count():
		titles.append((shell.bottom_tabs.get_tab_control(index) as WeftluminPanel).title)
	assert_array(titles).is_equal(DOCK_ORDER)
	assert_object(_panel(shell, "Console")).is_instanceof(WeftluminConsolePanel)
	assert_object(_panel(shell, "Consequence timeline")).is_instanceof(WeftluminTimelinePanel)
	assert_object(_panel(shell, "Combat lab")).is_instanceof(WeftluminCombatLabPanel)
	assert_object(_panel(shell, "Dialogue lab")).is_instanceof(WeftluminDialoguePanel)
	assert_object(_panel(shell, "Quest editor")).is_instanceof(WeftluminQuestPanel)
	for panel_title: String in ["Console", "Consequence timeline", "Quest editor"]:
		assert_bool(_panel(shell, panel_title).needs_sandbox).is_false()
	for panel_title: String in ["Combat lab", "Dialogue lab"]:
		assert_bool(_panel(shell, panel_title).needs_sandbox).is_true()
	for panel_title: String in ["Console", "Consequence timeline", "Combat lab", "Dialogue lab", "Quest editor"]:
		var panel := _panel(shell, panel_title)
		assert_object(panel.model).override_failure_message(panel_title).is_not_null()
		assert_object(panel.model.get_parent()).is_same(panel)
		assert_bool(bool(panel.model.get("_enabled"))).override_failure_message(panel_title).is_true()
		# The shell owns bindings: no hosted model listens for its legacy F-key.
		assert_bool(panel.model.is_processing_unhandled_key_input()).is_false()
		for command: Callable in panel.commands():
			assert_object(command.get_object()).is_same(panel.model)
			assert_bool(command.is_valid()).is_true()
	assert_bool(_panel(shell, "Console").commands().is_empty()).is_false()
	# The legacy autoload is a different instance and stays exactly as it was.
	assert_bool(bool(DevConsole.get("_enabled"))).is_equal(console_autoload_enabled)
	assert_object(_panel(shell, "Console").model).is_not_same(DevConsole)
	# The hosted models never open their legacy overlays above the shell.
	_panel(shell, "Console").model.call("open_console")
	assert_int(_panel(shell, "Console").model.get_child_count()).is_equal(0)


func test_hosting_seam_refuses_the_autoload_itself() -> void:
	assert_bool(bool(DevConsole.call("host_in_panel"))).is_false()
	assert_bool(bool(CombatLab.call("host_in_panel", &"weftlumin:1"))).is_false()
	assert_bool(bool(DialogueLab.call("host_in_panel", &"weftlumin:1"))).is_false()
	assert_bool(bool(QuestEditor.call("host_in_panel"))).is_false()
	assert_bool(bool(ConsequenceTimeline.call("host_in_panel"))).is_false()
	assert_bool(bool(DevConsole.get("_panel_hosted"))).is_false()


func test_console_panel_runs_the_interpreter_with_unchanged_provenance() -> void:
	var shell := _open()
	var panel := _panel(shell, "Console") as WeftluminConsolePanel
	var standing_before := Reputation.standing(FactionIds.IRON_COMPANIES)
	panel.entry.text = "rep iron-companies 5"
	panel.entry.text_submitted.emit(panel.entry.text)
	assert_float(Reputation.standing(FactionIds.IRON_COMPANIES)).is_equal_approx(
		standing_before + 5.0, 0.001
	)
	var events: Array[ReputationEvent] = Reputation.why(FactionIds.IRON_COMPANIES, 1)
	assert_str(events[0].cause).starts_with(DevConsoleScript.DEBUG_CAUSE_PREFIX)
	assert_bool(bool(GameState.get_flag(DevConsoleScript.USED_FLAG, false))).is_true()
	assert_str(panel.log_box.text).contains("> rep iron-companies 5")
	assert_str(panel.entry.text).is_empty()
	# The tamper marker cannot be erased through the panel either.
	assert_bool(panel.submit("flag %s false" % DevConsoleScript.USED_FLAG)).is_false()
	assert_bool(bool(GameState.get_flag(DevConsoleScript.USED_FLAG, false))).is_true()
	var soul_before := GameState.soul_meter
	assert_bool(panel.submit("soul not-a-number")).is_false()
	assert_float(GameState.soul_meter).is_equal(soul_before)
	assert_bool(panel.submit("quest complete 2")).is_false()
	assert_str(panel.log_box.text).contains("tagged provenance")
	assert_bool(panel.submit("frobnicate")).is_false()
	assert_str(panel.log_box.text).contains("ERROR: Unknown command 'frobnicate'")
	var up := InputEventKey.new()
	up.keycode = KEY_UP
	up.pressed = true
	panel.entry.gui_input.emit(up)
	assert_str(panel.entry.text).is_equal("frobnicate")
	assert_bool(panel.commands()[0].call("help")).is_true()


func test_console_panel_feeds_the_recorder_one_event_per_command() -> void:
	var shell := _open()
	var panel := _panel(shell, "Console") as WeftluminConsolePanel
	var test_root := OS.get_environment("SOUL_METER_TEST_DATA_DIR").path_join("weftlumin-console")
	assert_int(DirAccess.make_dir_recursive_absolute(test_root)).is_equal(OK)
	PlaytestRecorder.session_root_override = test_root
	PlaytestRecorder.force_enabled_for_tests = true
	var events_path := PlaytestRecorder.get_events_path()
	assert_bool(panel.submit("help")).is_true()
	PlaytestRecorder.force_enabled_for_tests = false
	var command_events := 0
	for line: String in FileAccess.get_file_as_string(events_path).split("\n", false):
		var row_value: Variant = JSON.parse_string(line)
		if row_value is Dictionary and str(row_value.get("type", "")) == "dev_console_command":
			command_events += 1
			assert_str(str(row_value.get("command", ""))).is_equal("help")
	assert_int(command_events).is_equal(1)


func test_timeline_panel_observes_both_ledgers_read_only_and_flags_debug_rows() -> void:
	var shell := _open()
	var timeline := _panel(shell, "Consequence timeline") as WeftluminTimelinePanel
	var console := _panel(shell, "Console") as WeftluminConsolePanel
	Reputation.record("panel-test", FactionIds.IRON_COMPANIES, 2.0, "honest panel cause", "test")
	Renown.gain_reputation("panel-test", 1.0, "honest renown cause", "test")
	assert_bool(console.submit("rep iron-companies 3")).is_true()
	var by_cause: Dictionary = {}
	for row: Dictionary in timeline.rows():
		by_cause[str(row.get("cause", ""))] = row
	assert_bool(by_cause.has("honest panel cause")).is_true()
	assert_bool(by_cause.has("honest renown cause")).is_true()
	assert_bool(bool((by_cause["honest panel cause"] as Dictionary)["debug_injected"])).is_false()
	var debug_row: Dictionary = {}
	for cause: String in by_cause:
		if cause.begins_with(DevConsoleScript.DEBUG_CAUSE_PREFIX):
			debug_row = by_cause[cause]
	assert_bool(bool(debug_row.get("debug_injected", false))).is_true()
	var flagged := 0
	for item: TreeItem in timeline.tree.get_root().get_children():
		if item.get_text(3).contains("DEBUG-INJECTED"):
			flagged += 1
			assert_str(item.get_text(4)).starts_with(DevConsoleScript.DEBUG_CAUSE_PREFIX)
	assert_int(flagged).is_equal(1)
	var reputation_before: Dictionary = Reputation.to_dict().duplicate(true)
	var renown_before: Dictionary = Renown.to_dict().duplicate(true)
	timeline.refresh({})
	assert_dict(Reputation.to_dict()).is_equal(reputation_before)
	assert_dict(Renown.to_dict()).is_equal(renown_before)
	assert_str(timeline.summary_label.text).contains("FACTIONS:")


func test_combat_panel_offers_the_catalog_and_reports_the_weather_source() -> void:
	var shell := _open()
	var panel := _panel(shell, "Combat lab") as WeftluminCombatLabPanel
	var offered: Array[StringName] = []
	for index: int in panel.encounter_picker.item_count:
		offered.append(StringName(str(panel.encounter_picker.get_item_metadata(index))))
	assert_array(offered).is_equal(EncounterCatalog.all_ids())
	panel.weather_picker.select(1)
	panel.refresh_weather_source()
	var resolved: Dictionary = panel.model.call(
		"resolve_weather", offered[panel.encounter_picker.selected], true, &""
	)
	assert_str(panel.weather_source.text).is_equal("In effect: %s" % str(resolved.get("label")))


func test_combat_panel_session_runs_under_the_shell_sandbox_and_is_contained() -> void:
	var shell := _open()
	var panel := _panel(shell, "Combat lab") as WeftluminCombatLabPanel
	var before: Dictionary = GameState.to_dict().duplicate(true)
	_select(shell, "Combat lab")
	var sandbox := WeftluminSandbox.shared()
	assert_bool(sandbox.is_armed()).is_true()
	assert_str(String(sandbox.owner())).is_equal(String(shell.sandbox_token(panel)))
	panel.encounter_picker.select(EncounterCatalog.all_ids().find(EncounterIds.BOG_WIGHT))
	panel.start()
	assert_bool(bool(panel.model.call("sandbox_is_armed"))).is_true()
	assert_str(String(sandbox.owner())).is_equal(String(shell.sandbox_token(panel)))
	assert_object(Battle.controller).is_not_null()
	# The editor guard still owns the chart: a lab battle never enters the Battle state.
	assert_bool(_active("Battle")).is_false()
	assert_str(panel.inspector.text).contains("RUNNING")
	var export_root := ProjectSettings.globalize_path(CombatLabScript.EXPORT_ROOT)
	var export_root_existed := DirAccess.dir_exists_absolute(export_root)
	var exported := panel.export_session()
	assert_bool(FileAccess.file_exists(exported)).is_true()
	assert_str(FileAccess.get_file_as_string(exported)).contains("# Combat Lab Session")
	# The legacy inert suite pins that a disabled lab leaves no export root behind.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(exported))
	if not export_root_existed:
		DirAccess.remove_absolute(export_root)
	# Restart replaces this panel's own session; it never needs a second owner.
	panel.model.call("restart_same_setup")
	assert_str(String(sandbox.owner())).is_equal(String(shell.sandbox_token(panel)))
	GameState.set_flag("weftlumin-combat-transient", true)
	_select(shell, "Console")
	assert_bool(sandbox.is_armed()).is_false()
	assert_object(Battle.controller).is_null()
	assert_dict(GameState.to_dict()).is_equal(before)


func test_combat_panel_refuses_over_a_live_production_battle() -> void:
	var hostile := _field_scene.get_node("BogWight") as Hostile
	assert_bool(bool(Battle.start_session(_field, hostile).get("allowed", false))).is_true()
	var production: CombatController = Battle.controller
	var shell := _open()
	var panel := _panel(shell, "Combat lab") as WeftluminCombatLabPanel
	assert_bool(shell.activate_panel(panel)).is_false()
	assert_bool(WeftluminSandbox.shared().is_armed()).is_false()
	# The model's start refusal is silent; the panel makes it visible.
	panel.start()
	assert_object(Battle.controller).is_same(production)
	assert_str(panel.status_text()).is_equal(CombatLabScript.REFUSAL_WARNING)
	assert_bool(bool(panel.model.call("sandbox_is_armed"))).is_false()


func test_sandbox_panels_exclude_each_other() -> void:
	var shell := _open()
	var combat := _panel(shell, "Combat lab") as WeftluminCombatLabPanel
	var dialogue := _panel(shell, "Dialogue lab") as WeftluminDialoguePanel
	assert_bool(shell.activate_panel(combat)).is_true()
	assert_bool(bool(dialogue.model.call("another_sandbox_is_armed"))).is_true()
	var holder: StringName = WeftluminSandbox.shared().owner()
	# The model's start refusal is silent; the panel makes it visible.
	dialogue.start()
	assert_str(String(WeftluminSandbox.shared().owner())).is_equal(String(holder))
	assert_bool(bool(dialogue.model.call("sandbox_is_armed"))).is_false()
	assert_str(dialogue.status_text()).is_equal(DialogueLabScript.REFUSAL_WARNING)


func test_dialogue_panel_derives_choices_from_disk_and_contains_seeded_state() -> void:
	var shell := _open()
	var panel := _panel(shell, "Dialogue lab") as WeftluminDialoguePanel
	var files: Array[String] = panel.model.call("dialogue_files")
	var offered: Array[String] = []
	for index: int in panel.file_picker.item_count:
		offered.append(str(panel.file_picker.get_item_metadata(index)))
	assert_array(offered).is_equal(files)
	var titles: Array[String] = panel.model.call("titles_for_file", offered[0])
	var offered_titles: Array[String] = []
	for index: int in panel.title_picker.item_count:
		offered_titles.append(str(panel.title_picker.get_item_metadata(index)))
	assert_array(offered_titles).is_equal(titles)
	panel.flags_editor.text = "weftlumin-panel = maybe"
	assert_bool(bool(panel.current_setup().get("valid", true))).is_false()

	var before: Dictionary = GameState.to_dict().duplicate(true)
	var standing_before := Reputation.standing(REGISTRY)
	_select(shell, "Dialogue lab")
	assert_str(String(WeftluminSandbox.shared().owner())).is_equal(
		String(shell.sandbox_token(panel))
	)
	panel.flags_editor.text = "weftlumin_panel_flag=true"
	panel.reputation_editor.text = "%s=%s" % [REGISTRY, standing_before + 7.0]
	var parsed: Dictionary = panel.current_setup()
	assert_bool(bool(parsed.get("valid", false))).is_true()
	panel.model.call("start_test_session", parsed["setup"])
	assert_bool(bool(panel.model.call("sandbox_is_armed"))).is_true()
	assert_bool(bool(GameState.get_flag("weftlumin_panel_flag", false))).is_true()
	assert_float(Reputation.standing(REGISTRY)).is_equal_approx(
		standing_before + 7.0, 0.001
	)
	# Replay-same restarts under the same owner and re-arms on pre-session state.
	panel.model.call("start_test_session", parsed["setup"])
	assert_str(String(WeftluminSandbox.shared().owner())).is_equal(
		String(shell.sandbox_token(panel))
	)
	_select(shell, "Console")
	assert_bool(WeftluminSandbox.shared().is_armed()).is_false()
	assert_dict(GameState.to_dict()).is_equal(before)
	assert_float(Reputation.standing(REGISTRY)).is_equal_approx(standing_before, 0.001)


func test_dialogue_panel_replay_launches_an_owned_balloon_and_leaving_ends_it() -> void:
	var shell := _open()
	var panel := _panel(shell, "Dialogue lab") as WeftluminDialoguePanel
	var before: Dictionary = GameState.to_dict().duplicate(true)
	_select(shell, "Dialogue lab")
	panel.flags_editor.text = "weftlumin_panel_replay=true"
	panel.start()
	assert_bool(bool(panel.model.call("sandbox_is_armed"))).is_true()
	assert_bool(bool(GameState.get_flag("weftlumin_panel_replay", false))).is_true()
	var balloon: Node = panel.model.get("_lab_balloon") as Node
	assert_object(balloon).override_failure_message("replay must launch a lab balloon").is_not_null()
	assert_str(panel.session_label.text).starts_with("REPLAYING")
	_select(shell, "Console")
	assert_bool(is_instance_valid(balloon)).is_false()
	assert_bool(WeftluminSandbox.shared().is_armed()).is_false()
	assert_dict(GameState.to_dict()).is_equal(before)


func test_dialogue_panel_refuses_over_a_live_production_battle() -> void:
	var hostile := _field_scene.get_node("BogWight") as Hostile
	assert_bool(bool(Battle.start_session(_field, hostile).get("allowed", false))).is_true()
	var shell := _open()
	var panel := _panel(shell, "Dialogue lab") as WeftluminDialoguePanel
	assert_bool(shell.activate_panel(panel)).is_false()
	# The model's start refusal is silent; the panel makes it visible.
	panel.start()
	assert_bool(bool(panel.model.call("sandbox_is_armed"))).is_false()
	assert_str(panel.status_text()).is_equal(DialogueLabScript.REFUSAL_WARNING)


func test_quest_panel_validates_saves_registers_and_requires_explicit_authorisation() -> void:
	var shell := _open()
	var panel := _panel(shell, "Quest editor") as WeftluminQuestPanel
	panel.model.set("campaigns_root_for_tests", SCRATCH_CAMPAIGNS_ROOT)
	panel.model.set("force_enabled_for_tests", true)
	var package_path := SCRATCH_CAMPAIGNS_ROOT.path_join(CAMPAIGN_ID)
	var invalid := _quest("panel-live")
	invalid["dialogue_title"] = "not_an_authored_dialogue_title"
	panel.campaign_editor.text = JSON.stringify(_campaign())
	panel.quests_editor.text = JSON.stringify([invalid])
	var validation: Dictionary = panel.validate()
	assert_bool(_has_error_code(validation.get("errors", []), "unknown_dialogue_title")).is_true()
	assert_str(panel.errors_label.text).contains("dialogue_title")
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(package_path))).is_false()

	panel.quests_editor.text = JSON.stringify([_quest("panel-live")])
	var saved: Dictionary = panel.save()
	assert_bool(bool(saved.get("saved", false))).is_true()
	assert_bool(bool(saved.get("registered", false))).is_true()
	assert_array(saved.get("written_files", [])).contains_exactly([
		package_path + "/campaign.json", package_path + "/quests/panel-live.json",
	])
	assert_str(panel.registered_label.text).contains(CAMPAIGN_ID + "/panel-live")
	assert_int(panel.campaign_picker.item_count).is_equal(1)

	var live: DomSideQuest = QuestRegistry.runtime_quests()[0]
	QuestRegistry.offer(live)
	var replacement := _quest("panel-live")
	replacement["name"] = "Replacement Quest"
	panel.quests_editor.text = JSON.stringify([replacement])
	var refused: Dictionary = panel.save()
	assert_bool(bool(refused.get("registered", true))).is_false()
	assert_bool(panel.authorize_button.visible).is_true()
	assert_str(panel.status_text()).contains("REGISTRATION REFUSED")
	assert_str(panel.status_text()).contains(CAMPAIGN_ID + "/panel-live")
	assert_bool(QuestRegistry.is_active(live)).is_true()
	var forced: Dictionary = panel.authorize()
	assert_bool(bool(forced.get("registered", false))).is_true()
	assert_bool(QuestRegistry.is_active(live)).is_false()
	assert_bool(panel.authorize_button.visible).is_false()

	panel.load_campaign(CAMPAIGN_ID)
	var draft: Dictionary = panel.current_draft()
	assert_bool(bool(draft.get("valid", false))).is_true()
	assert_str(str((draft["campaign"] as Dictionary).get("id", ""))).is_equal(CAMPAIGN_ID)


func test_rendered_panels_capture() -> void:
	var capture_dir := OS.get_environment("SOUL_METER_WEFTLUMIN_CAPTURE_DIR")
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	var current := get_tree().current_scene as CanvasItem
	var visible_before := current.visible if current != null else false
	if current != null:
		current.hide()
	var shell := _open()
	(_panel(shell, "Console") as WeftluminConsolePanel).submit("help")
	assert_int(DirAccess.make_dir_recursive_absolute(capture_dir)).is_equal(OK)
	for panel_title: String in ["Console", "Consequence timeline", "Combat lab", "Dialogue lab", "Quest editor"]:
		_select(shell, panel_title)
		await get_tree().create_timer(0.2).timeout
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var file_name := "weftlumin-panel-%s.png" % panel_title.to_lower().replace(" ", "-")
		assert_int(get_viewport().get_texture().get_image().save_png(
			capture_dir.path_join(file_name)
		)).is_equal(OK)
	_select(shell, "Console")
	if current != null:
		current.visible = visible_before


func _scene_panel(shell: WeftluminShell) -> WeftluminScenePanel:
	var left := shell.root.find_child("TreePalette", true, false) as TabContainer
	return left.get_node("Scene tree") as WeftluminScenePanel


## E3.1a (#338): the scene panel takes the left "Scene tree" slot and its tree IS the model's
## selection set; non-editable rows cannot be selected, and gestures land live and undo.
func test_scene_panel_mounts_in_the_left_slot_and_its_tree_is_the_selection() -> void:
	var shell := _open()
	var panel := _scene_panel(shell)
	assert_object(panel).is_not_null()
	var left := shell.root.find_child("TreePalette", true, false) as TabContainer
	assert_object(left.get_tab_control(0)).is_same(panel)
	assert_int(left.get_tab_count()).is_equal(2)
	assert_bool(panel.needs_sandbox).is_false()
	assert_object(shell.scene_tree).override_failure_message(
		"the built-in read-only tree is only the fallback when no host panel claims the slot"
	).is_null()
	panel.refresh({"scene_root": _field_scene})
	assert_object(panel.model.scene_root).is_same(_field_scene)
	assert_bool(panel.commands().is_empty()).is_false()

	var npc := _field_scene.get_node("IrisIllepah") as Node2D
	var spawn := _field_scene.get_node("SpawnDefault") as Node2D
	assert_bool((panel._items[_field_scene.get_node("Floor")] as TreeItem).is_selectable(0)).is_false()
	assert_bool((panel._items[npc] as TreeItem).is_selectable(0)).is_true()
	_tree_select(panel, npc)
	_tree_select(panel, spawn)
	await get_tree().process_frame
	assert_array(panel.model.selection()).contains_exactly_in_any_order([npc, spawn])
	assert_object(panel.model.primary()).is_same(spawn)
	assert_str(panel.status_text()).contains("2 selected")
	assert_str(shell.inspector.text).contains("SpawnDefault")

	var npc_before: Vector2 = npc.position
	var spawn_before: Vector2 = spawn.position
	assert_bool(bool(panel.model.nudge(Vector2(8.0, 0.0))["allowed"])).is_true()
	assert_vector(npc.position).is_equal(npc_before + Vector2(8.0, 0.0))
	assert_vector(spawn.position).is_equal(spawn_before + Vector2(8.0, 0.0))
	# The rebuilt tree keeps showing the selection after a gesture.
	assert_bool((panel._items[npc] as TreeItem).is_selected(0)).is_true()
	(panel.find_child("Undo", true, false) as Button).pressed.emit()
	assert_vector(npc.position).is_equal(npc_before)
	assert_vector(spawn.position).is_equal(spawn_before)
	# Delete removes the whole selection in one step; one undo puts both back.
	(panel.find_child("Delete", true, false) as Button).pressed.emit()
	assert_object(_field_scene.get_node_or_null("IrisIllepah")).is_null()
	(panel.find_child("Undo", true, false) as Button).pressed.emit()
	assert_object(_field_scene.get_node_or_null("IrisIllepah")).is_same(npc)
	assert_object(_field_scene.get_node_or_null("SpawnDefault")).is_same(spawn)


## What Tree does for a user's row click in SELECT_MULTI: select the cell, then emit
## `multi_selected` (a script-side `TreeItem.select()` alone emits nothing).
func _tree_select(panel: WeftluminScenePanel, node: Node) -> void:
	var item: TreeItem = panel._items[node]
	item.select(0)
	panel.tree.multi_selected.emit(item, 0, true)


func _click_row(panel: WeftluminScenePanel, node: Node, extend: bool) -> void:
	var item: TreeItem = panel._items[node]
	panel.tree.scroll_to_item(item)
	await get_tree().process_frame
	var point: Vector2 = (
		panel.tree.get_global_transform_with_canvas() * panel.tree.get_item_area_rect(item).get_center()
	)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = point
		click.global_position = point
		click.ctrl_pressed = extend
		get_viewport().push_input(click)
		await get_tree().process_frame


func test_rendered_scene_panel_capture() -> void:
	var capture_dir := OS.get_environment("SOUL_METER_WEFTLUMIN_SCENE_CAPTURE_DIR")
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	var shell := _open()
	var panel := _scene_panel(shell)
	panel.refresh({"scene_root": _field_scene})
	# Real pointer input: a click, then Ctrl+clicks to extend the selection.
	var picked: Array[Node2D] = []
	for node_name: String in ["IrisIllepah", "SpawnDefault", "ReturnToDom"]:
		var node := _field_scene.get_node(node_name) as Node2D
		await _click_row(panel, node, not picked.is_empty())
		picked.append(node)
	await get_tree().create_timer(0.3).timeout
	assert_array(panel.model.selection()).contains_exactly_in_any_order(picked)
	assert_object(panel.model.primary()).is_same(picked.back())
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(DirAccess.make_dir_recursive_absolute(capture_dir)).is_equal(OK)
	var frame: Image = get_viewport().get_texture().get_image()
	var left := shell.root.find_child("TreePalette", true, false) as Control
	var dock: Rect2i = Rect2i(left.get_global_rect())
	assert_int(frame.get_region(dock).save_png(capture_dir.path_join("weftlumin-scene-panel.png"))).is_equal(OK)
	frame.resize(frame.get_width() / 2, frame.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	assert_int(frame.save_png(capture_dir.path_join("weftlumin-scene-panel-dock.png"))).is_equal(OK)


func _campaign() -> Dictionary:
	return {
		"id": CAMPAIGN_ID,
		"title": "Weftlumin Panel Test",
		"entry_location": "dom",
		"locations": ["dom"],
	}


func _quest(quest_id: String) -> Dictionary:
	return {
		"schema": 1,
		"quest_id": quest_id,
		"kind": "side_quest",
		"name": "Panel Quest",
		"giver_actor_id": "panel-giver-%s" % quest_id,
		"dialogue_title": "dom_side_dishonest_casks",
		"decision_prompt": "Choose.",
		"resolution_flag": "panel_%s_resolution" % quest_id.replace("-", "_"),
		"outcomes": [
			{
				"id": "first", "label": "First", "faction_id": "the-registry",
				"reputation_delta": 1.0, "cause": "First cause", "readback": "First readback",
			},
			{
				"id": "second", "label": "Second", "faction_id": "iron-companies",
				"reputation_delta": -1.0, "cause": "Second cause", "readback": "Second readback",
			},
		],
	}


func _has_error_code(errors: Array, code: String) -> bool:
	for error_value: Variant in errors:
		if error_value is Dictionary and str((error_value as Dictionary).get("code", "")) == code:
			return true
	return false


func _remove_tree(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory: DirAccess = DirAccess.open(absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var child: String = absolute.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)
