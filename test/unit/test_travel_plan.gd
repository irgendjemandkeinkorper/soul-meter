extends GdUnitTestSuite


func _plan_for(state: TravelPlan.State) -> TravelPlan:
	var plan := TravelPlan.new()
	plan.origin_id = &"dom"
	plan.destination_id = &"dorthkor-road"
	plan.progress_step = 4
	plan.total_steps = 12
	plan.elapsed_phases = 1
	plan.rng_seed = 938475
	plan.state = state
	plan.encounter_schedule = [
		{
			"at_step": 3,
			"encounter_id": &"loam-boar",
			"resolved": true,
			"spoils_granted": true,
		},
		{
			"at_step": 9,
			"encounter_id": &"dorthkor-vanguard",
			"resolved": false,
			"spoils_granted": false,
		},
	]
	return plan


func test_dictionary_round_trip_preserves_every_journey_state() -> void:
	var states: Array[TravelPlan.State] = [
		TravelPlan.State.EN_ROUTE,
		TravelPlan.State.AVOID_PROMPT,
		TravelPlan.State.IN_BATTLE,
		TravelPlan.State.ARRIVED,
		TravelPlan.State.CANCELLED,
	]
	for state: TravelPlan.State in states:
		var original := _plan_for(state)
		var restored := TravelPlan.from_dict(original.to_dict())
		assert_dict(restored.to_dict()).is_equal(original.to_dict())


func test_from_dict_ignores_unknown_keys() -> void:
	var saved := _plan_for(TravelPlan.State.AVOID_PROMPT).to_dict()
	saved["future_top_level_field"] = {"preserve": "nothing"}
	var raw_schedule: Array = saved["encounter_schedule"]
	raw_schedule[0]["future_slot_field"] = 99

	var restored := TravelPlan.from_dict(saved)
	assert_bool(restored.to_dict().has("future_top_level_field")).is_false()
	assert_bool(restored.encounter_schedule[0].has("future_slot_field")).is_false()
	assert_int(int(restored.state)).is_equal(TravelPlan.State.AVOID_PROMPT)
