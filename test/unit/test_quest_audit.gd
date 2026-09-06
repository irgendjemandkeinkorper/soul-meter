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


func test_quest_critical_ids_cover_tres_givers_and_dialogue_offer_stems() -> void:
	var ids := QuestAuditScript.quest_critical_npc_ids()
	# giver_actor_id path: every authored Dom side quest names one.
	assert_array(ids).contains(["hadrik-vale", "vaara-cisternhand"])
	# dialogue-offer path: sella_varn.dialogue calls QuestRegistry.offer().
	assert_array(ids).contains(["sella-varn"])


func test_phase_reachability_passes_routined_and_unrouted_shipped_npcs() -> void:
	# Shipped content must hold the FR-905 floor: no quest-critical NPC with a
	# routine may be present in fewer than two phases.
	var violations := QuestAuditScript.phase_reachability_violations(
		QuestAuditScript.quest_critical_npc_ids()
	)
	assert_array(violations).is_empty()


func test_phase_reachability_flags_a_single_phase_quest_critical_npc() -> void:
	# No shipped NPC violates, so prove the detector on the rule itself: any id
	# WITHOUT a routine is phase-agnostic and passes; a routined id fails only
	# below two present phases. sella-varn is routined with 3 present phases.
	assert_array(
		QuestAuditScript.phase_reachability_violations(PackedStringArray(["no-such-npc"]))
	).is_empty()
	assert_int(NpcRoutines.present_phase_count("sella-varn")).is_greater_equal(2)


func test_report_carries_a_phase_reachability_category_and_metric() -> void:
	var quest_results: Array[Dictionary] = []
	var flags := QuestAuditScript.scan_flag_sources(PackedStringArray([FLAG_FIXTURE]))
	var report := QuestAuditScript.build_report(
		quest_results,
		flags,
		false,
		PackedStringArray(),
		PackedStringArray(["sella-varn", "branek-coiljaw"])
	)

	assert_bool(report["categories"].has("phase_reachability")).is_true()
	assert_int(report["metrics"]["phase_reachability"]["quest_critical_npcs"]).is_equal(2)
	assert_int(report["metrics"]["phase_reachability"]["routined"]).is_equal(1)
	assert_bool(report["metrics"]["phase_reachability"]["passes"]).is_true()


func test_report_contains_read_back_coverage_section() -> void:
	var report := QuestAuditScript.audit_project(false)
	assert_bool(report.has("read_back_coverage")).is_true()
	var coverage: Array = report["read_back_coverage"]
	assert_bool(coverage.is_empty()).is_false()
	var first_quest: Dictionary = coverage[0]
	assert_bool(first_quest.has("quest_id")).is_true()
	assert_bool(first_quest.has("quest_name")).is_true()
	assert_bool(first_quest.has("kind")).is_true()
	assert_bool(first_quest.has("outcomes")).is_true()
	assert_bool(first_quest.has("flags_written")).is_true()
	assert_bool(first_quest.has("read_backs")).is_true()


func test_coverage_outcomes_agree_with_classified_readback_metrics() -> void:
	var report := QuestAuditScript.audit_project(false)
	var counts := {"main": 0, "side": 0}
	for quest: Dictionary in report["read_back_coverage"]:
		for outcome: Dictionary in quest["outcomes"]:
			if outcome["read_back"]:
				counts[quest["kind"]] += 1
	for kind: String in counts:
		assert_int(counts[kind]).is_equal(report["metrics"]["readbacks"][kind]["read"])


func test_read_back_coverage_categorizes_locations() -> void:
	var quest_results: Array[Dictionary] = [
		{
			"quest_id": "bellhouse_repair",
			"quest_name": "The Bell That Won't Ring",
			"constant": "BELLHOUSE_REPAIR",
			"kind": "side",
			"outcomes": [
				{
					"id": "heard-the-silence",
					"readback_flag": "dom_bellhouse_inspected",
					"state_writes": ["dom_bellhouse_inspected=true"],
					"read_back": true,
				}
			]
		}
	]
	var dialogue_sources := {
		"res://dialogue/sella_varn.dialogue": '- "Inspected." [if GameState.get_flag("dom_bellhouse_inspected") /]'
	}
	var sources := dialogue_sources.duplicate()
	sources["res://quests/bellhouse_repair.tres"] = 'required_flags = PackedStringArray("dom_bellhouse_inspected")'
	sources["res://globals/npc_reactions.gd"] = """const REACTIONS: Dictionary = {
	"sella-varn": [
		{
			"flag": "dom_bellhouse_inspected",
		},
	],
}"""

	var coverage := QuestAuditScript._build_read_back_coverage(quest_results, sources, dialogue_sources)
	assert_int(coverage.size()).is_equal(1)
	var quest_cov: Dictionary = coverage[0]
	assert_str(quest_cov["quest_id"]).is_equal("bellhouse_repair")
	assert_array(quest_cov["flags_written"]).contains_exactly(["dom_bellhouse_inspected"])

	var read_backs: Array = quest_cov["read_backs"]
	assert_int(read_backs.size()).is_equal(1)
	var flag_rb: Dictionary = read_backs[0]
	assert_str(flag_rb["flag"]).is_equal("dom_bellhouse_inspected")
	assert_bool(flag_rb["read_back"]).is_true()
	assert_bool("res://dialogue/sella_varn.dialogue:1" in flag_rb["dialogue_conditions"]).is_true()
	assert_bool("NpcReactions:sella-varn" in flag_rb["reaction_rows"]).is_true()
	assert_bool("res://quests/bellhouse_repair.tres:1" in flag_rb["encounter_gates"]).is_true()


func _outcome(outcome_id: String, writes_state: bool, read_back: bool) -> Dictionary:
	return {
		"id": outcome_id,
		"state_writes": (["resolution=%s" % outcome_id] if writes_state else []),
		"ledger_events": [],
		"read_back": read_back,
	}
