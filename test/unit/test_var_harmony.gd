extends GdUnitTestSuite

const Resolver := preload("res://globals/elements/composition_resolver.gd")
const Result := preload("res://globals/elements/composition_result.gd")

var original_var_harmony: Dictionary


func before_test() -> void:
	original_var_harmony = GameState.var_harmony.duplicate(true)
	GameState.var_harmony.clear()


func after_test() -> void:
	GameState.var_harmony = original_var_harmony


func test_tone_is_allowed_across_the_entire_var_range() -> void:
	for harmony in range(-5, 6):
		var result: CompositionResult = _resolve_tone(harmony)

		assert_bool(result.allowed).is_true()
		assert_str(result.blocked_by).is_empty()


func test_tone_boundaries_are_allowed() -> void:
	for harmony in [-5, 0, 5]:
		assert_bool(_resolve_tone(harmony).is_castable()).is_true()


func test_chord_requires_neutral_or_better_var() -> void:
	var below: CompositionResult = _resolve_chord(-1)
	var neutral: CompositionResult = _resolve_chord(0)
	var above: CompositionResult = _resolve_chord(1)

	assert_bool(below.allowed).is_false()
	assert_str(below.blocked_by).is_equal("var_harmony")
	assert_int(below.nearest_unblock["minimum"]).is_equal(0)
	assert_int(below.nearest_unblock["delta"]).is_equal(1)
	assert_bool(neutral.allowed).is_true()
	assert_bool(above.allowed).is_true()


func test_solo_chord_is_blocked_without_mastery_and_allowed_with_it() -> void:
	var without_mastery := _resolve_chord(-5, {"solo": true})
	var with_mastery := _resolve_chord(-5, {"solo": true, "mastery": true})

	assert_bool(without_mastery.allowed).is_false()
	assert_str(without_mastery.blocked_by).is_equal("solo_mastery")
	assert_str(without_mastery.nearest_unblock["type"]).is_equal("mastery")
	assert_bool(with_mastery.allowed).is_true()


func test_triad_requires_two_or_better_var() -> void:
	var below: CompositionResult = _resolve_triad(1)
	var at_threshold: CompositionResult = _resolve_triad(2)
	var above: CompositionResult = _resolve_triad(3)

	assert_bool(below.allowed).is_false()
	assert_str(below.blocked_by).is_equal("var_harmony")
	assert_int(below.nearest_unblock["minimum"]).is_equal(2)
	assert_int(below.nearest_unblock["delta"]).is_equal(1)
	assert_bool(at_threshold.allowed).is_true()
	assert_bool(above.allowed).is_true()


func test_solo_triad_requires_highest_mastery_and_refrain_breath() -> void:
	var without_highest := _resolve_triad(
		-5, {"solo": true, "highest_mastery": false, "breath_tier": "refrain"}
	)
	var with_highest_and_refrain := _resolve_triad(
		-5, {"solo": true, "highest_mastery": true, "breath_tier": "refrain"}
	)
	var with_highest_but_not_refrain := _resolve_triad(
		-5, {"solo": true, "highest_mastery": true, "breath_tier": "song"}
	)

	assert_bool(without_highest.allowed).is_false()
	assert_str(without_highest.blocked_by).is_equal("solo_mastery")
	assert_bool(with_highest_and_refrain.allowed).is_true()
	assert_bool(with_highest_but_not_refrain.allowed).is_false()
	assert_str(with_highest_but_not_refrain.blocked_by).is_equal("breath_tier")
	assert_str(with_highest_but_not_refrain.nearest_unblock["type"]).is_equal("refrain")


func test_play_recovery_unblocks_a_chord() -> void:
	GameState.set_var_harmony("vex", -1, &"test_setup")
	var blocked: CompositionResult = _resolve_chord(GameState.get_var_harmony("vex"))

	var recovered := GameState.raise_var_harmony_from_play("vex", 1, &"combat")
	var unblocked: CompositionResult = _resolve_chord(recovered)

	assert_bool(blocked.allowed).is_false()
	assert_int(recovered).is_equal(0)
	assert_bool(unblocked.allowed).is_true()


func test_gate_preserves_strained_chord_var_cost() -> void:
	var result: CompositionResult = Resolver.resolve(
		[&"suul", &"aqua"], &"phrase", {"var_harmony": 0}
	)

	assert_int(result.kind).is_equal(Result.Kind.STRAINED_CHORD)
	assert_int(result.var_cost).is_equal(2)
	assert_bool(result.allowed).is_true()


func _resolve_tone(harmony: int, context: Dictionary = {}) -> CompositionResult:
	var gate_context := context.duplicate(true)
	gate_context["var_harmony"] = harmony
	return Resolver.resolve([&"suul"], &"note", gate_context)


func _resolve_chord(harmony: int, context: Dictionary = {}) -> CompositionResult:
	var gate_context := context.duplicate(true)
	gate_context["var_harmony"] = harmony
	return Resolver.resolve([&"suul", &"bloei"], &"phrase", gate_context)


func _resolve_triad(harmony: int, context: Dictionary = {}) -> CompositionResult:
	var gate_context := context.duplicate(true)
	gate_context["var_harmony"] = harmony
	return Resolver.resolve([&"strom", &"suul", &"bloei"], &"song", gate_context)
