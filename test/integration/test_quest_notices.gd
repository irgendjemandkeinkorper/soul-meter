extends GdUnitTestSuite
## Q2 (docs/design/quest-system-sprint-2026-11-26.md): the field says when a quest is taken up and
## when it moves to a new step. The registry's timing rules (deferred, nothing on load, nothing
## for a quest that finished at once) are covered in test_quest_registry.gd; this suite checks
## what the notices stack shows and that a conversation holds the news until it closes.

const NOTICE_SCENE := preload("res://ui/hud/consequence_notices.tscn")

var _flags: Dictionary
var _quests: Dictionary
var _reputation: Dictionary
var _renown: Dictionary
var _notices: ConsequenceNotices


func before_test() -> void:
	get_tree().paused = false
	_flags = GameState.flags.duplicate(true)
	_quests = QuestRegistry.to_dict().duplicate(true)
	_reputation = Reputation.to_dict().duplicate(true)
	_renown = Renown.to_dict().duplicate(true)
	GameState.flags.clear()
	QuestRegistry.reset()
	_notices = auto_free(NOTICE_SCENE.instantiate()) as ConsequenceNotices
	_notices.hold_seconds = 10.0
	_notices.slide_seconds = 0.01
	_notices.fade_seconds = 0.01
	get_tree().root.add_child(_notices)


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_notices):
		_notices.get_parent().remove_child(_notices)
	QuestRegistry.reset()
	QuestRegistry.from_dict(_quests)
	GameState.flags = _flags
	Reputation.from_dict(_reputation)
	Renown.from_dict(_renown)
	UIManager.reset_reward_reveals()


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_taking_up_a_quest_and_reaching_a_step_show_in_the_field() -> void:
	QuestRegistry.offer(QuestRegistry.DORTHKOR_ROAD)
	await _settle()
	GameState.set_flag("chapter_dorthkor_reached", true)
	await _settle()

	assert_array(_notices.visible_notice_texts()).contains_exactly(
		[
			"NEW QUEST — The Broken Muster",
			"THE BROKEN MUSTER — Break the demon vanguard.",
		]
	)


func test_news_from_a_conversation_waits_until_it_closes() -> void:
	# The dialogue balloon pauses the tree for the whole conversation.
	get_tree().paused = true
	QuestRegistry.offer(QuestRegistry.LIVING_TAG)
	await _settle()
	assert_array(_notices.visible_notice_texts()).is_empty()
	assert_int(_notices.pending_notice_count()).is_equal(1)

	get_tree().paused = false
	await _settle()
	assert_array(_notices.visible_notice_texts()).contains_exactly(["NEW QUEST — The Living Tag"])


func test_quest_news_carries_no_numbers() -> void:
	# Field notices outside a conversation stay non-numeric (owner, 2026-11-01).
	var digits := RegEx.create_from_string("[0-9]")
	for quest: Quest in QuestRegistry.known_quests():
		assert_object(digits.search(ConsequenceNotices.quest_taken_up_text(quest))).override_failure_message(
			"'%s' announces with a number" % quest.quest_name
		).is_null()
		if quest is FlagQuest:
			for objective: String in (quest as FlagQuest).objectives:
				assert_object(
					digits.search(ConsequenceNotices.quest_step_text(quest, objective))
				).override_failure_message(
					"'%s' step '%s' carries a number" % [quest.quest_name, objective]
				).is_null()
