class_name WeftluminPatternLibrary
extends RefCounted
## The pattern library (reusable prop groups) as `pattern` document ops on the command bus
## (`docs/architecture-in-game-editor.md` §4.6.1, E3.1c #370).
##
## The format is `globals/layout_patterns.gd` schema 1 and is not this file's to change: every
## write here is a whole schema-1 document produced by `LayoutPatterns`, and a rename touches
## only the `id` and `name` values. What this file adds is *where* patterns live and that every
## library write is one undoable, logged command.
##
## **Two sources.** The owner's working library is `user://layout_patterns/` (scratch, like
## layout overrides). A pattern worth keeping is **promoted** into the repo directory, which the
## browser treats as read-only: rename and delete refuse a repo pattern, and the only write that
## reaches the repo is a promotion. Saving under a repo pattern's name writes a user-side copy
## that shadows it until it is promoted over it, so a repo pattern can be revised without ever
## being edited in place.
##
## **Undo.** Each op's `pre_state` is the content of every file it touches (or their absence),
## captured by the bus; revert writes that back. The library holds no other state, so undo after
## a save, rename, delete or promotion restores exactly the files that were there.

signal changed

const Patterns := preload("res://globals/layout_patterns.gd")

const KIND := "pattern"
const OP_SAVE := "save"
const OP_RENAME := "rename"
const OP_DELETE := "delete"
const OP_PROMOTE := "promote"
const SOURCE_USER := "user"
const SOURCE_REPO := "repo"
## Where promoted patterns live in the repo. Only the editor reads it; it is authoring material,
## not game data.
const REPO_DIRECTORY := "res://weftlumin/patterns"

var user_directory: String = Patterns.PATTERN_DIRECTORY
var repo_directory: String = REPO_DIRECTORY


func register_ops(command_bus: WeftluminCommandBus) -> void:
	for op: String in [OP_SAVE, OP_RENAME, OP_DELETE, OP_PROMOTE]:
		command_bus.register_document_op(KIND, op, _capture, _apply, _revert)


## Every pattern in both sources as `{pattern, source, path}`: user patterns first, then repo
## patterns, each sorted by id (the order `LayoutPatterns.list_patterns` gives).
func entries() -> Array[Dictionary]:
	var listed: Array[Dictionary] = []
	for source: String in [SOURCE_USER, SOURCE_REPO]:
		for pattern: Dictionary in Patterns.list_patterns(_directory(source)):
			listed.append({
				"pattern": pattern, "source": source,
				"path": path_for(StringName(str(pattern["id"])), source),
			})
	return listed


func path_for(id: StringName, source: String = SOURCE_USER) -> String:
	return _directory(source).path_join("%s.json" % String(id))


func has_pattern(id: StringName, source: String = SOURCE_USER) -> bool:
	return FileAccess.file_exists(path_for(id, source))


# --- command constructors ----------------------------------------------------------------------


## Write a captured schema-1 document to the user library (creating or replacing it).
func save_command(pattern: Dictionary, package_name: String = "") -> WeftluminCommand:
	return WeftluminCommand.make(
		KIND, OP_SAVE, {"pattern": str(pattern.get("id", "")), "source": SOURCE_USER},
		{"pattern": pattern.duplicate(true)}, package_name,
	)


func rename_command(id: StringName, display_name: String, package_name: String = "") -> WeftluminCommand:
	var trimmed: String = display_name.strip_edges()
	return WeftluminCommand.make(
		KIND, OP_RENAME, {"pattern": String(id), "source": SOURCE_USER},
		{"to": String(Patterns.id_for_name(trimmed)), "name": trimmed}, package_name,
	)


func delete_command(id: StringName, package_name: String = "") -> WeftluminCommand:
	return WeftluminCommand.make(
		KIND, OP_DELETE, {"pattern": String(id), "source": SOURCE_USER}, {}, package_name,
	)


## Move a user pattern into the repo directory, replacing a repo pattern of the same id.
func promote_command(id: StringName, package_name: String = "") -> WeftluminCommand:
	return WeftluminCommand.make(
		KIND, OP_PROMOTE, {"pattern": String(id), "source": SOURCE_USER}, {}, package_name,
	)


# --- bus handlers ------------------------------------------------------------------------------


func _capture(command: WeftluminCommand) -> Dictionary:
	var files: Dictionary = {}
	for path: String in _touched_paths(command):
		files[path] = _read(path)
	return {"files": files}


func _apply(command: WeftluminCommand) -> Dictionary:
	var id := StringName(str(command.target.get("pattern", "")))
	if String(id).is_empty():
		return _blocked(&"pattern", &"pattern_id", "No pattern named.")
	var source_path: String = path_for(id, SOURCE_USER)
	var error: Error = OK
	match command.op:
		OP_SAVE:
			var pattern: Dictionary = (command.params.get("pattern", {}) as Dictionary).duplicate(true)
			if str(pattern.get("id", "")) != String(id) or Patterns.to_json(pattern).is_empty():
				return _blocked(&"schema", &"known_schema", "That pattern cannot be saved.")
			# A command replayed from the JSONL log comes back with every number a float.
			pattern["schema"] = Patterns.SCHEMA_VERSION
			error = Patterns.save_file(source_path, pattern)
		OP_RENAME:
			var text: String = _read(source_path).get("content", "")
			if Patterns.from_json(text).is_empty():
				return _missing(id)
			var to := StringName(str(command.params.get("to", "")))
			var display_name: String = str(command.params.get("name", ""))
			if String(to).is_empty():
				return _blocked(&"name", &"pattern_name", "A pattern needs a name with letters or digits.")
			if to != id and has_pattern(to, SOURCE_USER):
				return _blocked(&"name", &"unused_pattern_name", "A pattern named %s already exists." % display_name)
			error = LayoutOverrides.save_json(path_for(to, SOURCE_USER), renamed_text(text, to, display_name))
			if error == OK and to != id:
				error = _remove(source_path)
		OP_DELETE:
			if not FileAccess.file_exists(source_path):
				return _missing(id)
			error = _remove(source_path)
		OP_PROMOTE:
			var promoted: String = _read(source_path).get("content", "")
			if Patterns.from_json(promoted).is_empty():
				return _missing(id)
			# Byte-for-byte: the repo file is exactly what the owner saved.
			error = LayoutOverrides.save_json(path_for(id, SOURCE_REPO), promoted)
			if error == OK:
				error = _remove(source_path)
		_:
			return _blocked(&"handler", &"pattern_op", "Unknown pattern op %s." % command.op)
	if error != OK:
		return _blocked(&"save", &"writable_library", "Pattern library write failed: %s." % error_string(error))
	changed.emit()
	return _allowed()


func _revert(command: WeftluminCommand) -> Dictionary:
	var files: Dictionary = command.pre_state.get("files", {}) as Dictionary
	for path: Variant in files:
		var state: Dictionary = files[path] as Dictionary
		var error: Error = OK
		if bool(state.get("exists", false)):
			error = LayoutOverrides.save_json(str(path), str(state.get("content", "")))
		elif FileAccess.file_exists(str(path)):
			error = _remove(str(path))
		if error != OK:
			return _blocked(&"save", &"writable_library", "Could not restore %s: %s." % [path, error_string(error)])
	changed.emit()
	return _allowed()


## `content` with only its top-level `id` and `name` values replaced. Everything else keeps its
## bytes: a parse/re-serialise round trip would turn every integer in the file into a float.
static func renamed_text(content: String, id: StringName, display_name: String) -> String:
	var result: String = content
	for entry: Array in [["id", String(id)], ["name", display_name]]:
		var line := RegEx.create_from_string('(?m)^  "%s": "(?:[^"\\\\]|\\\\.)*"' % entry[0])
		if line.search_all(result).size() != 1:
			result = ""
			break
		result = line.sub(result, '  "%s": %s' % [entry[0], JSON.stringify(entry[1]).replace("$", "$$")])
	var parsed: Dictionary = Patterns.from_json(result) if not result.is_empty() else {}
	if not parsed.is_empty() and str(parsed["id"]) == String(id) and str(parsed["name"]) == display_name:
		return result
	# Not LayoutPatterns' own layout (hand-edited): fall back to a normalised rewrite.
	var fallback: Dictionary = Patterns.from_json(content)
	fallback["schema"] = Patterns.SCHEMA_VERSION
	fallback["id"] = String(id)
	fallback["name"] = display_name
	return Patterns.to_json(fallback)


func _touched_paths(command: WeftluminCommand) -> PackedStringArray:
	var id := StringName(str(command.target.get("pattern", "")))
	var paths := PackedStringArray([path_for(id, SOURCE_USER)])
	match command.op:
		OP_RENAME:
			var to := StringName(str(command.params.get("to", "")))
			if not String(to).is_empty() and to != id:
				paths.append(path_for(to, SOURCE_USER))
		OP_PROMOTE:
			paths.append(path_for(id, SOURCE_REPO))
	return paths


func _directory(source: String) -> String:
	return repo_directory if source == SOURCE_REPO else user_directory


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false}
	return {"exists": true, "content": FileAccess.get_file_as_string(path)}


static func _remove(path: String) -> Error:
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _missing(id: StringName) -> Dictionary:
	return _blocked(&"pattern", &"existing_pattern", "No user pattern %s to change." % id)


static func _allowed() -> Dictionary:
	return {"allowed": true, "blocked_by": &"", "nearest_unblock": {}, "message": ""}


static func _blocked(by: StringName, unblock: StringName, message: String) -> Dictionary:
	return {"allowed": false, "blocked_by": by, "nearest_unblock": {"type": unblock}, "message": message}
