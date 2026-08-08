extends GdUnitTestSuite

## M4.3 — husking-while-alive (cosmology/souls.md, ratified 2026-08-07).
## Reaching Gauge zero husks the caster; it does not end the run.

const QuestAudit := preload("res://tools/quest_audit.gd")

var game_state_before_test: Dictionary = {}


func before_test() -> void:
	game_state_before_test = GameState.to_dict()


func after_test() -> void:
	GameState.from_dict(game_state_before_test)


func test_reaching_zero_husks_but_does_not_end_the_run() -> void:
	GameState.soul_meter = 10.0
	assert_bool(GameState.is_husked()).is_false()

	GameState.soul_meter = 0.0

	assert_float(GameState.soul_meter).is_equal(0.0)
	assert_bool(GameState.is_husked()).is_true()


func test_spending_past_zero_still_clamps_to_zero_and_husks() -> void:
	GameState.soul_meter = 6.0
	GameState.soul_meter = -40.0

	assert_float(GameState.soul_meter).is_equal(0.0)
	assert_bool(GameState.is_husked()).is_true()


func test_husked_flag_satisfies_the_registered_soul_domain_grammar() -> void:
	assert_array(PackedStringArray(QuestAudit.FLAG_DOMAINS)).contains("soul")

	var flag_parts := QuestAudit.split_flag(GameState.HUSKED_FLAG)
	assert_bool(flag_parts.is_empty()).is_false()
	assert_str(str(flag_parts.get("domain"))).is_equal("soul")

	var ceiling_parts := QuestAudit.split_flag(GameState.HUSKED_RECOVERY_CEILING_FLAG)
	assert_bool(ceiling_parts.is_empty()).is_false()
	assert_str(str(ceiling_parts.get("domain"))).is_equal("soul")


func test_not_husked_soul_meter_still_clamps_zero_to_one_hundred() -> void:
	GameState.soul_meter = 500.0
	assert_float(GameState.soul_meter).is_equal(100.0)

	GameState.soul_meter = -500.0
	assert_float(GameState.soul_meter).is_equal(0.0)


func test_casting_gate_refuses_while_husked_naming_system_and_unblock() -> void:
	GameState.soul_meter = 10.0
	GameState.soul_meter = 0.0

	var context := GameState.husked_casting_context()
	var tone := CastingGate.query_breadth(&"tone", 5, &"", context)
	var chord := CastingGate.query_breadth(&"chord", 5, &"", context)
	var triad := CastingGate.query_breadth(&"triad", 5, &"", context)

	for gate in [tone, chord, triad]:
		assert_bool(gate["allowed"]).is_false()
		assert_str(gate["blocked_by"]).is_equal("husked")
		assert_str(gate["message"]).is_not_empty()
		assert_str(gate["nearest_unblock"]["type"]).is_equal("husked_recovery")


func test_casting_gate_query_also_refuses_a_composition_result_while_husked() -> void:
	GameState.soul_meter = 0.0
	var result := CompositionResult.new()
	result.kind = CompositionResult.Kind.TONE

	var gate := CastingGate.query(result, 5, GameState.husked_casting_context())

	assert_bool(gate["allowed"]).is_false()
	assert_str(gate["blocked_by"]).is_equal("husked")


func test_not_husked_casting_gate_is_unaffected() -> void:
	var context := GameState.husked_casting_context()
	assert_bool(bool(context["husked"])).is_false()

	var chord := CastingGate.query_breadth(&"chord", 0, &"", context)
	assert_bool(chord["allowed"]).is_true()


func test_husked_state_survives_save_and_load() -> void:
	GameState.soul_meter = 40.0
	GameState.soul_meter = 0.0
	assert_bool(GameState.is_husked()).is_true()
	var ceiling_before := GameState.husked_recovery_ceiling()

	var saved := GameState.to_dict()

	# Simulate a fresh load: clear the runtime state, then restore from the
	# serialized payload alone.
	GameState.flags.clear()
	GameState.soul_meter = 50.0
	assert_bool(GameState.is_husked()).is_false()

	assert_bool(GameState.from_dict(saved)).is_true()

	assert_bool(GameState.is_husked()).is_true()
	assert_float(GameState.husked_recovery_ceiling()).is_equal(ceiling_before)
	assert_float(GameState.soul_meter).is_equal(0.0)


func test_recovery_is_partial_by_construction_and_never_reaches_pre_zero_value() -> void:
	GameState.soul_meter = 40.0
	GameState.soul_meter = 0.0
	var ceiling := GameState.husked_recovery_ceiling()

	assert_float(ceiling).is_less(40.0)

	# Even a large recovery attempt cannot restore the pre-zero reading.
	GameState.soul_meter = 100.0

	assert_float(GameState.soul_meter).is_equal(ceiling)
	assert_float(GameState.soul_meter).is_less(40.0)


func test_recovering_above_zero_clears_the_husked_flag_but_keeps_the_ceiling() -> void:
	GameState.soul_meter = 40.0
	GameState.soul_meter = 0.0
	var ceiling := GameState.husked_recovery_ceiling()

	GameState.soul_meter = ceiling

	assert_bool(GameState.is_husked()).is_false()
	assert_bool(GameState.has_been_husked()).is_true()

	# The scar persists: a later recovery attempt still cannot exceed the
	# ceiling, even though the caster is no longer currently husked.
	GameState.soul_meter = 100.0
	assert_float(GameState.soul_meter).is_equal(ceiling)


func test_the_husked_refusal_actually_fires_through_the_resolver() -> void:
	# Regression: CastingGate returned the refusal, but the resolver only
	# consults the gate when `caster_context` carries a recognised key. "husked"
	# was missing from that list, so this refusal passed every unit test and
	# would never have fired in a real cast.
	GameState.set_soul_meter(0.0)
	assert_bool(GameState.is_husked()).is_true()

	var context := GameState.husked_casting_context()
	assert_bool(CompositionResolver._has_gate_context(context)).is_true()

	var refusal: Dictionary = CastingGate.query(&"tone", 0, context)
	assert_bool(bool(refusal.get("allowed", true))).is_false()
	assert_str(str(refusal.get("blocked_by", ""))).is_equal("husked")
