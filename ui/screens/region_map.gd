class_name RegionMapScreen
extends Screen
## Gazetteer and etched-map presentation over the existing discovered-hub registry.

var _destinations: Array[Dictionary] = []
var _selected: Dictionary = {}
var _map_layer: Control
var _name_label: Label
var _description_label: Label
var _distance_label: Label
var _time_label: Label
var _risk_label: Label
var _integrity_label: Label
var _writ_notice: PanelContainer
var _travel_button: Button
var _status_label: Label


func _build() -> void:
	# Opaque: the paused field scene otherwise reads through the etched map.
	_add_opaque_backdrop()
	var shell := _make_shell()
	shell_header = shell[0] as HBoxContainer
	shell_body = shell[1] as MarginContainer
	shell_hud_bar = shell[2] as HBoxContainer
	_build_header()
	_build_body()
	_build_hud()
	_refresh()
	if not GameFlow.last_travel_error.is_empty():
		GameFlow.last_travel_error = ""
		_status_label.text = "Travel failed. No silver was spent."


func _build_header() -> void:
	var title := Label.new()
	title.text = "DRAMGID — THE WANING MARCHES"
	title.theme_type_variation = "TitleLabel"
	shell_header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_header.add_child(spacer)
	var ledger := Label.new()
	ledger.name = "CommissionReadout"
	ledger.text = "%s  ·  %d SILVER" % [String(WorldClock.phase()).to_upper(), GameState.gp]
	ledger.theme_type_variation = "StatLabel"
	shell_header.add_child(ledger)


func _build_body() -> void:
	var columns := HBoxContainer.new()
	columns.name = "RegionMapColumns"
	columns.theme_type_variation = "InventoryColumns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_body.add_child(columns)
	columns.add_child(_build_gazetteer())
	columns.add_child(_build_map_field())


func _build_gazetteer() -> Control:
	var panel := PanelContainer.new()
	panel.name = "GazetteerRail"
	panel.custom_minimum_size.x = 420.0
	var column := VBoxContainer.new()
	column.theme_type_variation = "ScreenContentColumn"
	panel.add_child(column)
	_name_label = _label("GazetteerName", "NO MARK SELECTED", "HeadingLabel")
	_description_label = _label("GazetteerDescription", "Select a discovered mark.", "QuoteLabel")
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_distance_label = _label("StatRow_Distance", "DISTANCE  —", "StatLabel")
	_time_label = _label("StatRow_TravelTime", "TRAVEL TIME  —", "StatLabel")
	_risk_label = _label("StatRow_EncounterRisk", "ENCOUNTER RISK  —", "StatLabel")
	_integrity_label = _label("AgreementReadout", "LOCAL INTEGRITY  —", "EyebrowLabel")
	for label: Label in [_name_label, _description_label, _distance_label, _time_label, _risk_label, _integrity_label]:
		column.add_child(label)
	_writ_notice = PanelContainer.new()
	_writ_notice.name = "WritNotice"
	_writ_notice.visible = false
	var writ_text := _label("WritNoticeText", "ROAD SEALED BY WRIT", "DangerLabel")
	_writ_notice.add_child(writ_text)
	column.add_child(_writ_notice)
	_status_label = _label("TravelStatus", "", "EyebrowLabel")
	column.add_child(_status_label)
	_travel_button = Button.new()
	_travel_button.name = "TravelButton"
	_travel_button.text = "TRAVEL"
	_travel_button.theme_type_variation = "BronzeButton"
	_travel_button.custom_minimum_size.y = DS.CONTROL_H_LG
	_travel_button.pressed.connect(_travel_selected)
	column.add_child(_travel_button)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(close)
	column.add_child(back)
	return panel


func _build_map_field() -> Control:
	var panel := PanelContainer.new()
	panel.name = "EtchedMapField"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var canvas := RegionMapCanvas.new()
	canvas.name = "MapCanvas"
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(canvas)
	_map_layer = Control.new()
	_map_layer.name = "MapMarks"
	_map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(_map_layer)
	var legend := Label.new()
	legend.name = "MapLegend"
	legend.text = "BRONZE: CURRENT  ·  STONE: DISCOVERED"
	legend.theme_type_variation = "EyebrowLabel"
	legend.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	legend.position.y = -DS.SPACE_7
	panel.add_child(legend)
	return panel


func _build_hud() -> void:
	var party := Label.new()
	party.text = "PARTY  ·  SELECT MARK  ·  CONFIRM TRAVEL"
	party.theme_type_variation = "EyebrowLabel"
	shell_hud_bar.add_child(party)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_hud_bar.add_child(spacer)
	shell_hud_bar.add_child(SOUL_GAUGE_SCENE.instantiate())


static func destinations_for(current_scene_path: String) -> Array[Dictionary]:
	var destinations: Array[Dictionary] = []
	for location: LocationDefinition in LocationRegistry.ALL:
		var hub := FastTravelRegistry.by_id(location.id)
		if hub.is_empty() or not GameState.is_fast_travel_hub_discovered(location.id):
			continue
		var row := hub.duplicate(true)
		row["is_current"] = current_scene_path == location.scene_path
		row["affordable"] = GameState.can_afford(int(hub["base_cost_gp"]))
		row["location"] = location
		destinations.append(row)
	return destinations


func _refresh() -> void:
	_destinations = destinations_for(_current_scene_path())
	var canvas := find_child("MapCanvas", true, false) as RegionMapCanvas
	canvas.marks = _destinations
	for child: Node in _map_layer.get_children():
		child.queue_free()
	if _destinations.is_empty():
		_status_label.text = "No travel hubs have been discovered yet."
		_travel_button.disabled = true
		return
	for index: int in _destinations.size():
		_add_mark(_destinations[index], index)
	_select_destination(_destinations[0])


func _add_mark(destination: Dictionary, index: int) -> void:
	var button := Button.new()
	button.name = "Hub_%s" % destination["id"]
	button.text = "%s  ·  %d SILVER" % [destination["display_name"], destination["base_cost_gp"]]
	if bool(destination["is_current"]):
		button.text += "  ·  CURRENT"
		button.theme_type_variation = "BronzeButton"
	else:
		button.theme_type_variation = "ItemSlot"
	button.disabled = bool(destination["is_current"]) or not bool(destination["affordable"])
	button.custom_minimum_size = Vector2(180.0, DS.CONTROL_H_LG)
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.position = RegionMapCanvas.normalized_position(index, _destinations.size()) * Vector2(700.0, 430.0)
	button.pressed.connect(_select_destination.bind(destination))
	_map_layer.add_child(button)


## FR-506: the map itself is evidence — the gazetteer reads the destination's
## thinning tier instead of printing "UNRECORDED" placeholders.
const THINNING_WORDS: Array[String] = ["HELD", "FRAYING", "THINNING", "NEAR THE WOUND"]
const RISK_WORDS: Array[String] = ["LOW", "MODERATE", "HIGH", "SEVERE"]


func _select_destination(destination: Dictionary) -> void:
	_selected = destination
	var location: LocationDefinition = destination["location"]
	var tier: int = clampi(location.thinning_tier, 0, THINNING_WORDS.size() - 1)
	var cost := int(destination["base_cost_gp"])
	_name_label.text = str(destination["display_name"]).to_upper()
	if bool(destination["is_current"]):
		_description_label.text = "You are here. The ledger holds this mark open."
	else:
		_description_label.text = "A discovered hub held in the fast-travel ledger."
	_distance_label.text = "PASSAGE  ·  %d SILVER  ·  REGISTERED ROAD" % cost
	var arrival := WorldClock.PHASES[
		(WorldClock.PHASES.find(WorldClock.phase()) + 1) % WorldClock.PHASES.size()
	]
	_time_label.text = "TRAVEL TIME  ·  ONE PHASE — ARRIVE BY %s" % String(arrival).to_upper()
	_risk_label.text = "ENCOUNTER RISK  ·  %s" % RISK_WORDS[tier]
	_integrity_label.text = "LOCAL INTEGRITY  ·  %s (THINNING %d)" % [THINNING_WORDS[tier], tier]
	_writ_notice.visible = false
	_travel_button.disabled = bool(destination["is_current"]) or not bool(destination["affordable"])
	if bool(destination["is_current"]):
		_travel_button.text = "YOU ARE HERE"
	elif not bool(destination["affordable"]):
		_travel_button.text = "TRAVEL  ·  %d SILVER (SHORT)" % cost
	else:
		_travel_button.text = "TRAVEL  ·  %d SILVER" % cost
	var tween := create_tween()
	_name_label.modulate.a = 0.0
	tween.tween_property(_name_label, "modulate:a", 1.0, DS.DUR_FAST)


func _travel_selected() -> void:
	if not _selected.is_empty():
		_on_destination_pressed(StringName(_selected["id"]))


func _on_destination_pressed(hub_id: StringName) -> void:
	var result: Dictionary = GameFlow.fast_travel(hub_id)
	if bool(result.get("ok", false)):
		return
	var messages := {
		"unknown_destination": "That destination is no longer available.",
		"undiscovered": "You have not discovered that hub.",
		"current_destination": "You are already at that hub.",
		"insufficient_gp": "You do not have enough silver for that journey.",
		"purchase_failed": "The travel purchase could not be completed.",
		"route_rejected": "The route could not be opened. No silver was spent.",
	}
	_status_label.text = messages.get(str(result.get("error", "")), "Travel failed. No silver was spent.")
	_refresh()


func _label(node_name: String, text: String, variation: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.theme_type_variation = variation
	return label


func _current_scene_path() -> String:
	var current := get_tree().current_scene
	return current.scene_file_path if current != null else ""
