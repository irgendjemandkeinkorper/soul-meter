extends GdUnitTestSuite

const PROTOCOL_PATH := "res://docs/playtest-protocol.md"
const PACKET_PATH := "res://docs/playtest-packet.md"
const GATE_T_EVIDENCE_DIR := "res://test/manual/gate-t"


func test_protocol_asks_all_four_ratified_gate_t_comprehension_questions() -> void:
	var protocol := FileAccess.get_file_as_string(PROTOCOL_PATH)
	assert_str(protocol).contains("Gate T criterion 6")
	assert_str(protocol).contains("Why did that cast fail?")
	assert_str(protocol).contains("What does this gauge do?")
	assert_str(protocol).contains("Who acts next, and why?")
	assert_str(protocol).contains("Explain what just happened on that tile.")
	assert_str(protocol).contains("majority of eligible testers")
	assert_str(protocol).contains("per question")


func test_execution_packet_uses_ct_grid_and_tile_language_not_retired_ap_zones() -> void:
	var packet := FileAccess.get_file_as_string(PACKET_PATH)
	assert_str(packet).contains("charge time (CT)")
	assert_str(packet).contains("grid, elevation, and facing")
	assert_str(packet).contains("tile charge, residue, or detonation")
	assert_str(packet).contains("majority of eligible testers")
	assert_str(packet).not_contains("AP spent")
	assert_str(packet).not_contains("Zone facing or movement used")
	assert_str(packet).not_contains("G1–G7")


func test_protocol_names_phase_one_point_five_as_superseded_not_a_second_gate() -> void:
	var protocol := FileAccess.get_file_as_string(PROTOCOL_PATH)
	assert_str(protocol).contains("Phase 1.5 is superseded by Gate T, not cancelled")
	assert_str(protocol).contains("one gate")
	assert_str(protocol).contains("not a second session")


func test_gate_t_evidence_templates_are_ready_for_outside_sessions() -> void:
	for tester_id in ["T1", "T2", "T3"]:
		var tester_path := "%s/%s.md" % [GATE_T_EVIDENCE_DIR, tester_id]
		assert_bool(FileAccess.file_exists(tester_path)).is_true()
		var form := FileAccess.get_file_as_string(tester_path)
		assert_str(form).contains("Tester ID: %s" % tester_id)
		assert_str(form).contains("Build artifact / SHA verified")
		assert_str(form).contains("Why did that cast fail?")
		assert_str(form).contains("What does this gauge do?")
		assert_str(form).contains("Who acts next, and why?")
		assert_str(form).contains("Explain what just happened on that tile.")
		assert_str(form).contains("Facilitator interventions")

	var summary_path := "%s/summary.md" % GATE_T_EVIDENCE_DIR
	assert_bool(FileAccess.file_exists(summary_path)).is_true()
	var summary := FileAccess.get_file_as_string(summary_path)
	assert_str(summary).contains("3–5 eligible outside testers")
	assert_str(summary).contains("Q1 majority: cast refusal")
	assert_str(summary).contains("Q2 majority: Balance")
	assert_str(summary).contains("Q3 majority: CT order")
	assert_str(summary).contains("Q4 majority: tile state")
	assert_str(summary).contains("Gate T criterion 6: **PASS / FAIL**")
