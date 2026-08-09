extends GdUnitTestSuite

func test_tone_is_allowed_and_harmony_is_clamped() -> void:
	var result := CastingGate.query_breadth(&"tone", 99)
	assert_bool(result["allowed"]).is_true()
	assert_int(result["current_harmony"]).is_equal(5)

func test_chord_requires_harmony_or_solo_mastery() -> void:
	assert_str(String(CastingGate.query_breadth(&"chord", -1)["blocked_by"])).is_equal("var_harmony")
	assert_bool(CastingGate.query_breadth(&"chord", -1, &"", {"solo": true, "mastery": true})["allowed"]).is_true()
	assert_str(String(CastingGate.query_breadth(&"chord", -1, &"", {"solo": true})["blocked_by"])).is_equal("solo_mastery")

func test_triad_checks_highest_mastery_and_refrain() -> void:
	var blocked := CastingGate.query_breadth(&"triad", 0, &"", {"solo": true, "highest_mastery": true})
	assert_str(String(blocked["blocked_by"])).is_equal("breath_tier")
	var allowed := CastingGate.query_breadth(&"triad", 0, &"", {"solo": true, "highest_mastery": true, "breath_tier": "refrain"})
	assert_bool(allowed["allowed"]).is_true()

func test_husked_caster_blocks_every_breadth_and_reports_recovery() -> void:
	var result := CastingGate.query_breadth(&"tone", 0, &"", {"husked": true, "husked_recovery_ceiling": 2.5})
	assert_bool(result["allowed"]).is_false()
	assert_str(String(result["blocked_by"])).is_equal("husked")
	assert_float(result["nearest_unblock"]["ceiling"]).is_equal(2.5)
