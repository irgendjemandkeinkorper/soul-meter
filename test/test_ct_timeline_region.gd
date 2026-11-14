extends GdUnitTestSuite


func test_timeline_reads_scheduler_forecast_instead_of_estimating() -> void:
	var runner := scene_runner("res://ui/hud/regions/ct_timeline/ct_timeline_region.tscn")
	var timeline := runner.scene() as CTTimelineRegion
	var actor := BattleActor.new()
	actor.combat_id = &"vex"
	actor.display_name = "Vex"
	var rules := CombatRules.new()
	rules.use_charge_time = true
	var scheduler := TurnScheduler.create_default(rules)
	scheduler.setup([actor])
	timeline.bind_scheduler(scheduler)
	assert_int(timeline.marker_count()).is_greater(0)
	assert_str(timeline.marker_text(0)).contains("Vex")
	assert_int(scheduler.peek_order(8).size()).is_equal(timeline.marker_count())
