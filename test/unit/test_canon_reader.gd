extends GdUnitTestSuite

const SeedPandora := preload("res://tools/seed_pandora.gd")


func test_load_returns_all_factions_with_unique_stable_ids() -> void:
	var factions: Array[Dictionary] = SeedPandora.CanonReader.load("factions")
	var stable_ids: Dictionary = {}

	assert_int(factions.size()).is_equal(18)
	for faction: Dictionary in factions:
		assert_str(faction.get("schema", "")).is_equal("weftlumin.faction.v1")
		assert_str(faction.get("id", "")).is_not_empty()
		assert_bool(stable_ids.has(faction["id"])).is_false()
		stable_ids[faction["id"]] = true


func test_load_is_deterministic() -> void:
	var first_load: Array[Dictionary] = SeedPandora.CanonReader.load("factions")
	var second_load: Array[Dictionary] = SeedPandora.CanonReader.load("factions")

	assert_array(first_load).is_equal(second_load)


func test_faction_reseed_upserts_instead_of_creating_duplicates() -> void:
	if not Pandora.is_loaded():
		Pandora.load_data()
	var faction_root: PandoraCategory = _faction_root()
	var before_count: int = Pandora.get_all_entities(faction_root).size()
	var seeder: Node = SeedPandora.new()

	seeder._seed_factions()

	var after_count: int = Pandora.get_all_entities(faction_root).size()
	assert_int(after_count).is_equal(before_count)
	seeder.free()


func _faction_root() -> PandoraCategory:
	for root: PandoraCategory in Pandora.get_all_roots():
		if root.get_entity_name() == "Factions":
			return root
	return null
