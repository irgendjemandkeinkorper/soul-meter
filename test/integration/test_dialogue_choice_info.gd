extends GdUnitTestSuite
## U1 (owner 2026-11-01, docs/design/ui-rework-plan-2026-11-01.md): which locked choices a
## conversation shows, why each lock holds, what each choice changes, and a check's odds.

const IRIS := "res://dialogue/iris_illepah.dialogue"
const COUNCIL := "res://dialogue/council_elder.dialogue"

const GATES := """~ start
Nemo: Pick one.
- "Open line."
	Nemo: Open.
- "Quest bookkeeping." [if GameState.get_flag("u1_never_set") /]
	Nemo: Quest.
- "Earnable standing." [if Reputation.standing("ssae-seeders") >= 15.0 /]
	Nemo: Standing.
- "Quest and standing." [if GameState.get_flag("u1_never_set") and Reputation.standing("ssae-seeders") >= 15.0 /]
	Nemo: Both.
- "Shown by tag." [#lock=show] [if GameState.get_flag("u1_never_set") /]
	Nemo: Shown.
- "Hidden by tag." [#lock=hide] [if Reputation.standing("ssae-seeders") >= 15.0 /]
	Nemo: Hidden.
- "Hollowed only." [if GameState.is_hollowing() /]
	Nemo: Hollowed.
- "Low Soul only." [if GameState.soul_meter < 10.0 /]
	Nemo: Low.
- "Soul floor." [if GameState.soul_meter >= 90.0 /]
	Nemo: Floor.
- "Skill." [if check("undertone", 99) /]
	Nemo: Skill.
- "Guarded comparison." [if GameState.get_flag("u1_quest_done") and GameState.get_flag("u1_resolution") == "returned" /]
	Nemo: Guarded.
"""

var _reputation_before: Dictionary = {}
var _renown_before: Dictionary = {}
var _game_state_before: Dictionary = {}


func before_test() -> void:
	_reputation_before = Reputation.to_dict()
	_renown_before = Renown.to_dict()
	_game_state_before = GameState.to_dict()
	Reputation.from_dict({})
	Renown.from_dict({})
	GameState.set_soul_meter(50.0)
	GameState.set_flag("u1_never_set", false)
	GameState.set_flag("u1_quest_done", false)


func after_test() -> void:
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)
	GameState.from_dict(_game_state_before)
	DialogueLedgerEcho.clear()


func test_only_earnable_locks_are_offered() -> void:
	var shown := await _visibility_by_text(DialogueManager.create_resource_from_text(GATES))

	assert_bool(shown["Open line."]["visible"]).is_true()
	assert_bool(shown["Open line."]["locked"]).is_false()
	# Earnable: standing, a Soul floor, a skill. Visible, locked.
	for text: String in ["Earnable standing.", "Soul floor.", "Skill."]:
		assert_bool(shown[text]["visible"]).override_failure_message(text).is_true()
		assert_bool(shown[text]["locked"]).override_failure_message(text).is_true()
	# Not earnable: quest/flag state, hollowed-only, low-Soul-only, and a quest gate on an
	# earnable one (failing the quest part hides it whatever the standing).
	for text: String in [
		"Quest bookkeeping.", "Quest and standing.", "Hollowed only.", "Low Soul only.",
		"Guarded comparison.",
	]:
		assert_bool(shown[text]["visible"]).override_failure_message(text).is_false()
	# Authored overrides win either way.
	assert_bool(shown["Shown by tag."]["visible"]).is_true()
	assert_bool(shown["Hidden by tag."]["visible"]).is_false()


func test_a_quest_gate_that_holds_leaves_the_earnable_lock_visible() -> void:
	GameState.set_flag("u1_never_set", true)
	var shown := await _visibility_by_text(DialogueManager.create_resource_from_text(GATES))

	assert_bool(shown["Quest and standing."]["visible"]).is_true()
	assert_bool(shown["Quest and standing."]["locked"]).is_true()
	assert_array(Array(shown["Quest and standing."]["reasons"])).contains_exactly([
		"Ssae Seeders standing 15 needed — you have 0.",
	])


## DM short-circuits `and`; Iris's "How are the sprigs?" lines rely on it (an unset flag
## is `false`, and `false == "returned"` is a runtime error). Running this suite without
## a "Godot Runtime Error" is the assertion; the line must also stay hidden.
func test_guard_parts_short_circuit_like_dialogue_manager() -> void:
	var shown := await _visibility_by_text(DialogueManager.create_resource_from_text(GATES))
	assert_bool(shown["Guarded comparison."]["visible"]).is_false()

	GameState.set_flag("u1_quest_done", true)
	GameState.set_flag("u1_resolution", "communion")
	shown = await _visibility_by_text(DialogueManager.create_resource_from_text(GATES))
	assert_bool(shown["Guarded comparison."]["visible"]).is_false()

	var iris := await _visibility_by_text(load(IRIS) as DialogueResource, "hub")
	assert_bool(iris.has("How are the sprigs?")).is_true()
	assert_bool(iris["How are the sprigs?"]["visible"]).is_false()


func test_each_lock_names_its_system_and_bar() -> void:
	var shown := await _visibility_by_text(DialogueManager.create_resource_from_text(GATES))

	assert_array(Array(shown["Earnable standing."]["reasons"])).contains_exactly([
		"Ssae Seeders standing 15 needed — you have 0.",
	])
	assert_array(Array(shown["Soul floor."]["reasons"])).contains_exactly([
		"Soul 90 needed — you have 50.",
	])
	assert_array(Array(shown["Skill."]["reasons"])).contains_exactly([
		"Undertone 99 needed — you have %d." % DialogueChoiceInfo.odds("undertone"),
	])


func test_effects_are_read_from_the_branch_mutations() -> void:
	var iris := load(IRIS) as DialogueResource
	var chips := await _chips_by_text(iris, "hub")

	assert_str(chips["The Bloom isn't finished, is it?"]).is_equal("SSAE SEEDERS +8")
	assert_str(chips["This grove is unregistered. That will be recorded."]).is_equal(
		"SSAE SEEDERS −6  ·  THE REGISTRY +4  ·  INFAMY +5"
	)
	# Soul leads; karma (no readout anywhere) is left off.
	assert_str(chips["Show me what the Loam remembers."]).is_equal(
		"SOUL −6  ·  SSAE SEEDERS +3"
	)
	assert_str(chips["I should go."]).is_empty()


func test_a_check_shows_the_chance_it_rolls() -> void:
	var council := load(COUNCIL) as DialogueResource
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(council, "start")
	var response := _response(line, "Ask what truth matters before taking the road.")
	assert_object(response).is_not_null()

	assert_str(DialogueChoiceInfo.check_skill(council, response)).is_equal("undertone")
	assert_int(DialogueChoiceInfo.odds("undertone")).is_equal(
		roundi(SkillCheck.preview("undertone"))
	)
	assert_str(DialogueChoiceInfo.skill_label("undertone")).is_equal("Undertone")


func test_runtime_ids_resolve_to_compiled_line_keys() -> void:
	var iris := load(IRIS) as DialogueResource
	var uid := ResourceUID.path_to_uid(iris.resource_path).replace("uid://", "")

	assert_str(DialogueChoiceInfo.line_key(iris, "13")).is_equal("13")
	assert_str(DialogueChoiceInfo.line_key(iris, "%s@13" % uid)).is_equal("13")
	assert_str(DialogueChoiceInfo.line_key(iris, "%s@13|%s@40" % [uid, uid])).is_equal("13")
	assert_str(DialogueChoiceInfo.line_key(iris, "someotheruid@13")).is_empty()


## Pins the vendor evaluator the helper borrows (`DialogueManager._resolve`): a whole
## condition must mean to the helper exactly what it meant to DM's `is_allowed`.
func test_part_evaluation_agrees_with_dialogue_manager() -> void:
	var resource := DialogueManager.create_resource_from_text(GATES)
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, "start")
	var compared := 0
	for response: DialogueResponse in line.responses:
		var tokens := DialogueChoiceInfo.condition_tokens(resource, response)
		var parts := DialogueChoiceInfo.conjuncts(tokens)
		if parts.size() != 1:
			continue
		var holds: bool = await DialogueChoiceInfo._holds(parts[0], [])
		assert_bool(holds).override_failure_message(response.text).is_equal(response.is_allowed)
		compared += 1
	assert_int(compared).is_greater_equal(8)


func test_conjuncts_split_on_and_but_keep_or_whole() -> void:
	var resource := DialogueManager.create_resource_from_text("""~ start
Nemo: Pick.
- "And." [if GameState.get_flag("a") and GameState.get_flag("b") and GameState.get_flag("c") /]
	Nemo: A.
- "Or." [if GameState.get_flag("a") or GameState.get_flag("b") /]
	Nemo: B.
""")
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, "start")
	var by_and := DialogueChoiceInfo.conjuncts(
		DialogueChoiceInfo.condition_tokens(resource, _response(line, "And."))
	)
	var by_or := DialogueChoiceInfo.conjuncts(
		DialogueChoiceInfo.condition_tokens(resource, _response(line, "Or."))
	)
	assert_int(by_and.size()).is_equal(3)
	assert_int(by_or.size()).is_equal(1)


func test_signed_numbers_use_a_true_minus() -> void:
	assert_str(DialogueChoiceInfo.signed(-6.0)).is_equal("−6")
	assert_str(DialogueChoiceInfo.signed(4.0)).is_equal("+4")
	assert_str(DialogueChoiceInfo.signed(2.5)).is_equal("+2.5")


# --- helpers ------------------------------------------------------------------------------------

func _visibility_by_text(resource: DialogueResource, cue: String = "start") -> Dictionary:
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, cue)
	var shown := {}
	for response: DialogueResponse in line.responses:
		var key := response.text.trim_prefix("\"").trim_suffix("\"")
		if shown.has(key):
			# Iris authors "How are the sprigs?" three times; any visible copy counts.
			var again: Dictionary = await DialogueChoiceInfo.visibility(resource, response)
			if bool(again["visible"]):
				shown[key] = again
			continue
		shown[key] = await DialogueChoiceInfo.visibility(resource, response)
	return shown


func _chips_by_text(resource: DialogueResource, cue: String) -> Dictionary:
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, cue)
	var chips := {}
	for response: DialogueResponse in line.responses:
		var key := response.text.trim_prefix("\"").trim_suffix("\"")
		chips[key] = DialogueChoiceInfo.chips_text(DialogueChoiceInfo.effects(resource, response))
	return chips


func _response(line: DialogueLine, text: String) -> DialogueResponse:
	for response: DialogueResponse in line.responses:
		if response.text.trim_prefix("\"").trim_suffix("\"") == text:
			return response
	return null
