extends GdUnitTestSuite


func test_save_round_trip_preserves_gameplay_fields() -> void:
	var original := PartyMember.new()
	original.id = "vex"
	original.display_name = "Vex the Unbowed"
	original.race = "Ash-Bound Kes'reth"
	original.char_class = "Ironbrand (Kero)"
	original.level = 4
	original.hp = 31
	original.max_hp = 44
	original.attack = 9
	original.defense = 5
	original.bio = "A held line."
	original.min_reputation = 10.0

	var restored := PartyMember.from_dict(original.to_dict())

	assert_str(restored.id).is_equal("vex")
	assert_str(restored.display_name).is_equal(original.display_name)
	assert_str(restored.char_class).is_equal(original.char_class)
	assert_int(restored.hp).is_equal(31)
	assert_int(restored.max_hp).is_equal(44)
	assert_int(restored.attack).is_equal(9)
	assert_int(restored.defense).is_equal(5)
	assert_float(restored.min_reputation).is_equal(10.0)
