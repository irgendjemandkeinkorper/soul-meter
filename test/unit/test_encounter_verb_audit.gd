extends GdUnitTestSuite

## `tools/audit_encounter_verbs.gd` measures the PRD §3 encounter-verb row. These pin the
## arithmetic to the committed encounter data, not a hand-counted number, so content changes
## move the report rather than break the test.

const Audit := preload("res://tools/audit_encounter_verbs.gd")


func test_every_committed_encounter_is_audited_once() -> void:
	var result: Dictionary = Audit.audit()
	var ids: PackedStringArray = []
	for row: Dictionary in result["rows"]:
		ids.append(row["id"])
	assert_int(ids.size()).is_equal(EncounterCatalog.all_ids().size())
	for id: StringName in EncounterCatalog.all_ids():
		assert_bool(ids.has(String(id))).override_failure_message(
			"encounter '%s' is missing from the audit" % id
		).is_true()


func test_a_row_passes_the_prd_bar_exactly_when_it_authors_a_verb_beyond_attack_and_cast() -> void:
	var result: Dictionary = Audit.audit()
	var passing := 0
	var speech_or_context := 0
	for row: Dictionary in result["rows"]:
		var definition := EncounterCatalog.definition(StringName(row["id"]))
		var authored: PackedStringArray = row["authored"]
		assert_bool(authored.has("speech")).is_equal(
			not (definition.get("speech_hooks", []) as Array).is_empty()
		)
		assert_bool(authored.has("context")).is_equal(
			not EncounterCatalog.context_actions(StringName(row["id"])).is_empty()
		)
		assert_bool(authored.has("position")).is_equal(
			not (definition.get("zone_layout", []) as Array).is_empty()
		)
		assert_bool(row["prd_pass"]).is_equal(not authored.is_empty())
		assert_int((row["verbs"] as PackedStringArray).size()).is_equal(2 + authored.size())
		if row["prd_pass"]:
			passing += 1
		if row["speech_or_context"]:
			speech_or_context += 1
	assert_int(result["prd_passing"]).is_equal(passing)
	assert_int(result["speech_or_context"]).is_equal(speech_or_context)
	assert_bool(result["meets_target"]).is_equal(
		float(passing) / float(result["total"]) >= Audit.PRD_TARGET_SHARE
	)


func test_the_report_names_every_encounter_and_the_target() -> void:
	var result: Dictionary = Audit.audit()
	var text: String = Audit.report(result)
	for row: Dictionary in result["rows"]:
		assert_str(text).contains(row["id"])
	assert_str(text).contains("PRD target ≥ 80%")
	assert_str(text).contains("MET" if result["meets_target"] else "NOT MET")
