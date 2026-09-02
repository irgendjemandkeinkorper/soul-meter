extends GdUnitTestSuite
## Schema-level tests for the tactical layer (issue #141): the six Pandora tables, the
## generated lookup, and the value objects that read them.

const Generator := preload("res://tools/generate_tactical_tables.gd")
const TacticalSeeder := preload("res://tools/seed_tactical_tables.gd")
const TurnSchedulerScript := preload("res://globals/combat/turn_scheduler.gd")
const TABLES_PATH := "res://data/generated/tactical_tables.json"
const IDS_PATH := "res://data/generated/tactical_ids.gd"


func test_pandora_carries_all_six_tactical_tables_as_schema() -> void:
	if not Pandora.is_loaded():
		Pandora.load_data()
	var root_names: Array[String] = []
	for root: PandoraCategory in Pandora.get_all_roots():
		root_names.append(root.get_entity_name())
	for table_name: String in TacticalSeeder.TABLES:
		assert_array(root_names).contains([table_name])


func test_seeder_is_idempotent_against_the_committed_data() -> void:
	if not Pandora.is_loaded():
		Pandora.load_data()
	# Every table is already present, so a second run must create nothing at all.
	assert_array(Array(TacticalSeeder.seed_tables())).is_empty()


func test_generated_tactical_tables_match_pandora_and_ship_ten_note_spells() -> void:
	if not Pandora.is_loaded():
		Pandora.load_data()
	var result: Dictionary = Generator.generate(true)
	assert_bool(result.drift).is_false()
	assert_int(result.job_count).is_equal(0)
	assert_int(result.ability_count).is_equal(ElementWheel.ORDER.size())
	assert_int(result.unit_count).is_equal(1)


func test_generated_artifact_exposes_every_table_key() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLES_PATH))
	assert_bool(parsed is Dictionary).is_true()
	var data: Dictionary = parsed
	for table_key in [
		"jobs", "abilities", "units", "unit_jobs", "unit_attunement", "unit_loadout"
	]:
		assert_bool(data.has(table_key)).is_true()
		assert_bool(data[table_key] is Array).is_true()


func test_generated_ids_file_is_marked_generated() -> void:
	var source := FileAccess.get_file_as_string(IDS_PATH)
	assert_str(source).contains("GENERATED FILE")
	assert_str(source).contains("class_name TacticalIds")


func test_ct_cost_bound_mirrors_the_charge_time_economy() -> void:
	# The generator mirrors READY_AT rather than importing the combat layer. If the CT
	# economy ever changes, this is the test that notices — the constant must not drift.
	var ready_at: int = TurnSchedulerScript.READY_AT
	assert_int(Generator.CT_READY_AT).is_equal(ready_at)


func test_tactical_tables_loader_exposes_note_spells_and_unit_loadouts() -> void:
	var tables := TacticalTables.load_tables()
	assert_bool(tables.jobs.is_empty()).is_true()
	assert_int(tables.abilities.size()).is_equal(ElementWheel.ORDER.size())
	assert_object(tables.job("anything")).is_null()
	assert_array(tables.abilities_for_job("anything")).is_empty()
	var vex_abilities := tables.abilities_for_unit("vex", AbilityDefinition.SLOT_ACTION)
	assert_int(vex_abilities.size()).is_equal(1)
	assert_str(vex_abilities[0].id).is_equal("note-scor")
	assert_object(tables.unit("caster")).is_null()
	assert_object(tables.loadout("caster")).is_null()
	var combat_rules := load("res://data/combat/combat_rules.tres") as CombatRules
	var strike_ct_cost := combat_rules.charge_cost_for(CombatActionCatalog.by_id(&"strike"))
	for element_id: StringName in ElementWheel.ORDER:
		var ability := tables.ability("note-%s" % element_id)
		assert_object(ability).is_not_null()
		assert_str(ability.display_name).is_equal("%s Note" % ElementsData.element(element_id).display_name)
		assert_int(ability.power).is_equal(6)
		assert_int(ability.breath_cost).is_equal(3)
		assert_int(ability.mp_cost).is_equal(3)
		assert_int(ability.ct_cost).is_equal(strike_ct_cost)
		assert_int(ability.range).is_equal(3)
		assert_int(ability.aoe).is_equal(0)
		assert_str(ability.vault_id).is_equal(ElementsData.element(element_id).vault_id)


func test_tactical_tables_loader_returns_an_empty_catalog_for_a_missing_artifact() -> void:
	var tables := TacticalTables.load_tables("res://data/generated/does-not-exist.json")
	assert_bool(tables.jobs.is_empty()).is_true()


func test_attunement_rejects_values_outside_the_signed_three_range() -> void:
	var attunement := UnitAttunement.create("synthetic-unit")
	assert_int(attunement.values.size()).is_equal(ElementWheel.ORDER.size())
	for value in [-4, 4, -100, 99]:
		assert_bool(attunement.set_value(&"suul", value)).is_false()
		assert_int(attunement.value_for(&"suul")).is_equal(0)
	for value in [-3, -1, 0, 2, 3]:
		assert_bool(attunement.set_value(&"suul", value)).is_true()
		assert_int(attunement.value_for(&"suul")).is_equal(value)


func test_attunement_rejects_elements_outside_the_wheel_of_ten() -> void:
	var attunement := UnitAttunement.create("synthetic-unit")
	assert_bool(attunement.set_value(&"not-an-element", 1)).is_false()
	assert_int(attunement.values.size()).is_equal(ElementWheel.ORDER.size())


func test_attunement_from_dict_rejects_an_out_of_range_row_whole() -> void:
	var valid := UnitAttunement.create("synthetic-unit")
	valid.set_value(&"terra", -3)
	var payload := valid.to_dict()
	assert_object(UnitAttunement.from_dict(payload)).is_not_null()

	var corrupt: Dictionary = payload.duplicate(true)
	(corrupt["values"] as Dictionary)["terra"] = -4
	assert_object(UnitAttunement.from_dict(corrupt)).is_null()

	var unknown: Dictionary = payload.duplicate(true)
	(unknown["values"] as Dictionary)["eleventh"] = 0
	assert_object(UnitAttunement.from_dict(unknown)).is_null()


func test_attunement_round_trips_through_json_floats() -> void:
	# JSON has no integer type, so a saved 3 comes back as 3.0. It must still be valid.
	var restored := UnitAttunement.from_dict(
		{"unit_id": "synthetic-unit", "values": {"suul": 3.0, "daar": -3.0}}
	)
	assert_object(restored).is_not_null()
	assert_int(restored.value_for(&"suul")).is_equal(3)
	assert_int(restored.value_for(&"daar")).is_equal(-3)
	assert_object(
		UnitAttunement.from_dict({"unit_id": "synthetic-unit", "values": {"suul": 1.5}})
	).is_null()


func test_attunement_serializes_in_wheel_order() -> void:
	var row: Dictionary = UnitAttunement.create("synthetic-unit").to_dict()["values"]
	var keys: Array = row.keys()
	for index in ElementWheel.ORDER.size():
		assert_str(str(keys[index])).is_equal(String(ElementWheel.ORDER[index]))


func test_ability_slot_enum_is_exactly_action_reaction_passive() -> void:
	assert_int(AbilityDefinition.SLOTS.size()).is_equal(3)
	for slot in ["action", "reaction", "passive"]:
		assert_bool(AbilityDefinition.is_valid_slot(slot)).is_true()
	assert_bool(AbilityDefinition.is_valid_slot("ultimate")).is_false()
	assert_bool(AbilityDefinition.is_valid_slot("")).is_false()


func test_definitions_round_trip_through_dictionaries() -> void:
	var job := JobDefinition.from_dict(
		{"id": "synthetic-job", "tier": 2, "element_id": "aqua", "growth_hp": 1.5}
	)
	assert_str(JobDefinition.from_dict(job.to_dict()).id).is_equal("synthetic-job")
	assert_int(JobDefinition.from_dict(job.to_dict()).tier).is_equal(2)

	var ability := AbilityDefinition.from_dict(
		{"id": "synthetic-ability", "job_id": "synthetic-job", "slot": "reaction", "ct_cost": 40}
	)
	var restored := AbilityDefinition.from_dict(ability.to_dict())
	assert_str(String(restored.slot)).is_equal("reaction")
	assert_int(restored.ct_cost).is_equal(40)

	var unit := UnitDefinition.from_dict({"id": "synthetic-unit", "base_hp": 30, "move": 4})
	assert_int(UnitDefinition.from_dict(unit.to_dict()).base_hp).is_equal(30)

	var loadout := UnitLoadout.from_dict({
		"unit_id": "synthetic-unit",
		"action_ability_ids": ["note-suul", "note-strom"],
		"equip": {"hand": "x"},
	})
	assert_array(Array(UnitLoadout.from_dict(loadout.to_dict()).action_ability_ids)).is_equal(
		["note-suul", "note-strom"]
	)
	assert_str(str(UnitLoadout.from_dict(loadout.to_dict()).equip["hand"])).is_equal("x")


func test_job_progress_keeps_mastery_unique_and_sorted() -> void:
	var progress := UnitJobProgress.create("synthetic-unit", "synthetic-job")
	assert_bool(progress.master("c")).is_true()
	assert_bool(progress.master("a")).is_true()
	assert_bool(progress.master("a")).is_false()
	assert_array(Array(progress.mastered)).is_equal(["a", "c"])
	var restored := UnitJobProgress.from_dict(progress.to_dict())
	assert_array(Array(restored.mastered)).is_equal(["a", "c"])
	assert_int(UnitJobProgress.from_dict({"jp": -5}).jp).is_equal(0)
