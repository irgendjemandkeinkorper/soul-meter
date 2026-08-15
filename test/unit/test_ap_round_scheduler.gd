extends GdUnitTestSuite
## ApRoundScheduler — the FR-102 AP round economy behind the TurnScheduler seam.
##
## Two things are under test and they are different:
##
##   1. That the AP model still behaves exactly as CombatController's round loop did. This is a
##      port, so "the same as before" is the acceptance criterion, including the parts nobody
##      would design on purpose (one act per enemy per round).
##   2. That the flag selects it, both directions. Amendment §8 makes the abort path a flag flip;
##      a flip that only works one way is not an abort path, so both are asserted.

const ApRoundScheduler := preload("res://globals/combat/ap_round_scheduler.gd")
const ChargeTimeScheduler := preload("res://globals/combat/charge_time_scheduler.gd")


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_action_points = 4
	rules.attribute_points_per_ap = 2
	rules.minimum_action_points = 2
	rules.maximum_action_points = 8
	return rules


func _actor(id: String, side: StringName, hp: int = 20) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = id
	actor.combat_id = StringName(id)
	actor.side = side
	actor.hp = hp
	actor.max_hp = hp
	actor.attributes = {&"edge": 4}
	return actor


func _action(id: String, ap: int) -> CombatAction:
	var action := CombatAction.new()
	action.id = StringName(id)
	action.display_name = id
	action.verb = CombatAction.Verb.ATTACK
	action.ap_cost = ap
	return action


func _scheduler(participants: Array[BattleActor]) -> TurnScheduler:
	var scheduler := ApRoundScheduler.new() as TurnScheduler
	scheduler.configure(_rules())
	scheduler.setup(participants)
	return scheduler


# ---- the flag is the abort path ----


func test_create_default_builds_the_ap_model_when_charge_time_is_off() -> void:
	var rules := _rules()
	rules.use_charge_time = false
	var scheduler := TurnScheduler.create_default(rules)
	assert_str(scheduler.get_script().resource_path).is_equal(
		"res://globals/combat/ap_round_scheduler.gd"
	)


func test_create_default_builds_charge_time_when_the_flag_is_on() -> void:
	var rules := _rules()
	rules.use_charge_time = true
	var scheduler := TurnScheduler.create_default(rules)
	assert_str(scheduler.get_script().resource_path).is_equal(
		"res://globals/combat/charge_time_scheduler.gd"
	)


func test_the_ap_model_is_the_default_when_no_rules_are_supplied() -> void:
	# A null CombatRules must not silently activate charge time. The conservative branch is the
	# one that has to be unconditional.
	var scheduler := TurnScheduler.create_default(null)
	assert_str(scheduler.get_script().resource_path).is_equal(
		"res://globals/combat/ap_round_scheduler.gd"
	)


# ---- round bookkeeping ----


func test_the_first_advance_opens_round_one_and_refreshes_every_living_participant() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var foe := _actor("enemy-0", ApRoundScheduler.ENEMY_SIDE)
	var group: Array[BattleActor] = [ally, foe]
	var scheduler := _scheduler(group)

	var opened: Dictionary = scheduler.advance()

	assert_bool(opened.get("allowed", false)).is_true()
	assert_bool(opened.get("round_started", false)).is_true()
	assert_int(opened.get("round", 0)).is_equal(1)
	assert_int((opened.get("refreshed", []) as Array).size()).is_equal(2)
	assert_object(opened.get("actor")).is_same(ally)
	assert_int(ally.action_points).is_equal(ally.max_action_points)
	assert_int(foe.action_points).is_equal(foe.max_action_points)


func test_a_dead_participant_is_not_refreshed() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var corpse := _actor("ally-1", ApRoundScheduler.ALLY_SIDE, 0)
	var group: Array[BattleActor] = [ally, corpse]
	var scheduler := _scheduler(group)

	var opened: Dictionary = scheduler.advance()

	assert_int((opened.get("refreshed", []) as Array).size()).is_equal(1)
	assert_int(corpse.action_points).is_equal(0)


func test_a_round_is_the_measure_so_the_beat_fires_once_per_round() -> void:
	# Weather and any other measure-driven beat ride measure_index(). Under charge time a measure
	# is 16 ticks; under AP it is a round. Both must advance, or the beat silently stops when the
	# abort flag is flipped.
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var group: Array[BattleActor] = [ally]
	var scheduler := _scheduler(group)

	scheduler.advance()
	var first_measure: int = scheduler.measure_index()
	scheduler.yield_turn(ally)
	var second: Dictionary = scheduler.advance()

	assert_bool(second.get("round_ended", false)).is_true()
	assert_int(scheduler.measure_index()).is_equal(first_measure + 1)
	assert_int(second.get("measures_crossed", 0)).is_equal(1)


# ---- ally turns: act until AP runs out ----


func test_an_ally_keeps_the_turn_while_ap_remains() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var other := _actor("ally-1", ApRoundScheduler.ALLY_SIDE)
	var group: Array[BattleActor] = [ally, other]
	var scheduler := _scheduler(group)
	scheduler.advance()

	var strike := _action("strike", 2)
	scheduler.commit(ally, strike)
	scheduler.release(ally)
	var still: Dictionary = scheduler.advance()

	assert_object(still.get("actor")).is_same(ally)
	assert_int(still.get("ticks_elapsed", -1)).is_equal(0)


func test_the_turn_passes_to_the_next_ally_when_ap_is_exhausted() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var other := _actor("ally-1", ApRoundScheduler.ALLY_SIDE)
	var group: Array[BattleActor] = [ally, other]
	var scheduler := _scheduler(group)
	scheduler.advance()

	var heavy := _action("heavy", ally.max_action_points)
	scheduler.commit(ally, heavy)
	scheduler.release(ally)
	var passed: Dictionary = scheduler.advance()

	assert_int(ally.action_points).is_equal(0)
	assert_object(passed.get("actor")).is_same(other)


func test_yield_turn_forfeits_remaining_ap_and_passes_the_turn() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var other := _actor("ally-1", ApRoundScheduler.ALLY_SIDE)
	var group: Array[BattleActor] = [ally, other]
	var scheduler := _scheduler(group)
	scheduler.advance()
	var before := ally.action_points

	var yielded: Dictionary = scheduler.yield_turn(ally)
	var passed: Dictionary = scheduler.advance()

	assert_bool(yielded.get("allowed", false)).is_true()
	assert_int(yielded.get("ct_spent", -1)).is_equal(before)
	assert_int(ally.action_points).is_equal(0)
	assert_object(passed.get("actor")).is_same(other)


func test_yield_turn_refuses_a_combatant_whose_turn_it_is_not() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var other := _actor("ally-1", ApRoundScheduler.ALLY_SIDE)
	var group: Array[BattleActor] = [ally, other]
	var scheduler := _scheduler(group)
	scheduler.advance()

	var refusal: Dictionary = scheduler.yield_turn(other)

	assert_bool(refusal.get("allowed", true)).is_false()
	assert_str(String(refusal.get("blocked_by", ""))).is_equal("ct_not_ready")
	assert_int(other.action_points).is_greater(0)


# ---- enemy turns: exactly once per round ----


func test_enemies_act_after_every_ally() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var foe := _actor("enemy-0", ApRoundScheduler.ENEMY_SIDE)
	var group: Array[BattleActor] = [ally, foe]
	var scheduler := _scheduler(group)
	scheduler.advance()

	scheduler.yield_turn(ally)
	var enemy_turn: Dictionary = scheduler.advance()

	assert_object(enemy_turn.get("actor")).is_same(foe)
	assert_str(String(enemy_turn.get("side_started", ""))).is_equal("enemy")


func test_each_enemy_acts_exactly_once_per_round() -> void:
	# This is the old burst loop's rule, kept verbatim. An enemy with AP left over does NOT act
	# again — charge time is what changes that, not this shim.
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var foe := _actor("enemy-0", ApRoundScheduler.ENEMY_SIDE)
	var group: Array[BattleActor] = [ally, foe]
	var scheduler := _scheduler(group)
	scheduler.advance()
	scheduler.yield_turn(ally)
	scheduler.advance()

	var cheap := _action("jab", 1)
	scheduler.commit(foe, cheap)
	scheduler.release(foe)
	var after: Dictionary = scheduler.advance()

	assert_int(foe.action_points).is_greater(0)
	assert_bool(after.get("round_ended", false)).is_true()
	assert_int(after.get("round", 0)).is_equal(2)


func test_a_cancelled_enemy_action_does_not_consume_its_one_act() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var foe := _actor("enemy-0", ApRoundScheduler.ENEMY_SIDE)
	var group: Array[BattleActor] = [ally, foe]
	var scheduler := _scheduler(group)
	scheduler.advance()
	scheduler.yield_turn(ally)
	scheduler.advance()

	var cheap := _action("jab", 1)
	scheduler.commit(foe, cheap)
	var cancelled: Dictionary = scheduler.cancel_committed(foe, true)
	var still: Dictionary = scheduler.advance()

	assert_bool(cancelled.get("allowed", false)).is_true()
	assert_int(foe.action_points).is_equal(foe.max_action_points)
	assert_object(still.get("actor")).is_same(foe)


# ---- refusals: FR-606 taxonomy ----


func test_an_unaffordable_action_is_refused_as_action_points() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var group: Array[BattleActor] = [ally]
	var scheduler := _scheduler(group)
	scheduler.advance()

	var unaffordable := _action("ruinous", ally.max_action_points + 3)
	var refusal: Dictionary = scheduler.commit(ally, unaffordable)

	assert_bool(refusal.get("allowed", true)).is_false()
	assert_str(String(refusal.get("blocked_by", ""))).is_equal("action_points")
	assert_int(refusal.get("nearest_unblock", {}).get("minimum", 0)).is_equal(
		ally.max_action_points + 3
	)
	assert_int(ally.action_points).is_equal(ally.max_action_points)


func test_a_non_participant_is_refused_distinctly_from_a_waiting_combatant() -> void:
	# "You are not in this battle" and "it is not your turn" must not collapse into one refusal.
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var other := _actor("ally-1", ApRoundScheduler.ALLY_SIDE)
	var stranger := _actor("ally-9", ApRoundScheduler.ALLY_SIDE)
	var group: Array[BattleActor] = [ally, other]
	var scheduler := _scheduler(group)
	scheduler.advance()

	assert_str(String(scheduler.can_act(stranger).get("blocked_by", ""))).is_equal(
		"not_participating"
	)
	assert_str(String(scheduler.can_act(other).get("blocked_by", ""))).is_equal("ct_not_ready")


func test_a_defeated_combatant_is_refused_distinctly() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var corpse := _actor("ally-1", ApRoundScheduler.ALLY_SIDE, 0)
	var group: Array[BattleActor] = [ally, corpse]
	var scheduler := _scheduler(group)
	scheduler.advance()

	assert_str(String(scheduler.can_act(corpse).get("blocked_by", ""))).is_equal("defeated")


func test_an_interrupt_holds_the_queue_and_resume_preserves_banked_ap() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var group: Array[BattleActor] = [ally]
	var scheduler := _scheduler(group)
	scheduler.advance()
	var banked := ally.action_points

	scheduler.interrupt(&"speech")
	var held: Dictionary = scheduler.advance()
	scheduler.resume()

	assert_bool(held.get("allowed", true)).is_false()
	assert_str(String(held.get("blocked_by", ""))).is_equal("interrupted")
	assert_int(ally.action_points).is_equal(banked)
	assert_object(scheduler.active_actor()).is_same(ally)


# ---- determinism and persistence ----


func test_the_same_setup_produces_the_same_order_twice() -> void:
	var first := _walk_ten_turns()
	var second := _walk_ten_turns()
	assert_array(first).is_equal(second)


func test_state_survives_a_round_trip_through_to_dict() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var foe := _actor("enemy-0", ApRoundScheduler.ENEMY_SIDE)
	var group: Array[BattleActor] = [ally, foe]
	var scheduler := _scheduler(group)
	scheduler.advance()
	scheduler.yield_turn(ally)
	scheduler.advance()

	var saved: Dictionary = scheduler.to_dict()
	var restored := _scheduler(group)
	restored.from_dict(saved)

	assert_dict(restored.to_dict()).is_equal(saved)
	assert_object(restored.active_actor()).is_same(foe)


func test_peek_order_lists_the_rest_of_the_round_in_acting_order() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var other := _actor("ally-1", ApRoundScheduler.ALLY_SIDE)
	var foe := _actor("enemy-0", ApRoundScheduler.ENEMY_SIDE)
	var group: Array[BattleActor] = [ally, other, foe]
	var scheduler := _scheduler(group)
	scheduler.advance()

	var order: Array = scheduler.peek_order(3)

	assert_int(order.size()).is_equal(3)
	assert_object(order[0]["actor"]).is_same(ally)
	assert_object(order[1]["actor"]).is_same(other)
	assert_object(order[2]["actor"]).is_same(foe)


func _walk_ten_turns() -> Array[String]:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var other := _actor("ally-1", ApRoundScheduler.ALLY_SIDE)
	var foe := _actor("enemy-0", ApRoundScheduler.ENEMY_SIDE)
	var group: Array[BattleActor] = [ally, other, foe]
	var scheduler := _scheduler(group)
	var seen: Array[String] = []
	for i in 10:
		var step: Dictionary = scheduler.advance()
		if not bool(step.get("allowed", false)):
			break
		var actor := step.get("actor") as BattleActor
		seen.append(String(actor.combat_id))
		scheduler.yield_turn(actor)
	return seen


func test_force_advance_gates_enemy_act_bookkeeping_on_the_active_round_side() -> void:
	var ally := _actor("ally-0", ApRoundScheduler.ALLY_SIDE)
	var foe := _actor("enemy-0", ApRoundScheduler.ENEMY_SIDE)
	var group: Array[BattleActor] = [ally, foe]
	var scheduler := _scheduler(group)
	assert_bool(scheduler.advance()["allowed"]).is_true()

	# The ally round is active. Force-passing the enemy now must NOT consume its one
	# act for the coming enemy round (same _side gate as commit()/cancel_committed()).
	var forced: Dictionary = scheduler.force_advance(foe)
	assert_bool(forced["allowed"]).is_true()
	assert_int(int(forced["ct_refunded"])).is_equal(0)
	assert_bool(scheduler.to_dict()["acted_this_round"].has(String(foe.combat_id))).is_false()

	# Hand the round to the enemy side; a forced pass there DOES consume the act.
	scheduler.yield_turn(ally)
	var step: Dictionary = scheduler.advance()
	assert_object(step.get("actor")).is_same(foe)
	assert_bool(scheduler.force_advance(foe)["allowed"]).is_true()
	assert_bool(scheduler.to_dict()["acted_this_round"].has(String(foe.combat_id))).is_true()
