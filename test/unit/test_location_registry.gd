extends GdUnitTestSuite


func test_current_locations_are_registered_as_gameplay_only() -> void:
	# 25 Dom-era locations plus Kesselford and its two interiors (C1 / #238), Ashlaren and
	# its two interiors (C2 / #239), and The Long Verge (C3 / #240).
	assert_int(LocationRegistry.ALL.size()).is_equal(32)
	for location in LocationRegistry.ALL:
		assert_bool(location.allowed_gameplay).is_true()
		assert_bool(LocationRegistry.is_gameplay_scene(location.scene_path)).is_true()
	assert_array(GameFlow.GAMEPLAY_SCENES).contains_exactly(LocationRegistry.gameplay_scenes())


func test_named_arrivals_resolve_to_valid_spawn_markers() -> void:
	assert_str(LocationRegistry.by_id(&"dom").resolve_spawn(&"from_dorthkor")).is_equal(
		"from_dorthkor"
	)
	assert_str(LocationRegistry.by_scene(GameFlow.DORTHKOR_SCENE).resolve_spawn(&"from_dom")).is_equal(
		"from_dom"
	)
	assert_str(LocationRegistry.by_scene(GameFlow.WILDS_SCENE).resolve_spawn(&"unknown")).is_equal(
		"default"
	)


func test_unregistered_scene_is_not_a_valid_travel_target() -> void:
	assert_object(LocationRegistry.by_scene("res://ui/screens/main_menu.tscn")).is_null()
	assert_bool(LocationRegistry.is_gameplay_scene("res://ui/screens/main_menu.tscn")).is_false()


## --- FR-506 thinning gradient (#258, option B) --------------------------------

## `docs/thinning-gradient.md` §3. The authored accord is NOT a linear series —
## it is whatever puts a location's EFFECTIVE accord on a row the casting sweep
## actually measured, after option B's per-tier penalty is subtracted again.
const SWEPT_EFFECTIVE: Array[float] = [95.0, 80.0, 60.0, 40.0]


func test_the_authored_accord_matches_the_ratified_rule() -> void:
	# The four Dom-era macro locations are the swept rows; Kesselford (hub 2,
	# C1 / #238) sits at tier 1 and takes its accord from the rule. A location
	# authored off the rule is allowed (§3 says so) but has to be deliberate, so
	# this names them rather than looping the registry.
	var expected := {
		&"dom": 95.0, &"wilds": 85.0, &"dorthkor_road": 70.0, &"wound_lip": 55.0,
		&"kesselford": 85.0,
		# Ashlaren (hub 3, C2 / #239) is tier 0: the grain road's last working market.
		&"ashlaren": 95.0,
	}
	for location_id: StringName in expected:
		var location := LocationRegistry.by_id(location_id)
		assert_object(location).override_failure_message(
			"macro location '%s' is not registered" % location_id
		).is_not_null()
		assert_float(location.harmonic_accord).override_failure_message(
			"'%s' accord drifted from docs/thinning-gradient.md §3" % location_id
		).is_equal(float(expected[location_id]))
		var tier := location.thinning_tier
		assert_float(location.harmonic_accord).override_failure_message(
			"'%s' is no longer `swept_effective[%d] + 5 x %d`" % [location_id, tier, tier]
		).is_equal(
			SWEPT_EFFECTIVE[tier]
			+ SkillCheck.THINNING_INTEGRITY_PENALTY_PER_TIER * float(tier)
		)


func test_no_location_still_carries_the_neutral_default() -> void:
	# Option B keeps the tier penalty stacking on top of the authored accord, so
	# an unauthored 100.0 is not "neutral" — it is a location the gradient
	# forgot, and it will cast MORE reliably than the hub it sits inside.
	for location in LocationRegistry.ALL:
		assert_float(location.harmonic_accord).override_failure_message(
			"'%s' still has the default accord; every location is on the gradient"
			% location.id
		).is_not_equal(100.0)


func test_interiors_inherit_their_hub_accord() -> void:
	# §3: interiors are not on the wilds->front axis, so they take their hub's
	# value. Without this an interior would cast better than the street outside
	# it. The hub is whatever the interior's exit door chain finally reaches.
	for location in LocationRegistry.ALL:
		if not location.scene_path.contains("/interiors/"):
			continue
		var hub := _hub_of(location)
		assert_object(hub).override_failure_message(
			"interior '%s' has no exit chain back to a hub" % location.id
		).is_not_null()
		assert_float(location.harmonic_accord).override_failure_message(
			"interior '%s' does not match its hub's accord" % location.id
		).is_equal(hub.harmonic_accord)
		assert_int(location.thinning_tier).override_failure_message(
			"interior '%s' carries a thinning tier; interiors are off the axis" % location.id
		).is_zero()


## Follows exit transitions (loft -> house -> street) until the scene is no longer an interior.
## An interior with no door of its own (the Four Arms tavern is entered by the quest flow) is Dom's.
func _hub_of(location: LocationDefinition) -> LocationDefinition:
	var current := location
	for _hop: int in 4:
		var exit: BuildingTransitionDefinition = null
		for transition in BuildingTransitionRegistry.EXITS:
			if transition.source_scene == current.scene_path:
				exit = transition
				break
		if exit == null:
			return LocationRegistry.by_id(&"dom") if current == location else null
		current = LocationRegistry.by_id(exit.destination_location_id)
		if current == null:
			return null
		if not current.scene_path.contains("/interiors/"):
			return current
	return null


func test_the_effective_accord_lands_on_a_swept_row() -> void:
	# The reason the authored numbers are 95/85/70/55 and not 95/80/60/40: under
	# option B the tier penalty still applies, and every number a player MEETS
	# has to be one `tools/casting_economy_sweep.gd` actually measured.
	var swept := [95.0, 80.0, 60.0, 40.0]
	for location_id: StringName in [&"dom", &"wilds", &"dorthkor_road", &"wound_lip"]:
		var location := LocationRegistry.by_id(location_id)
		var effective := SkillCheck.location_fizzle_integrity(
			location.harmonic_accord, location.scene_path
		)
		assert_bool(swept.has(effective)).override_failure_message(
			"'%s' resolves to %s, which the casting sweep never measured (rows: %s)"
			% [location_id, effective, swept]
		).is_true()


## --- E3.3b (#342): the registry reads the baked index --------------------------

func after_test() -> void:
	LocationRegistry._clear_runtime()


func _index_rows() -> Array[Dictionary]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LocationRegistry.INDEX_PATH))
	assert_bool(parsed is Dictionary).is_true()
	var rows: Array[Dictionary] = []
	for row: Variant in (parsed as Dictionary)["locations"]:
		if not str((row as Dictionary)["definition_path"]).is_empty():
			rows.append(row as Dictionary)
	return rows


func test_all_is_exactly_the_index_rows_that_have_a_scene() -> void:
	var rows: Array[Dictionary] = _index_rows()
	assert_int(LocationRegistry.ALL.size()).is_equal(rows.size())
	for index: int in rows.size():
		var location: LocationDefinition = LocationRegistry.ALL[index]
		assert_str(String(location.id)).is_equal(str(rows[index]["id"]))
		assert_str(location.scene_path).is_equal(str(rows[index]["scene_path"]))
		assert_str(location.resource_path).is_equal(str(rows[index]["definition_path"]))


func test_named_consts_are_the_same_resources_the_index_loads() -> void:
	var constants: Dictionary = (load("res://globals/location_registry.gd") as Script).get_script_constant_map()
	var named := 0
	for constant_name: String in constants:
		var value: Variant = constants[constant_name]
		if value is LocationDefinition:
			named += 1
			assert_bool(LocationRegistry.ALL.has(value)).override_failure_message(
				"%s is not the instance in LocationRegistry.ALL" % constant_name
			).is_true()
			assert_object(LocationRegistry.by_id((value as LocationDefinition).id)).is_same(value)
	assert_int(named).is_equal(LocationRegistry.ALL.size())


func test_no_combat_zone_is_read_from_canon_and_matches_the_old_prefix_rule() -> void:
	for row: Dictionary in _index_rows():
		var scene_path := str(row["scene_path"])
		assert_bool(LocationRegistry.no_combat_zone_by_scene(scene_path)).override_failure_message(
			scene_path
		).is_equal(bool(row["no_combat_zone"]))
		# Players see no change: canon agrees with the rule the runtime used before #342.
		assert_bool(bool(row["no_combat_zone"])).override_failure_message(scene_path).is_equal(
			scene_path.begins_with("res://world/interiors/")
		)
	# An unindexed scene keeps the prefix rule.
	assert_bool(LocationRegistry.no_combat_zone_by_scene("res://world/interiors/unbaked.tscn")).is_true()
	assert_bool(LocationRegistry.no_combat_zone_by_scene("res://world/unbaked.tscn")).is_false()


func _runtime_definition(location_id: StringName, scene_path: String) -> LocationDefinition:
	var definition := LocationDefinition.new()
	definition.id = location_id
	definition.scene_path = scene_path
	definition.spawns = {"from_dom": "from_dom"}
	return definition


func test_register_runtime_makes_an_unbaked_scene_a_travel_target() -> void:
	var scene_path := "user://weftlumin/test-package/scenes/unbaked_grove.tscn"
	var changes: Array[int] = [0]
	var count_change := func() -> void: changes[0] += 1
	LocationRegistry.locations_changed.connect(count_change)
	var baked_size := LocationRegistry.ALL.size()
	assert_bool(LocationRegistry.is_gameplay_scene(scene_path)).is_false()

	var definition := _runtime_definition(&"unbaked-grove", scene_path)
	assert_bool(LocationRegistry.register_runtime(definition)).is_true()

	assert_int(changes[0]).is_equal(1)
	assert_object(LocationRegistry.by_id(&"unbaked-grove")).is_same(definition)
	assert_object(LocationRegistry.by_scene(scene_path)).is_same(definition)
	assert_object(LocationRegistry.resolve(scene_path, &"unbaked-grove")).is_same(definition)
	assert_str(LocationRegistry.by_scene(scene_path).resolve_spawn(&"from_dom")).is_equal("from_dom")
	assert_bool(LocationRegistry.is_gameplay_scene(scene_path)).is_true()
	assert_array(LocationRegistry.gameplay_scenes()).contains([scene_path])
	assert_array(GameFlow.GAMEPLAY_SCENES).contains([scene_path])
	assert_int(LocationRegistry.ALL.size()).override_failure_message(
		"the runtime overlay must not change the baked set"
	).is_equal(baked_size)

	# Re-registering the same id replaces the overlay entry instead of duplicating it.
	var revised := _runtime_definition(&"unbaked-grove", scene_path)
	assert_bool(LocationRegistry.register_runtime(revised)).is_true()
	assert_object(LocationRegistry.by_id(&"unbaked-grove")).is_same(revised)
	assert_int(LocationRegistry.gameplay_scenes().count(scene_path)).is_equal(1)

	LocationRegistry._clear_runtime()
	assert_bool(LocationRegistry.is_gameplay_scene(scene_path)).is_false()
	assert_array(GameFlow.GAMEPLAY_SCENES).not_contains([scene_path])
	LocationRegistry.locations_changed.disconnect(count_change)


func test_register_runtime_refuses_incomplete_or_baked_locations() -> void:
	var changes: Array[int] = [0]
	var count_change := func() -> void: changes[0] += 1
	LocationRegistry.locations_changed.connect(count_change)
	assert_bool(LocationRegistry.register_runtime(null)).is_false()
	assert_bool(LocationRegistry.register_runtime(_runtime_definition(&"", "user://x.tscn"))).is_false()
	assert_bool(LocationRegistry.register_runtime(_runtime_definition(&"no-scene", ""))).is_false()
	assert_bool(LocationRegistry.register_runtime(
		_runtime_definition(LocationRegistry.DOM.id, "user://elsewhere.tscn")
	)).is_false()
	assert_bool(LocationRegistry.register_runtime(
		_runtime_definition(&"shadow-dom", LocationRegistry.DOM.scene_path)
	)).is_false()
	assert_object(LocationRegistry.by_id(LocationRegistry.DOM.id)).is_same(LocationRegistry.DOM)
	assert_object(LocationRegistry.by_scene(LocationRegistry.DOM.scene_path)).is_same(LocationRegistry.DOM)
	assert_int(changes[0]).is_zero()
	LocationRegistry.locations_changed.disconnect(count_change)


## Architecture §5 overlay boundary: a runtime registration writes nothing under canon/ or the index.
func test_register_runtime_leaves_canon_and_the_index_byte_identical() -> void:
	var before := _canon_hashes()
	assert_bool(LocationRegistry.register_runtime(
		_runtime_definition(&"boundary-probe", "user://weftlumin/probe/scenes/probe.tscn")
	)).is_true()
	assert_dict(_canon_hashes()).is_equal(before)


func _canon_hashes() -> Dictionary:
	var hashes: Dictionary = {LocationRegistry.INDEX_PATH: FileAccess.get_md5(LocationRegistry.INDEX_PATH)}
	for hub: String in DirAccess.get_directories_at("res://canon"):
		var directory := "res://canon".path_join(hub).path_join("locations")
		if not DirAccess.dir_exists_absolute(directory):
			continue
		for filename: String in DirAccess.get_files_at(directory):
			var path := directory.path_join(filename)
			hashes[path] = FileAccess.get_md5(path)
	assert_int(hashes.size()).is_greater(1)
	return hashes
