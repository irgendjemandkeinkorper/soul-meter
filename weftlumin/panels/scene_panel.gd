class_name WeftluminScenePanel
extends WeftluminPanel
## The dock's left "Scene tree" slot (architecture §4.5.5) over the scene model (§4.6.1, E3.1a).
##
## The tree lists the live gameplay scene and marks each node's ownership boundary; only nodes
## the model can edit are selectable, and the tree's multi-selection IS the model's selection
## set. Every effect goes through `WeftluminSceneModel` and its command bus; this panel only
## presents. Chrome uses the `Editor*` theme variations.

const SNAP_LABELS: Array[String] = ["No snap", "8 px snap", "Cell snap"]
const BOUNDARY_TAGS := {
	WeftluminSceneModel.Boundary.INSTANCE: "instanced",
	WeftluminSceneModel.Boundary.RUNTIME: "runtime",
}

var model: WeftluminSceneModel = null
var tree: Tree = null
var status: Label = null
var snap_option: OptionButton = null
var _host: WeftluminShell = null
var _items: Dictionary = {}
var _syncing := false
var _sync_queued := false
var _last_selected: Node2D = null
var _message := ""


func _init() -> void:
	title = "Scene tree"
	needs_sandbox = false
	hotkey_hint = ""


func configure(host: WeftluminShell) -> void:
	_host = host
	if model != null:
		return
	model = WeftluminSceneModel.new()
	var adapter: WeftluminGameAdapter = host.adapter if host != null else null
	if adapter != null:
		# The adapter owns the editable-roots list; the panel only forwards to it.
		model.editable_roots_provider = func(scene_root: Node) -> Array[Node]:
			return adapter.editable_roots(scene_root)
	_build()
	model.selection_changed.connect(_sync_to_tree)
	model.scene_changed.connect(_rebuild)
	refresh({"scene_root": adapter.gameplay_scene_root() if adapter != null else null})


func refresh(payload: Dictionary) -> void:
	var scene_root: Node = payload.get("scene_root", model.scene_root) as Node
	if scene_root != model.scene_root or model.bus == null:
		model.configure(scene_root)
		model.grid = _grid_for(scene_root)
		snap_option.set_item_disabled(WeftluminSceneModel.Snap.CELL, model.grid == null)
		if model.grid == null and model.snap_mode == WeftluminSceneModel.Snap.CELL:
			set_snap_mode(WeftluminSceneModel.Snap.GRID)
	_rebuild()


func commands() -> Array[Callable]:
	return model.command_constructors()


func _exit_tree() -> void:
	if model != null:
		model.dispose()


## A viewport click in world space: Shift-style `additive` toggles membership.
func pick_at(world_position: Vector2, additive: bool = false) -> Node2D:
	return model.pick_select(world_position, additive)


func set_snap_mode(mode: WeftluminSceneModel.Snap) -> void:
	model.snap_mode = mode
	snap_option.select(mode)
	_refresh_status()


func status_text() -> String:
	return status.text if status != null else ""


func _build() -> void:
	var content := VBoxContainer.new()
	content.name = "Content"
	content.theme_type_variation = &"EditorColumn"
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var snap_row := SoulMeterToolPanel._row()
	content.add_child(snap_row)
	snap_option = SoulMeterToolPanel._option("Snap")
	snap_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label: String in SNAP_LABELS:
		snap_option.add_item(label)
	snap_option.select(model.snap_mode)
	snap_option.item_selected.connect(func(index: int) -> void:
		set_snap_mode(index as WeftluminSceneModel.Snap)
	)
	snap_row.add_child(snap_option)
	snap_row.add_child(SoulMeterToolPanel._button("Undo", "Undo", func() -> void: _report(model.undo())))
	snap_row.add_child(SoulMeterToolPanel._button("Redo", "Redo", func() -> void: _report(model.redo())))
	var edit_row := SoulMeterToolPanel._row()
	content.add_child(edit_row)
	edit_row.add_child(SoulMeterToolPanel._button(
		"Duplicate", "Duplicate", func() -> void: _report(model.duplicate_selection())
	))
	edit_row.add_child(SoulMeterToolPanel._button(
		"Delete", "Delete", func() -> void: _report(model.delete_selection())
	))
	status = SoulMeterToolPanel._label("", &"EditorLabel", true)
	status.name = "Status"
	content.add_child(status)
	tree = Tree.new()
	tree.name = "SceneTree"
	tree.theme_type_variation = &"EditorTree"
	tree.select_mode = Tree.SELECT_MULTI
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.multi_selected.connect(_on_tree_multi_selected)
	content.add_child(tree)


func _rebuild() -> void:
	if tree == null:
		return
	_syncing = true
	tree.clear()
	_items.clear()
	if model.scene_root != null:
		_append(model.scene_root, null)
	_syncing = false
	_sync_to_tree()


func _append(node: Node, parent_item: TreeItem) -> void:
	var item := tree.create_item(parent_item)
	var info: Dictionary = model.boundary(node)
	var editable: bool = model.is_editable(node)
	var tag: String = BOUNDARY_TAGS.get(int(info["kind"]), "")
	if int(info["kind"]) == WeftluminSceneModel.Boundary.INSTANCE and bool(info["editable_instance"]):
		tag = "override"
	item.set_text(0, String(node.name) if tag.is_empty() else "%s  · %s" % [node.name, tag])
	item.set_tooltip_text(0, "%s (%s)" % [node.get_class(), "editable" if editable else "locked"])
	item.set_selectable(0, editable)
	item.set_metadata(0, weakref(node))
	item.collapsed = parent_item != null
	_items[node] = item
	for child: Node in node.get_children():
		_append(child, item)


func _on_tree_multi_selected(item: TreeItem, _column: int, selected: bool) -> void:
	if _syncing:
		return
	var node := (item.get_metadata(0) as WeakRef).get_ref() as Node2D
	if selected and node != null:
		_last_selected = node
	# Tree emits once per changed row; read the settled set once.
	if not _sync_queued:
		_sync_queued = true
		_sync_from_tree.call_deferred()


func _sync_from_tree() -> void:
	_sync_queued = false
	var nodes: Array[Node2D] = []
	var item: TreeItem = tree.get_next_selected(null)
	while item != null:
		var node := (item.get_metadata(0) as WeakRef).get_ref() as Node2D
		if node != null:
			nodes.append(node)
		item = tree.get_next_selected(item)
	model.set_selection(nodes, _last_selected)


func _sync_to_tree() -> void:
	if tree == null:
		return
	_syncing = true
	tree.deselect_all()
	var lead: Node2D = model.primary()
	for node: Node2D in model.selection():
		var item: TreeItem = _items.get(node)
		if item == null:
			continue
		var ancestor: TreeItem = item.get_parent()
		while ancestor != null:
			ancestor.collapsed = false
			ancestor = ancestor.get_parent()
		item.select(0)
	if lead != null and _items.has(lead):
		tree.scroll_to_item(_items[lead] as TreeItem)
	_syncing = false
	_refresh_status()
	_refresh_inspector()


func _report(outcome: Dictionary) -> void:
	_message = "" if bool(outcome.get("allowed", false)) else str(outcome.get("message", ""))
	_refresh_status()


func _refresh_status() -> void:
	if status == null:
		return
	var members: Array[Node2D] = model.selection()
	var lines: PackedStringArray = []
	if model.scene_root == null:
		lines.append("No gameplay scene.")
	elif members.is_empty():
		lines.append("Select a scene node.")
	else:
		lines.append("%d selected · primary %s" % [members.size(), model.primary().name])
	lines.append(SNAP_LABELS[model.snap_mode])
	if not _message.is_empty():
		lines.append(_message)
	status.text = "\n".join(lines)


func _refresh_inspector() -> void:
	if _host == null or _host.inspector == null:
		return
	var lead: Node2D = model.primary()
	if lead == null:
		_host.inspector.text = "INSPECTOR\nSelect a scene node."
		return
	var info: Dictionary = model.boundary(lead)
	var ownership := "scene-owned"
	if int(info["kind"]) == WeftluminSceneModel.Boundary.INSTANCE:
		ownership = "instance override (%s)" % (info["instance_root"] as Node).name
	_host.inspector.text = "INSPECTOR\n%s\n%s · %s\nposition %s" % [
		lead.name, lead.get_class(), ownership, lead.position,
	]


static func _grid_for(scene_root: Node) -> IsoGrid:
	if scene_root == null:
		return null
	var pending: Array[Node] = [scene_root]
	while not pending.is_empty():
		var node: Node = pending.pop_front()
		if node is FieldMap:
			return (node as FieldMap).iso_grid()
		pending.append_array(node.get_children())
	return null
