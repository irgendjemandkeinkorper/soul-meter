extends GdUnitTestSuite


func before_test() -> void:
	EncounterCatalog.clear_cache()
	EncounterCatalog.clear_runtime_encounters()


func after_test() -> void:
	EncounterCatalog.clear_runtime_encounters()


func test_dorthkor_vanguard_expands_to_multiple_pandora_combatants() -> void:
	var actors := EncounterCatalog.make_actors(EncounterIds.DORTHKOR_VANGUARD)

	assert_int(actors.size()).is_equal(2)
	assert_str(actors[0].display_name).is_equal("Gnaal Breach-Hound")
	assert_str(actors[1].display_name).is_equal("Gnaal Rift-Scavenger")
	assert_int(actors[0].balance_affinity).is_equal(-1)
	assert_str(actors[0].defeated_flag).is_equal("defeated_breach_hound")
	assert_str(actors[0].win_faction).is_equal("iron-companies")


func test_catalog_returns_fresh_combatants_for_each_battle() -> void:
	var first := EncounterCatalog.make_actors(EncounterIds.BOG_WIGHT)
	first[0].hp = 1
	var second := EncounterCatalog.make_actors(EncounterIds.BOG_WIGHT)

	assert_int(second[0].hp).is_equal(second[0].max_hp)
	assert_int(second[0].hp).is_equal(20)


func test_encounter_can_override_location_agreement_integrity() -> void:
	assert_bool(EncounterCatalog.register_runtime_encounters({
		"integrity-override-test": {"agreement_integrity": 42.0},
	})).is_true()

	assert_float(
		EncounterCatalog.agreement_integrity(&"integrity-override-test", 85.0)
	).is_equal(42.0)
	assert_float(EncounterCatalog.agreement_integrity(&"missing-encounter", 85.0)).is_equal(85.0)


func test_deep_trial_encounter_has_a_durable_completion_flag() -> void:
	assert_str(EncounterCatalog.defeated_flag(EncounterIds.JAWBRACE_EMPTY_POST)).is_equal(
		"defeated_cleaned_jawbrace_guard"
	)


func test_first_field_encounters_carry_authored_wheel_attunement() -> void:
	## The gamble curve (vault: systems/magic-system.md "Target relation") prices any
	## elemental attack by Wheel distance to the target's attunement — these are the first
	## two enemies a player fights, so their attunement should not be neutral-by-omission.
	var bog_wight := EncounterCatalog.make_actors(EncounterIds.BOG_WIGHT)
	assert_str(bog_wight[0].element_id).is_equal("molm")

	var boar := EncounterCatalog.make_actors(EncounterIds.LOAM_BOAR)
	assert_str(boar[0].element_id).is_equal("terra")


func test_bloodbellow_exposes_three_authored_outcomes() -> void:
	var actions := EncounterCatalog.context_actions(EncounterIds.DORTHKOR_MUSTER)

	assert_int(actions.size()).is_equal(2)
	assert_str(actions[0]["outcome_id"]).is_equal("named")
	assert_str(actions[1]["outcome_id"]).is_equal("released")
	assert_str(EncounterCatalog.outcome(EncounterIds.DORTHKOR_MUSTER, &"slain")["cause"]).contains(
		"by force"
	)


func test_every_encounter_definition_has_an_authored_spoils_table() -> void:
	# Wave 5 invariant: battle victory yields inspectable spoils EVERYWHERE.
	# Enumerates the generated encounter data so a future encounter cannot
	# ship without a spoils entry (gate-recorded drift risk).
	var encounters: Dictionary = (
		load("res://data/generated/encounters.json") as JSON
	).data
	assert_int(encounters.size()).is_greater_equal(10)
	for encounter_id: String in encounters:
		assert_array(EncounterCatalog.roll_spoils(StringName(encounter_id))) \
			.override_failure_message(
				"Encounter '%s' has no authored spoils table" % encounter_id
			).is_not_empty()
