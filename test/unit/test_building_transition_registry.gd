extends GdUnitTestSuite

const VALUE_FIXTURE := "res://test/fixtures/building_transitions_342.json"

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
	# Kesselford (hub 2, C1 / #238).
	&"kesselford_wayhouse",
	&"kesselford_chandlery",
	# Ashlaren (hub 3, C2 / #239).
	&"ashlaren_weighing_hall",
	&"ashlaren_millhouse",
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


## Captured before the #342 PR 3 migration, including every omitted script default.
## The fixture records its source revisions; the 48 resources were identical to main.
func test_generated_transitions_match_every_original_export_and_resource_header() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VALUE_FIXTURE))
	var resources: Array = fixture["resources"]
	assert_int(resources.size()).is_equal(48)
	var paths: Array[String] = []
	for row: Dictionary in resources:
		var path: String = row["path"]
		paths.append(path)
		var transition: BuildingTransitionDefinition = load(path) as BuildingTransitionDefinition
		assert_object(transition).override_failure_message(path).is_not_null()
		var fields: Dictionary = row["fields"]
		var exported: Array[String] = []
		for property: Dictionary in transition.get_property_list():
			var usage: int = int(property["usage"])
			if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
				exported.append(String(property["name"]))
		assert_array(exported).contains_exactly(fields.keys())
		for field: String in fields:
			var expected: Variant = str_to_var(fields[field])
			var actual: Variant = transition.get(field)
			var context: String = "%s: %s" % [path, field]
			assert_int(typeof(actual)).override_failure_message(context).is_equal(typeof(expected))
			assert_bool(actual == expected).override_failure_message(context).is_true()
		# Includes the resource UID when present; never silently replaces a scene reference.
		assert_str(FileAccess.get_file_as_string(path).get_slice("\n", 0)) \
			.override_failure_message(path).is_equal(row["header"])
	var committed: Array[String] = []
	for filename: String in DirAccess.get_files_at("res://actors/building_door/transitions"):
		if filename.ends_with(".tres"):
			committed.append("res://actors/building_door/transitions/" + filename)
	assert_array(committed).contains_exactly(paths)


func test_registry_lists_come_from_the_index_and_share_the_preloaded_instances() -> void:
	assert_int(BuildingTransitionRegistry.ENTRIES.size()).is_equal(24)
	assert_int(BuildingTransitionRegistry.EXITS.size()).is_equal(24)
	assert_int(BuildingTransitionRegistry.ALL.size()).is_equal(48)
	for entry: BuildingTransitionDefinition in BuildingTransitionRegistry.ENTRIES:
		assert_bool(entry.is_entry()).override_failure_message(String(entry.id)).is_true()
	for exit: BuildingTransitionDefinition in BuildingTransitionRegistry.EXITS:
		assert_bool(exit.is_exit()).override_failure_message(String(exit.id)).is_true()
	# GameFlow keys the garrison permission on this const; the index must yield the same object.
	assert_object(BuildingTransitionRegistry.by_id(&"garrison_yard_enter")) \
		.is_same(BuildingTransitionRegistry.GARRISON_YARD_ENTER)


func test_every_door_in_every_scene_resolves_its_transition() -> void:
	var pending: Array[String] = ["res://world"]
	var doors: int = 0
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		for child: String in DirAccess.get_directories_at(directory):
			pending.append(directory.path_join(child))
		for filename: String in DirAccess.get_files_at(directory):
			if filename.get_extension() != "tscn":
				continue
			var path: String = directory.path_join(filename)
			for line: String in FileAccess.get_file_as_string(path).split("\n"):
				# Town doors export `transition_id`; an interior's root exports its `exit_transition_id`.
				var value: String = line.get_slice(" = ", 1)
				if not (line.begins_with("transition_id = ") or line.begins_with("exit_transition_id = ")):
					continue
				doors += 1
				var transition_id: StringName = str_to_var(value)
				assert_object(BuildingTransitionRegistry.by_id(transition_id)) \
					.override_failure_message("%s: %s" % [path, transition_id]).is_not_null()
	assert_int(doors).is_equal(BuildingTransitionRegistry.ALL.size())
