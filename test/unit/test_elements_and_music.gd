extends GdUnitTestSuite

const Resolver := preload("res://globals/elements/composition_resolver.gd")
const Result := preload("res://globals/elements/composition_result.gd")
const Data := preload("res://globals/elements/elements_data.gd")
const Wheel := preload("res://globals/elements/element_wheel.gd")


func test_every_triad_resolves_with_center_amplified_imposition_all_bends_and_effect() -> void:
	for triad in Data.all_triads():
		var result: CompositionResult = Resolver.resolve(triad.elements, &"song")

		assert_int(result.kind).is_equal(Result.Kind.TRIAD)
		assert_str(result.center_element).is_equal(triad.center_element)
		assert_str(result.imposition_strength).is_equal("amplified")
		assert_str(result.unique_effect_id).is_equal(triad.unique_effect_id)
		assert_int(result.rule_bends.size()).is_equal(3)
		for element_id in triad.elements:
			assert_bool(result.rule_bends.has(Data.element(element_id).rule_bend_id)).is_true()


func test_strained_chords_at_two_three_and_four_steps_weaken_both_and_cost_distance() -> void:
	var cases := [
		{"first": &"sul", "second": &"luth", "distance": 2},
		{"first": &"vel", "second": &"tham", "distance": 3},
		{"first": &"sul", "second": &"tham", "distance": 4},
	]
	for test_case: Dictionary in cases:
		var span: int = test_case["distance"]
		var result: CompositionResult = Resolver.resolve(
			[test_case["first"], test_case["second"]], &"phrase"
		)

		assert_int(result.kind).is_equal(Result.Kind.STRAINED_CHORD)
		assert_int(result.distance_steps).is_equal(span)
		assert_int(result.var_cost).is_equal(span)
		assert_str(result.imposition_strength).is_equal("weakened")
		assert_int(result.impositions.size()).is_equal(2)
		for entry: Dictionary in result.imposition_entries:
			assert_str(entry["strength"]).is_equal("weakened")


func test_wider_three_element_span_is_clash_self_discord_without_fizzle() -> void:
	var result: CompositionResult = Resolver.resolve([&"sul", &"luth", &"tham"], &"note")

	assert_bool(result.is_clash()).is_true()
	assert_bool(result.self_inflicted_discord).is_true()
	assert_bool(result.fizzle_requested).is_false()
	assert_str(result.failure_id).is_equal("span_exceeds_two")


func test_opposed_elements_are_rejected() -> void:
	var result: CompositionResult = Resolver.resolve([&"sul", &"vekh"], &"note")

	assert_bool(result.is_opposed()).is_true()
	assert_bool(result.rejected).is_true()
	assert_bool(result.fizzle_requested).is_false()
	assert_str(result.failure_id).is_equal("opposed_elements")


func test_tone_has_one_imposition_and_one_rule_bend() -> void:
	var result: CompositionResult = Resolver.resolve([&"sul"], &"note")

	assert_int(result.kind).is_equal(Result.Kind.TONE)
	assert_int(result.impositions.size()).is_equal(1)
	assert_int(result.rule_bends.size()).is_equal(1)


func test_chord_has_one_full_imposition_and_two_rule_bends_with_caster_choice() -> void:
	var result: CompositionResult = Resolver.resolve(
		[&"sul", &"vel"], &"phrase", {"imposition_element": &"vel"}
	)

	assert_int(result.kind).is_equal(Result.Kind.CHORD)
	assert_int(result.impositions.size()).is_equal(1)
	assert_str(result.impositions[0]).is_equal("overgrown")
	assert_int(result.rule_bends.size()).is_equal(2)


func test_khor_and_zhem_never_produce_damage_components() -> void:
	for element_id in [&"khor", &"zhem"]:
		var tone: CompositionResult = Resolver.resolve([element_id], &"note")
		assert_int(tone.damage_components.size()).is_equal(0)

	for triad in Data.all_triads():
		if triad.center_element == &"khor" or triad.center_element == &"zhem":
			var result: CompositionResult = Resolver.resolve(triad.elements, &"song")
			assert_int(result.damage_components.size()).is_equal(0)


func test_each_element_rules_one_triad_and_wings_two() -> void:
	var triads := Data.all_triads()
	assert_int(triads.size()).is_equal(10)
	for element in Data.all_elements():
		var rules := 0
		var wings := 0
		for triad in triads:
			if triad.center_element == element.id:
				rules += 1
			elif triad.contains_element(element.id):
				wings += 1
		assert_int(rules).is_equal(1)
		assert_int(wings).is_equal(2)
