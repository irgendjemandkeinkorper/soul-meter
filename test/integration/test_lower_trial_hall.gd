extends GdUnitTestSuite

const SCENE_PATH := "res://world/interiors/lower_trial_hall.tscn"
const DIALOGUE_PATH := "res://dialogue/lower_trial_hall.dialogue"

var _original_party: Array[PartyMember]


func before_test() -> void:
	_original_party = GameState.party.duplicate(true)
	GameState.flags.clear()
	GameState.party.clear()
	GameState._seed_demo_data()
	SkillCheck._check_log.clear()


func after_test() -> void:
	if not Battle.ended:
		Battle._finish(BattleResult.State.FLED, &"fled")
	GameState.flags.clear()
	GameState.party = _original_party


func test_scene_loads_with_every_gauntlet_beat() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)

	assert_object(hall.get_node("EntranceAide")).is_not_null()
	assert_object(hall.get_node("InteractionSwitch")).is_not_null()
	assert_object(hall.get_node("WardenTrigger")).is_not_null()
	assert_object(hall.get_node("TrialDoorKey")).is_not_null()
	assert_object(hall.get_node("SkillDoorExaminer")).is_not_null()
	assert_object(hall.get_node("TrialKeeper")).is_not_null()
	assert_object(hall.get_node("ExitToDom")).is_not_null()
	var skill_door_shape := hall.get_node("SkillDoor/CollisionShape2D") as CollisionShape2D
	assert_float((skill_door_shape.shape as RectangleShape2D).size.x).is_equal(880.0)
	assert_str(hall.get_node("ExitToDom").required_flag).is_equal(
		"opening_gauntlet_complete"
	)


func test_entrance_speech_skip_success_unlocks_exit() -> void:
	_configure_skill("insight", 95.0)
	SkillCheck.random_number_generator.seed = _successful_seed()
	var resource := load(DIALOGUE_PATH) as DialogueResource
	var response: DialogueResponse = await _response_containing(
		resource, "trial_aide", "Read the trial's intent"
	)

	await DialogueManager.get_next_dialogue_line(resource, response.next_id)

	assert_bool(GameState.flag_is_true("opening_gauntlet_complete")).is_true()
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	assert_bool(hall.get_node("ExitToDom")._is_unlocked()).is_true()


func test_warden_trigger_starts_once_and_victory_opens_the_next_beat() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	var starts: Array[StringName] = []
	hall.trial_encounter_started.connect(func(id: StringName) -> void: starts.append(id))

	hall.request_warden_encounter()
	hall.request_warden_encounter()

	assert_array(starts).is_equal([&"trial-warden"])
	assert_str(Battle.encounter_id).is_equal("trial-warden")
	Battle._finish(BattleResult.State.VICTORY, &"slain")
	assert_bool(GameState.flag_is_true("trial_warden_cleared")).is_true()


func test_fled_warden_encounter_can_be_retried() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	var starts: Array[StringName] = []
	hall.trial_encounter_started.connect(func(id: StringName) -> void: starts.append(id))

	hall.request_warden_encounter()
	Battle._finish(BattleResult.State.FLED, &"fled")

	assert_bool(GameState.flag_is_true("trial_warden_started")).is_false()
	assert_bool(GameState.flag_is_true("trial_warden_cleared")).is_false()
	hall.request_warden_encounter()
	assert_array(starts).is_equal([&"trial-warden", &"trial-warden"])
	assert_str(Battle.encounter_id).is_equal("trial-warden")


func test_keeper_talk_success_completes_gauntlet() -> void:
	_configure_skill("persuasion", 95.0)
	SkillCheck.random_number_generator.seed = _successful_seed()
	var resource := load(DIALOGUE_PATH) as DialogueResource
	var response: DialogueResponse = await _response_containing(
		resource, "trial_keeper", "No blood is needed"
	)

	await DialogueManager.get_next_dialogue_line(resource, response.next_id)

	assert_bool(GameState.flag_is_true("opening_gauntlet_complete")).is_true()


func test_keeper_fight_starts_authored_battle_and_victory_completes_gauntlet() -> void:
	var hall: Node = auto_free((load(SCENE_PATH) as PackedScene).instantiate())
	add_child(hall)
	var resource := load(DIALOGUE_PATH) as DialogueResource
	var response: DialogueResponse = await _response_containing(
		resource, "trial_keeper", "Fight me"
	)

	await DialogueManager.get_next_dialogue_line(resource, response.next_id)
	await get_tree().process_frame

	assert_str(Battle.encounter_id).is_equal("trial-keeper")
	Battle._finish(BattleResult.State.VICTORY, &"slain")
	assert_bool(GameState.flag_is_true("opening_gauntlet_complete")).is_true()


func _response_containing(
	resource: DialogueResource, title: String, response_text: String
) -> DialogueResponse:
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, title)
	assert_object(line).is_not_null()
	if line == null:
		return null
	for response: DialogueResponse in line.responses:
		if response.text.contains(response_text):
			assert_bool(response.is_allowed).is_true()
			return response
	fail("No response containing '%s' at dialogue title '%s'." % [response_text, title])
	return null


func _configure_skill(skill: String, advancement: float) -> void:
	var member: PartyMember = GameState.protagonist()
	assert_object(member).is_not_null()
	for attribute: String in member.attributes:
		member.attributes[attribute] = 0
	member.skill_tiers[skill] = "untrained"
	member.skill_percentages[skill] = advancement


func _successful_seed() -> int:
	var probe := RandomNumberGenerator.new()
	for candidate: int in range(1, 1000):
		probe.seed = candidate
		if probe.randi_range(1, 100) <= 95:
			return candidate
	return 1
