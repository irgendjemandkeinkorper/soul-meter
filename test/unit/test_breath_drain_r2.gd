extends GdUnitTestSuite
## R2 (owner, 2026-10-31: `per scene`; roadmap P2.2, #595): a set-piece should drain a caster's
## Breath by PROVISIONAL round 3-4, so the overreach decision arrives mid-fight. This pins the
## steady-casting half of `tools/set_piece_drain.gd` against the live numbers: a caster who
## casts Notes or Phrases as often as the shipped AP allows first meets a cast its Breath cannot
## pay on turn 3 or 4 at Intuition 2-4. Intuition 5 (24 Breath, one Refrain) reaches it on turn
## 5, recorded in `docs/casting-economy.md` §(c) as the owner's call, not a failure here.
## Whether a set-piece lasts that long is the sweep's other half, and is the owner's call too.

const Drain := preload("res://tools/set_piece_drain.gd")
const R2_FIRST_TURN := 3
const R2_LAST_TURN := 4


func test_steady_notes_and_phrases_meet_the_overreach_decision_on_turn_three_or_four() -> void:
	var ap := (load("res://data/combat/combat_rules.tres") as CombatRules).base_action_points
	for magnitude: StringName in [&"note", &"phrase"]:
		var cost := AbilityDefinition.breath_cost_for_magnitude(magnitude)
		var per_turn := maxi(ap / _least_ap_for(cost), 1)
		for intuition: int in range(2, 5):
			var turn := Drain.decision_turn(DramgidDerived.breath_max(intuition), cost, per_turn)
			assert_int(turn)\
				.override_failure_message("%s at Intuition %d: overreach decision on turn %d" % [magnitude, intuition, turn])\
				.is_between(R2_FIRST_TURN, R2_LAST_TURN)


func test_the_decision_turn_counts_casts_within_and_across_turns() -> void:
	# 18 Breath, 3 a cast, 2 casts a turn: 12, 6, 0, then the fourth turn cannot pay.
	assert_int(Drain.decision_turn(18, 3, 2)).is_equal(4)
	# 15 Breath, 6 a cast, one a turn: 9, 3, then the third turn cannot pay.
	assert_int(Drain.decision_turn(15, 6, 1)).is_equal(3)
	# A Refrain past a 15 pool is the decision on the first cast.
	assert_int(Drain.decision_turn(15, 24, 1)).is_equal(1)


## The least AP any shipped spell card of this Breath cost needs: what a steady caster pays.
func _least_ap_for(cost: int) -> int:
	var least := 0
	for action: CombatAction in CombatActionCatalog.all():
		if action.spell and action.breath_cost == cost and (least == 0 or action.ap_cost < least):
			least = action.ap_cost
	assert_int(least).override_failure_message("no spell card costs %d Breath" % cost).is_greater(0)
	return least
