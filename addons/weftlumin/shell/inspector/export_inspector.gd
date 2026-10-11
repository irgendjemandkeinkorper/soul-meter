class_name WeftluminExportInspector
extends VBoxContainer
## Schema-agnostic export inspector (architecture §4.6.4, P8, E3.1b).
##
## Fields come from the inspected node's `get_property_list()`, filtered to exported script
## variables (`WeftluminSceneModel.is_export`); `@export_group`/`@export_subgroup` entries become
## headings. Each field gets an editor chosen by its type and hint — `@export_range` spin boxes,
## enum option buttons, `@export_file` choices, multiline text — and, where the host's
## `pickers` table claims the property name, a semantic picker with live validation. The
## inspector never writes the node: every edit goes through `commit`, which the scene tool binds
## to its `set_property` command, and the field then re-reads the node.

## Emitted after every attempted commit with the command outcome.
signal edited(key: String, outcome: Dictionary)

## Most options a picker menu lists at once; typing in the field narrows the list.
const MENU_LIMIT := 200
## Directories an `@export_file` choice list never scans.
const FILE_SCAN_SKIP: Array[String] = ["addons", "test", "docs", "reports"]

static var _file_cache: Dictionary = {}

## `{picker_id: {label, properties: PackedStringArray globs, options: (node) -> PackedStringArray,
## validate: (value: String, node) -> String}}` from `WeftluminGameAdapter.pickers()`.
var pickers: Dictionary = {}
## `(key: String, value: Variant) -> Dictionary` refusal-shaped outcome.
var commit: Callable = Callable()
var target: Node = null
var _fields: Dictionary = {}
var _syncing := false


func _init() -> void:
	name = "ExportInspector"
	theme_type_variation = &"EditorColumn"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Rebuild the field list for `node` (null clears it).
func inspect(node: Node) -> void:
	if node == target and not _fields.is_empty() and is_instance_valid(node):
		refresh()
		return
	# Detach first: a field may be the control whose signal led here.
	_fields.clear()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	target = node if is_instance_valid(node) else null
	if target == null:
		return
	add_child(_label("EXPORTS", &"EditorHeading"))
	# Engine classes declare groups too; a heading appears only once an export falls under it.
	var group := ""
	var subgroup := ""
	var shown: Dictionary = {}
	for property: Dictionary in target.get_property_list():
		var usage: int = int(property["usage"])
		if usage & PROPERTY_USAGE_CATEGORY:
			group = ""
			subgroup = ""
		elif usage & PROPERTY_USAGE_SUBGROUP:
			subgroup = str(property["name"])
		elif usage & PROPERTY_USAGE_GROUP:
			group = str(property["name"])
			subgroup = ""
		elif WeftluminSceneModel.is_export(property):
			if not group.is_empty() and not shown.has(group):
				shown[group] = true
				add_child(_label(group, &"EditorHeading"))
			if not subgroup.is_empty() and not shown.has(group + "/" + subgroup):
				shown[group + "/" + subgroup] = true
				add_child(_label(subgroup, &"EditorLabel"))
			_add_field(property)
	if _fields.is_empty():
		add_child(_label("No exported properties.", &"EditorLabel"))
	refresh()


## Re-read every field from the node, except the one being typed in: viewport input refreshes
## the inspector, and an uncommitted edit must survive the mouse crossing the viewport.
func refresh() -> void:
	if not is_instance_valid(target):
		return
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	_syncing = true
	for key: String in _fields:
		var root: Control = _fields[key]["root"]
		if focused != null and (focused == root or root.is_ancestor_of(focused)):
			continue
		(_fields[key]["write"] as Callable).call(target.get(key))
	_syncing = false


func keys() -> PackedStringArray:
	return PackedStringArray(_fields.keys())


## The field's main editor control.
func editor(key: String) -> Control:
	return _fields[key]["control"] if _fields.has(key) else null


## The picker id claiming `key`, or "".
func picker_for(key: String) -> String:
	for picker_id: Variant in pickers:
		for glob: String in (pickers[picker_id] as Dictionary).get("properties", PackedStringArray()):
			if key.match(glob):
				return str(picker_id)
	return ""


## Options the field's picker (or `@export_file` filter) offers for the inspected node.
func options(key: String) -> PackedStringArray:
	if not _fields.has(key):
		return PackedStringArray()
	var source: Callable = _fields[key]["options"]
	return source.call() if source.is_valid() else PackedStringArray()


## The field's visible validation or refusal message.
func message(key: String) -> String:
	return (_fields[key]["message"] as Label).text if _fields.has(key) else ""


## Commit the field's current editor value, as its own change signal does.
func commit_field(key: String) -> Dictionary:
	if _syncing or not _fields.has(key) or not is_instance_valid(target):
		return {"allowed": false, "message": "No field %s." % key}
	var field: Dictionary = _fields[key]
	var value: Variant = (field["read"] as Callable).call()
	var problem: String = _validate(key, value)
	if problem.is_empty() and value is Dictionary and (value as Dictionary).has("__invalid"):
		problem = str(value["__invalid"])
	var outcome: Dictionary
	if not problem.is_empty():
		outcome = {"allowed": false, "blocked_by": &"picker_validation", "message": problem}
	elif commit.is_valid():
		outcome = commit.call(key, value)
	else:
		outcome = {"allowed": false, "message": "No commit target."}
	_show_message(key, "" if bool(outcome.get("allowed", false)) else str(outcome.get("message", "")))
	if bool(outcome.get("allowed", false)):
		_syncing = true
		(field["write"] as Callable).call(target.get(key))
		_syncing = false
	edited.emit(key, outcome)
	return outcome


# --- fields -----------------------------------------------------------------------------------


func _add_field(property: Dictionary) -> void:
	var key: String = str(property["name"])
	var box := VBoxContainer.new()
	box.name = "Field_%s" % key
	box.theme_type_variation = &"EditorColumn"
	add_child(box)
	var picker_id: String = picker_for(key)
	var caption: String = key.capitalize()
	if not picker_id.is_empty():
		caption += "  · %s" % str((pickers[picker_id] as Dictionary).get("label", picker_id)).to_lower()
	box.add_child(_label(caption, &"EditorLabel"))
	var field: Dictionary = _editor_for(property, picker_id)
	box.add_child(field["root"] as Control)
	var note := _label("", &"EditorLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.visible = false
	box.add_child(note)
	field["message"] = note
	field["property"] = property
	_fields[key] = field


func _editor_for(property: Dictionary, picker_id: String) -> Dictionary:
	var key: String = str(property["name"])
	var type: int = int(property["type"])
	var hint: int = int(property["hint"])
	var hint_string: String = str(property["hint_string"])
	if type == TYPE_BOOL:
		return _check_box(key)
	if hint == PROPERTY_HINT_ENUM and type in [TYPE_INT, TYPE_STRING, TYPE_STRING_NAME]:
		return _enum_option(key, type, hint_string)
	if type == TYPE_INT or type == TYPE_FLOAT:
		return _number(key, type, hint, hint_string)
	if type in [TYPE_STRING, TYPE_STRING_NAME, TYPE_PACKED_STRING_ARRAY]:
		var source := Callable()
		if not picker_id.is_empty():
			source = func() -> PackedStringArray:
				return (pickers[picker_id] as Dictionary)["options"].call(target) as PackedStringArray
		elif hint in [PROPERTY_HINT_FILE, PROPERTY_HINT_GLOBAL_FILE] and type != TYPE_PACKED_STRING_ARRAY:
			source = func() -> PackedStringArray: return _project_files(hint_string)
		if hint == PROPERTY_HINT_MULTILINE_TEXT and not source.is_valid():
			return _text_box(key, type)
		return _line(key, type, source)
	if type in [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I]:
		return _vector(key, type)
	if type == TYPE_COLOR:
		return _color(key)
	return _text_box(key, type)


func _check_box(key: String) -> Dictionary:
	var check := CheckBox.new()
	check.theme_type_variation = &"EditorCheckBox"
	check.text = "On"
	check.toggled.connect(func(_on: bool) -> void: commit_field(key))
	return {
		"root": check, "control": check, "options": Callable(),
		"read": func() -> Variant: return check.button_pressed,
		"write": func(value: Variant) -> void: check.set_pressed_no_signal(bool(value)),
	}


func _enum_option(key: String, type: int, hint_string: String) -> Dictionary:
	var option := OptionButton.new()
	option.theme_type_variation = &"EditorOptionButton"
	var next_value := 0
	for raw: String in hint_string.split(",", false):
		var parts: PackedStringArray = raw.split(":")
		var label: String = parts[0].strip_edges()
		var value: int = int(parts[1]) if parts.size() > 1 else next_value
		next_value = value + 1
		option.add_item(label)
		option.set_item_metadata(option.item_count - 1, value if type == TYPE_INT else label)
	option.item_selected.connect(func(_index: int) -> void: commit_field(key))
	return {
		"root": option, "control": option, "options": Callable(),
		"read": func() -> Variant:
			var chosen: Variant = option.get_item_metadata(option.selected) if option.selected >= 0 else null
			return StringName(str(chosen)) if type == TYPE_STRING_NAME else chosen,
		"write": func(value: Variant) -> void:
			for index: int in option.item_count:
				if str(option.get_item_metadata(index)) == str(value):
					option.select(index)
					return
			option.select(-1),
	}


func _number(key: String, type: int, hint: int, hint_string: String) -> Dictionary:
	var spin := _spin(type == TYPE_INT)
	if hint == PROPERTY_HINT_RANGE:
		var parts: PackedStringArray = hint_string.split(",")
		if parts.size() >= 2:
			spin.min_value = float(parts[0])
			spin.max_value = float(parts[1])
			spin.allow_lesser = parts.has("or_less") or parts.has("or_lesser")
			spin.allow_greater = parts.has("or_greater")
		if parts.size() >= 3 and parts[2].is_valid_float():
			spin.step = float(parts[2])
	spin.value_changed.connect(func(_value: float) -> void: commit_field(key))
	return {
		"root": spin, "control": spin, "options": Callable(),
		"read": func() -> Variant: return int(spin.value) if type == TYPE_INT else spin.value,
		"write": func(value: Variant) -> void: spin.set_value_no_signal(float(value)),
	}


## Single-line text. A source of options adds a picker menu: picking replaces the value (or, for
## a string list, appends to it) and commits; typing re-validates live.
func _line(key: String, type: int, source: Callable) -> Dictionary:
	var line := LineEdit.new()
	line.theme_type_variation = &"EditorLineEdit"
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.text_submitted.connect(func(_text: String) -> void: commit_field(key))
	line.focus_exited.connect(func() -> void:
		if is_instance_valid(target) and _fields.has(key) and _read_line(line.text, type) != target.get(key):
			commit_field(key)
	)
	var root: Control = line
	var menu: MenuButton = null
	if source.is_valid():
		line.text_changed.connect(func(text: String) -> void:
			_show_message(key, _validate(key, _read_line(text, type)))
		)
		var row := HBoxContainer.new()
		row.theme_type_variation = &"EditorRow"
		row.add_child(line)
		menu = MenuButton.new()
		menu.name = "Pick"
		menu.text = "Pick"
		menu.theme_type_variation = &"EditorButton"
		menu.get_popup().theme_type_variation = &"EditorPopupMenu"
		menu.about_to_popup.connect(func() -> void: _fill_menu(menu.get_popup(), source.call() as PackedStringArray, line.text, type))
		menu.get_popup().index_pressed.connect(func(index: int) -> void:
			var picked: String = menu.get_popup().get_item_text(index)
			if type == TYPE_PACKED_STRING_ARRAY:
				var current: PackedStringArray = _read_line(line.text, type)
				if not current.has(picked):
					current.append(picked)
				line.text = ", ".join(current)
			else:
				line.text = picked
			commit_field(key)
		)
		row.add_child(menu)
		root = row
	return {
		"root": root, "control": line, "menu": menu, "options": source,
		"read": func() -> Variant: return _read_line(line.text, type),
		"write": func(value: Variant) -> void:
			line.text = ", ".join(value as PackedStringArray) if type == TYPE_PACKED_STRING_ARRAY else str(value),
	}


## Multiline text, or the literal (`var_to_str`) form of any other value — arrays, dictionaries
## and packed arrays — committed when focus leaves.
func _text_box(key: String, type: int) -> Dictionary:
	var box := TextEdit.new()
	box.theme_type_variation = &"EditorTextEdit"
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.scroll_fit_content_height = true
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var literal: bool = type != TYPE_STRING and type != TYPE_STRING_NAME
	box.focus_exited.connect(func() -> void: commit_field(key))
	return {
		"root": box, "control": box, "options": Callable(),
		"read": func() -> Variant:
			if not literal:
				return StringName(box.text) if type == TYPE_STRING_NAME else box.text
			return _read_literal(box.text, target.get(key)),
		"write": func(value: Variant) -> void:
			box.text = var_to_str(value) if literal else str(value),
	}


func _vector(key: String, type: int) -> Dictionary:
	var rect: bool = type == TYPE_RECT2 or type == TYPE_RECT2I
	var integer: bool = type == TYPE_VECTOR2I or type == TYPE_RECT2I
	var root := VBoxContainer.new()
	root.theme_type_variation = &"EditorColumn"
	var spins: Array[SpinBox] = []
	for row_index: int in (2 if rect else 1):
		var row := HBoxContainer.new()
		row.theme_type_variation = &"EditorRow"
		root.add_child(row)
		for _axis: int in 2:
			var spin := _spin(integer)
			spin.allow_greater = true
			spin.allow_lesser = true
			spin.min_value = -100000
			spin.max_value = 100000
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value_changed.connect(func(_value: float) -> void: commit_field(key))
			row.add_child(spin)
			spins.append(spin)
	return {
		"root": root, "control": spins[0], "spins": spins, "options": Callable(),
		"read": func() -> Variant:
			var a := Vector2(spins[0].value, spins[1].value)
			if not rect:
				return Vector2i(a) if integer else a
			var b := Vector2(spins[2].value, spins[3].value)
			return Rect2i(Vector2i(a), Vector2i(b)) if integer else Rect2(a, b),
		"write": func(value: Variant) -> void:
			var parts: Array[float] = []
			if rect:
				var area := Rect2(value)
				parts = [area.position.x, area.position.y, area.size.x, area.size.y]
			else:
				var point := Vector2(value)
				parts = [point.x, point.y]
			for index: int in spins.size():
				spins[index].set_value_no_signal(parts[index]),
	}


func _color(key: String) -> Dictionary:
	var picker := ColorPickerButton.new()
	picker.theme_type_variation = &"EditorButton"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# One command per closed picker, not one per drag step.
	picker.popup_closed.connect(func() -> void: commit_field(key))
	return {
		"root": picker, "control": picker, "options": Callable(),
		"read": func() -> Variant: return picker.color,
		"write": func(value: Variant) -> void: picker.color = Color(value),
	}


# --- helpers ----------------------------------------------------------------------------------


func _spin(integer: bool) -> SpinBox:
	var spin := SpinBox.new()
	spin.theme_type_variation = &"EditorSpinBox"
	spin.step = 1.0 if integer else 0.001
	spin.min_value = -1000000
	spin.max_value = 1000000
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


func _validate(key: String, value: Variant) -> String:
	var picker_id: String = picker_for(key)
	if picker_id.is_empty() or not is_instance_valid(target):
		return ""
	var check: Variant = (pickers[picker_id] as Dictionary).get("validate")
	if not check is Callable or not (check as Callable).is_valid():
		return ""
	var values: PackedStringArray = value if value is PackedStringArray else PackedStringArray([str(value)])
	for item: String in values:
		var problem: String = str((check as Callable).call(item, target))
		if not problem.is_empty():
			return problem
	return ""


func _show_message(key: String, text: String) -> void:
	if not _fields.has(key):
		return
	var note: Label = _fields[key]["message"]
	note.text = text
	note.visible = not text.is_empty()


static func _read_line(text: String, type: int) -> Variant:
	match type:
		TYPE_STRING_NAME:
			return StringName(text.strip_edges())
		TYPE_PACKED_STRING_ARRAY:
			var items := PackedStringArray()
			for item: String in text.split(",", false):
				if not item.strip_edges().is_empty():
					items.append(item.strip_edges())
			return items
	return text


## Parse literal text against the current value's type; a typed array keeps its element type.
static func _read_literal(text: String, current: Variant) -> Variant:
	var parsed: Variant = str_to_var(text)
	if current is Array and parsed is Array and not (current as Array).is_same_typed(parsed as Array):
		var typed: Array = (current as Array).duplicate()
		typed.clear()
		typed.assign(parsed as Array)
		return typed
	if typeof(parsed) != typeof(current):
		return {"__invalid": "Expected a %s literal." % type_string(typeof(current))}
	return parsed


static func _fill_menu(popup: PopupMenu, choices: PackedStringArray, query: String, type: int) -> void:
	popup.clear()
	var needle: String = "" if type == TYPE_PACKED_STRING_ARRAY else query.strip_edges()
	for choice: String in choices:
		if popup.item_count >= MENU_LIMIT:
			break
		if needle.is_empty() or choice.containsn(needle):
			popup.add_item(choice)
	if popup.item_count == 0:
		for choice: String in choices.slice(0, MENU_LIMIT):
			popup.add_item(choice)


## `res://` files matching an `@export_file` filter such as `*.tscn,*.scn`.
static func _project_files(filter: String) -> PackedStringArray:
	if _file_cache.has(filter):
		return _file_cache[filter]
	var patterns: PackedStringArray = PackedStringArray()
	for pattern: String in filter.split(",", false):
		patterns.append(pattern.strip_edges())
	var found: Array[String] = []
	_scan_files("res://", patterns, found)
	found.sort()
	var result := PackedStringArray(found)
	_file_cache[filter] = result
	return result


static func _scan_files(directory: String, patterns: PackedStringArray, output: Array[String]) -> void:
	for child: String in DirAccess.get_directories_at(directory):
		if not child.begins_with(".") and not (directory == "res://" and FILE_SCAN_SKIP.has(child)):
			_scan_files(directory.path_join(child), patterns, output)
	for file: String in DirAccess.get_files_at(directory):
		for pattern: String in patterns:
			if pattern.is_empty() or file.match(pattern):
				output.append(directory.path_join(file))
				break


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
