extends GdUnitTestSuite
## FR-505 companion personal quest coverage for Maura Greyfen.

const COMPANION_ID := "maura-greyfen"
const DIALOGUE_PATH := "res://dialogue/companions/maura_greyfen.dialogue"

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


func test_joining_party_offers_maura_quest_and_dialogue_is_loadable() -> void:
	var maura: PartyMember = _candidate(COMPANION_ID)
	var other: PartyMember = _other_recruit(COMPANION_ID)
	_unlock_recruit(maura)
	_unlock_recruit(other)

	assert_bool(GameState.set_companions([maura, other])).is_true()
	assert_bool(QuestRegistry.is_active(QuestRegistry.MAURA_QUEST)).is_true()
	assert_object(QuestRegistry.companion_quest_for(COMPANION_ID)).is_same(
		QuestRegistry.MAURA_QUEST
	)
	var resource: DialogueResource = load(DIALOGUE_PATH) as DialogueResource
	assert_object(resource).is_not_null()


func _candidate(companion_id: String) -> PartyMember:
	for candidate: PartyMember in GameState.recruitable_candidates():
		if candidate.id == companion_id:
			return candidate
	fail("%s is no longer a recruitable candidate" % companion_id)
	return null


func _other_recruit(companion_id: String) -> PartyMember:
	for candidate: PartyMember in GameState.recruitable_candidates():
		if candidate.id != companion_id:
			return candidate
	fail("no second recruit available")
	return null


func _unlock_recruit(candidate: PartyMember) -> void:
	if candidate == null:
		return
	var missing_reputation: float = candidate.min_reputation - Renown.reputation()
	if missing_reputation > 0.0:
		Renown.gain_reputation("player", missing_reputation, "test recruit unlock", "test")
	var missing_infamy: float = candidate.min_infamy - Renown.infamy()
	if missing_infamy > 0.0:
		Renown.gain_infamy("player", missing_infamy, "test recruit unlock", "test")
