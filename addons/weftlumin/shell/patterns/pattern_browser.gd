class_name WeftluminPatternBrowser
extends VBoxContainer
## The pattern library browser (E3.1c, #370): list, arm-as-brush, rename, delete, promote.
##
## It only presents `WeftluminPatternLibrary.entries()` rows (`{pattern, source, path}`) and
## emits intent; the host's scene model runs each request as one undoable command. Choosing a
## row also fills the name field, so a stamped arrangement can be rearranged and saved straight
## back over its own name. Repo patterns are listed read-only: rename, delete and promote are
## disabled for them.

signal pattern_chosen(entry: Dictionary)
signal save_requested(display_name: String)
signal rename_requested(entry: Dictionary, display_name: String)
signal delete_requested(entry: Dictionary)
signal promote_requested(entry: Dictionary)

const REPO_TAG := "repo, read-only"

var name_field: LineEdit
var list: Tree
var save_button: Button
var rename_button: Button
var delete_button: Button
var promote_button: Button
var _refreshing := false


func _init() -> void:
	name = "PatternBrowser"
	theme_type_variation = &"EditorColumn"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_field = LineEdit.new()
	name_field.name = "PatternName"
	name_field.theme_type_variation = &"EditorLineEdit"
	name_field.placeholder_text = "Pattern name"
	add_child(name_field)
	save_button = _button("Save pattern (Ctrl+G)", "SavePattern", func() -> void:
		save_requested.emit(name_field.text)
	)
	add_child(save_button)
	var row := HBoxContainer.new()
	row.name = "PatternActions"
	row.theme_type_variation = &"EditorRow"
	add_child(row)
	rename_button = _button("Rename", "RenamePattern", func() -> void:
		var entry: Dictionary = selected_entry()
		if not entry.is_empty():
			rename_requested.emit(entry, name_field.text)
	)
	delete_button = _button("Delete", "DeletePattern", func() -> void:
		var entry: Dictionary = selected_entry()
		if not entry.is_empty():
			delete_requested.emit(entry)
	)
	promote_button = _button("Promote to repo", "PromotePattern", func() -> void:
		var entry: Dictionary = selected_entry()
		if not entry.is_empty():
			promote_requested.emit(entry)
	)
	for button: Button in [rename_button, delete_button, promote_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	list = Tree.new()
	list.name = "Patterns"
	list.theme_type_variation = &"EditorTree"
	list.hide_root = true
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(_on_item_selected)
	add_child(list)
	_update_actions()


## Replace the listed rows, keeping the current choice when it is still listed.
func set_entries(entries: Array[Dictionary]) -> void:
	var kept: String = _key(selected_entry())
	list.clear()
	var root: TreeItem = list.create_item()
	var reselect: TreeItem = null
	for entry: Dictionary in entries:
		var pattern: Dictionary = entry["pattern"]
		var item: TreeItem = list.create_item(root)
		var read_only: bool = is_read_only(entry)
		item.set_text(0, "%s (%d)%s" % [
			pattern.get("name", pattern.get("id", "")), (pattern.get("nodes", []) as Array).size(),
			" · %s" % REPO_TAG if read_only else "",
		])
		item.set_tooltip_text(0, str(entry.get("path", "")))
		item.set_metadata(0, entry)
		if not kept.is_empty() and _key(entry) == kept:
			reselect = item
	if reselect != null:
		# Keeping the row is presentation only; re-arming the brush would drop the selection.
		_refreshing = true
		reselect.select(0)
		_refreshing = false
	_update_actions()


func selected_entry() -> Dictionary:
	var item: TreeItem = list.get_selected() if list != null else null
	return item.get_metadata(0) as Dictionary if item != null else {}


## Select the listed pattern with `id` from `source`, as a click on its row would.
func choose(id: StringName, source: String = WeftluminPatternLibrary.SOURCE_USER) -> bool:
	var root: TreeItem = list.get_root()
	for item: TreeItem in root.get_children() if root != null else []:
		var entry: Dictionary = item.get_metadata(0) as Dictionary
		if str((entry["pattern"] as Dictionary).get("id", "")) == String(id) and str(entry.get("source", "")) == source:
			item.select(0)
			return true
	return false


func clear_choice() -> void:
	list.deselect_all()
	_update_actions()


static func is_read_only(entry: Dictionary) -> bool:
	return str(entry.get("source", "")) == WeftluminPatternLibrary.SOURCE_REPO


func _on_item_selected() -> void:
	var entry: Dictionary = selected_entry()
	_update_actions()
	if entry.is_empty() or _refreshing:
		return
	name_field.text = str((entry["pattern"] as Dictionary).get("name", ""))
	pattern_chosen.emit(entry)


func _update_actions() -> void:
	var entry: Dictionary = selected_entry()
	var editable: bool = not entry.is_empty() and not is_read_only(entry)
	for button: Button in [rename_button, delete_button, promote_button]:
		button.disabled = not editable
		button.tooltip_text = "" if editable or entry.is_empty() else "Repo patterns are read-only."


static func _key(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	return "%s/%s" % [entry.get("source", ""), (entry["pattern"] as Dictionary).get("id", "")]


static func _button(text: String, node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.theme_type_variation = &"EditorButton"
	button.pressed.connect(action)
	return button
