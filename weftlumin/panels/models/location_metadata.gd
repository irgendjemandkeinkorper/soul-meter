extends Node
## Location metadata model (E3.3a / #341) behind the Locations panel.
##
## Reads `canon/<hub>/locations/*.json` through `WeftluminLocationsKind` and edits the hidden
## state of the locations that have a scene: Harmonic Accord, thinning tier, weather default,
## no-combat zone, respawn policy, gameplay permission, spawns and the arrival flag/checkpoint.
## Identity (`id`, `definition_path`, `scene_path`) and the gazetteer facet are read-only here:
## renaming or re-pointing a location is not metadata.
##
## Writes go ONLY to the draft directory (`user://weftlumin/location-drafts/locations/<id>.json`,
## canonical text). It never writes `res://`: promoting drafts into canon and regenerating the
## `.tres` + index is `tools/generate_locations.gd` with `SOUL_METER_LOCATION_DRAFTS`. Every
## save validates the whole location set with the draft applied, so a draft that would break
## the bake (a duplicate scene, an unknown weather) is refused before it reaches disk.
##
## Inert until a panel hosts it (`host_in_panel()`), like every Weftlumin tool model.

const DRAFTS_ROOT := "user://weftlumin/location-drafts/locations"
const EDITABLE_FIELDS: Array[String] = [
	"allowed_gameplay", "default_spawn_id", "spawns", "arrival_flag", "arrival_checkpoint",
	"harmonic_accord", "thinning_tier", "weather_default", "no_combat_zone", "respawn_policy",
]

## Test seams: alternative canon and draft roots.
var canon_root_for_tests: String = ""
var drafts_root_for_tests: String = ""

var _enabled: bool = false
var _kind := WeftluminLocationsKind.new()
var _canon: Dictionary = {}
var _drafts: Dictionary = {}
var _load_errors: Array[Dictionary] = []


func is_enabled() -> bool:
	return _enabled


func host_in_panel() -> bool:
	if not OS.is_debug_build() or not is_inside_tree():
		return false
	_enabled = true
	reload()
	return true


func _exit_tree() -> void:
	_enabled = false


## Re-reads canon and the saved drafts. Returns the attributed load/validation errors.
func reload() -> Array[Dictionary]:
	_load_errors = []
	_canon.clear()
	_drafts.clear()
	if not _enabled:
		return _load_errors
	var documents: Array[Dictionary] = WeftluminLocationsKind.load_canon(_load_errors, _canon_root())
	for row: Dictionary in _kind.validate(documents.duplicate(true), _load_errors):
		_canon[row["id"]] = row
	var root: String = _drafts_root()
	if DirAccess.dir_exists_absolute(root):
		var filenames: PackedStringArray = DirAccess.get_files_at(root)
		filenames.sort()
		for filename: String in filenames:
			if filename.get_extension() != "json":
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(filename)))
			if parsed is Dictionary and _canon.has((parsed as Dictionary).get("id")):
				var batch: Array[Dictionary] = [parsed]
				var normalised: Array[Dictionary] = _kind.validate(batch, _load_errors)
				if not normalised.is_empty():
					_drafts[normalised[0]["id"]] = normalised[0]
	return _load_errors.duplicate(true)


func load_errors() -> Array[Dictionary]:
	return _load_errors.duplicate(true)


## Ids of the locations that have a scene facet, sorted.
func location_ids() -> Array[String]:
	var ids: Array[String] = []
	for location_id: String in _canon:
		if (_canon[location_id] as Dictionary).has("scene_path"):
			ids.append(location_id)
	ids.sort()
	return ids


func has_draft(location_id: String) -> bool:
	return _drafts.has(location_id)


## The current document: the saved draft when there is one, otherwise canon.
func document(location_id: String) -> Dictionary:
	if _drafts.has(location_id):
		return (_drafts[location_id] as Dictionary).duplicate(true)
	return (_canon.get(location_id, {}) as Dictionary).duplicate(true)


func canon_document(location_id: String) -> Dictionary:
	return (_canon.get(location_id, {}) as Dictionary).duplicate(true)


## Validates `edits` (field → value, editable fields only) applied over `document(id)`, against
## the whole location set. Returns {errors, row}; `row` is the normalised result when clean.
func preview_edit(location_id: String, edits: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var result: Dictionary = {"errors": errors, "row": {}}
	if not _enabled:
		errors.append(WeftluminLocationsKind._error("", "$", "a hosted model", "not_hosted"))
		return result
	if not _canon.has(location_id) or not (_canon[location_id] as Dictionary).has("scene_path"):
		errors.append(WeftluminLocationsKind._error(location_id, "id", "a canon location with a scene", "unknown_location"))
		return result
	var row: Dictionary = document(location_id)
	for field: Variant in edits:
		if not EDITABLE_FIELDS.has(String(field)):
			errors.append(WeftluminLocationsKind._error(location_id, String(field), "an editable metadata field", "read_only_field"))
		else:
			row[String(field)] = edits[field]
	if not errors.is_empty():
		return result
	var candidate: Array[Dictionary] = []
	for other_id: String in _canon:
		candidate.append(row if other_id == location_id else document(other_id))
	var normalised: Array[Dictionary] = _kind.validate(candidate, errors)
	for validated: Dictionary in normalised:
		if validated["id"] == location_id:
			result["row"] = validated
	return result


## Validates and writes the draft for `location_id`. Returns the attributed errors (empty = saved).
func save_draft(location_id: String, edits: Dictionary) -> Array[Dictionary]:
	var preview: Dictionary = preview_edit(location_id, edits)
	var errors: Array[Dictionary] = preview["errors"]
	if not errors.is_empty():
		return errors
	var row: Dictionary = preview["row"]
	var root: String = _drafts_root()
	DirAccess.make_dir_recursive_absolute(root)
	var path: String = root.path_join("%s.json" % location_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		errors.append(WeftluminLocationsKind._error(path, "$", "writable draft", "write_failed"))
		return errors
	file.store_string(WeftluminLocationsKind.canon_text(row))
	file.close()
	_drafts[location_id] = row
	return errors


func discard_draft(location_id: String) -> bool:
	if not _enabled or not _drafts.has(location_id):
		return false
	DirAccess.remove_absolute(_drafts_root().path_join("%s.json" % location_id))
	_drafts.erase(location_id)
	return true


## A `weftlumin.bake.v1` report for canon with every saved draft applied. Report-only: it plans
## the `.tres`/index changes the generator would make and writes nothing.
func bake_preview() -> Dictionary:
	var errors: Array[Dictionary] = []
	if not _enabled:
		errors.append(WeftluminLocationsKind._error("", "$", "a hosted model", "not_hosted"))
		return {"schema": WeftluminLocationsKind.BAKE_SCHEMA, "errors": errors, "planned": [], "orphans": []}
	var candidate: Array[Dictionary] = []
	for location_id: String in _canon:
		candidate.append(document(location_id))
	var normalised: Array[Dictionary] = _kind.validate(candidate, errors)
	if not errors.is_empty():
		return {"schema": WeftluminLocationsKind.BAKE_SCHEMA, "errors": errors, "planned": [], "orphans": []}
	return _kind.bake(normalised, "res://", false, false)


func notes(location_id: String) -> Array[String]:
	return WeftluminLocationsKind.runtime_notes(document(location_id))


func drafts_root() -> String:
	return _drafts_root()


func _canon_root() -> String:
	return canon_root_for_tests if not canon_root_for_tests.is_empty() else WeftluminLocationsKind.CANON_ROOT


func _drafts_root() -> String:
	return drafts_root_for_tests if not drafts_root_for_tests.is_empty() else DRAFTS_ROOT
