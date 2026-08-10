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
