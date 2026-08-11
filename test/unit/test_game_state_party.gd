extends GdUnitTestSuite

var original_party: Array[PartyMember]
var original_flags: Dictionary
var original_renown: Dictionary
var original_autosave_reason: String


func before_test() -> void:
	original_party = GameState.party.duplicate()
	original_flags = GameState.flags.duplicate(true)
	original_renown = Renown.to_dict().duplicate(true)
	original_autosave_reason = SaveGame._pending_autosave_reason
	GameState.party = [GameState._make_vex()]
	GameState.flags.clear()
	Renown.from_dict({})
	SaveGame._pending_autosave_reason = ""


func after_test() -> void:
	GameState.party = original_party
	GameState.flags = original_flags
	Renown.from_dict(original_renown)
	SaveGame._pending_autosave_reason = original_autosave_reason


func test_roster_is_the_curated_six_and_excludes_fixed_lead() -> void:
	var names: PackedStringArray = []
	for candidate in GameState.recruitable_candidates():
		names.append(candidate.display_name)

	assert_int(names.size()).is_equal(6)
	assert_bool(names.has("Vex the Unbowed")).is_false()
	assert_bool(names.has("Serai-Lun")).is_true()
	assert_bool(names.has("Old Grumbrand")).is_true()
	assert_bool(names.has("Wyneth Hallow-Tide")).is_true()
	assert_bool(names.has("Ressa Quickfingers")).is_true()


func test_exactly_two_open_companions_are_ordered_after_vex() -> void:
	var candidates := GameState.recruitable_candidates()
	assert_bool(GameState.set_companions([candidates[0]])).is_false()
	assert_bool(GameState.set_companions([candidates[0], candidates[0]])).is_false()
	assert_bool(GameState.set_companions([candidates[0], candidates[1]])).is_true()

	assert_int(GameState.party.size()).is_equal(3)
	assert_str(GameState.party[0].id).is_equal(GameState.PROTAGONIST_ID)
	assert_str(GameState.party[1].id).is_equal("serai-lun")
	assert_str(GameState.party[2].id).is_equal("old-grumbrand")


func test_gated_companions_cannot_bypass_renown_validation() -> void:
	var candidates := GameState.recruitable_candidates()
	var korrath := candidates[4]

	assert_bool(GameState.set_companions([candidates[0], korrath])).is_false()
	Renown.gain_reputation("player", 10.0, "test", "test")
	assert_bool(GameState.set_companions([candidates[0], korrath])).is_true()


func test_apply_created_character_replaces_the_lead_identity_in_place() -> void:
	var built := PartyMember.new()
	built.id = "whatever-chargen-typed"
	built.display_name = "Sera"
	built.race = "Vael"

	GameState.apply_created_character(built)

	assert_int(GameState.party.size()).is_equal(1)
	assert_str(GameState.party[0].id).is_equal(GameState.PROTAGONIST_ID)
	assert_str(GameState.party[0].display_name).is_equal("Sera")
	assert_bool(GameState.has_created_character()).is_true()
	# protagonist()/companions() must keep resolving by the stable id afterward.
	assert_object(GameState.protagonist()).is_equal(GameState.party[0])


func test_custom_recruit_chargen_is_off_by_default_and_unlockable() -> void:
	assert_bool(GameState.custom_recruit_chargen_unlocked()).is_false()
	GameState.unlock_custom_recruit_chargen()
	assert_bool(GameState.custom_recruit_chargen_unlocked()).is_true()


func test_add_custom_recruit_surfaces_in_recruitable_candidates() -> void:
	var original_custom_recruits := GameState.custom_recruits.duplicate()
	GameState.custom_recruits.clear()

	var built := PartyMember.new()
	built.id = "player-made-recruit"
	built.display_name = "Vann"
	GameState.add_custom_recruit(built)

	var names: PackedStringArray = []
	for candidate in GameState.recruitable_candidates():
		names.append(candidate.display_name)
	assert_bool(names.has("Vann")).is_true()

	GameState.custom_recruits = original_custom_recruits
