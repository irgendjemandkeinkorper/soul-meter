extends GdUnitTestSuite

const BattleScript := preload("res://globals/battle.gd")
const FIXTURE_PATH := "res://test/fixtures/harem_stet_speech_encounter.json"
const TEST_ENCOUNTER := &"undertakers-parley-test"
const TEST_FACTION := "undertakers-communion"

var battle
var original_party: Array[PartyMember] = []
var original_flags: Dictionary
var original_reputation: Dictionary
var original_renown: Dictionary
var original_autosave_reason: String


func before_test() -> void:
	original_party = GameState.party.duplicate()
	original_flags = GameState.flags.duplicate(true)
	original_reputation = Reputation.to_dict().duplicate(true)
	original_renown = Renown.to_dict().duplicate(true)
	original_autosave_reason = SaveGame._pending_autosave_reason
	_reset_consequences()
	GameState.party.clear()
	GameState.party.append(_speaker())
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	EncounterCatalog._definitions[String(TEST_ENCOUNTER)] = (
		parsed.duplicate(true) if parsed is Dictionary else {}
	)
	battle = _new_battle()


func after_test() -> void:
	EncounterCatalog._definitions.erase(String(TEST_ENCOUNTER))
	GameState.party.clear()
	for member in original_party:
		GameState.party.append(member)
	GameState.flags = original_flags
	Reputation.from_dict(original_reputation)
	Renown.from_dict(original_renown)
	SaveGame._pending_autosave_reason = original_autosave_reason


func test_speech_is_a_data_declared_ap_costed_verb() -> void:
	var action := CombatActionCatalog.by_id(BattleScript.ACTION_SPEECH)

	assert_object(action).is_not_null()
	assert_int(action.verb).is_equal(CombatAction.Verb.SPEECH)
	assert_int(action.kind).is_equal(CombatAction.Kind.PASS)
	assert_int(action.ap_cost).is_greater(0)
	assert_str(action.summary()).is_equal("Encounter · Opens combat dialogue · 2 AP")
	assert_object(_action(battle, BattleScript.ACTION_SPEECH)).is_not_null()


func test_using_speech_requests_the_authored_dialogue_before_spending_ap() -> void:
	var requests: Array[Dictionary] = []
	battle.speech_requested.connect(
		func(path: String, start: String) -> void:
			requests.append({"path": path, "start": start})
	)
	var ap_before: int = battle.current_ally().action_points

	assert_bool(battle.use_action(BattleScript.ACTION_SPEECH)).is_true()
	assert_int(requests.size()).is_equal(1)
	assert_str(requests[0]["path"]).is_equal(
		"res://test/integration/harem_stet_combat.dialogue"
	)
	assert_str(requests[0]["start"]).is_equal("start")
	assert_int(battle.current_ally().action_points).is_equal(ap_before)


func test_successful_end_removes_every_enemy_without_damage() -> void:
	var foes: Array[BattleActor] = battle.enemies.duplicate()
	var hit_points: Array[int] = []
	for foe in foes:
		hit_points.append(foe.hp)
	var model: BattlefieldModel = battle.controller.battlefield

	var result: Dictionary = battle.commit_speech(&"remembered-name", [1])

	assert_bool(result["allowed"]).is_true()
	assert_bool(result["success"]).is_true()
	assert_int(result["damage"]).is_equal(0)
	assert_bool(battle.ended).is_true()
	assert_str(battle.last_result.outcome_id).is_equal("spared")
	assert_int(battle.enemies.size()).is_equal(0)
	for i in foes.size():
		assert_int(foes[i].hp).is_equal(hit_points[i])
		assert_bool(model.has_combatant(foes[i])).is_false()


func test_successful_split_changes_composition_through_battlefield_model() -> void:
	var departing: BattleActor = battle.enemies[0]
	var model: BattlefieldModel = battle.controller.battlefield

	var result: Dictionary = battle.commit_speech(&"divide-the-offer", [1])

	assert_bool(result["success"]).is_true()
	assert_bool(battle.ended).is_false()
	assert_int(battle.enemies.size()).is_equal(2)
	assert_bool(model.has_combatant(departing)).is_false()
	assert_str(model.side_of(departing)).is_empty()
	for foe in battle.enemies:
		assert_bool(model.has_combatant(foe)).is_true()


func test_successful_turn_moves_an_enemy_to_the_allied_side() -> void:
	var turned: BattleActor = battle.enemies[0]
	var acting: BattleActor = battle.current_ally()
	var model: BattlefieldModel = battle.controller.battlefield
	var allied_side := model.side_of(acting)
	assert_bool(model.side_of(turned) == allied_side).is_false()

	var result: Dictionary = battle.commit_speech(&"turn-the-ledger", [1])

	assert_bool(result["success"]).is_true()
	assert_bool(battle.ended).is_false()
	assert_int(battle.enemies.size()).is_equal(2)
	assert_bool(battle.allies.has(turned)).is_true()
	assert_str(model.side_of(turned)).is_equal(String(allied_side))
	assert_bool(model.combatants_on_side(allied_side).has(turned)).is_true()


func test_failed_speech_spends_ap_and_leaves_a_playable_fight() -> void:
	var foes: Array[BattleActor] = battle.enemies.duplicate()
	var model: BattlefieldModel = battle.controller.battlefield

	var result: Dictionary = battle.commit_speech(&"divide-the-offer", [100])

	assert_bool(result["allowed"]).is_true()
	assert_bool(result["success"]).is_false()
	assert_bool(battle.ended).is_false()
	assert_int(battle.enemies.size()).is_equal(3)
	assert_int(battle.current_ally().action_points).is_equal(2)
	for foe in foes:
		assert_bool(model.has_combatant(foe)).is_true()
	assert_bool(battle.use_action(BattleScript.ACTION_STRIKE)).is_true()
	assert_bool(battle.ended).is_false()


func test_speech_spare_and_slaughter_write_distinct_actual_ledger_events() -> void:
	battle.commit_speech(&"remembered-name", [1])
	var spare_reputation: Dictionary = Reputation.events_for(TEST_FACTION)[0].to_dict()
	var spare_renown: Dictionary = Renown.why(&"reputation", 1)[0].to_dict()
	assert_bool(GameState.get_flag("undertakers_parley_spared")).is_true()
	assert_bool(
		GameState.get_flag("encounter_undertakers_parley_test_spared_consequence")
	).is_true()

	_reset_consequences()
	battle = _new_battle()
	for i in battle.enemies.size():
		battle.enemies[i].hp = 1 if i == 0 else 0
	assert_bool(battle.use_action(BattleScript.ACTION_STRIKE)).is_true()
	var slain_reputation: Dictionary = Reputation.events_for(TEST_FACTION)[0].to_dict()
	var slain_renown: Dictionary = Renown.why(&"infamy", 1)[0].to_dict()

	assert_str(battle.last_result.outcome_id).is_equal("slain")
	assert_bool(GameState.get_flag("undertakers_parley_slain")).is_true()
	assert_bool(
		GameState.get_flag("encounter_undertakers_parley_test_slain_consequence")
	).is_true()
	assert_bool(spare_reputation != slain_reputation).is_true()
	assert_bool(spare_renown != slain_renown).is_true()
	assert_str(spare_reputation["faction"]).is_equal(TEST_FACTION)
	assert_str(slain_reputation["faction"]).is_equal(TEST_FACTION)
	assert_str(spare_reputation["scene"]).is_equal("wintervast-road")
	assert_str(slain_reputation["scene"]).is_equal("wintervast-road")
	assert_bool(spare_reputation["cause"] != slain_reputation["cause"]).is_true()
	assert_str(spare_renown["kind"]).is_equal("reputation")
	assert_str(slain_renown["kind"]).is_equal("infamy")


func test_flee_writes_its_own_events_and_flag_so_retreat_is_costed() -> void:
	battle.flee()

	var reputation_events := Reputation.events_for(TEST_FACTION)
	var infamy_events := Renown.why(&"infamy")
	assert_int(reputation_events.size()).is_equal(1)
	assert_int(infamy_events.size()).is_equal(1)
	assert_str(reputation_events[0].cause).contains("Abandoned the parley")
	assert_str(reputation_events[0].scene).is_equal("wintervast-road")
	assert_float(reputation_events[0].delta).is_less(0.0)
	assert_float(infamy_events[0].delta).is_greater(0.0)
	assert_bool(GameState.get_flag("undertakers_parley_fled")).is_true()
	assert_bool(
		GameState.get_flag("encounter_undertakers_parley_test_fled_consequence")
	).is_true()


func test_reputation_private_ledger_state_has_no_external_writer() -> void:
	var forbidden := ["Reputation._log", "Reputation._standings", "Reputation._events_by_faction"]
	for path in _gdscript_files("res://globals") + _gdscript_files("res://actors") + _gdscript_files("res://ui"):
		if path == "res://globals/reputation.gd":
			continue
		var source := FileAccess.get_file_as_string(path)
		for marker in forbidden:
			assert_str(source).not_contains(marker)
	var ledger_source := FileAccess.get_file_as_string("res://globals/reputation.gd")
	assert_int(ledger_source.count("func record(")).is_equal(1)
	assert_str(ledger_source).not_contains("func set_standing(")


func _new_battle():
	var instance = auto_free(BattleScript.new())
	instance.start(TEST_ENCOUNTER)
	return instance


func _reset_consequences() -> void:
	GameState.flags.clear()
	Reputation.from_dict({})
	Renown.from_dict({})


func _action(source, action_id: StringName) -> CombatAction:
	for action in source.available_actions():
		if action.id == action_id:
			return action
	return null


func _speaker() -> PartyMember:
	var member := PartyMember.new()
	member.display_name = "Vex"
	member.hp = 24
	member.max_hp = 24
	member.attack = 8
	member.defense = 2
	member.attributes = {"voice": 10, "pitch": 10, "edge": 0}
	return member


func _gdscript_files(root: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if directory.current_is_dir():
			result.append_array(_gdscript_files(path))
		elif entry.get_extension() == "gd":
			result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
	return result
