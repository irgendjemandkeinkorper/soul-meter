extends GdUnitTestSuite
## FR-505 companion personal quests — Serai-Lun's coverage (see also
## test_wyneth_companion_quest.gd, test_grumbrand_companion_quest.gd).
## See docs/chapter-one-open-questions.md Q8 and CLAUDE.md for the ratified
## scope decision: personal quests are offered automatically the moment a
## recruit joins the active party, and only companions with an entry in
## QuestRegistry.COMPANION_QUESTS have one authored yet.

const DIALOGUE_PATH := "res://dialogue/companions/serai_lun.dialogue"

var _original_party: Array[PartyMember]
var _original_flags: Dictionary
var _original_renown: Dictionary
var _original_quests: Dictionary


func before_test() -> void:
	_original_party = GameState.party.duplicate()
	_original_flags = GameState.flags.duplicate(true)
	_original_renown = Renown.to_dict().duplicate(true)
	_original_quests = QuestRegistry.to_dict().duplicate(true)
	GameState.flags.clear()
	QuestRegistry.reset()


func after_test() -> void:
	GameState.party = _original_party
	GameState.flags = _original_flags
	Renown.from_dict(_original_renown)
	QuestRegistry.reset()
	QuestRegistry.from_dict(_original_quests)


func _serai_lun() -> PartyMember:
	for candidate in GameState.recruitable_candidates():
		if candidate.id == "serai-lun":
			return candidate
	fail("serai-lun is no longer a recruitable candidate")
	return null


## Deliberately excludes every recruit with authored content, not just this file's own
## companion, so this stays the "no authored content" fixture as more personal quests land.
func _other_recruit() -> PartyMember:
	for candidate in GameState.recruitable_candidates():
		if (
			candidate.id != "serai-lun"
			and not QuestRegistry.COMPANION_QUESTS.has(candidate.id)
			and candidate.min_reputation <= 0.0
			and candidate.min_infamy <= 0.0
		):
			return candidate
	fail("no ungated second recruit available")
	return null


func test_joining_the_party_offers_her_personal_quest_exactly_once() -> void:
	assert_bool(QuestRegistry.is_active(QuestRegistry.SERAI_LUN_QUEST)).is_false()
	assert_bool(GameState.set_companions([_serai_lun(), _other_recruit()])).is_true()
	assert_bool(QuestRegistry.is_active(QuestRegistry.SERAI_LUN_QUEST)).is_true()


func test_recruit_without_authored_content_has_no_dialogue_or_quest() -> void:
	var undecided := _other_recruit()
	assert_object(QuestRegistry.companion_quest_for(undecided.id)).is_null()
	assert_str(QuestRegistry.companion_quest_dialogue_for(undecided.id)).is_empty()


func test_resolving_grants_renown_exactly_once_and_sets_the_flag() -> void:
	GameState.set_companions([_serai_lun(), _other_recruit()])
	GameState.set_flag("party_serai_lun_resolved", true)

	var ok := QuestRegistry.resolve_companion_quest(
		"serai-lun", QuestRegistry.SERAI_LUN_QUEST, 6.0, "Told Serai-Lun the line matters"
	)

	assert_bool(ok).is_true()
	assert_bool(QuestRegistry.is_done(QuestRegistry.SERAI_LUN_QUEST)).is_true()
	var events: Array[RenownEvent] = Renown.why(&"reputation", 10)
	assert_int(events.size()).is_equal(1)
	assert_float(events[0].delta).is_equal_approx(6.0, 0.001)

	var again := QuestRegistry.resolve_companion_quest(
		"serai-lun", QuestRegistry.SERAI_LUN_QUEST, 6.0, "Told Serai-Lun the line matters"
	)
	assert_bool(again).is_false()
	assert_int(Renown.why(&"reputation", 10).size()).is_equal(1)


func test_resolve_rejects_a_mismatched_companion_id() -> void:
	GameState.set_companions([_serai_lun(), _other_recruit()])
	GameState.set_flag("party_serai_lun_resolved", true)
	var ok := QuestRegistry.resolve_companion_quest(
		"old-grumbrand", QuestRegistry.SERAI_LUN_QUEST, 6.0, "wrong companion"
	)
	assert_bool(ok).is_false()
	assert_bool(QuestRegistry.is_done(QuestRegistry.SERAI_LUN_QUEST)).is_false()


func test_dialogue_offers_and_resolves_through_both_authored_outcomes() -> void:
	var resource: DialogueResource = load(DIALOGUE_PATH)
	assert_object(resource).is_not_null()
	var first_line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, "start")
	assert_object(first_line).is_not_null()
	var source := FileAccess.get_file_as_string(DIALOGUE_PATH)
	assert_str(source).contains('QuestRegistry.resolve_companion_quest("serai-lun"')
	assert_str(source).contains('GameState.set_flag("party_serai_lun_resolved", true)')
