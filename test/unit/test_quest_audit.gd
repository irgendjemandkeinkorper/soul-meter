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


func test_flag_grammar_splits_domain_optional_subject_and_predicate() -> void:
	var full: Dictionary = QuestAuditScript.split_flag("dom_dishonest_casks_resolution")
	assert_str(full["domain"]).is_equal("dom")
	assert_str(full["subject"]).is_equal("dishonest_casks")
	assert_str(full["predicate"]).is_equal("resolution")

	# The subject is optional: shipped content uses both shapes.
	var short: Dictionary = QuestAuditScript.split_flag("field_debt_open")
	assert_str(short["domain"]).is_equal("field_debt")
	assert_str(short["subject"]).is_equal("")
	assert_str(short["predicate"]).is_equal("open")

	# Longest domain wins, so `deep_trial` is not mistaken for a shorter prefix.
	assert_str(
		str(QuestAuditScript.split_flag("deep_trial_resolution")["domain"])
	).is_equal("deep_trial")

	# No registered domain means no split.
	assert_bool(QuestAuditScript.split_flag("wibble_thing_done").is_empty()).is_true()


func test_flag_grammar_flags_unregistered_domains_and_wrong_case() -> void:
	var violations: Array[Dictionary] = QuestAuditScript.flag_grammar_violations(
		PackedStringArray(
			[
				"dom_shrine_visited",
				"field_debt_open",
				"wibble_thing_done",
				"Dom_Shrine_Visited",
				"dom.shrine.visited",
			]
		)
	)
	var flagged := PackedStringArray()
	for violation: Dictionary in violations:
		flagged.append(str(violation["flag"]))

	assert_int(violations.size()).is_equal(3)
	assert_bool(flagged.has("wibble_thing_done")).is_true()
	assert_bool(flagged.has("Dom_Shrine_Visited")).is_true()
	assert_bool(flagged.has("dom.shrine.visited")).is_true()
	assert_bool(flagged.has("dom_shrine_visited")).is_false()
	assert_bool(flagged.has("field_debt_open")).is_false()


func test_flag_grammar_exempts_legacy_flags_and_format_string_artifacts() -> void:
	# A shipped flag id is permanent; renaming one is a save migration.
	var legacy: Array[Dictionary] = QuestAuditScript.flag_grammar_violations(
		PackedStringArray(["reported_bloodbellow", "defeated_bog_wight"])
	)
	assert_int(legacy.size()).is_equal(0)

	# Limitation 2: a format-string flag is a scanner artifact, not content debt.
	var artifact: Array[Dictionary] = QuestAuditScript.flag_grammar_violations(
		PackedStringArray(["quest_%d_resolution"])
	)
	assert_int(artifact.size()).is_equal(0)


func test_report_carries_a_flag_grammar_category_and_metric() -> void:
	var quest_results: Array[Dictionary] = []
	var flags := QuestAuditScript.scan_flag_sources(PackedStringArray([FLAG_FIXTURE]))
	var report := QuestAuditScript.build_report(
		quest_results, flags, false, PackedStringArray(["dom_shrine_visited", "wibble_thing_done"])
	)

	assert_bool(report["categories"].has("flag_grammar")).is_true()
	assert_int(report["categories"]["flag_grammar"]["count"]).is_equal(1)
	assert_int(report["metrics"]["flag_grammar"]["scanned"]).is_equal(2)
	assert_int(report["metrics"]["flag_grammar"]["violations"]).is_equal(1)
	assert_bool(report["metrics"]["flag_grammar"]["passes"]).is_false()


func _outcome(outcome_id: String, writes_state: bool, read_back: bool) -> Dictionary:
	return {
		"id": outcome_id,
		"state_writes": (["resolution=%s" % outcome_id] if writes_state else []),
		"ledger_events": [],
		"read_back": read_back,
	}
