extends GdUnitTestSuite

const ROSTER_PATH := "res://data/generated/dom_npc_roster.json"
const DIALOGUE_PATH := "res://dialogue/dom_side_quests.dialogue"
const REGISTRY_PATH := "res://globals/quest_registry.gd"
const SIDE_QUEST_SCRIPT_PATH := "res://quests/dom_side_quest.gd"

var original_flags: Dictionary
var original_reputation: Dictionary
var original_quests: Dictionary


func before_test() -> void:
	original_flags = GameState.flags.duplicate(true)
	original_reputation = Reputation.to_dict().duplicate(true)
	original_quests = QuestRegistry.to_dict().duplicate(true)
	_reset_side_quest_state()


func after_test() -> void:
	GameState.flags = original_flags
	Reputation.from_dict(original_reputation)
	QuestRegistry.reset()
	QuestRegistry.from_dict(original_quests)


func test_ten_side_quests_are_registered_to_authored_npc_stable_ids() -> void:
	var roster: Dictionary = _json(ROSTER_PATH)["npcs"]
	var quest_ids := {}
	var resource_ids := {}
	assert_int(QuestRegistry.DOM_SIDE_QUESTS.size()).is_equal(10)
	var all_resource_ids := {}
	for registered_quest: Quest in QuestRegistry.ALL_QUESTS:
		assert_bool(all_resource_ids.has(registered_quest.id)).is_false()
		all_resource_ids[registered_quest.id] = true
	for quest: DomSideQuest in QuestRegistry.DOM_SIDE_QUESTS:
		assert_bool(QuestRegistry.ALL_QUESTS.has(quest)).is_true()
		assert_bool(
			StableIds.is_valid_record(StableIds.QUEST, quest.quest_id_record())
		).is_true()
		assert_bool(quest_ids.has(quest.stable_id)).is_false()
		assert_bool(resource_ids.has(quest.id)).is_false()
		quest_ids[quest.stable_id] = true
		resource_ids[quest.id] = true

		assert_bool(roster.has(quest.giver_actor_id)).is_true()
		assert_bool(quest.participant_actor_ids.has(quest.giver_actor_id)).is_true()
		assert_object(QuestRegistry.side_quest_for_giver(quest.giver_actor_id)).is_same(quest)
		var giver: Dictionary = roster[quest.giver_actor_id]
		assert_bool(giver["stable_id"] == quest.giver_id_record()).is_true()
		for hook_record: Dictionary in quest.hook_id_records():
			assert_bool(StableIds.is_valid_record(StableIds.QUEST, hook_record)).is_true()
		var giver_hook_found := false
		for hook: Dictionary in giver["quest_hooks"]:
			if (
				str(hook["involvement"]) == "giver"
				and quest.hook_ids.has(str(hook["quest_id"]))
			):
				giver_hook_found = true
		assert_bool(giver_hook_found).is_true()

		var participant_records := quest.participant_id_records()
		for index in quest.participant_actor_ids.size():
			var actor_id: String = quest.participant_actor_ids[index]
			assert_bool(roster.has(actor_id)).is_true()
			var participant: Dictionary = roster[actor_id]
			assert_bool(participant["stable_id"] == participant_records[index]).is_true()
			var attached_hook_found := false
			for hook: Dictionary in participant["quest_hooks"]:
				if quest.hook_ids.has(str(hook["quest_id"])):
					attached_hook_found = true
			assert_bool(attached_hook_found).is_true()


func test_every_side_quest_has_two_genuinely_distinct_choice_outcomes() -> void:
	var roster: Dictionary = _json(ROSTER_PATH)["npcs"]
	var roster_factions := {}
	for row: Dictionary in roster.values():
		roster_factions[str(row["faction_id"])] = true
	for quest: DomSideQuest in QuestRegistry.DOM_SIDE_QUESTS:
		assert_str(quest.decision_prompt).starts_with("Decide")
		assert_bool(quest.has_complete_outcome_schema()).is_true()
		assert_int(quest.outcome_count()).is_greater_equal(2)
		var outcome_ids := {}
		var ledger_signatures := {}
		var readbacks := {}
		for index in quest.outcome_count():
			var outcome_id := quest.outcome_ids[index]
			var faction_id := quest.outcome_faction_ids[index]
			var delta := quest.outcome_reputation_deltas[index]
			var signature := "%s:%s" % [faction_id, delta]
			assert_bool(outcome_ids.has(outcome_id)).is_false()
			assert_bool(ledger_signatures.has(signature)).is_false()
			assert_bool(readbacks.has(quest.outcome_readbacks[index])).is_false()
			assert_bool(roster_factions.has(faction_id)).is_true()
			assert_bool(not is_zero_approx(delta)).is_true()
			assert_str(quest.outcome_labels[index]).is_not_empty()
			assert_str(quest.outcome_causes[index]).is_not_empty()
			assert_str(quest.outcome_readbacks[index]).is_not_empty()
			outcome_ids[outcome_id] = true
			ledger_signatures[signature] = true
			readbacks[quest.outcome_readbacks[index]] = true


func test_every_outcome_resolves_once_with_a_durable_flag_and_ledger_event() -> void:
	for quest: DomSideQuest in QuestRegistry.DOM_SIDE_QUESTS:
		for outcome_id: String in quest.outcome_ids:
			_reset_side_quest_state()
			assert_bool(QuestRegistry.offer_side_quest(quest)).is_true()
			for required_flag: String in quest.required_flags:
				GameState.set_flag(required_flag, true)
			var outcome: Dictionary = quest.outcome_for(outcome_id)
			assert_bool(QuestRegistry.resolve_side_quest(quest, outcome_id)).is_true()
			assert_bool(QuestRegistry.is_done(quest)).is_true()
			assert_str(GameState.get_flag(quest.resolution_flag)).is_equal(outcome_id)
			var events: Array[ReputationEvent] = Reputation.events_for(outcome["faction_id"])
			assert_int(events.size()).is_equal(1)
			assert_str(events[0].actor).is_equal("player")
			assert_str(events[0].scene).is_equal("dom")
			assert_str(events[0].cause).is_equal(outcome["cause"])
			assert_float(events[0].delta).is_equal_approx(outcome["reputation_delta"], 0.001)
			assert_str(QuestRegistry.side_quest_readback(quest)).is_equal(outcome["readback"])
			var event_count: int = Reputation.to_dict()["log"].size()
			assert_bool(QuestRegistry.resolve_side_quest(quest, outcome_id)).is_false()
			assert_int(Reputation.to_dict()["log"].size()).is_equal(event_count)


func test_every_outcome_has_a_later_dialogue_readback() -> void:
	var resource: DialogueResource = load(DIALOGUE_PATH)
	assert_object(resource).is_not_null()
	var source := FileAccess.get_file_as_string(DIALOGUE_PATH)
	for quest: DomSideQuest in QuestRegistry.DOM_SIDE_QUESTS:
		var giver: Dictionary = _json(ROSTER_PATH)["npcs"][quest.giver_actor_id]
		var first_line: DialogueLine = await DialogueManager.get_next_dialogue_line(
			resource, quest.dialogue_title
		)
		assert_object(first_line).is_not_null()
		assert_str(first_line.character).is_equal(giver["display_name"])
		for outcome_id: String in quest.outcome_ids:
			var outcome: Dictionary = quest.outcome_for(outcome_id)
			var readback_guard := 'GameState.get_flag("%s") == "%s" /]' % [
				quest.resolution_flag, outcome_id
			]
			assert_str(source).contains(readback_guard)
			assert_str(source).contains(str(outcome["readback"]))
	for condition: String in _conditions(source):
		assert_str(condition).ends_with(" /]")


func test_reputation_record_is_the_only_side_quest_faction_write_path() -> void:
	var reputation_calls := 0
	var expression := RegEx.new()
	expression.compile("Reputation\\.([A-Za-z_][A-Za-z0-9_]*)\\s*\\(")
	for path: String in [REGISTRY_PATH, SIDE_QUEST_SCRIPT_PATH, DIALOGUE_PATH]:
		var source := FileAccess.get_file_as_string(path)
		for result: RegExMatch in expression.search_all(source):
			reputation_calls += 1
			assert_str(result.get_string(1)).is_equal("record")
	assert_int(reputation_calls).is_greater_equal(1)


func _reset_side_quest_state() -> void:
	GameState.flags.clear()
	Reputation.from_dict({})
	QuestRegistry.reset()


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_bool(parsed is Dictionary).is_true()
	return parsed


func _conditions(source: String) -> Array[String]:
	var conditions: Array[String] = []
	var regex := RegEx.new()
	regex.compile("\\[if [^\\]]+\\]")
	for result: RegExMatch in regex.search_all(source):
		conditions.append(result.get_string())
	return conditions
