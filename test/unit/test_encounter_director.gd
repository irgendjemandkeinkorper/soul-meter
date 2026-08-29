extends GdUnitTestSuite

var _reputation_before: Dictionary


func before_test() -> void:
	_reputation_before = Reputation.to_dict()
	_set_iron_companies_band(&"neutral")


func after_test() -> void:
	Reputation.from_dict(_reputation_before)


func _route() -> Dictionary:
	return {
		"steps": 12,
		"min_encounters": 2,
		"max_encounters": 4,
		"risk_modifier": 10.0,
		"encounter_table": [
			{"encounter_id": &"bog-wight", "weight": 2},
			{"encounter_id": &"loam-boar", "weight": 1},
			{"encounter_id": &"dorthkor-vanguard", "weight": 1},
		],
	}


func _route_with_band_weights() -> Dictionary:
	var route: Dictionary = _route()
	route["band_encounter_weights"] = {
		"faction_id": &"iron-companies",
		"bands": {
			&"hostile": {&"dorthkor-vanguard": 3},
			&"cold": {&"dorthkor-vanguard": 2},
			&"warm": {&"dorthkor-vanguard": 1},
			&"allied": {&"dorthkor-vanguard": 0},
		},
	}
	return route


func _set_iron_companies_band(band: StringName) -> void:
	var delta := 0.0
	match band:
		&"hostile":
			delta = Reputation.BAND_HOSTILE
		&"cold":
			delta = Reputation.BAND_COLD
		&"warm":
			delta = Reputation.BAND_WARM
		&"allied":
			delta = Reputation.BAND_ALLIED
	var log: Array[Dictionary] = []
	if not is_zero_approx(delta):
		log.append({
			"actor": "test",
			"faction": "iron-companies",
			"delta": delta,
			"cause": "Test band setup",
			"scene": "test",
			"at": 0,
			"order": 0,
		})
	Reputation.from_dict({"log": log, "next_order": log.size()})


func _weight_for(table: Array[Dictionary], encounter_id: StringName) -> int:
	for entry: Dictionary in table:
		if StringName(entry["encounter_id"]) == encounter_id:
			return int(entry["weight"])
	return 0


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


func test_band_overrides_apply_current_iron_companies_weight() -> void:
	var expected_weights := {
		&"hostile": 3,
		&"cold": 2,
		&"warm": 1,
		&"allied": 0,
	}
	for band: StringName in expected_weights:
		_set_iron_companies_band(band)
		var table: Array[Dictionary] = EncounterDirector._encounter_table_for_route(
			_route_with_band_weights()
		)
		assert_int(_weight_for(table, &"dorthkor-vanguard")).is_equal(
			int(expected_weights[band])
		)


func test_route_without_band_weights_is_identical_across_reputation_bands() -> void:
	_set_iron_companies_band(&"hostile")
	var hostile_schedule: Array[Dictionary] = EncounterDirector.build_schedule(_route(), 62140)
	_set_iron_companies_band(&"allied")
	var allied_schedule: Array[Dictionary] = EncounterDirector.build_schedule(_route(), 62140)
	assert_array(hostile_schedule).is_equal(allied_schedule)


func test_neutral_band_weights_preserve_the_unconfigured_schedule() -> void:
	_set_iron_companies_band(&"neutral")
	var unconfigured: Array[Dictionary] = EncounterDirector.build_schedule(_route(), 19407)
	var configured: Array[Dictionary] = EncounterDirector.build_schedule(
		_route_with_band_weights(), 19407
	)
	assert_array(configured).is_equal(unconfigured)


func test_band_aware_schedule_remains_deterministic() -> void:
	_set_iron_companies_band(&"hostile")
	var first: Array[Dictionary] = EncounterDirector.build_schedule(
		_route_with_band_weights(), 84521
	)
	var second: Array[Dictionary] = EncounterDirector.build_schedule(
		_route_with_band_weights(), 84521
	)
	assert_array(first).is_equal(second)


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
