extends Node
## Character model (E5.1 / #347) behind the Characters panel.
##
## Reads `canon/<hub>/characters/*.json` through `WeftluminCharactersKind` (with Soul Meter's
## registry declarations) and edits any declared kind — npc, archetype, recruit — field by field
## from the kind's contract, never from a hard-coded form. `stats` is opaque: edited key by key
## in the order its schema declares, validated by that schema.
##
## Writes go ONLY to the draft directory (`user://weftlumin/character-drafts/characters/<id>.json`,
## canonical text). It never writes `res://`. Identity (`schema`, `kind`, `id`, `order`) is fixed
## after create; `vault_id` is required on create for a kind that declares it, checked against the
## lore-vault index, never renamed and never filled in by the editor.
##
## Inert until a panel hosts it (`host_in_panel()`), like every Weftlumin tool model.

const DRAFTS_ROOT := "user://weftlumin/character-drafts/characters"
const READ_ONLY_FIELDS: Array[String] = ["schema", "kind", "id", "order"]

## Test seams: alternative canon root, draft root and vault index.
var canon_root_for_tests: String = ""
var drafts_root_for_tests: String = ""
var vault_index_path_for_tests: String = "":
	set(value):
		vault_index_path_for_tests = value
		_kind = WeftluminCharactersKind.soul_meter()
		_kind.vault_index_path_for_tests = value

var _enabled: bool = false
var _kind: WeftluminCharactersKind = WeftluminCharactersKind.soul_meter()
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


func kind() -> WeftluminCharactersKind:
	return _kind


## Re-reads canon and the saved drafts. Returns the attributed load/validation errors.
func reload() -> Array[Dictionary]:
	_load_errors = []
	_canon.clear()
	_drafts.clear()
	if not _enabled:
		return _load_errors
	var documents: Array[Dictionary] = WeftluminCharactersKind.load_canon(_load_errors, _canon_root())
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
			if not parsed is Dictionary:
				continue
			var batch: Array[Dictionary] = [parsed]
			var normalised: Array[Dictionary] = _kind.validate(batch, _load_errors)
			if not normalised.is_empty():
				_drafts[normalised[0]["id"]] = normalised[0]
	return _load_errors.duplicate(true)


func load_errors() -> Array[Dictionary]:
	return _load_errors.duplicate(true)


## Ids of every character (canon and new drafts), in `order` then id; `kind_name` filters.
func character_ids(kind_name: String = "") -> Array[String]:
	var rows: Array[Dictionary] = []
	for character_id: String in _all_ids():
		var row: Dictionary = document(character_id)
		if kind_name.is_empty() or row["kind"] == kind_name:
			rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["order"]) != float(b["order"]):
			return float(a["order"]) < float(b["order"])
		return String(a["id"]) < String(b["id"])
	)
	var ids: Array[String] = []
	for row: Dictionary in rows:
		ids.append(String(row["id"]))
	return ids


func has_draft(character_id: String) -> bool:
	return _drafts.has(character_id)


func is_new(character_id: String) -> bool:
	return _drafts.has(character_id) and not _canon.has(character_id)


## The current document: the saved draft when there is one, otherwise canon.
func document(character_id: String) -> Dictionary:
	if _drafts.has(character_id):
		return (_drafts[character_id] as Dictionary).duplicate(true)
	return (_canon.get(character_id, {}) as Dictionary).duplicate(true)


func canon_document(character_id: String) -> Dictionary:
	return (_canon.get(character_id, {}) as Dictionary).duplicate(true)


## Validates `edits` (field → value) applied over `document(id)`. Returns {errors, row}; `row`
## is the normalised result when clean. `stats` edits replace the block; a stats key whose value
## is `null` is removed.
func preview_edit(character_id: String, edits: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var result: Dictionary = {"errors": errors, "row": {}}
	if not _enabled:
		errors.append(WeftluminCharactersKind._error("", "$", "a hosted model", "not_hosted"))
		return result
	var previous: Dictionary = document(character_id)
	if previous.is_empty():
		errors.append(WeftluminCharactersKind._error(character_id, "id", "a known character", "unknown_character"))
		return result
	var row: Dictionary = previous.duplicate(true)
	for field: Variant in edits:
		if READ_ONLY_FIELDS.has(String(field)):
			errors.append(WeftluminCharactersKind._error(character_id, String(field), "an editable field", "read_only_field",
				"%s is identity; it cannot change on an existing character." % field))
		else:
			row[String(field)] = edits[field]
	if not errors.is_empty():
		return result
	# The vault rules judge against canon when the character is canon, so a draft cannot launder
	# a rename through two saves.
	var baseline: Dictionary = canon_document(character_id) if _canon.has(character_id) else previous
	errors.append_array(_kind.edit_problems(baseline, row))
	if errors.is_empty():
		var batch: Array[Dictionary] = [row]
		result["row"] = _kind.validate(batch, errors)[0]
	return result


## Validates and writes the draft for `character_id`. Returns the attributed errors (empty = saved).
func save_draft(character_id: String, edits: Dictionary) -> Array[Dictionary]:
	var preview: Dictionary = preview_edit(character_id, edits)
	var errors: Array[Dictionary] = preview["errors"]
	if not errors.is_empty():
		return errors
	return _write_draft(preview["row"])


## Creates a new character as a draft from the kind's skeleton. `vault_id` is the author's,
## verbatim; a kind that requires one refuses without it.
func create(kind_name: String, character_id: String, display_name: String, vault_id: String) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	if not _enabled:
		errors.append(WeftluminCharactersKind._error("", "$", "a hosted model", "not_hosted"))
		return errors
	if not _kind.character_kinds().has(kind_name):
		errors.append(WeftluminCharactersKind._error(character_id, "kind", "a declared character kind", "unknown_character_kind"))
		return errors
	var existing: Array[Dictionary] = []
	var highest: int = -1
	for known_id: String in _all_ids():
		var row: Dictionary = document(known_id)
		existing.append(row)
		highest = maxi(highest, int(row["order"]))
	var created: Dictionary = _kind.skeleton(kind_name, character_id, display_name, vault_id, highest + 1)
	errors.append_array(_kind.create_problems(created, existing))
	if not errors.is_empty():
		return errors
	var batch: Array[Dictionary] = [created]
	return _write_draft(_kind.validate(batch, errors)[0])


func discard_draft(character_id: String) -> bool:
	if not _enabled or not _drafts.has(character_id):
		return false
	DirAccess.remove_absolute(_drafts_root().path_join("%s.json" % character_id))
	_drafts.erase(character_id)
	return true


## A `weftlumin.bake.v1` report for canon with every saved draft applied. Report-only.
func bake_preview() -> Dictionary:
	var errors: Array[Dictionary] = []
	if not _enabled:
		errors.append(WeftluminCharactersKind._error("", "$", "a hosted model", "not_hosted"))
		return {"schema": WeftluminCharactersKind.BAKE_SCHEMA, "errors": errors, "planned": [], "orphans": []}
	var candidate: Array[Dictionary] = []
	for character_id: String in _all_ids():
		candidate.append(document(character_id))
	var normalised: Array[Dictionary] = _kind.validate(candidate, errors)
	if not errors.is_empty():
		return {"schema": WeftluminCharactersKind.BAKE_SCHEMA, "errors": errors, "planned": [], "orphans": []}
	return _kind.bake(normalised, _bake_root(), false, false)


func notes(character_id: String) -> Array[String]:
	return _kind.runtime_notes(document(character_id))


func drafts_root() -> String:
	return _drafts_root()


func _write_draft(row: Dictionary) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var root: String = _drafts_root()
	DirAccess.make_dir_recursive_absolute(root)
	var path: String = root.path_join("%s.json" % row["id"])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		errors.append(WeftluminCharactersKind._error(path, "$", "writable draft", "write_failed"))
		return errors
	file.store_string(WeftluminCharactersKind.canon_text(row))
	file.close()
	_drafts[row["id"]] = row
	return errors


func _all_ids() -> Array[String]:
	var ids: Dictionary = {}
	for character_id: String in _canon:
		ids[character_id] = true
	for character_id: String in _drafts:
		ids[character_id] = true
	var result: Array[String] = []
	result.assign(ids.keys())
	return result


func _canon_root() -> String:
	return canon_root_for_tests if not canon_root_for_tests.is_empty() else WeftluminCharactersKind.CANON_ROOT


## A test canon root re-roots the bake so its plan compares against that tree.
func _bake_root() -> String:
	if canon_root_for_tests.is_empty():
		return "res://"
	return canon_root_for_tests.get_base_dir()


func _drafts_root() -> String:
	return drafts_root_for_tests if not drafts_root_for_tests.is_empty() else DRAFTS_ROOT
