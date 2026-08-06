extends GdUnitTestSuite
## FR-102a TurnScheduler seam (amendment §2.1).
##
## Every contract test runs against BOTH implementations — the production charge-time scheduler
## and a throwaway round robin. That is the amendment's own definition of the seam being real:
## a test that only passes against ChargeTimeScheduler is coupled to charge-time internals, not
## to the TurnScheduler contract.

const RoundRobinScheduler := preload("res://test/helpers/round_robin_scheduler.gd")


func _rules() -> CombatRules:
	var rules := CombatRules.new()
	rules.base_charge_speed = 6
	rules.attribute_points_per_speed = 2
	return rules


func _actor(id: String, speed_attribute: int, hp: int = 20) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = id
	actor.combat_id = StringName(id)
	actor.hp = hp
	actor.max_hp = hp
	actor.attributes = {&"edge": speed_attribute}
	return actor


func _action(id: String, ct: int, verb: CombatAction.Verb = CombatAction.Verb.ATTACK) -> CombatAction:
	var action := CombatAction.new()
	action.id = StringName(id)
	action.display_name = id
	action.verb = verb
	action.ct_cost = ct
	return action


func _schedulers() -> Array[TurnScheduler]:
	var charge := TurnScheduler.create_default(_rules())
	var robin := RoundRobinScheduler.new() as TurnScheduler
	robin.configure(_rules())
	var both: Array[TurnScheduler] = [charge, robin]
	return both


# ---- contract tests: must pass against BOTH implementations ----


func test_both_implementations_satisfy_the_seam_contract() -> void:
	for scheduler in _schedulers():
		var label: String = scheduler.get_script().resource_path
		var a := _actor("a", 4)
		var b := _actor("b", 4)
		var group: Array[BattleActor] = [a, b]
		scheduler.setup(group)

		var first: Variant = scheduler.advance()
		assert_bool(first.get("allowed", false)).override_failure_message(
			"%s: advance() must produce a ready actor" % label
		).is_true()
		var actor: BattleActor = first.get("actor")
		assert_object(actor).is_not_null()

		# A committed action locks out everyone else until it resolves.
		var committed: Variant = scheduler.commit(actor, _action("strike", 30))
		assert_bool(committed.get("allowed", false)).override_failure_message(
			"%s: commit() must succeed for the ready actor" % label
		).is_true()
		var other: BattleActor = b if actor == a else a
		var blocked: Variant = scheduler.can_act(other)
		assert_bool(blocked.get("allowed", true)).is_false()
		assert_str(String(blocked.get("blocked_by", ""))).is_equal("awaiting_resolution")

		scheduler.release(actor)
		assert_int(scheduler.phase()).is_equal(TurnScheduler.Phase.RESOLVED)


func test_refusals_use_the_shared_taxonomy_shape() -> void:
	# FR-606 / amendment §2.2: one refusal shape across positioning, casting and turn order.
	for scheduler in _schedulers():
		var a := _actor("a", 4)
		var group: Array[BattleActor] = [a]
		scheduler.setup(group)
		var stranger := _actor("stranger", 4)
		var refusal: Variant = scheduler.can_act(stranger)
		assert_bool(refusal.get("allowed", true)).is_false()
		for key in ["allowed", "blocked_by", "nearest_unblock", "message"]:
			assert_bool(refusal.has(key)).override_failure_message(
				"refusal is missing '%s'; it must match BattlefieldModel._blocked()" % key
			).is_true()
		assert_str(String(refusal.get("blocked_by", ""))).is_equal("not_participating")
		assert_str(String(refusal.get("message", ""))).is_not_empty()


func test_interrupt_freezes_the_queue_and_resume_preserves_state() -> void:
	# Amendment §4: a speech check can end or split a battle mid-queue.
	for scheduler in _schedulers():
		var a := _actor("a", 4)
		var b := _actor("b", 4)
		var group: Array[BattleActor] = [a, b]
		scheduler.setup(group)
		scheduler.advance()

		var held: Variant = scheduler.interrupt(&"speech_resolution")
		assert_bool(held.get("allowed", false)).is_true()

		# Q1: CT freezes while held.
		var ticked: Variant = scheduler.advance()
		assert_bool(ticked.get("allowed", true)).override_failure_message(
			"advance() must refuse while interrupted"
		).is_false()
		assert_str(String(ticked.get("blocked_by", ""))).is_equal("interrupted")
		assert_object(scheduler.active_actor()).is_null()

		# Q3: banked progress survives the hold.
		var tick_before := scheduler.tick_count()
		scheduler.resume()
		assert_int(scheduler.tick_count()).is_equal(tick_before)
		var after: Variant = scheduler.advance()
		assert_bool(after.get("allowed", false)).is_true()


func test_interrupt_does_not_silently_void_a_committed_action() -> void:
	# The scheduler must not guess whether a speech voided the swing — §4 says the controller
	# decides. This is the specific "silence is not a policy" guarantee.
	for scheduler in _schedulers():
		var a := _actor("a", 4)
		var b := _actor("b", 4)
		var group: Array[BattleActor] = [a, b]
		scheduler.setup(group)
		var ready: Variant = scheduler.advance()
		var actor: BattleActor = ready.get("actor")
		scheduler.commit(actor, _action("cast", 40))

		var held: Variant = scheduler.interrupt(&"speech_resolution")
		assert_object(held.get("committed_actor")).override_failure_message(
			"interrupt() must report the committed actor so the controller can decide"
		).is_same(actor)
		assert_int(scheduler.phase()).override_failure_message(
			"a committed action must remain COMMITTED across an interrupt"
		).is_equal(TurnScheduler.Phase.COMMITTED)

		var cancelled: Variant = scheduler.cancel_committed(actor, true)
		assert_bool(cancelled.get("allowed", false)).is_true()
		assert_int(scheduler.phase()).is_equal(TurnScheduler.Phase.CANCELLED)


func test_removing_a_participant_does_not_reorder_survivors() -> void:
	# A speech-driven split must not silently reshuffle the queue.
	for scheduler in _schedulers():
		var a := _actor("a", 6)
		var b := _actor("b", 4)
		var c := _actor("c", 2)
		var group: Array[BattleActor] = [a, b, c]
		scheduler.setup(group)
		scheduler.advance()
		var before := scheduler.peek_order(3)
		var survivors_before: Array = []
		for entry in before:
			if entry["actor"] != b:
				survivors_before.append(entry["actor"])

		scheduler.remove_participant(b)
		var after := scheduler.peek_order(3)
		var survivors_after: Array = []
		for entry in after:
			survivors_after.append(entry["actor"])

		for i in mini(survivors_before.size(), survivors_after.size()):
			assert_object(survivors_after[i]).override_failure_message(
				"removing a participant reordered the survivors"
			).is_same(survivors_before[i])


func test_save_load_round_trip_reproduces_the_same_next_actor() -> void:
	# Gate T criterion 10 in miniature: state survives a round trip.
	for scheduler in _schedulers():
		var a := _actor("a", 6)
		var b := _actor("b", 3)
		var group: Array[BattleActor] = [a, b]
		scheduler.setup(group)
		scheduler.advance()
		var expected := scheduler.active_actor()
		var saved := scheduler.to_dict()

		var restored: TurnScheduler = scheduler.get_script().new()
		restored.configure(_rules())
		restored.setup(group)
		restored.from_dict(saved)
		assert_object(restored.active_actor()).override_failure_message(
			"the next actor changed across a save/load round trip"
		).is_same(expected)


# ---- charge-time specifics: production implementation only ----


func test_charge_time_ordering_is_deterministic_across_identical_runs() -> void:
	var sequences: Array = []
	for run in 3:
		var scheduler := TurnScheduler.create_default(_rules())
		var a := _actor("a", 6)
		var b := _actor("b", 4)
		var c := _actor("c", 2)
		var group: Array[BattleActor] = [a, b, c]
		scheduler.setup(group)
		var order: Array[String] = []
		for step in 6:
			var ready: Variant = scheduler.advance()
			var actor: BattleActor = ready.get("actor")
			order.append(String(actor.combat_id))
			scheduler.commit(actor, _action("strike", 30))
			scheduler.release(actor)
		sequences.append(order)
	assert_array(sequences[1]).override_failure_message(
		"identical inputs produced different turn orders — determinism is broken"
	).is_equal(sequences[0])
	assert_array(sequences[2]).is_equal(sequences[0])


func test_faster_actors_act_more_often() -> void:
	var scheduler := TurnScheduler.create_default(_rules())
	var swift := _actor("swift", 20)
	var slow := _actor("slow", 0)
	var group: Array[BattleActor] = [swift, slow]
	scheduler.setup(group)
	var swift_turns := 0
	var slow_turns := 0
	for step in 12:
		var ready: Variant = scheduler.advance()
		var actor: BattleActor = ready.get("actor")
		if actor == swift:
			swift_turns += 1
		else:
			slow_turns += 1
		scheduler.commit(actor, _action("strike", 30))
		scheduler.release(actor)
	assert_int(swift_turns).override_failure_message(
		"a higher speed attribute must yield more turns (swift=%d slow=%d)"
		% [swift_turns, slow_turns]
	).is_greater(slow_turns)


func test_charge_overflow_is_preserved_not_truncated() -> void:
	# Reaching 112 CT and spending 30 must leave 82, not 70. Truncating to READY_AT would
	# quietly punish being fast and make the timeline lie.
	var scheduler := TurnScheduler.create_default(_rules())
	var fast := _actor("fast", 30)
	var group: Array[BattleActor] = [fast]
	scheduler.setup(group)
	scheduler.advance()
	var charge_at_turn := scheduler.charge_of(fast)
	assert_int(charge_at_turn).is_greater_equal(TurnScheduler.READY_AT)
	scheduler.commit(fast, _action("strike", 30))
	assert_int(scheduler.charge_of(fast)).override_failure_message(
		"overflow was truncated: %d - 30 should be %d" % [charge_at_turn, charge_at_turn - 30]
	).is_equal(charge_at_turn - 30)


func test_banked_overflow_survives_an_interrupt_without_double_acting() -> void:
	# Amendment §4 question 3, the sharpest edge case: a participant sitting well past
	# READY_AT when a speech check halts the queue must neither be clamped back to 100 nor
	# get a free second turn when the battle resumes.
	var scheduler := TurnScheduler.create_default(_rules())
	var fast := _actor("fast", 30)
	var slow := _actor("slow", 0)
	var group: Array[BattleActor] = [fast, slow]
	scheduler.setup(group)
	scheduler.advance()

	var banked := scheduler.charge_of(fast)
	assert_int(banked).override_failure_message(
		"setup should leave the fast actor past the threshold for this test to mean anything"
	).is_greater(TurnScheduler.READY_AT)

	scheduler.interrupt(&"speech_resolution")
	assert_int(scheduler.charge_of(fast)).override_failure_message(
		"an interrupt clamped or reset banked charge"
	).is_equal(banked)

	scheduler.resume()
	assert_int(scheduler.charge_of(fast)).is_equal(banked)

	# Resuming must not hand out a turn that was never spent.
	scheduler.commit(fast, _action("strike", 30))
	scheduler.release(fast)
	assert_int(scheduler.charge_of(fast)).override_failure_message(
		"resume produced a free turn — charge should have dropped by exactly the action cost"
	).is_equal(banked - 30)


func test_ct_not_ready_refusal_reports_how_many_ticks_remain() -> void:
	# FR-606 wants the nearest unblock condition, not just a refusal.
	var scheduler := TurnScheduler.create_default(_rules())
	var a := _actor("a", 4)
	var group: Array[BattleActor] = [a]
	scheduler.setup(group)
	var refusal := scheduler.can_act(a)
	assert_bool(refusal.get("allowed", true)).is_false()
	assert_str(String(refusal.get("blocked_by", ""))).is_equal("ct_not_ready")
	var unblock: Dictionary = refusal.get("nearest_unblock", {})
	assert_int(int(unblock.get("ticks", 0))).override_failure_message(
		"ct_not_ready must say how many ticks remain"
	).is_greater(0)


func test_measure_is_sixteen_ticks() -> void:
	var scheduler := TurnScheduler.create_default(_rules())
	var slow := _actor("slow", 0)
	var group: Array[BattleActor] = [slow]
	scheduler.setup(group)
	assert_int(scheduler.measure_index()).is_equal(0)
	var crossed := 0
	for step in 4:
		var ready: Variant = scheduler.advance()
		crossed += int(ready.get("measures_crossed", 0))
		scheduler.commit(slow, _action("strike", 30))
		scheduler.release(slow)
	assert_int(scheduler.tick_count() / TurnScheduler.TICKS_PER_MEASURE).is_equal(
		scheduler.measure_index()
	)
	assert_int(crossed).override_failure_message(
		"measures_crossed must report the weather beat"
	).is_greater(0)


func test_unauthored_ct_cost_falls_back_to_the_ap_conversion_shim() -> void:
	# Amendment §8.1: AP compatibility is retained, not removed alongside CT.
	var rules := _rules()
	var unauthored := CombatAction.new()
	unauthored.ap_cost = 3
	unauthored.ct_cost = -1
	unauthored.verb = CombatAction.Verb.ATTACK
	var derived := rules.charge_cost_for(unauthored)
	assert_int(derived).is_between(rules.minimum_action_ct_cost, rules.maximum_action_ct_cost)

	var moved := CombatAction.new()
	moved.ct_cost = -1
	moved.verb = CombatAction.Verb.MOVE
	assert_int(rules.charge_cost_for(moved)).override_failure_message(
		"movement must price at move_ct_cost, not the attack band"
	).is_equal(rules.move_ct_cost)

	var authored := CombatAction.new()
	authored.ap_cost = 3
	authored.ct_cost = 45
	assert_int(rules.charge_cost_for(authored)).override_failure_message(
		"an authored ct_cost must win over the shim"
	).is_equal(45)
