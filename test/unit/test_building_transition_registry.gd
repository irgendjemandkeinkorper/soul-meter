extends GdUnitTestSuite

const BUILDING_IDS: Array[StringName] = [
	&"registry_archive",
	&"bell_house",
	&"river_shrine",
	&"iron_companies",
	&"item_shop",
	&"equipment_shop",
	&"town_hall",
	&"chefs_house",
	&"players_house",
	&"trial_hall",
	&"registry_stacks",
	&"bell_loft",
	&"shrine_undercroft",
	&"garrison_yard",
	&"cask_warehouse",
	&"equipment_forge",
	&"council_chamber",
	&"chefs_pantry",
	&"players_loft",
	&"lower_trial_hall",
]


func test_dom_exposes_at_least_twenty_registry_backed_entry_transitions() -> void:
	var town_entries := BuildingTransitionRegistry.entries_from(GameFlow.TOWN_SCENE)
	assert_int(BuildingTransitionRegistry.ENTRIES.size()).is_greater_equal(20)
	assert_int(BuildingTransitionRegistry.ALL.size()).is_greater_equal(40)
	assert_int(town_entries.size()).is_equal(10)
	assert_int(BuildingTransitionRegistry.ENTRIES.size() - town_entries.size()).is_greater_equal(10)


func test_registry_has_one_directed_pair_for_each_building() -> void:
	assert_int(BuildingTransitionRegistry.ENTRIES.size()).is_equal(BUILDING_IDS.size())
	assert_int(BuildingTransitionRegistry.EXITS.size()).is_equal(BUILDING_IDS.size())
	assert_int(BuildingTransitionRegistry.ALL.size()).is_equal(BUILDING_IDS.size() * 2)
	var seen_ids: Dictionary = {}
	for transition: BuildingTransitionDefinition in BuildingTransitionRegistry.ALL:
		assert_bool(seen_ids.has(transition.id)).is_false()
		seen_ids[transition.id] = true
		assert_bool(LocationRegistry.is_gameplay_scene(transition.source_scene)).is_true()
		assert_bool(LocationRegistry.is_gameplay_scene(transition.destination_scene)).is_true()
		assert_bool(transition.source_anchor.is_empty()).is_false()
		var destination := LocationRegistry.resolve(
			transition.destination_scene, transition.destination_location_id
		)
		assert_object(destination).is_not_null()
		assert_str(destination.resolve_spawn(transition.spawn_id)).is_equal(
			String(transition.spawn_id)
		)

	for building_id: StringName in BUILDING_IDS:
		var entry := BuildingTransitionRegistry.entry_for(building_id)
		var exit := BuildingTransitionRegistry.exit_for(building_id)
		assert_object(entry).is_not_null()
		assert_object(exit).is_not_null()
		assert_bool(entry.is_entry()).is_true()
		assert_bool(exit.is_exit()).is_true()
		assert_str(entry.destination_scene).is_equal(exit.source_scene)
		assert_str(exit.destination_scene).is_equal(entry.source_scene)
		assert_str(exit.spawn_id).is_equal("from_" + String(building_id))
		var source_location := LocationRegistry.by_scene(entry.source_scene)
		assert_object(source_location).is_not_null()
		assert_str(exit.destination_location_id).is_equal(String(source_location.id))


func test_registry_preserves_quest_and_reputation_gates_on_entries_only() -> void:
	var bell_entry := BuildingTransitionRegistry.entry_for(&"bell_house")
	assert_str(bell_entry.required_flag).is_equal("dom_bell_quest_open")
	assert_str(bell_entry.reputation_faction).is_empty()
	assert_str(bell_entry.minimum_reputation_band).is_empty()

	var warehouse_entry := BuildingTransitionRegistry.entry_for(&"cask_warehouse")
	assert_str(warehouse_entry.required_flag).is_equal("dom_dishonest_casks_traced")
	var lower_trial_entry := BuildingTransitionRegistry.entry_for(&"lower_trial_hall")
	assert_str(lower_trial_entry.required_flag).is_equal("deep_trial_open")

	var yard_entry := BuildingTransitionRegistry.entry_for(&"garrison_yard")
	assert_str(yard_entry.reputation_faction).is_equal("iron-companies")
	assert_str(yard_entry.minimum_reputation_band).is_equal("warm")

	for transition: BuildingTransitionDefinition in BuildingTransitionRegistry.EXITS:
		assert_str(transition.required_flag).is_empty()
		assert_str(transition.reputation_faction).is_empty()
		assert_str(transition.minimum_reputation_band).is_empty()


func test_every_interior_location_resolves_its_entry_spawn() -> void:
	for transition: BuildingTransitionDefinition in BuildingTransitionRegistry.ENTRIES:
		var location := LocationRegistry.by_scene(transition.destination_scene)
		assert_object(location).is_not_null()
		assert_str(location.default_spawn_id).is_equal("entry")
		assert_str(location.resolve_spawn(&"entry")).is_equal("entry")
