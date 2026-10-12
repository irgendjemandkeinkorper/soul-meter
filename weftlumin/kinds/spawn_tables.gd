class_name WeftluminSpawnTablesKind
extends WeftluminKind
## The `spawn_tables` kind (architecture §4.10, E4.2 / #346): `canon/<hub>/spawn_tables/<id>.json`
## documents in the `weftlumin.spawn_table.v1` schema. `SpawnDirector` (E4.1 / #345) reads these
## files directly at runtime, so there is nothing to bake: this kind validates, normalises, diffs
## and writes the canonical text the Spawns panel saves as a draft.
##
## Validation is §4.10 step 5's invariants, each as an attributed error (`file`, `field` as a
## path such as `slots[0].entries[2].weight`, `expected`, `code`, `message`):
##
## - every slot has at least one non-empty entry with `weight > 0`;
## - weights are positive integers;
## - `respawn_days >= 1`;
## - `pack_size.min >= 1` (and `max >= min`, the bound `SpawnDirector.table_problems()` holds too);
## - the anchor marker exists in the scene.
##
## plus the location's `respawn_policy` (ruling 13), through `SpawnMath.policy_violations()`: a
## `none` scene refuses every table and a `limited` one enforces the provisional bounds. A scene
## with no location document is treated as `none`, exactly as `SpawnDirector.live_context()` does.
##
## Roll semantics are E4.1's; nothing here weights, scales or rolls.

const SCHEMA := "weftlumin.spawn_table.v1"
const CANON_ROOT := "res://canon"
## Load-time-only keys `load_canon()` attaches for error attribution; never written back.
const META_FILE := "$file"
const META_HUB := "$hub"

const TABLE_FIELDS: Array[String] = ["schema", "id", "scene_path", "slots", "caps"]
const SLOT_FIELDS: Array[String] = ["id", "anchor", "respawn_days", "entries", "pack_size"]
const CAP_FIELDS: Array[String] = ["max_alive"]
## The node-name stem the spawn panel gives an anchor marker (§4.10: `SpawnSlot<PascalCase>`).
const ANCHOR_PREFIX := "SpawnSlot"

## Test/panel seam: `scene_path` -> anchor names that count as present even though the `.tscn`
## does not hold them yet (a marker placed in the live scene before the scene bake, E3.5).
var extra_anchors: Dictionary = {}
## Test seam: `scene_path` -> respawn policy. Empty means read the locations canon.
var policies_for_tests: Dictionary = {}
## Canon root the location policies are read from.
var canon_root: String = CANON_ROOT

var _policies: Dictionary = {}
var _policies_loaded: bool = false
var _anchor_cache: Dictionary = {}


func _init() -> void:
	id = &"spawn_tables"
	subdir = "spawn_tables"
	ext = "json"
	stable_id_kind = &"spawn_table"


# --- Discovery -----------------------------------------------------------------------------


## Every `canon/<hub>/spawn_tables/*.json` in a stable (hub, filename) order, each tagged with its
## file and hub. Unreadable or non-object files append an attributed error and are skipped.
static func load_canon(errors: Array[Dictionary], root: String = CANON_ROOT) -> Array[Dictionary]:
	var documents: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(root):
		errors.append(_error(root, "$", "canon root directory", "missing_canon_root"))
		return documents
	var hubs: PackedStringArray = DirAccess.get_directories_at(root)
	hubs.sort()
	for hub: String in hubs:
		var kind_root: String = root.path_join(hub).path_join("spawn_tables")
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


## Pure apart from reading scenes and the location policies: returns normalised documents (ints,
## canonical key order, meta keys dropped) sorted by id, or an empty array when any error was
## appended.
func validate(documents: Array[Dictionary], errors: Array[Dictionary]) -> Array[Dictionary]:
	var normalised: Array[Dictionary] = []
	var error_count: int = errors.size()
	var seen_ids: Dictionary = {}
	for index: int in documents.size():
		var document: Dictionary = documents[index]
		var file: String = String(document.get(META_FILE, "spawn_tables[%d]" % index))
		var row: Dictionary = normalise(document, file, errors)
		if row.is_empty():
			continue
		var table_id: String = row["id"]
		if seen_ids.has(table_id):
			errors.append(_error(file, "id", "unique spawn table id", "duplicate_id",
				"Spawn table id '%s' is also declared by %s." % [table_id, seen_ids[table_id]]))
			continue
		seen_ids[table_id] = file
		normalised.append(row)
	if errors.size() != error_count:
		return []
	normalised.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	return normalised


## One document → its normalised row, or `{}` when it appended an error.
func normalise(document: Dictionary, file: String, errors: Array[Dictionary]) -> Dictionary:
	var error_count: int = errors.size()
	for key: Variant in document.keys():
		if not (TABLE_FIELDS.has(String(key)) or String(key) in [META_FILE, META_HUB]):
			errors.append(_error(file, String(key), "a %s field" % SCHEMA, "unknown_field"))
	if document.get("schema") != SCHEMA:
		errors.append(_error(file, "schema", SCHEMA, "unsupported_schema"))
	var table_id: Variant = document.get("id")
	if not table_id is String or not _is_stable_id(table_id):
		errors.append(_error(file, "id", "lower-case stable id ([a-z0-9_-]+)", "invalid_id"))
	var row: Dictionary = {"schema": SCHEMA, "id": String(table_id) if table_id is String else ""}

	var scene_path: Variant = document.get("scene_path")
	var scene_ok: bool = false
	if not scene_path is String or not String(scene_path).begins_with("res://") or String(scene_path).get_extension() != "tscn":
		errors.append(_error(file, "scene_path", "res:// path to a .tscn", "invalid_scene_path"))
	elif not FileAccess.file_exists(scene_path):
		errors.append(_error(file, "scene_path", "an existing scene", "missing_scene",
			"Scene '%s' does not exist." % scene_path))
	else:
		scene_ok = true
	row["scene_path"] = String(scene_path) if scene_path is String else ""

	var raw_slots: Variant = document.get("slots")
	var slots: Array = []
	if not raw_slots is Array or (raw_slots as Array).is_empty():
		errors.append(_error(file, "slots", "a non-empty array of slots", "invalid_slots"))
	else:
		var anchors: Dictionary = scene_anchors(String(scene_path)) if scene_ok else {}
		var seen_slots: Dictionary = {}
		for index: int in (raw_slots as Array).size():
			var raw_slot: Variant = (raw_slots as Array)[index]
			var raw_id: Variant = (raw_slot as Dictionary).get("id") if raw_slot is Dictionary else null
			if raw_id is String and seen_slots.has(raw_id):
				errors.append(_error(file, "slots[%d].id" % index, "unique slot id", "duplicate_slot",
					"Slot id '%s' is repeated." % raw_id))
			if raw_id is String:
				seen_slots[raw_id] = true
			var slot: Dictionary = _normalise_slot(raw_slot, index, file, errors)
			if slot.is_empty():
				continue
			if scene_ok and not anchors.has(slot["anchor"]):
				errors.append(_error(file, "slots[%d].anchor" % index, "a marker in %s" % scene_path, "missing_anchor",
					"Anchor '%s' does not exist in %s." % [slot["anchor"], scene_path]))
			slots.append(slot)
	row["slots"] = slots

	var raw_caps: Variant = document.get("caps", {})
	var caps: Dictionary = {}
	if not raw_caps is Dictionary:
		errors.append(_error(file, "caps", "an object", "invalid_field_type"))
	else:
		for key: Variant in (raw_caps as Dictionary).keys():
			if not CAP_FIELDS.has(String(key)):
				errors.append(_error(file, "caps.%s" % key, "max_alive", "unknown_field"))
		if (raw_caps as Dictionary).has("max_alive"):
			var cap: Variant = raw_caps["max_alive"]
			if not _is_whole(cap) or int(cap) < 1:
				errors.append(_error(file, "caps.max_alive", "integer >= 1 (omit for the policy default)", "out_of_range"))
			else:
				caps["max_alive"] = int(cap)
	row["caps"] = caps

	if errors.size() == error_count and scene_ok:
		var policy: String = policy_for_scene(String(scene_path))
		var violations: PackedStringArray = SpawnMath.policy_violations(policy, row)
		if not has_location(String(scene_path)) and not violations.is_empty():
			violations = PackedStringArray([
				"No location document targets %s, so SpawnDirector treats it as respawn_policy \"none\"." % scene_path
			])
		for violation: String in violations:
			errors.append(_error(file, "respawn_policy", "a table within the scene's \"%s\" bounds" % policy,
				"policy_refused", violation))
	return row if errors.size() == error_count else {}


func _normalise_slot(raw: Variant, index: int, file: String, errors: Array[Dictionary]) -> Dictionary:
	var at: String = "slots[%d]" % index
	if not raw is Dictionary:
		errors.append(_error(file, at, "a slot object", "invalid_slot"))
		return {}
	var source: Dictionary = raw
	var error_count: int = errors.size()
	for key: Variant in source.keys():
		if not SLOT_FIELDS.has(String(key)):
			errors.append(_error(file, "%s.%s" % [at, key], "a slot field", "unknown_field"))
	var slot: Dictionary = {}
	var slot_id: Variant = source.get("id")
	if not slot_id is String or not _is_stable_id(slot_id):
		errors.append(_error(file, at + ".id", "lower-case stable id ([a-z0-9_-]+)", "invalid_id"))
	slot["id"] = String(slot_id) if slot_id is String else ""
	var anchor: Variant = source.get("anchor")
	if not anchor is String or String(anchor).strip_edges().is_empty() or String(anchor).validate_node_name() != anchor:
		errors.append(_error(file, at + ".anchor", "a node name", "invalid_anchor"))
	slot["anchor"] = String(anchor) if anchor is String else ""
	var days: Variant = source.get("respawn_days")
	if not _is_whole(days) or int(days) < 1:
		errors.append(_error(file, at + ".respawn_days", "integer >= 1", "out_of_range"))
	else:
		slot["respawn_days"] = int(days)

	var raw_entries: Variant = source.get("entries")
	var entries: Array = []
	var has_creature: bool = false
	if not raw_entries is Array:
		errors.append(_error(file, at + ".entries", "an array of entries", "invalid_entries"))
	else:
		for entry_index: int in (raw_entries as Array).size():
			var entry_at: String = "%s.entries[%d]" % [at, entry_index]
			var raw_entry: Variant = (raw_entries as Array)[entry_index]
			if not raw_entry is Dictionary:
				errors.append(_error(file, entry_at, "an entry object", "invalid_entry"))
				continue
			var entry: Dictionary = raw_entry
			var weight: Variant = entry.get("weight")
			var weight_ok: bool = _is_whole(weight) and int(weight) > 0
			if not weight_ok:
				errors.append(_error(file, entry_at + ".weight", "positive integer", "invalid_weight"))
			var is_empty: bool = entry.get("empty", false) == true
			var allowed: Array = ["empty", "weight"] if is_empty else ["archetype_id", "weight"]
			for key: Variant in entry.keys():
				if not allowed.has(String(key)):
					errors.append(_error(file, "%s.%s" % [entry_at, key],
						"empty + weight, or archetype_id + weight", "unknown_field"))
			if is_empty:
				entries.append({"empty": true, "weight": int(weight) if weight_ok else 0})
				continue
			var archetype: Variant = entry.get("archetype_id")
			if not archetype is String or String(archetype).strip_edges().is_empty():
				errors.append(_error(file, entry_at + ".archetype_id", "archetype id, or \"empty\": true", "invalid_archetype"))
				continue
			entries.append({"archetype_id": String(archetype), "weight": int(weight) if weight_ok else 0})
			has_creature = has_creature or weight_ok
		if not has_creature:
			errors.append(_error(file, at + ".entries", "at least one non-empty entry with weight > 0", "no_creature_entry"))
	slot["entries"] = entries

	var pack: Variant = source.get("pack_size")
	if not pack is Dictionary:
		errors.append(_error(file, at + ".pack_size", "{min, max}", "invalid_pack_size"))
	else:
		var pack_min: Variant = (pack as Dictionary).get("min")
		var pack_max: Variant = (pack as Dictionary).get("max")
		if not _is_whole(pack_min) or int(pack_min) < 1:
			errors.append(_error(file, at + ".pack_size.min", "integer >= 1", "out_of_range"))
		elif not _is_whole(pack_max) or int(pack_max) < int(pack_min):
			errors.append(_error(file, at + ".pack_size.max", "integer >= pack_size.min", "out_of_range"))
		else:
			slot["pack_size"] = {"min": int(pack_min), "max": int(pack_max)}
	return slot if errors.size() == error_count else {}


## Non-blocking authoring notes for one normalised table: an archetype the encounter catalog does
## not know would be skipped at spawn time (`EncounterCatalog.make_actor()` returns null).
static func notes(row: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for slot: Dictionary in row.get("slots", []):
		for entry: Dictionary in slot.get("entries", []):
			if entry.has("archetype_id") and EncounterCatalog.committed_archetype(String(entry["archetype_id"])).is_empty():
				result.append("Slot '%s': archetype '%s' is not in the encounter catalog; it would spawn nothing."
					% [slot["id"], entry["archetype_id"]])
	return result


# --- Scene and location lookups ------------------------------------------------------------


## Names of every node in the scene file, plus `extra_anchors` for it. Read once per scene.
func scene_anchors(scene_path: String) -> Dictionary:
	if not _anchor_cache.has(scene_path):
		var names: Dictionary = {}
		if FileAccess.file_exists(scene_path):
			var document: TscnDocument = TscnDocument.parse(FileAccess.get_file_as_string(scene_path))
			for node: Dictionary in document.nodes:
				names[str((node["attributes"] as Dictionary).get("name", ""))] = true
		_anchor_cache[scene_path] = names
	var result: Dictionary = (_anchor_cache[scene_path] as Dictionary).duplicate()
	for extra: Variant in extra_anchors.get(scene_path, []):
		result[String(extra)] = true
	return result


## Forget cached scene reads (the panel calls this on reload).
func clear_caches() -> void:
	_anchor_cache.clear()
	_policies.clear()
	_policies_loaded = false


## The `respawn_policy` of the location whose scene is `scene_path`, or `none` with no location.
func policy_for_scene(scene_path: String) -> String:
	if not policies_for_tests.is_empty():
		return String(policies_for_tests.get(scene_path, "none"))
	_load_policies()
	return String(_policies.get(scene_path, "none"))


func has_location(scene_path: String) -> bool:
	if not policies_for_tests.is_empty():
		return policies_for_tests.has(scene_path)
	_load_policies()
	return _policies.has(scene_path)


func _load_policies() -> void:
	if _policies_loaded:
		return
	_policies_loaded = true
	var ignored: Array[Dictionary] = []
	for document: Dictionary in WeftluminLocationsKind.load_canon(ignored, canon_root):
		var scene: Variant = document.get("scene_path")
		var policy: Variant = document.get("respawn_policy")
		if scene is String and policy is String:
			_policies[scene] = policy


## `SpawnSlot<PascalCase>` for a slot id: `hollow-east` → `SpawnSlotHollowEast`.
static func anchor_name_for(slot_id: String) -> String:
	var result: String = ANCHOR_PREFIX
	for part: String in slot_id.replace("_", "-").split("-", false):
		result += part.substr(0, 1).to_upper() + part.substr(1)
	return result


static func _is_stable_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character: String in value:
		if not (character in "abcdefghijklmnopqrstuvwxyz0123456789_-"):
			return false
	return true


## JSON hands every number back as a float, so a whole number is either type.
static func _is_whole(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_equal_approx(value, roundf(value))


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
	for table_id: String in before:
		if not after_ids.has(table_id):
			removed.append(table_id)
	return {
		"changed": not (added.is_empty() and modified.is_empty() and removed.is_empty()),
		"added": added, "modified": modified, "removed": removed,
	}


# --- Text form -----------------------------------------------------------------------------


## The canonical on-disk form of one table: tab-indented, one slot field per line, each entry,
## `pack_size` and `caps` on one line, one trailing newline. It is the layout the committed canon
## tables were written in, so a draft of an unchanged table is byte-identical to its canon file
## and promoting a draft is a copy.
static func canon_text(row: Dictionary) -> String:
	var lines: Array[String] = ["{"]
	lines.append('\t"schema": %s,' % JSON.stringify(SCHEMA))
	lines.append('\t"id": %s,' % JSON.stringify(String(row.get("id", ""))))
	lines.append('\t"scene_path": %s,' % JSON.stringify(String(row.get("scene_path", ""))))
	lines.append('\t"slots": [')
	var slots: Array = row.get("slots", [])
	for slot_index: int in slots.size():
		var slot: Dictionary = slots[slot_index]
		lines.append("\t\t{")
		lines.append('\t\t\t"id": %s,' % JSON.stringify(String(slot["id"])))
		lines.append('\t\t\t"anchor": %s,' % JSON.stringify(String(slot["anchor"])))
		lines.append('\t\t\t"respawn_days": %d,' % int(slot["respawn_days"]))
		lines.append('\t\t\t"entries": [')
		var entries: Array = slot["entries"]
		for entry_index: int in entries.size():
			var entry: Dictionary = entries[entry_index]
			var ordered: Dictionary = {}
			if entry.has("empty"):
				ordered["empty"] = true
			else:
				ordered["archetype_id"] = String(entry["archetype_id"])
			ordered["weight"] = int(entry["weight"])
			lines.append("\t\t\t\t%s%s" % [_inline(ordered), "," if entry_index < entries.size() - 1 else ""])
		lines.append("\t\t\t],")
		var pack: Dictionary = slot["pack_size"]
		lines.append('\t\t\t"pack_size": %s' % _inline({"min": int(pack["min"]), "max": int(pack["max"])}))
		lines.append("\t\t}%s" % ("," if slot_index < slots.size() - 1 else ""))
	lines.append("\t],")
	var caps: Dictionary = row.get("caps", {})
	var ordered_caps: Dictionary = {}
	for key: String in CAP_FIELDS:
		if caps.has(key):
			ordered_caps[key] = int(caps[key])
	lines.append('\t"caps": %s' % _inline(ordered_caps))
	lines.append("}")
	return "\n".join(lines) + "\n"


## `{"a": 1, "b": "x"}` with `": "` / `", "` separators; values are ints, bools or strings.
static func _inline(values: Dictionary) -> String:
	var parts: Array[String] = []
	for key: Variant in values:
		parts.append("%s: %s" % [JSON.stringify(String(key)), JSON.stringify(values[key])])
	return "{%s}" % ", ".join(parts)
