class_name WorldMapRegistry
extends RefCounted
## Read-only geographic data from the baked location index. Public rows are defensive copies.

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


static var _locations: Array[Dictionary] = []
static var _routes: Array[Dictionary] = []
static var _loaded: bool = _load_index()


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
	return _locations.duplicate(true)


static func _route_rows() -> Array[Dictionary]:
	return _routes.duplicate(true)


static func _load_index() -> bool:
	var index: JSON = load(LocationRegistry.INDEX_PATH) as JSON
	if index == null or not index.data is Dictionary:
		push_error("WorldMapRegistry: missing or invalid location index.")
		return false
	var data: Dictionary = index.data
	if data.get("schema") != LocationRegistry.INDEX_SCHEMA:
		push_error("WorldMapRegistry: unsupported location index schema.")
		return false
	for row: Dictionary in data.get("locations", []):
		var facet: Variant = row.get("world_map")
		if not facet is Dictionary:
			continue
		var coordinate: Array = facet["map_coordinate"]
		_locations.append({
			"id": StringName(row["id"]),
			"scene_path": String(row["scene_path"]),
			"map_coordinate": Vector2(float(coordinate[0]), float(coordinate[1])),
		})
	for row: Dictionary in data.get("routes", []):
		var route: Dictionary = row.duplicate(true)
		for key: String in ["id", "origin_id", "destination_id", "risk_tier"]:
			route[key] = StringName(row[key])
		for key: String in ["steps", "phases_cost", "min_encounters", "max_encounters"]:
			route[key] = int(row[key])
		route["risk_modifier"] = float(row["risk_modifier"])
		# JSON numbers/strings return to the original public Variant types at this boundary.
		var encounters: Array[Dictionary] = []
		for entry: Dictionary in row["encounter_table"]:
			encounters.append({"encounter_id": StringName(entry["encounter_id"]), "weight": int(entry["weight"])})
		# The former literal was an untyped Array.
		route["encounter_table"] = Array(encounters)
		if row.has("band_encounter_weights"):
			var source: Dictionary = row["band_encounter_weights"]
			var bands: Dictionary = {}
			for band: String in source["bands"]:
				var weights: Dictionary = {}
				for encounter: String in source["bands"][band]:
					weights[StringName(encounter)] = int(source["bands"][band][encounter])
				bands[StringName(band)] = weights
			route["band_encounter_weights"] = {"faction_id": StringName(source["faction_id"]), "bands": bands}
		_routes.append(route)
	return true
