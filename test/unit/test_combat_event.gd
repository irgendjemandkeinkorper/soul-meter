extends GdUnitTestSuite

func test_to_dict_contains_fields_and_deep_copies_data() -> void:
	var event := CombatEvent.new()
	event.sequence = 7
	event.type = &"damage"
	event.actor_id = &"iris"
	event.target_id = &"wight"
	event.data = {"hits": [{"amount": 3}]}
	var result := event.to_dict()
	assert_int(result["sequence"]).is_equal(7)
	assert_str(String(result["type"])).is_equal("damage")
	assert_dict(result["data"]).is_equal({"hits": [{"amount": 3}]})
	result["data"]["hits"][0]["amount"] = 99
	assert_int(event.data["hits"][0]["amount"]).is_equal(3)
