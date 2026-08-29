extends GdUnitTestSuite
## Dedicated value-object coverage for BattleResult.


func test_new_result_defaults_to_an_unsuccessful_defeat() -> void:
	var result := BattleResult.new()

	assert_int(result.state).is_equal(BattleResult.State.DEFEAT)
	assert_str(String(result.encounter_id)).is_empty()
	assert_str(String(result.outcome_id)).is_empty()
	assert_str(result.message).is_empty()
	assert_str(result.cause).is_empty()
	assert_array(result.spoils).is_empty()
	assert_bool(result.succeeded()).is_false()
	assert_bool(result.fled()).is_false()


func test_assigned_fields_retain_their_values() -> void:
	var result := BattleResult.new()
	result.state = BattleResult.State.VICTORY
	result.encounter_id = &"bog-road"
	result.outcome_id = &"spared"
	result.message = "The road is clear."
	result.cause = "speech"
	result.spoils = [{"item_id": ItemIds.MATERIALS_LOAMROOT_SPRIG, "quantity": 2}]

	assert_int(result.state).is_equal(BattleResult.State.VICTORY)
	assert_str(String(result.encounter_id)).is_equal("bog-road")
	assert_str(String(result.outcome_id)).is_equal("spared")
	assert_str(result.message).is_equal("The road is clear.")
	assert_str(result.cause).is_equal("speech")
	assert_array(result.spoils).is_equal(
		[{"item_id": ItemIds.MATERIALS_LOAMROOT_SPRIG, "quantity": 2}]
	)
	assert_bool(result.succeeded()).is_true()
	assert_bool(result.fled()).is_false()


func test_fled_only_matches_the_fled_state() -> void:
	var result := BattleResult.new()
	result.state = BattleResult.State.FLED

	assert_bool(result.succeeded()).is_false()
	assert_bool(result.fled()).is_true()


func test_equivalent_results_keep_identity_equality_semantics() -> void:
	var first := BattleResult.new()
	first.state = BattleResult.State.VICTORY
	first.outcome_id = &"victory"
	var second := BattleResult.new()
	second.state = BattleResult.State.VICTORY
	second.outcome_id = &"victory"

	assert_object(first).is_same(first)
	assert_bool(first == second).is_false()


func test_mutating_one_result_does_not_change_another() -> void:
	var first := BattleResult.new()
	var second := BattleResult.new()

	first.state = BattleResult.State.VICTORY
	first.message = "Won"

	assert_int(second.state).is_equal(BattleResult.State.DEFEAT)
	assert_str(second.message).is_empty()
