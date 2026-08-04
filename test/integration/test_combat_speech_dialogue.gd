extends GdUnitTestSuite

const PresenterScript := preload("res://ui/dialogue/combat_speech_presenter.gd")
const DIALOGUE_PATH := "res://test/integration/harem_stet_combat.dialogue"

var original_party: Array[PartyMember] = []


func before_test() -> void:
	original_party = GameState.party.duplicate()
	GameState.party.clear()
	var member := PartyMember.new()
	member.attributes = {"voice": 10, "pitch": 10}
	GameState.party.append(member)


func after_test() -> void:
	GameState.party.clear()
	for member in original_party:
		GameState.party.append(member)
	get_tree().paused = false


func test_harem_stet_combat_dialogue_exercises_all_three_checked_outcomes() -> void:
	var resource := load(DIALOGUE_PATH) as DialogueResource
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, "start", [Battle])

	assert_object(resource).is_not_null()
	assert_object(line).is_not_null()
	assert_int(line.responses.size()).is_equal(3)
	for response in line.responses:
		assert_bool(response.is_allowed).is_true()
	var source := FileAccess.get_file_as_string(DIALOGUE_PATH)
	assert_int(source.count("[if ")).is_equal(3)
	assert_int(source.count(" /]")).is_equal(3)
	assert_str(source).not_contains("[if check(\"insight\", 0)]")
	assert_str(source).not_contains("[if check(\"persuasion\", 0)]")


func test_presenter_uses_dialogue_managers_registered_echo_gate_balloon() -> void:
	assert_str(ProjectSettings.get_setting("dialogue_manager/runtime/balloon_path")).is_equal(
		"res://ui/dialogue/dialogue_balloon.tscn"
	)
	var presenter = auto_free(PresenterScript.new())
	var balloon: Node = presenter.present(DIALOGUE_PATH, "start", [Battle])
	assert_object(balloon).is_not_null()

	await get_tree().process_frame
	assert_str(balloon.scene_file_path).is_equal("res://ui/dialogue/dialogue_balloon.tscn")
	assert_bool(get_tree().paused).is_true()
	balloon.free()
	assert_bool(get_tree().paused).is_false()
