extends GdUnitTestSuite
## Gate T-2 CLOSED as PASSED (#169, owner verdicts 2026-08-24) under the final
## owner-amended threshold — see the harness header and docs/gate-t2-evidence.md.
##
## Both assertions run against SUBPROCESS invocations of the canonical harness, not
## in-process calls: the harness is byte-deterministic in a fresh process (the gate's
## actual evidence standard), but in-process runs after certain suite combinations
## drift by single hit-rolls via ambient engine state that GameState snapshots do not
## reach (documented in docs/gate-t2-evidence.md — root cause unidentified, contained
## here). Judged on stdout JSON, never on exit codes (headless teardown aborts).

const HARNESS_PATH := "res://tools/gate_t2_positional_depth.gd"


func test_harness_is_byte_deterministic_and_meets_the_amended_threshold() -> void:
	var first := _run_harness_subprocess()
	var second := _run_harness_subprocess()
	assert_str(first).is_not_empty()
	assert_str(first).is_equal(second)

	var parsed: Variant = JSON.parse_string(first)
	assert_bool(parsed is Dictionary).is_true()
	var comparison: Dictionary = parsed
	var positional: Dictionary = comparison.get("positional", {})
	var naive: Dictionary = comparison.get("naive", {})
	assert_str(str(positional.get("outcome", ""))).is_equal("victory")
	assert_int(int(positional.get("party_survivors", 0))).is_equal(2)
	assert_int(int(naive.get("party_survivors", 0))).is_less(2)
	assert_bool(bool(comparison.get("passed", false))).is_true()


func _run_harness_subprocess() -> String:
	var output := []
	OS.execute(
		OS.get_executable_path(),
		[
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", HARNESS_PATH,
		],
		output,
		true,
	)
	var combined := "\n".join(PackedStringArray(output))
	for line in combined.split("\n"):
		if line.begins_with("{"):
			return line.strip_edges()
	return ""
