extends GdUnitTestSuite
## FR-505: the party screen is where a companion's personal quest is talked
## through (see ui/screens/party.gd) — there's no field NPC for companions.

var _original_party: Array[PartyMember]


func before_test() -> void:
	UIManager.close_all()
	get_tree().paused = false
	_original_party = GameState.party.duplicate()


func after_test() -> void:
	UIManager.close_all()
	get_tree().paused = false
	GameState.party = _original_party


func _serai_lun() -> PartyMember:
	for candidate in GameState.recruitable_candidates():
		if candidate.id == "serai-lun":
			return candidate
	fail("serai-lun is no longer a recruitable candidate")
	return null


func test_quest_button_hidden_for_a_companion_with_no_authored_quest() -> void:
	var vex := PartyMember.new()
	vex.id = GameState.PROTAGONIST_ID
	vex.display_name = "Vex"
	var no_quest := PartyMember.new()
	no_quest.id = "no-quest-companion"
	no_quest.display_name = "Undecided"
	GameState.party = [vex, no_quest]

	var runner := scene_runner("res://ui/screens/party.tscn")
	await runner.simulate_frames(2)
	var list := runner.find_child("MemberList", true, false) as ItemList
	list.select(1)
	list.item_selected.emit(1)
	await runner.simulate_frames(1)

	var button := runner.find_child("PersonalQuestButton", true, false) as Button
	assert_object(button).is_not_null()
	assert_bool(button.visible).is_false()


func test_quest_button_visible_and_labeled_for_serai_lun() -> void:
	var vex := PartyMember.new()
	vex.id = GameState.PROTAGONIST_ID
	vex.display_name = "Vex"
	GameState.party = [vex, _serai_lun()]

	var runner := scene_runner("res://ui/screens/party.tscn")
	await runner.simulate_frames(2)
	var list := runner.find_child("MemberList", true, false) as ItemList
	list.select(1)
	list.item_selected.emit(1)
	await runner.simulate_frames(1)

	var button := runner.find_child("PersonalQuestButton", true, false) as Button
	assert_object(button).is_not_null()
	assert_bool(button.visible).is_true()
	assert_str(button.text).contains("Serai-Lun")
