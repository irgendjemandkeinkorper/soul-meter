class_name WorldMapRegistry
extends RefCounted
## Read-only geographic data for the four current macro locations.

const DOM_ID: StringName = &"dom"
const WILDS_ID: StringName = &"wilds"
const DORTHKOR_ROAD_ID: StringName = &"dorthkor-road"
const WOUND_LIP_ID: StringName = &"wound-lip"


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
	]
