extends GdUnitTestSuite

var _saved_units: Dictionary[String, Dictionary]


func before_test() -> void:
	UnitFrames._ensure_loaded()
	_saved_units = UnitFrames._units
	UnitFrames._units = _saved_units.duplicate(true)


func after_test() -> void:
	UnitFrames._units = _saved_units


func test_untagged_manifest_preserves_every_existing_crowd_choice() -> void:
	for hub_id: String in TownNpcSpawner.HUB_RACE_MIX:
		for index: int in UnitArt.FALLBACK_POOL.size():
			var fallback := UnitArt.FALLBACK_POOL[index]
			assert_str(TownNpcSpawner.crowd_unit_for(hub_id, "npc-%d" % index, fallback)).is_equal(fallback)


func test_empty_and_unknown_hubs_keep_the_old_choice_even_when_race_art_exists() -> void:
	_tag("crowd-guard-a", "ghorr")
	for hub_id: String in ["ashlaren", "kesselford", "long_verge", "hollowmere", "unknown", ""]:
		assert_str(TownNpcSpawner.crowd_unit_for(hub_id, "legacy", "crowd-beggar-a")).is_equal("crowd-beggar-a")


func test_dom_selects_only_available_matching_race_tagged_crowd_units() -> void:
	_tag("crowd-guard-a", "ghorr")
	_tag("crowd-guard-b", "ghorr")
	_tag("vex", "ghorr")  # Named art is never a crowd candidate.
	_tag("crowd-merchant-a", "unconfigured-race")
	for index: int in 100:
		var unit_id := TownNpcSpawner.crowd_unit_for("dom", "npc-%d" % index, "crowd-beggar-a")
		assert_bool(unit_id in ["crowd-guard-a", "crowd-guard-b"]).is_true()
		assert_str(TownNpcSpawner.crowd_unit_for("dom", "npc-%d" % index, "crowd-beggar-a")).is_equal(unit_id)


func test_race_weight_is_independent_of_the_number_of_variants() -> void:
	_tag("crowd-guard-a", "ghorr")
	_tag("crowd-guard-b", "ghorr")
	_tag("crowd-guard-c", "ghorr")
	_tag("crowd-acolyte-a", "vael")
	_tag("crowd-laborer-a", "kaan")
	_tag("crowd-dockworker-a", "kes-reth")
	_tag("crowd-merchant-a", "orthos")
	var counts: Dictionary[String, int] = {}
	for index: int in 2000:
		var unit_id := TownNpcSpawner.crowd_unit_for("dom", "npc-%d" % index, "crowd-beggar-a")
		var race_id := str(UnitFrames.metadata_for(unit_id)["race_id"])
		counts[race_id] = int(counts.get(race_id, 0)) + 1
	var mix: Dictionary = TownNpcSpawner.HUB_RACE_MIX["dom"]
	for race_id: String in mix:
		assert_float(float(counts.get(race_id, 0)) / 20.0).is_equal_approx(float(mix[race_id]), 5.0)


func _tag(unit_id: String, race_id: String) -> void:
	UnitFrames._units[unit_id]["metadata"]["race_id"] = race_id
