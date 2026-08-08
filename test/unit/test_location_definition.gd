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


func test_spawns_authored_with_stringname_keys_also_resolve() -> void:
	# Godot 4 hashes StringName and String alike, so spawns.has(String(...))
	# still matches a dictionary authored with &"" keys. Locked down because
	# resolve_spawn() converts one way only and a regression here would
	# silently send every named arrival to the default marker.
	var location := LocationDefinition.new()
	location.default_spawn_id = &"fallback_marker"
	location.spawns = {&"from_dom": "west_gate"}

	assert_str(String(location.resolve_spawn(&"from_dom"))).is_equal("west_gate")


func test_an_empty_spawn_request_falls_back_to_default_spawn_id() -> void:
	var location := LocationDefinition.new()
	location.default_spawn_id = &"fallback_marker"
	location.spawns = {"from_dorthkor": "east_gate"}

	assert_str(String(location.resolve_spawn(&""))).is_equal("fallback_marker")


func test_an_unset_default_spawn_id_resolves_an_unknown_request_to_an_empty_name() -> void:
	# resolve_spawn() never invents a marker: a chapter that cleared its
	# default_spawn_id gets an empty StringName back, not &"default".
	var location := LocationDefinition.new()
	location.default_spawn_id = &""

	assert_str(String(location.resolve_spawn(&"nonexistent"))).is_equal("")


func test_a_resolved_named_spawn_is_returned_as_a_stringname() -> void:
	# spawns values are authored as plain Strings; the return contract is
	# StringName, so the conversion must happen inside resolve_spawn().
	var location := LocationDefinition.new()
	location.spawns = {"from_dorthkor": "east_gate"}
	var resolved: Variant = location.resolve_spawn(&"from_dorthkor")

	assert_int(typeof(resolved)).is_equal(TYPE_STRING_NAME)


func test_allowed_gameplay_can_be_turned_off_for_a_non_gameplay_destination() -> void:
	var location := LocationDefinition.new()
	location.allowed_gameplay = false

	assert_bool(location.allowed_gameplay).is_false()
	# Turning gameplay off is a registry-level concern; it must not disturb
	# spawn resolution on the definition itself.
	assert_str(String(location.resolve_spawn(&"default"))).is_equal("default")
