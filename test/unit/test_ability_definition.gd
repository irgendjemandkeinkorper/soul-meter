extends GdUnitTestSuite


func test_casting_fields_round_trip_without_losing_typed_element_ids() -> void:
	var source := AbilityDefinition.new()
	source.id = "test-cast"
	source.display_name = "Test Cast"
	source.job_id = "test-job"
	source.element_id = &"strom"
	source.elements = [&"strom", &"suul"]
	source.magnitude = &"phrase"
	source.power = 17
	source.breath_cost = 3
	source.ct_cost = 40
	source.range = 4
	source.aoe = 1
	source.vertical = 2

	var restored := AbilityDefinition.from_dict(source.to_dict())

	assert_str(restored.id).is_equal(source.id)
	assert_array(restored.elements).contains_exactly([&"strom", &"suul"])
	assert_str(String(restored.magnitude)).is_equal("phrase")
	assert_int(restored.breath_cost).is_equal(3)
	assert_bool(restored.to_dict() == source.to_dict()).is_true()


func test_legacy_mp_cost_is_read_as_breath_cost() -> void:
	var restored := AbilityDefinition.from_dict({"id": "legacy-cast", "mp_cost": 4})

	assert_int(restored.breath_cost).is_equal(4)
	assert_int(restored.mp_cost).is_equal(4)
