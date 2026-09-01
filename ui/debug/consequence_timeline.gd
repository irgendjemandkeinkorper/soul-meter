class_name ConsequenceTimelinePanel
extends Control
## Read-only presentation for ConsequenceTimelineController's signal-fed rows.

var _controller: ConsequenceTimelineController = null
var _summary_label: Label = null
var _rows_container: VBoxContainer = null
var _timeline_changed_callable: Callable = Callable(self, "_refresh")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func configure(controller: ConsequenceTimelineController) -> void:
	_controller = controller
	if not _controller.timeline_changed.is_connected(_timeline_changed_callable):
		_controller.timeline_changed.connect(_timeline_changed_callable)
	_refresh()


func _exit_tree() -> void:
	if _controller != null and is_instance_valid(_controller):
		if _controller.timeline_changed.is_connected(_timeline_changed_callable):
			_controller.timeline_changed.disconnect(_timeline_changed_callable)


func _build() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "TimelinePanel"
	panel.theme_type_variation = "ConsequenceNoticePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -920.0
	panel.offset_top = 16.0
	panel.offset_right = -16.0
	panel.offset_bottom = 700.0
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.theme_type_variation = "ScreenWindowMargin"
	panel.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = "ScreenContentColumn"
	margin.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	header.theme_type_variation = "ScreenHeader"
	column.add_child(header)

	var title: Label = Label.new()
	title.text = "CONSEQUENCE TIMELINE"
	title.theme_type_variation = "HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var hint: Label = Label.new()
	hint.text = "F4 close"
	hint.theme_type_variation = "MutedLabel"
	header.add_child(hint)

	_summary_label = Label.new()
	_summary_label.name = "Summary"
	_summary_label.theme_type_variation = "StatLabel"
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_summary_label)

	var restored_note: Label = Label.new()
	restored_note.text = (
		"RESTORED HISTORY is approximate across ledgers; live rows follow signal arrival."
	)
	restored_note.theme_type_variation = "MutedLabel"
	restored_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(restored_note)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "TimelineScroll"
	scroll.custom_minimum_size = Vector2(0.0, 540.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(scroll)

	_rows_container = VBoxContainer.new()
	_rows_container.name = "TimelineRows"
	_rows_container.theme_type_variation = "LedgerHistory"
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_rows_container)


func _refresh() -> void:
	if _controller == null or _summary_label == null or _rows_container == null:
		return
	_summary_label.text = _format_summary(_controller.summary())
	for child: Node in _rows_container.get_children():
		child.free()
	var timeline_rows: Array[Dictionary] = _controller.rows()
	if timeline_rows.is_empty():
		var empty: Label = Label.new()
		empty.text = "No consequences recorded this session."
		empty.theme_type_variation = "MutedLabel"
		_rows_container.add_child(empty)
		return
	for row: Dictionary in timeline_rows:
		_rows_container.add_child(_build_row(row))


func _build_row(row: Dictionary) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = "ConsequenceNoticePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var restored: bool = bool(row.get("restored", false))
	var debug_injected: bool = bool(row.get("debug_injected", false))
	if debug_injected:
		label.theme_type_variation = "DangerLabel"
	elif restored:
		label.theme_type_variation = "MutedLabel"
	else:
		label.theme_type_variation = "StatLabel"
	var provenance: Array[String] = []
	if debug_injected:
		provenance.append("DEBUG-INJECTED")
	if restored:
		provenance.append("RESTORED HISTORY / CROSS-LEDGER ORDER APPROXIMATE")
	var provenance_text: String = ""
	if not provenance.is_empty():
		provenance_text = "  •  " + "  •  ".join(provenance)
	label.text = "%s  •  %s / %s  •  %s → %s%s\n%s\nactor: %s  •  scene: %s" % [
		_format_time(int(row.get("at", 0))),
		str(row.get("ledger", "")),
		str(row.get("subject", "")),
		_signed(float(row.get("delta", 0.0))),
		_number(float(row.get("resulting", 0.0))),
		provenance_text,
		str(row.get("cause", "")),
		str(row.get("actor", "")),
		str(row.get("scene", "")),
	]
	panel.add_child(label)
	return panel


func _format_summary(summary: Dictionary) -> String:
	var standings_value: Variant = summary.get("standings", {})
	var standings: Dictionary = standings_value as Dictionary
	var faction_ids: Array[String] = []
	for faction_value: Variant in standings.keys():
		faction_ids.append(str(faction_value))
	faction_ids.sort()
	var faction_parts: Array[String] = []
	for faction: String in faction_ids:
		faction_parts.append("%s %s" % [faction, _signed(float(standings[faction]))])
	var faction_summary: String = "none touched" if faction_parts.is_empty() else ", ".join(faction_parts)
	return "FACTIONS: %s  •  REPUTATION %s  •  INFAMY %s" % [
		faction_summary,
		_number(float(summary.get("reputation", 0.0))),
		_number(float(summary.get("infamy", 0.0))),
	]


func _format_time(timestamp: int) -> String:
	var value: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d:%02d:%02d" % [
		int(value.get("hour", 0)), int(value.get("minute", 0)), int(value.get("second", 0))
	]


func _signed(value: float) -> String:
	return "+%.1f" % value if value >= 0.0 else "%.1f" % value


func _number(value: float) -> String:
	return "%.1f" % value
