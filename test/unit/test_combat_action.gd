extends GdUnitTestSuite


func test_attack_summary_explains_target_balance_and_cost() -> void:
	var action := CombatAction.make(&"definition", "Defining Strike", CombatAction.Kind.ATTACK, 3, 25, 2.0)

	assert_str(action.summary()).is_equal("Enemy target · +25 Order · 2 Soul")


func test_defensive_summaries_explain_self_target_and_balance_effect() -> void:
	var guard := CombatAction.make(&"guard", "Guard", CombatAction.Kind.GUARD)
	var stabilize := CombatAction.make(&"stabilize", "Stabilize", CombatAction.Kind.STABILIZE)

	assert_str(guard.summary()).is_equal("Self · Reduces the next hit · Free")
	assert_str(stabilize.summary()).is_equal(
		"Self · Pulls Balance 30 toward Equilibrium · Free"
	)


func test_resolution_summary_explains_that_it_ends_the_encounter() -> void:
	var action := CombatAction.from_context_row(
		{"id": "release", "display_name": "Release", "outcome_id": "released", "soul_cost": 0.0}
	)

	assert_str(action.summary()).is_equal("Encounter · Ends the encounter · Free")
