class_name WeftluminCombatLabPanel
extends SoulMeterToolPanel
## Combat lab tab (§4.9): Combat Lab's model behind the panel contract. Weather resolution, the
## forecast == resolution tripwire, session markdown and sandbox containment are the model's.
##
## `needs_sandbox`: the shell arms the shared sandbox under this panel's token on activation, and
## the model's own session restarts under that same token instead of competing with it. Leaving
## the tab ends the lab session, matching the shell ending the sandbox it held for the panel.

const MODEL_SCRIPT := preload("res://globals/combat_lab.gd")
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
var aim_picker: OptionButton = null
var aim_submit: Button = null
var inspector: TextEdit = null
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

	var aim_row := _row()
	aim_row.name = "AimControls"
	content.add_child(aim_row)
	aim_picker = _fixture_option("AimLocation", AIM_LOCATIONS, "%s")
	aim_picker.item_selected.connect(func(index: int) -> void:
		model.call("select_lab_aim", StringName(str(aim_picker.get_item_metadata(index))))
	)
	aim_row.add_child(aim_picker)
	aim_submit = _button("Fire lab shot", "SubmitAim", func() -> void: model.call("submit_lab_aim"))
	aim_row.add_child(aim_submit)

	inspector = _text_box("Inspector", false)
	content.add_child(inspector)
	# Session readout and aim sit directly under the setup/actions row; setup detail follows.
	content.move_child(inspector, 1)
	content.move_child(aim_row, 2)
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


## The setup the F3 setup screen would have submitted for the current selections.
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


func _render(payload: Dictionary) -> void:
	if inspector == null:
		return
	var aim_enabled := bool(payload.get("aim_enabled", false))
	aim_picker.get_parent().visible = aim_enabled
	var lines: PackedStringArray = []
	if payload.is_empty():
		inspector.text = "No lab session. Choose an encounter and start a lab battle."
		return
	lines.append("RUNNING" if bool(payload.get("running", false)) else "SESSION ENDED")
	lines.append("TIMELINE")
	for row_value: Variant in payload.get("timeline", []):
		var row: Dictionary = row_value
		lines.append("  %s — READY_AT %s · SPD %s · CHARGE %s · +%s ticks" % [
			str(row.get("display_name", row.get("actor_id", "?"))), str(row.get("ready_at", "—")),
			str(row.get("speed", "—")), str(row.get("charge", "—")), str(row.get("ticks_until", "—")),
		])
	var pending: Dictionary = payload.get("pending_forecast", {})
	lines.append("FORECAST %s" % (
		"awaiting the next allied turn" if pending.is_empty() else "%s → %s · %s · damage %d" % [
			str(pending.get("actor", "?")), str(pending.get("target_id", "?")),
			str(pending.get("action_id", "?")), int(pending.get("damage", 0)),
		]
	))
	var comparison: Dictionary = payload.get("comparison", {})
	if bool(comparison.get("diverged", false)):
		lines.append("FORECAST / RESOLUTION DIVERGENCE: %s" % "; ".join(
			comparison.get("differences", [])
		))
	if aim_enabled:
		var quote: Dictionary = payload.get("aim_forecast", {})
		aim_submit.disabled = not bool(quote.get("allowed", false))
		lines.append("AIM %s: %s" % [
			str(payload.get("aim_location", "")),
			str(quote.get("message", "")) if aim_submit.disabled else "hit %s%% · %s damage" % [
				str((quote.get("resolution", {}) as Dictionary).get("accuracy_breakdown", {}).get(
					"effective_hit_chance", "—"
				)),
				str(quote.get("damage_on_hit", "—")),
			],
		])
	var snapshot: Dictionary = payload.get("snapshot", {})
	lines.append("FIELD balance %s · band %s" % [
		str(snapshot.get("balance", "—")), str(snapshot.get("balance_band_id", "—")),
	])
	for tile_value: Variant in payload.get("combatant_tiles", []):
		var tile_row: Dictionary = tile_value
		lines.append("  %s @ %s" % [str(tile_row.get("actor", "?")), str(tile_row.get("position", {}))])
	lines.append("STYLE %s" % str(payload.get("style", {})))
	lines.append("TURNS %d" % (payload.get("turns", []) as Array).size())
	for turn_value: Variant in payload.get("turns", []):
		lines.append("  %s" % str(turn_value))
	var outcome: Dictionary = payload.get("outcome", {})
	if not outcome.is_empty():
		lines.append("OUTCOME %s" % str(outcome))
	var export_path := str(payload.get("last_export_path", ""))
	lines.append("Export: %s" % (export_path if not export_path.is_empty() else "not exported"))
	inspector.text = "\n".join(lines)


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
