extends GdUnitTestSuite

const TEST_FLAG := "flag_coercion_test"

var original_flags: Dictionary


func before_test() -> void:
	original_flags = GameState.flags.duplicate(true)
	GameState.flags.clear()


func after_test() -> void:
	GameState.flags = original_flags


func test_flag_is_true_coercion_matrix() -> void:
	var cases: Array[Dictionary] = [
		{"value": true, "expected": true, "label": "boolean true"},
		{"value": false, "expected": false, "label": "boolean false"},
		{"value": "true", "expected": true, "label": "lowercase true"},
		{"value": " TRUE ", "expected": true, "label": "trimmed uppercase true"},
		{"value": "1", "expected": true, "label": "numeric true string"},
		{"value": "yes", "expected": true, "label": "yes string"},
		{"value": "On", "expected": true, "label": "mixed-case on string"},
		{"value": "false", "expected": false, "label": "false string"},
		{"value": " FALSE ", "expected": false, "label": "trimmed uppercase false"},
		{"value": "0", "expected": false, "label": "numeric false string"},
		{"value": "no", "expected": false, "label": "no string"},
		{"value": "off", "expected": false, "label": "off string"},
		{"value": "", "expected": false, "label": "empty string"},
		{"value": "   ", "expected": false, "label": "whitespace string"},
		{"value": "enabled", "expected": true, "label": "other non-empty string"},
		{"value": &"yes", "expected": true, "label": "true StringName"},
		{"value": &"off", "expected": false, "label": "false StringName"},
		{"value": 1, "expected": true, "label": "positive integer"},
		{"value": -1, "expected": true, "label": "negative integer"},
		{"value": 0, "expected": false, "label": "zero integer"},
		{"value": 0.5, "expected": true, "label": "non-zero float"},
		{"value": 0.0, "expected": false, "label": "zero float"},
		{"value": null, "expected": false, "label": "null"},
		{"value": [], "expected": false, "label": "array"},
		{"value": {}, "expected": false, "label": "dictionary"},
	]

	for test_case: Dictionary in cases:
		GameState.flags.erase(TEST_FLAG)
		GameState.set_flag(TEST_FLAG, test_case["value"])
		assert_bool(GameState.flag_is_true(TEST_FLAG)).override_failure_message(
			"Unexpected coercion for %s" % test_case["label"]
		).is_equal(test_case["expected"])


func test_flag_is_true_returns_false_for_a_missing_flag() -> void:
	assert_bool(GameState.flag_is_true("missing_flag")).is_false()


func test_flag_is_true_does_not_change_stored_values() -> void:
	GameState.set_flag(TEST_FLAG, "yes")

	assert_bool(GameState.flag_is_true(TEST_FLAG)).is_true()
	assert_str(GameState.get_flag(TEST_FLAG)).is_equal("yes")
