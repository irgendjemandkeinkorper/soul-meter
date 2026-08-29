extends GdUnitTestSuite


func _route() -> Dictionary:
	return {
		"steps": 12,
		"min_encounters": 2,
		"max_encounters": 4,
		"risk_modifier": 10.0,
		"encounter_table": [
			{"encounter_id": &"bog-wight", "weight": 2},
			{"encounter_id": &"loam-boar", "weight": 1},
		],
	}


func _member(anchor: float, bonus: float = 0.0) -> PartyMember:
	var member := PartyMember.new()
	member.id = "travel-test-member"
	member.attributes = {"anchor": anchor}
	member.skill_percentages = {"survival": bonus}
	member.skill_tiers = {"survival": "untrained"}
	return member


func test_same_route_and_seed_produce_identical_schedule() -> void:
	var first: Array[Dictionary] = EncounterDirector.build_schedule(_route(), 84521)
	var second: Array[Dictionary] = EncounterDirector.build_schedule(_route(), 84521)
	assert_array(first).is_equal(second)


func test_different_seeds_vary_the_schedule() -> void:
	var signatures: Dictionary = {}
	for seed: int in range(32):
		var schedule: Array[Dictionary] = EncounterDirector.build_schedule(_route(), seed)
		signatures[JSON.stringify(schedule)] = true
	assert_int(signatures.size()).is_greater(1)


func test_schedule_respects_cadence_and_uses_distinct_steps_over_many_seeds() -> void:
	var route := _route()
	for seed: int in range(256):
		var schedule: Array[Dictionary] = EncounterDirector.build_schedule(route, seed)
		assert_int(schedule.size()).is_greater_equal(int(route["min_encounters"]))
		assert_int(schedule.size()).is_less_equal(int(route["max_encounters"]))
		var seen_steps: Dictionary = {}
		for slot: Dictionary in schedule:
			var at_step := int(slot["at_step"])
			assert_bool(seen_steps.has(at_step)).is_false()
			seen_steps[at_step] = true
			assert_bool(bool(slot["resolved"])).is_false()
			assert_bool(bool(slot["spoils_granted"])).is_false()


func test_avoidance_uses_best_party_member_and_caps_before_risk() -> void:
	var party: Array[PartyMember] = [_member(3.0), _member(20.0, 100.0)]
	var route := {"risk_modifier": 10.0}
	assert_float(EncounterDirector.avoidance_chance(route, party)).is_equal_approx(85.0, 0.001)


func test_avoidance_is_floored_at_zero() -> void:
	var party: Array[PartyMember] = [_member(1.0)]
	var route := {"risk_modifier": 40.0}
	assert_float(EncounterDirector.avoidance_chance(route, party)).is_equal_approx(0.0, 0.001)
