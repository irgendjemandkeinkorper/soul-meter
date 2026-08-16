extends GdUnitTestSuite

const HARNESS_PATH := "res://tools/gate_t2_positional_depth.gd"


func test_comparison_is_byte_deterministic_for_the_registered_seed() -> void:
	var harness_script: Script = load(HARNESS_PATH) as Script
	assert_object(harness_script).is_not_null()
	if harness_script == null:
		return

	var first: Dictionary = harness_script.call("run_comparison")
	var second: Dictionary = harness_script.call("run_comparison")
	assert_str(JSON.stringify(first)).is_equal(JSON.stringify(second))


func test_positional_policy_wins_where_ablated_policy_loses() -> void:
	var harness_script: Script = load(HARNESS_PATH) as Script
	assert_object(harness_script).is_not_null()
	if harness_script == null:
		return

	var comparison: Dictionary = harness_script.call("run_comparison")
	var positional: Dictionary = comparison.get("positional", {})
	var naive: Dictionary = comparison.get("naive", {})

	assert_str(str(positional.get("outcome", ""))).is_equal("victory")
	assert_str(str(naive.get("outcome", ""))).is_equal("defeat")
	assert_bool(bool(comparison.get("passed", false))).is_true()
