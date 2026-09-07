extends GdUnitTestSuite


func test_current_locations_are_registered_as_gameplay_only() -> void:
	assert_int(LocationRegistry.ALL.size()).is_equal(25)
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
	# The four macro locations are the swept rows. A fifth location authored
	# off the rule is allowed (§3 says so) but has to be deliberate, so this
	# names the four rather than looping the registry.
	var expected := {
		&"dom": 95.0, &"wilds": 85.0, &"dorthkor_road": 70.0, &"wound_lip": 55.0,
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


func test_dom_interiors_inherit_their_hub_accord() -> void:
	# §3: interiors are not on the wilds->front axis, so they take the hub's
	# value. Without this a Dom interior would cast better than Dom's street.
	var dom := LocationRegistry.by_id(&"dom")
	for location in LocationRegistry.ALL:
		if not location.scene_path.contains("/interiors/"):
			continue
		assert_float(location.harmonic_accord).override_failure_message(
			"interior '%s' does not match Dom's accord" % location.id
		).is_equal(dom.harmonic_accord)
		assert_int(location.thinning_tier).override_failure_message(
			"interior '%s' carries a thinning tier; interiors are off the axis" % location.id
		).is_zero()


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
