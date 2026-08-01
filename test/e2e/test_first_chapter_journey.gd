extends GdUnitTestSuite
## Deterministic first-chapter journey fixtures.
##
## These tests intentionally exercise the durable state seams rather than
## simulating pixels. Private battle finishing is used only to set up defeat,
## which is documented by the retry fixture below.

const BattleScript := preload("res://globals/battle.gd")

var original_flags: Dictionary
var original_party: Array[PartyMember]
var original_soul: float
var original_reputation: Dictionary
var original_renown: Dictionary
var original_quests: Dictionary
var original_autosave_reason: String


func before_test() -> void:
	original_flags = GameState.flags.duplicate(true)
	original_party = GameState.party.duplicate()
	original_soul = GameState.soul_meter
	original_reputation = Reputation.to_dict().duplicate(true)
	original_renown = Renown.to_dict().duplicate(true)
	original_quests = QuestRegistry.to_dict().duplicate(true)
	original_autosave_reason = SaveGame._pending_autosave_reason
	_reset_fixture()


func after_test() -> void:
	GameState.flags = original_flags
	GameState.party = original_party
	GameState.soul_meter = original_soul
	Reputation.from_dict(original_reputation)
	Renown.from_dict(original_renown)
	QuestRegistry.reset()
	QuestRegistry.from_dict(original_quests)
	SaveGame._pending_autosave_reason = original_autosave_reason


func test_fresh_journey_reaches_complete_and_free_roam() -> void:
	_assert_journey_prerequisites()
	_resolve_vanguard()
	_resolve_muster(&"slain")
	_assert_return_stage()

	GameState.set_flag("chapter_one_resolution", "hold-both")
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.COMPLETE)
	GameState.set_flag("chapter_one_free_roam", true)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.FREE_ROAM)


func test_all_three_bloodbellow_outcomes_are_isolated_and_durable() -> void:
	for outcome_id in [&"slain", &"named", &"released"]:
		_reset_fixture()
		_assert_journey_prerequisites()
		_resolve_vanguard()
		_resolve_muster(outcome_id)
		assert_str(GameState.get_flag("dorthkor_muster_outcome")).is_equal(String(outcome_id))
		_assert_return_stage()


func test_all_three_dom_rulings_complete_the_same_chapter_stage() -> void:
	for ruling in ["demons-first", "dead-first", "hold-both"]:
		_reset_fixture()
		_assert_journey_prerequisites()
		_resolve_vanguard()
		_resolve_muster(&"slain")
		GameState.set_flag("chapter_one_resolution", ruling)
		assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.COMPLETE)


func test_defeat_retry_preserves_recovery_and_applies_loss_once() -> void:
	_assert_journey_prerequisites()
	var first_loss = BattleScript.new()
	auto_free(first_loss)
	first_loss.start(EncounterIds.BOG_WIGHT)
	first_loss._finish(BattleResult.State.DEFEAT, BattleScript.OUTCOME_DEFEAT)
	assert_bool(GameState.get_flag("defeated_bog_wight")).is_false()
	assert_str(GameState.get_flag("encounter_bog_wight_outcome")).is_equal("defeat")
	assert_float(Reputation.standing("ssae-seeders")).is_equal_approx(-3.0, 0.001)

	var retry_loss = BattleScript.new()
	auto_free(retry_loss)
	retry_loss.start(EncounterIds.BOG_WIGHT)
	retry_loss._finish(BattleResult.State.DEFEAT, BattleScript.OUTCOME_DEFEAT)
	assert_float(Reputation.standing("ssae-seeders")).is_equal_approx(-3.0, 0.001)

	var retry_win = BattleScript.new()
	auto_free(retry_win)
	retry_win.start(EncounterIds.BOG_WIGHT)
	retry_win.enemies[0].hp = 1
	retry_win.use_action(BattleScript.ACTION_STRIKE)
	assert_bool(GameState.get_flag("defeated_bog_wight")).is_true()
	assert_str(retry_win.last_result.outcome_id).is_equal("slain")


func test_checkpoint_payload_reconstructs_party_quests_and_flags() -> void:
	_assert_journey_prerequisites()
	var payload := SaveGame._build_payload()
	assert_bool(SaveGame.validate_payload(payload)).is_true()

	var state_payload: Dictionary = payload["game_state"]
	var reputation_payload: Dictionary = payload["reputation"]
	var renown_payload: Dictionary = payload["renown"]
	var quest_payload: Dictionary = payload["quests"]
	GameState.flags.clear()
	GameState.party.clear()
	QuestRegistry.reset()
	assert_bool(GameState.from_dict(state_payload)).is_true()
	Reputation.from_dict(reputation_payload)
	Renown.from_dict(renown_payload)
	QuestRegistry.from_dict(quest_payload)

	assert_bool(GameState.has_selected_companions()).is_true()
	assert_bool(GameState.get_flag("chapter_dorthkor_commissioned")).is_true()
	assert_bool(QuestRegistry.is_active(QuestRegistry.DORTHKOR_ROAD)).is_true()


func _reset_fixture() -> void:
	GameState.flags.clear()
	GameState.soul_meter = 50.0
	GameState._seed_demo_data()
	Reputation.from_dict({})
	Renown.from_dict({})
	QuestRegistry.reset()
	SaveGame._pending_autosave_reason = ""


func _assert_journey_prerequisites() -> void:
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.RECRUIT)
	var candidates := GameState.recruitable_candidates()
	assert_bool(GameState.set_companions([candidates[0], candidates[1]])).is_true()
	QuestRegistry.offer(QuestRegistry.DORTHKOR_ROAD)
	GameState.set_flag("chapter_dorthkor_reached", true)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.SECURE_ROAD)


func _resolve_vanguard() -> void:
	var battle = BattleScript.new()
	auto_free(battle)
	battle.start(EncounterIds.DORTHKOR_VANGUARD)
	for enemy in battle.enemies:
		enemy.hp = 1
	while not battle.ended:
		assert_bool(battle.use_action(BattleScript.ACTION_STRIKE)).is_true()
	assert_bool(GameState.get_flag("defeated_breach_hound")).is_true()


func _resolve_muster(outcome_id: StringName) -> void:
	var battle = BattleScript.new()
	auto_free(battle)
	battle.start(EncounterIds.DORTHKOR_MUSTER)
	if outcome_id == &"named":
		battle.shift_balance(50)
		assert_bool(battle.use_action(&"speak-muster-name")).is_true()
	elif outcome_id == &"released":
		battle.enemy_rounds = 1
		assert_bool(battle.use_action(&"release-bound-soldier")).is_true()
	else:
		battle.enemies[0].hp = 1
		assert_bool(battle.use_action(BattleScript.ACTION_STRIKE)).is_true()
	assert_str(battle.last_result.outcome_id).is_equal(String(outcome_id))


func _assert_return_stage() -> void:
	QuestSystem.update_quest(QuestRegistry.DORTHKOR_ROAD)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.RETURN)
