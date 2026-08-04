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
]


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
		assert_str(exit.destination_scene).is_equal(GameFlow.TOWN_SCENE)
		assert_str(exit.spawn_id).is_equal("from_" + String(building_id))


func test_bell_house_preserves_the_existing_quest_flag_gate() -> void:
	var bell_entry := BuildingTransitionRegistry.entry_for(&"bell_house")
	assert_str(bell_entry.required_flag).is_equal("dom_bell_quest_open")
	assert_str(bell_entry.reputation_faction).is_empty()
	assert_str(bell_entry.minimum_reputation_band).is_empty()
	for transition: BuildingTransitionDefinition in BuildingTransitionRegistry.ENTRIES:
		if transition.building_id != &"bell_house":
			assert_str(transition.required_flag).is_empty()


func test_every_interior_location_resolves_its_entry_spawn() -> void:
	for transition: BuildingTransitionDefinition in BuildingTransitionRegistry.ENTRIES:
		var location := LocationRegistry.by_scene(transition.destination_scene)
		assert_object(location).is_not_null()
		assert_str(location.default_spawn_id).is_equal("entry")
		assert_str(location.resolve_spawn(&"entry")).is_equal("entry")
