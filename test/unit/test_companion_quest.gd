extends GdUnitTestSuite
## FR-505 companion personal quests — Serai-Lun's coverage (see also
## test_wyneth_companion_quest.gd, test_grumbrand_companion_quest.gd).
## See docs/chapter-one-open-questions.md Q8 and CLAUDE.md for the ratified
## scope decision: personal quests are offered automatically the moment a
## recruit joins the active party, and only companions with an entry in
## QuestRegistry.COMPANION_QUESTS have one authored yet.

const DIALOGUE_PATH := "res://dialogue/companions/serai_lun.dialogue"
const PROVISIONAL_MARKER := "# PROVISIONAL — CANON REVIEW REQUIRED"

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
	Renown.from_dict({})
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


func _other_recruit() -> PartyMember:
	for candidate in GameState.recruitable_candidates():
		if (
			candidate.id != "serai-lun"
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
	assert_object(QuestRegistry.companion_quest_for("no-quest-companion")).is_null()
	assert_str(QuestRegistry.companion_quest_dialogue_for("no-quest-companion")).is_empty()


func test_resolving_grants_renown_exactly_once_and_sets_the_flag() -> void:
	GameState.set_companions([_serai_lun(), _other_recruit()])

	var ok: bool = QuestRegistry.resolve_companion_quest(
		"serai-lun", QuestRegistry.SERAI_LUN_QUEST, 6.0, "Told Serai-Lun the line matters"
	)

	assert_bool(ok).is_true()
	assert_bool(GameState.flag_is_true("party_serai_lun_resolved")).is_true()
	assert_bool(QuestRegistry.is_done(QuestRegistry.SERAI_LUN_QUEST)).is_true()
	var events: Array[RenownEvent] = Renown.why(&"reputation", 10)
	assert_int(events.size()).is_equal(1)
	assert_float(events[0].delta).is_equal_approx(6.0, 0.001)

	var again: bool = QuestRegistry.resolve_companion_quest(
		"serai-lun", QuestRegistry.SERAI_LUN_QUEST, 6.0, "Told Serai-Lun the line matters"
	)
	assert_bool(again).is_false()
	assert_int(Renown.why(&"reputation", 10).size()).is_equal(1)


func test_resolve_rejects_a_mismatched_companion_id() -> void:
	GameState.set_companions([_serai_lun(), _other_recruit()])
	var ok: bool = QuestRegistry.resolve_companion_quest(
		"old-grumbrand", QuestRegistry.SERAI_LUN_QUEST, 6.0, "wrong companion"
	)
	assert_bool(ok).is_false()
	assert_bool(GameState.flag_is_true("party_serai_lun_resolved")).is_false()
	assert_bool(QuestRegistry.is_done(QuestRegistry.SERAI_LUN_QUEST)).is_false()


func test_dialogue_offers_and_resolves_through_both_authored_outcomes() -> void:
	var resource: DialogueResource = load(DIALOGUE_PATH)
	assert_object(resource).is_not_null()
	var first_line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, "start")
	assert_object(first_line).is_not_null()
	var source: String = FileAccess.get_file_as_string(DIALOGUE_PATH)
	assert_str(source).contains('QuestRegistry.resolve_companion_quest("serai-lun"')
	assert_str(source).not_contains('GameState.set_flag("party_serai_lun_resolved", true)')


func test_remaining_recruits_have_registered_personal_quests_and_dialogue() -> void:
	assert_object(QuestRegistry.companion_quest_for("ressa-quickfingers")).is_same(
		QuestRegistry.RESSA_QUEST
	)
	assert_object(QuestRegistry.companion_quest_for("korrath-ninefold")).is_same(
		QuestRegistry.KORRATH_QUEST
	)
	assert_object(QuestRegistry.companion_quest_for("maura-greyfen")).is_same(
		QuestRegistry.MAURA_QUEST
	)
	assert_str(QuestRegistry.companion_quest_dialogue_for("ressa-quickfingers")).is_equal(
		"res://dialogue/companions/ressa_quickfingers.dialogue"
	)
	assert_str(QuestRegistry.companion_quest_dialogue_for("korrath-ninefold")).is_equal(
		"res://dialogue/companions/korrath_ninefold.dialogue"
	)
	assert_str(QuestRegistry.companion_quest_dialogue_for("maura-greyfen")).is_equal(
		"res://dialogue/companions/maura_greyfen.dialogue"
	)


func test_new_companion_dialogue_is_provisional_and_uses_self_closing_conditions() -> void:
	var paths: PackedStringArray = PackedStringArray(
		[
			"res://dialogue/companions/ressa_quickfingers.dialogue",
			"res://dialogue/companions/korrath_ninefold.dialogue",
			"res://dialogue/companions/maura_greyfen.dialogue",
		]
	)
	for path: String in paths:
		var source: String = FileAccess.get_file_as_string(path)
		assert_str(source).starts_with(PROVISIONAL_MARKER)
		for line: String in source.split("\n"):
			if "[if " in line:
				assert_str(line).contains(" /]")
		var resource: DialogueResource = load(path)
		assert_object(resource).is_not_null()
		var first_line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, "start")
		assert_object(first_line).is_not_null()


func test_new_companion_resolutions_write_exactly_one_reputation_event() -> void:
	var cases: Array[Dictionary] = [
		{
			"id": "ressa-quickfingers",
			"quest": QuestRegistry.RESSA_QUEST,
			"flag": "party_ressa_quickfingers_resolved",
		},
		{
			"id": "korrath-ninefold",
			"quest": QuestRegistry.KORRATH_QUEST,
			"flag": "party_korrath_ninefold_resolved",
		},
		{
			"id": "maura-greyfen",
			"quest": QuestRegistry.MAURA_QUEST,
			"flag": "party_maura_greyfen_resolved",
		},
	]
	for companion_case: Dictionary in cases:
		Renown.from_dict({})
		QuestRegistry.reset()
		var quest: FlagQuest = companion_case["quest"] as FlagQuest
		QuestRegistry.offer(quest)
		var resolved: bool = QuestRegistry.resolve_companion_quest(
			str(companion_case["id"]), quest, 6.0, "Resolved provisional companion quest"
		)
		assert_bool(resolved).is_true()
		assert_bool(GameState.flag_is_true(str(companion_case["flag"]))).is_true()
		assert_int(Renown.why(&"reputation", 10).size()).is_equal(1)
		assert_bool(
			QuestRegistry.resolve_companion_quest(
				str(companion_case["id"]), quest, 6.0, "Duplicate resolution"
			)
		).is_false()
		assert_int(Renown.why(&"reputation", 10).size()).is_equal(1)
