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


# ─── (d) Vär gates breadth, table-driven over the full threshold range ───────
#
# The breadth ladder is canon: Tone is always available; Chord requires
# Vär >= 0 OR (Solo AND Mastery); Triad requires Vär >= +2 OR (Solo AND highest
# Mastery AND Refrain-tier Breath). The thresholds come from the gate's own
# constants — never re-typed here — and the Vär sweep covers the clamped range
# around each threshold so an off-by-one in either direction fails.


const HARMONY_SWEEP: Array[int] = [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5]


func test_tone_is_allowed_at_every_var_value_regardless_of_context() -> void:
	for harmony: int in HARMONY_SWEEP:
		for context: Dictionary in [
			{},
			{"solo": true},
			{"solo": true, "mastery": true},
			{"mastery": true, "highest_mastery": true, "breath_tier": "refrain"},
		]:
			var result: Dictionary = CastingGate.query_breadth(&"tone", harmony, &"", context)
			assert_bool(result["allowed"]).override_failure_message(
				"Tone must always be available (harmony %d, context %s)" % [harmony, context]
			).is_true()
			assert_int(result["current_harmony"]).is_equal(clampi(harmony, -5, 5))


func test_chord_gate_tracks_the_var_threshold_across_the_sweep() -> void:
	for harmony: int in HARMONY_SWEEP:
		var result: Dictionary = CastingGate.query_breadth(&"chord", harmony)
		var expected_allowed: bool = harmony >= CastingGate.CHORD_MIN_HARMONY
		assert_bool(result["allowed"]).override_failure_message(
			"Chord at harmony %d (threshold %d)" % [harmony, CastingGate.CHORD_MIN_HARMONY]
		).is_equal(expected_allowed)
		if not expected_allowed:
			assert_str(String(result["blocked_by"])).is_equal("var_harmony")
			assert_int(result["nearest_unblock"]["delta"]).is_equal(
				CastingGate.CHORD_MIN_HARMONY - harmony
			)


func test_chord_solo_mastery_override_across_the_sweep() -> void:
	# Below the Vär threshold, Solo AND Mastery is the only override; each
	# missing half must block with its own reason.
	for harmony: int in HARMONY_SWEEP:
		if harmony >= CastingGate.CHORD_MIN_HARMONY:
			continue
		var full: Dictionary = CastingGate.query_breadth(
			&"chord", harmony, &"", {"solo": true, "mastery": true}
		)
		assert_bool(full["allowed"]).override_failure_message(
			"Solo+Mastery chord at harmony %d" % harmony
		).is_true()
		var solo_only: Dictionary = CastingGate.query_breadth(
			&"chord", harmony, &"", {"solo": true, "mastery": false}
		)
		assert_bool(solo_only["allowed"]).is_false()
		assert_str(String(solo_only["blocked_by"])).is_equal("solo_mastery")
		var mastery_only: Dictionary = CastingGate.query_breadth(
			&"chord", harmony, &"", {"solo": false, "mastery": true}
		)
		assert_bool(mastery_only["allowed"]).is_false()
		assert_str(String(mastery_only["blocked_by"])).is_equal("var_harmony")


func test_triad_gate_tracks_the_var_threshold_across_the_sweep() -> void:
	for harmony: int in HARMONY_SWEEP:
		var result: Dictionary = CastingGate.query_breadth(&"triad", harmony)
		var expected_allowed: bool = harmony >= CastingGate.TRIAD_MIN_HARMONY
		assert_bool(result["allowed"]).override_failure_message(
			"Triad at harmony %d (threshold %d)" % [harmony, CastingGate.TRIAD_MIN_HARMONY]
		).is_equal(expected_allowed)
		if not expected_allowed:
			assert_str(String(result["blocked_by"])).is_equal("var_harmony")
			assert_int(result["nearest_unblock"]["delta"]).is_equal(
				CastingGate.TRIAD_MIN_HARMONY - harmony
			)


func test_triad_solo_override_requires_all_three_prerequisites() -> void:
	# Below the Vär threshold the override is Solo AND highest Mastery AND
	# Refrain-tier Breath. Every subset that drops one leg must block, and the
	# block reason must name the missing leg.
	var below_threshold: Array[int] = []
	for harmony: int in HARMONY_SWEEP:
		if harmony < CastingGate.TRIAD_MIN_HARMONY:
			below_threshold.append(harmony)
	for harmony: int in below_threshold:
		var full: Dictionary = CastingGate.query_breadth(
			&"triad", harmony, &"",
			{"solo": true, "highest_mastery": true, "breath_tier": "refrain"}
		)
		assert_bool(full["allowed"]).override_failure_message(
			"Full override triad at harmony %d" % harmony
		).is_true()

		var no_solo: Dictionary = CastingGate.query_breadth(
			&"triad", harmony, &"",
			{"solo": false, "highest_mastery": true, "breath_tier": "refrain"}
		)
		assert_bool(no_solo["allowed"]).is_false()
		assert_str(String(no_solo["blocked_by"])).is_equal("var_harmony")

		var no_mastery: Dictionary = CastingGate.query_breadth(
			&"triad", harmony, &"",
			{"solo": true, "highest_mastery": false, "breath_tier": "refrain"}
		)
		assert_bool(no_mastery["allowed"]).is_false()
		assert_str(String(no_mastery["blocked_by"])).is_equal("solo_mastery")

		var no_refrain: Dictionary = CastingGate.query_breadth(
			&"triad", harmony, &"",
			{"solo": true, "highest_mastery": true, "breath_tier": "phrase"}
		)
		assert_bool(no_refrain["allowed"]).is_false()
		assert_str(String(no_refrain["blocked_by"])).is_equal("breath_tier")

		# Mastery without HIGHEST mastery is not enough for a Triad.
		var plain_mastery: Dictionary = CastingGate.query_breadth(
			&"triad", harmony, &"",
			{"solo": true, "mastery": true, "breath_tier": "refrain"}
		)
		assert_bool(plain_mastery["allowed"]).is_false()
		assert_str(String(plain_mastery["blocked_by"])).is_equal("solo_mastery")


func test_husked_blocks_every_breadth_at_every_var_value() -> void:
	# "Husked" gates on the caster_context flag alone: a husked caster has no
	# pattern left to spend, so no Vär value, breadth, or Solo/Mastery
	# combination unblocks them — including Tone, which is otherwise always
	# available.
	for harmony: int in HARMONY_SWEEP:
		for breadth: StringName in [&"tone", &"chord", &"triad"]:
			for extras: Dictionary in [
				{},
				{"solo": true, "mastery": true},
				{"solo": true, "highest_mastery": true, "breath_tier": "refrain"},
			]:
				var context: Dictionary = extras.duplicate()
				context["husked"] = true
				var result: Dictionary = CastingGate.query_breadth(
					breadth, harmony, &"refrain", context
				)
				assert_bool(result["allowed"]).override_failure_message(
					"Husked caster, breadth '%s' at harmony %d, context %s"
					% [breadth, harmony, extras]
				).is_false()
				assert_str(String(result["blocked_by"])).is_equal("husked")
				assert_str(String(result["nearest_unblock"]["type"])).is_equal("husked_recovery")


func test_husked_recovery_ceiling_is_reported_only_when_known() -> void:
	var with_ceiling: Dictionary = CastingGate.query_breadth(
		&"tone", 5, &"", {"husked": true, "husked_recovery_ceiling": 2.5}
	)
	assert_float(with_ceiling["nearest_unblock"]["ceiling"]).is_equal(2.5)
	var without_ceiling: Dictionary = CastingGate.query_breadth(
		&"tone", 5, &"", {"husked": true}
	)
	assert_bool(without_ceiling["nearest_unblock"].has("ceiling")).is_false()
