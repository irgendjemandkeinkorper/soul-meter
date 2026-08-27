extends GdUnitTestSuite
## QuestRegistry.debug_force_complete — the playtest god-mode seam behind
## ui/screens/debug_menu.gd. The contract under test: a skipped quest must
## leave the same durable state as an earned completion (resolver side
## effects, ledger writes, resolution flags), because the skip routes through
## the real resolvers instead of moving pool entries.

var _original_party: Array[PartyMember]
var _original_flags: Dictionary
var _original_reputation: Dictionary
var _original_renown: Dictionary
var _original_quests: Dictionary
var _original_soul: float


func before_test() -> void:
	_original_party = GameState.party.duplicate()
	_original_flags = GameState.flags.duplicate(true)
	_original_reputation = Reputation.to_dict().duplicate(true)
	_original_renown = Renown.to_dict().duplicate(true)
	_original_quests = QuestRegistry.to_dict().duplicate(true)
	_original_soul = GameState.soul_meter
	GameState.flags.clear()
	Reputation.from_dict({})
	Renown.from_dict({})
	QuestRegistry.reset()


func after_test() -> void:
	GameState.party = _original_party
	GameState.flags = _original_flags
	GameState.set_soul_meter(_original_soul)
	Reputation.from_dict(_original_reputation)
	Renown.from_dict(_original_renown)
	QuestRegistry.reset()
	QuestRegistry.from_dict(_original_quests)


func test_fetch_quest_grants_items_and_completes_with_reward() -> void:
	var quest: FetchQuest = QuestRegistry.LOAMROOT_SPRIGS
	var before: int = GameState.item_count(quest.item_id)
	var standing_before: float = Reputation.standing(quest.reward_faction)

	assert_bool(QuestRegistry.debug_force_complete(quest)).is_true()

	assert_bool(QuestRegistry.is_done(quest)).is_true()
	# turn_in consumes the granted items again; the skip must not leak a stack.
	assert_int(GameState.item_count(quest.item_id)).is_equal(before)
	assert_float(Reputation.standing(quest.reward_faction)).is_equal(
		standing_before + quest.reward_amount
	)


func test_side_quest_completes_through_first_authored_outcome() -> void:
	var quest: DomSideQuest = QuestRegistry.DISHONEST_CASKS

	assert_bool(QuestRegistry.debug_force_complete(quest)).is_true()

	assert_bool(QuestRegistry.is_done(quest)).is_true()
	assert_str(str(GameState.get_flag(quest.resolution_flag, ""))).is_equal(
		str(quest.outcome_ids[0])
	)


func test_broken_muster_skip_lands_the_full_chapter_ruling() -> void:
	assert_bool(QuestRegistry.debug_force_complete(QuestRegistry.DORTHKOR_ROAD)).is_true()

	assert_bool(QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)).is_true()
	assert_str(str(GameState.get_flag("chapter_one_resolution", ""))).is_equal("demons-first")
	# The ruling's consequence writes must have happened exactly as in real play.
	assert_float(Reputation.standing("iron-companies")).is_equal(12.0)
	assert_float(Renown.reputation()).is_equal(10.0)


func test_completing_a_done_quest_returns_false() -> void:
	var quest: DomSideQuest = QuestRegistry.DISHONEST_CASKS
	assert_bool(QuestRegistry.debug_force_complete(quest)).is_true()
	assert_bool(QuestRegistry.debug_force_complete(quest)).is_false()


func test_every_quest_can_be_force_completed_in_one_sweep() -> void:
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		if not QuestRegistry.is_done(quest):
			assert_bool(QuestRegistry.debug_force_complete(quest)) \
				.override_failure_message("could not force-complete '%s'" % quest.quest_name) \
				.is_true()
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		assert_bool(QuestRegistry.is_done(quest)) \
			.override_failure_message("'%s' not done after sweep" % quest.quest_name) \
			.is_true()
