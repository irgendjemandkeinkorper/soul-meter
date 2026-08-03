extends GdUnitTestSuite

const StableIdsScript := preload("res://globals/stable_ids.gd")


func test_manifest_covers_all_save_and_consequence_domains() -> void:
	var manifest: Dictionary = StableIdsScript.schema_manifest()
	assert_int(manifest.size()).is_equal(7)
	assert_array(manifest.keys()).contains(
		"actor", "quest", "skill", "item", "zone", "world_fact", "dialogue_node"
	)
	for schema: Variant in manifest.values():
		assert_str(schema["field"]).is_equal("id")
		assert_str(schema["format"]).is_equal("opaque non-empty identifier (no whitespace)")


func test_stable_ids_are_opaque_identifier_records() -> void:
	assert_bool(StableIdsScript.is_valid(StableIdsScript.ACTOR, "vex")).is_true()
	assert_bool(StableIdsScript.is_valid(StableIdsScript.DIALOGUE_NODE, "iris-start")).is_true()
	assert_bool(StableIdsScript.is_valid(StableIdsScript.SKILL, "sleight_of_hand")).is_true()
	assert_bool(StableIdsScript.is_valid(StableIdsScript.ITEM, "materials/loamroot_sprig")).is_true()
	assert_bool(StableIdsScript.is_valid(StableIdsScript.ITEM, "bad id")).is_false()
	assert_bool(StableIdsScript.is_valid_record(
		StableIdsScript.ZONE, StableIdsScript.zone("dom")
	)).is_true()
