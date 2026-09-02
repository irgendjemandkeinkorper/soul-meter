extends GdUnitTestSuite

var original_party: Array[PartyMember] = []


func before_test() -> void:
	original_party = GameState.party.duplicate()
	var member := PartyMember.new()
	member.display_name = "Vex"
	member.hp = 10
	member.max_hp = 12
	member.breath = 6
	member.breath_max = 15
	GameState.party = [member]


func after_test() -> void:
	GameState.party = original_party


func test_field_hud_shows_party_breath() -> void:
	var runner := scene_runner("res://ui/hud/field_hud.tscn")

	var party_status := runner.find_child("PartyStatus", true, false) as Label
	assert_str(party_status.text).contains("BREATH 6/15")
