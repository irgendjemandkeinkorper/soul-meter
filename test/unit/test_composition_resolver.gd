extends GdUnitTestSuite

func test_resolve_rejects_invalid_magnitude_count_unknown_and_duplicates() -> void:
	var invalid_magnitude := CompositionResolver.resolve([&"suul"], &"verse")
	assert_str(String(invalid_magnitude.failure_id)).is_equal("invalid_magnitude")
	assert_str(String(CompositionResolver.resolve([], &"note").failure_id)).is_equal("invalid_element_count")
	assert_str(String(CompositionResolver.resolve([&"unknown"], &"note").failure_id)).is_equal("unknown_element")
	assert_str(String(CompositionResolver.resolve([&"suul", &"suul"], &"note").failure_id)).is_equal("duplicate_element")

func test_resolve_tone_and_chords_capture_effect_shape() -> void:
	var tone := CompositionResolver.resolve([&"suul"], &"note")
	assert_bool(tone.is_resolved()).is_true()
	assert_str(String(tone.status_id)).is_equal("tone")
	assert_bool(tone.fizzle_requested).is_true()
	var chord := CompositionResolver.resolve([&"suul", &"bloei"], &"phrase")
	assert_str(String(chord.status_id)).is_equal("chord")
	assert_int(chord.distance_steps).is_equal(1)
	var strained := CompositionResolver.resolve([&"suul", &"aqua"], &"song")
	assert_str(String(strained.status_id)).is_equal("strained_chord")
	assert_bool(strained.rejected).is_false()

func test_resolve_opposed_and_clashing_triads_are_rejected() -> void:
	var opposed := CompositionResolver.resolve([&"suul", &"daar"], &"note")
	assert_str(String(opposed.failure_id)).is_equal("opposed_elements")
	assert_bool(opposed.is_opposed()).is_true()
	var clash := CompositionResolver.resolve([&"suul", &"aqua", &"terra"], &"song")
	assert_bool(clash.is_clash()).is_true()
	assert_str(String(clash.failure_id)).is_equal("span_exceeds_two")

func test_casting_context_blocks_resolved_composition_with_gate_metadata() -> void:
	var result := CompositionResolver.resolve([&"suul", &"bloei"], &"phrase", {"harmony": -2})
	assert_bool(result.allowed).is_false()
	assert_str(String(result.failure_id)).is_equal("casting_gate")
	assert_str(String(result.blocked_by)).is_equal("var_harmony")
