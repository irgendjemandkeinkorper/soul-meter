extends GdUnitTestSuite

var original_flags: Dictionary
var original_quests: Dictionary
var original_party: Array[PartyMember]
var original_autosave_reason: String


func before_test() -> void:
	original_flags = GameState.flags.duplicate(true)
	original_quests = QuestRegistry.to_dict().duplicate(true)
	original_party = GameState.party.duplicate()
	original_autosave_reason = SaveGame._pending_autosave_reason
	GameState.flags.clear()
	QuestRegistry.reset()
	GameState._seed_demo_data()
	SaveGame._pending_autosave_reason = ""


func after_test() -> void:
	QuestRegistry.reset()
	QuestRegistry.from_dict(original_quests)
	GameState.flags = original_flags
	GameState.party = original_party
	SaveGame._pending_autosave_reason = original_autosave_reason


func test_critical_path_is_derived_from_party_quest_and_ruling_facts() -> void:
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.RECRUIT)
	var candidates := GameState.recruitable_candidates()
	GameState.set_companions([candidates[0], candidates[1]])
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.REPORT)

	QuestRegistry.offer(QuestRegistry.DORTHKOR_ROAD)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.SECURE_ROAD)
	for flag in QuestRegistry.DORTHKOR_ROAD.required_flags:
		GameState.set_flag(flag, true)
	QuestSystem.update_quest(QuestRegistry.DORTHKOR_ROAD)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.RETURN)

	GameState.set_flag("chapter_one_resolution", "hold-both")
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.COMPLETE)
	GameState.set_flag("chapter_one_free_roam", true)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.FREE_ROAM)


func test_deep_trial_content_stays_dormant_in_the_external_playtest() -> void:
	QuestSystem.completed.add_quest(QuestRegistry.DORTHKOR_ROAD)
	GameState.set_flag("chapter_one_resolution", "dead-first")

	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.COMPLETE)
	assert_str(ChapterOneProgress.title()).is_equal("THE BROKEN MUSTER")


func test_extended_content_flag_continues_into_the_deep_trial() -> void:
	QuestSystem.completed.add_quest(QuestRegistry.DORTHKOR_ROAD)
	GameState.set_flag("chapter_one_resolution", "dead-first")
	GameState.set_flag("prototype_extended_content", true)

	assert_int(ChapterOneProgress.current_stage()).is_equal(
		ChapterOneProgress.Stage.DEEP_TRIAL_OFFER
	)
	QuestRegistry.offer(QuestRegistry.DEEP_TRIAL)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.DEEP_TRIAL)
	assert_str(ChapterOneProgress.title()).is_equal("THE DEEP TRIAL")
	assert_bool(GameState.get_flag("deep_trial_open")).is_true()

	for flag in QuestRegistry.DEEP_TRIAL.required_flags:
		GameState.set_flag(flag, true)
	assert_int(ChapterOneProgress.current_stage()).is_equal(
		ChapterOneProgress.Stage.DEEP_TRIAL_RETURN
	)


func test_free_roam_objective_opens_loamroot() -> void:
	GameState.set_flag("chapter_one_free_roam", true)

	assert_bool(ChapterOneProgress.loamroot_unlocked()).is_true()
	assert_str(ChapterOneProgress.objective()).contains("Loamroot")
