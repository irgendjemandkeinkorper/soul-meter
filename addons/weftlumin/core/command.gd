class_name WeftluminCommand
extends RefCounted
## One editor operation in the ratified `weftlumin.command.v1` shape
## (`docs/architecture-in-game-editor.md` §4.4).
##
## A command is data, not behaviour. The bus owns validation, `pre_state` capture, application
## and logging; a command knows only how to describe itself. That split is what lets `replay()`
## rebuild a session out of a JSONL file long after the objects the original commands ran
## against are gone — a command that carried its own apply logic could not survive the trip
## through a text file.

const SCHEMA := "weftlumin.command.v1"

## Bookkeeping ops the bus writes to record an undo or a redo. They are entries in the log's
## grammar but have no kind of their own: replay reads them to work out which commands are
## still in effect, and never executes them.
const OP_UNDO := "undo"
const OP_REDO := "redo"

## Sortable, ULID-shaped id: a millisecond timestamp, then a sequence, then randomness, all in
## Crockford base32. Lexical order is creation order, so a commands.jsonl stays readable and
## diffable by hand.
##
## The sequence is what makes that true. A burst of commands — a drag emits dozens — lands
## inside a single millisecond, where the timestamp prefix is identical and random suffixes
## would order them arbitrarily. The counter breaks those ties in creation order and resets
## whenever the clock moves on.
const _CROCKFORD := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const _TIME_CHARS := 10
const _SEQUENCE_CHARS := 6
const _RANDOM_CHARS := 10

static var _last_timestamp_ms: int = -1
static var _sequence: int = 0

var id: String = ""
var ts: String = ""
var package: String = ""
var kind: String = ""
var op: String = ""
var target: Dictionary = {}
var params: Dictionary = {}
## Captured authoritatively by the bus at execute time. A value supplied by a caller is
## overwritten, because drift detection is only worth anything if the recorded state came from
## the live model rather than from whoever built the command.
var pre_state: Dictionary = {}
var provenance: Dictionary = {}


static func make(
	kind_name: String,
	op_name: String,
	target_ref: Dictionary = {},
	command_params: Dictionary = {},
	package_name: String = "",
	command_provenance: Dictionary = {}
) -> WeftluminCommand:
	var command := WeftluminCommand.new()
	command.id = new_id()
	command.ts = Time.get_datetime_string_from_system(true, true) + "Z"
	command.package = package_name
	command.kind = kind_name
	command.op = op_name
	command.target = target_ref.duplicate(true)
	command.params = command_params.duplicate(true)
	command.provenance = (
		command_provenance.duplicate(true)
		if not command_provenance.is_empty()
		else {"source": "ui", "actor": "owner"}
	)
	return command


## A bookkeeping entry recording that `command_id` was undone or redone.
static func make_bookkeeping(
	op_name: String, command_id: String, package_name: String = ""
) -> WeftluminCommand:
	var command := make(
		"", op_name, {"command": command_id}, {}, package_name, {"source": "bus", "actor": "owner"}
	)
	return command


static func from_dict(data: Dictionary) -> WeftluminCommand:
	var command := WeftluminCommand.new()
	command.id = str(data.get("id", ""))
	command.ts = str(data.get("ts", ""))
	command.package = str(data.get("package", ""))
	command.kind = str(data.get("kind", ""))
	command.op = str(data.get("op", ""))
	command.target = _dictionary(data.get("target", {}))
	command.params = _dictionary(data.get("params", {}))
	command.pre_state = _dictionary(data.get("pre_state", {}))
	command.provenance = _dictionary(data.get("provenance", {}))
	return command


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA,
		"id": id,
		"ts": ts,
		"package": package,
		"kind": kind,
		"op": op,
		"target": target.duplicate(true),
		"params": params.duplicate(true),
		"pre_state": pre_state.duplicate(true),
		"provenance": provenance.duplicate(true),
	}


## Undo/redo entries, which record an effect rather than requesting one.
func is_bookkeeping() -> bool:
	return op == OP_UNDO or op == OP_REDO


## The command id an undo/redo entry refers to.
func referenced_command_id() -> String:
	return str(target.get("command", ""))


## Empty when the command is well formed. Reported rather than thrown so the bus can refuse
## with a message naming every problem at once.
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("id is required")
	if op.is_empty():
		errors.append("op is required")
	if is_bookkeeping():
		if referenced_command_id().is_empty():
			errors.append("%s entries must name target.command" % op)
		return errors
	if kind.is_empty():
		errors.append("kind is required")
	return errors


static func new_id() -> String:
	# Multiply before truncating: `get_unix_time_from_system() as int * 1000` would round to a
	# whole second first and throw the millisecond away.
	var timestamp_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	if timestamp_ms == _last_timestamp_ms:
		_sequence += 1
	else:
		_last_timestamp_ms = timestamp_ms
		_sequence = 0
	return (
		_base32(timestamp_ms, _TIME_CHARS)
		+ _base32(_sequence, _SEQUENCE_CHARS)
		+ _random_base32(_RANDOM_CHARS)
	)


static func _base32(value: int, width: int) -> String:
	var encoded := ""
	var remaining: int = maxi(value, 0)
	for _index in width:
		encoded = _CROCKFORD[remaining % 32] + encoded
		remaining /= 32
	return encoded


static func _random_base32(width: int) -> String:
	var encoded := ""
	for _index in width:
		encoded += _CROCKFORD[randi() % 32]
	return encoded


static func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
