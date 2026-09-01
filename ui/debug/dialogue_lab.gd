extends Control
## Read-only authoring overlay for selecting and replaying imported dialogue.

var _lab: Node = null
var _replay_mode: bool = false
var _file_picker: OptionButton = null
var _title_picker: OptionButton = null
var _flags_editor: TextEdit = null
var _reputation_editor: TextEdit = null
var _renown_reputation: LineEdit = null
var _renown_infamy: LineEdit = null
var _status: Label = null
var _session_summary: Label = null


func configure(lab: Node, replay_controls: bool) -> void:
	_lab = lab
	_replay_mode = replay_controls
	theme = UIManager.ui_theme
	for child: Node in get_children():
		child.queue_free()
	if replay_controls:
		_build_replay_controls()
	else:
		_build_setup()


func update_replay_controls(running: bool, setup: Dictionary) -> void:
	if not _replay_mode or _status == null or _session_summary == null:
		return
	_status.text = "PLAYING" if running else "READY TO REPLAY"
	_session_summary.text = "%s\nTitle: %s" % [
		str(setup.get("dialogue_path", "")),
		str(setup.get("title", "")),
	]


func _build_setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.theme_type_variation = "WorldMapSidebar"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 72.0
	panel.offset_top = 48.0
	panel.offset_right = -72.0
	panel.offset_bottom = -48.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.theme_type_variation = "ScreenWindowMargin"
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.theme_type_variation = "ScreenShellColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)

	column.add_child(_label("DIALOGUE LAB", "TitleLabel"))
	column.add_child(_label(
		"F5 · Replay imported dialogue without changing campaign state or authored files.",
		"MutedLabel",
	))
	column.add_child(_label("DIALOGUE FILE", "EyebrowLabel"))
	_file_picker = OptionButton.new()
	_file_picker.item_selected.connect(_on_file_selected)
	column.add_child(_file_picker)
	column.add_child(_label("TITLE", "EyebrowLabel"))
	_title_picker = OptionButton.new()
	column.add_child(_title_picker)

	column.add_child(_label("FLAGS", "EyebrowLabel"))
	column.add_child(_label(
		"One per line: flag_key=true to set, flag_key=false to clear.", "MutedLabel"
	))
	_flags_editor = TextEdit.new()
	_flags_editor.custom_minimum_size = Vector2(0.0, 92.0)
	_flags_editor.placeholder_text = "dom_bellhouse_inspected=true\ndom_registry_notice_seen=false"
	column.add_child(_flags_editor)

	column.add_child(_label("FACTION REPUTATION", "EyebrowLabel"))
	column.add_child(_label(
		"Optional target standings, one per line: faction-id=value.", "MutedLabel"
	))
	_reputation_editor = TextEdit.new()
	_reputation_editor.custom_minimum_size = Vector2(0.0, 76.0)
	_reputation_editor.placeholder_text = "the-registry=21\nmirror-choir=-11"
	column.add_child(_reputation_editor)

	column.add_child(_label("RENOWN", "EyebrowLabel"))
	var renown_row := HBoxContainer.new()
	renown_row.theme_type_variation = "ScreenHeader"
	_renown_reputation = LineEdit.new()
	_renown_reputation.placeholder_text = "Reputation target (optional)"
	_renown_reputation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	renown_row.add_child(_renown_reputation)
	_renown_infamy = LineEdit.new()
	_renown_infamy.placeholder_text = "Infamy target (optional)"
	_renown_infamy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	renown_row.add_child(_renown_infamy)
	column.add_child(renown_row)

	_status = _label("", "DangerLabel")
	column.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.theme_type_variation = "ScreenHeader"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(func() -> void: _lab.call("close_overlay"))
	buttons.add_child(close)
	var start := Button.new()
	start.text = "PLAY CONVERSATION"
	start.theme_type_variation = "BronzeButton"
	start.pressed.connect(_start_replay)
	buttons.add_child(start)
	column.add_child(buttons)
	_populate_files()


func _build_replay_controls() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.theme_type_variation = "WorldMapSidebar"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -540.0
	panel.offset_top = 24.0
	panel.offset_right = -24.0
	panel.offset_bottom = 230.0
	add_child(panel)
	var margin := MarginContainer.new()
	margin.theme_type_variation = "ScreenWindowMargin"
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.theme_type_variation = "ScreenShellColumn"
	margin.add_child(column)
	column.add_child(_label("DIALOGUE LAB — REPLAY", "HeadingLabel"))
	_status = _label("PLAYING", "PositiveLabel")
	column.add_child(_status)
	_session_summary = _label("", "MutedLabel")
	_session_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_session_summary)
	var buttons := HBoxContainer.new()
	buttons.theme_type_variation = "ScreenHeader"
	var replay := Button.new()
	replay.text = "REPLAY SAME STATE"
	replay.pressed.connect(func() -> void: _lab.call("replay_same_state"))
	buttons.add_child(replay)
	var reload := Button.new()
	reload.text = "RELOAD FROM DISK + REPLAY"
	reload.theme_type_variation = "BronzeButton"
	reload.pressed.connect(func() -> void: _lab.call("reload_and_replay"))
	buttons.add_child(reload)
	var end := Button.new()
	end.text = "END SESSION"
	end.theme_type_variation = "DangerButton"
	end.pressed.connect(func() -> void: _lab.call("end_session"))
	buttons.add_child(end)
	column.add_child(buttons)
	var hide := Button.new()
	hide.text = "HIDE CONTROLS (F5)"
	hide.pressed.connect(func() -> void: _lab.call("close_overlay"))
	column.add_child(hide)


func _populate_files() -> void:
	_file_picker.clear()
	var file_values: Variant = _lab.call("dialogue_files")
	if file_values is Array:
		for path_value: Variant in file_values:
			var path := str(path_value)
			_file_picker.add_item(path.trim_prefix("res://dialogue/"))
			_file_picker.set_item_metadata(_file_picker.item_count - 1, path)
	if _file_picker.item_count == 0:
		_status.text = "No .dialogue files found."
		return
	_on_file_selected(0)


func _on_file_selected(_index: int) -> void:
	_title_picker.clear()
	if _file_picker.item_count == 0:
		return
	var path := str(_file_picker.get_selected_metadata())
	var title_values: Variant = _lab.call("titles_for_file", path)
	if title_values is Array:
		for title_value: Variant in title_values:
			var title := str(title_value)
			_title_picker.add_item(title)
			_title_picker.set_item_metadata(_title_picker.item_count - 1, title)
	_status.text = "" if _title_picker.item_count > 0 else "This resource has no titles."


func _start_replay() -> void:
	if _file_picker.item_count == 0 or _title_picker.item_count == 0:
		_status.text = "Choose a dialogue file and title."
		return
	var parsed_flags := _parse_flags(_flags_editor.text)
	if not bool(parsed_flags.get("valid", false)):
		_status.text = str(parsed_flags.get("error", "Invalid flag state."))
		return
	var parsed_reputation := _parse_numbers(_reputation_editor.text, "reputation")
	if not bool(parsed_reputation.get("valid", false)):
		_status.text = str(parsed_reputation.get("error", "Invalid reputation state."))
		return
	var setup := {
		"dialogue_path": str(_file_picker.get_selected_metadata()),
		"title": str(_title_picker.get_selected_metadata()),
		"flags": parsed_flags.get("values", {}),
		"reputation": parsed_reputation.get("values", {}),
	}
	if not _renown_reputation.text.strip_edges().is_empty():
		if not _renown_reputation.text.is_valid_float():
			_status.text = "Renown reputation must be a number or blank."
			return
		setup["renown_reputation"] = _renown_reputation.text.to_float()
	if not _renown_infamy.text.strip_edges().is_empty():
		if not _renown_infamy.text.is_valid_float():
			_status.text = "Renown infamy must be a number or blank."
			return
		setup["renown_infamy"] = _renown_infamy.text.to_float()
	_lab.call("start_replay", setup)


static func _parse_flags(text: String) -> Dictionary:
	var values: Dictionary = {}
	for raw_line: String in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		var pair := line.split("=", false, 1)
		if pair.size() != 2 or str(pair[0]).strip_edges().is_empty():
			return {"valid": false, "error": "Flags use flag_key=true or flag_key=false."}
		var value := str(pair[1]).strip_edges().to_lower()
		if value != "true" and value != "false":
			return {"valid": false, "error": "Flag '%s' must be true or false." % pair[0]}
		values[str(pair[0]).strip_edges()] = value == "true"
	return {"valid": true, "values": values}


static func _parse_numbers(text: String, label: String) -> Dictionary:
	var values: Dictionary = {}
	for raw_line: String in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		var pair := line.split("=", false, 1)
		if pair.size() != 2 or str(pair[0]).strip_edges().is_empty():
			return {"valid": false, "error": "%s uses key=value." % label.capitalize()}
		var value := str(pair[1]).strip_edges()
		if not value.is_valid_float():
			return {"valid": false, "error": "%s value for '%s' must be numeric." % [
				label.capitalize(), str(pair[0]).strip_edges(),
			]}
		values[str(pair[0]).strip_edges()] = value.to_float()
	return {"valid": true, "values": values}


static func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
