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


func test_from_dict_rejects_unsafe_portrait_paths() -> void:
	# Test with path outside res://
	var dict_external := {
		"portrait_path": "user://malicious.gd"
	}
	var restored_ext := PartyMember.from_dict(dict_external)
	assert_object(restored_ext.portrait).is_null()

	# Test with directory traversal
	var dict_traversal := {
		"portrait_path": "res://ui/screens/../../malicious.gd"
	}
	var restored_trav := PartyMember.from_dict(dict_traversal)
	assert_object(restored_trav.portrait).is_null()

	# Test with non-existent resource
	var dict_not_exists := {
		"portrait_path": "res://assets/does-not-exist.png"
	}
	var restored_missing := PartyMember.from_dict(dict_not_exists)
	assert_object(restored_missing.portrait).is_null()

	# Test with non-texture resource (e.g. script or scene)
	var dict_invalid_type := {
		"portrait_path": "res://globals/party_member.gd"
	}
	var restored_invalid := PartyMember.from_dict(dict_invalid_type)
	assert_object(restored_invalid.portrait).is_null()

	for extension in ["import", "ctex"]:
		var dict_generated_resource := {
			"portrait_path": "res://icon." + extension
		}
		var restored_generated := PartyMember.from_dict(dict_generated_resource)
		assert_object(restored_generated.portrait).is_null()


func test_from_dict_accepts_safe_portrait_paths() -> void:
	# Test with a valid texture resource (res://icon.svg is a CompressedTexture2D or Texture2D)
	var dict_valid := {
		"portrait_path": "res://icon.svg"
	}
	var restored_valid := PartyMember.from_dict(dict_valid)
	assert_object(restored_valid.portrait).is_not_null()
