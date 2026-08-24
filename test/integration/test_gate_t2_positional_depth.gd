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


## SKIPPED pending the #169 human ruling of 2026-08-24: a to-hit system (ratified) must be
## built and the unchanged harness rerun ONCE. If that rerun still fails, the grid was the
## wrong trade (amendment §5) — do not un-skip without the rerun evidence on #169.
func test_positional_policy_wins_where_ablated_policy_loses(
	do_skip := true,
	skip_reason := "Gate T-2 red pending #169 to-hit rerun — see issue for the ruling"
) -> void:
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
