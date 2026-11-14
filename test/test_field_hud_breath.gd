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

	await runner.simulate_frames(1)
	# U2: the party is a strip of cards; Breath is a meter, its numbers on hover.
	var card := runner.find_child("PartyStrip", true, false).get_child(0)
	var breath := card.find_child("Breath", true, false) as MeterBar
	assert_float(breath.value).is_equal_approx(6.0 / 15.0, 0.001)
	var numbers := card.find_child("Numbers", true, false) as Label
	assert_str(numbers.text).contains("BR 6/15")
