class_name WorldMapRegistry
extends RefCounted
## Read-only geographic data for the five current macro locations.

const DOM_ID: StringName = &"dom"
const WILDS_ID: StringName = &"wilds"
const DORTHKOR_ROAD_ID: StringName = &"dorthkor-road"
const WOUND_LIP_ID: StringName = &"wound-lip"
## Hub 2 (C1 / #238); the id is the LocationRegistry / fast-travel id.
const KESSELFORD_ID: StringName = &"kesselford"
## Hub 3 (C2 / #239): the grain-road market town past Kesselford.
const ASHLAREN_ID: StringName = &"ashlaren"
## Location 7 (C3 / #240): the high moor-road between Dom and the ford country. Wilds, not a hub.
const LONG_VERGE_ID: StringName = &"long-verge"


static func all_locations() -> Array[Dictionary]:
	return _location_rows()


static func location(location_id: StringName) -> Dictionary:
	for row: Dictionary in _location_rows():
		if row["id"] == location_id:
			return row
	return {}


static func all_routes() -> Array[Dictionary]:
	return _route_rows()


static func route_between(first_id: StringName, second_id: StringName) -> Dictionary:
	for route: Dictionary in _route_rows():
		var origin_id := StringName(route.get("origin_id", &""))
		var destination_id := StringName(route.get("destination_id", &""))
		if (
			(origin_id == first_id and destination_id == second_id)
			or (origin_id == second_id and destination_id == first_id)
		):
			return route
	return {}


static func routes_from(location_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for route: Dictionary in _route_rows():
		if route["origin_id"] == location_id or route["destination_id"] == location_id:
			result.append(route)
	return result


static func _location_rows() -> Array[Dictionary]:
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
	]


static func _route_rows() -> Array[Dictionary]:
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
			"id": &"dom-dorthkor-road",
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
			"id": &"dom-wound-lip",
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
			"id": &"dom-long-verge",
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
			"id": &"long-verge-kesselford",
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
	]
