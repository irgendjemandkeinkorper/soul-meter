extends GdUnitTestSuite

func test_from_row_normalizes_values_and_copies_effect_parameters() -> void:
	var definition := TriadDefinition.from_row({
		"id": "Dawn",
		"display_name": "Dawn Triad",
		"elements": ["SUUL", "AQUA"],
		"center": "AQUA",
		"unique_effect": {"id": "heal", "display_name": "Healing", "parameters": {"amount": 3}},
	})
	assert_str(String(definition.id)).is_equal("dawn")
	assert_str(String(definition.center)).is_equal("aqua")
	assert_bool(definition.contains_element(&"suul")).is_true()
	assert_bool(definition.contains_element(&"terra")).is_false()
	var serialized := definition.to_dict()
	serialized["unique_effect"]["parameters"]["amount"] = 9
	assert_int(definition.unique_effect_parameters["amount"]).is_equal(3)

func test_missing_or_malformed_optional_fields_use_empty_defaults() -> void:
	var definition := TriadDefinition.from_row({"id": 12, "elements": "not-an-array", "unique_effect": []})
	assert_str(String(definition.id)).is_equal("12")
	assert_str(definition.display_name).is_equal("12")
	assert_array(definition.elements).is_empty()
	assert_str(String(definition.unique_effect_id)).is_equal("")
