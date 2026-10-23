class_name WeftluminLocationsKind
extends WeftluminKind
## The `locations` kind (architecture §4.3.3, E3.3a / #341): `canon/<hub>/locations/<id>.json`
## documents in the `weftlumin.location.v1` schema, baked to `world/locations/**/*.tres`
## (`LocationDefinition`) and `data/generated/location_index.json`.
##
## A location document requires a gazetteer or scene facet:
##
## - **Gazetteer** (E1.4e / #323): `display_name`, `epithet`, `patron`, `agreement`, `vault_id`.
##   The twelve world-map cities. `tools/seed_pandora.gd` seeds this facet into Pandora; this
##   kind only validates and indexes it.
## - **Scene**: everything a `LocationDefinition` holds, plus `definition_path` (where the
##   `.tres` bakes to — today's committed paths are referenced by `LocationRegistry`'s preload
##   consts, so they are data, not derived from the id) and `no_combat_zone`.
## - Optional scene-backed travel facets: `world_map` coordinates and `fast_travel` cost.
##   Routes are separate documents; this bake combines both kinds in the v2 index.
##
## Dom is the only location carrying both today. Every scene field is REQUIRED when the facet is
## present, defaults included: canon states its values instead of inheriting them from a script.
## The `.tres` bake omits the fields the hand-written files omitted, in one fixed order, so a
## bake of unchanged canon is byte-identical to the committed definitions.
##
## `no_combat_zone` is canon and indexed; `LocationRegistry` reads the index and
## `FieldMap.no_combat_zone()` asks it (E3.3b / #342).
##
## `register()` stays the base refusal: a live runtime overlay is `LocationRegistry
## .register_runtime()`.

const SCHEMA := "weftlumin.location.v1"
const INDEX_SCHEMA := "weftlumin.location_index.v2"
const BAKE_SCHEMA := "weftlumin.bake.v1"
const CANON_ROOT := "res://canon"
const INDEX_PATH := "res://data/generated/location_index.json"
const DEFINITIONS_ROOT := "res://world/locations/"
const DEFINITION_SCRIPT := "res://globals/location_definition.gd"
const INTERIOR_SCENES_ROOT := "res://world/interiors/"

const GAZETTEER_FIELDS: Array[String] = ["display_name", "epithet", "patron", "agreement", "vault_id"]
## Canonical key order of the scene facet; also the order the canon text is written in.
const SCENE_FIELDS: Array[String] = [
	"definition_path", "scene_path", "allowed_gameplay", "default_spawn_id", "spawns",
	"arrival_flag", "arrival_checkpoint", "harmonic_accord", "thinning_tier", "weather_default",
	"no_combat_zone", "respawn_policy",
]
## Mirrors `LocationDefinition`'s `@export_enum` and `@export_range` bounds.
const RESPAWN_POLICIES: Array[String] = ["none", "limited", "wilderness"]
const MAX_THINNING_TIER := 3
## Load-time-only keys `load_canon()` attaches for error attribution; never written back.
const META_FILE := "$file"
const META_HUB := "$hub"
const TRAVEL_FACETS: Array[String] = ["world_map", "fast_travel"]

## Null reads canon; the generator/package bake supplies its own complete route overlay.
var route_documents: Variant = null


func _init() -> void:
	id = &"locations"
	subdir = "locations"
	ext = "json"
	stable_id_kind = &"location"


# --- Discovery -----------------------------------------------------------------------------


## Every `canon/<hub>/locations/*.json` in a stable (hub, filename) order, each tagged with its
## file and hub. Unreadable or non-object files append an attributed error and are skipped.
static func load_canon(errors: Array[Dictionary], canon_root: String = CANON_ROOT) -> Array[Dictionary]:
	var documents: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(canon_root):
		errors.append(_error(canon_root, "$", "canon root directory", "missing_canon_root"))
		return documents
	var hubs: PackedStringArray = DirAccess.get_directories_at(canon_root)
	hubs.sort()
	for hub: String in hubs:
		var kind_root: String = canon_root.path_join(hub).path_join("locations")
		if not DirAccess.dir_exists_absolute(kind_root):
			continue
		var filenames: PackedStringArray = DirAccess.get_files_at(kind_root)
		filenames.sort()
		for filename: String in filenames:
			if filename.get_extension().to_lower() != "json":
				continue
			var path: String = kind_root.path_join(filename)
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not parsed is Dictionary:
				errors.append(_error(path, "$", "one JSON object", "invalid_document"))
				continue
			var document: Dictionary = parsed
			document[META_FILE] = path
			document[META_HUB] = hub
			documents.append(document)
	return documents


# --- Validation ----------------------------------------------------------------------------


## Pure: returns normalised documents (typed values, canonical key order, meta keys dropped),
## sorted by id, or an empty array when any error was appended.
func validate(documents: Array[Dictionary], errors: Array[Dictionary]) -> Array[Dictionary]:
	var normalised: Array[Dictionary] = []
	var error_count: int = errors.size()
	var seen_ids: Dictionary = {}
	var seen_definitions: Dictionary = {}
	var seen_scenes: Dictionary = {}
	for index: int in documents.size():
		var document: Dictionary = documents[index]
		var file: String = String(document.get(META_FILE, "locations[%d]" % index))
		var row: Dictionary = _normalise(document, file, errors)
		if row.is_empty():
			continue
		var location_id: String = row["id"]
		if seen_ids.has(location_id):
			errors.append(_error(file, "id", "unique location id", "duplicate_id",
				"Location id '%s' is also declared by %s." % [location_id, seen_ids[location_id]]))
			continue
		seen_ids[location_id] = file
		if row.has("definition_path"):
			for pair: Array in [["definition_path", seen_definitions], ["scene_path", seen_scenes]]:
				var field: String = pair[0]
				var seen: Dictionary = pair[1]
				var value: String = row[field]
				if seen.has(value):
					errors.append(_error(file, field, "unique %s" % field, "duplicate_%s" % field,
						"'%s' is also used by location '%s'." % [value, seen[value]]))
				seen[value] = location_id
		normalised.append(row)
	if errors.size() != error_count:
		return []
	normalised.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	return normalised


func _normalise(document: Dictionary, file: String, errors: Array[Dictionary]) -> Dictionary:
	var error_count: int = errors.size()
	var allowed: Array[String] = ["schema", "id", META_FILE, META_HUB]
	allowed.append_array(GAZETTEER_FIELDS)
	allowed.append_array(SCENE_FIELDS)
	allowed.append_array(TRAVEL_FACETS)
	for key: Variant in document.keys():
		if not allowed.has(String(key)):
			errors.append(_error(file, String(key), "a weftlumin.location.v1 field", "unknown_field"))
	if document.get("schema") != SCHEMA:
		errors.append(_error(file, "schema", SCHEMA, "unsupported_schema"))
	var location_id: Variant = document.get("id")
	if not location_id is String or not _is_stable_id(location_id):
		errors.append(_error(file, "id", "lower-case stable id ([a-z0-9_-]+)", "invalid_id"))
	var row: Dictionary = {"schema": SCHEMA, "id": String(location_id) if location_id is String else ""}

	var has_gazetteer: bool = false
	for field: String in ["epithet", "patron", "agreement", "vault_id"]:
		has_gazetteer = has_gazetteer or document.has(field)
	if document.has("display_name"):
		if not document["display_name"] is String:
			errors.append(_error(file, "display_name", "string", "invalid_field_type"))
		else:
			row["display_name"] = document["display_name"]
	if has_gazetteer:
		for field: String in GAZETTEER_FIELDS:
			if not document.get(field) is String:
				errors.append(_error(file, field, "string (gazetteer facet)", "invalid_field_type"))
			else:
				row[field] = document[field]

	var has_scene: bool = false
	for field: String in SCENE_FIELDS:
		has_scene = has_scene or document.has(field)
	if has_scene:
		_normalise_scene(document, file, row, errors)
	elif not has_gazetteer:
		errors.append(_error(file, "$", "a gazetteer or scene facet", "empty_location"))
	_normalise_travel_facets(document, file, row, errors)
	return row if errors.size() == error_count else {}


func _normalise_travel_facets(document: Dictionary, file: String, row: Dictionary, errors: Array[Dictionary]) -> void:
	for facet: String in TRAVEL_FACETS:
		if not document.has(facet):
			continue
		if not row.has("scene_path"):
			errors.append(_error(file, facet, "a scene-backed location", "missing_scene_facet"))
		var value: Variant = document[facet]
		var field: String = "map_coordinate" if facet == "world_map" else "base_cost_gp"
		if not value is Dictionary:
			errors.append(_error(file, facet, "an object containing %s" % field, "invalid_field_type"))
			continue
		for key: Variant in value:
			if key != field:
				errors.append(_error(file, "%s.%s" % [facet, key], field, "unknown_field"))
		if facet == "world_map":
			var coordinate: Variant = value.get(field)
			if not coordinate is Array or coordinate.size() != 2:
				errors.append(_error(file, facet + "." + field, "two numbers from 0 to 1", "out_of_range"))
				continue
			var valid: bool = true
			for component: Variant in coordinate:
				valid = valid and (component is int or component is float) \
					and is_finite(float(component)) and float(component) >= 0.0 and float(component) <= 1.0
			if not valid:
				errors.append(_error(file, facet + "." + field, "two numbers from 0 to 1", "out_of_range"))
			else:
				row[facet] = {field: [float(coordinate[0]), float(coordinate[1])]}
		else:
			if document.get("allowed_gameplay") != true:
				errors.append(_error(file, facet, "allowed_gameplay = true", "non_gameplay_hub"))
			var cost: Variant = value.get(field)
			if not (cost is int or cost is float) or not is_finite(float(cost)) \
				or float(cost) != floorf(float(cost)) or float(cost) < 0.0:
				errors.append(_error(file, facet + "." + field, "integer >= 0", "out_of_range"))
			else:
				row[facet] = {field: int(cost)}


func _normalise_scene(document: Dictionary, file: String, row: Dictionary, errors: Array[Dictionary]) -> void:
	var definition_path: Variant = document.get("definition_path")
	if (
		not definition_path is String or not definition_path.begins_with(DEFINITIONS_ROOT)
		or definition_path.get_extension() != "tres" or definition_path.contains("..")
	):
		errors.append(_error(file, "definition_path", "res://world/locations/…/<name>.tres", "invalid_definition_path"))
	else:
		row["definition_path"] = definition_path
	var scene_path: Variant = document.get("scene_path")
	if not scene_path is String or not scene_path.begins_with("res://") or scene_path.get_extension() != "tscn":
		errors.append(_error(file, "scene_path", "res:// path to a .tscn", "invalid_scene_path"))
	elif not FileAccess.file_exists(scene_path) and not _package_creates(file, scene_path):
		errors.append(_error(file, "scene_path", "an existing scene", "missing_scene",
			"Scene '%s' does not exist." % scene_path))
	else:
		row["scene_path"] = scene_path
	for field: String in ["allowed_gameplay", "no_combat_zone"]:
		if not document.get(field) is bool:
			errors.append(_error(file, field, "boolean", "invalid_field_type"))
		else:
			row[field] = document[field]
	var default_spawn: Variant = document.get("default_spawn_id")
	if not default_spawn is String or String(default_spawn).strip_edges().is_empty():
		errors.append(_error(file, "default_spawn_id", "non-empty string", "invalid_field_type"))
	else:
		row["default_spawn_id"] = default_spawn
	var spawns: Variant = document.get("spawns")
	if not spawns is Dictionary:
		errors.append(_error(file, "spawns", "object of alias → spawn id strings", "invalid_field_type"))
	else:
		var ordered_spawns: Dictionary = {}
		var aliases: Array = (spawns as Dictionary).keys()
		aliases.sort()
		for alias: Variant in aliases:
			var target: Variant = spawns[alias]
			if String(alias).strip_edges().is_empty() or not target is String or String(target).strip_edges().is_empty():
				errors.append(_error(file, "spawns.%s" % alias, "non-empty spawn id string", "invalid_spawn"))
			else:
				ordered_spawns[String(alias)] = target
		row["spawns"] = ordered_spawns
	for field: String in ["arrival_flag", "arrival_checkpoint"]:
		if not document.get(field) is String:
			errors.append(_error(file, field, "string (empty for none)", "invalid_field_type"))
		else:
			row[field] = document[field]
	var accord: Variant = document.get("harmonic_accord")
	if not (accord is float or accord is int) or float(accord) < 0.0 or float(accord) > 100.0:
		errors.append(_error(file, "harmonic_accord", "number from 0 to 100", "out_of_range"))
	else:
		row["harmonic_accord"] = float(accord)
	var tier: Variant = document.get("thinning_tier")
	if (
		not (tier is float or tier is int) or float(tier) != floorf(float(tier))
		or int(tier) < 0 or int(tier) > MAX_THINNING_TIER
	):
		errors.append(_error(file, "thinning_tier", "integer from 0 to %d" % MAX_THINNING_TIER, "out_of_range"))
	else:
		row["thinning_tier"] = int(tier)
	var weather: Variant = document.get("weather_default")
	if not weather is String or not (String(weather).is_empty() or weather_ids().has(String(weather))):
		errors.append(_error(file, "weather_default", "empty (calm) or an element id", "unknown_weather"))
	else:
		row["weather_default"] = weather
	var policy: Variant = document.get("respawn_policy")
	if not policy is String or not RESPAWN_POLICIES.has(String(policy)):
		errors.append(_error(file, "respawn_policy", " | ".join(RESPAWN_POLICIES), "invalid_enum"))
	else:
		row["respawn_policy"] = policy
	# Canonical key order: the gazetteer facet first (already in `row`), then the scene facet.
	var reordered: Dictionary = {}
	for key: String in row.keys():
		if not SCENE_FIELDS.has(key):
			reordered[key] = row[key]
	for key: String in SCENE_FIELDS:
		if row.has(key):
			reordered[key] = row[key]
	row.clear()
	row.merge(reordered)


## Calm (`""`) plus every element on the generated wheel: weather is an element (F0 D8).
## True when `file` is a package document (`<package>/locations/<id>.json`) whose package already
## holds the scene `new_scene` rendered for it (`<package>/scenes/<name>.tscn`): the bake writes
## `scene_path` from that scene, so it need not exist yet (E3.4).
static func _package_creates(file: String, scene_path: String) -> bool:
	var package: String = file.get_base_dir().get_base_dir()
	return file.get_base_dir().get_file() == "locations" and not package.begins_with("res://") \
		and FileAccess.file_exists(package.path_join("scenes").path_join(scene_path.get_file()))


static func weather_ids() -> Array[String]:
	var ids: Array[String] = []
	for element: StringName in ElementMatrixRows.WHEEL_ORDER:
		ids.append(String(element))
	return ids


## Non-blocking authoring notes for one normalised document: canon values the runtime would
## ignore. None today — `no_combat_zone` was the last, and `FieldMap.no_combat_zone()` reads it
## through `LocationRegistry` since E3.3b (#342). Kept as the panel's and bake report's hook.
static func runtime_notes(_row: Dictionary) -> Array[String]:
	return []


static func _is_stable_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character: String in value:
		if not (character in "abcdefghijklmnopqrstuvwxyz0123456789_-"):
			return false
	return true


static func _error(file: String, field: String, expected: String, code: String, message: String = "") -> Dictionary:
	return {
		"file": file, "field": field, "expected": expected, "code": code,
		"message": message if not message.is_empty() else "%s: expected %s." % [field, expected],
	}


# --- Diff ----------------------------------------------------------------------------------


func diff(previous: Array[Dictionary], next: Array[Dictionary]) -> Dictionary:
	var before: Dictionary = {}
	for row: Dictionary in previous:
		before[row["id"]] = row
	var added: Array[String] = []
	var modified: Array[String] = []
	var removed: Array[String] = []
	var after_ids: Dictionary = {}
	for row: Dictionary in next:
		after_ids[row["id"]] = true
		if not before.has(row["id"]):
			added.append(row["id"])
		elif canon_text(before[row["id"]]) != canon_text(row):
			modified.append(row["id"])
	for location_id: String in before:
		if not after_ids.has(location_id):
			removed.append(location_id)
	return {
		"changed": not (added.is_empty() and modified.is_empty() and removed.is_empty()),
		"added": added, "modified": modified, "removed": removed,
	}


# --- Text forms ----------------------------------------------------------------------------


## The canonical on-disk form of one location document: compact JSON, canonical key order, one
## trailing newline — the form E1.4e wrote the gazetteer documents in.
static func canon_text(row: Dictionary) -> String:
	var ordered: Dictionary = {"schema": SCHEMA, "id": row.get("id", "")}
	for key: String in GAZETTEER_FIELDS:
		if row.has(key):
			ordered[key] = row[key]
	for key: String in SCENE_FIELDS:
		if row.has(key):
			ordered[key] = int(row[key]) if key == "thinning_tier" else row[key]
	for key: String in TRAVEL_FACETS:
		if row.has(key):
			ordered[key] = row[key]
	return JSON.stringify(ordered, "", false) + "\n"


## The `LocationDefinition` resource text for one normalised scene document. Always written:
## id, scene_path, harmonic_accord, default_spawn_id, spawns. Written only when they differ from
## the script default: allowed_gameplay, thinning_tier, respawn_policy, weather_default,
## arrival_flag, arrival_checkpoint. That is exactly what the committed hand-written files held.
static func definition_text(row: Dictionary) -> String:
	var lines: Array[String] = [
		'[gd_resource type="Resource" script_class="LocationDefinition" load_steps=2 format=3]',
		"",
		'[ext_resource type="Script" path="%s" id="1_definition"]' % DEFINITION_SCRIPT,
		"",
		"[resource]",
		'script = ExtResource("1_definition")',
		"id = %s" % var_to_str(StringName(row["id"])),
		"scene_path = %s" % var_to_str(String(row["scene_path"])),
	]
	if not bool(row["allowed_gameplay"]):
		lines.append("allowed_gameplay = false")
	lines.append("harmonic_accord = %s" % var_to_str(float(row["harmonic_accord"])))
	if int(row["thinning_tier"]) != 0:
		lines.append("thinning_tier = %d" % int(row["thinning_tier"]))
	if String(row["respawn_policy"]) != "limited":
		lines.append("respawn_policy = %s" % var_to_str(String(row["respawn_policy"])))
	if not String(row["weather_default"]).is_empty():
		lines.append("weather_default = %s" % var_to_str(StringName(row["weather_default"])))
	lines.append("default_spawn_id = %s" % var_to_str(StringName(row["default_spawn_id"])))
	for field: String in ["arrival_flag", "arrival_checkpoint"]:
		if not String(row[field]).is_empty():
			lines.append("%s = %s" % [field, var_to_str(String(row[field]))])
	var spawns: Dictionary = row["spawns"]
	if spawns.is_empty():
		lines.append("spawns = {}")
	else:
		var entries: Array[String] = []
		var aliases: Array = spawns.keys()
		aliases.sort()
		for alias: Variant in aliases:
			entries.append("%s: %s" % [var_to_str(String(alias)), var_to_str(String(spawns[alias]))])
		lines.append("spawns = {\n%s\n}" % ",\n".join(entries))
	return "\n".join(lines) + "\n"


## One index row per location, sorted by id. The six E1.4e columns keep their meaning (empty
## strings where a scene-only location has no gazetteer facet); the scene columns are empty /
## false for a city with no playable scene.
static func index_text(normalised: Array[Dictionary], routes: Array[Dictionary] = []) -> String:
	var rows: Array[Dictionary] = []
	for row: Dictionary in normalised:
		rows.append({
			"id": row["id"],
			"display_name": String(row.get("display_name", "")),
			"epithet": String(row.get("epithet", "")),
			"patron": String(row.get("patron", "")),
			"agreement": String(row.get("agreement", "")),
			"vault_id": String(row.get("vault_id", "")),
			"definition_path": String(row.get("definition_path", "")),
			"scene_path": String(row.get("scene_path", "")),
			"no_combat_zone": bool(row.get("no_combat_zone", false)),
			"world_map": row.get("world_map"),
			"fast_travel": row.get("fast_travel"),
			"transition": null,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	var route_rows: Array[Dictionary] = []
	for route: Dictionary in routes:
		var entry: Dictionary = route.duplicate(true)
		entry.erase("schema")
		route_rows.append(entry)
	route_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	return JSON.stringify({"schema": INDEX_SCHEMA, "locations": rows, "routes": route_rows}, "  ", false) + "\n"


## res:// path → text for every artifact this kind bakes.
static func artifacts(normalised: Array[Dictionary], routes: Array[Dictionary] = []) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in normalised:
		if row.has("definition_path"):
			result[row["definition_path"]] = definition_text(row)
	result[INDEX_PATH] = index_text(normalised, routes)
	return result


func validate_routes(locations: Array[Dictionary], errors: Array[Dictionary]) -> Array[Dictionary]:
	var documents: Array[Dictionary] = []
	if route_documents == null:
		documents = WeftluminRoutesKind.load_canon(errors)
	else:
		documents.assign(route_documents)
	return WeftluminRoutesKind.new().validate_with_locations(documents, locations, errors)


# --- Bake ----------------------------------------------------------------------------------


## `weftlumin.bake.v1` report. `target_root` re-roots every `res://` artifact path (tests bake
## into a scratch directory); `write` writes changed artifacts. `force` has no effect: there is
## no hand-edit protection to override (whether `.tres` stays hand-editable is ruling 10's call),
## and a stale `.tres` with no canon document is reported as an orphan, never deleted.
func bake(normalised: Array[Dictionary], target_root: String, write: bool, force: bool) -> Dictionary:
	var _unused_force: bool = force
	var report: Dictionary = {
		"schema": BAKE_SCHEMA, "package": "canon", "mode": "write" if write else "report",
		"planned": [], "written": [], "regenerated": [], "orphans": [],
		"lint": {"errors": 0, "warnings": 0, "pot_delta": []},
		"refused_overlap": [], "errors": [], "summary": "",
	}
	var errors: Array[Dictionary] = []
	var routes: Array[Dictionary] = validate_routes(normalised, errors)
	if not errors.is_empty():
		report["errors"] = errors
		report["summary"] = "refused: invalid routes; nothing written"
		return report
	var texts: Dictionary = artifacts(normalised, routes)
	var paths: Array = texts.keys()
	paths.sort()
	var changed: int = 0
	for path: String in paths:
		var target: String = _retarget(path, target_root)
		var exists: bool = FileAccess.file_exists(target)
		var action: String = "unchanged"
		if not exists:
			action = "create"
		elif FileAccess.get_file_as_string(target) != texts[path]:
			action = "update"
		(report["planned"] as Array).append({"kind": String(id), "path": path, "action": action})
		if action == "unchanged":
			continue
		changed += 1
		if write:
			DirAccess.make_dir_recursive_absolute(target.get_base_dir())
			var file := FileAccess.open(target, FileAccess.WRITE)
			if file == null:
				(report["errors"] as Array).append(_error(path, "$", "writable artifact", "write_failed"))
				continue
			file.store_string(texts[path])
			file.close()
			(report["written"] as Array).append(path)
	for path: String in _committed_definitions(target_root):
		if not texts.has(path):
			(report["orphans"] as Array).append(path)
	for row: Dictionary in normalised:
		var notes: Array[String] = runtime_notes(row)
		(report["lint"] as Dictionary)["warnings"] = int(report["lint"]["warnings"]) + notes.size()
	report["summary"] = "%d locations, %d artifacts, %d changed, %d orphaned" % [
		normalised.size(), paths.size(), changed, (report["orphans"] as Array).size(),
	]
	return report


## True when canon fully explains the committed artifacts.
static func report_is_clean(report: Dictionary) -> bool:
	if not (report.get("errors", []) as Array).is_empty() or not (report.get("orphans", []) as Array).is_empty():
		return false
	for entry: Dictionary in report.get("planned", []):
		if entry["action"] != "unchanged":
			return false
	return true


static func _retarget(path: String, target_root: String) -> String:
	if target_root.is_empty() or target_root == "res://":
		return path
	return target_root.path_join(path.trim_prefix("res://"))


## Every committed `.tres` under the definitions root, as `res://` paths, sorted.
static func _committed_definitions(target_root: String) -> Array[String]:
	var found: Array[String] = []
	var pending: Array[String] = [DEFINITIONS_ROOT.trim_suffix("/")]
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		var physical: String = _retarget(directory, target_root)
		if not DirAccess.dir_exists_absolute(physical):
			continue
		for child: String in DirAccess.get_directories_at(physical):
			pending.append(directory.path_join(child))
		for filename: String in DirAccess.get_files_at(physical):
			if filename.get_extension() == "tres":
				found.append(directory.path_join(filename))
	found.sort()
	return found
