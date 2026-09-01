class_name CombatLabPanel
extends Control
## Utility-only debug UI. All combat values arrive from CombatLab's signal-fed snapshots.

var _lab: Node = null
var _inspector_mode: bool = false
var _encounter_picker: OptionButton = null
var _party_picker: ItemList = null
var _weather_picker: OptionButton = null
var _weather_source: Label = null
var _tile_x: SpinBox = null
var _tile_y: SpinBox = null
var _tile_element: OptionButton = null
var _tile_charge: SpinBox = null
var _timeline: Label = null
var _forecast: Label = null
var _divergence: Label = null
var _field_state: Label = null
var _style: Label = null
var _turns: Label = null
var _export_path: Label = null


func configure(lab: Node, inspector: bool) -> void:
	_lab = lab
	_inspector_mode = inspector
	for child: Node in get_children():
		child.queue_free()
	if inspector:
		_build_inspector()
	else:
		_build_setup()


func update_inspector(payload: Dictionary) -> void:
	if not _inspector_mode or _timeline == null:
		return
	_update_timeline(payload.get("timeline", []))
	_update_forecast(payload)
	_update_field_state(payload)
	_style.text = _style_text(payload.get("style", {}))
	_turns.text = _turn_text(payload.get("turns", []), payload.get("outcome", {}))
	var export_path := str(payload.get("last_export_path", ""))
	_export_path.text = "Export: %s" % (export_path if not export_path.is_empty() else "not exported")


func _build_setup() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.03, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "SetupPanel"
	panel.custom_minimum_size = Vector2(720, 760)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-360, -380)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	column.add_child(_heading("COMBAT LAB — ENCOUNTER SETUP", 24))
	column.add_child(_note("Debug sandbox. Runtime overrides never write authored balance data."))
	column.add_child(_heading("ENCOUNTER", 16))
	_encounter_picker = OptionButton.new()
	for encounter_id: StringName in _lab.call("encounter_ids"):
		var definition: Dictionary = EncounterCatalog.definition(encounter_id)
		_encounter_picker.add_item("%s — %s" % [
			String(encounter_id), str(definition.get("display_name", encounter_id)),
		])
		_encounter_picker.set_item_metadata(_encounter_picker.item_count - 1, encounter_id)
	_encounter_picker.item_selected.connect(_on_setup_selection_changed)
	column.add_child(_encounter_picker)

	column.add_child(_heading("PARTY", 16))
	column.add_child(_note("Select up to %d combatants (the live party cap)." % int(_lab.call("party_cap"))))
	_party_picker = ItemList.new()
	_party_picker.select_mode = ItemList.SELECT_MULTI
	_party_picker.custom_minimum_size = Vector2(0, 170)
	var current_ids: Dictionary = {}
	for current: PartyMember in GameState.party:
		current_ids[current.id] = true
	for member: PartyMember in _lab.call("party_candidates"):
		_party_picker.add_item("%s  [%s]" % [member.display_name, member.id])
		var item_index := _party_picker.item_count - 1
		_party_picker.set_item_metadata(item_index, StringName(member.id))
		if current_ids.has(member.id):
			_party_picker.select(item_index, false)
	_party_picker.multi_selected.connect(_on_party_selection_changed)
	column.add_child(_party_picker)

	column.add_child(_heading("WEATHER", 16))
	_weather_picker = OptionButton.new()
	_weather_picker.add_item("Encounter default")
	_weather_picker.set_item_metadata(0, _lab.call("authored_weather_marker"))
	_weather_picker.add_item("CALM (override)")
	_weather_picker.set_item_metadata(1, &"")
	for element_id: StringName in ElementWheel.ORDER:
		_weather_picker.add_item("%s (override)" % String(element_id).to_upper())
		_weather_picker.set_item_metadata(_weather_picker.item_count - 1, element_id)
	_weather_picker.item_selected.connect(_on_setup_selection_changed)
	column.add_child(_weather_picker)
	_weather_source = _note("")
	column.add_child(_weather_source)

	column.add_child(_heading("TILE SEED", 16))
	var tile_row := HBoxContainer.new()
	tile_row.add_child(_note("Cell X"))
	_tile_x = _spin(0, 64, 0)
	tile_row.add_child(_tile_x)
	tile_row.add_child(_note("Y"))
	_tile_y = _spin(0, 64, 0)
	tile_row.add_child(_tile_y)
	_tile_element = OptionButton.new()
	_tile_element.add_item("UNCHARGED")
	_tile_element.set_item_metadata(0, &"")
	for element_id: StringName in ElementWheel.ORDER:
		_tile_element.add_item(String(element_id).to_upper())
		_tile_element.set_item_metadata(_tile_element.item_count - 1, element_id)
	tile_row.add_child(_tile_element)
	tile_row.add_child(_note("Charge"))
	_tile_charge = _spin(0, TileState.MAX_CHARGE_LEVEL, 0)
	tile_row.add_child(_tile_charge)
	column.add_child(tile_row)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(func() -> void: _lab.call("close_overlay"))
	buttons.add_child(close)
	var start := Button.new()
	start.text = "START LAB BATTLE"
	start.theme_type_variation = "BronzeButton"
	start.pressed.connect(_start_battle)
	buttons.add_child(start)
	column.add_child(buttons)
	_refresh_weather_source()


func _build_inspector() -> void:
	var panel := PanelContainer.new()
	panel.name = "InspectorDock"
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.anchor_left = 1.0
	panel.offset_left = -520.0
	panel.custom_minimum_size = Vector2(520, 0)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	column.add_child(_heading("COMBAT LAB — LIVE RESOLUTION", 20))
	var buttons := HBoxContainer.new()
	var restart := Button.new()
	restart.text = "RESTART SAME"
	restart.pressed.connect(func() -> void: _lab.call("restart_same_setup"))
	buttons.add_child(restart)
	var reseed := Button.new()
	reseed.text = "NEW SEED"
	reseed.pressed.connect(func() -> void: _lab.call("restart_new_seed"))
	buttons.add_child(reseed)
	var export := Button.new()
	export.text = "EXPORT .MD"
	export.pressed.connect(func() -> void: _lab.call("export_session"))
	buttons.add_child(export)
	var hide := Button.new()
	hide.text = "HIDE (F3)"
	hide.pressed.connect(func() -> void: _lab.call("close_overlay"))
	buttons.add_child(hide)
	column.add_child(buttons)

	_timeline = _section(column, "CT TIMELINE")
	_forecast = _section(column, "FORECAST → RESOLUTION")
	_divergence = Label.new()
	_divergence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_divergence.add_theme_color_override("font_color", Color(1.0, 0.22, 0.12))
	_divergence.add_theme_font_size_override("font_size", 20)
	column.add_child(_divergence)
	_field_state = _section(column, "LIVE FIELD")
	_style = _section(column, "STYLE TRACKER")
	_turns = _section(column, "SESSION ROWS")
	_turns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_export_path = _note("Export: not exported")
	column.add_child(_export_path)


func _start_battle() -> void:
	if _encounter_picker.item_count == 0:
		return
	var party_ids: Array[StringName] = []
	for selected_index: int in _party_picker.get_selected_items():
		party_ids.append(StringName(_party_picker.get_item_metadata(selected_index)))
	var weather_value := StringName(_weather_picker.get_selected_metadata())
	var authored_marker := StringName(_lab.call("authored_weather_marker"))
	_lab.call("start_lab_battle", {
		"encounter_id": StringName(_encounter_picker.get_selected_metadata()),
		"party_ids": party_ids,
		"weather_override_enabled": weather_value != authored_marker,
		"weather_override": &"" if weather_value == authored_marker else weather_value,
		"tile_seed": {
			"cell": Vector2i(int(_tile_x.value), int(_tile_y.value)),
			"element_id": StringName(_tile_element.get_selected_metadata()),
			"charge": int(_tile_charge.value),
		},
		"seed": Time.get_ticks_usec(),
	})


func _on_party_selection_changed(index: int, selected: bool) -> void:
	if selected and _party_picker.get_selected_items().size() > int(_lab.call("party_cap")):
		_party_picker.deselect(index)


func _on_setup_selection_changed(_index: int) -> void:
	_refresh_weather_source()


func _refresh_weather_source() -> void:
	if _weather_source == null or _encounter_picker.item_count == 0:
		return
	var selected_weather := StringName(_weather_picker.get_selected_metadata())
	var authored_marker := StringName(_lab.call("authored_weather_marker"))
	var resolved: Dictionary = _lab.call(
		"resolve_weather",
		StringName(_encounter_picker.get_selected_metadata()),
		selected_weather != authored_marker,
		&"" if selected_weather == authored_marker else selected_weather,
	)
	_weather_source.text = "In effect: %s" % str(resolved.get("label", "CALM"))


func _update_timeline(rows_value: Variant) -> void:
	var lines: Array[String] = []
	if rows_value is Array:
		for row_value: Variant in rows_value:
			if not row_value is Dictionary:
				continue
			var row := row_value as Dictionary
			lines.append("%s — READY_AT %s · SPD %s · CHARGE %s · +%s ticks" % [
				str(row.get("display_name", row.get("actor_id", "?"))),
				str(row.get("ready_at", "—")),
				str(row.get("speed", "—")),
				str(row.get("charge", "—")),
				str(row.get("ticks_until", "—")),
			])
	_timeline.text = "\n".join(lines) if not lines.is_empty() else "No scheduler rows."


func _update_forecast(payload: Dictionary) -> void:
	var pending: Dictionary = payload.get("pending_forecast", {})
	var comparison: Dictionary = payload.get("comparison", {})
	if pending.is_empty():
		_forecast.text = "Pending strike forecast unavailable; awaiting the next allied turn."
	else:
		var context: Dictionary = pending.get("context", {})
		var ability: Dictionary = context.get("ability", {})
		var unit: Dictionary = context.get("unit", {})
		var target: Dictionary = context.get("target", {})
		_forecast.text = "%s → %s · %s\nForecast damage %d · power %s · scale %s · target HP %s · tick %s" % [
			str(pending.get("actor", "?")),
			str(pending.get("target_id", "?")),
			str(pending.get("action_id", "?")),
			int(pending.get("damage", 0)),
			str(ability.get("power", "—")),
			str(unit.get("attack_scale", "—")),
			str(target.get("hp", "—")),
			str(context.get("tick", "—")),
		]
	if bool(comparison.get("diverged", false)):
		_divergence.text = "⚠ FORECAST / RESOLUTION DIVERGENCE ⚠\n%s" % "; ".join(
			comparison.get("differences", [])
		)
	else:
		_divergence.text = ""


func _update_field_state(payload: Dictionary) -> void:
	var snapshot: Dictionary = payload.get("snapshot", {})
	var weather: Dictionary = snapshot.get("weather", {})
	var lines: Array[String] = [
		"Balance %s · band %s" % [
			str(snapshot.get("balance", "—")), str(snapshot.get("balance_band_id", "—")),
		],
		"Weather %s · tick %s" % [
			"CALM" if str(weather.get("element_id", "")).is_empty() else str(weather.get("element_id", "")).to_upper(),
			str(weather.get("tick", "—")),
		],
	]
	var combatant_tiles: Variant = payload.get("combatant_tiles", [])
	if combatant_tiles is Array:
		for row_value: Variant in combatant_tiles:
			if not row_value is Dictionary:
				continue
			var row := row_value as Dictionary
			var tile: Dictionary = row.get("tile", {})
			lines.append("%s @ %s — %s %s" % [
				str(row.get("actor", "?")),
				str(row.get("position", {})),
				"UNCHARGED" if str(tile.get("charge_element_id", "")).is_empty() else str(tile.get("charge_element_id", "")).to_upper(),
				str(tile.get("charge_level", 0)),
			])
	_field_state.text = "\n".join(lines)


func _style_text(style_value: Variant) -> String:
	if not style_value is Dictionary:
		return "No style data."
	var style := style_value as Dictionary
	return "Total %s · verb %s · balance %s · no-damage %s · speech %s" % [
		str(style.get(&"total", 0)),
		str(style.get(&"verb_variety", 0)),
		str(style.get(&"balance_management", 0)),
		str(style.get(&"no_damage_turns", 0)),
		str(style.get(&"speech_resolutions", 0)),
	]


func _turn_text(turns_value: Variant, outcome: Dictionary) -> String:
	var lines: Array[String] = []
	if turns_value is Array:
		for row_value: Variant in turns_value:
			if not row_value is Dictionary:
				continue
			var row := row_value as Dictionary
			lines.append("%s. %s / %s — %s → %s%s" % [
				str(row.get("turn", "?")), str(row.get("actor", "?")),
				str(row.get("action", "?")), str(row.get("forecast", "—")),
				str(row.get("resolution", "—")),
				"  DIVERGED" if bool(row.get("diverged", false)) else "",
			])
	if not outcome.is_empty():
		lines.append("Outcome: %s / %s" % [
			str(outcome.get("state", "")), str(outcome.get("outcome_id", "")),
		])
	return "\n".join(lines) if not lines.is_empty() else "No resolved actions yet."


func _section(parent: VBoxContainer, title: String) -> Label:
	parent.add_child(_heading(title, 14))
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _heading(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _spin(minimum: float, maximum: float, initial: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.value = initial
	spin.custom_minimum_size = Vector2(72, 0)
	return spin
