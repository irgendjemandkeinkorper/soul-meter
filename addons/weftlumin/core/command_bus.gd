class_name WeftluminCommandBus
extends RefCounted
## Every editor operation goes through here (`docs/architecture-in-game-editor.md` §4.4).
##
## The bus owns four things a caller must not: it captures `pre_state` from the live model
## itself, it decides what is replayable, it writes the JSONL log, and it drives undo/redo. A
## caller supplies intent; the bus supplies the record.
##
## **Two op classes.** *Document ops* mutate files or out-of-tree scene instances and are
## replayable — `replay()` re-executes them against a fresh instance, which is what the CLI and
## the replay-equivalence tests use. *Live-state verbs* act on running autoloads (the console
## vocabulary, `respawn now`, sandbox arm/disarm); they are logged with provenance for the
## session record but are deliberately excluded from replay, because re-running them against a
## fresh instance would mean something different from what they originally did.
##
## **Undo and redo are themselves logged.** The log is therefore not a list of what the owner
## asked for; it is a stream whose *effective* content — commands minus the ones undone — is
## what replay and bake apply. Recording only the forward commands would replay work the owner
## explicitly took back.

const CommandScript := preload("res://addons/weftlumin/core/command.gd")

const LOG_ROOT := "user://weftlumin"
const LOG_FILE_NAME := "commands.jsonl"
const RECORDER_EVENT := &"weftlumin_command"

## Refusals use the project's standard shape so a caller can present one without knowing which
## system refused: `{allowed, blocked_by, nearest_unblock, message}`.
const _NO_HANDLER := &"handler"
const _INVALID := &"schema"
const _REFUSED := &"handler_refusal"
const _DRIFT := &"pre_state_drift"
const _EMPTY := &"history"

var package: String = "":
	set(value):
		package = value
		_log_path = ""

## Set to a node exposing `append_event(type, payload)` — PlaytestRecorder in this game — to
## mirror commands into the session record. Optional: the bus works with no recorder attached.
var recorder: Object = null

## When false the bus keeps its in-memory log but writes no file. Tests and the headless CLI
## use this to stay out of `user://`.
var persist_log: bool = true

var _handlers: Dictionary = {}
var _history: UndoRedo = UndoRedo.new()
var _entries: Array[Dictionary] = []
var _undo_groups: Array[PackedStringArray] = []
var _redo_groups: Array[PackedStringArray] = []
var _merge_label: String = ""
var _merge_open: bool = false
var _log_path: String = ""


func _init(package_name: String = "default") -> void:
	package = package_name


## A document op: replayable, and reversible from its own captured `pre_state`.
## `capture` is `(WeftluminCommand) -> Dictionary`, `apply` and `revert` are
## `(WeftluminCommand) -> Dictionary` returning at least `{"allowed": bool}`.
func register_document_op(
	kind_name: String, op_name: String, capture: Callable, apply: Callable, revert: Callable
) -> void:
	_handlers[_handler_key(kind_name, op_name)] = {
		"capture": capture,
		"apply": apply,
		"revert": revert,
		"replayable": true,
	}


## A live-state verb: logged for the session record, never replayed, and not undoable — the
## running autoloads it touched have moved on by the time anyone would undo it.
func register_live_verb(kind_name: String, op_name: String, run: Callable) -> void:
	_handlers[_handler_key(kind_name, op_name)] = {
		"capture": Callable(),
		"apply": run,
		"revert": Callable(),
		"replayable": false,
	}


func has_handler(kind_name: String, op_name: String) -> bool:
	return _handlers.has(_handler_key(kind_name, op_name))


## Group the commands executed between here and `end_merge()` into one undo step. Used for
## drags, where thirty mouse-motion commands are one thing the owner did.
func begin_merge(label: String) -> void:
	_merge_label = label
	_merge_open = false


func end_merge() -> void:
	_merge_label = ""
	_merge_open = false


func execute(command: WeftluminCommand) -> Dictionary:
	var errors: PackedStringArray = command.validation_errors()
	if not errors.is_empty():
		return _blocked(_INVALID, &"valid_command", "; ".join(errors))
	var key: String = _handler_key(command.kind, command.op)
	if not _handlers.has(key):
		return _blocked(
			_NO_HANDLER, &"registered_handler", "No handler registered for %s." % key
		)
	var handler: Dictionary = _handlers[key]

	# Authoritative capture. Whatever the caller put in pre_state is discarded: drift detection
	# is only worth anything if the recorded state came from the live model.
	if handler["capture"] is Callable and (handler["capture"] as Callable).is_valid():
		command.pre_state = _dictionary((handler["capture"] as Callable).call(command))
	else:
		command.pre_state = {}

	var outcome: Dictionary = _dictionary((handler["apply"] as Callable).call(command))
	if not bool(outcome.get("allowed", true)):
		# A refused command never reaches the log. The log is a record of what happened, and
		# nothing happened.
		return _blocked(
			_REFUSED,
			StringName(str(outcome.get("nearest_unblock", "handler_accepts"))),
			str(outcome.get("message", "That operation was refused.")),
		)

	_append(command)
	if bool(handler["replayable"]):
		_push_history(command, handler)
	return _allowed({"command": command.to_dict()})


func undo() -> Dictionary:
	if _undo_groups.is_empty() or not _history.has_undo():
		return _blocked(_EMPTY, &"executed_command", "There is nothing to undo.")
	var group: PackedStringArray = _undo_groups.pop_back()
	_history.undo()
	_redo_groups.append(group)
	# Newest first, so replaying the bookkeeping in log order unwinds the group the same way.
	for index in range(group.size() - 1, -1, -1):
		_append(CommandScript.make_bookkeeping(CommandScript.OP_UNDO, group[index], package))
	return _allowed({"commands": group})


func redo() -> Dictionary:
	if _redo_groups.is_empty() or not _history.has_redo():
		return _blocked(_EMPTY, &"undone_command", "There is nothing to redo.")
	var group: PackedStringArray = _redo_groups.pop_back()
	_history.redo()
	_undo_groups.append(group)
	for command_id: String in group:
		_append(CommandScript.make_bookkeeping(CommandScript.OP_REDO, command_id, package))
	return _allowed({"commands": group})


func has_undo() -> bool:
	return not _undo_groups.is_empty()


func has_redo() -> bool:
	return not _redo_groups.is_empty()


## Every entry written so far, bookkeeping included, in order.
func log_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


## The commands still in effect: forward commands minus the ones undone, in original order.
## This — not the raw log — is what replay and bake apply.
static func effective_stream(entries: Array) -> Array[Dictionary]:
	var undone: Dictionary = {}
	for entry: Variant in entries:
		var data: Dictionary = entry as Dictionary if entry is Dictionary else {}
		var op: String = str(data.get("op", ""))
		if op != CommandScript.OP_UNDO and op != CommandScript.OP_REDO:
			continue
		var referenced: String = str(_dictionary(data.get("target", {})).get("command", ""))
		if referenced.is_empty():
			continue
		if op == CommandScript.OP_UNDO:
			undone[referenced] = true
		else:
			undone.erase(referenced)
	var stream: Array[Dictionary] = []
	for entry: Variant in entries:
		var data: Dictionary = entry as Dictionary if entry is Dictionary else {}
		var op: String = str(data.get("op", ""))
		if op == CommandScript.OP_UNDO or op == CommandScript.OP_REDO:
			continue
		if undone.has(str(data.get("id", ""))):
			continue
		stream.append(data.duplicate(true))
	return stream


## Re-execute a log's effective stream against whatever the registered handlers are currently
## bound to — for a document op that is a fresh out-of-tree instance, never the running scene.
##
## Each command's recorded `pre_state` is verified against a fresh capture first. A mismatch
## means the target changed under the log since it was recorded, and replaying on top of that
## would produce a scene the log does not describe, so replay refuses rather than guessing.
func replay(entries: Array) -> Dictionary:
	var applied: Array[String] = []
	var skipped: Array[String] = []
	for data: Dictionary in effective_stream(entries):
		var command: WeftluminCommand = CommandScript.from_dict(data)
		var key: String = _handler_key(command.kind, command.op)
		if not _handlers.has(key):
			return _blocked(
				_NO_HANDLER,
				&"registered_handler",
				"Replay stopped at %s: no handler for %s." % [command.id, key],
			)
		var handler: Dictionary = _handlers[key]
		if not bool(handler["replayable"]):
			# Live-state verbs are logged for the session record and excluded here by design.
			skipped.append(command.id)
			continue
		var fresh: Dictionary = _dictionary((handler["capture"] as Callable).call(command))
		if not _states_match(fresh, command.pre_state):
			return _blocked(
				_DRIFT,
				&"matching_pre_state",
				(
					"Replay stopped at %s (%s): recorded pre_state %s but found %s."
					% [command.id, key, command.pre_state, fresh]
				),
			)
		var outcome: Dictionary = _dictionary((handler["apply"] as Callable).call(command))
		if not bool(outcome.get("allowed", true)):
			return _blocked(
				_REFUSED,
				&"handler_accepts",
				"Replay stopped at %s: %s" % [command.id, str(outcome.get("message", ""))],
			)
		applied.append(command.id)
	return _allowed({"applied": applied, "skipped": skipped})


func log_path() -> String:
	if _log_path.is_empty():
		_log_path = "%s/%s/%s" % [LOG_ROOT, package, LOG_FILE_NAME]
	return _log_path


## Mirror an event the shell owns (`dev_console_command`, `combat_lab_battle_started`) into the
## recorder without the caller reaching past the bus into the recorder's API.
func emit_recorder_event(event_type: StringName, payload: Dictionary) -> void:
	if recorder == null or not is_instance_valid(recorder):
		return
	if not recorder.has_method("append_event"):
		return
	recorder.call("append_event", event_type, payload)


func _append(command: WeftluminCommand) -> void:
	var data: Dictionary = command.to_dict()
	_entries.append(data)
	_write_line(data)
	emit_recorder_event(RECORDER_EVENT, data)


func _push_history(command: WeftluminCommand, handler: Dictionary) -> void:
	var apply: Callable = handler["apply"]
	var revert: Callable = handler["revert"]
	var label: String = _merge_label if not _merge_label.is_empty() else "%s %s" % [
		command.kind, command.op
	]
	var merging: bool = not _merge_label.is_empty() and _merge_open
	_history.create_action(
		label, UndoRedo.MERGE_ENDS if merging else UndoRedo.MERGE_DISABLE
	)
	_history.add_do_method(func() -> void: apply.call(command))
	_history.add_undo_method(func() -> void: revert.call(command))
	# The action is registered without executing: apply already ran in execute(), and this is
	# where a double-apply would otherwise creep in.
	_history.commit_action(false)
	if merging:
		var group: PackedStringArray = _undo_groups[-1]
		group.append(command.id)
		_undo_groups[-1] = group
	else:
		_undo_groups.append(PackedStringArray([command.id]))
	if not _merge_label.is_empty():
		_merge_open = true
	# Any new command invalidates the redo branch, exactly as UndoRedo does internally.
	_redo_groups.clear()


func _write_line(data: Dictionary) -> void:
	if not persist_log:
		return
	var directory: String = log_path().get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		var error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if error != OK:
			push_warning("Weftlumin: cannot create %s (error %d)." % [directory, error])
			return
	var file: FileAccess = FileAccess.open(log_path(), FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(log_path(), FileAccess.WRITE)
	if file == null:
		push_warning("Weftlumin: cannot open %s for append." % log_path())
		return
	file.seek_end()
	file.store_line(JSON.stringify(data))
	file.close()


## Compared through a JSON round trip on purpose. A recorded `pre_state` has been through a text
## file, where every number came back a float; comparing a fresh capture to it any other way
## reports drift that is really just `0` versus `0.0`.
static func _states_match(fresh: Dictionary, recorded: Dictionary) -> bool:
	return JSON.stringify(_normalised(fresh)) == JSON.stringify(_normalised(recorded))


static func _normalised(value: Variant) -> Variant:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed != null else value


static func _handler_key(kind_name: String, op_name: String) -> String:
	return "%s/%s" % [kind_name, op_name]


static func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


static func _allowed(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"allowed": true, "blocked_by": &"", "nearest_unblock": &"", "message": ""
	}
	result.merge(extra, true)
	return result


static func _blocked(by: StringName, unblock: StringName, message: String) -> Dictionary:
	return {
		"allowed": false, "blocked_by": by, "nearest_unblock": unblock, "message": message
	}
