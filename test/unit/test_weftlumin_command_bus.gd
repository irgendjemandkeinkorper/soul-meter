extends GdUnitTestSuite
## E2.2 (#333): the command bus contract from architecture §4.4.
##
## The bus is driven against a small stand-in document model rather than a mocked handler, so
## the interesting properties are actually exercised: pre_state really is read from a live
## object, replay really does rebuild a second document from a log, and drift really is a
## disagreement between a recording and a world that moved.

const CommandScript := preload("res://addons/weftlumin/core/command.gd")
const BusScript := preload("res://addons/weftlumin/core/command_bus.gd")


## Stands in for a scene or package document: a bag of properties the bus can read and write.
class Document extends RefCounted:
	var values: Dictionary = {}

	func get_value(key: String) -> Variant:
		return values.get(key, null)

	func set_value(key: String, value: Variant) -> void:
		values[key] = value


var _document: Document
var _bus: WeftluminCommandBus


func before_test() -> void:
	_document = Document.new()
	_bus = _bus_for(_document)


## A bus wired to `document` with one document op (`scene/set_property`) and one live verb.
func _bus_for(document: Document) -> WeftluminCommandBus:
	var bus := BusScript.new("test-package")
	# Never touch user:// from a test suite.
	bus.persist_log = false
	bus.register_document_op(
		"scene",
		"set_property",
		func(command: WeftluminCommand) -> Dictionary:
			return {"value": document.get_value(str(command.params.get("key", "")))},
		func(command: WeftluminCommand) -> Dictionary:
			document.set_value(
				str(command.params.get("key", "")), command.params.get("value", null)
			)
			return {"allowed": true},
		func(command: WeftluminCommand) -> Dictionary:
			document.set_value(
				str(command.params.get("key", "")), command.pre_state.get("value", null)
			)
			return {"allowed": true},
	)
	bus.register_live_verb(
		"console",
		"run",
		func(_command: WeftluminCommand) -> Dictionary: return {"allowed": true},
	)
	return bus


func _set_property(key: String, value: Variant) -> WeftluminCommand:
	return CommandScript.make(
		"scene",
		"set_property",
		{"scene": "res://world/starting_town.tscn", "node": "Actors/BellHouseDoor"},
		{"key": key, "value": value},
		"test-package",
	)


func test_execute_captures_pre_state_itself_and_ignores_what_the_caller_supplied() -> void:
	_document.set_value("locked_message", "This door is locked.")
	var command := _set_property("locked_message", "The bell-house is shut at night.")
	# A caller inventing a pre_state is the whole reason the bus captures its own: a log that
	# trusted this would report drift where there is none, and miss drift where there is.
	command.pre_state = {"value": "something the caller made up"}

	var result: Dictionary = _bus.execute(command)
	assert_bool(result["allowed"]).is_true()
	assert_str(str(command.pre_state["value"])).override_failure_message(
		"the bus must capture pre_state from the live model, not accept the caller's"
	).is_equal("This door is locked.")
	assert_str(str(_document.get_value("locked_message"))).is_equal(
		"The bell-house is shut at night."
	)


func test_an_unknown_op_is_refused_and_never_reaches_the_log() -> void:
	var command := CommandScript.make("scene", "detonate", {}, {}, "test-package")
	var result: Dictionary = _bus.execute(command)
	assert_bool(result["allowed"]).is_false()
	assert_str(str(result["blocked_by"])).is_equal("handler")
	assert_array(_bus.log_entries()).override_failure_message(
		"the log records what happened; a refused command did not happen"
	).is_empty()


func test_a_handler_refusal_is_not_logged_either() -> void:
	var bus := BusScript.new("test-package")
	bus.persist_log = false
	bus.register_document_op(
		"scene",
		"set_property",
		func(_c: WeftluminCommand) -> Dictionary: return {},
		func(_c: WeftluminCommand) -> Dictionary:
			return {"allowed": false, "message": "That node is not editable."},
		func(_c: WeftluminCommand) -> Dictionary: return {"allowed": true},
	)
	var result: Dictionary = bus.execute(_set_property("k", "v"))
	assert_bool(result["allowed"]).is_false()
	assert_str(str(result["message"])).contains("not editable")
	assert_array(bus.log_entries()).is_empty()
	assert_bool(bus.has_undo()).is_false()


func test_undo_and_redo_restore_the_value_and_are_themselves_logged() -> void:
	_document.set_value("locked_message", "This door is locked.")
	var command := _set_property("locked_message", "The bell-house is shut at night.")
	assert_bool(_bus.execute(command)["allowed"]).is_true()

	assert_bool(_bus.undo()["allowed"]).is_true()
	assert_str(str(_document.get_value("locked_message"))).is_equal("This door is locked.")
	assert_bool(_bus.redo()["allowed"]).is_true()
	assert_str(str(_document.get_value("locked_message"))).is_equal(
		"The bell-house is shut at night."
	)

	var ops: Array[String] = []
	for entry: Dictionary in _bus.log_entries():
		ops.append(str(entry["op"]))
	assert_array(ops).override_failure_message(
		"undo and redo must appear in the log, or replay cannot know what is still in effect"
	).is_equal(["set_property", "undo", "redo"])


func test_an_undone_command_leaves_the_effective_stream_and_a_redone_one_returns() -> void:
	assert_bool(_bus.execute(_set_property("a", 1))["allowed"]).is_true()
	assert_bool(_bus.execute(_set_property("b", 2))["allowed"]).is_true()
	_bus.undo()
	var after_undo: Array = BusScript.effective_stream(_bus.log_entries())
	assert_int(after_undo.size()).override_failure_message(
		"an undone command must drop out of the effective stream"
	).is_equal(1)
	assert_str(str((after_undo[0]["params"] as Dictionary)["key"])).is_equal("a")

	_bus.redo()
	assert_int(BusScript.effective_stream(_bus.log_entries()).size()).is_equal(2)


func test_replay_rebuilds_a_second_document_from_the_log() -> void:
	_document.set_value("locked_message", "This door is locked.")
	_bus.execute(_set_property("locked_message", "The bell-house is shut at night."))
	_bus.execute(_set_property("bell_rings", true))

	# A fresh document in the same starting state, which is what the CLI replays into.
	var replica := Document.new()
	replica.set_value("locked_message", "This door is locked.")
	var replica_bus: WeftluminCommandBus = _bus_for(replica)
	var result: Dictionary = replica_bus.replay(_bus.log_entries())

	assert_bool(result["allowed"]).override_failure_message(
		"%s" % str(result["message"])
	).is_true()
	assert_int((result["applied"] as Array).size()).is_equal(2)
	assert_str(str(replica.get_value("locked_message"))).is_equal(
		"The bell-house is shut at night."
	)
	assert_bool(bool(replica.get_value("bell_rings"))).is_true()


func test_replay_skips_a_command_the_owner_undid() -> void:
	_bus.execute(_set_property("keep", "yes"))
	_bus.execute(_set_property("discard", "no"))
	_bus.undo()

	var replica := Document.new()
	var replica_bus: WeftluminCommandBus = _bus_for(replica)
	assert_bool(replica_bus.replay(_bus.log_entries())["allowed"]).is_true()
	assert_str(str(replica.get_value("keep"))).is_equal("yes")
	assert_object(replica.get_value("discard")).override_failure_message(
		"replaying work the owner explicitly took back is the bug the effective stream prevents"
	).is_null()


func test_replay_refuses_when_the_target_drifted_under_the_log() -> void:
	_document.set_value("locked_message", "This door is locked.")
	_bus.execute(_set_property("locked_message", "The bell-house is shut at night."))

	# The replica starts somewhere the log does not describe.
	var replica := Document.new()
	replica.set_value("locked_message", "Someone else already changed this.")
	var replica_bus: WeftluminCommandBus = _bus_for(replica)
	var result: Dictionary = replica_bus.replay(_bus.log_entries())

	assert_bool(result["allowed"]).override_failure_message(
		"a pre_state mismatch means the world moved; replaying on top of it would produce a "
		+ "scene the log does not describe"
	).is_false()
	assert_str(str(result["blocked_by"])).is_equal("pre_state_drift")
	assert_str(str(result["message"])).contains("Someone else already changed this")
	assert_str(str(replica.get_value("locked_message"))).override_failure_message(
		"a refused replay must not half-apply"
	).is_equal("Someone else already changed this.")


func test_a_pre_state_that_only_survived_json_as_a_float_is_not_drift() -> void:
	# The recorded pre_state has been through a text file, where every number came back a
	# float. Comparing a fresh int capture to it naively reports drift that is really 0 vs 0.0.
	_document.set_value("elevation", 0)
	_bus.execute(_set_property("elevation", 3))
	var round_tripped: Array = JSON.parse_string(JSON.stringify(_bus.log_entries()))

	var replica := Document.new()
	replica.set_value("elevation", 0)
	var replica_bus: WeftluminCommandBus = _bus_for(replica)
	var result: Dictionary = replica_bus.replay(round_tripped)
	assert_bool(result["allowed"]).override_failure_message(
		"%s" % str(result["message"])
	).is_true()


func test_live_verbs_are_logged_but_excluded_from_replay_and_from_undo() -> void:
	var verb := CommandScript.make("console", "run", {}, {"command": "give soul 10"}, "test-package")
	assert_bool(_bus.execute(verb)["allowed"]).is_true()
	assert_int(_bus.log_entries().size()).override_failure_message(
		"a live verb belongs in the session record"
	).is_equal(1)
	assert_bool(_bus.has_undo()).override_failure_message(
		"the autoloads a live verb touched have moved on; it is not undoable"
	).is_false()

	var replica_bus: WeftluminCommandBus = _bus_for(Document.new())
	var result: Dictionary = replica_bus.replay(_bus.log_entries())
	assert_bool(result["allowed"]).is_true()
	assert_int((result["applied"] as Array).size()).is_equal(0)
	assert_array(result["skipped"]).override_failure_message(
		"live verbs are excluded from replay by design, not by accident"
	).is_not_empty()


func test_a_merged_drag_undoes_as_one_step() -> void:
	_document.set_value("x", 0)
	_bus.begin_merge("Move prop")
	for step in range(1, 31):
		_bus.execute(_set_property("x", step))
	_bus.end_merge()
	assert_int(int(_document.get_value("x"))).is_equal(30)

	assert_bool(_bus.undo()["allowed"]).is_true()
	assert_int(int(_document.get_value("x"))).override_failure_message(
		"thirty mouse-motion commands are one thing the owner did; one undo must take it back"
	).is_equal(0)
	assert_bool(_bus.has_undo()).is_false()


func test_a_new_command_discards_the_redo_branch() -> void:
	_bus.execute(_set_property("a", 1))
	_bus.undo()
	assert_bool(_bus.has_redo()).is_true()
	_bus.execute(_set_property("b", 2))
	assert_bool(_bus.has_redo()).override_failure_message(
		"executing after an undo must abandon the redo branch, as UndoRedo does internally"
	).is_false()


func test_commands_carry_the_ratified_schema_and_sort_in_creation_order() -> void:
	_bus.execute(_set_property("a", 1))
	var entry: Dictionary = _bus.log_entries()[0]
	assert_str(str(entry["schema"])).is_equal("weftlumin.command.v1")
	for key: String in ["id", "ts", "package", "kind", "op", "target", "params", "pre_state", "provenance"]:
		assert_bool(entry.has(key)).override_failure_message(
			"weftlumin.command.v1 requires the key %s" % key
		).is_true()

	var ids: Array[String] = []
	for _index in 8:
		ids.append(CommandScript.new_id())
	var sorted: Array[String] = ids.duplicate()
	sorted.sort()
	assert_array(ids).override_failure_message(
		"ids must sort lexically in creation order so a commands.jsonl reads in order"
	).is_equal(sorted)


func test_undo_on_an_empty_history_refuses_in_the_standard_shape() -> void:
	var result: Dictionary = _bus.undo()
	assert_bool(result["allowed"]).is_false()
	for key: String in ["blocked_by", "nearest_unblock", "message"]:
		assert_bool(result.has(key)).is_true()
	assert_bool(_bus.redo()["allowed"]).is_false()


func test_the_recorder_sees_every_logged_command() -> void:
	var recorder := RecordingSpy.new()
	auto_free(recorder)
	_bus.recorder = recorder
	_bus.execute(_set_property("a", 1))
	_bus.undo()
	assert_int(recorder.events.size()).override_failure_message(
		"the command and its undo entry both belong in the session record"
	).is_equal(2)
	assert_str(str(recorder.events[0]["type"])).is_equal("weftlumin_command")


class RecordingSpy extends Node:
	var events: Array[Dictionary] = []

	func append_event(event_type: StringName, payload: Dictionary) -> bool:
		events.append({"type": String(event_type), "payload": payload})
		return true
