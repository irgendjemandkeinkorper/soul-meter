extends GdUnitTestSuite
## Dedicated coverage for globals/location_definition.gd (issue #71).
## test_location_registry.gd exercises real, data-driven LocationDefinition instances;
## this suite isolates resolve_spawn()'s own branching with synthetic fixtures.


func test_defaults_are_empty_id_and_a_default_spawn() -> void:
	var location := LocationDefinition.new()

	assert_str(String(location.id)).is_equal("")
	assert_str(location.scene_path).is_equal("")
	assert_bool(location.allowed_gameplay).is_true()
	assert_str(String(location.default_spawn_id)).is_equal("default")
	assert_bool(location.spawns.is_empty()).is_true()
	assert_str(location.arrival_flag).is_equal("")
	assert_str(location.arrival_checkpoint).is_equal("")


func test_requesting_the_default_marker_resolves_to_default_spawn_id_even_if_registered() -> void:
	var location := LocationDefinition.new()
	location.default_spawn_id = &"custom_default"
	location.spawns = {"default": "should_be_ignored"}

	# &"default" is a sentinel, not a lookup key: it always resolves to
	# default_spawn_id, never through the spawns dictionary.
	assert_str(String(location.resolve_spawn(&"default"))).is_equal("custom_default")


func test_a_registered_named_spawn_resolves_through_the_spawns_dictionary() -> void:
	var location := LocationDefinition.new()
	location.spawns = {"from_dorthkor": "east_gate"}

	assert_str(String(location.resolve_spawn(&"from_dorthkor"))).is_equal("east_gate")


func test_an_unregistered_named_spawn_falls_back_to_default_spawn_id() -> void:
	var location := LocationDefinition.new()
	location.default_spawn_id = &"fallback_marker"
	location.spawns = {"from_dorthkor": "east_gate"}

	assert_str(String(location.resolve_spawn(&"nonexistent"))).is_equal("fallback_marker")


func test_spawn_lookup_is_keyed_by_string_not_stringname_identity() -> void:
	var location := LocationDefinition.new()
	# Authored .tres data stores plain String keys; resolve_spawn must still
	# match a StringName request against them.
	location.spawns = {"east_gate": "east_gate_marker"}

	assert_str(String(location.resolve_spawn(&"east_gate"))).is_equal("east_gate_marker")
