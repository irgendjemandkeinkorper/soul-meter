extends GdUnitTestSuite


func test_macro_locations_use_location_registry_scenes_and_normalized_coordinates() -> void:
	var expected_scenes := {
		&"dom": LocationRegistry.DOM.scene_path,
		&"wilds": LocationRegistry.WILDS.scene_path,
		&"dorthkor-road": LocationRegistry.DORTHKOR.scene_path,
		&"wound-lip": LocationRegistry.WOUND_LIP.scene_path,
	}
	var locations := WorldMapRegistry.all_locations()
	assert_int(locations.size()).is_equal(4)
	for location: Dictionary in locations:
		var location_id := StringName(location["id"])
		var coordinate: Vector2 = location["map_coordinate"]
		assert_str(str(location["scene_path"])).is_equal(str(expected_scenes[location_id]))
		assert_bool(coordinate.x >= 0.0 and coordinate.x <= 1.0).is_true()
		assert_bool(coordinate.y >= 0.0 and coordinate.y <= 1.0).is_true()


func test_routes_are_read_only_copies_with_valid_existing_encounters() -> void:
	var routes := WorldMapRegistry.all_routes()
	assert_int(routes.size()).is_equal(3)
	routes[0]["phases_cost"] = -1
	assert_int(int(WorldMapRegistry.all_routes()[0]["phases_cost"])).is_greater(0)

	for route: Dictionary in WorldMapRegistry.all_routes():
		assert_bool(WorldMapRegistry.location(route["origin_id"]).is_empty()).is_false()
		assert_bool(WorldMapRegistry.location(route["destination_id"]).is_empty()).is_false()
		assert_int(int(route["min_encounters"])).is_greater_equal(0)
		assert_int(int(route["max_encounters"])).is_greater_equal(int(route["min_encounters"]))
		for entry: Dictionary in route["encounter_table"]:
			assert_dict(EncounterCatalog.definition(entry["encounter_id"])).is_not_empty()
			assert_int(int(entry["weight"])).is_greater(0)


func test_route_lookup_is_bidirectional() -> void:
	var forward := WorldMapRegistry.route_between(&"dom", &"dorthkor-road")
	var reverse := WorldMapRegistry.route_between(&"dorthkor-road", &"dom")
	assert_dict(forward).is_not_empty()
	assert_dict(reverse).is_equal(forward)
