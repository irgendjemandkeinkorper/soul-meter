extends GdUnitTestSuite

const GATE_IDS := [
	EncounterIds.PHASE2_DEMON,
	EncounterIds.PHASE2_UNDEAD,
	EncounterIds.PHASE2_MIXED_WHIPSAW,
	EncounterIds.PHASE2_SPEECH_WINNABLE,
	EncounterIds.PHASE2_STABILIZER_SHOWCASE,
]


func before_test() -> void:
	EncounterCatalog.clear_cache()


func test_five_archetype_gate_encounters_load_from_generated_data() -> void:
	for encounter_id: StringName in GATE_IDS:
		var definition := EncounterCatalog.definition(encounter_id)
		assert_bool(definition.is_empty()).is_false()
		assert_bool(definition.get("composition") is Dictionary).is_true()
		assert_bool(definition.get("zone_layout") is Array).is_true()
		assert_bool(definition.get("speech_hooks") is Array).is_true()
		assert_int(definition.get("zone_layout", []).size()).is_greater(0)
		assert_int(EncounterCatalog.make_actors(encounter_id).size()).is_greater(0)


func test_archetype_and_balance_contracts_cover_the_phase_two_gate() -> void:
	var demon := EncounterCatalog.definition(EncounterIds.PHASE2_DEMON)
	var undead := EncounterCatalog.definition(EncounterIds.PHASE2_UNDEAD)
	var mixed := EncounterCatalog.definition(EncounterIds.PHASE2_MIXED_WHIPSAW)
	var stabilizer := EncounterCatalog.definition(EncounterIds.PHASE2_STABILIZER_SHOWCASE)

	assert_array(demon["composition"]["archetypes"]).contains("demon")
	assert_float(demon["balance_bias"]).is_less(0.0)
	assert_array(undead["composition"]["archetypes"]).contains("undead")
	assert_float(undead["balance_bias"]).is_greater(0.0)
	assert_array(mixed["composition"]["archetypes"]).contains("demon", "undead")
	assert_float(mixed["balance_bias"]).is_equal(0.0)
	assert_array(stabilizer["composition"]["archetypes"]).contains("demon", "undead")
	assert_float(stabilizer["balance_bias"]).is_equal(0.0)


func test_zone_layout_uses_only_the_positioning_interface_vocabulary() -> void:
	for encounter_id: StringName in GATE_IDS:
		var layout: Array = EncounterCatalog.definition(encounter_id)["zone_layout"]
		for placement: Dictionary in layout:
			assert_array(["ally", "enemy"]).contains(str(placement.get("side", "")))
			assert_array(["front", "back", "flank"]).contains(str(placement.get("zone", "")))
			assert_bool(placement.get("combatant_ids") is Array).is_true()


func test_speech_winnable_fixture_binds_hook_action_and_outcome() -> void:
	var definition := EncounterCatalog.definition(EncounterIds.PHASE2_SPEECH_WINNABLE)
	var hooks: Array = definition["speech_hooks"]
	var actions := EncounterCatalog.context_actions(EncounterIds.PHASE2_SPEECH_WINNABLE)
	assert_int(hooks.size()).is_equal(1)
	assert_str(hooks[0]["action_id"]).is_equal("phase2-release-binding")
	assert_str(actions[0]["id"]).is_equal(hooks[0]["action_id"])
	assert_str(actions[0]["outcome_id"]).is_equal(hooks[0]["outcome_id"])
	assert_bool(
		EncounterCatalog.outcome(
			EncounterIds.PHASE2_SPEECH_WINNABLE, StringName(hooks[0]["outcome_id"])
		).is_empty()
	).is_false()
