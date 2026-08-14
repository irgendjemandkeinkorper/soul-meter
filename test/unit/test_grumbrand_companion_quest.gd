extends GdUnitTestSuite
## FR-505 companion personal quests — the third worked example (Old Grumbrand).
## Mirrors test_companion_quest.gd's Serai-Lun coverage; see that file and
## CLAUDE.md for the ratified FR-505 scope decision.

const DIALOGUE_PATH := "res://dialogue/companions/old_grumbrand.dialogue"

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


func _grumbrand() -> PartyMember:
	for candidate in GameState.recruitable_candidates():
		if candidate.id == "old-grumbrand":
			return candidate
	fail("old-grumbrand is no longer a recruitable candidate")
	return null


## Deliberately excludes every recruit with authored content, not just this file's own
## companion, so this stays the "no authored content" fixture as more personal quests land.
func _other_recruit() -> PartyMember:
	for candidate in GameState.recruitable_candidates():
		if (
			candidate.id != "old-grumbrand"
			and not QuestRegistry.COMPANION_QUESTS.has(candidate.id)
			and candidate.min_reputation <= 0.0
			and candidate.min_infamy <= 0.0
		):
			return candidate
	fail("no ungated second recruit available")
	return null


func test_joining_the_party_offers_his_personal_quest_exactly_once() -> void:
	assert_bool(QuestRegistry.is_active(QuestRegistry.GRUMBRAND_QUEST)).is_false()
	assert_bool(GameState.set_companions([_grumbrand(), _other_recruit()])).is_true()
	assert_bool(QuestRegistry.is_active(QuestRegistry.GRUMBRAND_QUEST)).is_true()


func test_resolving_grants_renown_exactly_once_and_sets_the_flag() -> void:
	GameState.set_companions([_grumbrand(), _other_recruit()])
	GameState.set_flag("party_grumbrand_resolved", true)

	var ok := QuestRegistry.resolve_companion_quest(
		"old-grumbrand", QuestRegistry.GRUMBRAND_QUEST, 6.0, "Told Grumbrand his silence was mercy enough"
	)

	assert_bool(ok).is_true()
	assert_bool(QuestRegistry.is_done(QuestRegistry.GRUMBRAND_QUEST)).is_true()
	var events: Array[RenownEvent] = Renown.why(&"reputation", 10)
	assert_int(events.size()).is_equal(1)
	assert_float(events[0].delta).is_equal_approx(6.0, 0.001)

	var again := QuestRegistry.resolve_companion_quest(
		"old-grumbrand", QuestRegistry.GRUMBRAND_QUEST, 6.0, "Told Grumbrand his silence was mercy enough"
	)
	assert_bool(again).is_false()
	assert_int(Renown.why(&"reputation", 10).size()).is_equal(1)


func test_resolve_rejects_a_mismatched_companion_id() -> void:
	GameState.set_companions([_grumbrand(), _other_recruit()])
	GameState.set_flag("party_grumbrand_resolved", true)
	var ok := QuestRegistry.resolve_companion_quest(
		"serai-lun", QuestRegistry.GRUMBRAND_QUEST, 6.0, "wrong companion"
	)
	assert_bool(ok).is_false()
	assert_bool(QuestRegistry.is_done(QuestRegistry.GRUMBRAND_QUEST)).is_false()


func test_dialogue_offers_and_resolves_through_both_authored_outcomes() -> void:
	var resource: DialogueResource = load(DIALOGUE_PATH)
	assert_object(resource).is_not_null()
	var first_line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, "start")
	assert_object(first_line).is_not_null()
	var source := FileAccess.get_file_as_string(DIALOGUE_PATH)
	assert_str(source).contains('QuestRegistry.resolve_companion_quest("old-grumbrand"')
	assert_str(source).contains('GameState.set_flag("party_grumbrand_resolved", true)')
