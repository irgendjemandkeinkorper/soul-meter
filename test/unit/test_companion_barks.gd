extends GdUnitTestSuite
## #286: the hollowing has a witness.
##
## `cosmology/souls.md` makes being witnessed and remembered the only mechanism
## by which a husked soul recovers, so these cases are about WHO speaks and
## whether anyone does — not about the prose.

var _party_before: Array[PartyMember] = []


func before_test() -> void:
	_party_before = GameState.party.duplicate()


func after_test() -> void:
	GameState.party = _party_before.duplicate()


func test_every_authored_companion_has_both_transitions() -> void:
	# A companion with a hollowing line and no return line would go silent at
	# exactly the moment canon says the witnessing matters most.
	assert_int(CompanionBarks.bark_count()).is_greater(0)
	for companion_id: String in CompanionBarks.BARKS:
		for occasion: StringName in CompanionBarks.OCCASIONS:
			assert_str(CompanionBarks.line(companion_id, occasion)).override_failure_message(
				"'%s' has no %s line" % [companion_id, occasion]
			).is_not_empty()


func test_every_authored_companion_is_a_real_recruit() -> void:
	var recruit_ids: Array[String] = []
	for member: PartyMember in GameState.recruitable_candidates():
		recruit_ids.append(member.id)
	for companion_id: String in CompanionBarks.BARKS:
		assert_array(recruit_ids).override_failure_message(
			"'%s' has barks but is not a recruitable companion" % companion_id
		).contains([companion_id])


func test_the_first_companion_with_a_line_speaks() -> void:
	var speaker: Dictionary = CompanionBarks.speaker(
		_companions(["korrath-ninefold", "wyneth-hallow-tide"]), CompanionBarks.HOLLOWED
	)
	# Party order is the player's own tavern ordering, so the speaker must be
	# deterministic rather than "whoever the dictionary happened to list first".
	assert_str(str(speaker["companion_id"])).is_equal("korrath-ninefold")
	assert_str(str(speaker["line"])).is_equal(
		CompanionBarks.line("korrath-ninefold", CompanionBarks.HOLLOWED)
	)


func test_an_unwitnessed_hollowing_is_silent() -> void:
	# Canon: recovery is done TO the husked BY other people. Travelling alone
	# into the state must not produce a line from nowhere.
	assert_bool(
		CompanionBarks.speaker([] as Array[PartyMember], CompanionBarks.HOLLOWED).is_empty()
	).is_true()
	assert_bool(
		CompanionBarks.speaker(
			_companions(["no-such-companion"]), CompanionBarks.HOLLOWED
		).is_empty()
	).is_true()


func test_a_companion_without_a_line_is_skipped_rather_than_silencing_the_party() -> void:
	var speaker: Dictionary = CompanionBarks.speaker(
		_companions(["no-such-companion", "maura-greyfen"]), CompanionBarks.RETURNED
	)
	assert_str(str(speaker["companion_id"])).is_equal("maura-greyfen")


func test_occasion_maps_the_signal_payload() -> void:
	assert_str(String(CompanionBarks.occasion_for(true))).is_equal(
		String(CompanionBarks.HOLLOWED)
	)
	assert_str(String(CompanionBarks.occasion_for(false))).is_equal(
		String(CompanionBarks.RETURNED)
	)


func test_an_unknown_occasion_has_no_line() -> void:
	assert_str(CompanionBarks.line("wyneth-hallow-tide", &"elated")).is_empty()
	assert_bool(CompanionBarks.has_line("wyneth-hallow-tide", &"elated")).is_false()


func _companions(ids: Array) -> Array[PartyMember]:
	var members: Array[PartyMember] = []
	for id: String in ids:
		var member := PartyMember.new()
		member.id = id
		member.display_name = id.capitalize()
		members.append(member)
	return members
