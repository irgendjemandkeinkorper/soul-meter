extends GdUnitTestSuite


func before_test() -> void:
	EncounterCatalog.clear_cache()


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


func test_deep_trial_encounter_has_a_durable_completion_flag() -> void:
	assert_str(EncounterCatalog.defeated_flag(EncounterIds.JAWBRACE_EMPTY_POST)).is_equal(
		"defeated_cleaned_jawbrace_guard"
	)


func test_bloodbellow_exposes_three_authored_outcomes() -> void:
	var actions := EncounterCatalog.context_actions(EncounterIds.DORTHKOR_MUSTER)

	assert_int(actions.size()).is_equal(2)
	assert_str(actions[0]["outcome_id"]).is_equal("named")
	assert_str(actions[1]["outcome_id"]).is_equal("released")
	assert_str(EncounterCatalog.outcome(EncounterIds.DORTHKOR_MUSTER, &"slain")["cause"]).contains(
		"by force"
	)
