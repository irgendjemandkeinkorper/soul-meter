extends GdUnitTestSuite
## Q3 (docs/design/quest-system-sprint-2026-11-26.md): the player can track one active quest. The
## field HUD's objective line follows it; with nothing tracked it follows the chapter thread.

var _flags: Dictionary
var _reputation: Dictionary
var _renown: Dictionary
var _quests: Dictionary
var _soul: float
var _party: Array[PartyMember] = []
var _zhavar: Dictionary = {}


func before_test() -> void:
	_party = GameState.party.duplicate()
	_flags = GameState.flags.duplicate(true)
	_reputation = Reputation.to_dict().duplicate(true)
	_renown = Renown.to_dict().duplicate(true)
	_quests = QuestRegistry.to_dict().duplicate(true)
	_soul = GameState.soul_meter
	_zhavar = SaveGame.zhavar.duplicate(true)
	GameState.flags.clear()
	Reputation.from_dict({})
	Renown.from_dict({})
	QuestRegistry.reset()


func after_test() -> void:
	QuestRegistry.reset()
	QuestRegistry.from_dict(_quests)
	GameState.flags = _flags
	GameState.soul_meter = _soul
	Reputation.from_dict(_reputation)
	Renown.from_dict(_renown)
	SaveGame.zhavar = _zhavar.duplicate(true)
	GameState.party = _party
	UIManager.reset_reward_reveals()


func test_only_an_active_quest_can_be_tracked() -> void:
	assert_object(QuestRegistry.pinned_quest()).is_null()
	assert_bool(QuestRegistry.pin(QuestRegistry.LIVING_TAG)).is_false()
	assert_bool(QuestRegistry.pin(null)).is_false()
	QuestRegistry.offer(QuestRegistry.LIVING_TAG)
	assert_bool(QuestRegistry.pin(QuestRegistry.LIVING_TAG)).is_true()
	assert_object(QuestRegistry.pinned_quest()).is_same(QuestRegistry.LIVING_TAG)
	QuestRegistry.unpin()
	assert_object(QuestRegistry.pinned_quest()).is_null()


func test_tracking_lets_go_when_the_quest_completes() -> void:
	var side: DomSideQuest = QuestRegistry.COLD_BOWL
	QuestRegistry.offer(side)
	assert_bool(QuestRegistry.pin(side)).is_true()
	assert_bool(QuestRegistry.debug_force_complete(side)).is_true()
	assert_object(QuestRegistry.pinned_quest()).is_null()
	assert_bool(QuestRegistry.to_dict().has("pinned")).is_false()


func test_the_tracked_quest_rides_in_the_save_and_older_saves_track_nothing() -> void:
	var stub: StubSideQuest = QuestRegistry.STUB_MESSAGE
	QuestRegistry.offer(stub)
	assert_bool(QuestRegistry.pin(stub)).is_true()
	var saved := QuestRegistry.to_dict().duplicate(true)
	assert_int(int(saved["pinned"])).is_equal(stub.id)

	QuestRegistry.reset()
	assert_object(QuestRegistry.pinned_quest()).is_null()
	# A JSON save brings the id back as a float.
	saved["pinned"] = float(stub.id)
	QuestRegistry.from_dict(saved)
	assert_object(QuestRegistry.pinned_quest()).is_same(stub)

	# A save from before tracking existed has no key; a stale or junk id tracks nothing.
	saved.erase("pinned")
	QuestRegistry.from_dict(saved)
	assert_object(QuestRegistry.pinned_quest()).is_null()
	for junk: Variant in [QuestRegistry.LIVING_TAG.id, 999999, "seven", null]:
		saved["pinned"] = junk
		QuestRegistry.from_dict(saved)
		assert_object(QuestRegistry.pinned_quest()).override_failure_message(
			"pinned=%s tracked something" % [junk]
		).is_null()


func test_tracking_changes_are_announced() -> void:
	var seen: Array = []
	var record := func(quest: Quest) -> void: seen.append(quest)
	QuestRegistry.pinned_quest_changed.connect(record)
	QuestRegistry.offer(QuestRegistry.FIFTH_ECHO)
	QuestRegistry.pin(QuestRegistry.FIFTH_ECHO)
	QuestRegistry.pin(QuestRegistry.FIFTH_ECHO)
	QuestRegistry.unpin()
	QuestRegistry.unpin()
	QuestRegistry.pinned_quest_changed.disconnect(record)
	assert_array(seen).is_equal([QuestRegistry.FIFTH_ECHO, null])


func test_destination_names_the_area_to_go_to() -> void:
	# A side quest is found where its giver stands: Droma is in Dom's town hall.
	assert_str(QuestRegistry.destination_for(QuestRegistry.LIVING_TAG)).is_equal("Dom")
	assert_str(QuestRegistry.destination_for(QuestRegistry.INSTRUMENT_STAKE)).is_equal("Hollowmere")
	assert_str(QuestRegistry.destination_for(QuestRegistry.DORTHKOR_ROAD)).is_equal("Dorthkor Road")
	# A companion's quest goes where the party goes.
	assert_str(QuestRegistry.destination_for(QuestRegistry.SERAI_LUN_QUEST)).is_empty()
	assert_str(QuestRegistry.destination_for(null)).is_empty()
