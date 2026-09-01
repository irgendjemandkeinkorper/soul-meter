extends GdUnitTestSuite

const DevConsoleScript := preload("res://globals/dev_console.gd")

var _console: Node
var _original_game_state: Dictionary
var _original_reputation: Dictionary
var _original_renown: Dictionary
var _original_quests: Dictionary
var _original_world_clock: Dictionary
var _original_recorder_force: bool
var _original_recorder_root: String


func before_test() -> void:
	_original_game_state = GameState.to_dict().duplicate(true)
	_original_reputation = Reputation.to_dict().duplicate(true)
	_original_renown = Renown.to_dict().duplicate(true)
	_original_quests = QuestRegistry.to_dict().duplicate(true)
	_original_world_clock = WorldClock.to_dict().duplicate(true)
	_original_recorder_force = bool(PlaytestRecorder.force_enabled_for_tests)
	_original_recorder_root = PlaytestRecorder.session_root_override
	PlaytestRecorder.force_enabled_for_tests = false
	_console = get_node_or_null("/root/DevConsole")
	assert_object(_console).is_not_null()
	if _console != null:
		_console.call("close_console")
		_console.set("force_enabled_for_tests", false)
		_console.set("force_enabled_for_tests", true)


func after_test() -> void:
	if _console != null:
		_console.call("close_console")
		_console.set("force_enabled_for_tests", false)
	var restored: bool = GameState.from_dict(_original_game_state)
	assert_bool(restored).is_true()
	Reputation.from_dict(_original_reputation)
	Renown.from_dict(_original_renown)
	QuestRegistry.from_dict(_original_quests)
	WorldClock.from_dict(_original_world_clock)
	PlaytestRecorder.force_enabled_for_tests = false
	PlaytestRecorder.session_root_override = _original_recorder_root
	PlaytestRecorder.force_enabled_for_tests = _original_recorder_force
	get_tree().paused = false


func test_flag_flags_soul_and_gp_commands_use_game_state_public_apis() -> void:
	assert_bool(_execute("flag dev_console_test true")).is_true()
	assert_bool(bool(GameState.get_flag("dev_console_test", false))).is_true()
	assert_bool(_execute("flags dev_console_test")).is_true()
	assert_str(_last_text()).contains("dev_console_test = true")

	assert_bool(_execute("soul 37.5")).is_true()
	assert_float(GameState.soul_meter).is_equal_approx(37.5, 0.001)
	assert_bool(_execute("gp 123")).is_true()
	assert_int(GameState.gp).is_equal(123)


func test_reputation_commands_write_tagged_ledger_events_and_read_them() -> void:
	var standing_before := Reputation.standing(FactionIds.IRON_COMPANIES)

	assert_bool(_execute("rep iron-companies 5")).is_true()
	assert_float(Reputation.standing(FactionIds.IRON_COMPANIES)).is_equal_approx(
		standing_before + 5.0, 0.001
	)
	var events: Array[ReputationEvent] = Reputation.why(FactionIds.IRON_COMPANIES, 1)
	assert_int(events.size()).is_equal(1)
	assert_bool(DevConsoleScript.is_debug_caused(events[0].cause)).is_true()
	assert_str(events[0].cause).starts_with(DevConsoleScript.DEBUG_CAUSE_PREFIX)

	assert_bool(_execute("standing iron-companies")).is_true()
	assert_str(_last_text()).contains("iron-companies standing")
	assert_bool(_execute("why iron-companies")).is_true()
	assert_str(_last_text()).contains(DevConsoleScript.DEBUG_CAUSE_PREFIX)


func test_renown_and_infamy_commands_write_only_tagged_ledger_events() -> void:
	var renown_before := Renown.reputation()
	var infamy_before := Renown.infamy()

	assert_bool(_execute("renown 3")).is_true()
	assert_bool(_execute("infamy 2")).is_true()
	assert_float(Renown.reputation()).is_equal_approx(renown_before + 3.0, 0.001)
	assert_float(Renown.infamy()).is_equal_approx(infamy_before + 2.0, 0.001)

	var renown_events: Array[RenownEvent] = Renown.why(&"reputation", 1)
	var infamy_events: Array[RenownEvent] = Renown.why(&"infamy", 1)
	assert_bool(DevConsoleScript.is_debug_caused(renown_events[0].cause)).is_true()
	assert_bool(DevConsoleScript.is_debug_caused(infamy_events[0].cause)).is_true()
	assert_bool(_execute("why renown")).is_true()
	assert_bool(_execute("why infamy")).is_true()


func test_item_quest_offer_and_phase_commands_use_public_paths() -> void:
	var item_before := GameState.item_count(ItemIds.MATERIALS_LOAMROOT_SPRIG)
	assert_bool(_execute("item materials/loamroot_sprig 2")).is_true()
	assert_int(GameState.item_count(ItemIds.MATERIALS_LOAMROOT_SPRIG)).is_equal(item_before + 2)

	QuestRegistry.reset()
	assert_bool(_execute("quest offer 1")).is_true()
	assert_bool(QuestRegistry.is_active(QuestRegistry.LOAMROOT_SPRIGS)).is_true()

	WorldClock.set_phase(&"morning", "test")
	assert_bool(_execute("phase evening")).is_true()
	assert_str(String(WorldClock.phase())).is_equal("evening")
	assert_bool(_execute("phase next")).is_true()
	assert_str(String(WorldClock.phase())).is_equal("night")


func test_quest_complete_is_rejected_when_public_api_cannot_accept_debug_provenance() -> void:
	QuestRegistry.reset()
	assert_bool(_execute("quest complete 2")).is_false()
	assert_bool(QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)).is_false()
	assert_str(_last_text()).contains("tagged provenance")


func test_bad_arguments_add_errors_and_do_not_change_state() -> void:
	var soul_before := GameState.soul_meter
	var gp_before := GameState.gp
	var reputation_before := Reputation.to_dict().duplicate(true)
	var quests_before := QuestRegistry.to_dict().duplicate(true)

	assert_bool(_execute("soul")).is_false()
	assert_float(GameState.soul_meter).is_equal(soul_before)
	assert_bool(_execute("gp not-a-number")).is_false()
	assert_int(GameState.gp).is_equal(gp_before)
	assert_bool(_execute("rep no-such-faction 4")).is_false()
	assert_dict(Reputation.to_dict()).is_equal(reputation_before)
	assert_bool(_execute("quest offer 9999")).is_false()
	assert_dict(QuestRegistry.to_dict()).is_equal(quests_before)
	assert_bool(_execute("item no/such_item")).is_false()
	assert_bool(bool(_last_entry().get("error", false))).is_true()


func test_first_command_marks_session_and_history_navigates() -> void:
	GameState.set_flag("dev_console_used", false)
	assert_bool(bool(GameState.get_flag("dev_console_used", false))).is_false()

	assert_bool(_execute("help")).is_true()
	assert_bool(bool(GameState.get_flag("dev_console_used", false))).is_true()
	assert_bool(_execute("flags")).is_true()

	assert_str(str(_console.call("history_previous"))).is_equal("flags")
	assert_str(str(_console.call("history_previous"))).is_equal("help")
	assert_str(str(_console.call("history_next"))).is_equal("flags")
	assert_str(str(_console.call("history_next"))).is_empty()


func test_enabled_playtest_recorder_receives_one_event_per_command() -> void:
	var test_root := OS.get_environment("SOUL_METER_TEST_DATA_DIR").path_join(
		"dev-console-recorder"
	)
	assert_int(DirAccess.make_dir_recursive_absolute(test_root)).is_equal(OK)
	PlaytestRecorder.session_root_override = test_root
	PlaytestRecorder.force_enabled_for_tests = true
	var events_path := PlaytestRecorder.get_events_path()

	assert_bool(_execute("help")).is_true()
	PlaytestRecorder.force_enabled_for_tests = false

	var command_events := 0
	for line: String in FileAccess.get_file_as_string(events_path).split("\n", false):
		var row_value: Variant = JSON.parse_string(line)
		if row_value is Dictionary and str(row_value.get("type", "")) == "dev_console_command":
			command_events += 1
			assert_str(str(row_value.get("command", ""))).is_equal("help")
	assert_int(command_events).is_equal(1)


func test_debug_cause_helper_only_accepts_the_exported_prefix() -> void:
	assert_bool(DevConsoleScript.is_debug_caused("[debug] console rep iron-companies +5")).is_true()
	assert_bool(DevConsoleScript.is_debug_caused("ordinary gameplay cause")).is_false()
	assert_bool(DevConsoleScript.is_debug_caused("")).is_false()


func test_the_tamper_marker_cannot_be_cleared_from_the_console() -> void:
	# Gate finding 1: the marker exists so a debug-touched save never looks
	# clean. Because _mark_session_used() only fires once per session, a
	# successful clear would be permanent for that session.
	assert_bool(_execute("help")).is_true()
	assert_bool(GameState.flag_is_true(DevConsoleScript.USED_FLAG)).is_true()

	assert_bool(_execute("flag %s false" % DevConsoleScript.USED_FLAG)).is_false()
	assert_bool(bool(_last_entry().get("error", false))).is_true()
	assert_bool(GameState.flag_is_true(DevConsoleScript.USED_FLAG)) \
		.override_failure_message("The console must not be able to erase its own tamper marker") \
		.is_true()

	# Setting it true is refused too — only the console's own guard may write it.
	assert_bool(_execute("flag %s true" % DevConsoleScript.USED_FLAG)).is_false()


func test_quest_offer_refuses_a_completed_quest_instead_of_claiming_success() -> void:
	# Gate finding 2: QuestRegistry.offer() no-ops on a completed quest, so
	# reporting success would assert a state that was never reached.
	var quest: Quest = QuestRegistry.FIELD_DEBT
	assert_bool(_execute("quest offer %d" % quest.id)).is_true()
	QuestRegistry.debug_force_complete(quest)
	assert_bool(QuestRegistry.is_done(quest)).is_true()

	assert_bool(_execute("quest offer %d" % quest.id)).is_false()
	assert_bool(bool(_last_entry().get("error", false))).is_true()
	assert_str(_last_text()).contains("already completed")


func _execute(command: String) -> bool:
	return bool(_console.call("execute_command", command))


func _last_entry() -> Dictionary:
	var entry_value: Variant = _console.call("last_log_entry")
	return entry_value as Dictionary


func _last_text() -> String:
	return str(_last_entry().get("text", ""))
