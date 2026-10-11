extends Node
## Spawn table model (E4.2 / #346) behind the Spawns panel.
##
## Reads `canon/<hub>/spawn_tables/*.json` through `WeftluminSpawnTablesKind` and edits a table's
## slots (anchor, respawn cadence, weighted entries, pack size) and its `caps.max_alive`. Identity
## (`id`, `scene_path`) is read-only: re-pointing a table at another scene is not an edit.
##
## Writes go ONLY to the draft directory (`user://weftlumin/spawn-drafts/spawn_tables/<id>.json`),
## in the kind's canonical text — the layout of the committed canon files, so promoting a draft is
## copying it over `canon/<hub>/spawn_tables/<id>.json`. It never writes `res://`. Every save
## validates the whole table set with the draft applied, including §4.10's invariants and the
## location's respawn policy, so a draft `SpawnDirector` would reject never reaches disk.
##
## It reads live slot state from `SaveGame.spawn_director` and never mutates it: `respawn now`
## and `clear slot` are `[debug]` console verbs (`dev_console.gd`), not panel actions.
##
## Inert until a panel hosts it (`host_in_panel()`), like every Weftlumin tool model.

const DRAFTS_ROOT := "user://weftlumin/spawn-drafts/spawn_tables"

## Test seams: alternative canon and draft roots.
var canon_root_for_tests: String = ""
var drafts_root_for_tests: String = ""

var _enabled: bool = false
var _kind := WeftluminSpawnTablesKind.new()
var _canon: Dictionary = {}
var _canon_files: Dictionary = {}
var _drafts: Dictionary = {}
var _load_errors: Array[Dictionary] = []
var _scene_root: Node = null


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
	_scene_root = null


## The live gameplay scene, whose markers count as anchors for its tables and whose slots the
## live view reports on.
func set_scene_root(root: Node) -> void:
	_scene_root = root if is_instance_valid(root) else null
	_kind.extra_anchors = {}
	if _scene_root != null and not _scene_root.scene_file_path.is_empty():
		_kind.extra_anchors[_scene_root.scene_file_path] = live_anchor_names()


func scene_root() -> Node:
	return _scene_root if is_instance_valid(_scene_root) else null


## Re-reads canon and the saved drafts. Returns the attributed load/validation errors.
func reload() -> Array[Dictionary]:
	_load_errors = []
	_canon.clear()
	_canon_files.clear()
	_drafts.clear()
	if not _enabled:
		return _load_errors
	_kind.clear_caches()
	_kind.canon_root = _canon_root()
	set_scene_root(_scene_root)
	var documents: Array[Dictionary] = WeftluminSpawnTablesKind.load_canon(_load_errors, _canon_root())
	for document: Dictionary in documents:
		_canon_files[String(document.get("id", ""))] = String(document[WeftluminSpawnTablesKind.META_FILE])
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


func table_ids() -> Array[String]:
	var ids: Array[String] = []
	for table_id: String in _canon:
		ids.append(table_id)
	ids.sort()
	return ids


func has_draft(table_id: String) -> bool:
	return _drafts.has(table_id)


## The current table: the saved draft when there is one, otherwise canon.
func document(table_id: String) -> Dictionary:
	if _drafts.has(table_id):
		return (_drafts[table_id] as Dictionary).duplicate(true)
	return (_canon.get(table_id, {}) as Dictionary).duplicate(true)


func canon_document(table_id: String) -> Dictionary:
	return (_canon.get(table_id, {}) as Dictionary).duplicate(true)


## The canon file a draft of `table_id` would replace.
func canon_path(table_id: String) -> String:
	return String(_canon_files.get(table_id, ""))


## Validates `row` (a whole table) in place of `document(id)`, against the whole table set.
## Returns {errors, row}; `row` is the normalised result when clean.
func preview_edit(table_id: String, row: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var result: Dictionary = {"errors": errors, "row": {}}
	if not _enabled:
		errors.append(WeftluminSpawnTablesKind._error("", "$", "a hosted model", "not_hosted"))
		return result
	if not _canon.has(table_id):
		errors.append(WeftluminSpawnTablesKind._error(table_id, "id", "a canon spawn table", "unknown_table"))
		return result
	var current: Dictionary = _canon[table_id]
	for field: String in ["id", "scene_path"]:
		if row.get(field) != current[field]:
			errors.append(WeftluminSpawnTablesKind._error(table_id, field, "unchanged (identity is read-only)", "read_only_field"))
	if not errors.is_empty():
		return result
	var edited: Dictionary = row.duplicate(true)
	edited[WeftluminSpawnTablesKind.META_FILE] = _drafts_root().path_join("%s.json" % table_id)
	var candidate: Array[Dictionary] = []
	for other_id: String in _canon:
		candidate.append(edited if other_id == table_id else document(other_id))
	for validated: Dictionary in _kind.validate(candidate, errors):
		if validated["id"] == table_id:
			result["row"] = validated
	return result


## Validates and writes the draft for `table_id`. Returns the attributed errors (empty = saved).
func save_draft(table_id: String, row: Dictionary) -> Array[Dictionary]:
	var preview: Dictionary = preview_edit(table_id, row)
	var errors: Array[Dictionary] = preview["errors"]
	if not errors.is_empty():
		return errors
	var normalised: Dictionary = preview["row"]
	var root: String = _drafts_root()
	DirAccess.make_dir_recursive_absolute(root)
	var path: String = root.path_join("%s.json" % table_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		errors.append(WeftluminSpawnTablesKind._error(path, "$", "writable draft", "write_failed"))
		return errors
	file.store_string(WeftluminSpawnTablesKind.canon_text(normalised))
	file.close()
	_drafts[table_id] = normalised
	return errors


func discard_draft(table_id: String) -> bool:
	if not _enabled or not _drafts.has(table_id):
		return false
	DirAccess.remove_absolute(_drafts_root().path_join("%s.json" % table_id))
	_drafts.erase(table_id)
	return true


## Non-blocking notes: unknown archetypes, and anchors that exist only in the live scene.
func notes(table_id: String) -> Array[String]:
	var row: Dictionary = document(table_id)
	var result: Array[String] = WeftluminSpawnTablesKind.notes(row)
	var root: Node = scene_root()
	if root == null or root.scene_file_path != String(row.get("scene_path", "")):
		return result
	var saved_kind := WeftluminSpawnTablesKind.new()
	var in_file: Dictionary = saved_kind.scene_anchors(root.scene_file_path)
	for slot: Dictionary in row.get("slots", []):
		if not in_file.has(slot["anchor"]) and root.find_child(String(slot["anchor"]), true, false) != null:
			result.append("Anchor %s is placed in the live scene only; the scene bake (E3.5) writes it to the .tscn."
				% slot["anchor"])
	return result


# --- Live slot state (read-only) -----------------------------------------------------------


## Names of the `Marker2D`s in the live scene.
func live_anchor_names() -> Array[String]:
	var names: Array[String] = []
	var root: Node = scene_root()
	if root == null:
		return names
	for node: Node in root.find_children("*", "Marker2D", true, false):
		names.append(String(node.name))
	return names


## One row per slot of `table_id`: `{slot_id, anchor, anchor_live, state, text}`. `state` is
## `SpawnDirector.slot_state()` (empty for a slot that has never rolled).
func live_slots(table_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var row: Dictionary = document(table_id)
	if row.is_empty():
		return rows
	var root: Node = scene_root()
	var in_scene: bool = root != null and root.scene_file_path == String(row["scene_path"])
	var day: int = WorldClock.day_index()
	for slot: Dictionary in row["slots"]:
		var state: Dictionary = SaveGame.spawn_director.slot_state(table_id, String(slot["id"]))
		var anchor_live: bool = in_scene and root.find_child(String(slot["anchor"]), true, false) != null
		rows.append({
			"slot_id": slot["id"], "anchor": slot["anchor"], "anchor_live": anchor_live,
			"state": state, "text": _describe(slot, state, day, in_scene, anchor_live),
		})
	return rows


static func _describe(slot: Dictionary, state: Dictionary, day: int, in_scene: bool, anchor_live: bool) -> String:
	var anchor: String = String(slot["anchor"])
	if not in_scene:
		anchor += " (scene not loaded)"
	elif not anchor_live:
		anchor += " MISSING"
	var status: String
	if state.is_empty():
		status = "never rolled"
	else:
		var members: Array = state["members"]
		var living: int = 0
		for member: Dictionary in members:
			if not bool(member["downed"]):
				living += 1
		if not members.is_empty():
			status = "%d/%d alive · %s · rolled day %d" % [living, members.size(), state["group_id"], int(state["spawned_day"])]
		elif int(state["cleared_day"]) != SpawnDirector.NEVER_CLEARED:
			status = "cleared day %d · authored cadence %d day(s)" % [int(state["cleared_day"]), int(slot["respawn_days"])]
		else:
			status = "empty, not cleared"
		if bool(state["blocked_by_cap"]):
			status += " · blocked by cap"
	return "%s · %s · %s · day %d" % [slot["id"], anchor, status, day]


func drafts_root() -> String:
	return _drafts_root()


func _canon_root() -> String:
	return canon_root_for_tests if not canon_root_for_tests.is_empty() else WeftluminSpawnTablesKind.CANON_ROOT


func _drafts_root() -> String:
	return drafts_root_for_tests if not drafts_root_for_tests.is_empty() else DRAFTS_ROOT
