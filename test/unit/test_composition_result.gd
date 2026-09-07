extends GdUnitTestSuite

func test_kind_predicates_distinguish_resolved_clash_and_opposed() -> void:
	var result := CompositionResult.new()
	assert_bool(result.is_resolved()).is_false()
	result.kind = CompositionResult.Kind.CHORD
	assert_bool(result.is_resolved()).is_true()
	assert_bool(result.is_castable()).is_true()
	result.allowed = false
	assert_bool(result.is_castable()).is_false()
	result.kind = CompositionResult.Kind.CLASH
	assert_bool(result.is_clash()).is_true()
	result.kind = CompositionResult.Kind.OPPOSED
	assert_bool(result.is_opposed()).is_true()

func test_to_dict_deep_copies_nested_payloads() -> void:
	var result := CompositionResult.new()
	result.kind = CompositionResult.Kind.TRIAD
	result.elements = [&"sul"]
	result.imposition_entries = [{"parameters": {"power": 2}}]
	result.nearest_unblock = {"nested": {"minimum": 2}}
	var serialized := result.to_dict()
	serialized["imposition_entries"][0]["parameters"]["power"] = 9
	serialized["nearest_unblock"]["nested"]["minimum"] = 8
	assert_int(result.imposition_entries[0]["parameters"]["power"]).is_equal(2)
	assert_int(result.nearest_unblock["nested"]["minimum"]).is_equal(2)
