class_name WeftluminSceneModel
extends RefCounted
## The live gameplay scene, wrapped for editing (`docs/architecture-in-game-editor.md` §4.6.1).
##
## The model owns four things: which nodes are editable (the host's sub-tool predicate — the
## layout tool's rules by default — widened to every `Node2D` under the adapter's editable
## roots), the **scene-ownership boundary** of each node, the selection set, and the mapping from
## a gesture on nodes to `scene` commands on the bus. It never decides the editable-roots list:
## that is the adapter's (`WeftluminGameAdapter.editable_roots`), reached through
## `editable_roots_provider`.
##
## **Ownership boundaries.** A node owned by the edited scene accepts every op. A node inside an
## instanced sub-scene accepts only property overrides, and only while that instance has editable
## children. Adds go only under scene-owned nodes or editable instances; removes only of
## scene-owned nodes. A node with no owner chain to the scene root (spawned at runtime) accepts
## nothing, because no scene file could carry the edit.
##
## **Live apply.** Every command lands on the live scene the way `LayoutOverrides.apply_to_scene`
## lands a scratch document — the model builds the one-entry document and hands it to
## `apply_to_scene`, which stays the replay primitive. The model also keeps the accumulated
## layout document, so `apply_to_scene(fresh_instance, document)` reproduces the live scene.
## Removals detach rather than free (the one departure), so undo can put the same node back.
##
## **Gestures.** One owner action — a group drag, a nudge, a delete, a duplicate — is one undo
## step however many nodes it touches. The bus merges a gesture's commands into one `UndoRedo`
## action, which keeps only the first command's undo and the last command's do; the model
## therefore binds every command of a gesture to the whole gesture, and either end restores or
## reapplies all of it.

signal selection_changed
signal scene_changed

const KIND := "scene"
const OP_SET := "set_property"
const OP_ADD := "add_node"
const OP_REMOVE := "remove_node"
const SNAP_GRID := 8.0
## Selection forgiveness for markers and small props.
const PICK_PADDING := 8.0
## Offset a duplicate lands at, one snap step down-right of its source.
const DUPLICATE_OFFSET := Vector2(SNAP_GRID, SNAP_GRID)
## `LayoutOverrides.apply_to_scene` tags its additions with this, which is how they re-select.
const ADDITION_META := &"layout_addition"
const SESSION_META := &"weftlumin_scene_session"
const SESSION_NODE := "_WeftluminSceneSession"
const Recovery := preload("res://globals/layout_recovery.gd")
const Patterns := preload("res://globals/layout_patterns.gd")
const DEFAULT_COLLISION_SIZE := Vector2(64, 24)
const MAX_FOOTPRINT := Vector2(120, 48)
const PALETTE_RESULT_LIMIT := 240
const PALETTE_CATEGORIES := [
	{"label": "Town (fantasy kit)", "roots": ["res://assets/generated/sprites/fantasy-town-kit/"]},
	{"label": "Castle", "roots": ["res://assets/generated/sprites/castle-kit/"]},
	{"label": "Nature", "roots": ["res://assets/generated/sprites/nature-kit/"]},
	{"label": "Terrain & ground", "roots": ["res://assets/generated/sprites/terrain/", "res://assets/generated/sprites/ground/"]},
	{"label": "World objects", "roots": ["res://assets/generated/sprites/world/objects/"]},
	{"label": "World locations", "roots": ["res://assets/generated/sprites/world/"]},
	{"label": "Units & NPCs", "roots": ["res://assets/generated/sprites/units/"]},
	{"label": "Mini characters", "roots": ["res://assets/generated/sprites/mini-characters/"]},
	{"label": "Items", "roots": ["res://assets/generated/sprites/items/"]},
]

## The live scene owns its session without production signal connections to an unhosted
## tool. This unowned, dormant node also releases detached undo targets when the scene exits.
class SessionLifetime extends Node:
	var model: WeftluminSceneModel

	func _exit_tree() -> void:
		if model == null:
			return
		model._checkpoint_on_scene_exit()
		get_parent().remove_meta(SESSION_META)
		model.dispose()
		model = null

enum Snap { OFF, GRID, CELL }
enum Boundary { OUTSIDE, SCENE, INSTANCE, RUNTIME }

var scene_root: Node = null
var bus: WeftluminCommandBus = null
## The layout scratch document the live edits amount to (`LayoutOverrides` schema 1).
var document: Dictionary = {}
var snap_mode: Snap = Snap.GRID
## Cell space for `Snap.CELL`. Without one, cell snap falls back to the 8 px grid.
var grid: IsoGrid = null
## `(scene_root: Node) -> Array[Node]`: the adapter's editable roots. Every `Node2D` strictly
## below one is editable. Unset or empty means only the host predicate applies.
var editable_roots_provider: Callable = Callable()
## `(node: Node) -> bool`: the active sub-tool's predicate. Defaults to the layout tool's.
var host_predicate: Callable = Callable()
var texture_path := ""
var pattern: Dictionary = {}
var placement_layer: StringName = &"GroundDetails"
var footprint := DEFAULT_COLLISION_SIZE
var saved_document: Dictionary = {}
var recovery_error: Error = OK
var _persistent := false

var _selection: Array[Node2D] = []
var _primary: Node2D = null
## `editable path=` entries of the edited scene file. A runtime-instantiated scene does not
## carry Godot's editable-instance flags, so the file is the authority.
var _editable_paths: Dictionary = {}
## Command id -> its gesture record. Every command of a gesture maps to the same record.
var _gestures: Dictionary = {}
var _gesture: Dictionary = {}
var _drag: Dictionary = {}


func _init() -> void:
	host_predicate = func(node: Node) -> bool: return LayoutOverrides.is_layout_editable(node)


## Wrap `root`. A private in-memory bus is made when none is supplied.
func configure(root: Node, command_bus: WeftluminCommandBus = null) -> void:
	dispose()
	scene_root = root
	document = LayoutOverrides.create_document(scene_path())
	saved_document = document.duplicate(true)
	_persistent = false
	_selection.clear()
	_primary = null
	_drag.clear()
	_editable_paths = _read_editable_paths(root)
	if command_bus == null:
		command_bus = WeftluminCommandBus.new(KIND)
		command_bus.persist_log = false
	bus = command_bus
	register_ops(bus)
	selection_changed.emit()


## The live scene owns history across shell close/reopen; only a hosted scene opts into disk
## recovery. Plain model instances (including command/replay tests) remain memory-only.
static func session_for(root: Node) -> WeftluminSceneModel:
	if root.has_meta(SESSION_META):
		return root.get_meta(SESSION_META) as WeftluminSceneModel
	var session := WeftluminSceneModel.new()
	session.configure(root)
	session._persistent = true
	var restored: Dictionary = Recovery.load_scene(session.scene_path())
	session.document = restored["working"]
	session.saved_document = restored["saved"]
	LayoutOverrides.apply_to_scene(root, session.document)
	root.set_meta(SESSION_META, session)
	var lifetime := root.get_node_or_null(NodePath(SESSION_NODE)) as SessionLifetime
	if lifetime == null:
		lifetime = SessionLifetime.new()
		lifetime.name = SESSION_NODE
		lifetime.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(lifetime)
	lifetime.model = session
	return session


func is_dirty() -> bool:
	return LayoutOverrides.to_json(document) != LayoutOverrides.to_json(saved_document)


func save() -> Dictionary:
	finish_pointer()
	var error: Error = LayoutOverrides.save_file(LayoutOverrides.override_path_for_scene(scene_path()), document)
	if error != OK:
		return _blocked(&"save", &"writable_scratch", "Save failed: %s." % error_string(error))
	saved_document = document.duplicate(true)
	_checkpoint()
	scene_changed.emit()
	return _allowed()


func _checkpoint() -> void:
	if _persistent:
		recovery_error = Recovery.checkpoint(scene_path(), document, saved_document)


func _checkpoint_on_scene_exit() -> void:
	# Godot clears Node.owner before the dying scene emits tree_exiting. The preview was
	# already authorised at begin_drag; capture it for recovery before disposing its history.
	# Do not weaken ownership checks or send new edits to a scene that is being destroyed.
	for node: Variant in _drag.get("starts", {}):
		if is_instance_valid(node) and scene_root.is_ancestor_of(node):
			_record(node as Node2D)
	_drag.clear()
	_checkpoint()


## Free nodes this model detached (removed, or added then undone) that nothing re-attached.
## The owner calls this when it is done with the model (a hosted scene does on exit); a
## RefCounted cannot run script from its own predelete.
func dispose() -> void:
	cancel_drag()
	for record: Variant in _unique_gestures():
		for step: Dictionary in (record as Dictionary)["steps"]:
			var node: Variant = step.get("node")
			if is_instance_valid(node) and (node as Node).get_parent() == null:
				(node as Node).free()
	_gestures.clear()
	_gesture = {}
	# The bus owns bound model callbacks, so release our side of that reference cycle.
	bus = null
	_selection.clear()
	_primary = null


func scene_path() -> String:
	return scene_root.scene_file_path if is_instance_valid(scene_root) else ""


func register_ops(command_bus: WeftluminCommandBus) -> void:
	for op: String in [OP_SET, OP_ADD, OP_REMOVE]:
		command_bus.register_document_op(KIND, op, _capture, _apply, _revert)


# --- ownership --------------------------------------------------------------------------------


## `{kind: Boundary, instance_root: Node, editable_instance: bool}` for `node`.
func boundary(node: Node) -> Dictionary:
	var result := {"kind": Boundary.OUTSIDE, "instance_root": null, "editable_instance": false}
	if scene_root == null or not is_instance_valid(node):
		return result
	if node != scene_root and not scene_root.is_ancestor_of(node):
		return result
	if node == scene_root or node.owner == scene_root or _is_scratch(node):
		result["kind"] = Boundary.SCENE
		return result
	if node.owner == null:
		result["kind"] = Boundary.RUNTIME
		return result
	# Walk the instance roots outward: the node's owner is the innermost sub-scene root, whose
	# owner is the next one out, until the edited scene. Every level must be editable.
	var editable := true
	var instance: Node = node.owner
	var outermost: Node = instance
	while instance != null and instance != scene_root:
		editable = editable and _is_editable_instance(instance)
		outermost = instance
		instance = instance.owner
	if instance == null:
		result["kind"] = Boundary.RUNTIME
		return result
	result["kind"] = Boundary.INSTANCE
	result["instance_root"] = outermost
	result["editable_instance"] = editable
	return result


## Whether `op` may act on `node` (for `add_node`, `node` is the parent). Refusal shape.
func check(op: String, node: Node) -> Dictionary:
	var info: Dictionary = boundary(node)
	var kind: int = int(info["kind"])
	var label: String = String(node.name) if is_instance_valid(node) else "That node"
	if kind == Boundary.OUTSIDE:
		return _blocked(&"scene_boundary", &"node_in_scene", "%s is not in the edited scene." % label)
	if kind == Boundary.RUNTIME:
		return _blocked(
			&"scene_ownership", &"scene_owned_node",
			"%s was spawned at runtime; no scene file carries it." % label,
		)
	var instance_name: String = (
		String((info["instance_root"] as Node).name) if info["instance_root"] != null else ""
	)
	match op:
		OP_SET, OP_ADD:
			if kind == Boundary.INSTANCE and not bool(info["editable_instance"]):
				return _blocked(
					&"instance_boundary", &"editable_children",
					"%s is inside instanced sub-scene %s; enable its editable children first."
					% [label, instance_name],
				)
		OP_REMOVE:
			if node == scene_root:
				return _blocked(&"scene_boundary", &"child_node", "The scene root cannot be removed.")
			if kind == Boundary.INSTANCE:
				return _blocked(
					&"instance_boundary", &"scene_owned_node",
					"%s belongs to instanced sub-scene %s; only property overrides apply inside it."
					% [label, instance_name],
				)
		_:
			return _blocked(&"handler", &"scene_op", "Unknown scene op %s." % op)
	return _allowed()


## The host predicate or an adapter editable root, and a boundary that accepts overrides.
func is_editable(node: Node) -> bool:
	return _is_editable_under(node, _roots())


func _is_editable_under(node: Node, roots: Array[Node]) -> bool:
	if not node is Node2D or node == scene_root or not bool(check(OP_SET, node)["allowed"]):
		return false
	if host_predicate.is_valid() and bool(host_predicate.call(node)):
		return true
	for root: Node in roots:
		if is_instance_valid(root) and root != node and root.is_ancestor_of(node):
			return true
	return false


func editable_nodes() -> Array[Node2D]:
	var output: Array[Node2D] = []
	if scene_root != null:
		_collect_editable(scene_root, _roots(), output)
	return output


# --- pick and bounds --------------------------------------------------------------------------


## Smallest hit wins, so a prop inside a big backdrop stays reachable; on an area tie the LAST
## candidate wins — the one drawn on top. A strict `<` would pick the prop behind.
func pick(world_position: Vector2) -> Node2D:
	var picked: Node2D = null
	var picked_area := INF
	for candidate: Node2D in editable_nodes():
		var hit: Rect2 = bounds(candidate).grow(PICK_PADDING)
		if not hit.has_point(world_position):
			continue
		var area: float = hit.size.x * hit.size.y
		if area <= picked_area:
			picked = candidate
			picked_area = area
	return picked


func bounds(node: Node2D) -> Rect2:
	if node is Sprite2D:
		return _sprite_world_bounds(node as Sprite2D)
	var sprite: Sprite2D = _first_sprite(node)
	if sprite != null:
		return _sprite_world_bounds(sprite)
	return Rect2(node.global_position - Vector2(12.0, 12.0), Vector2(24.0, 24.0))


# --- snapping ---------------------------------------------------------------------------------


func snap(world_position: Vector2, mode: Snap = snap_mode) -> Vector2:
	match mode:
		Snap.OFF:
			return world_position
		Snap.CELL:
			if grid != null:
				return grid.cell_to_world(grid.world_to_cell(world_position))
	return Vector2(
		roundf(world_position.x / SNAP_GRID) * SNAP_GRID,
		roundf(world_position.y / SNAP_GRID) * SNAP_GRID,
	)


# --- selection --------------------------------------------------------------------------------


## Live members, oldest first. The primary is the most recent addition.
func selection() -> Array[Node2D]:
	_prune_selection()
	return _selection.duplicate()


func primary() -> Node2D:
	_prune_selection()
	return _primary


func is_selected(node: Node2D) -> bool:
	return _selection.has(node)


## Replace the selection with `node` (null clears). Refuses a node that is not editable.
func select_only(node: Node2D) -> bool:
	if node != null and not is_editable(node):
		return false
	_selection.clear()
	if node != null:
		_selection.append(node)
	_primary = node
	selection_changed.emit()
	return true


## Shift+click: an unselected node joins and becomes primary; a member leaves, and the primary
## falls back to the most recent remaining member.
func toggle(node: Node2D) -> bool:
	if node == null:
		return false
	var index := _selection.find(node)
	if index >= 0:
		_selection.remove_at(index)
		_primary = _selection.back() if not _selection.is_empty() else null
	else:
		if not is_editable(node):
			return false
		_selection.append(node)
		_primary = node
	selection_changed.emit()
	return true


## Whole-set replacement (the scene panel's tree). Non-editable entries are dropped.
func set_selection(nodes: Array[Node2D], new_primary: Node2D = null) -> void:
	_selection.clear()
	for node: Node2D in nodes:
		if is_editable(node) and not _selection.has(node):
			_selection.append(node)
	_primary = new_primary if _selection.has(new_primary) else (
		_selection.back() if not _selection.is_empty() else null
	)
	selection_changed.emit()


func clear_selection() -> void:
	select_only(null)


## A click at `world_position`: additive toggles the picked node; a plain click on a member keeps
## the group and makes it primary (so a drag moves all of it); otherwise the pick replaces it.
func pick_select(world_position: Vector2, additive: bool = false) -> Node2D:
	var picked: Node2D = pick(world_position)
	if additive:
		toggle(picked)
	elif picked == null:
		select_only(null)
	elif not _selection.has(picked):
		select_only(picked)
	else:
		_primary = picked
		selection_changed.emit()
	return picked


## Coordinates are supplied by the shell, after its GUI/canvas conversion. Modifier clicks
## only change membership; a plain press on an existing member grabs the entire group.
func pointer_input(event: InputEvent, world_position: Vector2) -> Dictionary:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			cancel_placement()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			finish_pointer()
			if not button.pressed:
				return _allowed()
			if not pattern.is_empty() or not texture_path.is_empty():
				var outcome: Dictionary = stamp_pattern(world_position, button.alt_pressed) if not pattern.is_empty() else place_prop(world_position, button.alt_pressed)
				if bool(outcome["allowed"]) and not button.shift_pressed:
					cancel_placement()
				return outcome
			var additive: bool = button.ctrl_pressed or button.shift_pressed
			var picked: Node2D = pick_select(world_position, additive)
			if picked != null and not additive:
				begin_drag(world_position)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if not motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			finish_pointer()
		else:
			drag_to(world_position, motion.alt_pressed or motion.shift_pressed)
	return _allowed()


func finish_pointer() -> void:
	if not _drag.is_empty():
		end_drag()


func cancel_placement() -> void:
	texture_path = ""
	pattern = {}


func choose_texture(path: String) -> void:
	finish_pointer()
	texture_path = path
	pattern = {}
	clear_selection()


func choose_pattern(value: Dictionary) -> void:
	finish_pointer()
	pattern = value.duplicate(true)
	texture_path = ""
	clear_selection()


# --- gestures ---------------------------------------------------------------------------------


## Start a rigid group drag with the cursor at `world_position`.
func begin_drag(world_position: Vector2) -> bool:
	_drag.clear()
	var members: Array[Node2D] = selection()
	if members.is_empty():
		return false
	# Ancestors move before descendants so selecting both cannot apply the delta twice.
	members.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.get_path().get_name_count() < b.get_path().get_name_count()
	)
	var offsets: Dictionary = {}
	var starts: Dictionary = {}
	for node: Node2D in members:
		offsets[node] = node.global_position - world_position
		starts[node] = node.position
	_drag = {"offsets": offsets, "starts": starts, "primary": _primary}
	return true


## Live preview: the primary decides the snap and every member keeps its offset from it, so a
## snapped group drag never deforms the group. No command runs until `end_drag()`.
func drag_to(world_position: Vector2, free_move: bool = false) -> void:
	if _drag.is_empty():
		return
	var offsets: Dictionary = _drag["offsets"]
	var lead: Variant = _drag["primary"]
	var lead_offset: Vector2 = offsets.get(lead, Vector2.ZERO) if is_instance_valid(lead) else Vector2.ZERO
	var destination: Vector2 = world_position + lead_offset
	var applied: Vector2 = Vector2.ZERO if free_move else snap(destination) - destination
	for node: Variant in offsets:
		if is_instance_valid(node):
			(node as Node2D).global_position = world_position + (offsets[node] as Vector2) + applied


## Commit the drag as one gesture: one `set_property position` command per moved member.
func end_drag() -> Dictionary:
	if _drag.is_empty():
		return _blocked(&"drag", &"begin_drag", "No drag in progress.")
	var starts: Dictionary = _drag["starts"]
	_drag.clear()
	var targets: Array[Node2D] = []
	var values: Array = []
	for node: Variant in starts:
		if not is_instance_valid(node):
			continue
		var moved := node as Node2D
		var final_position: Vector2 = moved.position
		moved.position = starts[node]
		if final_position != moved.position:
			targets.append(moved)
			values.append([final_position.x, final_position.y])
	if targets.is_empty():
		return _allowed({"commands": PackedStringArray()})
	return _run_gesture("Move", _property_commands(targets, "position", values))


func cancel_drag() -> void:
	if _drag.is_empty():
		return
	var starts: Dictionary = _drag["starts"]
	for node: Variant in starts:
		if is_instance_valid(node):
			(node as Node2D).position = starts[node]
	_drag.clear()


## One property on every selected node, as one gesture.
func set_selection_property(key: String, value: Variant) -> Dictionary:
	var targets: Array[Node2D] = selection()
	var values: Array = []
	for _node: Node2D in targets:
		values.append(value)
	return _run_gesture("Set %s" % key, _property_commands(targets, key, values))


## Inspector edits preserve untouched fractional components and are one undo gesture.
func set_primary_properties(values: Dictionary) -> Dictionary:
	finish_pointer()
	var lead: Node2D = primary()
	if lead == null:
		return _blocked(&"selection", &"editable_selection", "Select something first.")
	var current: Dictionary = LayoutOverrides.capture_properties(lead)
	var commands: Array[WeftluminCommand] = []
	for key: String in values:
		if current.get(key) != values[key]:
			commands.append(command_for(lead, OP_SET, {"key": key, "value": values[key]}))
	return _allowed() if commands.is_empty() else _run_gesture("Edit property", commands)


func nudge(delta: Vector2) -> Dictionary:
	var targets: Array[Node2D] = selection()
	var values: Array = []
	for node: Node2D in targets:
		var moved: Vector2 = node.position + delta
		values.append([moved.x, moved.y])
	return _run_gesture("Nudge", _property_commands(targets, "position", values))


func delete_selection() -> Dictionary:
	var commands: Array[WeftluminCommand] = []
	for node: Node2D in selection():
		commands.append(command_for(node, OP_REMOVE))
	var outcome: Dictionary = _run_gesture("Delete", commands)
	if bool(outcome["allowed"]):
		select_only(null)
	return outcome


## Copy every selected dressing prop one snap step down-right and select the copies. Refuses the
## whole gesture when any member is a structure the scratch format cannot recreate.
func duplicate_selection() -> Dictionary:
	var commands: Array[WeftluminCommand] = []
	var reserved: Dictionary = {}
	var primary_copy := ""
	for node: Node2D in selection():
		var layer: Node = node.get_parent()
		var addition: Dictionary = (
			LayoutOverrides.capture_addition(node, StringName(layer.name)) if layer != null else {}
		)
		if addition.is_empty():
			return _blocked(
				&"addition_schema", &"simple_dressing_prop",
				"Cannot duplicate %s: compound or scripted assets do not round-trip." % node.name,
			)
		var copy_name: String = _unique_name(layer, "%sCopy" % node.name, reserved)
		reserved["%s/%s" % [layer.get_instance_id(), copy_name]] = true
		addition["name"] = copy_name
		var moved: Vector2 = node.position + DUPLICATE_OFFSET
		addition["position"] = [moved.x, moved.y]
		var command: WeftluminCommand = command_for(layer, OP_ADD, {"addition": addition})
		commands.append(command)
		if node == _primary:
			primary_copy = command.id
	var outcome: Dictionary = _run_gesture("Duplicate", commands)
	if bool(outcome["allowed"]):
		var copies: Array[Node2D] = []
		var lead: Node2D = null
		for command: WeftluminCommand in commands:
			var added: Node2D = _added_node(command.id)
			if added != null:
				copies.append(added)
				if command.id == primary_copy:
					lead = added
		set_selection(copies, lead)
	return outcome


## Place one dressing prop from a complete `LayoutOverrides` addition payload.
func add_prop(addition: Dictionary) -> Dictionary:
	var layer: Node = _layer(StringName(str(addition.get("layer", ""))))
	if layer == null:
		return _blocked(&"layer", &"dressing_layer", "No %s layer in this scene." % addition.get("layer", ""))
	return _run_gesture("Place", [command_for(layer, OP_ADD, {"addition": addition.duplicate(true)})])


func place_prop(world_position: Vector2, free_move: bool = false) -> Dictionary:
	var layer := _layer(placement_layer) as Node2D
	if layer == null:
		return _blocked(&"layer", &"dressing_layer", "No %s layer in this scene." % placement_layer)
	var at: Vector2 = layer.to_local(world_position if free_move else snap(world_position))
	var size: Vector2 = footprint.clamp(Vector2.ONE, MAX_FOOTPRINT)
	var addition := {
		"layer": String(placement_layer), "texture": texture_path,
		"name": _prop_name(layer, texture_path), "position": [at.x, at.y],
		"scale": [1.0, 1.0], "collision": [size.x, size.y],
	}
	var outcome: Dictionary = add_prop(addition)
	if bool(outcome["allowed"]):
		select_only(layer.get_node_or_null(NodePath(str(addition["name"]))) as Node2D)
	return outcome


func save_pattern(label: String) -> Dictionary:
	finish_pointer()
	if selection().is_empty():
		return _blocked(&"selection", &"editable_selection", "Select something first, then Ctrl+G.")
	var outcome: Dictionary = Patterns.capture(selection(), label)
	if not bool(outcome.get("allowed", false)):
		return outcome
	var captured: Dictionary = outcome["pattern"]
	var error: Error = Patterns.save_file(Patterns.pattern_path_for_id(StringName(captured["id"])), captured)
	if error != OK:
		return _blocked(&"save", &"writable_library", "Pattern could not be saved: %s." % error_string(error))
	return outcome


func stamp_pattern(world_position: Vector2, free_move: bool = false) -> Dictionary:
	var outcome: Dictionary = Patterns.stamp(
		pattern, world_position if free_move else snap(world_position),
		func(layer_name: StringName) -> Node2D: return _layer(layer_name) as Node2D,
		_prop_name, 0.0,
	)
	if not bool(outcome.get("allowed", false)):
		return outcome
	var commands: Array[WeftluminCommand] = []
	for addition: Dictionary in outcome["additions"]:
		commands.append(command_for(_layer(StringName(addition["layer"])), OP_ADD, {"addition": addition}))
	var result: Dictionary = _run_gesture("Stamp pattern", commands)
	if bool(result["allowed"]):
		var placed: Array[Node2D] = []
		for command: WeftluminCommand in commands:
			var node: Node2D = _added_node(command.id)
			if node != null:
				placed.append(node)
		set_selection(placed)
		result["skipped_layers"] = outcome.get("skipped_layers", [])
	return result


func _prop_name(layer: Node, path: String, reserved: PackedStringArray = PackedStringArray()) -> String:
	var names: Dictionary = {}
	for value: String in reserved:
		names["%s/%s" % [layer.get_instance_id(), value]] = true
	var base: String = path.get_file().get_basename().to_pascal_case()
	return _unique_name(layer, "LayoutProp" if base.is_empty() else base, names)


static func palette_entries(category_index: int, query: String) -> Array[Dictionary]:
	var paths: Dictionary = {}
	for path: String in PALETTE_CATEGORIES[clampi(category_index, 0, PALETTE_CATEGORIES.size() - 1)]["roots"]:
		_scan_palette(path, paths)
	var scored: Array[Dictionary] = []
	for path: String in paths:
		var score: int = Patterns.fuzzy_score(query.strip_edges(), path.trim_prefix("res://assets/generated/sprites/"))
		if score >= 0:
			scored.append({"path": path, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["score"]) < int(b["score"]) if a["score"] != b["score"] else str(a["path"]) < str(b["path"])
	)
	return scored


static func _scan_palette(path: String, paths: Dictionary) -> void:
	for directory: String in DirAccess.get_directories_at(path):
		_scan_palette(path.path_join(directory), paths)
	for file: String in DirAccess.get_files_at(path):
		if file.get_extension().to_lower() == "png":
			paths[path.path_join(file)] = true


func undo() -> Dictionary:
	cancel_drag()
	var outcome: Dictionary = bus.undo()
	_after_history()
	return outcome


func redo() -> Dictionary:
	cancel_drag()
	var outcome: Dictionary = bus.redo()
	_after_history()
	return outcome


# --- node -> command mapping ------------------------------------------------------------------


## The `scene` command for `op` on `node`, targeting it by path from the scene root.
func command_for(node: Node, op: String, params: Dictionary = {}) -> WeftluminCommand:
	return WeftluminCommand.make(
		KIND, op,
		{"scene": scene_path(), "node": String(scene_root.get_path_to(node))},
		params, bus.package if bus != null else "",
	)


## Command constructors, for the panel's `commands()` and CLI help.
func command_constructors() -> Array[Callable]:
	return [
		set_selection_property, nudge, delete_selection, duplicate_selection, add_prop,
		begin_drag, drag_to, end_drag,
	]


func _property_commands(targets: Array[Node2D], key: String, values: Array) -> Array[WeftluminCommand]:
	var commands: Array[WeftluminCommand] = []
	for index: int in targets.size():
		commands.append(command_for(targets[index], OP_SET, {"key": key, "value": values[index]}))
	return commands


## Run `commands` as one undo step. Every command is checked first, so a gesture lands whole or
## not at all.
func _run_gesture(label: String, commands: Array[WeftluminCommand]) -> Dictionary:
	if commands.is_empty():
		return _blocked(&"selection", &"editable_selection", "Nothing selected to %s." % label.to_lower())
	for command: WeftluminCommand in commands:
		var refusal: Dictionary = _check_command(command)
		if not bool(refusal["allowed"]):
			return refusal
	var record := {
		"label": label, "ids": PackedStringArray(), "steps": [],
		"document_before": document.duplicate(true), "document_after": {},
	}
	_gesture = record
	bus.begin_merge(label)
	var outcome: Dictionary = _allowed()
	for command: WeftluminCommand in commands:
		var result: Dictionary = bus.execute(command)
		if not bool(result["allowed"]):
			outcome = result
			break
		(record["ids"] as PackedStringArray).append(command.id)
		_gestures[command.id] = record
	bus.end_merge()
	_gesture = {}
	record["document_after"] = document.duplicate(true)
	outcome["commands"] = record["ids"]
	_prune_selection()
	_checkpoint()
	scene_changed.emit()
	return outcome


func _check_command(command: WeftluminCommand) -> Dictionary:
	var node: Node = _resolve(command)
	if node == null:
		return _blocked(&"scene_boundary", &"node_in_scene", "No node at %s." % command.target.get("node", ""))
	var refusal: Dictionary = check(command.op, node)
	if not bool(refusal["allowed"]):
		return refusal
	match command.op:
		OP_SET:
			var key: String = str(command.params.get("key", ""))
			if not LayoutOverrides.REPLAYABLE_PROPERTY_KEYS.has(key):
				return _blocked(
					&"property_schema", &"replayable_property",
					"%s is outside the layout replay schema." % key,
				)
			if not LayoutOverrides.capture_properties(node as Node2D).has(key):
				return _blocked(&"property_schema", &"node_has_property", "%s has no %s." % [node.name, key])
		OP_ADD:
			var addition: Dictionary = command.params.get("addition", {}) as Dictionary
			var layer_name := StringName(str(addition.get("layer", "")))
			# apply_to_scene places an addition in the FIRST layer of that name; refuse any other
			# target rather than let the live scene and its replay disagree.
			if node.name != layer_name or node != _layer(layer_name):
				return _blocked(&"layer", &"dressing_layer", "Props are added to a dressing layer only.")
			if node.get_node_or_null(NodePath(str(addition.get("name", "")))) != null:
				return _blocked(&"name", &"unique_name", "%s already has %s." % [node.name, addition.get("name", "")])
	return _allowed()


# --- bus handlers -----------------------------------------------------------------------------


func _capture(command: WeftluminCommand) -> Dictionary:
	var node: Node = _resolve(command)
	match command.op:
		OP_SET:
			if not node is Node2D:
				return {}
			var values: Dictionary = LayoutOverrides.capture_properties(node as Node2D)
			return {"value": values.get(str(command.params.get("key", "")))}
		OP_ADD:
			var child_name: String = str((command.params.get("addition", {}) as Dictionary).get("name", ""))
			return {"present": node != null and node.get_node_or_null(NodePath(child_name)) != null}
	return {"present": node != null}


## First execution applies the command alone; a redo (or replay of a known gesture) reapplies
## its whole gesture, because merged undo keeps only one end of the gesture.
func _apply(command: WeftluminCommand) -> Dictionary:
	if _gesture.is_empty() and _gestures.has(command.id):
		_reapply(_gestures[command.id], true)
		return _allowed()
	var refusal: Dictionary = _check_command(command)
	if not bool(refusal["allowed"]):
		return refusal
	var step: Dictionary = _apply_once(command)
	if not _gesture.is_empty() and not step.is_empty():
		step["id"] = command.id
		(_gesture["steps"] as Array).append(step)
	return _allowed()


func _revert(command: WeftluminCommand) -> Dictionary:
	if _gestures.has(command.id):
		_reapply(_gestures[command.id], false)
		return _allowed()
	var node: Node = _resolve(command)
	if command.op == OP_SET and node is Node2D:
		LayoutOverrides.apply_properties(
			node as Node2D, {str(command.params["key"]): command.pre_state.get("value")}
		)
		_record(node as Node2D)
		return _allowed()
	return _blocked(&"history", &"gesture", "No live record of %s to revert." % command.id)


func _apply_once(command: WeftluminCommand) -> Dictionary:
	var node: Node = _resolve(command)
	match command.op:
		OP_SET:
			var key: String = str(command.params["key"])
			var path: String = str(command.target["node"])
			var edit := {"path": path}
			edit[key] = command.params.get("value")
			LayoutOverrides.apply_to_scene(scene_root, _single(&"edits", edit))
			_record(node as Node2D)
			return {
				"op": OP_SET, "node": node, "key": key,
				"before": command.pre_state.get("value"), "after": command.params.get("value"),
			}
		OP_REMOVE:
			_record_removal(node as Node2D)
			var parent: Node = node.get_parent()
			var index: int = node.get_index()
			var owners: Dictionary = {}
			_capture_owners(node, owners)
			parent.remove_child(node)
			return {"op": OP_REMOVE, "node": node, "parent": parent, "index": index, "owners": owners}
		OP_ADD:
			var addition: Dictionary = (command.params["addition"] as Dictionary).duplicate(true)
			LayoutOverrides.apply_to_scene(scene_root, _single(&"additions", addition))
			var added: Node = node.get_node_or_null(NodePath(str(addition["name"])))
			if added != null:
				(document["additions"] as Array).append(addition)
				return {"op": OP_ADD, "node": added, "parent": node, "index": added.get_index()}
	return {}


## Restore (`forward == false`) or reapply a whole gesture. Idempotent per step, so it is safe
## whichever command of the gesture the history calls it through, and however often.
func _reapply(record: Dictionary, forward: bool) -> void:
	var steps: Array = (record["steps"] as Array).duplicate()
	if not forward:
		steps.reverse()
	for step: Dictionary in steps:
		var node: Variant = step.get("node")
		if not is_instance_valid(node):
			continue
		match String(step["op"]):
			OP_SET:
				var value: Variant = step["after"] if forward else step["before"]
				LayoutOverrides.apply_properties(node as Node2D, {step["key"]: value})
			OP_REMOVE:
				_attach(node as Node, step, not forward)
			OP_ADD:
				_attach(node as Node, step, forward)
	document = (record["document_after" if forward else "document_before"] as Dictionary).duplicate(true)
	_sync_addition_meta()


func _attach(node: Node, step: Dictionary, attached: bool) -> void:
	var parent: Node = step["parent"]
	if attached and node.get_parent() == null and is_instance_valid(parent):
		parent.add_child(node)
		parent.move_child(node, mini(int(step["index"]), parent.get_child_count() - 1))
		for member: Variant in step.get("owners", {}):
			var owner_node: Variant = step["owners"][member]
			if is_instance_valid(member) and is_instance_valid(owner_node) and (owner_node as Node).is_ancestor_of(member):
				(member as Node).owner = owner_node
	elif not attached and node.get_parent() != null:
		node.get_parent().remove_child(node)


func _capture_owners(node: Node, owners: Dictionary) -> void:
	owners[node] = node.owner
	for child: Node in node.get_children():
		_capture_owners(child, owners)


func _after_history() -> void:
	_prune_selection()
	_checkpoint()
	selection_changed.emit()
	scene_changed.emit()


# --- document bookkeeping ----------------------------------------------------------------------


func _record(node: Node2D) -> void:
	var index: int = _addition_index(node)
	if index >= 0:
		var additions: Array = document["additions"]
		var addition: Dictionary = additions[index]
		addition.merge(LayoutOverrides.capture_properties(node), true)
		node.set_meta(ADDITION_META, addition.duplicate(true))
		return
	var path: String = String(scene_root.get_path_to(node))
	var edit: Dictionary = LayoutOverrides.capture_properties(node)
	edit["path"] = path
	var edits: Array = document["edits"]
	for slot: int in edits.size():
		if str((edits[slot] as Dictionary).get("path", "")) == path:
			edits[slot] = edit
			return
	edits.append(edit)


func _record_removal(node: Node2D) -> void:
	var index: int = _addition_index(node)
	if index >= 0:
		(document["additions"] as Array).remove_at(index)
		return
	var path: String = String(scene_root.get_path_to(node))
	var deletions: Array = document["deletions"]
	if not deletions.has(path):
		deletions.append(path)
	var edits: Array = document["edits"]
	for slot: int in range(edits.size() - 1, -1, -1):
		var edited: String = str((edits[slot] as Dictionary).get("path", ""))
		if edited == path or edited.begins_with(path + "/"):
			edits.remove_at(slot)


func _addition_index(node: Node2D) -> int:
	if not node.has_meta(ADDITION_META):
		return -1
	var parent: Node = node.get_parent()
	if parent == null:
		return -1
	var additions: Array = document["additions"]
	for index: int in additions.size():
		var addition: Dictionary = additions[index]
		if str(addition.get("layer", "")) == String(parent.name) \
				and str(addition.get("name", "")) == String(node.name):
			return index
	return -1


## Undo restores a document snapshot; keep each live addition's re-select tag in step with it.
func _sync_addition_meta() -> void:
	for addition: Dictionary in document["additions"]:
		var layer: Node = _layer(StringName(str(addition.get("layer", ""))))
		var added: Node = layer.get_node_or_null(NodePath(str(addition.get("name", "")))) if layer != null else null
		if added != null and added.has_meta(ADDITION_META):
			added.set_meta(ADDITION_META, addition.duplicate(true))


# --- helpers ----------------------------------------------------------------------------------


func _resolve(command: WeftluminCommand) -> Node:
	if scene_root == null:
		return null
	return scene_root.get_node_or_null(NodePath(str(command.target.get("node", ""))))


func _added_node(command_id: String) -> Node2D:
	var record: Dictionary = _gestures.get(command_id, {})
	for step: Dictionary in record.get("steps", []):
		if str(step.get("id", "")) == command_id and is_instance_valid(step.get("node")):
			return step["node"] as Node2D
	return null


func _unique_gestures() -> Array:
	var seen: Array = []
	for record: Variant in _gestures.values():
		if not seen.has(record):
			seen.append(record)
	return seen


func _roots() -> Array[Node]:
	var roots: Array[Node] = []
	if scene_root == null or not editable_roots_provider.is_valid():
		return roots
	var provided: Variant = editable_roots_provider.call(scene_root)
	if provided is Array:
		for root: Variant in provided:
			if root is Node:
				roots.append(root as Node)
	return roots


func _collect_editable(node: Node, roots: Array[Node], output: Array[Node2D]) -> void:
	for child: Node in node.get_children():
		if _is_editable_under(child, roots):
			output.append(child as Node2D)
		_collect_editable(child, roots, output)


func _is_scratch(node: Node) -> bool:
	var current: Node = node
	while current != null and current != scene_root:
		if current.has_meta(ADDITION_META) and current.owner == null:
			return true
		current = current.get_parent()
	return false


func _is_editable_instance(instance: Node) -> bool:
	return scene_root.is_editable_instance(instance) \
		or _editable_paths.has(String(scene_root.get_path_to(instance)))


func _prune_selection() -> void:
	for index: int in range(_selection.size() - 1, -1, -1):
		var node: Node2D = _selection[index]
		if not is_instance_valid(node) or not is_instance_valid(scene_root) or not scene_root.is_ancestor_of(node):
			_selection.remove_at(index)
	if not is_instance_valid(_primary) or not _selection.has(_primary):
		_primary = _selection.back() if not _selection.is_empty() else null


func _layer(layer_name: StringName) -> Node:
	if scene_root == null or not LayoutOverrides.DRESSING_LAYERS.has(layer_name):
		return null
	if scene_root.name == layer_name:
		return scene_root
	return scene_root.find_child(String(layer_name), true, false)


func _unique_name(parent: Node, base: String, reserved: Dictionary) -> String:
	var candidate := base
	var suffix := 2
	while parent.get_node_or_null(NodePath(candidate)) != null \
			or reserved.has("%s/%s" % [parent.get_instance_id(), candidate]):
		candidate = "%s%d" % [base, suffix]
		suffix += 1
	return candidate


func _sprite_world_bounds(sprite: Sprite2D) -> Rect2:
	var local_rect: Rect2 = sprite.get_rect()
	var transform: Transform2D = sprite.global_transform
	var area := Rect2(transform * local_rect.position, Vector2.ZERO)
	for corner: Vector2 in [
		Vector2(local_rect.end.x, local_rect.position.y), local_rect.end,
		Vector2(local_rect.position.x, local_rect.end.y),
	]:
		area = area.expand(transform * corner)
	return area


static func _first_sprite(node: Node) -> Sprite2D:
	for child: Node in node.get_children():
		if child is Sprite2D:
			return child as Sprite2D
		var nested: Sprite2D = _first_sprite(child)
		if nested != null:
			return nested
	return null


static func _single(field: StringName, entry: Variant) -> Dictionary:
	var single: Dictionary = LayoutOverrides.create_document("")
	(single[String(field)] as Array).append(entry)
	return single


static func _read_editable_paths(root: Node) -> Dictionary:
	var paths: Dictionary = {}
	var path: String = root.scene_file_path if root != null else ""
	if path.is_empty() or not FileAccess.file_exists(path):
		return paths
	var parsed: TscnDocument = TscnDocument.parse(FileAccess.get_file_as_string(path))
	if parsed == null:
		return paths
	for section: Dictionary in parsed.editable_paths:
		paths[str(section.get("path", ""))] = true
	return paths


static func _allowed(extra: Dictionary = {}) -> Dictionary:
	var result := {"allowed": true, "blocked_by": &"", "nearest_unblock": &"", "message": ""}
	result.merge(extra, true)
	return result


static func _blocked(by: StringName, unblock: StringName, message: String) -> Dictionary:
	return {"allowed": false, "blocked_by": by, "nearest_unblock": unblock, "message": message}
