class_name WeftluminCombatLabPanel
extends SoulMeterToolPanel
## Combat lab tab (§4.9): Combat Lab's model behind the panel contract. Weather resolution, the
## forecast == resolution tripwire, session markdown and sandbox containment are the model's.
##
## `needs_sandbox`: the shell arms the shared sandbox under this panel's token on activation, and
## the model's own session restarts under that same token instead of competing with it. Leaving
## the tab ends the lab session, matching the shell ending the sandbox it held for the panel.

const MODEL_SCRIPT := preload("res://weftlumin/panels/models/combat_lab.gd")
const ANATOMY_FIXTURES: Array[Array] = [
	["Exposed anatomy", "exposed"], ["Arm covered", "covered_arm"],
	["No throat", "no_throat"], ["Low cover", "low_cover"],
]
const VISIBILITY_FIXTURES: Array[Array] = [["Clear", "clear"], ["Dim", "dim"], ["Obscured", "obscured"]]
const AIM_LOCATIONS: Array[Array] = [
	["Ordinary attack", ""], ["Torso", "torso"], ["Arm", "arm"], ["Throat", "throat"],
]

var encounter_picker: OptionButton = null
var weather_picker: OptionButton = null
var weather_source: Label = null
var party_tree: Tree = null
var tile_x: SpinBox = null
var tile_y: SpinBox = null
var tile_element: OptionButton = null
var tile_charge: SpinBox = null
var aim_fixture: CheckBox = null
var anatomy_fixture: OptionButton = null
var visibility_fixture: OptionButton = null
## Styled inspector (#474): one column per readout, as the retired F3 inspector dock showed them.
var inspector: HBoxContainer = null
var aim_controls: VBoxContainer = null
var aim_picker: OptionButton = null
var aim_quote: Label = null
var aim_submit: Button = null
var session_label: Label = null
var timeline_label: Label = null
var forecast_label: Label = null
var divergence_label: Label = null
var field_label: Label = null
var style_label: Label = null
var turns_label: Label = null
var export_label: Label = null
var _last_payload: Dictionary = {}


func _init() -> void:
	title = "Combat lab"
	needs_sandbox = true
	hotkey_hint = ""


func _model_script() -> Script:
	return MODEL_SCRIPT


func _attach_model() -> bool:
	return bool(model.call("host_in_panel", _host.sandbox_token(self)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and model != null and not is_visible_in_tree():
		model.call("stop_test_session")


func _build(content: VBoxContainer) -> void:
	var setup := _row()
	content.add_child(setup)
	encounter_picker = _option("Encounter")
	for encounter_id: StringName in model.call("encounter_ids"):
		var definition: Dictionary = EncounterCatalog.definition(encounter_id)
		encounter_picker.add_item("%s — %s" % [
			String(encounter_id), str(definition.get("display_name", encounter_id)),
		])
		encounter_picker.set_item_metadata(encounter_picker.item_count - 1, encounter_id)
	encounter_picker.item_selected.connect(func(_index: int) -> void: refresh_weather_source())
	setup.add_child(encounter_picker)
	weather_picker = _option("Weather")
	weather_picker.add_item("Encounter default")
	weather_picker.set_item_metadata(0, model.call("authored_weather_marker"))
	weather_picker.add_item("CALM (override)")
	weather_picker.set_item_metadata(1, &"")
	for element_id: StringName in ElementWheel.ORDER:
		weather_picker.add_item("%s (override)" % String(element_id).to_upper())
		weather_picker.set_item_metadata(weather_picker.item_count - 1, element_id)
	weather_picker.item_selected.connect(func(_index: int) -> void: refresh_weather_source())
	setup.add_child(weather_picker)
	setup.add_child(_button("Start lab battle", "Start", start))
	setup.add_child(_button("Restart same", "RestartSame", func() -> void:
		model.call("restart_same_setup")
	))
	setup.add_child(_button("Restart new seed", "RestartNewSeed", func() -> void:
		model.call("restart_new_seed")
	))
	setup.add_child(_button("Stop", "Stop", func() -> void: model.call("stop_test_session")))
	setup.add_child(_button("Export markdown", "Export", export_session))
	weather_source = _label("")
	weather_source.name = "WeatherSource"
	setup.add_child(weather_source)

	content.add_child(_label("Party — up to %d combatants (the live party cap)." % int(
		model.call("party_cap")
	), &"EditorLabel", true))
	party_tree = Tree.new()
	party_tree.name = "Party"
	party_tree.theme_type_variation = &"EditorTree"
	party_tree.hide_root = true
	party_tree.custom_minimum_size.y = get_theme_constant(&"dock_height", &"EditorTabContainer")
	party_tree.item_edited.connect(_on_party_edited)
	content.add_child(party_tree)

	var tile_row := _row()
	content.add_child(tile_row)
	tile_row.add_child(_label("Tile seed cell"))
	tile_x = _spin("TileX", 64)
	tile_row.add_child(tile_x)
	tile_y = _spin("TileY", 64)
	tile_row.add_child(tile_y)
	tile_element = _option("TileElement")
	tile_element.add_item("UNCHARGED")
	tile_element.set_item_metadata(0, &"")
	for element_id: StringName in ElementWheel.ORDER:
		tile_element.add_item(String(element_id).to_upper())
		tile_element.set_item_metadata(tile_element.item_count - 1, element_id)
	tile_row.add_child(tile_element)
	tile_charge = _spin("TileCharge", TileState.MAX_CHARGE_LEVEL)
	tile_row.add_child(tile_charge)

	var fixture_row := _row()
	content.add_child(fixture_row)
	aim_fixture = CheckBox.new()
	aim_fixture.name = "CalledShotFixture"
	aim_fixture.text = "Called-shot fixture (provisional)"
	aim_fixture.theme_type_variation = &"EditorCheckBox"
	fixture_row.add_child(aim_fixture)
	anatomy_fixture = _fixture_option("AnatomyFixture", ANATOMY_FIXTURES, "%s")
	fixture_row.add_child(anatomy_fixture)
	visibility_fixture = _fixture_option("VisibilityFixture", VISIBILITY_FIXTURES, "%s visibility")
	fixture_row.add_child(visibility_fixture)

	_build_inspector(content)
	# The live inspector sits directly under the setup/actions row; setup detail follows.
	content.move_child(inspector, 1)
	model.connect("inspector_changed", _on_inspector_changed)


func refresh(_payload: Dictionary) -> void:
	_populate_party()
	refresh_weather_source()
	_render(_last_payload)


func commands() -> Array[Callable]:
	return [
		Callable(model, "start_lab_battle"),
		Callable(model, "restart_same_setup"),
		Callable(model, "restart_new_seed"),
		Callable(model, "stop_test_session"),
		Callable(model, "export_session"),
		Callable(model, "select_lab_aim"),
		Callable(model, "submit_lab_aim"),
	]


## The lab setup for the current selections.
func current_setup() -> Dictionary:
	var party_ids: Array[StringName] = []
	var root := party_tree.get_root()
	if root != null:
		for item: TreeItem in root.get_children():
			if item.is_checked(0):
				party_ids.append(StringName(str(item.get_metadata(0))))
	var weather_value := StringName(str(_selected_metadata(weather_picker)))
	var authored_marker := StringName(model.call("authored_weather_marker"))
	return {
		"encounter_id": StringName(str(_selected_metadata(encounter_picker))),
		"party_ids": party_ids,
		"weather_override_enabled": weather_value != authored_marker,
		"weather_override": &"" if weather_value == authored_marker else weather_value,
		"tile_seed": {
			"cell": Vector2i(int(tile_x.value), int(tile_y.value)),
			"element_id": StringName(str(_selected_metadata(tile_element))),
			"charge": int(tile_charge.value),
		},
		"seed": Time.get_ticks_usec(),
		"called_shot_fixture": aim_fixture.button_pressed,
		"anatomy_fixture": str(_selected_metadata(anatomy_fixture)),
		"visibility_fixture": str(_selected_metadata(visibility_fixture)),
	}


func start() -> void:
	if encounter_picker.item_count == 0:
		_set_status("No encounters in the catalog.")
		return
	_set_status("")
	if bool(model.call("production_battle_is_live")) or bool(model.call("another_sandbox_is_armed")):
		_set_status(MODEL_SCRIPT.REFUSAL_WARNING)
	model.call("start_lab_battle", current_setup())


func export_session() -> String:
	var path := str(model.call("export_session"))
	_set_status("Exported %s" % path if not path.is_empty() else "Nothing to export yet.")
	return path


func refresh_weather_source() -> void:
	if weather_source == null or encounter_picker.item_count == 0:
		return
	var selected_weather := StringName(str(_selected_metadata(weather_picker)))
	var authored_marker := StringName(model.call("authored_weather_marker"))
	var resolved: Dictionary = model.call(
		"resolve_weather",
		StringName(str(_selected_metadata(encounter_picker))),
		selected_weather != authored_marker,
		&"" if selected_weather == authored_marker else selected_weather,
	)
	weather_source.text = "In effect: %s" % str(resolved.get("label", "CALM"))


func _populate_party() -> void:
	party_tree.clear()
	var root := party_tree.create_item()
	var current_ids: Dictionary = {}
	for current: PartyMember in GameState.party:
		current_ids[current.id] = true
	for member: PartyMember in model.call("party_candidates"):
		var item := root.create_child()
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_text(0, "%s  [%s]" % [member.display_name, member.id])
		item.set_metadata(0, StringName(member.id))
		item.set_checked(0, current_ids.has(member.id))


func _on_party_edited() -> void:
	var edited := party_tree.get_edited()
	if edited == null or not edited.is_checked(0):
		return
	var checked := 0
	for item: TreeItem in party_tree.get_root().get_children():
		checked += 1 if item.is_checked(0) else 0
	if checked > int(model.call("party_cap")):
		edited.set_checked(0, false)


func _on_inspector_changed(payload: Dictionary) -> void:
	_last_payload = payload
	_render(payload)


func _build_inspector(content: VBoxContainer) -> void:
	inspector = _row()
	inspector.name = "InspectorDock"
	content.add_child(inspector)
	aim_controls = _inspector_column("AimControls", "Called shots — provisional fixture")
	aim_picker = _fixture_option("AimLocation", AIM_LOCATIONS, "%s")
	aim_picker.item_selected.connect(func(index: int) -> void:
		model.call("select_lab_aim", StringName(str(aim_picker.get_item_metadata(index))))
	)
	aim_controls.add_child(aim_picker)
	aim_quote = _section_label(aim_controls, "AimQuote")
	aim_submit = _button("Fire lab shot", "SubmitAim", func() -> void: model.call("submit_lab_aim"))
	aim_controls.add_child(aim_submit)
	var session := _inspector_column("Session", "Live resolution")
	session_label = _section_label(session, "SessionState")
	session.add_child(_label("CT timeline", &"EditorHeading"))
	timeline_label = _section_label(session, "Timeline")
	var forecast := _inspector_column("Forecast", "Forecast → resolution")
	forecast_label = _section_label(forecast, "ForecastText")
	divergence_label = _section_label(forecast, "Divergence", &"DangerLabel")
	var field := _inspector_column("Field", "Live field")
	field_label = _section_label(field, "FieldState")
	var rows := _inspector_column("Rows", "Style tracker")
	style_label = _section_label(rows, "Style")
	rows.add_child(_label("Session rows", &"EditorHeading"))
	turns_label = _section_label(rows, "Turns")
	export_label = _section_label(rows, "ExportPath")


func _inspector_column(node_name: String, heading: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = node_name
	column.theme_type_variation = &"EditorColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_label(heading, &"EditorHeading"))
	inspector.add_child(column)
	return column


static func _section_label(
	column: VBoxContainer, node_name: String, variation: StringName = &"EditorLabel"
) -> Label:
	var label := _label("", variation, true)
	label.name = node_name
	column.add_child(label)
	return label


## Every visible inspector readout, column by column.
func inspector_text() -> String:
	var parts: PackedStringArray = []
	if aim_controls.visible:
		parts.append(aim_quote.text)
	for label: Label in [session_label, timeline_label, forecast_label]:
		parts.append(label.text)
	if divergence_label.visible:
		parts.append(divergence_label.text)
	for label: Label in [field_label, style_label, turns_label, export_label]:
		parts.append(label.text)
	return "\n".join(parts)


func _render(payload: Dictionary) -> void:
	if inspector == null:
		return
	aim_controls.visible = bool(payload.get("aim_enabled", false))
	if payload.is_empty():
		session_label.text = "No lab session. Choose an encounter and start a lab battle."
	else:
		session_label.text = "RUNNING" if bool(payload.get("running", false)) else "SESSION ENDED"
	timeline_label.text = _timeline_text(payload.get("timeline", []))
	_render_forecast(payload)
	_render_aim(payload)
	field_label.text = _field_text(payload)
	style_label.text = _style_text(payload.get("style", {}))
	turns_label.text = _turn_text(payload.get("turns", []), payload.get("outcome", {}))
	var export_path := str(payload.get("last_export_path", ""))
	export_label.text = "Export: %s" % (export_path if not export_path.is_empty() else "not exported")


## The full aim quote: target, cost, hit chance, damage on hit, every accuracy term, injury.
func _render_aim(payload: Dictionary) -> void:
	if not aim_controls.visible:
		return
	var location := str(payload.get("aim_location", "torso"))
	for index: int in aim_picker.item_count:
		if str(aim_picker.get_item_metadata(index)) == location:
			aim_picker.select(index)
	var quote: Dictionary = payload.get("aim_forecast", {})
	aim_submit.disabled = not bool(quote.get("allowed", false))
	if aim_submit.disabled:
		aim_quote.text = str(quote.get("message", "Aim unavailable."))
		return
	var accuracy: Dictionary = (quote["resolution"] as Dictionary)["accuracy_breakdown"]
	var terms: PackedStringArray = ["Base %d%%" % int(accuracy["base"])]
	for modifier: Dictionary in accuracy["modifiers"]:
		terms.append("%s %+d pp" % [str(modifier["label"]), int(modifier["percentage_points"])])
	if int(accuracy["clamp_adjustment"]) != 0:
		terms.append("Clamp %+d pp" % int(accuracy["clamp_adjustment"]))
	var use_ct := str(quote.get("scheduler_mode", "ap")) == "ct"
	var injury: Dictionary = quote.get("injury_forecast", {})
	var injury_line := "Synthetic anatomy; no injury authored for this location."
	if not injury.is_empty():
		injury_line = "INJURY %s · %d%% ON HIT · %d%% OVERALL (needs %d damage)" % [
			str(injury.get("id", "")), int(injury.get("chance_on_hit", 0)),
			int(injury.get("overall_chance", 0)), int(injury.get("min_damage", 1)),
		]
	# AP compatibility: the lab quotes AP cost when the CT battlefield flag is off.
	aim_quote.text = "%s · COST %d %s · HIT %d%%\n%d DAMAGE ON HIT\n%s\n%s" % [
		str(quote.get("target_name", "")), int(quote["ct_cost"] if use_ct else quote["ap_cost"]),
		"CT" if use_ct else "AP", int(accuracy["effective_hit_chance"]),
		int(quote["damage_on_hit"]), " · ".join(terms), injury_line,
	]


func _render_forecast(payload: Dictionary) -> void:
	var pending: Dictionary = payload.get("pending_forecast", {})
	if pending.is_empty():
		forecast_label.text = "Pending strike forecast unavailable; awaiting the next allied turn."
	else:
		var context: Dictionary = pending.get("context", {})
		forecast_label.text = (
			"%s → %s · %s\nForecast damage %d · power %s · scale %s · target HP %s · tick %s" % [
				str(pending.get("actor", "?")), str(pending.get("target_id", "?")),
				str(pending.get("action_id", "?")), int(pending.get("damage", 0)),
				str((context.get("ability", {}) as Dictionary).get("power", "—")),
				str((context.get("unit", {}) as Dictionary).get("attack_scale", "—")),
				str((context.get("target", {}) as Dictionary).get("hp", "—")),
				str(context.get("tick", "—")),
			]
		)
	var comparison: Dictionary = payload.get("comparison", {})
	var diverged := bool(comparison.get("diverged", false))
	divergence_label.visible = diverged
	divergence_label.text = "FORECAST / RESOLUTION DIVERGENCE\n%s" % "; ".join(
		comparison.get("differences", [])
	) if diverged else ""


static func _timeline_text(rows: Array) -> String:
	var lines: PackedStringArray = []
	for row: Dictionary in rows:
		lines.append("%s — READY_AT %s · SPD %s · CHARGE %s · +%s ticks" % [
			str(row.get("display_name", row.get("actor_id", "?"))), str(row.get("ready_at", "—")),
			str(row.get("speed", "—")), str(row.get("charge", "—")), str(row.get("ticks_until", "—")),
		])
	return "\n".join(lines) if not lines.is_empty() else "No scheduler rows."


static func _field_text(payload: Dictionary) -> String:
	var snapshot: Dictionary = payload.get("snapshot", {})
	var weather: Dictionary = snapshot.get("weather", {})
	var weather_id := str(weather.get("element_id", ""))
	var lines: PackedStringArray = [
		"Balance %s · band %s" % [
			str(snapshot.get("balance", "—")), str(snapshot.get("balance_band_id", "—")),
		],
		"Weather %s · tick %s" % [
			"CALM" if weather_id.is_empty() else weather_id.to_upper(), str(weather.get("tick", "—")),
		],
	]
	for row: Dictionary in payload.get("combatant_tiles", []):
		var tile: Dictionary = row.get("tile", {})
		var charge_id := str(tile.get("charge_element_id", ""))
		lines.append("%s @ %s — %s %s" % [
			str(row.get("actor", "?")), _position_text(row.get("position", {})),
			"UNCHARGED" if charge_id.is_empty() else charge_id.to_upper(),
			str(tile.get("charge_level", 0)),
		])
	return "\n".join(lines)


static func _position_text(position: Dictionary) -> String:
	if position.has("cell"):
		var cell: Vector2i = position["cell"]
		return "(%d, %d)" % [cell.x, cell.y]
	return str(position) if not position.is_empty() else "—"


static func _style_text(style: Dictionary) -> String:
	return "Total %s · verb %s · balance %s · no-damage %s · speech %s" % [
		str(style.get(&"total", 0)), str(style.get(&"verb_variety", 0)),
		str(style.get(&"balance_management", 0)), str(style.get(&"no_damage_turns", 0)),
		str(style.get(&"speech_resolutions", 0)),
	]


static func _turn_text(turns: Array, outcome: Dictionary) -> String:
	var lines: PackedStringArray = []
	for row: Dictionary in turns:
		lines.append("%s. %s / %s — %s → %s%s" % [
			str(row.get("turn", "?")), str(row.get("actor", "?")), str(row.get("action", "?")),
			str(row.get("forecast", "—")), str(row.get("resolution", "—")),
			"  DIVERGED" if bool(row.get("diverged", false)) else "",
		])
	if not outcome.is_empty():
		lines.append("Outcome: %s / %s" % [
			str(outcome.get("state", "")), str(outcome.get("outcome_id", "")),
		])
	return "\n".join(lines) if not lines.is_empty() else "No resolved actions yet."


func _spin(node_name: String, maximum: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.name = node_name
	spin.theme_type_variation = &"EditorSpinBox"
	spin.min_value = 0
	spin.max_value = maximum
	spin.step = 1
	return spin


static func _fixture_option(node_name: String, rows: Array[Array], label: String) -> OptionButton:
	var option := _option(node_name)
	for row: Array in rows:
		option.add_item(label % str(row[0]))
		option.set_item_metadata(option.item_count - 1, row[1])
	return option
