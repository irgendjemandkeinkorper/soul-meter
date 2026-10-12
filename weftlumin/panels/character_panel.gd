class_name WeftluminCharacterPanel
extends SoulMeterToolPanel
## Characters bottom tab (E5.1 / #347, architecture §4.7): one form for every declared character
## kind — npc, archetype, recruit — built from the kind's contract, not from hard-coded fields.
## The `stats` block is rendered from its schema's declared field order and edited key by key;
## the panel never reads meaning into a stat. Portrait and sprite fields use the semantic
## pickers (`pickers.gd`, previews through `ChargenArtResolver` / `UnitArt`).
##
## Validation, drafts, the vault_id rules and the bake preview are the model's
## (`models/character_roster.gd`); saving writes a draft under `user://`, never `res://`.

const MODEL_SCRIPT := preload("res://weftlumin/panels/models/character_roster.gd")
const PICKERS_SCRIPT := preload("res://weftlumin/panels/pickers.gd")
const NONE_LABEL := "(none)"
const PREVIEW_SIZE := Vector2(72, 72)
const STAT_FIELD_SIZE := Vector2(88, 0)

var character_option: OptionButton = null
var identity_label: Label = null
var fields_box: VBoxContainer = null
var stats_box: VBoxContainer = null
var stat_schema_option: OptionButton = null
var portrait_option: OptionButton = null
var portrait_preview: TextureRect = null
var sprite_option: OptionButton = null
var sprite_preview: TextureRect = null
var create_kind_option: OptionButton = null
var create_id_edit: LineEdit = null
var create_name_edit: LineEdit = null
var create_vault_edit: LineEdit = null
var notes_label: Label = null
var errors_label: Label = null
var report_box: TextEdit = null

var _pickers: RefCounted = PICKERS_SCRIPT.new()
var _character_id: String = ""
## field → control (LineEdit / CheckBox / TextEdit / OptionButton), `[x, y]` LineEdits for a
## number pair, or {sub-field → control} for a block.
var _controls: Dictionary = {}
var _stat_edits: Dictionary = {}


func _init() -> void:
	title = "Characters"
	needs_sandbox = false
	hotkey_hint = ""


func _model_script() -> Script:
	return MODEL_SCRIPT


func _build(content: VBoxContainer) -> void:
	var picker := _row()
	content.add_child(picker)
	picker.add_child(_label("Character"))
	character_option = _option("Character")
	character_option.item_selected.connect(func(index: int) -> void:
		select_character(String(character_option.get_item_metadata(index)))
	)
	picker.add_child(character_option)
	picker.add_child(_button("Save draft", "SaveDraft", save))
	picker.add_child(_button("Discard draft", "DiscardDraft", discard))
	picker.add_child(_button("Bake preview", "BakePreview", preview_bake))
	picker.add_child(_button("Reload", "Reload", reload))

	var create_row := _row()
	content.add_child(create_row)
	create_row.add_child(_label("New"))
	create_kind_option = _option("CreateKind")
	for kind_name: String in _kind().character_kinds():
		create_kind_option.add_item(kind_name)
		create_kind_option.set_item_metadata(create_kind_option.item_count - 1, kind_name)
	create_row.add_child(create_kind_option)
	create_id_edit = _line("CreateId", "id")
	create_row.add_child(create_id_edit)
	create_name_edit = _line("CreateName", "display name")
	create_row.add_child(create_name_edit)
	create_vault_edit = _line("CreateVaultId", "vault_id (lore-vault character)")
	create_row.add_child(create_vault_edit)
	create_row.add_child(_button("Create draft", "Create", create))

	identity_label = _label("", &"EditorLabel", true)
	identity_label.name = "Identity"
	content.add_child(identity_label)
	# Refusals and notes sit under the identity line: the form below can be long.
	errors_label = _label("", &"DangerLabel", true)
	errors_label.name = "Errors"
	errors_label.visible = false
	content.add_child(errors_label)
	notes_label = _label("", &"EditorLabel", true)
	notes_label.name = "Notes"
	content.add_child(notes_label)

	var art := _row()
	art.name = "Art"
	content.add_child(art)
	art.add_child(_label("Portrait"))
	portrait_option = _option("Portrait")
	portrait_option.item_selected.connect(func(_index: int) -> void: _show_portrait())
	art.add_child(portrait_option)
	portrait_preview = _preview("PortraitPreview")
	art.add_child(portrait_preview)
	art.add_child(_label("Sprite"))
	sprite_option = _option("Sprite")
	sprite_option.item_selected.connect(func(_index: int) -> void: _show_sprite())
	art.add_child(sprite_option)
	sprite_preview = _preview("SpritePreview")
	art.add_child(sprite_preview)

	fields_box = VBoxContainer.new()
	fields_box.name = "Fields"
	fields_box.theme_type_variation = &"EditorColumn"
	content.add_child(fields_box)

	stats_box = VBoxContainer.new()
	stats_box.name = "Stats"
	stats_box.theme_type_variation = &"EditorColumn"
	content.add_child(stats_box)

	report_box = _text_box("BakeReport", false)
	report_box.visible = false
	content.add_child(report_box)
	_populate_characters()


func refresh(_payload: Dictionary) -> void:
	if character_option == null:
		return
	if _character_id.is_empty():
		_populate_characters()


## Re-reads canon and drafts, keeping the selection when it still exists.
func reload() -> void:
	var errors: Array[Dictionary] = model.call("reload")
	_populate_characters()
	_show_errors(errors)


func character_ids(kind_name: String = "") -> Array[String]:
	return model.call("character_ids", kind_name)


func selected_character() -> String:
	return _character_id


func select_character(character_id: String) -> void:
	_character_id = character_id
	for index: int in character_option.item_count:
		if String(character_option.get_item_metadata(index)) == character_id:
			character_option.select(index)
	var row: Dictionary = model.call("document", character_id)
	if row.is_empty():
		return
	var source: String = "draft" if bool(model.call("has_draft", character_id)) else "canon"
	if bool(model.call("is_new", character_id)):
		source = "new draft"
	var vault_id: String = String(row.get("vault_id", ""))
	identity_label.text = "%s · %s · vault %s · %s" % [
		character_id, row["kind"], vault_id if not vault_id.is_empty() else "none", source,
	]
	_fill_art(row)
	_build_fields(row)
	_build_stats(row)
	_show_notes()
	_show_errors([])


## Sets one form control by its document field name (the test and CLI seam). A block field
## takes "block.field"; `stats` takes the whole block.
func set_field(field: String, value: Variant) -> void:
	if field == "portrait_path":
		_select_or_add(portrait_option, String(value))
		_show_portrait()
		return
	if field == "sprite_unit_id":
		_select_or_add(sprite_option, String(value))
		_show_sprite()
		return
	if field == "stats":
		var row: Dictionary = model.call("document", _character_id)
		row["stats"] = value
		_build_stats(row)
		return
	var path: PackedStringArray = field.split(".", false, 1)
	var control: Variant = _controls.get(path[0])
	if path.size() == 2 and control is Dictionary:
		control = (control as Dictionary).get(path[1])
	_set_control(control, value)


## Sets one stat key's text (the seam the stats rows share).
func set_stat(key: String, text: String) -> void:
	if not _stat_edits.has(key):
		var row: Dictionary = model.call("document", _character_id)
		var stats: Dictionary = (edits().get("stats", row.get("stats", {})) as Dictionary).duplicate()
		stats[key] = text
		row["stats"] = stats
		_build_stats(row)
	if _stat_edits.has(key):
		(_stat_edits[key] as LineEdit).text = text


## The fields whose form value differs from the current document, as document edits.
## Unparseable structured text is returned as a String and refused by the kind.
func edits() -> Dictionary:
	var row: Dictionary = model.call("document", _character_id)
	var result: Dictionary = {}
	for field: String in _controls:
		var value: Variant = _control_value(_controls[field], _shape(row, field), field)
		if not _matches(row, field, value):
			result[field] = value
	for pair: Array in [["portrait_path", portrait_option], ["sprite_unit_id", sprite_option]]:
		var picked: String = String(_selected_metadata(pair[1]) if _selected_metadata(pair[1]) != null else "")
		if not _matches(row, pair[0], picked):
			result[pair[0]] = picked
	if stat_schema_option != null and _selected_metadata(stat_schema_option) != null:
		var stats: Dictionary = {"schema": String(_selected_metadata(stat_schema_option))}
		for key: String in _stat_edits:
			var text: String = (_stat_edits[key] as LineEdit).text.strip_edges()
			if not text.is_empty():
				stats[key] = _parse_scalar(text)
		if not _matches(row, "stats", stats):
			result["stats"] = stats
	return result


## Validates and saves the form as a draft. Returns true when saved.
func save() -> bool:
	if _character_id.is_empty():
		return false
	var errors: Array[Dictionary] = model.call("save_draft", _character_id, edits())
	if errors.is_empty():
		select_character(_character_id)
		_populate_characters()
		_set_status("Draft saved to %s/%s.json." % [model.call("drafts_root"), _character_id])
		return true
	_show_errors(errors)
	return false


## Creates a new character draft from the "New" row. Returns true when created.
func create() -> bool:
	var kind_name: String = String(_selected_metadata(create_kind_option))
	var character_id: String = create_id_edit.text.strip_edges()
	var errors: Array[Dictionary] = model.call(
		"create", kind_name, character_id, create_name_edit.text.strip_edges(),
		create_vault_edit.text.strip_edges(),
	)
	if not errors.is_empty():
		_show_errors(errors)
		return false
	_character_id = character_id
	_populate_characters()
	_set_status("Created %s %s as a draft." % [kind_name, character_id])
	return true


func set_create(kind_name: String, character_id: String, display_name: String, vault_id: String) -> void:
	_select_metadata(create_kind_option, kind_name)
	create_id_edit.text = character_id
	create_name_edit.text = display_name
	create_vault_edit.text = vault_id


func discard() -> void:
	if _character_id.is_empty():
		return
	var was_new: bool = bool(model.call("is_new", _character_id))
	if bool(model.call("discard_draft", _character_id)):
		_set_status("Draft discarded; showing canon." if not was_new else "New character discarded.")
	if was_new:
		_character_id = ""
		_populate_characters()
		return
	select_character(_character_id)


## Shows the report-only bake for canon plus every saved draft.
func preview_bake() -> Dictionary:
	var report: Dictionary = model.call("bake_preview")
	var lines: Array[String] = []
	for entry: Dictionary in report.get("planned", []):
		if entry["action"] != "unchanged":
			lines.append("%s  %s" % [entry["action"], entry["path"]])
	for path: String in report.get("regenerated", []):
		lines.append("regenerate  %s" % path)
	for orphan: String in report.get("orphans", []):
		lines.append("orphan  %s" % orphan)
	if lines.is_empty() and (report.get("errors", []) as Array).is_empty():
		lines.append("No change: canon and drafts match the committed documents.")
	lines.push_front(String(report.get("summary", "")))
	report_box.text = "\n".join(lines).strip_edges()
	report_box.visible = true
	_show_errors(report.get("errors", []))
	return report


func errors_text() -> String:
	return errors_label.text if errors_label.visible else ""


## The rendered stat rows' keys, in display order.
func stat_keys() -> Array[String]:
	var keys: Array[String] = []
	keys.assign(_stat_edits.keys())
	return keys


func field_names() -> Array[String]:
	var names: Array[String] = []
	names.assign(_controls.keys())
	return names


# --- form construction ---------------------------------------------------------------------


func _kind() -> WeftluminCharactersKind:
	return model.call("kind") as WeftluminCharactersKind


func _build_fields(row: Dictionary) -> void:
	_clear(fields_box)
	_controls.clear()
	var kind: WeftluminCharactersKind = _kind()
	var kind_name: String = row["kind"]
	var shapes: Dictionary = kind.field_shapes(kind_name)
	var display := _line("DisplayName", "")
	display.text = String(row["display_name"])
	_captioned_row(fields_box, "display_name", display)
	_controls["display_name"] = display
	for field: String in shapes:
		var shape: String = shapes[field]
		if WeftluminCharactersKind.PICKER_FIELDS.has(field) or shape == WeftluminCharactersKind.STATS:
			continue
		if not row.has(field) and not kind.is_required(kind_name, field) and shape != WeftluminCharactersKind.STRING:
			continue
		var value: Variant = row.get(field)
		var caption: String = field if kind.is_required(kind_name, field) else "%s (optional)" % field
		match shape:
			WeftluminCharactersKind.BLOCK:
				fields_box.add_child(_label(caption, &"EditorHeading"))
				var block: Dictionary = {}
				var block_value: Dictionary = value if value is Dictionary else {}
				var block_shapes: Dictionary = kind.block_shapes(kind_name, field)
				for key: String in block_shapes:
					var control: Control = _control_for(block_shapes[key], "%s_%s" % [field, key], block_value.get(key))
					_captioned_row(fields_box, "  " + key, control)
					block[key] = control
				_controls[field] = block
			WeftluminCharactersKind.NUMBER_PAIR:
				var pair: Array = value if value is Array else [0, 0]
				var x := _line("%s_x" % field, "x")
				var y := _line("%s_y" % field, "y")
				x.text = _number_text(pair[0])
				y.text = _number_text(pair[1])
				var row_box := _row()
				row_box.add_child(_label(caption))
				row_box.add_child(x)
				row_box.add_child(y)
				fields_box.add_child(row_box)
				_controls[field] = [x, y]
			_:
				var control: Control = _control_for(shape, field, value)
				if field == "vault_id":
					# Required on create, checked against the vault, never renamed: an id once
					# set is shown read-only; an empty one may be linked.
					(control as LineEdit).editable = String(value if value != null else "").is_empty()
				_captioned_row(fields_box, caption, control)
				_controls[field] = control


func _build_stats(row: Dictionary) -> void:
	_clear(stats_box)
	_stat_edits.clear()
	stat_schema_option = null
	var kind: WeftluminCharactersKind = _kind()
	if not kind.field_shapes(String(row["kind"])).has("stats"):
		return
	var stats: Dictionary = row.get("stats", {}) if row.get("stats") is Dictionary else {}
	var schema_name: String = String(stats.get("schema", ""))
	var header := _row()
	stats_box.add_child(header)
	header.add_child(_label("Stats", &"EditorHeading"))
	stat_schema_option = _option("StatSchema")
	for declared: String in kind.stat_schemas():
		stat_schema_option.add_item(kind.stat_schema_label(declared))
		stat_schema_option.set_item_metadata(stat_schema_option.item_count - 1, declared)
	_select_metadata(stat_schema_option, schema_name)
	stat_schema_option.item_selected.connect(func(index: int) -> void:
		var current: Dictionary = edits().get("stats", stats).duplicate()
		current["schema"] = String(stat_schema_option.get_item_metadata(index))
		var next: Dictionary = row.duplicate()
		next["stats"] = current
		_build_stats(next)
	)
	header.add_child(stat_schema_option)
	header.add_child(_label("opaque — validated by the schema, not the editor"))
	if stats.is_empty() and not row.has("stats"):
		stat_schema_option.select(-1)
	var columns := GridContainer.new()
	columns.name = "StatRows"
	columns.columns = 8
	stats_box.add_child(columns)
	var display: Dictionary = stats.duplicate()
	display["schema"] = schema_name
	for key: String in kind.stat_fields(display):
		columns.add_child(_label(kind.stat_field_label(schema_name, key)))
		var edit := _line("Stat_%s" % key, "")
		edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		edit.custom_minimum_size = STAT_FIELD_SIZE
		edit.text = _number_text(stats.get(key)) if stats.has(key) else ""
		columns.add_child(edit)
		_stat_edits[key] = edit


func _control_for(shape: String, node_name: String, value: Variant) -> Control:
	match shape:
		WeftluminCharactersKind.BOOLEAN:
			var check := CheckBox.new()
			check.name = node_name.to_pascal_case()
			check.theme_type_variation = &"EditorCheckBox"
			check.button_pressed = bool(value) if value is bool else false
			return check
		WeftluminCharactersKind.ROUTINE, WeftluminCharactersKind.ANATOMY:
			var box := _text_box(node_name.to_pascal_case(), true)
			box.text = JSON.stringify(WeftluminCharactersKind._integral(value if value != null else {}), "  ", false)
			return box
		WeftluminCharactersKind.NUMBER:
			var number := _line(node_name.to_pascal_case(), "0")
			number.text = _number_text(value)
			return number
	var line := _line(node_name.to_pascal_case(), "")
	line.text = String(value) if value is String else ""
	return line


func _fill_art(row: Dictionary) -> void:
	portrait_option.clear()
	portrait_option.add_item(NONE_LABEL)
	portrait_option.set_item_metadata(0, "")
	var portraits: Dictionary = _pickers.call("table")["portraits"]
	for path: String in (portraits["options"] as Callable).call(null):
		portrait_option.add_item(path.get_file())
		portrait_option.set_item_metadata(portrait_option.item_count - 1, path)
	_select_or_add(portrait_option, String(row.get("portrait_path", "")))
	sprite_option.clear()
	sprite_option.add_item(NONE_LABEL)
	sprite_option.set_item_metadata(0, "")
	var sprites: Dictionary = _pickers.call("table")["sprites"]
	for unit_id: String in (sprites["options"] as Callable).call(null):
		sprite_option.add_item(unit_id)
		sprite_option.set_item_metadata(sprite_option.item_count - 1, unit_id)
	_select_or_add(sprite_option, String(row.get("sprite_unit_id", "")))
	_show_portrait()
	_show_sprite()


## The portrait plate through `ChargenArtResolver`; the sprite through `UnitArt`. The sprite
## preview falls back to the character id's own unit, which is what the seeders resolve today.
func _show_portrait() -> void:
	portrait_preview.texture = PICKERS_SCRIPT.portrait_texture(String(_selected_metadata(portrait_option)))


func _show_sprite() -> void:
	var unit_id: String = String(_selected_metadata(sprite_option))
	if unit_id.is_empty():
		unit_id = _character_id
	sprite_preview.texture = PICKERS_SCRIPT.sprite_texture(unit_id)


# --- values --------------------------------------------------------------------------------


func _shape(row: Dictionary, field: String) -> String:
	if field == "display_name":
		return WeftluminCharactersKind.STRING
	return String(_kind().field_shapes(String(row["kind"])).get(field, WeftluminCharactersKind.STRING))


func _control_value(control: Variant, shape: String, field: String = "") -> Variant:
	if control is Array:
		return [_parse_number((control[0] as LineEdit).text), _parse_number((control[1] as LineEdit).text)]
	if control is Dictionary:
		var block: Dictionary = {}
		var row: Dictionary = model.call("document", _character_id)
		var kind_name: String = String(row["kind"])
		for key: String in control:
			var inner_shape: String = String(_kind().block_shapes(kind_name, field).get(key, WeftluminCharactersKind.STRING))
			block[key] = _control_value(control[key], inner_shape)
		return block
	if control is CheckBox:
		return (control as CheckBox).button_pressed
	if control is TextEdit:
		var json := JSON.new()
		if json.parse((control as TextEdit).text) == OK:
			return json.data
		return (control as TextEdit).text
	if control is LineEdit:
		var text: String = (control as LineEdit).text
		return _parse_number(text) if shape == WeftluminCharactersKind.NUMBER else text
	return null


func _set_control(control: Variant, value: Variant) -> void:
	if control is CheckBox:
		(control as CheckBox).button_pressed = bool(value)
	elif control is TextEdit:
		(control as TextEdit).text = value if value is String else JSON.stringify(value, "  ", false)
	elif control is LineEdit:
		(control as LineEdit).text = value if value is String else _number_text(value)
	elif control is Array and value is Array:
		(control[0] as LineEdit).text = _number_text(value[0])
		(control[1] as LineEdit).text = _number_text(value[1])


## An absent optional field matches an empty form value, so opening and saving a document
## never adds fields the author did not touch.
func _matches(row: Dictionary, field: String, value: Variant) -> bool:
	if not row.has(field):
		return value == null or (value is String and String(value).is_empty())
	var before: Variant = WeftluminCharactersKind._integral(row[field])
	var after: Variant = WeftluminCharactersKind._integral(value)
	return typeof(before) == typeof(after) and before == after


static func _parse_number(text: String) -> Variant:
	var stripped: String = text.strip_edges()
	if stripped.is_valid_int():
		return stripped.to_int()
	if stripped.is_valid_float():
		return stripped.to_float()
	return stripped


## A stat value: a number when it reads as one, otherwise the text verbatim (opaque).
static func _parse_scalar(text: String) -> Variant:
	if text.is_valid_int() or text.is_valid_float():
		return _parse_number(text)
	if text == "true" or text == "false":
		return text == "true"
	return text


static func _number_text(value: Variant) -> String:
	var integral: Variant = WeftluminCharactersKind._integral(value)
	return str(integral) if integral != null else ""


# --- presentation --------------------------------------------------------------------------


func _populate_characters() -> void:
	character_option.clear()
	var ids: Array[String] = character_ids()
	for character_id: String in ids:
		var row: Dictionary = model.call("document", character_id)
		var marker: String = " •" if bool(model.call("has_draft", character_id)) else ""
		character_option.add_item("%s (%s)%s" % [character_id, row["kind"], marker])
		character_option.set_item_metadata(character_option.item_count - 1, character_id)
	if ids.is_empty():
		_character_id = ""
		_show_errors(model.call("load_errors"))
		return
	select_character(_character_id if ids.has(_character_id) else ids[0])


func _show_notes() -> void:
	var notes: Array[String] = model.call("notes", _character_id)
	notes_label.text = "\n".join(notes)
	notes_label.visible = not notes.is_empty()


func _show_errors(errors: Array) -> void:
	var lines: Array[String] = []
	for error: Dictionary in errors:
		lines.append("%s: %s" % [error.get("field", ""), error.get("message", "")])
	errors_label.text = "\n".join(lines)
	errors_label.visible = not lines.is_empty()


static func _clear(box: Container) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.free()


static func _select_metadata(option: OptionButton, value: String) -> void:
	for index: int in option.item_count:
		if String(option.get_item_metadata(index)) == value:
			option.select(index)
			return


## Selects `value`, adding it first when the picker does not list it (an authored path the
## scan no longer finds stays visible rather than silently becoming "none").
static func _select_or_add(option: OptionButton, value: String) -> void:
	for index: int in option.item_count:
		if String(option.get_item_metadata(index)) == value:
			option.select(index)
			return
	option.add_item(value.get_file() if value.begins_with("res://") else value)
	option.set_item_metadata(option.item_count - 1, value)
	option.select(option.item_count - 1)


static func _captioned_row(box: Container, caption: String, control: Control) -> void:
	var row := _row()
	var label := _label(caption)
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	box.add_child(row)


static func _preview(node_name: String) -> TextureRect:
	var preview := TextureRect.new()
	preview.name = node_name
	preview.custom_minimum_size = PREVIEW_SIZE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return preview


static func _line(node_name: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.name = node_name
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return edit
