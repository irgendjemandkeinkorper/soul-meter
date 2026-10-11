class_name WeftluminLocationPanel
extends SoulMeterToolPanel
## Locations bottom tab (E3.3a / #341, architecture §4.3.3): a form over one location's hidden
## state — Harmonic Accord, thinning tier, weather default, no-combat zone, respawn policy,
## gameplay permission, spawns and the arrival flag/checkpoint. Validation, drafts and the bake
## preview are the model's (`models/location_metadata.gd`); this panel only lays them out.
## Saving writes a draft under `user://`; `tools/generate_locations.gd` promotes drafts into
## `canon/` and regenerates `world/locations/*.tres` and the location index.

const MODEL_SCRIPT := preload("res://weftlumin/panels/models/location_metadata.gd")
const CALM_LABEL := "calm (none)"

var location_option: OptionButton = null
var identity_label: Label = null
var accord_spin: SpinBox = null
var tier_spin: SpinBox = null
var weather_option: OptionButton = null
var respawn_option: OptionButton = null
var no_combat_check: CheckBox = null
var gameplay_check: CheckBox = null
var default_spawn_edit: LineEdit = null
var arrival_flag_edit: LineEdit = null
var arrival_checkpoint_edit: LineEdit = null
var spawns_box: TextEdit = null
var notes_label: Label = null
var errors_label: Label = null
var report_box: TextEdit = null

var _location_id: String = ""


func _init() -> void:
	title = "Locations"
	needs_sandbox = false
	hotkey_hint = ""


func _model_script() -> Script:
	return MODEL_SCRIPT


func _build(content: VBoxContainer) -> void:
	var picker := _row()
	content.add_child(picker)
	picker.add_child(_label("Location"))
	location_option = _option("Location")
	location_option.item_selected.connect(func(index: int) -> void:
		select_location(String(location_option.get_item_metadata(index)))
	)
	picker.add_child(location_option)
	picker.add_child(_button("Save draft", "SaveDraft", save))
	picker.add_child(_button("Discard draft", "DiscardDraft", discard))
	picker.add_child(_button("Bake preview", "BakePreview", preview_bake))
	picker.add_child(_button("Reload", "Reload", reload))

	identity_label = _label("", &"EditorLabel", true)
	identity_label.name = "Identity"
	content.add_child(identity_label)

	var numbers := _row()
	content.add_child(numbers)
	accord_spin = _spin("HarmonicAccord", 0.0, 100.0, 1.0)
	_captioned(numbers, "Harmonic accord", accord_spin)
	tier_spin = _spin("ThinningTier", 0.0, float(WeftluminLocationsKind.MAX_THINNING_TIER), 1.0)
	_captioned(numbers, "Thinning tier", tier_spin)
	weather_option = _option("Weather")
	for weather_id: String in [""] + WeftluminLocationsKind.weather_ids():
		weather_option.add_item(CALM_LABEL if weather_id.is_empty() else weather_id)
		weather_option.set_item_metadata(weather_option.item_count - 1, weather_id)
	_captioned(numbers, "Weather", weather_option)
	respawn_option = _option("RespawnPolicy")
	for policy: String in WeftluminLocationsKind.RESPAWN_POLICIES:
		respawn_option.add_item(policy)
		respawn_option.set_item_metadata(respawn_option.item_count - 1, policy)
	_captioned(numbers, "Respawn", respawn_option)
	no_combat_check = _check("NoCombatZone", "No-combat zone")
	numbers.add_child(no_combat_check)
	gameplay_check = _check("AllowedGameplay", "Gameplay")
	numbers.add_child(gameplay_check)

	var texts := _row()
	content.add_child(texts)
	default_spawn_edit = _line("DefaultSpawn", "default spawn id")
	_captioned(texts, "Default spawn", default_spawn_edit)
	arrival_flag_edit = _line("ArrivalFlag", "none")
	_captioned(texts, "Arrival flag", arrival_flag_edit)
	arrival_checkpoint_edit = _line("ArrivalCheckpoint", "none")
	_captioned(texts, "Checkpoint", arrival_checkpoint_edit)

	content.add_child(_label("Spawns — one “alias = spawn id” per line", &"EditorLabel", true))
	spawns_box = _text_box("Spawns", true)
	content.add_child(spawns_box)

	notes_label = _label("", &"EditorLabel", true)
	notes_label.name = "Notes"
	content.add_child(notes_label)
	errors_label = _label("", &"DangerLabel", true)
	errors_label.name = "Errors"
	errors_label.visible = false
	content.add_child(errors_label)
	report_box = _text_box("BakeReport", false)
	report_box.visible = false
	content.add_child(report_box)
	_populate_locations()


func refresh(_payload: Dictionary) -> void:
	if location_option == null:
		return
	if _location_id.is_empty():
		_populate_locations()


## Re-reads canon and drafts, keeping the selection when it still exists.
func reload() -> void:
	var errors: Array[Dictionary] = model.call("reload")
	_populate_locations()
	_show_errors(errors)


func location_ids() -> Array[String]:
	return model.call("location_ids")


func selected_location() -> String:
	return _location_id


func select_location(location_id: String) -> void:
	_location_id = location_id
	for index: int in location_option.item_count:
		if String(location_option.get_item_metadata(index)) == location_id:
			location_option.select(index)
	var row: Dictionary = model.call("document", location_id)
	if row.is_empty():
		return
	var source: String = "draft" if bool(model.call("has_draft", location_id)) else "canon"
	identity_label.text = "%s · %s · bakes to %s · %s" % [
		location_id, row["scene_path"], row["definition_path"], source,
	]
	accord_spin.value = float(row["harmonic_accord"])
	tier_spin.value = float(row["thinning_tier"])
	_select_metadata(weather_option, String(row["weather_default"]))
	_select_metadata(respawn_option, String(row["respawn_policy"]))
	no_combat_check.button_pressed = bool(row["no_combat_zone"])
	gameplay_check.button_pressed = bool(row["allowed_gameplay"])
	default_spawn_edit.text = String(row["default_spawn_id"])
	arrival_flag_edit.text = String(row["arrival_flag"])
	arrival_checkpoint_edit.text = String(row["arrival_checkpoint"])
	spawns_box.text = format_spawns(row["spawns"])
	_show_notes()
	_show_errors([])


## Sets one form control by its document field name (the test and CLI seam).
func set_field(field: String, value: Variant) -> void:
	match field:
		"harmonic_accord":
			accord_spin.value = float(value)
		"thinning_tier":
			tier_spin.value = float(value)
		"weather_default":
			_select_metadata(weather_option, String(value))
		"respawn_policy":
			_select_metadata(respawn_option, String(value))
		"no_combat_zone":
			no_combat_check.button_pressed = bool(value)
		"allowed_gameplay":
			gameplay_check.button_pressed = bool(value)
		"default_spawn_id":
			default_spawn_edit.text = String(value)
		"arrival_flag":
			arrival_flag_edit.text = String(value)
		"arrival_checkpoint":
			arrival_checkpoint_edit.text = String(value)
		"spawns":
			spawns_box.text = value if value is String else format_spawns(value)


## The form as document edits.
func edits() -> Dictionary:
	return {
		"harmonic_accord": accord_spin.value,
		"thinning_tier": int(tier_spin.value),
		"weather_default": String(_selected_metadata(weather_option)),
		"respawn_policy": String(_selected_metadata(respawn_option)),
		"no_combat_zone": no_combat_check.button_pressed,
		"allowed_gameplay": gameplay_check.button_pressed,
		"default_spawn_id": default_spawn_edit.text.strip_edges(),
		"arrival_flag": arrival_flag_edit.text.strip_edges(),
		"arrival_checkpoint": arrival_checkpoint_edit.text.strip_edges(),
		"spawns": parse_spawns(spawns_box.text),
	}


## Validates and saves the form as a draft. Returns true when saved.
func save() -> bool:
	if _location_id.is_empty():
		return false
	var parsed: Variant = edits()["spawns"]
	if not parsed is Dictionary:
		_show_errors([{"field": "spawns", "message": String(parsed)}])
		return false
	var errors: Array[Dictionary] = model.call("save_draft", _location_id, edits())
	if errors.is_empty():
		select_location(_location_id)
		_set_status("Draft saved to %s/%s.json." % [model.call("drafts_root"), _location_id])
		return true
	_show_errors(errors)
	return false


func discard() -> void:
	if _location_id.is_empty():
		return
	if bool(model.call("discard_draft", _location_id)):
		_set_status("Draft discarded; showing canon.")
	select_location(_location_id)


## Shows the report-only bake for canon plus every saved draft.
func preview_bake() -> Dictionary:
	var report: Dictionary = model.call("bake_preview")
	var lines: Array[String] = []
	for entry: Dictionary in report.get("planned", []):
		if entry["action"] != "unchanged":
			lines.append("%s  %s" % [entry["action"], entry["path"]])
	for orphan: String in report.get("orphans", []):
		lines.append("orphan  %s" % orphan)
	if lines.is_empty() and (report.get("errors", []) as Array).is_empty():
		lines.append("No change: canon and drafts bake to the committed artifacts.")
	lines.push_front(String(report.get("summary", "")))
	report_box.text = "\n".join(lines).strip_edges()
	report_box.visible = true
	_show_errors(report.get("errors", []))
	return report


func errors_text() -> String:
	return errors_label.text if errors_label.visible else ""


static func format_spawns(spawns: Dictionary) -> String:
	var aliases: Array = spawns.keys()
	aliases.sort()
	var lines: Array[String] = []
	for alias: Variant in aliases:
		lines.append("%s = %s" % [alias, spawns[alias]])
	return "\n".join(lines)


## `alias = spawn id` lines → dictionary, or an error string naming the bad line.
static func parse_spawns(text: String) -> Variant:
	var spawns: Dictionary = {}
	var number: int = 0
	for line: String in text.split("\n"):
		number += 1
		if line.strip_edges().is_empty():
			continue
		var parts: PackedStringArray = line.split("=", true, 1)
		if parts.size() != 2:
			return "Spawns line %d needs “alias = spawn id”." % number
		spawns[parts[0].strip_edges()] = parts[1].strip_edges()
	return spawns


func _populate_locations() -> void:
	location_option.clear()
	var ids: Array[String] = location_ids()
	for location_id: String in ids:
		var marker: String = " •" if bool(model.call("has_draft", location_id)) else ""
		location_option.add_item(location_id + marker)
		location_option.set_item_metadata(location_option.item_count - 1, location_id)
	if ids.is_empty():
		_location_id = ""
		_show_errors(model.call("load_errors"))
		return
	select_location(_location_id if ids.has(_location_id) else ids[0])


func _show_notes() -> void:
	var notes: Array[String] = model.call("notes", _location_id)
	notes_label.text = "\n".join(notes)
	notes_label.visible = not notes.is_empty()


func _show_errors(errors: Array) -> void:
	var lines: Array[String] = []
	for error: Dictionary in errors:
		lines.append("%s: %s" % [error.get("field", ""), error.get("message", "")])
	errors_label.text = "\n".join(lines)
	errors_label.visible = not lines.is_empty()


static func _select_metadata(option: OptionButton, value: String) -> void:
	for index: int in option.item_count:
		if String(option.get_item_metadata(index)) == value:
			option.select(index)
			return


static func _captioned(row: HBoxContainer, caption: String, control: Control) -> void:
	row.add_child(_label(caption))
	row.add_child(control)


static func _spin(node_name: String, minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.name = node_name
	spin.theme_type_variation = &"EditorSpinBox"
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	return spin


static func _check(node_name: String, text: String) -> CheckBox:
	var check := CheckBox.new()
	check.name = node_name
	check.text = text
	check.theme_type_variation = &"EditorCheckBox"
	return check


static func _line(node_name: String, placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.name = node_name
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return edit
