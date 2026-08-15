extends GdUnitTestSuite

func _actor(id: String, edge: int = 0, hp: int = 10) -> BattleActor:
	var actor := BattleActor.new()
	actor.combat_id = StringName(id)
	actor.display_name = id
	actor.attributes = {&"edge": edge}
	actor.hp = hp
	actor.max_hp = 10
	return actor

func _scheduler(actors: Array[BattleActor]) -> TurnScheduler:
	var rules := CombatRules.new()
	rules.base_charge_speed = 50
	rules.attribute_points_per_speed = 2
	var scheduler: TurnScheduler = preload("res://globals/combat/charge_time_scheduler.gd").new()
	scheduler.configure(rules)
	scheduler.setup(actors)
	return scheduler

func test_advance_selects_ready_actor_and_preserves_tie_seat_order() -> void:
	var first := _actor("first")
	var second := _actor("second")
	var scheduler := _scheduler([first, second])
	var result := scheduler.advance()
	assert_bool(result["allowed"]).is_true()
	assert_int(result["ticks_elapsed"]).is_equal(4)
	assert_object(result["actor"]).is_equal(first)
	assert_int(scheduler.charge_of(second)).is_equal(120)

func test_commit_release_yield_and_not_ready_refusals() -> void:
	var actor := _actor("actor")
	var scheduler := _scheduler([actor])
	assert_str(String(scheduler.can_act(actor)["blocked_by"])).is_equal("ct_not_ready")
	scheduler.advance()
	var action := CombatAction.new()
	action.ct_cost = 30
	var committed := scheduler.commit(actor, action)
	assert_int(committed["ct_spent"]).is_equal(30)
	assert_int(int(scheduler.phase())).is_equal(1)
	assert_str(String(scheduler.can_act(_actor("other"))["blocked_by"])).is_equal("not_participating")
	scheduler.release(actor)
	var yielded := scheduler.yield_turn(actor)
	assert_bool(yielded["allowed"]).is_false()

func test_interrupt_cancel_refund_and_resume_preserve_state() -> void:
	var actor := _actor("actor")
	var scheduler := _scheduler([actor])
	scheduler.advance()
	var action := CombatAction.new()
	action.ct_cost = 30
	scheduler.commit(actor, action)
	var held := scheduler.interrupt(&"speech")
	assert_bool(held["allowed"]).is_true()
	assert_str(String(scheduler.advance()["blocked_by"])).is_equal("interrupted")
	var cancelled := scheduler.cancel_committed(actor, true)
	assert_int(cancelled["ct_refunded"]).is_equal(30)
	scheduler.resume()
	assert_int(scheduler.charge_of(actor)).is_equal(120)

func test_to_dict_round_trip_restores_charge_and_interrupt_reason() -> void:
	var actor := _actor("actor")
	var scheduler := _scheduler([actor])
	scheduler.advance()
	scheduler.interrupt(&"pause")
	var restored := _scheduler([actor])
	restored.from_dict(scheduler.to_dict())
	assert_int(restored.tick_count()).is_equal(scheduler.tick_count())
	assert_int(restored.charge_of(actor)).is_equal(scheduler.charge_of(actor))
	assert_str(String(restored.can_act(actor)["blocked_by"])).is_equal("interrupted")

func test_wait_refund_is_flat_half_ready_at_and_floors_odd_thresholds() -> void:
	var scheduler_script := preload("res://globals/combat/charge_time_scheduler.gd")
	assert_int(scheduler_script.wait_refund_ct(101)).is_equal(50)
	assert_int(scheduler_script.wait_refund_ct(99)).is_equal(49)

	var actor := _actor("actor")
	var scheduler := _scheduler([actor])
	scheduler.advance()
	var yielded := scheduler.yield_turn(actor)
	assert_bool(yielded["allowed"]).is_true()
	assert_int(scheduler.charge_of(actor)).is_equal(50)
	assert_int(yielded["ct_refunded"]).is_equal(50)

func test_wait_discards_overflow_before_applying_flat_refund() -> void:
	var fast := _actor("fast", 20)
	var scheduler := _scheduler([fast])
	scheduler.advance()
	assert_int(scheduler.charge_of(fast)).is_greater(100)
	var charge_before := scheduler.charge_of(fast)
	var yielded := scheduler.yield_turn(fast)
	assert_int(scheduler.charge_of(fast)).is_equal(50)
	assert_int(yielded["overflow_discarded"]).is_equal(charge_before - 100)

func test_third_consecutive_wait_is_refused_and_non_wait_action_resets_cap() -> void:
	var actor := _actor("actor")
	var scheduler := _scheduler([actor])
	for expected_count in [1, 2]:
		scheduler.advance()
		var yielded := scheduler.yield_turn(actor)
		assert_bool(yielded["allowed"]).is_true()
		assert_int(yielded["consecutive_waits"]).is_equal(expected_count)
	scheduler.advance()
	var refused := scheduler.yield_turn(actor)
	assert_bool(refused["allowed"]).is_false()
	assert_str(String(refused["blocked_by"])).is_equal("consecutive_wait_cap")
	assert_int(scheduler.charge_of(actor)).is_greater_equal(100)

	var action := CombatAction.new()
	action.ct_cost = 30
	assert_bool(scheduler.commit(actor, action)["allowed"]).is_true()
	scheduler.release(actor)
	scheduler.advance()
	var yielded_after_action := scheduler.yield_turn(actor)
	assert_bool(yielded_after_action["allowed"]).is_true()
	assert_int(yielded_after_action["consecutive_waits"]).is_equal(1)

func test_consecutive_wait_counter_round_trips_with_scheduler_state() -> void:
	var actor := _actor("actor")
	var scheduler := _scheduler([actor])
	for _wait_index in 2:
		scheduler.advance()
		assert_bool(scheduler.yield_turn(actor)["allowed"]).is_true()
	var saved := scheduler.to_dict()
	assert_int(saved["consecutive_waits"]["actor"]).is_equal(2)

	var restored := _scheduler([actor])
	restored.from_dict(saved)
	restored.advance()
	var refused := restored.yield_turn(actor)
	assert_bool(refused["allowed"]).is_false()
	assert_str(String(refused["blocked_by"])).is_equal("consecutive_wait_cap")

func test_large_queue_is_deterministic_fair_and_interrupt_safe_across_battles() -> void:
	var reference_order: Array[StringName] = []
	for battle_index in 3:
		var actors: Array[BattleActor] = []
		for actor_index in 8:
			actors.append(_actor("unit_%d" % actor_index))
		var scheduler := _scheduler(actors)
		var observed_order: Array[StringName] = []
		var turn_counts: Dictionary = {}
		var action := CombatAction.new()
		action.ct_cost = 30
		for turn_index in 48:
			var advanced := scheduler.advance()
			assert_bool(advanced["allowed"]).is_true()
			var actor: BattleActor = advanced["actor"]
			if turn_index % 7 == 3:
				assert_bool(scheduler.interrupt(&"stress_test")["allowed"]).is_true()
				assert_str(String(scheduler.advance()["blocked_by"])).is_equal("interrupted")
				scheduler.resume()
				assert_object(scheduler.active_actor()).is_equal(actor)
			observed_order.append(actor.combat_id)
			turn_counts[actor.combat_id] = int(turn_counts.get(actor.combat_id, 0)) + 1
			assert_bool(scheduler.commit(actor, action)["allowed"]).is_true()
			scheduler.release(actor)
		for actor in actors:
			assert_int(int(turn_counts.get(actor.combat_id, 0))).is_equal(6)
		for offset in range(0, observed_order.size(), actors.size()):
			var cycle := observed_order.slice(offset, offset + actors.size())
			assert_int(cycle.size()).is_equal(actors.size())
			var unique_in_cycle: Dictionary = {}
			for combat_id in cycle:
				unique_in_cycle[combat_id] = true
			assert_int(unique_in_cycle.size()).is_equal(actors.size())
		if battle_index == 0:
			reference_order = observed_order.duplicate()
		else:
			assert_array(observed_order).is_equal(reference_order)
