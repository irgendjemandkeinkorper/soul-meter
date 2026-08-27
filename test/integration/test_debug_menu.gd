extends GdUnitTestSuite
## ui/screens/debug_menu.gd — the playtest god-mode screen. The heavy lifting
## (state-consistent quest skipping) is covered by
## test/unit/test_debug_force_complete.gd; this suite proves the screen builds,
## lists every quest, and its sweep button really completes them.

var _original_flags: Dictionary
var _original_reputation: Dictionary
var _original_renown: Dictionary
var _original_quests: Dictionary
var _original_gp: int


func before_test() -> void:
	_original_flags = GameState.flags.duplicate(true)
	_original_reputation = Reputation.to_dict().duplicate(true)
	_original_renown = Renown.to_dict().duplicate(true)
	_original_quests = QuestRegistry.to_dict().duplicate(true)
	_original_gp = GameState.gp
	GameState.flags.clear()
	Reputation.from_dict({})
	Renown.from_dict({})
	QuestRegistry.reset()


func after_test() -> void:
	GameState.flags = _original_flags
	GameState.set_gp(_original_gp)
	Reputation.from_dict(_original_reputation)
	Renown.from_dict(_original_renown)
	QuestRegistry.reset()
	QuestRegistry.from_dict(_original_quests)
	UIManager.close_all()


func test_screen_builds_with_a_row_per_quest_and_sweep_completes_them() -> void:
	var runner := scene_runner("res://ui/screens/debug_menu.tscn")
	await runner.simulate_frames(2)
	var screen := runner.scene() as Screen
	assert_object(screen).is_not_null()

	for quest: Quest in QuestRegistry.ALL_QUESTS:
		var row := screen.find_child("QuestRow%d" % quest.id, true, false)
		assert_object(row) \
			.override_failure_message("no debug row for quest '%s'" % quest.quest_name) \
			.is_not_null()

	var sweep := screen.find_child("CompleteAllQuests", true, false) as Button
	assert_object(sweep).is_not_null()
	sweep.pressed.emit()
	await runner.simulate_frames(1)
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		assert_bool(QuestRegistry.is_done(quest)) \
			.override_failure_message("'%s' not done after debug sweep" % quest.quest_name) \
			.is_true()


func test_gp_grant_button_raises_gp() -> void:
	var runner := scene_runner("res://ui/screens/debug_menu.tscn")
	await runner.simulate_frames(2)
	var before := GameState.gp
	var screen := runner.scene() as Screen
	var button: Button = null
	for candidate in screen.find_children("*", "Button", true, false):
		if (candidate as Button).text == "GP +500":
			button = candidate
			break
	assert_object(button).is_not_null()
	button.pressed.emit()
	assert_int(GameState.gp).is_equal(before + 500)
