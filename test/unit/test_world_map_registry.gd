extends GdUnitTestSuite

const DOM_ID: StringName = &"dom"
const WILDS_ID: StringName = &"wilds"
const DORTHKOR_ROAD_ID: StringName = &"dorthkor_road"
const WOUND_LIP_ID: StringName = &"wound_lip"
## Hub 2 (C1 / #238); the id is the LocationRegistry / fast-travel id.
const KESSELFORD_ID: StringName = &"kesselford"
## Hub 3 (C2 / #239): the grain-road market town past Kesselford.
const ASHLAREN_ID: StringName = &"ashlaren"
## Location 7 (C3 / #240): the high moor-road between Dom and the ford country. Wilds, not a hub.
const LONG_VERGE_ID: StringName = &"long_verge"
## Location 8 (C4 / #241): the drowned mere past the Dorthkor Road, where the front's weather is
## read early. Wilds, not a hub.
const HOLLOWMERE_ID: StringName = &"hollowmere"


func test_macro_locations_use_location_registry_scenes_and_normalized_coordinates() -> void:
	var expected_scenes := {
		&"dom": LocationRegistry.DOM.scene_path,
		&"wilds": LocationRegistry.WILDS.scene_path,
		&"dorthkor_road": LocationRegistry.DORTHKOR.scene_path,
		&"wound_lip": LocationRegistry.WOUND_LIP.scene_path,
		&"kesselford": LocationRegistry.KESSELFORD.scene_path,
		&"ashlaren": LocationRegistry.ASHLAREN.scene_path,
		&"long_verge": LocationRegistry.LONG_VERGE.scene_path,
		&"hollowmere": LocationRegistry.HOLLOWMERE.scene_path,
	}
	var locations := WorldMapRegistry.all_locations()
	assert_int(locations.size()).is_equal(8)
	for location: Dictionary in locations:
		var location_id := StringName(location["id"])
		var coordinate: Vector2 = location["map_coordinate"]
		assert_str(str(location["scene_path"])).is_equal(str(expected_scenes[location_id]))
		assert_bool(coordinate.x >= 0.0 and coordinate.x <= 1.0).is_true()
		assert_bool(coordinate.y >= 0.0 and coordinate.y <= 1.0).is_true()


func test_routes_are_read_only_copies_with_valid_existing_encounters() -> void:
	var routes := WorldMapRegistry.all_routes()
	assert_int(routes.size()).is_equal(8)
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
	var forward := WorldMapRegistry.route_between(&"dom", &"dorthkor_road")
	var reverse := WorldMapRegistry.route_between(&"dorthkor_road", &"dom")
	assert_dict(forward).is_not_empty()
	assert_dict(reverse).is_equal(forward)


func test_index_matches_the_pre_migration_tables_field_by_field() -> void:
	for pair: Array in [
		[WorldMapRegistry.all_locations(), _expected_location_rows()],
		[WorldMapRegistry.all_routes(), _expected_route_rows()],
	]:
		var actual: Array = pair[0]
		var expected: Array = pair[1]
		assert_int(actual.size()).is_equal(expected.size())
		actual.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
		expected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
		for index: int in expected.size():
			assert_dict(actual[index]).override_failure_message(str(expected[index]["id"])).is_equal(expected[index])
			_assert_value_types(actual[index], expected[index])


func _assert_value_types(actual: Variant, expected: Variant) -> void:
	assert_int(typeof(actual)).is_equal(typeof(expected))
	if expected is Dictionary:
		for key: Variant in expected:
			_assert_value_types(actual[key], expected[key])
	elif expected is Array:
		for index: int in expected.size():
			_assert_value_types(actual[index], expected[index])


# Frozen from the pre-index registry; only the three location-id spellings changed.
static func _expected_location_rows() -> Array[Dictionary]:
	# Coordinates are normalized map-space values, independent of viewport size.
	return [
		{
			"id": DOM_ID,
			"scene_path": LocationRegistry.DOM.scene_path,
			"map_coordinate": Vector2(0.45, 0.55),
		},
		{
			"id": WILDS_ID,
			"scene_path": LocationRegistry.WILDS.scene_path,
			"map_coordinate": Vector2(0.15, 0.75),
		},
		{
			"id": DORTHKOR_ROAD_ID,
			"scene_path": LocationRegistry.DORTHKOR.scene_path,
			"map_coordinate": Vector2(0.65, 0.25),
		},
		{
			"id": WOUND_LIP_ID,
			"scene_path": LocationRegistry.WOUND_LIP.scene_path,
			"map_coordinate": Vector2(0.85, 0.55),
		},
		{
			# West of Dom along the inland road, at the river crossing (vault proposal).
			"id": KESSELFORD_ID,
			"scene_path": LocationRegistry.KESSELFORD.scene_path,
			"map_coordinate": Vector2(0.2, 0.4),
		},
		{
			# Past Kesselford on the grain road, inland toward the Ghorr fields (vault proposal).
			"id": ASHLAREN_ID,
			"scene_path": LocationRegistry.ASHLAREN.scene_path,
			"map_coordinate": Vector2(0.1, 0.22),
		},
		{
			# The exposed moor-road the Company columns march between Dom and the ford country
			# (vault proposal): above the river valley the Ford Road follows.
			"id": LONG_VERGE_ID,
			"scene_path": LocationRegistry.LONG_VERGE.scene_path,
			"map_coordinate": Vector2(0.32, 0.4),
		},
		{
			# The quiet mere on the front-ward side of the wilds (vault proposal): off the Dorthkor
			# Road, short of the Wound Lip, where the Agreement reads lower than anywhere near Dom.
			"id": HOLLOWMERE_ID,
			"scene_path": LocationRegistry.HOLLOWMERE.scene_path,
			"map_coordinate": Vector2(0.78, 0.32),
		},
	]


static func _expected_route_rows() -> Array[Dictionary]:
	# Route values are mechanical tuning, not additional encounter or lore content.
	return [
		{
			"id": &"dom-wilds",
			"origin_id": DOM_ID,
			"destination_id": WILDS_ID,
			"steps": 8,
			"phases_cost": 2,
			"risk_tier": &"low",
			"risk_modifier": 5.0,
			"encounter_table": [
				{"encounter_id": &"loam-boar", "weight": 3},
				{"encounter_id": &"bog-wight", "weight": 1},
			],
			"min_encounters": 0,
			"max_encounters": 1,
		},
		{
			"id": &"dom-dorthkor_road",
			"origin_id": DOM_ID,
			"destination_id": DORTHKOR_ROAD_ID,
			"steps": 12,
			"phases_cost": 3,
			"risk_tier": &"moderate",
			"risk_modifier": 15.0,
			"encounter_table": [
				{"encounter_id": &"loam-boar", "weight": 2},
				{"encounter_id": &"dorthkor-vanguard", "weight": 1},
			],
			# PROVISIONAL: tune after encounter-frequency playtests. Neutral keeps base weights.
			"band_encounter_weights": {
				"faction_id": &"iron-companies",
				"bands": {
					&"hostile": {&"dorthkor-vanguard": 3},
					&"cold": {&"dorthkor-vanguard": 2},
					&"warm": {&"dorthkor-vanguard": 1},
					&"allied": {&"dorthkor-vanguard": 0},
				},
			},
			"min_encounters": 1,
			"max_encounters": 2,
		},
		{
			"id": &"dom-wound_lip",
			"origin_id": DOM_ID,
			"destination_id": WOUND_LIP_ID,
			"steps": 16,
			"phases_cost": 4,
			"risk_tier": &"high",
			"risk_modifier": 30.0,
			"encounter_table": [
				{"encounter_id": &"bog-wight", "weight": 2},
				{"encounter_id": &"dorthkor-vanguard", "weight": 2},
			],
			"min_encounters": 1,
			"max_encounters": 3,
		},
		{
			# PROVISIONAL (C1 / #238): a kept road between two hubs, longer than the Wilds walk
			# but no riskier; tune after encounter-frequency playtests.
			"id": &"dom-kesselford",
			"origin_id": DOM_ID,
			"destination_id": KESSELFORD_ID,
			"steps": 10,
			"phases_cost": 2,
			"risk_tier": &"low",
			"risk_modifier": 5.0,
			"encounter_table": [
				{"encounter_id": &"loam-boar", "weight": 2},
				{"encounter_id": &"bog-wight", "weight": 1},
			],
			"min_encounters": 0,
			"max_encounters": 1,
		},
		{
			# PROVISIONAL (C2 / #239): the grain road between Kesselford and Ashlaren, a shorter and
			# busier stretch than the Dom road. Tune after encounter-frequency playtests.
			"id": &"kesselford-ashlaren",
			"origin_id": KESSELFORD_ID,
			"destination_id": ASHLAREN_ID,
			"steps": 8,
			"phases_cost": 2,
			"risk_tier": &"low",
			"risk_modifier": 5.0,
			"encounter_table": [
				{"encounter_id": &"loam-boar", "weight": 3},
				{"encounter_id": &"bog-wight", "weight": 1},
			],
			"min_encounters": 0,
			"max_encounters": 1,
		},
		{
			# PROVISIONAL (C3 / #240): the high road out of Dom onto the Verge. Half the Ford Road's
			# length, but the Agreement thins in streaks up here, so the dead walk it more often
			# than boars do. Tune after encounter-frequency playtests.
			"id": &"dom-long_verge",
			"origin_id": DOM_ID,
			"destination_id": LONG_VERGE_ID,
			"steps": 6,
			"phases_cost": 1,
			"risk_tier": &"moderate",
			"risk_modifier": 10.0,
			"encounter_table": [
				{"encounter_id": &"bog-wight", "weight": 2},
				{"encounter_id": &"loam-boar", "weight": 1},
			],
			"min_encounters": 0,
			"max_encounters": 1,
		},
		{
			# PROVISIONAL (C3 / #240): the moor track down from the Verge into the ford country.
			# The same stretch the Companies march; the Ford Road below stays the kept road.
			"id": &"long_verge-kesselford",
			"origin_id": LONG_VERGE_ID,
			"destination_id": KESSELFORD_ID,
			"steps": 6,
			"phases_cost": 1,
			"risk_tier": &"low",
			"risk_modifier": 5.0,
			"encounter_table": [
				{"encounter_id": &"bog-wight", "weight": 1},
				{"encounter_id": &"loam-boar", "weight": 1},
			],
			"min_encounters": 0,
			"max_encounters": 1,
		},
		{
			# PROVISIONAL (C4 / #241): the reed track off the Dorthkor Road down to the mere. Short,
			# and the dead walk the shallows: the thin here is deeper than on any road near Dom.
			"id": &"dorthkor_road-hollowmere",
			"origin_id": DORTHKOR_ROAD_ID,
			"destination_id": HOLLOWMERE_ID,
			"steps": 5,
			"phases_cost": 1,
			"risk_tier": &"high",
			"risk_modifier": 15.0,
			"encounter_table": [
				{"encounter_id": &"bog-wight", "weight": 3},
			],
			"min_encounters": 0,
			"max_encounters": 1,
		},
	]


func test_dom_is_first_and_the_rest_follow_id_order() -> void:
	var ids: Array[String] = []
	for location: Dictionary in WorldMapRegistry.all_locations():
		ids.append(String(location["id"]))
	assert_str(ids[0]).is_equal("dom")
	var rest: Array[String] = ids.slice(1)
	var sorted_rest: Array[String] = rest.duplicate()
	sorted_rest.sort()
	assert_array(rest).is_equal(sorted_rest)


func test_encounter_tables_stay_untyped_like_the_former_literal() -> void:
	for route: Dictionary in WorldMapRegistry.all_routes():
		var table: Array = route["encounter_table"]
		assert_bool(table.is_typed()).is_false()
