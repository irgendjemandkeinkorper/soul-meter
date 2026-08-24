extends GdUnitTestSuite
## Deterministic first-chapter journey fixtures.
##
## These tests intentionally exercise the durable state seams rather than
## simulating pixels. Private battle finishing is used only to set up defeat,
## which is documented by the retry fixture below.

const BattleScript := preload("res://globals/battle.gd")
const MARSHAL_DIALOGUE_PATH := "res://dialogue/marshal_coiljaw.dialogue"
const IRIS_DIALOGUE_PATH := "res://dialogue/iris_illepah.dialogue"
const SELLA_DIALOGUE_PATH := "res://dialogue/sella_varn.dialogue"
const SERAI_LUN_DIALOGUE_PATH := "res://dialogue/companions/serai_lun.dialogue"
const WYNETH_DIALOGUE_PATH := "res://dialogue/companions/wyneth_hallow_tide.dialogue"
const GRUMBRAND_DIALOGUE_PATH := "res://dialogue/companions/old_grumbrand.dialogue"
const RESSA_DIALOGUE_PATH := "res://dialogue/companions/ressa_quickfingers.dialogue"
const KORRATH_DIALOGUE_PATH := "res://dialogue/companions/korrath_ninefold.dialogue"
const MAURA_DIALOGUE_PATH := "res://dialogue/companions/maura_greyfen.dialogue"
const PLACEMENTS_PATH := "res://data/generated/dom_npc_placements.json"

var original_game_state: Dictionary
var original_reputation: Dictionary
var original_renown: Dictionary
var original_quests: Dictionary
var original_autosave_reason: String
var original_save_runtime: Dictionary
var original_flow_target_scene: String
var original_flow_target_spawn: StringName


func before_test() -> void:
	UIManager.close_all()
	get_tree().paused = false
	original_game_state = GameState.to_dict().duplicate(true)
	original_reputation = Reputation.to_dict().duplicate(true)
	original_renown = Renown.to_dict().duplicate(true)
	original_quests = QuestRegistry.to_dict().duplicate(true)
	original_autosave_reason = SaveGame._pending_autosave_reason
	original_save_runtime = {
		"pending_player_position": SaveGame.pending_player_position,
		"has_pending_player_position": SaveGame.has_pending_player_position,
		"pending_spawn_id": SaveGame.pending_spawn_id,
		"run_started_unix": SaveGame._run_started_unix,
		"elapsed_before_load": SaveGame._elapsed_before_load,
		"ng_plus": SaveGame.ng_plus.duplicate(true),
		"zhavar": SaveGame.zhavar.duplicate(true),
	}
	original_flow_target_scene = GameFlow._target_scene
	original_flow_target_spawn = GameFlow._target_spawn_id
	_reset_fixture()


func after_test() -> void:
	UIManager.close_all()
	get_tree().paused = false
	GameState.from_dict(original_game_state)
	Reputation.from_dict(original_reputation)
	Renown.from_dict(original_renown)
	QuestRegistry.reset()
	QuestRegistry.from_dict(original_quests)
	SaveGame._pending_autosave_reason = original_autosave_reason
	SaveGame.pending_player_position = original_save_runtime["pending_player_position"]
	SaveGame.has_pending_player_position = original_save_runtime["has_pending_player_position"]
	SaveGame.pending_spawn_id = original_save_runtime["pending_spawn_id"]
	SaveGame._run_started_unix = original_save_runtime["run_started_unix"]
	SaveGame._elapsed_before_load = original_save_runtime["elapsed_before_load"]
	SaveGame.ng_plus = original_save_runtime["ng_plus"]
	SaveGame.zhavar = original_save_runtime["zhavar"]
	GameFlow._target_scene = original_flow_target_scene
	GameFlow._target_spawn_id = original_flow_target_spawn


func test_boot_recruit_commission_side_thread_encounters_and_ruling_reach_ledger() -> void:
	SaveGame.new_game()
	# This journey exercises the base COMPLETE -> FREE_ROAM path, which is
	# still reachable with extended content off (e.g. --no-extended-content);
	# the extended-content-on path is covered separately in
	# test_chapter_one_progress.gd's test_extended_content_flag_continues_into_the_deep_trial.
	GameState.set_flag("prototype_extended_content", false)
	assert_str(ProjectSettings.get_setting("application/run/main_scene")).is_equal(
		"res://ui/screens/main_menu.tscn"
	)
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TOWN_SCENE)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.RECRUIT)

	var runner := scene_runner(GameFlow.TOWN_SCENE)
	await runner.simulate_frames(8)
	await _assert_objective_surfaces(runner)
	await _recruit_at_tavern(runner)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.REPORT)
	await _assert_objective_surfaces(runner)

	var marshal := load(MARSHAL_DIALOGUE_PATH) as DialogueResource
	await _choose_response(marshal, "start", "Give me the road commission.")
	assert_bool(QuestRegistry.is_active(QuestRegistry.DORTHKOR_ROAD)).is_true()
	assert_bool(GameState.get_flag("chapter_dorthkor_commissioned")).is_true()
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.SECURE_ROAD)
	await _assert_objective_surfaces(runner)

	# Carry one authored town thread through the main endpoint: its objective is
	# visible while active, and its authored outcome is read back by the ledger.
	var side_quest := QuestRegistry.DISHONEST_CASKS
	var giver := NpcRoster.get_npc(side_quest.giver_actor_id)
	var giver_dialogue: Dictionary = giver["dialogue"]
	var route := QuestRegistry.dialogue_route_for_actor(
		side_quest.giver_actor_id, str(giver_dialogue["path"]), str(giver_dialogue["title"])
	)
	var side_resource := load(str(route["path"])) as DialogueResource
	await _choose_first_allowed_response(side_resource, str(route["title"]))
	assert_bool(QuestRegistry.is_active(side_quest)).is_true()
	await _assert_side_objective_visible(runner, side_quest)
	for required_flag: String in side_quest.required_flags:
		GameState.set_flag(required_flag, true)
	assert_bool(
		QuestRegistry.resolve_side_quest(side_quest, side_quest.outcome_ids[0])
	).is_true()

	GameState.set_flag("chapter_dorthkor_reached", true)
	await _assert_objective_surfaces(runner)
	_resolve_vanguard()
	await _assert_objective_surfaces(runner)
	_resolve_muster(&"slain")
	_assert_return_stage()
	await _assert_objective_surfaces(runner)

	await _choose_response(marshal, "start", "I destroyed the Bloodbellow")
	assert_bool(GameState.get_flag("reported_bloodbellow")).is_true()
	await _choose_response(marshal, "start", "Split the Companies")
	assert_bool(QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)).is_true()
	assert_str(GameState.get_flag("chapter_one_resolution")).is_equal("hold-both")
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.COMPLETE)
	await _assert_objective_surfaces(runner)

	GameFlow._on_chapter_complete_entered()
	await runner.simulate_frames(2)
	assert_bool(UIManager.is_open()).is_true()
	var ledger_screen: Control = UIManager._stack.back()
	assert_str(ledger_screen.scene_file_path).is_equal(
		"res://ui/screens/chapter_complete.tscn"
	)
	var side_ledger := ledger_screen.find_child("SideQuestLedger", true, false) as Label
	assert_object(side_ledger).is_not_null()
	assert_str(side_ledger.text).contains(side_quest.quest_name.to_upper())
	assert_str(side_ledger.text).contains(QuestRegistry.side_quest_readback(side_quest))
	GameFlow._on_chapter_complete_exited()

	# The endpoint's continue action is the only transition from completion to
	# free roam; exercise the durable fact even though the screen is now closed.
	GameState.set_flag("chapter_one_free_roam", true)
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.FREE_ROAM)


func test_every_registered_quest_has_a_playable_dialogue_starter() -> void:
	var reached := {}
	var placements: Dictionary = _json(PLACEMENTS_PATH)["placements"]
	for side_quest: DomSideQuest in QuestRegistry.DOM_SIDE_QUESTS:
		_reset_fixture()
		var giver := NpcRoster.get_npc(side_quest.giver_actor_id)
		assert_bool(giver.is_empty()).is_false()
		assert_bool(placements.has(side_quest.giver_actor_id)).is_true()
		var placement: Dictionary = placements[side_quest.giver_actor_id]
		assert_bool(LocationRegistry.is_gameplay_scene(str(placement["scene"]))).is_true()
		var dialogue: Dictionary = giver["dialogue"]
		var route := QuestRegistry.dialogue_route_for_actor(
			side_quest.giver_actor_id, str(dialogue["path"]), str(dialogue["title"])
		)
		assert_str(str(route["path"])).is_equal(QuestRegistry.DOM_SIDE_QUEST_DIALOGUE_PATH)
		assert_str(str(route["title"])).is_equal(side_quest.dialogue_title)
		var resource := load(str(route["path"])) as DialogueResource
		await _choose_first_allowed_response(resource, str(route["title"]))
		assert_bool(QuestRegistry.is_active(side_quest)).is_true()
		reached[side_quest.id] = true

	_reset_fixture()
	await _start_quest_from_dialogue(
		QuestRegistry.LOAMROOT_SPRIGS, IRIS_DIALOGUE_PATH, "start", "work I could do"
	)
	reached[QuestRegistry.LOAMROOT_SPRIGS.id] = true

	_reset_fixture()
	_select_companions()
	await _start_quest_from_dialogue(
		QuestRegistry.DORTHKOR_ROAD, MARSHAL_DIALOGUE_PATH, "start", "road commission"
	)
	reached[QuestRegistry.DORTHKOR_ROAD.id] = true

	_reset_fixture()
	QuestSystem.completed.add_quest(QuestRegistry.DORTHKOR_ROAD)
	GameState.set_flag("chapter_one_resolution", "dead-first")
	GameState.set_flag("prototype_extended_content", true)
	await _start_quest_from_dialogue(
		QuestRegistry.DEEP_TRIAL, MARSHAL_DIALOGUE_PATH, "start", "What follows"
	)
	reached[QuestRegistry.DEEP_TRIAL.id] = true

	_reset_fixture()
	await _start_quest_from_dialogue(
		QuestRegistry.BELLHOUSE_REPAIR, SELLA_DIALOGUE_PATH, "start", "What happened"
	)
	reached[QuestRegistry.BELLHOUSE_REPAIR.id] = true

	_reset_fixture()
	await _start_quest_from_dialogue(
		QuestRegistry.FIELD_DEBT, MARSHAL_DIALOGUE_PATH, "start", "Accept the field debt"
	)
	reached[QuestRegistry.FIELD_DEBT.id] = true

	_reset_fixture()
	_select_companions()  # candidates[0] is Serai-Lun — recruiting her auto-offers her
	# personal quest (see QuestRegistry._offer_companion_quests_for_party()), so by the
	# time her dialogue opens the "offer" branch has already given way to "in progress".
	await _start_quest_from_dialogue(
		QuestRegistry.SERAI_LUN_QUEST, SERAI_LUN_DIALOGUE_PATH, "start", "What line are you watching"
	)
	reached[QuestRegistry.SERAI_LUN_QUEST.id] = true

	# Wyneth is not one of _select_companions()'s fixed candidates[0]/[1], so her
	# personal quest is not auto-offered here — start it straight from her own
	# dialogue, same as the marshal-given quests above.
	await _start_quest_from_dialogue(
		QuestRegistry.WYNETH_QUEST, WYNETH_DIALOGUE_PATH, "start", "You never finish the muster forms"
	)
	reached[QuestRegistry.WYNETH_QUEST.id] = true

	# Old Grumbrand IS one of _select_companions()'s fixed candidates[0]/[1] (candidate
	# index 1), so recruiting him above already auto-offered this one — the "offer" hub
	# line is already gone, same as Serai-Lun above, so this jumps straight to the
	# "reveal" response.
	await _start_quest_from_dialogue(
		QuestRegistry.GRUMBRAND_QUEST, GRUMBRAND_DIALOGUE_PATH, "start", "What does it mean"
	)
	reached[QuestRegistry.GRUMBRAND_QUEST.id] = true

	await _start_quest_from_dialogue(
		QuestRegistry.RESSA_QUEST, RESSA_DIALOGUE_PATH, "start", "weak flank first"
	)
	reached[QuestRegistry.RESSA_QUEST.id] = true

	await _start_quest_from_dialogue(
		QuestRegistry.KORRATH_QUEST, KORRATH_DIALOGUE_PATH, "start", "prove every command"
	)
	reached[QuestRegistry.KORRATH_QUEST.id] = true

	await _start_quest_from_dialogue(
		QuestRegistry.MAURA_QUEST, MAURA_DIALOGUE_PATH, "start", "trusted the name"
	)
	reached[QuestRegistry.MAURA_QUEST.id] = true

	assert_int(reached.size()).is_equal(QuestRegistry.ALL_QUESTS.size())
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		assert_bool(reached.has(quest.id)).is_true()


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
		GameState.set_flag("reported_bloodbellow", true)
		assert_bool(QuestRegistry.resolve_broken_muster(ruling)).is_true()
		assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.COMPLETE)
		assert_bool(QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)).is_true()


func test_broken_muster_cannot_complete_without_an_atomic_ruling() -> void:
	_assert_journey_prerequisites()
	_resolve_vanguard()
	_resolve_muster(&"slain")
	_assert_return_stage()
	GameState.set_flag("reported_bloodbellow", true)

	QuestRegistry.turn_in(QuestRegistry.DORTHKOR_ROAD, "dead-first", false)
	assert_bool(QuestRegistry.is_active(QuestRegistry.DORTHKOR_ROAD)).is_true()
	assert_bool(QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)).is_false()
	assert_str(GameState.get_flag("chapter_one_resolution", "")).is_empty()
	assert_int(ChapterOneProgress.current_stage()).is_equal(ChapterOneProgress.Stage.RETURN)

	assert_bool(QuestRegistry.resolve_broken_muster(&"dead-first")).is_true()
	assert_bool(QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)).is_true()
	assert_str(GameState.get_flag("chapter_one_resolution")).is_equal("dead-first")
	assert_bool(QuestRegistry.resolve_broken_muster(&"dead-first")).is_false()


func test_extreme_soul_values_keep_an_unconditional_ruling_route() -> void:
	for case: Dictionary in [
		{"soul": 0.0, "ruling": &"demons-first"},
		{"soul": 100.0, "ruling": &"dead-first"},
	]:
		_reset_fixture()
		_assert_journey_prerequisites()
		_resolve_vanguard()
		_resolve_muster(&"slain")
		GameState.set_flag("reported_bloodbellow", true)
		GameState.soul_meter = case["soul"]
		assert_bool(QuestRegistry.resolve_broken_muster(case["ruling"])).is_true()
		assert_int(ChapterOneProgress.current_stage()).is_equal(
			ChapterOneProgress.Stage.COMPLETE
		)

	_reset_fixture()
	_assert_journey_prerequisites()
	_resolve_vanguard()
	_resolve_muster(&"slain")
	GameState.set_flag("reported_bloodbellow", true)
	GameState.soul_meter = 0.0
	assert_bool(QuestRegistry.resolve_broken_muster(&"hold-both")).is_false()
	assert_bool(QuestRegistry.resolve_broken_muster(&"demons-first")).is_true()


func test_chapter_encounter_defeat_and_retreat_both_leave_retry_routes() -> void:
	_assert_journey_prerequisites()
	for encounter_id: StringName in [EncounterIds.DORTHKOR_VANGUARD, EncounterIds.DORTHKOR_MUSTER]:
		var defeated_flag := EncounterCatalog.defeated_flag(encounter_id)
		for state: BattleResult.State in [BattleResult.State.DEFEAT, BattleResult.State.FLED]:
			GameState.flags.erase(defeated_flag)
			var failed_attempt = BattleScript.new()
			auto_free(failed_attempt)
			failed_attempt.start(encounter_id)
			failed_attempt._finish(
				state,
				BattleScript.OUTCOME_DEFEAT if state == BattleResult.State.DEFEAT else BattleScript.OUTCOME_FLED
			)
			assert_bool(GameState.get_flag(defeated_flag, false)).is_false()

			var retry = BattleScript.new()
			auto_free(retry)
			retry.start(encounter_id)
			for enemy: BattleActor in retry.enemies:
				enemy.hp = 1
			while not retry.ended:
				assert_bool(retry.use_action(BattleScript.ACTION_STRIKE)).is_true()
			assert_bool(GameState.get_flag(defeated_flag)).is_true()


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
	# Grid battles roll to-hit (#169/#98 rulings) — a single strike may whiff, so
	# strike until the battle ends, as the retry-routes test above already does.
	while not retry_win.ended:
		assert_bool(retry_win.use_action(BattleScript.ACTION_STRIKE)).is_true()
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
	_select_companions()
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


func _select_companions() -> void:
	var candidates := GameState.recruitable_candidates()
	assert_bool(GameState.set_companions([candidates[0], candidates[1]])).is_true()


func _recruit_at_tavern(runner: GdUnitSceneRunner) -> void:
	var door: Node2D = runner.find_child("TavernDoor", true, false)
	var player: Node2D = runner.find_child("Player", true, false)
	assert_object(door).is_not_null()
	assert_object(player).is_not_null()
	player.global_position = door.global_position
	await runner.simulate_frames(20)
	runner.simulate_action_press("interact")
	await runner.simulate_frames(5)
	runner.simulate_action_release("interact")
	# The door no longer opens the picker over the town map — it travels to the
	# Four Arms interior; the picker is opened at the taverner's counter there.
	assert_str(GameFlow._target_scene).is_equal(GameFlow.TAVERN_SCENE)
	assert_str(GameFlow._target_spawn_id).is_equal("entry")
	var tavern: Control = UIManager.open(UIManager.TAVERN, true)
	assert_object(tavern).is_not_null()
	assert_str(tavern.scene_file_path).is_equal("res://ui/screens/tavern.tscn")
	var chosen := 0
	for check: CheckBox in tavern._checks:
		if check.disabled:
			continue
		check.button_pressed = true
		tavern._on_toggled(true, check)
		chosen += 1
		if chosen == 2:
			break
	assert_int(chosen).is_equal(2)
	tavern._on_confirm()
	await runner.simulate_frames(2)
	assert_bool(GameState.has_selected_companions()).is_true()
	assert_bool(UIManager.is_open()).is_false()


func _assert_objective_surfaces(runner: GdUnitSceneRunner) -> void:
	await runner.simulate_frames(2)
	var expected := ChapterOneProgress.objective()
	var hud_objective := runner.find_child("Objective", true, false) as Label
	assert_object(hud_objective).is_not_null()
	assert_str(hud_objective.text).contains(expected)
	assert_str(hud_objective.text).contains(ChapterOneProgress.title())

	var journal = UIManager.open(UIManager.JOURNAL, true)
	await runner.simulate_frames(2)
	var journal_objective := journal.find_child("NextObjective", true, false) as Label
	assert_object(journal_objective).is_not_null()
	assert_str(journal_objective.text).is_equal("NEXT OBJECTIVE\n" + expected)
	UIManager.back()
	await runner.simulate_frames(2)


func _assert_side_objective_visible(
	runner: GdUnitSceneRunner, quest: DomSideQuest
) -> void:
	var journal = UIManager.open(UIManager.JOURNAL, true)
	await runner.simulate_frames(2)
	var active := journal.find_child("ActiveQuests", true, false) as VBoxContainer
	assert_object(active).is_not_null()
	var active_text := _label_text(active)
	assert_str(active_text).contains(quest.quest_name)
	assert_str(active_text).contains(QuestRegistry.objective_for(quest))
	UIManager.back()
	await runner.simulate_frames(2)


func _start_quest_from_dialogue(
	quest: Quest, dialogue_path: String, title: String, response_text: String
) -> void:
	var resource := load(dialogue_path) as DialogueResource
	assert_object(resource).is_not_null()
	await _choose_response(resource, title, response_text)
	assert_bool(QuestRegistry.is_active(quest)).is_true()


func _choose_response(
	resource: DialogueResource, title: String, response_text: String
) -> void:
	var line := await _line_with_responses(resource, title)
	if line == null:
		return
	for response: DialogueResponse in line.responses:
		if response.is_allowed and response.text.contains(response_text):
			await DialogueManager.get_next_dialogue_line(resource, response.next_id)
			return
	fail("No allowed response containing '%s' at dialogue title '%s'." % [response_text, title])


func _choose_first_allowed_response(resource: DialogueResource, title: String) -> void:
	var line := await _line_with_responses(resource, title)
	if line == null:
		return
	for response: DialogueResponse in line.responses:
		if response.is_allowed:
			await DialogueManager.get_next_dialogue_line(resource, response.next_id)
			return
	fail("No allowed response at dialogue title '%s'." % title)


func _line_with_responses(resource: DialogueResource, title: String) -> DialogueLine:
	assert_object(resource).is_not_null()
	if resource == null:
		return null
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, title)
	var steps := 0
	while line != null and line.responses.is_empty() and steps < 20:
		if line.next_id.is_empty() or line.next_id.contains("end"):
			break
		line = await DialogueManager.get_next_dialogue_line(resource, line.next_id)
		steps += 1
	assert_object(line).is_not_null()
	if line != null:
		assert_array(line.responses).is_not_empty()
	return line


func _label_text(root: Node) -> String:
	var lines := PackedStringArray()
	_collect_label_text(root, lines)
	return "\n".join(lines)


func _collect_label_text(node: Node, lines: PackedStringArray) -> void:
	if node is Label:
		lines.append((node as Label).text)
	for child: Node in node.get_children():
		_collect_label_text(child, lines)


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_bool(parsed is Dictionary).is_true()
	return parsed as Dictionary
