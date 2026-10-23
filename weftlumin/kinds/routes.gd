class_name WeftluminRoutesKind
extends WeftluminKind
## Routes live with their origin's location package and bake into location_index.v2.
## Existing route tuning and reputation-band weights remain PROVISIONAL; see canon/routes.md.

const SCHEMA := "weftlumin.route.v1"
const FIELDS: Array[String] = [
	"id", "origin_id", "destination_id", "steps", "phases_cost", "risk_tier", "risk_modifier",
	"encounter_table", "band_encounter_weights", "min_encounters", "max_encounters",
]
const RISK_TIERS: Array[String] = ["low", "moderate", "high"]


func _init() -> void:
	id = &"routes"
	subdir = "routes"
	ext = "json"
	stable_id_kind = &"route"


static func load_canon(errors: Array[Dictionary], canon_root: String = "res://canon") -> Array[Dictionary]:
	var documents: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(canon_root):
		errors.append(_error(canon_root, "$", "canon root directory", "missing_canon_root"))
		return documents
	var hubs: PackedStringArray = DirAccess.get_directories_at(canon_root)
	hubs.sort()
	for hub: String in hubs:
		var folder: String = canon_root.path_join(hub).path_join("routes")
		if not DirAccess.dir_exists_absolute(folder):
			continue
		var filenames: PackedStringArray = DirAccess.get_files_at(folder)
		filenames.sort()
		for filename: String in filenames:
			if filename.get_extension().to_lower() != "json":
				continue
			var path: String = folder.path_join(filename)
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not parsed is Dictionary:
				errors.append(_error(path, "$", "one JSON object", "invalid_document"))
				continue
			var document: Dictionary = parsed
			document["$file"] = path
			document["$hub"] = hub
			documents.append(document)
	return documents


func validate(documents: Array[Dictionary], errors: Array[Dictionary]) -> Array[Dictionary]:
	var locations: Array[Dictionary] = WeftluminLocationsKind.load_canon(errors)
	locations = WeftluminLocationsKind.new().validate(locations, errors)
	return validate_with_locations(documents, locations, errors)


## Explicit location overlay lets package validation resolve newly authored endpoints.
func validate_with_locations(
	documents: Array[Dictionary], locations: Array[Dictionary], errors: Array[Dictionary],
) -> Array[Dictionary]:
	var error_count: int = errors.size()
	var scenes: Dictionary = {}
	for location: Dictionary in locations:
		if not String(location.get("scene_path", "")).is_empty():
			scenes[location["id"]] = true
	var rows: Array[Dictionary] = []
	var seen: Dictionary = {}
	for index: int in documents.size():
		var document: Dictionary = documents[index]
		var file: String = String(document.get("$file", "routes[%d]" % index))
		var row: Dictionary = _normalise(document, scenes, file, errors)
		if row.is_empty():
			continue
		if seen.has(row["id"]):
			errors.append(_error(file, "id", "unique route id", "duplicate_id"))
		seen[row["id"]] = true
		rows.append(row)
	if errors.size() != error_count:
		return []
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	return rows


func _normalise(document: Dictionary, scenes: Dictionary, file: String, errors: Array[Dictionary]) -> Dictionary:
	var error_count: int = errors.size()
	for key: Variant in document:
		if not FIELDS.has(String(key)) and not String(key) in ["schema", "$file", "$hub"]:
			errors.append(_error(file, String(key), "a weftlumin.route.v1 field", "unknown_field"))
	if document.get("schema") != SCHEMA:
		errors.append(_error(file, "schema", SCHEMA, "unsupported_schema"))
	var row: Dictionary = {"schema": SCHEMA}
	for field: String in ["id", "origin_id", "destination_id", "risk_tier"]:
		if not document.get(field) is String:
			errors.append(_error(file, field, "string", "invalid_field_type"))
		else:
			row[field] = document[field]
	for field: String in ["origin_id", "destination_id"]:
		if not scenes.has(row.get(field, "")):
			errors.append(_error(file, field, "a scene-backed location id", "unknown_location"))
	if row.get("id") != "%s-%s" % [row.get("origin_id", ""), row.get("destination_id", "")]:
		errors.append(_error(file, "id", "<origin_id>-<destination_id>", "invalid_id"))
	if not RISK_TIERS.has(String(row.get("risk_tier", ""))):
		errors.append(_error(file, "risk_tier", "low | moderate | high", "invalid_enum"))
	for field: String in ["steps", "phases_cost", "min_encounters", "max_encounters"]:
		var value: Variant = document.get(field)
		if not _number(value) or float(value) != floorf(float(value)) or float(value) < 0.0:
			errors.append(_error(file, field, "integer >= 0", "out_of_range"))
		else:
			row[field] = int(value)
	if int(row.get("min_encounters", 0)) > int(row.get("max_encounters", 0)):
		errors.append(_error(file, "min_encounters", "<= max_encounters", "out_of_range"))
	if not _number(document.get("risk_modifier")):
		errors.append(_error(file, "risk_modifier", "number", "invalid_field_type"))
	else:
		row["risk_modifier"] = float(document["risk_modifier"])
	var table: Variant = document.get("encounter_table")
	if not table is Array:
		errors.append(_error(file, "encounter_table", "array of encounter weights", "invalid_field_type"))
	else:
		var entries: Array[Dictionary] = []
		for index: int in table.size():
			var entry: Variant = table[index]
			var field: String = "encounter_table[%d]" % index
			if not entry is Dictionary:
				errors.append(_error(file, field, "encounter_id and weight object", "invalid_field_type"))
				continue
			for key: Variant in entry:
				if not String(key) in ["encounter_id", "weight"]:
					errors.append(_error(file, field + "." + String(key), "encounter_id | weight", "unknown_field"))
			_validate_encounter(entry.get("encounter_id"), file, field + ".encounter_id", errors)
			_validate_weight(entry.get("weight"), false, file, field + ".weight", errors)
			if _number(entry.get("weight")):
				entries.append({"encounter_id": entry.get("encounter_id"), "weight": _weight(entry["weight"])})
		row["encounter_table"] = entries
	if document.has("band_encounter_weights"):
		_validate_bands(document["band_encounter_weights"], file, errors)
	if errors.size() != error_count:
		return {}
	if document.has("band_encounter_weights"):
		var source: Dictionary = document["band_encounter_weights"]
		var bands: Dictionary = {}
		for band: String in source["bands"]:
			var weights: Dictionary = {}
			for encounter: String in source["bands"][band]:
				weights[encounter] = _weight(source["bands"][band][encounter])
			bands[band] = weights
		row["band_encounter_weights"] = {"faction_id": source["faction_id"], "bands": bands}
	return _ordered(row)


static func _weight(value: Variant) -> Variant:
	return int(value) if float(value) == floorf(float(value)) else float(value)


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _validate_encounter(value: Variant, file: String, field: String, errors: Array[Dictionary]) -> void:
	if not value is String or EncounterCatalog.definition(StringName(value)).is_empty():
		errors.append(_error(file, field, "an EncounterCatalog id", "unknown_encounter"))


static func _validate_weight(value: Variant, override: bool, file: String, field: String, errors: Array[Dictionary]) -> void:
	# Allied's existing zero override disables that encounter; only base weights must be positive.
	if not _number(value) or float(value) < 0.0 or (not override and float(value) == 0.0):
		errors.append(_error(file, field, "weight >= 0" if override else "weight > 0", "out_of_range"))


static func _validate_bands(value: Variant, file: String, errors: Array[Dictionary]) -> void:
	var field: String = "band_encounter_weights"
	if not value is Dictionary:
		errors.append(_error(file, field, "faction_id and bands object", "invalid_field_type"))
		return
	for key: Variant in value:
		if not String(key) in ["faction_id", "bands"]:
			errors.append(_error(file, field + "." + String(key), "faction_id | bands", "unknown_field"))
	if not value.get("faction_id") is String or String(value["faction_id"]).is_empty():
		errors.append(_error(file, field + ".faction_id", "non-empty faction id", "invalid_field_type"))
	var bands: Variant = value.get("bands")
	if not bands is Dictionary:
		errors.append(_error(file, field + ".bands", "band -> encounter id -> weight object", "invalid_field_type"))
		return
	for band: Variant in bands:
		var weights: Variant = bands[band]
		var band_field: String = field + ".bands." + String(band)
		if not weights is Dictionary:
			errors.append(_error(file, band_field, "encounter id -> weight object", "invalid_field_type"))
			continue
		for encounter: Variant in weights:
			_validate_encounter(encounter, file, band_field + "." + String(encounter), errors)
			_validate_weight(weights[encounter], true, file, band_field + "." + String(encounter), errors)


static func _ordered(row: Dictionary) -> Dictionary:
	var ordered: Dictionary = {"schema": SCHEMA}
	for field: String in FIELDS:
		if row.has(field):
			ordered[field] = row[field]
	return ordered


static func canon_text(row: Dictionary) -> String:
	return JSON.stringify(_ordered(row), "", false) + "\n"


static func _error(file: String, field: String, expected: String, code: String) -> Dictionary:
	return WeftluminLocationsKind._error(file, field, expected, code)


func bake(normalised: Array[Dictionary], target_root: String, write: bool, force: bool) -> Dictionary:
	var errors: Array[Dictionary] = []
	var locations_kind := WeftluminLocationsKind.new()
	var locations: Array[Dictionary] = WeftluminLocationsKind.load_canon(errors)
	locations = locations_kind.validate(locations, errors)
	if not errors.is_empty():
		return {"errors": errors}
	locations_kind.route_documents = normalised
	return locations_kind.bake(locations, target_root, write, force)
