class_name CampaignEncounterLoader
extends RefCounted
## Structural validation and normalization for campaign-owned encounters.

const PackageFilesScript: Script = preload("res://globals/campaign_package_files.gd")
## Post-F1 an encounter owns actors, spoils, outcomes, speech hooks and `group_id` — not a board
## and not weather (spec §4.9, F0 D8). These are refused, never accepted and quietly ignored.
const REFUSED_FIELDS: Dictionary = {
	"grid": "absent (the grid derives from the field's tiles)",
	"weather_default": "absent (weather is the location's)",
}
const INVALID_CELL := Vector2i(-1, -1)


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
	for refused_field: String in REFUSED_FIELDS:
		if data.has(refused_field):
			_add_error(
				errors, file_path, refused_field, str(REFUSED_FIELDS[refused_field]),
				"refused_encounter_field",
				"Encounter field '%s' is refused: %s." % [
					refused_field, str(REFUSED_FIELDS[refused_field])
				]
			)
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

	if data.has("group_id"):
		_required_string(data, "group_id", file_path, "group_id", errors)
	var set_piece: Dictionary = _validate_set_piece(data.get("set_piece"), file_path, errors)
	var spoils: Array = _validate_spoils(data.get("spoils", []), file_path, errors)
	_validate_consequences(data, file_path, errors)
	if errors.size() != error_count:
		return {}
	var result: Dictionary = data.duplicate(true)
	result["encounter_id"] = encounter_id
	result["display_name"] = display_name
	result["enemies"] = enemies
	result["spoils"] = spoils
	if data.has("set_piece"):
		result["set_piece"] = set_piece
	return result


## An enemy row names a generated combatant archetype and nothing else. Stats, element and
## identity are the archetype's (#283): a row that restates them would be a second, silently
## diverging source of truth, so every other key is refused rather than ignored.
static func _validate_enemy(
	value: Variant, file_path: String, field: String, errors: Array[Dictionary]
) -> Dictionary:
	if not value is Dictionary:
		_add_error(
			errors, file_path, field, "{\"archetype_id\": id} object",
			"invalid_field_type", "Enemy row must be an object."
		)
		return {}
	var row: Dictionary = value as Dictionary
	var refused: Array[String] = []
	for key: Variant in row.keys():
		if str(key) != "archetype_id":
			refused.append(str(key))
	refused.sort()
	for key: String in refused:
		_add_error(
			errors, file_path, field + "." + key,
			"absent (the archetype owns every combat stat)",
			"refused_enemy_field",
			"Enemy field '%s' is refused; author it on the combatant archetype." % key
		)
	if not row.get("archetype_id") is String or str(row.get("archetype_id")).is_empty():
		_add_error(
			errors, file_path, field + ".archetype_id", "existing generated combatant archetype id",
			"missing_required_field", "Enemy row requires 'archetype_id'."
		)
		return {}
	var archetype_id: String = str(row["archetype_id"])
	var inherited: Dictionary = EncounterCatalog.committed_archetype(archetype_id)
	if inherited.is_empty():
		_add_error(
			errors, file_path, field + ".archetype_id",
			"existing generated combatant archetype id",
			"unknown_archetype_id",
			"Combatant archetype '%s' does not exist." % archetype_id
		)
	if not refused.is_empty():
		return {}
	return inherited


## `set_piece: {ally_cells: [[x, y], ...]}` — the authored deployment cells of a set-piece
## (spec §4.9). Shape only: whether the cells exist and are deployable is a question about a
## scene, answered by `fits_the_board()` against the field the encounter is fought on.
static func _validate_set_piece(
	value: Variant, file_path: String, errors: Array[Dictionary]
) -> Dictionary:
	if value == null:
		return {}
	if not value is Dictionary:
		_add_error(
			errors, file_path, "set_piece", "{ally_cells: [[x, y], ...]} object",
			"invalid_field_type", "Encounter set_piece must be an object."
		)
		return {}
	var raw: Dictionary = value as Dictionary
	for key: Variant in raw.keys():
		if str(key) != "ally_cells":
			_add_error(
				errors, file_path, "set_piece." + str(key), "absent",
				"refused_encounter_field",
				"Set-piece field '%s' is refused; hostiles are placed in the scene." % str(key)
			)
	var raw_cells: Variant = raw.get("ally_cells")
	if not raw_cells is Array or (raw_cells as Array).is_empty():
		_add_error(
			errors, file_path, "set_piece.ally_cells", "non-empty array of [x, y] cells",
			"invalid_field_type", "Set-piece ally_cells must be a non-empty array."
		)
		return {}
	var cells: Array[Vector2i] = []
	for index: int in (raw_cells as Array).size():
		var cell: Vector2i = _cell((raw_cells as Array)[index])
		var field: String = "set_piece.ally_cells[%d]" % index
		if cell == INVALID_CELL:
			_add_error(
				errors, file_path, field, "[x, y] integer pair",
				"invalid_set_piece_cell", "Set-piece cell must be an integer pair."
			)
		elif cells.has(cell):
			_add_error(
				errors, file_path, field, "distinct cell",
				"duplicate_set_piece_cell", "Set-piece cell %s is authored twice." % cell
			)
		else:
			cells.append(cell)
	return {"ally_cells": cells}


## The "fits the board" check, moved off the encounter and onto the scene (spec §4.9, F0 D8:
## the grid derives from the field's tiles). A board fits when its deployable cells can hold the
## party and every hostile, and — for a set-piece that authors deployment cells — when each of
## those cells is deployable on THIS field and there are enough of them for the party.
##
## `hostile_count < 0` means "the encounter's own enemies". Refusals follow the FR-606 shape.
static func fits_the_board(
	definition: Dictionary,
	field: FieldMap,
	party_size: int = GameState.REQUIRED_COMPANIONS + 1,
	hostile_count: int = -1
) -> Dictionary:
	if field == null or field.ground() == null or field.iso_grid() == null:
		return _board_refusal(
			&"field_map", "Combat requires a loaded field map with a ready grid.", 0, 0
		)
	var hostiles: int = hostile_count
	if hostiles < 0:
		hostiles = (definition.get("enemies", []) as Array).size()
	var deployable: Dictionary = {}
	for cell: Vector2i in deployable_cells(field):
		deployable[cell] = true
	var required: int = party_size + hostiles
	if deployable.size() < required:
		return _board_refusal(
			&"board_too_small",
			"The field has %d deployable cells; %d party and %d hostiles need %d."
			% [deployable.size(), party_size, hostiles, required],
			deployable.size(), required
		)
	var set_piece: Dictionary = definition.get("set_piece", {})
	var ally_cells: Array = set_piece.get("ally_cells", [])
	if not set_piece.is_empty():
		for cell: Variant in ally_cells:
			if not cell is Vector2i or not deployable.has(cell):
				return _board_refusal(
					&"set_piece_cell_not_deployable",
					"Set-piece cell %s is not a deployable cell on this field." % str(cell),
					deployable.size(), required
				)
		if ally_cells.size() < party_size:
			return _board_refusal(
				&"set_piece_cells_short",
				"The set-piece authors %d deployment cells for a party of %d."
				% [ally_cells.size(), party_size],
				deployable.size(), required
			)
	return {
		"allowed": true,
		"blocked_by": &"",
		"nearest_unblock": {},
		"message": "",
		"deployable": deployable.size(),
		"required": required,
	}


## Painted ground cells that static scenery does not block. Whoever is standing on a cell does
## not make it undeployable: the party and the hostiles are exactly what is being deployed.
static func deployable_cells(field: FieldMap) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if field == null or field.ground() == null or field.iso_grid() == null:
		return cells
	var grid: IsoGrid = field.iso_grid()
	for cell: Vector2i in field.ground().get_used_cells():
		if grid.is_in_bounds(cell) and not grid.is_blocked_for(cell, grid.occupant_of(cell)):
			cells.append(cell)
	return cells


static func _board_refusal(
	blocked_by: StringName, message: String, deployable: int, required: int
) -> Dictionary:
	return {
		"allowed": false,
		"blocked_by": blocked_by,
		"nearest_unblock": {"type": &"field_map"},
		"message": message,
		"deployable": deployable,
		"required": required,
	}


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
	return INVALID_CELL


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
