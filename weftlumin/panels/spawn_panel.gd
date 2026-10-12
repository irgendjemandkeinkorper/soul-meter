class_name WeftluminSpawnPanel
extends SoulMeterToolPanel
## Spawns bottom tab (E4.2 / #346, architecture §4.10): edits a spawn table's slots, places each
## slot's `SpawnSlot<PascalCase>` anchor marker in the live scene, and shows every slot's live
## state from `SaveGame.spawn_director`. Validation, drafts and live state are the model's
## (`models/spawn_tables_editor.gd`); this panel only lays them out.
##
## Placing an anchor arms the scene model's `spawn_slot` placeable (a `Marker2D`, adapter
## `PLACEABLES`) named after the slot; the next viewport click drops it at the nearest open cell,
## as one `add_node` command in the scene's own history. `respawn now` / `clear slot` are
## `[debug]` verbs on the Console tab.

const MODEL_SCRIPT := preload("res://weftlumin/panels/models/spawn_tables_editor.gd")
const SPAWN_SLOT_PLACEABLE := &"spawn_slot"

var table_option: OptionButton = null
var identity_label: Label = null
var slot_option: OptionButton = null
var new_slot_edit: LineEdit = null
var max_alive_spin: SpinBox = null
var anchor_edit: LineEdit = null
var respawn_spin: SpinBox = null
var pack_min_spin: SpinBox = null
var pack_max_spin: SpinBox = null
var entries_box: TextEdit = null
var live_label: Label = null
var notes_label: Label = null
var errors_label: Label = null

var _table_id: String = ""
var _slot_index: int = -1
## The table being edited, with the form's uncommitted slot folded in by `_commit_slot()`.
var _working: Dictionary = {}
var _scene_root: Node = null
var _session: WeftluminSceneModel = null


func _init() -> void:
	title = "Spawns"
	needs_sandbox = false
	hotkey_hint = ""


func _model_script() -> Script:
	return MODEL_SCRIPT


func _build(content: VBoxContainer) -> void:
	var picker := _row()
	content.add_child(picker)
	picker.add_child(_label("Table"))
	table_option = _option("Table")
	table_option.item_selected.connect(func(index: int) -> void:
		select_table(String(table_option.get_item_metadata(index)))
	)
	picker.add_child(table_option)
	picker.add_child(_button("Save draft", "SaveDraft", save))
	picker.add_child(_button("Discard draft", "DiscardDraft", discard))
	picker.add_child(_button("Reload", "Reload", reload))

	identity_label = _label("", &"EditorLabel", true)
	identity_label.name = "Identity"
	content.add_child(identity_label)

	var slots := _row()
	content.add_child(slots)
	slots.add_child(_label("Slot"))
	slot_option = _option("Slot")
	slot_option.item_selected.connect(func(index: int) -> void: select_slot(index))
	slots.add_child(slot_option)
	new_slot_edit = _line("NewSlotId", "new slot id")
	slots.add_child(new_slot_edit)
	slots.add_child(_button("Add slot", "AddSlot", func() -> void: add_slot(new_slot_edit.text)))
	slots.add_child(_button("Remove slot", "RemoveSlot", remove_slot))
	max_alive_spin = _spin("MaxAlive", 0.0, 99.0)
	slots.add_child(_label("Max alive (0 = policy default)"))
	slots.add_child(max_alive_spin)

	var fields := _row()
	content.add_child(fields)
	fields.add_child(_label("Anchor"))
	anchor_edit = _line("Anchor", "SpawnSlot…")
	fields.add_child(anchor_edit)
	fields.add_child(_button("Place anchor", "PlaceAnchor", place_anchor))
	respawn_spin = _spin("RespawnDays", 1.0, 99.0)
	fields.add_child(_label("Respawn days"))
	fields.add_child(respawn_spin)
	pack_min_spin = _spin("PackMin", 1.0, 99.0)
	fields.add_child(_label("Pack"))
	fields.add_child(pack_min_spin)
	pack_max_spin = _spin("PackMax", 1.0, 99.0)
	fields.add_child(_label("to"))
	fields.add_child(pack_max_spin)

	content.add_child(_label("Entries — one “archetype_id = weight” or “empty = weight” per line", &"EditorLabel", true))
	entries_box = _text_box("Entries", true)
	content.add_child(entries_box)

	content.add_child(_label("Live slot state", &"EditorLabel", true))
	live_label = _label("", &"EditorLabel", true)
	live_label.name = "LiveState"
	content.add_child(live_label)
	notes_label = _label("", &"EditorLabel", true)
	notes_label.name = "Notes"
	content.add_child(notes_label)
	errors_label = _label("", &"DangerLabel", true)
	errors_label.name = "Errors"
	errors_label.visible = false
	content.add_child(errors_label)
	_populate_tables()


func refresh(payload: Dictionary) -> void:
	if table_option == null:
		return
	if payload.has("scene_root"):
		_set_scene_root(payload["scene_root"] as Node)
	if _table_id.is_empty():
		_populate_tables()
	else:
		refresh_live()


func _set_scene_root(root: Node) -> void:
	if _session != null and _session.scene_changed.is_connected(refresh_live):
		_session.scene_changed.disconnect(refresh_live)
	_scene_root = root if is_instance_valid(root) else null
	_session = null
	model.call("set_scene_root", _scene_root)
	if _scene_root != null and _host != null:
		_session = WeftluminSceneModel.session_for(_scene_root)
		_session.scene_changed.connect(refresh_live)


func _exit_tree() -> void:
	if _session != null and _session.scene_changed.is_connected(refresh_live):
		_session.scene_changed.disconnect(refresh_live)
	_session = null


## Re-reads canon and drafts, keeping the selection when it still exists.
func reload() -> void:
	var errors: Array[Dictionary] = model.call("reload")
	_populate_tables()
	_show_errors(errors)


func table_ids() -> Array[String]:
	return model.call("table_ids")


func selected_table() -> String:
	return _table_id


func select_table(table_id: String) -> void:
	_table_id = table_id
	for index: int in table_option.item_count:
		if String(table_option.get_item_metadata(index)) == table_id:
			table_option.select(index)
	_working = model.call("document", table_id)
	if _working.is_empty():
		return
	var source: String = "draft" if bool(model.call("has_draft", table_id)) else "canon"
	identity_label.text = "%s · %s · %s · %s" % [table_id, _working["scene_path"], model.call("canon_path", table_id), source]
	max_alive_spin.value = float((_working["caps"] as Dictionary).get("max_alive", 0))
	_slot_index = -1
	_populate_slots(0)
	_show_errors([])


func select_slot(index: int) -> void:
	var error: String = _commit_slot()
	if not error.is_empty():
		# Keep the slot whose entries do not parse, rather than dropping the author's text.
		slot_option.select(_slot_index)
		_show_errors([{"field": "entries", "message": error}])
		return
	var slots: Array = _working.get("slots", [])
	if index < 0 or index >= slots.size():
		return
	_slot_index = index
	slot_option.select(index)
	var slot: Dictionary = slots[index]
	anchor_edit.text = String(slot.get("anchor", ""))
	respawn_spin.value = float(slot.get("respawn_days", 1))
	var pack: Dictionary = slot.get("pack_size", {"min": 1, "max": 1})
	pack_min_spin.value = float(pack.get("min", 1))
	pack_max_spin.value = float(pack.get("max", 1))
	entries_box.text = format_entries(slot.get("entries", []))


func selected_slot_id() -> String:
	var slots: Array = _working.get("slots", [])
	return String((slots[_slot_index] as Dictionary)["id"]) if _slot_index >= 0 and _slot_index < slots.size() else ""


## Sets one form control by field name (the test and CLI seam): `anchor`, `respawn_days`,
## `pack_min`, `pack_max`, `entries` (text or array) or `max_alive`.
func set_field(field: String, value: Variant) -> void:
	match field:
		"anchor":
			anchor_edit.text = String(value)
		"respawn_days":
			respawn_spin.value = float(value)
		"pack_min":
			pack_min_spin.value = float(value)
		"pack_max":
			pack_max_spin.value = float(value)
		"entries":
			entries_box.text = value if value is String else format_entries(value)
		"max_alive":
			max_alive_spin.value = float(value)


## Appends a slot with `slot_id`, its anchor `SpawnSlot<PascalCase>` and a placeholder entry list
## the author must fill (an empty slot fails validation until it has a creature entry).
func add_slot(slot_id: String) -> bool:
	var trimmed: String = slot_id.strip_edges()
	if _table_id.is_empty() or trimmed.is_empty():
		return false
	_commit_slot()
	var slots: Array = _working["slots"]
	for slot: Dictionary in slots:
		if String(slot["id"]) == trimmed:
			_show_errors([{"field": "slots", "message": "Slot '%s' already exists." % trimmed}])
			return false
	slots.append({
		"id": trimmed, "anchor": WeftluminSpawnTablesKind.anchor_name_for(trimmed), "respawn_days": 1,
		"entries": [], "pack_size": {"min": 1, "max": 1},
	})
	new_slot_edit.text = ""
	_slot_index = -1
	_populate_slots(slots.size() - 1)
	return true


func remove_slot() -> void:
	var slots: Array = _working.get("slots", [])
	if _slot_index < 0 or _slot_index >= slots.size():
		return
	slots.remove_at(_slot_index)
	_slot_index = -1
	_populate_slots(0)


## The form as a whole table document, or an error string naming a malformed entry line.
func edited_table() -> Variant:
	var error: String = _commit_slot()
	if not error.is_empty():
		return error
	var table: Dictionary = _working.duplicate(true)
	var caps: Dictionary = {}
	if int(max_alive_spin.value) > 0:
		caps["max_alive"] = int(max_alive_spin.value)
	table["caps"] = caps
	return table


## Validates and saves the form as a draft. Returns true when saved.
func save() -> bool:
	if _table_id.is_empty():
		return false
	var table: Variant = edited_table()
	if not table is Dictionary:
		_show_errors([{"field": "entries", "message": String(table)}])
		return false
	var errors: Array[Dictionary] = model.call("save_draft", _table_id, table)
	if errors.is_empty():
		var keep: int = _slot_index
		select_table(_table_id)
		_populate_slots(maxi(keep, 0))
		_set_status("Draft saved to %s/%s.json." % [model.call("drafts_root"), _table_id])
		return true
	_show_errors(errors)
	return false


func discard() -> void:
	if _table_id.is_empty():
		return
	if bool(model.call("discard_draft", _table_id)):
		_set_status("Draft discarded; showing canon.")
	select_table(_table_id)


## Arms the scene model to place the selected slot's anchor marker; the next viewport click
## places it. Refused when the table targets another scene or the anchor already exists.
func place_anchor() -> bool:
	_commit_slot()
	var anchor: String = anchor_edit.text.strip_edges()
	if anchor.is_empty() or anchor.validate_node_name() != anchor:
		_set_status("Give the slot an anchor name first.")
		return false
	if _session == null or _scene_root == null or _scene_root.scene_file_path != String(_working.get("scene_path", "")):
		_set_status("Load %s to place its anchors." % _working.get("scene_path", "the table's scene"))
		return false
	if _scene_root.find_child(anchor, true, false) != null:
		_set_status("%s is already in the scene." % anchor)
		return false
	_session.choose_placeable(WeftluminPlaceable.make(
		SPAWN_SLOT_PLACEABLE, "Spawn slot", "Markers", null, &"Marker2D", anchor
	))
	_set_status("Click in the viewport to place %s." % anchor)
	return true


## Re-reads live slot state and notes.
func refresh_live() -> void:
	if live_label == null or _table_id.is_empty():
		return
	if _session != null and _session.placeable == null and status_text().begins_with("Click in the viewport"):
		_set_status("")
	model.call("set_scene_root", _scene_root)
	var lines: Array[String] = []
	for row: Dictionary in model.call("live_slots", _table_id):
		lines.append(String(row["text"]))
	live_label.text = "\n".join(lines)
	var notes: Array[String] = model.call("notes", _table_id)
	notes_label.text = "\n".join(notes)
	notes_label.visible = not notes.is_empty()


func live_text() -> String:
	return live_label.text


func errors_text() -> String:
	return errors_label.text if errors_label.visible else ""


static func format_entries(entries: Array) -> String:
	var lines: Array[String] = []
	for entry: Dictionary in entries:
		var key: String = "empty" if entry.has("empty") else String(entry.get("archetype_id", ""))
		lines.append("%s = %s" % [key, entry.get("weight", 0)])
	return "\n".join(lines)


## `archetype_id = weight` / `empty = weight` lines → entries, or an error string naming the bad
## line. A weight that is not an integer is passed through for the kind to refuse with its field.
static func parse_entries(text: String) -> Variant:
	var entries: Array = []
	var number: int = 0
	for line: String in text.split("\n"):
		number += 1
		if line.strip_edges().is_empty():
			continue
		var parts: PackedStringArray = line.split("=", true, 1)
		if parts.size() != 2 or parts[0].strip_edges().is_empty():
			return "Entries line %d needs “archetype_id = weight” or “empty = weight”." % number
		var raw_weight: String = parts[1].strip_edges()
		var weight: Variant = raw_weight.to_int() if raw_weight.is_valid_int() else raw_weight
		var key: String = parts[0].strip_edges()
		if key == "empty":
			entries.append({"empty": true, "weight": weight})
		else:
			entries.append({"archetype_id": key, "weight": weight})
	return entries


## Folds the form into `_working`'s selected slot. Returns an error string, or "".
func _commit_slot() -> String:
	var slots: Array = _working.get("slots", [])
	if _slot_index < 0 or _slot_index >= slots.size():
		return ""
	var entries: Variant = parse_entries(entries_box.text)
	if not entries is Array:
		return String(entries)
	var slot: Dictionary = slots[_slot_index]
	slot["anchor"] = anchor_edit.text.strip_edges()
	slot["respawn_days"] = int(respawn_spin.value)
	slot["pack_size"] = {"min": int(pack_min_spin.value), "max": int(pack_max_spin.value)}
	slot["entries"] = entries
	return ""


func _populate_tables() -> void:
	table_option.clear()
	var ids: Array[String] = table_ids()
	for table_id: String in ids:
		var marker: String = " •" if bool(model.call("has_draft", table_id)) else ""
		table_option.add_item(table_id + marker)
		table_option.set_item_metadata(table_option.item_count - 1, table_id)
	if ids.is_empty():
		_table_id = ""
		_working = {}
		_show_errors(model.call("load_errors"))
		return
	select_table(_table_id if ids.has(_table_id) else ids[0])


func _populate_slots(select_index: int) -> void:
	slot_option.clear()
	var slots: Array = _working.get("slots", [])
	for slot: Dictionary in slots:
		slot_option.add_item(String(slot["id"]))
	if not slots.is_empty():
		select_slot(clampi(select_index, 0, slots.size() - 1))
	else:
		anchor_edit.text = ""
		entries_box.text = ""
	refresh_live()


func _show_errors(errors: Array) -> void:
	var lines: Array[String] = []
	for error: Dictionary in errors:
		lines.append("%s: %s" % [error.get("field", ""), error.get("message", "")])
	errors_label.text = "\n".join(lines)
	errors_label.visible = not lines.is_empty()


static func _spin(node_name: String, minimum: float, maximum: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.name = node_name
	spin.theme_type_variation = &"EditorSpinBox"
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1.0
	return spin


static func _line(node_name: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.name = node_name
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return edit
