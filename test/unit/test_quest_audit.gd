extends GdUnitTestSuite

const QuestAuditScript := preload("res://tools/quest_audit.gd")
const FLAG_FIXTURE := "res://test/fixtures/quest_audit/flags.dialogue"


func test_classification_counts_only_genuinely_distinct_outcomes() -> void:
	var outcomes: Array[Dictionary] = [
		{
			"id": "keep",
			"state_writes": ["decision=keep"],
			"ledger_events": ["faction-a:+5"],
		},
		{
			"id": "keep-copy",
			"state_writes": ["decision=keep"],
			"ledger_events": ["faction-a:+5"],
		},
		{
			"id": "change",
			"state_writes": ["decision=change"],
			"ledger_events": ["faction-b:+5"],
		},
	]

	assert_int(QuestAuditScript.distinct_outcome_count(outcomes)).is_equal(2)
	assert_bool(QuestAuditScript.has_enough_outcomes(outcomes)).is_true()
	assert_bool(QuestAuditScript.has_enough_outcomes(outcomes.slice(0, 2))).is_false()


func test_side_readback_threshold_includes_exact_sixty_percent_boundary() -> void:
	assert_bool(QuestAuditScript.meets_readback_threshold(3, 5)).is_true()
	assert_bool(QuestAuditScript.meets_readback_threshold(6, 10)).is_true()
	assert_bool(QuestAuditScript.meets_readback_threshold(2, 4)).is_false()
	assert_bool(QuestAuditScript.meets_readback_threshold(0, 0)).is_false()


func test_report_has_categories_metrics_and_severity_split() -> void:
	var quest_results: Array[Dictionary] = [
		{
			"quest_id": "main-quest",
			"quest_name": "Main Quest",
			"kind": "main",
			"outcomes": [
				_outcome("first", true, true),
				_outcome("second", true, true),
			],
		},
		{
			"quest_id": "side-quest",
			"quest_name": "Side Quest",
			"kind": "side",
			"outcomes": [_outcome("only", false, false)],
		},
	]
	var flags := QuestAuditScript.scan_flag_sources(PackedStringArray([FLAG_FIXTURE]))
	var report := QuestAuditScript.build_report(quest_results, flags, false)

	assert_str(report["schema"]).is_equal("soul_meter.quest_audit.v1")
	assert_str(report["mode"]).is_equal("reporting")
	assert_int(report["summary"]["quest_count"]).is_equal(2)
	assert_int(report["summary"]["resolution_count"]).is_equal(3)
	assert_bool(report["categories"].has("outcome_count")).is_true()
	assert_bool(report["categories"].has("resolution_writes")).is_true()
	assert_bool(report["categories"].has("readbacks")).is_true()
	assert_bool(report["categories"].has("orphaned_flags")).is_true()
	assert_int(report["categories"]["outcome_count"]["count"]).is_equal(1)
	assert_int(report["categories"]["resolution_writes"]["count"]).is_equal(1)
	assert_int(report["metrics"]["readbacks"]["main"]["read"] ).is_equal(2)
	assert_int(report["metrics"]["readbacks"]["side"]["total"]).is_equal(1)
	assert_array(flags["written_never_read"]).contains_exactly(["write_only"])
	assert_array(flags["read_never_written"]).contains_exactly(["read_only"])
	assert_bool(report["summary"]["severity"].has("error")).is_true()
	assert_bool(report["summary"]["severity"].has("warning")).is_true()
	assert_bool(report["summary"]["severity"].has("info")).is_true()


func test_exit_code_is_zero_by_default_and_nonzero_only_for_strict_findings() -> void:
	var finding_report := {
		"summary": {"severity": {"error": 0, "warning": 1, "info": 0}}
	}
	var clean_report := {
		"summary": {"severity": {"error": 0, "warning": 0, "info": 0}}
	}

	assert_int(QuestAuditScript.exit_code_for_report(finding_report, false)).is_equal(0)
	assert_int(QuestAuditScript.exit_code_for_report(finding_report, true)).is_equal(1)
	assert_int(QuestAuditScript.exit_code_for_report(clean_report, true)).is_equal(0)
	assert_bool(QuestAuditScript.strict_mode_from_value("1")).is_true()
	assert_bool(QuestAuditScript.strict_mode_from_value("0")).is_false()
	assert_bool(QuestAuditScript.strict_mode_from_value("true")).is_false()


func _outcome(outcome_id: String, writes_state: bool, read_back: bool) -> Dictionary:
	return {
		"id": outcome_id,
		"state_writes": (["resolution=%s" % outcome_id] if writes_state else []),
		"ledger_events": [],
		"read_back": read_back,
	}
