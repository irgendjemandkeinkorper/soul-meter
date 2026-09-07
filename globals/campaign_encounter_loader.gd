class_name CampaignEncounterLoader
extends RefCounted
## Structural validation and normalization for campaign-owned encounters.

const PackageFilesScript: Script = preload("res://globals/campaign_package_files.gd")
const ENEMY_FIELDS: Array[String] = [
	"id",
	"display_name",
	"max_hp",
	"attack",
	"defense",
	"balance_affinity",
	"balance_pressure",
	"element_id",
	"edge",
]


class EncountersKind extends WeftluminKind:
	func _init() -> void:
		id = &"encounters"
		subdir = "encounters"
		ext = "json"
		stable_id_kind = StableIds.QUEST

	func validate(documents: Array[Dictionary], errors: Array[Dictionary]) -> Array[Dictionary]:
		var definitions: Dictionary = CampaignEncounterLoader.validate_documents(documents, errors)
		var ids: Array = definitions.keys()
		ids.sort()
		var normalised: Array[Dictionary] = []
		for encounter_id: String in ids:
			normalised.append(definitions[encounter_id])
		return normalised

	func register(normalised: Array[Dictionary]) -> bool:
		return EncounterCatalog.register_runtime_encounters(_definitions(normalised))

	func clear() -> void:
		EncounterCatalog.clear_runtime_encounters()

	func diff(previous: Array[Dictionary], next: Array[Dictionary]) -> Dictionary:
		var current: Dictionary = {}
		for encounter_id: StringName in EncounterCatalog.all_ids():
			if not EncounterCatalog.has_committed(String(encounter_id)):
				current[String(encounter_id)] = EncounterCatalog.definition(encounter_id)
		return {"changed": previous != next or current != _definitions(next)}

	func _definitions(normalised: Array[Dictionary]) -> Dictionary:
		var definitions: Dictionary = {}
		for definition: Dictionary in normalised:
			definitions[definition.encounter_id] = definition.duplicate(true)
		return definitions


static func load_package(package_path: String, errors: Array[Dictionary]) -> Dictionary:
	var documents: Array[Dictionary] = read_documents(package_path, errors)
	return validate_documents(documents, errors)


static func read_documents(
	package_path: String, errors: Array[Dictionary]
) -> Array[Dictionary]:
	var documents: Array[Dictionary] = []
	for file_path: String in source_files(package_path, errors):
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			_add_error(
				errors, file_path, "$", "readable JSON object",
				"encounter_file_unreadable", "Could not open encounter file."
			)
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			_add_error(
				errors, file_path, "$", "valid JSON object",
				"invalid_encounter_json", "Encounter source must contain one JSON object."
			)
			continue
		documents.append({"file": file_path, "data": parsed as Dictionary})
	return documents


static func source_files(
	package_path: String, errors: Array[Dictionary]
) -> Array[String]:
	var directory_path: String = package_path.path_join("encounters")
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory_path)):
		return []
	var discovery_state: Dictionary = {"file_count": 0, "stopped": false}
	return PackageFilesScript.package_files(
		directory_path,
		directory_path,
		"json",
		"encounters",
		"encounter",
		"Encounter",
		errors,
		0,
		discovery_state,
		true
	)


static func validate_documents(
	documents: Array[Dictionary], errors: Array[Dictionary]
) -> Dictionary:
	var definitions: Dictionary = {}
	var sources: Dictionary = {}
	var duplicate_ids: Dictionary = {}
	for document: Dictionary in documents:
		var file_path: String = str(document.get("file", "encounters/<memory>.json"))
		var raw_data: Variant = document.get("data")
		if not raw_data is Dictionary:
			_add_error(
				errors, file_path, "$", "encounter JSON object",
				"invalid_encounter_document", "Encounter document data must be an object."
			)
			continue
		var data: Dictionary = raw_data as Dictionary
		var encounter_id: String = str(data.get("encounter_id", data.get("id", "")))
		if encounter_id.is_empty():
			_add_error(
				errors, file_path, "encounter_id", "non-empty stable id",
				"missing_required_field", "Encounter requires 'encounter_id'."
			)
			continue
		if not StableIds.is_valid(StableIds.QUEST, encounter_id):
			_add_error(
				errors, file_path, "encounter_id",
				StableIds.schema_for(StableIds.QUEST).get("format", "valid stable id"),
				"invalid_encounter_id",
				"Encounter id '%s' does not match the stable-id format." % encounter_id
			)
			continue
		if EncounterCatalog.has_committed(encounter_id):
			_add_error(
				errors, file_path, "encounter_id",
				"id distinct from every committed encounter",
				"campaign_encounter_shadows_committed",
				"Campaign encounter '%s' shadows a committed encounter." % encounter_id
			)
			continue
		if duplicate_ids.has(encounter_id):
			_add_duplicate_error(errors, file_path, encounter_id)
			continue
		if sources.has(encounter_id):
			_add_duplicate_error(errors, str(sources[encounter_id]), encounter_id)
			_add_duplicate_error(errors, file_path, encounter_id)
			definitions.erase(encounter_id)
			sources.erase(encounter_id)
			duplicate_ids[encounter_id] = true
			continue
		var definition: Dictionary = _validate_definition(
			encounter_id, data, file_path, errors
		)
		if definition.is_empty():
			continue
		definitions[encounter_id] = definition
		sources[encounter_id] = file_path
	return definitions


static func _validate_definition(
	encounter_id: String, data: Dictionary, file_path: String, errors: Array[Dictionary]
) -> Dictionary:
	var error_count: int = errors.size()
	var display_name: String = _required_string(
		data, "display_name", file_path, "display_name", errors
	)
	var enemy_value: Variant = data.get("enemies")
	if not enemy_value is Array:
		_add_error(
			errors, file_path, "enemies", "non-empty array",
			"invalid_field_type", "Encounter enemies must be an array."
		)
		return {}
	var raw_enemies: Array = enemy_value as Array
	if raw_enemies.is_empty():
		_add_error(
			errors, file_path, "enemies", "non-empty array",
			"empty_enemy_list", "Encounter requires at least one enemy."
		)
		return {}
	var enemies: Array[Dictionary] = []
	for index: int in raw_enemies.size():
		var enemy: Dictionary = _validate_enemy(
			raw_enemies[index], file_path, "enemies[%d]" % index, errors
		)
		if not enemy.is_empty():
			enemies.append(enemy)

	var grid: Dictionary = _validate_grid(
		data.get("grid"), enemies.size(), file_path, errors
	)
	var weather_default: String = _required_string(
		data, "weather_default", file_path, "weather_default", errors, true
	)
	if not weather_default.is_empty() and ElementWheel.index_of(weather_default) < 0:
		_add_error(
			errors, file_path, "weather_default", "empty (calm) or real element id",
			"unknown_element_id",
			"Weather element '%s' does not exist." % weather_default
		)
	var spoils: Array = _validate_spoils(data.get("spoils", []), file_path, errors)
	_validate_consequences(data, file_path, errors)
	if errors.size() != error_count:
		return {}
	var result: Dictionary = data.duplicate(true)
	result["encounter_id"] = encounter_id
	result["display_name"] = display_name
	result["enemies"] = enemies
	result["grid"] = grid
	result["weather_default"] = weather_default
	result["spoils"] = spoils
	return result


static func _validate_enemy(
	value: Variant, file_path: String, field: String, errors: Array[Dictionary]
) -> Dictionary:
	if not value is Dictionary:
		_add_error(
			errors, file_path, field, "enemy object",
			"invalid_field_type", "Enemy row must be an object."
		)
		return {}
	var row: Dictionary = value as Dictionary
	if row.has("archetype_id"):
		var archetype_id: String = str(row.get("archetype_id", ""))
		var inherited: Dictionary = EncounterCatalog.committed_archetype(archetype_id)
		if inherited.is_empty():
			_add_error(
				errors, file_path, field + ".archetype_id",
				"existing generated combatant archetype id",
				"unknown_archetype_id",
				"Combatant archetype '%s' does not exist." % archetype_id
			)
		return inherited

	var error_count: int = errors.size()
	for required_field: String in ENEMY_FIELDS:
		if not row.has(required_field):
			_add_error(
				errors, file_path, field + "." + required_field,
				"required complete enemy stat field",
				"missing_required_field",
				"Complete enemy row requires '%s'." % required_field
			)
	for string_field: String in ["id", "display_name", "element_id"]:
		if row.has(string_field) and (
			not row[string_field] is String or str(row[string_field]).is_empty()
		):
			_add_error(
				errors, file_path, field + "." + string_field, "non-empty string",
				"invalid_field_type", "Enemy '%s' must be a non-empty string." % string_field
			)
	for number_field: String in [
		"max_hp", "attack", "defense", "balance_affinity", "balance_pressure", "edge"
	]:
		if row.has(number_field) and not _is_whole_number(row[number_field]):
			_add_error(
				errors, file_path, field + "." + number_field, "integer",
				"invalid_field_type", "Enemy '%s' must be an integer." % number_field
			)
	if row.has("max_hp") and _is_whole_number(row["max_hp"]) and int(row["max_hp"]) <= 0:
		_add_error(
			errors, file_path, field + ".max_hp", "positive integer",
			"unplayable_max_hp", "Enemy max_hp must be positive."
		)
	if row.has("element_id") and row["element_id"] is String:
		var element_id: String = str(row["element_id"])
		if not element_id.is_empty() and ElementWheel.index_of(element_id) < 0:
			_add_error(
				errors, file_path, field + ".element_id", "real element id",
				"unknown_element_id", "Enemy element '%s' does not exist." % element_id
			)
	if errors.size() != error_count:
		return {}
	var normalized: Dictionary = row.duplicate(true)
	for number_field: String in [
		"max_hp", "attack", "defense", "balance_affinity", "balance_pressure", "edge"
	]:
		normalized[number_field] = int(normalized[number_field])
	return normalized


static func _validate_grid(
	value: Variant,
	enemy_count: int,
	file_path: String,
	errors: Array[Dictionary]
) -> Dictionary:
	if not value is Dictionary:
		_add_error(
			errors, file_path, "grid", "grid object with dimensions",
			"invalid_field_type", "Encounter requires its own grid object."
		)
		return {}
	var raw_grid: Dictionary = value as Dictionary
	var dimensions: Vector2i = _cell(raw_grid.get("dimensions"))
	if dimensions == Vector2i(-1, -1):
		_add_error(
			errors, file_path, "grid.dimensions", "[width, height] integer pair",
			"invalid_grid_dimensions", "Grid dimensions must be two integers."
		)
		return {}
	var normal_ally_count: int = GameState.REQUIRED_COMPANIONS + 1
	var required_rows: int = maxi(normal_ally_count, enemy_count)
	if dimensions.x < 2 or dimensions.y < required_rows:
		_add_error(
			errors, file_path, "grid.dimensions",
			"width >= 2 and height >= max(normal ally count, enemy count)",
			"grid_cannot_fit_combatants",
			"Grid %dx%d cannot fit %d allies and %d enemies; at least %d rows are required."
			% [dimensions.x, dimensions.y, normal_ally_count, enemy_count, required_rows]
		)
	var cover: Array[Vector2i] = []
	var raw_cover: Variant = raw_grid.get("cover", [])
	if not raw_cover is Array:
		_add_error(
			errors, file_path, "grid.cover", "array of [x, y] cells",
			"invalid_field_type", "Grid cover must be an array."
		)
	else:
		for index: int in (raw_cover as Array).size():
			var cell: Vector2i = _cell((raw_cover as Array)[index])
			if cell == Vector2i(-1, -1):
				_add_error(
					errors, file_path, "grid.cover[%d]" % index, "[x, y] integer pair",
					"invalid_grid_cell", "Cover cell must be an integer pair."
				)
			elif not _inside(cell, dimensions):
				_add_error(
					errors, file_path, "grid.cover[%d]" % index, "cell inside grid",
					"grid_cell_outside_dimensions",
					"Cover cell %s is outside the grid." % cell
				)
			else:
				cover.append(cell)
	var elevation: Dictionary = {}
	var raw_elevation: Variant = raw_grid.get("elevation", [])
	if not raw_elevation is Array:
		_add_error(
			errors, file_path, "grid.elevation",
			"array of {cell: [x, y], height: integer}",
			"invalid_field_type", "Grid elevation must be an array."
		)
	else:
		for index: int in (raw_elevation as Array).size():
			var elevation_value: Variant = (raw_elevation as Array)[index]
			if not elevation_value is Dictionary:
				_add_error(
					errors, file_path, "grid.elevation[%d]" % index, "elevation object",
					"invalid_grid_cell", "Elevation row must be an object."
				)
				continue
			var elevation_row: Dictionary = elevation_value as Dictionary
			var cell: Vector2i = _cell(elevation_row.get("cell"))
			if cell == Vector2i(-1, -1) or not _is_whole_number(elevation_row.get("height")):
				_add_error(
					errors, file_path, "grid.elevation[%d]" % index,
					"{cell: [x, y], height: integer}",
					"invalid_grid_cell", "Elevation row requires an integer cell and height."
				)
			elif not _inside(cell, dimensions):
				_add_error(
					errors, file_path, "grid.elevation[%d].cell" % index,
					"cell inside grid", "grid_cell_outside_dimensions",
					"Elevation cell %s is outside the grid." % cell
				)
			else:
				elevation[cell] = int(elevation_row["height"])
	return {"dimensions": dimensions, "cover": cover, "elevation": elevation}


static func _validate_spoils(
	value: Variant, file_path: String, errors: Array[Dictionary]
) -> Array:
	var normalized: Array = []
	if not value is Array:
		_add_error(
			errors, file_path, "spoils", "array of item ids or item rows",
			"invalid_field_type", "Spoils must be an array."
		)
		return normalized
	for index: int in (value as Array).size():
		var row_value: Variant = (value as Array)[index]
		if row_value is Dictionary:
			var row: Dictionary = (row_value as Dictionary).duplicate(true)
			if row.has("quantity"):
				var quantity: Variant = row["quantity"]
				if not _is_whole_number(quantity):
					_add_error(
						errors, file_path, "spoils[%d].quantity" % index,
						"positive integer", "invalid_field_type",
						"Spoils quantity must be a positive integer."
					)
				elif int(quantity) <= 0:
					_add_error(
						errors, file_path, "spoils[%d].quantity" % index,
						"positive integer", "invalid_field_value",
						"Spoils quantity must be greater than zero."
					)
				else:
					row["quantity"] = int(quantity)
			else:
				row["quantity"] = 1
			row_value = row
		var item_id: String = str(
			(row_value as Dictionary).get("item_id", "") if row_value is Dictionary else row_value
		)
		if item_id.is_empty() or not _script_constants_contain(ItemIds as Script, item_id):
			_add_error(
				errors, file_path, "spoils[%d].item_id" % index,
				"existing generated item id", "unknown_item_id",
				"Spoils item '%s' does not exist." % item_id
			)
		normalized.append(row_value)
	return normalized


static func _validate_consequences(
	data: Dictionary, file_path: String, errors: Array[Dictionary]
) -> void:
	var outcomes: Variant = data.get("outcomes", {})
	if not outcomes is Dictionary:
		_add_error(
			errors, file_path, "outcomes", "dictionary of outcome rows",
			"invalid_field_type", "Encounter outcomes must be a dictionary."
		)
	else:
		for outcome_id: Variant in (outcomes as Dictionary).keys():
			var row_value: Variant = (outcomes as Dictionary)[outcome_id]
			if not row_value is Dictionary:
				_add_error(
					errors, file_path, "outcomes.%s" % str(outcome_id), "outcome object",
					"invalid_field_type", "Outcome row must be an object."
				)
				continue
			var outcome: Dictionary = row_value as Dictionary
			_validate_faction(
				str(outcome.get("faction", "")),
				file_path,
				"outcomes.%s.faction" % str(outcome_id),
				errors
			)
			_validate_optional_number(
				outcome, "delta", file_path,
				"outcomes.%s.delta" % str(outcome_id), errors
			)
			_validate_optional_number(
				outcome, "renown", file_path,
				"outcomes.%s.renown" % str(outcome_id), errors
			)
	var loss: Variant = data.get("loss", {})
	if not loss is Dictionary:
		_add_error(
			errors, file_path, "loss", "loss object",
			"invalid_field_type", "Encounter loss must be an object."
		)
	else:
		var loss_row: Dictionary = loss as Dictionary
		if not loss_row.is_empty():
			_validate_faction(
				str(loss_row.get("faction", "")), file_path, "loss.faction", errors
			)
			_validate_optional_number(loss_row, "delta", file_path, "loss.delta", errors)
	if data.has("loss_faction"):
		_validate_faction(str(data.get("loss_faction", "")), file_path, "loss_faction", errors)
	_validate_optional_number(data, "win_delta", file_path, "win_delta", errors)
	_validate_optional_number(data, "loss_delta", file_path, "loss_delta", errors)


static func _validate_optional_number(
	data: Dictionary,
	key: String,
	file_path: String,
	field: String,
	errors: Array[Dictionary]
) -> void:
	if not data.has(key):
		return
	var value: Variant = data[key]
	if value is int or value is float:
		return
	_add_error(
		errors, file_path, field, "number", "invalid_field_type",
		"Encounter field '%s' must be a number (integer or float); numeric strings are not accepted."
		% field
	)


static func _validate_faction(
	faction_id: String, file_path: String, field: String, errors: Array[Dictionary]
) -> void:
	if faction_id.is_empty() or not _script_constants_contain(FactionIds as Script, faction_id):
		_add_error(
			errors, file_path, field, "existing generated faction id",
			"unknown_faction_id", "Faction '%s' does not exist." % faction_id
		)


static func _required_string(
	data: Dictionary,
	key: String,
	file_path: String,
	field: String,
	errors: Array[Dictionary],
	allow_empty: bool = false
) -> String:
	var value: Variant = data.get(key)
	if not value is String or (not allow_empty and str(value).is_empty()):
		_add_error(
			errors, file_path, field,
			"string" if allow_empty else "non-empty string",
			"missing_required_field",
			"Encounter requires string field '%s'." % key
		)
		return ""
	return str(value)


static func _cell(value: Variant) -> Vector2i:
	if value is Array and (value as Array).size() == 2:
		var values: Array = value as Array
		if _is_whole_number(values[0]) and _is_whole_number(values[1]):
			return Vector2i(int(values[0]), int(values[1]))
	if value is Dictionary:
		var values: Dictionary = value as Dictionary
		if _is_whole_number(values.get("x")) and _is_whole_number(values.get("y")):
			return Vector2i(int(values["x"]), int(values["y"]))
	return Vector2i(-1, -1)


static func _inside(cell: Vector2i, dimensions: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < dimensions.x and cell.y < dimensions.y


## Whole means EXACTLY whole, not approximately whole.
##
## Callers convert an accepted value with int(), so anything this admits is
## rounded. `is_equal_approx()` let an authored 1.000001 through and stored it as
## 1 — a silent coercion, which is the exact thing these rules exist to refuse.
## Non-finite values are excluded too: floorf(INF) == INF, so INF and NAN would
## otherwise satisfy an equality check and then convert meaninglessly.
static func _is_whole_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var number: float = value as float
	return is_finite(number) and number == floorf(number)


static func _script_constants_contain(script: Script, expected: String) -> bool:
	var constants: Dictionary = script.get_script_constant_map()
	for value: Variant in constants.values():
		if value is String and value == expected:
			return true
	return false


static func _add_duplicate_error(
	errors: Array[Dictionary], file_path: String, encounter_id: String
) -> void:
	_add_error(
		errors, file_path, "encounter_id", "id unique within campaign encounters",
		"duplicate_campaign_encounter_id",
		"Campaign encounter id '%s' is authored by more than one file." % encounter_id
	)


static func _add_error(
	errors: Array[Dictionary],
	file_path: String,
	field: String,
	expected: String,
	code: String,
	message: String
) -> void:
	PackageFilesScript.add_error(errors, file_path, field, expected, code, message)
