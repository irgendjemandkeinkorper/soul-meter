extends Node
## One live scene's scratch document and undo history, retained while F10 is closed.

signal changed

const Overrides := preload("res://globals/layout_overrides.gd")
const Recovery := preload("res://globals/layout_recovery.gd")
var document: Dictionary = {}
var saved_document: Dictionary = {}
var history := UndoRedo.new()
var panel_position := Vector2.INF
var recovery_error: Error = OK


func initialize(initial: Dictionary, working: Dictionary = {}) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	document = (working if not working.is_empty() else initial).duplicate(true)
	saved_document = initial.duplicate(true)


func _exit_tree() -> void:
	# UndoRedo owns references to detached additions/deletions, not live scene nodes.
	history.clear_history()


func capture(node: Node2D) -> Dictionary:
	if not is_instance_valid(node) or node.get_parent() == null:
		return {}
	var owners: Array = []
	_capture_owners(node, owners)
	return {"parent": node.get_parent(), "index": node.get_index(),
		"properties": Overrides.capture_properties(node), "owners": owners,
		"addition": node.get_meta("layout_addition") if node.has_meta("layout_addition") else null}


func _capture_owners(node: Node, output: Array) -> void:
	output.append([node, node.owner])
	for child: Node in node.get_children():
		_capture_owners(child, output)


func record(label: String, node: Node2D, before: Dictionary, previous_document: Dictionary) -> void:
	record_many(label, [{"node": node, "before": before}], previous_document)


## One undo step covering SEVERAL nodes — a multi-selection drag, delete or nudge, and a
## stamped pattern, which places a whole group at once.
##
## Recording per node instead would make one drag N undo steps, which the editor's contract
## forbids ("a drag is one undo step"), and would leave the live scene half-reverted: the
## document snapshot restores every edit, but only the nodes named here have their live
## transforms put back. `entries` is `[{node, before}]`, `before` from `capture()`.
func record_many(label: String, entries: Array, previous_document: Dictionary) -> void:
	if previous_document == document or entries.is_empty():
		return
	var before_states: Array = []
	var after_states: Array = []
	for entry: Dictionary in entries:
		var node: Node2D = entry["node"]
		before_states.append({"node": node, "state": entry.get("before", {})})
		after_states.append({"node": node, "state": capture(node)})
	history.create_action(label)
	history.add_do_method(_restore_many.bind(after_states, document.duplicate(true)))
	history.add_undo_method(_restore_many.bind(before_states, previous_document.duplicate(true)))
	# An empty BEFORE means this action created the node, so redo owns the reference; an empty
	# AFTER means it removed it, so undo does. Both can occur inside one multi-node action.
	for pair: Dictionary in before_states:
		if (pair["state"] as Dictionary).is_empty():
			history.add_do_reference(pair["node"])
	for pair: Dictionary in after_states:
		if (pair["state"] as Dictionary).is_empty():
			history.add_undo_reference(pair["node"])
	history.commit_action(false)
	_checkpoint()
	changed.emit()


func _restore_many(states: Array, snapshot: Dictionary) -> void:
	for pair: Dictionary in states:
		# Gameplay may retire an actor while F10 is closed. Its scratch edit still has an inverse.
		var node: Variant = pair["node"]
		if is_instance_valid(node):
			_restore_live(node, pair["state"])
	document.clear()
	document.merge(snapshot.duplicate(true))
	_checkpoint()
	changed.emit()


func _restore_live(node: Node2D, state: Dictionary) -> void:
	if not is_instance_valid(node):
		return
	var target_parent: Variant = state.get("parent")
	if node.get_parent() != target_parent:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		if is_instance_valid(target_parent):
			target_parent.add_child(node)
	if not state.is_empty() and is_instance_valid(target_parent):
		target_parent.move_child(node, mini(int(state["index"]), target_parent.get_child_count() - 1))
		for pair: Array in state["owners"]:
			if is_instance_valid(pair[0]) and is_instance_valid(pair[1]):
				pair[0].owner = pair[1]
		Overrides.apply_properties(node, state["properties"])
		if state["addition"] != null:
			node.set_meta("layout_addition", state["addition"].duplicate(true))


func is_dirty() -> bool:
	return document != saved_document


func mark_saved() -> void:
	saved_document = document.duplicate(true)
	_checkpoint()
	changed.emit()


func _checkpoint() -> void:
	recovery_error = Recovery.checkpoint(str(document.get("scene", "")), document, saved_document)
