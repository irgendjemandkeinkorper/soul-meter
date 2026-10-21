extends GdUnitTestSuite

const QuestAuditScript := preload("res://tools/quest_audit.gd")
const FLAG_FIXTURE := "res://test/fixtures/quest_audit/flags.dialogue"


func test_standalone_cli_audit_has_zero_error_findings() -> void:
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		[
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tools/quest_audit.gd",
		],
		output,
		true
	)
	var combined := "\n".join(PackedStringArray(output))
	var report_start := combined.find("{")
	var report_end := combined.rfind("}")
	assert_int(exit_code).is_equal(0)
	assert_str(combined).not_contains("SCRIPT ERROR:")
	assert_str(combined).not_contains("Failed loading resource:")
	assert_int(report_start).is_greater_equal(0)
	assert_int(report_end).is_greater(report_start)
	var report_json := combined.substr(report_start, report_end - report_start + 1)
	var parsed: Variant = JSON.parse_string(report_json)
	assert_bool(parsed is Dictionary).is_true()
	var report: Dictionary = parsed
	assert_int(int(report["summary"]["severity"]["error"])).is_equal(0)


func test_dom_side_agreement_reward_is_audited_as_a_soul_ledger_event() -> void:
	var quest := DomSideQuest.new()
	quest.outcome_ids = PackedStringArray(["agree", "decline"])
	quest.outcome_faction_ids = PackedStringArray(["faction-a", "faction-b"])
	quest.outcome_reputation_deltas = PackedFloat32Array([2.0, -2.0])
	quest.outcome_causes = PackedStringArray(["Agreed", "Declined"])
	quest.outcome_tags = [
		PackedStringArray([DomSideQuest.ACT_OF_AGREEMENT_TAG]), PackedStringArray()
	]
	quest.outcome_soul_deltas = PackedFloat32Array([5.0, 0.0])

	var outcomes := QuestAuditScript._dom_side_outcomes(quest, "test_resolution")

	assert_array(outcomes[0]["ledger_events"]).contains(
		"soul:5.0:%s" % DomSideQuest.ACT_OF_AGREEMENT_TAG
	)
	assert_int(outcomes[1]["ledger_events"].size()).is_equal(1)


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


const QUEST_OK := '''[gd_resource type="Resource" script_class="DomSideQuest" load_steps=2 format=3]

[resource]
quest_name = "Dishonest Water"
giver_actor_id = "keth-varr"
objectives = PackedStringArray("Trace the casks.", "Rule on them.")
'''

const QUEST_BARE := '''[gd_resource type="Resource" script_class="FlagQuest" load_steps=2 format=3]

[resource]
quest_name = ""
quest_giver = ""
objectives = PackedStringArray()
'''

const FETCH_QUEST := '''[gd_resource type="Resource" script_class="FetchQuest" load_steps=2 format=3]

[resource]
quest_name = "Loamroot Sprigs"
quest_giver = "Iris Illepah"
'''

const LOCATION_OK := '''[gd_resource type="Resource" script_class="LocationDefinition" load_steps=2 format=3]

[resource]
id = &"wound_lip"
scene_path = "res://world/wound_lip.tscn"
default_spawn_id = &"default"
arrival_flag = "chapter_wound_lip_reached"
spawns = {
"from_dom": "from_dom"
}
'''

const LOCATION_BROKEN := '''[gd_resource type="Resource" script_class="LocationDefinition" load_steps=2 format=3]

[resource]
id = &"nowhere"
scene_path = "res://world/does_not_exist.tscn"
default_spawn_id = &"entry"
arrival_flag = "Nowhere.Reached"
spawns = {
"from_dom": "from_dom"
}
'''

const LOCATION_ALIASED := '''[gd_resource type="Resource" script_class="LocationDefinition" load_steps=2 format=3]

[resource]
id = &"bell_house"
scene_path = "res://world/interiors/bell_house.tscn"
default_spawn_id = &"entry"
spawns = {
"entry": "entry",
"from_bell_loft": "from_bell_loft"
}
'''


func test_template_conformance_accepts_shipped_shapes() -> void:
	var violations := QuestAuditScript.template_conformance_violations(
		{"res://quests/ok.tres": QUEST_OK, "res://quests/fetch.tres": FETCH_QUEST},
		{
			"res://world/locations/ok.tres": LOCATION_OK,
			"res://world/locations/interiors/aliased.tres": LOCATION_ALIASED,
		}
	)

	assert_array(violations).is_empty()


func test_template_conformance_warns_on_missing_quest_fields() -> void:
	var violations := QuestAuditScript.template_conformance_violations(
		{"res://quests/bare.tres": QUEST_BARE}, {}
	)

	assert_int(violations.size()).is_equal(3)
	var codes := PackedStringArray()
	for violation: Dictionary in violations:
		codes.append(str(violation["code"]))
		assert_str(str(violation["severity"])).is_equal("warning")
		assert_str(str(violation["path"])).is_equal("res://quests/bare.tres")
	assert_bool(codes.has("quest_missing_name")).is_true()
	assert_bool(codes.has("quest_missing_giver")).is_true()
	assert_bool(codes.has("quest_missing_objectives")).is_true()


func test_template_conformance_flags_broken_location_fields() -> void:
	var violations := QuestAuditScript.template_conformance_violations(
		{}, {"res://world/locations/broken.tres": LOCATION_BROKEN}
	)

	var by_code := {}
	for violation: Dictionary in violations:
		by_code[str(violation["code"])] = violation
	assert_int(violations.size()).is_equal(3)
	assert_str(str(by_code["location_scene_missing"]["severity"])).is_equal("error")
	assert_str(str(by_code["location_scene_missing"]["scene_path"])).is_equal(
		"res://world/does_not_exist.tscn"
	)
	assert_str(str(by_code["location_arrival_flag_grammar"]["severity"])).is_equal("warning")
	assert_str(str(by_code["location_default_spawn_unaliased"]["severity"])).is_equal("error")
	assert_str(str(by_code["location_default_spawn_unaliased"]["default_spawn_id"])).is_equal("entry")


func test_report_carries_a_template_conformance_category_and_metric() -> void:
	var quest_results: Array[Dictionary] = []
	var flags := QuestAuditScript.scan_flag_sources(PackedStringArray([FLAG_FIXTURE]))
	var violations := QuestAuditScript.template_conformance_violations(
		{"res://quests/bare.tres": QUEST_BARE},
		{"res://world/locations/broken.tres": LOCATION_BROKEN}
	)
	var report := QuestAuditScript.build_report(
		quest_results, flags, false, PackedStringArray(), PackedStringArray(), {}, violations
	)

	var category: Dictionary = report["categories"]["template_conformance"]
	assert_int(int(category["count"])).is_equal(6)
	assert_int(int(category["severity"]["error"])).is_equal(2)
	assert_int(int(category["severity"]["warning"])).is_equal(4)
	assert_int(int(report["metrics"]["template_conformance"]["violations"])).is_equal(6)
	assert_int(int(report["metrics"]["template_conformance"]["errors"])).is_equal(2)
	assert_bool(bool(report["metrics"]["template_conformance"]["passes"])).is_false()
	assert_int(QuestAuditScript.exit_code_for_report(report, true)).is_equal(1)


func test_template_conformance_passes_on_shipped_content() -> void:
	var report := QuestAuditScript.audit_project(false)

	assert_bool(bool(report["metrics"]["template_conformance"]["passes"])).is_true()
	assert_int(int(report["metrics"]["template_conformance"]["errors"])).is_equal(0)


# --- Skill-check routes (check_softlocks) ------------------------------------


## A pre-offer check and a plain offer at the same quest stage: not a soft-lock.
const CHECK_PRE_OFFER_WITH_PLAIN_OFFER := '''~ charge
- "Ask first." [#tag=UNDERTONE] [if not QuestRegistry.is_active(QuestRegistry.ROAD) and not QuestRegistry.is_done(QuestRegistry.ROAD) and check("undertone", 40) /]
	do SkillCheck.resolve("undertone")
	if SkillCheck.last_check_succeeded()
		do GameState.set_flag("chapter_charge_understood", true)
		do QuestRegistry.offer(QuestRegistry.ROAD)
		=> END
	else
		do GameState.set_flag("chapter_charge_check_failed", true)
		=> charge
- "I will carry it." [if not QuestRegistry.is_active(QuestRegistry.ROAD) and not QuestRegistry.is_done(QuestRegistry.ROAD) /]
	do QuestRegistry.offer(QuestRegistry.ROAD)
	=> END
- "Already mine." [if QuestRegistry.is_active(QuestRegistry.ROAD) /]
	=> END
'''

## A mid-quest check whose only sibling is the offer: the offer is an earlier
## stage, not an alternative, so this IS a soft-lock candidate.
const CHECK_MID_QUEST_WITH_ONLY_OFFER := '''~ hub
- "Trace it." [#tag=SWAY] [if QuestRegistry.is_active(QuestRegistry.CASKS) and not GameState.get_flag("dom_casks_traced") and check("sway", 40) /]
	do SkillCheck.resolve("sway")
	if SkillCheck.last_check_succeeded()
		do GameState.set_flag("dom_casks_traced", true)
		=> END
	else
		do GameState.set_flag("dom_casks_check_failed", true)
		=> END
- "What happened?" [if not QuestRegistry.is_active(QuestRegistry.CASKS) and not QuestRegistry.is_done(QuestRegistry.CASKS) /]
	do QuestRegistry.offer(QuestRegistry.CASKS)
	=> END
'''

const CHECK_MID_QUEST_WITH_SAME_STAGE_ROUTE := '''~ hub
- "Trace it." [#tag=SWAY] [if QuestRegistry.is_active(QuestRegistry.CASKS) and not GameState.get_flag("dom_casks_traced") and check("sway", 40) /]
	do SkillCheck.resolve("sway")
	if SkillCheck.last_check_succeeded()
		do GameState.set_flag("dom_casks_traced", true)
		=> END
	else
		do GameState.set_flag("dom_casks_check_failed", true)
		=> END
- "Ask the cooper instead." [if QuestRegistry.is_active(QuestRegistry.CASKS) and not GameState.get_flag("dom_casks_traced") /]
	do GameState.set_flag("dom_casks_traced", true)
	=> END
'''

## No quest constant at all: the route has to come from whatever else writes
## the flag the success branch writes.
const CHECK_WITHOUT_QUEST := '''~ trial_aide
- "Ask to pass." [#tag=UNDERTONE] [if not GameState.get_flag("tutorial_gauntlet_complete") and check("undertone", 40) /]
	do SkillCheck.resolve("undertone")
	if SkillCheck.last_check_succeeded()
		do GameState.set_flag("tutorial_gauntlet_complete", true)
		=> END
	else
		do GameState.set_flag("tutorial_aide_skip_failed", true)
		=> END
- "I will take the trial."
	=> END
'''

const SCENE_SCRIPT_WRITER := '''extends Node2D

const OPENING_COMPLETE_FLAG := "tutorial_gauntlet_complete"


func _on_battle_ended() -> void:
	GameState.set_flag(OPENING_COMPLETE_FLAG, true)
'''

const SCENE_PICKUP_WRITER := '''[node name="TrialDoorKey" parent="." instance=ExtResource("5_pickup")]
completion_flag = "tutorial_gauntlet_complete"
'''

const OTHER_DIALOGUE_WRITER := '''~ start
do GameState.set_flag("tutorial_gauntlet_complete", true)
=> END
'''


func _softlock_codes(findings: Array[Dictionary]) -> Array[String]:
	var codes: Array[String] = []
	for finding: Dictionary in findings:
		codes.append(str(finding["code"]))
	return codes


func test_check_route_accepts_a_plain_offer_at_the_same_quest_stage() -> void:
	var findings := QuestAuditScript.check_softlock_violations(
		{"res://dialogue/elder.dialogue": CHECK_PRE_OFFER_WITH_PLAIN_OFFER}
	)
	assert_array(_softlock_codes(findings)).not_contains(
		["checked_response_may_be_only_acquisition_route"]
	)


func test_check_route_rejects_an_offer_as_a_route_for_a_mid_quest_check() -> void:
	var findings := QuestAuditScript.check_softlock_violations(
		{"res://dialogue/casks.dialogue": CHECK_MID_QUEST_WITH_ONLY_OFFER}
	)
	assert_array(_softlock_codes(findings)).contains_exactly(
		["checked_response_may_be_only_acquisition_route"]
	)
	assert_str(str(findings[0]["quest_constant"])).is_equal("CASKS")

	findings = QuestAuditScript.check_softlock_violations(
		{"res://dialogue/casks.dialogue": CHECK_MID_QUEST_WITH_SAME_STAGE_ROUTE}
	)
	assert_int(findings.size()).is_equal(0)


func test_check_without_quest_needs_another_writer_of_its_success_flag() -> void:
	var dialogue := {"res://dialogue/hall.dialogue": CHECK_WITHOUT_QUEST}

	var findings := QuestAuditScript.check_softlock_violations(dialogue, {})
	assert_array(_softlock_codes(findings)).contains_exactly(
		["checked_response_may_be_only_acquisition_route"]
	)
	assert_array(findings[0]["success_effects"]).contains_exactly(["flag:tutorial_gauntlet_complete"])

	findings = QuestAuditScript.check_softlock_violations(
		dialogue, {"res://world/hall.gd": SCENE_SCRIPT_WRITER}
	)
	assert_int(findings.size()).is_equal(0)

	findings = QuestAuditScript.check_softlock_violations(
		dialogue, {"res://world/hall.tscn": SCENE_PICKUP_WRITER}
	)
	assert_int(findings.size()).is_equal(0)

	var two_files := dialogue.duplicate()
	two_files["res://dialogue/other.dialogue"] = OTHER_DIALOGUE_WRITER
	findings = QuestAuditScript.check_softlock_violations(two_files, {})
	assert_int(findings.size()).is_equal(0)


func test_shipped_dialogue_has_no_check_only_routes() -> void:
	var report := QuestAuditScript.audit_project(false)

	assert_int(int(report["categories"]["check_softlocks"]["count"])).is_equal(0)


# --- Orphan scanner blind spots ----------------------------------------------


func test_flag_reads_through_constants_and_flag_is_true_count_as_reads() -> void:
	var quest_results: Array[Dictionary] = []
	var dialogue_sources := {FLAG_FIXTURE: FileAccess.get_file_as_string(FLAG_FIXTURE)}
	var through_constant := '''const WRITE_ONLY_FLAG := "write_only"


func _ready() -> void:
	if GameState.flag_is_true(WRITE_ONLY_FLAG):
		pass
'''
	var literal := '''func _ready() -> void:
	if GameState.flag_is_true("write_only"):
		pass
'''

	var access := QuestAuditScript._project_flag_access(quest_results, dialogue_sources, {})
	assert_array(access["written_never_read"]).contains(["write_only"])

	access = QuestAuditScript._project_flag_access(
		quest_results, dialogue_sources, {"res://world/scene.gd": through_constant}
	)
	assert_array(access["written_never_read"]).not_contains(["write_only"])

	access = QuestAuditScript._project_flag_access(
		quest_results, dialogue_sources, {"res://world/scene.gd": literal}
	)
	assert_array(access["written_never_read"]).not_contains(["write_only"])


func test_format_string_flag_writes_are_prefix_sites_not_literal_orphans() -> void:
	var flags := QuestAuditScript.scan_flag_sources(
		PackedStringArray(["res://quests/fetch_quest.gd"])
	)

	assert_array(flags["written"]).not_contains(["quest_%d_resolution"])


func test_outcome_readback_flags_belong_to_the_readback_category_not_orphans() -> void:
	var quest_results: Array[Dictionary] = [
		{
			"quest_id": "sprigs",
			"quest_name": "Sprigs",
			"kind": "side",
			"constant": "SPRIGS",
			"outcomes": [
				{
					"id": "returned",
					"state_writes": ["quest_1_resolution=returned"],
					"ledger_events": [],
					"readback_flag": "quest_1_resolution",
					"read_back": false,
				}
			],
		}
	]
	var dialogue_sources := {FLAG_FIXTURE: FileAccess.get_file_as_string(FLAG_FIXTURE)}

	var access := QuestAuditScript._project_flag_access(quest_results, dialogue_sources, {})

	assert_array(access["written"]).contains(["quest_1_resolution"])
	assert_array(access["written_never_read"]).not_contains(["quest_1_resolution"])


func test_direct_outcome_names_a_fetch_resolution_flag_only_for_fetch_quests() -> void:
	var flag_quest := FlagQuest.new()
	flag_quest.id = 3
	var quest := {"resource": flag_quest, "constant": "DEEP"}
	var lines := PackedStringArray(
		[
			'	do QuestRegistry.turn_in(QuestRegistry.DEEP, "sealed", false)',
			'	do GameState.set_flag("deep_resolution", "sealed")',
			"	=> END",
		]
	)

	var outcome := QuestAuditScript._direct_outcome(
		quest, "sealed", false, "res://dialogue/deep.dialogue", 0, lines
	)

	assert_array(outcome["state_writes"]).contains_exactly(["deep_resolution=sealed"])
	assert_str(str(outcome["readback_flag"])).is_equal("deep_resolution")


# --- Companion quests ----------------------------------------------------------


func test_companion_resolutions_are_two_distinct_completion_read_back_outcomes() -> void:
	var registry_source := FileAccess.get_file_as_string("res://globals/quest_registry.gd")
	var metadata := QuestAuditScript._quest_metadata(registry_source)
	var path := "res://dialogue/companions/korrath_ninefold.dialogue"
	var dialogue_sources := {path: FileAccess.get_file_as_string(path)}

	var results := QuestAuditScript._collect_quest_results(metadata, dialogue_sources)
	var korrath: Dictionary = {}
	for quest: Dictionary in results:
		if str(quest["constant"]) == "KORRATH_QUEST":
			korrath = quest
	assert_bool(korrath.is_empty()).is_false()
	var outcomes: Array[Dictionary] = QuestAuditScript._typed_dictionaries(korrath["outcomes"])
	assert_int(outcomes.size()).is_equal(2)
	assert_int(QuestAuditScript.distinct_outcome_count(outcomes)).is_equal(2)
	assert_array(outcomes[0]["state_writes"]).contains_exactly(
		["party_korrath_ninefold_resolved=true"]
	)

	QuestAuditScript._classify_readbacks(results, dialogue_sources)
	for outcome: Dictionary in korrath["outcomes"]:
		assert_bool(bool(outcome["read_back"])).is_true()
