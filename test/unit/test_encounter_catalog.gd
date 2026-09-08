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
	assert_str(bog_wight[0].element_id).is_equal("mozh")

	var boar := EncounterCatalog.make_actors(EncounterIds.LOAM_BOAR)
	assert_str(boar[0].element_id).is_equal("tham")


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


func test_make_actor_builds_one_combatant_from_an_archetype_id() -> void:
	# Same-map combat D4: a Hostile scene node owns its own unit, so the catalog must be able to
	# speak in single units and not only in whole encounters.
	var actor := EncounterCatalog.make_actor(&"bog-wight")
	assert_object(actor).is_not_null()
	assert_str(String(actor.archetype_id)).is_equal("bog-wight")
	assert_int(actor.hp).is_equal(actor.max_hp)
	assert_int(actor.hp).is_greater(0)
	# A unit built with no group carries no ledger fields — those belong to an encounter.
	assert_str(actor.defeated_flag).is_empty()

	var second := EncounterCatalog.make_actor(&"bog-wight")
	assert_object(second).is_not_same(actor)


func test_make_actor_applies_the_groups_outcome_fields() -> void:
	var actor := EncounterCatalog.make_actor(&"bog-wight", EncounterIds.BOG_WIGHT)
	assert_str(actor.defeated_flag).is_equal("defeated_bog_wight")
	assert_str(actor.win_faction).is_not_empty()
	var plural := EncounterCatalog.make_actors(EncounterIds.BOG_WIGHT)
	assert_str(actor.defeated_flag).override_failure_message(
		"a hostile built for a group must carry the same ledger fields make_actors() gives actors[0]"
	).is_equal(plural[0].defeated_flag)


func test_make_actor_refuses_an_unknown_unit() -> void:
	assert_object(EncounterCatalog.make_actor(&"no-such-unit")).is_null()


## #283 §3.6. Canon authors all seven DRAMGID attributes per archetype, but until the
## Combatants re-seed only `Edge` had a Pandora column, so the generated table carried one
## number and every enemy read 0 for the other six. Nothing said so — `attribute_value()`
## returns 0 for a name it does not hold, which is the same shape as the chargen defect
## #411 closed on the party's side. This is the live consumer of that re-seed.
func test_a_built_enemy_carries_every_dramgid_attribute() -> void:
	var actor := EncounterCatalog.make_actor(&"bog-wight")
	for attribute_id: String in DramgidSchema.ATTRIBUTES:
		assert_bool(actor.attributes.has(StringName(attribute_id))).override_failure_message(
			"a bog wight reaches combat without '%s'" % attribute_id
		).is_true()
	# The authored block, in schema order: doctrine/reason/alacrity/muster/grit/intuition/decorum.
	assert_int(actor.attribute_value(&"doctrine")).is_equal(1)
	assert_int(actor.attribute_value(&"reason")).is_equal(1)
	assert_int(actor.attribute_value(&"alacrity")).is_equal(2)
	assert_int(actor.attribute_value(&"muster")).is_equal(2)
	assert_int(actor.attribute_value(&"grit")).is_equal(2)
	assert_int(actor.attribute_value(&"intuition")).is_equal(3)
	assert_int(actor.attribute_value(&"decorum")).is_equal(1)


## The two archetypes have to differ, or the block is being defaulted rather than read.
func test_two_archetypes_carry_different_attribute_blocks() -> void:
	var wight := EncounterCatalog.make_actor(&"bog-wight")
	var guard := EncounterCatalog.make_actor(&"cleaned-jawbrace-guard")
	assert_int(guard.attribute_value(&"grit")).override_failure_message(
		"the Jawbrace guard's authored grit of 5 did not survive the seed"
	).is_equal(5)
	assert_int(guard.attribute_value(&"doctrine")).is_equal(4)
	assert_bool(
		guard.attribute_value(&"grit") != wight.attribute_value(&"grit")
	).is_true()


## The boundary #411 left standing on purpose: an authored campaign package writes the flat
## `edge` key and no DRAMGID block (`campaign_encounter_loader.gd`). That row must still
## produce a fighting unit, and `edge` must land on Alacrity — its ratified rename — not be
## dropped for want of an `attributes` object.
func test_a_campaign_package_row_with_only_edge_still_lands_on_alacrity() -> void:
	EncounterCatalog.register_runtime_encounters({
		"package-fixture": {
			"display_name": "Package Fixture",
			"enemies": [{
				"id": "package-brute",
				"display_name": "Package Brute",
				"max_hp": 11,
				"attack": 3,
				"defense": 1,
				"balance_affinity": 0,
				"balance_pressure": 12,
				"element_id": "",
				"edge": 4,
			}],
		},
	})
	var actors := EncounterCatalog.make_actors(&"package-fixture")

	assert_int(actors.size()).is_equal(1)
	assert_int(actors[0].attribute_value(&"alacrity")).override_failure_message(
		"a package row's flat `edge` no longer reaches Alacrity"
	).is_equal(4)


## F0 D8 (#281 step 8). `_WEATHER_DEFAULTS` used to be injected here, keyed per
## encounter, so a bog wight brought mozh with it wherever it was fought. Weather
## is `LocationDefinition.weather_default` now — the map has the weather. This pins
## the retirement: a catalog row must carry no weather of its own.
func test_the_catalog_no_longer_authors_weather() -> void:
	for encounter_id: StringName in EncounterCatalog.all_ids():
		var definition := EncounterCatalog.definition(encounter_id)
		assert_bool(definition.has("weather_default")).override_failure_message(
			"encounter '%s' carries a weather default; weather belongs to the location (F0 D8)"
			% encounter_id
		).is_false()


## The boundary left standing: a campaign package authors `weather_default` on its
## own encounter (`campaign_encounter_loader.gd` validates the key), and that row
## still round-trips through the catalog untouched.
func test_a_campaign_package_may_still_author_its_own_weather() -> void:
	EncounterCatalog.register_runtime_encounters({
		"package-weather": {
			"display_name": "Package Weather",
			"weather_default": "zhur",
			"enemies": [{"id": "package-brute", "display_name": "Brute", "max_hp": 9, "attack": 2}],
		},
	})
	var definition := EncounterCatalog.definition(&"package-weather")
	assert_str(str(definition.get("weather_default", ""))).is_equal("zhur")
