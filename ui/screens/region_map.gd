class_name RegionMapScreen
extends Screen
## Registry-driven world map and presentation controller for committed journeys.

const ATLAS_TEXTURE_PATH := "res://assets/generated/backgrounds/ui/waning-marches-atlas-v1.png"
const MARKER_SIZE := Vector2(148.0, 44.0)
const PARTY_MARKER_SIZE := Vector2(88.0, 30.0)
const JOURNEY_STEP_SECONDS := 0.5
const THINNING_WORDS: Array[String] = ["HELD", "FRAYING", "THINNING", "NEAR THE WOUND"]

var _locations: Array[Dictionary] = []
var _selected: Dictionary = {}
var _origin_id: StringName = &""
var _map_canvas: WorldRouteCanvas
var _marker_layer: Control
var _party_layer: Control
var _markers: Dictionary = {}
var _party_marker: PanelContainer
var _journey_timer: Timer
var _party_tween: Tween
var _name_label: Label
var _description_label: Label
var _distance_label: Label
var _time_label: Label
var _risk_label: Label
var _integrity_label: Label
var _travel_button: Button
var _continue_button: Button
var _cancel_button: Button
var _status_label: Label
var _prompt_overlay: Control
var _prompt_name: Label
var _prompt_risk: Label


func _build() -> void:
	_add_opaque_backdrop()
	var shell := _make_shell()
	shell_header = shell[0] as HBoxContainer
	shell_body = shell[1] as MarginContainer
	shell_hud_bar = shell[2] as HBoxContainer
	_build_header()
	_build_body()
	_build_hud()
	_build_journey_timer()
	_build_encounter_prompt()
	_refresh()


func _build_header() -> void:
	var title := Label.new()
	title.text = "DRAMGID — THE WANING MARCHES"
	title.theme_type_variation = "TitleLabel"
	shell_header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_header.add_child(spacer)
	var phase := Label.new()
	phase.name = "PhaseReadout"
	phase.text = String(WorldClock.phase()).to_upper()
	phase.theme_type_variation = "StatLabel"
	shell_header.add_child(phase)


func _build_body() -> void:
	var columns := HBoxContainer.new()
	columns.name = "RegionMapColumns"
	columns.theme_type_variation = "WorldMapColumns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_body.add_child(columns)
	columns.add_child(_build_map_field())
	columns.add_child(_build_route_panel())


func _build_map_field() -> Control:
	var panel := PanelContainer.new()
	panel.name = "WorldMapField"
	panel.theme_type_variation = "WorldMapField"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Wave AF: painterly atlas plate under the route canvas. STRETCH_SCALE (not
	# cover/crop) is load-bearing — marks sit at normalized map coordinates, and
	# the plate's landmarks are painted at those same normalized coordinates, so
	# both must warp together under any field aspect.
	var atlas_texture: Texture2D = null
	if ResourceLoader.exists(ATLAS_TEXTURE_PATH):
		atlas_texture = load(ATLAS_TEXTURE_PATH) as Texture2D
	if atlas_texture != null:
		var backdrop := TextureRect.new()
		backdrop.name = "AtlasBackdrop"
		backdrop.texture = atlas_texture
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_SCALE
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(backdrop)

	_map_canvas = WorldRouteCanvas.new()
	_map_canvas.name = "MapCanvas"
	_map_canvas.has_backdrop = atlas_texture != null
	_map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(_map_canvas)

	_marker_layer = Control.new()
	_marker_layer.name = "MapMarkers"
	_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(_marker_layer)

	_party_layer = Control.new()
	_party_layer.name = "PartyLayer"
	_party_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(_party_layer)
	_build_party_marker()

	var legend := Label.new()
	legend.name = "MapLegend"
	legend.text = "BRONZE: CURRENT  ·  IRON: DISCOVERED  ·  DIM: UNDISCOVERED"
	legend.theme_type_variation = "WorldMapLegend"
	legend.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	legend.position = Vector2(DS.SPACE_6, -DS.SPACE_8)
	panel.add_child(legend)
	_map_canvas.resized.connect(_relayout_markers)
	return panel


func _build_route_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "RoutePanel"
	panel.theme_type_variation = "WorldMapSidebar"
	panel.custom_minimum_size.x = 360.0
	var column := VBoxContainer.new()
	column.theme_type_variation = "ScreenContentColumn"
	panel.add_child(column)

	_name_label = _label("RouteName", "NO ROUTE SELECTED", "HeadingLabel")
	_description_label = _label("RouteDescription", "Select a discovered connected mark.", "QuoteLabel")
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_distance_label = _label("RouteSteps", "ROUTE  —", "StatLabel")
	_time_label = _label("RouteTime", "TRAVEL TIME  —", "StatLabel")
	_risk_label = _label("RouteRisk", "ENCOUNTER RISK  —", "StatLabel")
	_integrity_label = _label("LocationIntegrity", "LOCAL INTEGRITY  —", "EyebrowLabel")
	for label: Label in [
		_name_label,
		_description_label,
		_distance_label,
		_time_label,
		_risk_label,
		_integrity_label,
	]:
		column.add_child(label)

	_status_label = _label("TravelStatus", "", "EyebrowLabel")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_travel_button = Button.new()
	_travel_button.name = "TravelButton"
	_travel_button.text = "BEGIN JOURNEY"
	_travel_button.theme_type_variation = "BronzeButton"
	_travel_button.pressed.connect(_travel_selected)
	column.add_child(_travel_button)

	_continue_button = Button.new()
	_continue_button.name = "ContinueJourneyButton"
	_continue_button.text = "CONTINUE JOURNEY"
	_continue_button.theme_type_variation = "BronzeButton"
	_continue_button.visible = false
	_continue_button.pressed.connect(_continue_journey)
	column.add_child(_continue_button)

	_cancel_button = Button.new()
	_cancel_button.name = "CancelJourneyButton"
	_cancel_button.text = "CANCEL JOURNEY"
	_cancel_button.theme_type_variation = "DangerButton"
	_cancel_button.visible = false
	_cancel_button.pressed.connect(_cancel_journey)
	column.add_child(_cancel_button)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "BACK"
	back.pressed.connect(close)
	column.add_child(back)
	return panel


func _build_party_marker() -> void:
	_party_marker = PanelContainer.new()
	_party_marker.name = "PartyMarker"
	_party_marker.theme_type_variation = "WorldMapPartyMarker"
	_party_marker.custom_minimum_size = PARTY_MARKER_SIZE
	_party_marker.size = PARTY_MARKER_SIZE
	_party_marker.visible = false
	_party_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "PARTY"
	label.theme_type_variation = "WorldMapPartyLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_party_marker.add_child(label)
	_party_layer.add_child(_party_marker)


func _build_journey_timer() -> void:
	_journey_timer = Timer.new()
	_journey_timer.name = "JourneyStepTimer"
	_journey_timer.wait_time = JOURNEY_STEP_SECONDS
	_journey_timer.one_shot = false
	_journey_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_journey_timer.timeout.connect(_on_journey_tick)
	add_child(_journey_timer)


func _build_encounter_prompt() -> void:
	_prompt_overlay = CenterContainer.new()
	_prompt_overlay.name = "EncounterPrompt"
	_prompt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prompt_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_prompt_overlay.visible = false
	add_child(_prompt_overlay)

	var panel := PanelContainer.new()
	panel.name = "EncounterPromptPanel"
	panel.theme_type_variation = "JourneyEncounterPanel"
	panel.custom_minimum_size = Vector2(520.0, 300.0)
	_prompt_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.theme_type_variation = "ScreenContentColumn"
	panel.add_child(column)

	var heading := _label("EncounterHeading", "ROAD ENCOUNTER", "EyebrowLabel")
	column.add_child(heading)
	_prompt_name = _label("EncounterName", "UNKNOWN ENCOUNTER", "HeadingLabel")
	column.add_child(_prompt_name)
	_prompt_risk = _label("EncounterRisk", "ROUTE RISK  —", "DangerLabel")
	column.add_child(_prompt_risk)

	var avoid := Button.new()
	avoid.name = "AvoidEncounterButton"
	avoid.text = "AVOID (SURVIVAL)"
	avoid.theme_type_variation = "BronzeButton"
	avoid.pressed.connect(_resolve_encounter.bind(true))
	column.add_child(avoid)
	var stand := Button.new()
	stand.name = "StandGroundButton"
	stand.text = "STAND GROUND"
	stand.pressed.connect(_resolve_encounter.bind(false))
	column.add_child(stand)
	var cancel := Button.new()
	cancel.name = "EncounterCancelButton"
	cancel.text = "CANCEL JOURNEY"
	cancel.theme_type_variation = "DangerButton"
	cancel.pressed.connect(_cancel_journey)
	column.add_child(cancel)


func _build_hud() -> void:
	var instruction := Label.new()
	instruction.text = "SELECT MARK  ·  REVIEW ROUTE  ·  COMMIT"
	instruction.theme_type_variation = "EyebrowLabel"
	shell_hud_bar.add_child(instruction)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_hud_bar.add_child(spacer)
	shell_hud_bar.add_child(SOUL_GAUGE_SCENE.instantiate())


static func locations_for(current_scene_path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_location: Dictionary in WorldMapRegistry.all_locations():
		var row: Dictionary = raw_location.duplicate(true)
		var location_id := StringName(row.get("id", &""))
		var is_current := current_scene_path == str(row.get("scene_path", ""))
		row["display_name"] = _display_name(location_id)
		row["is_current"] = is_current
		row["is_discovered"] = is_current or GameState.is_world_location_discovered(location_id)
		var definition := LocationRegistry.by_scene(str(row.get("scene_path", "")))
		row["thinning_tier"] = definition.thinning_tier if definition != null else 0
		result.append(row)
	return result


func _refresh() -> void:
	_locations = locations_for(_current_scene_path())
	_origin_id = _resolve_origin_id()
	_map_canvas.configure(_locations, WorldMapRegistry.all_routes(), {})
	_rebuild_markers()
	if _has_live_plan():
		_sync_live_plan()
		return
	_reset_journey_controls()
	_select_initial_location()


func _rebuild_markers() -> void:
	for child: Node in _marker_layer.get_children():
		_marker_layer.remove_child(child)
		child.queue_free()
	_markers.clear()
	for location: Dictionary in _locations:
		var location_id := StringName(location["id"])
		var marker := Button.new()
		marker.name = "Location_%s" % String(location_id)
		marker.custom_minimum_size = MARKER_SIZE
		marker.size = MARKER_SIZE
		marker.set_meta("location_id", location_id)
		marker.set_meta("map_coordinate", Vector2(location["map_coordinate"]))
		if bool(location["is_current"]):
			marker.text = "%s  ·  CURRENT" % location["display_name"]
			marker.theme_type_variation = "WorldMapCurrentMarker"
		elif bool(location["is_discovered"]):
			marker.text = str(location["display_name"]).to_upper()
			marker.theme_type_variation = "WorldMapMarker"
		else:
			marker.text = "UNDISCOVERED"
			marker.theme_type_variation = "WorldMapUndiscoveredMarker"
		marker.disabled = not _is_selectable(location)
		marker.pressed.connect(_select_location.bind(location_id))
		_marker_layer.add_child(marker)
		_markers[location_id] = marker
	_relayout_markers()


func _relayout_markers() -> void:
	if _map_canvas == null:
		return
	for location: Dictionary in _locations:
		var location_id := StringName(location["id"])
		var marker: Button = _markers.get(location_id) as Button
		if marker == null:
			continue
		marker.size = MARKER_SIZE
		marker.position = Vector2(location["map_coordinate"]) * _map_canvas.size - marker.size * 0.5
	_update_party_marker(false)


func _select_initial_location() -> void:
	for location: Dictionary in _locations:
		if _is_selectable(location):
			_select_location(StringName(location["id"]))
			return
	_selected = {}
	_travel_button.disabled = true
	_status_label.text = "No discovered connected destination is available."


func _select_location(location_id: StringName) -> void:
	var location := _location_row(location_id)
	if location.is_empty() or (not bool(location["is_current"]) and not bool(location["is_discovered"])):
		return
	_selected = location
	var route := WorldMapRegistry.route_between(_origin_id, location_id)
	_name_label.text = str(location["display_name"]).to_upper()
	var tier := clampi(int(location["thinning_tier"]), 0, THINNING_WORDS.size() - 1)
	_integrity_label.text = "LOCAL INTEGRITY  ·  %s" % THINNING_WORDS[tier]
	if bool(location["is_current"]):
		_description_label.text = "You are here."
		_clear_route_details()
		_travel_button.text = "YOU ARE HERE"
		_travel_button.disabled = true
		return
	if route.is_empty():
		_description_label.text = "No direct route is registered from the current mark."
		_clear_route_details()
		_travel_button.text = "NO DIRECT ROUTE"
		_travel_button.disabled = true
		return
	_description_label.text = "A connected route is ready for commitment."
	_distance_label.text = "ROUTE  ·  %d STEPS" % int(route.get("steps", 0))
	_time_label.text = "TRAVEL TIME  ·  %d PHASES" % int(route.get("phases_cost", 0))
	_risk_label.text = "ENCOUNTER RISK  ·  %s" % String(route.get("risk_tier", &"unknown")).to_upper()
	_travel_button.text = "BEGIN JOURNEY"
	_travel_button.disabled = false


func _clear_route_details() -> void:
	_distance_label.text = "ROUTE  —"
	_time_label.text = "TRAVEL TIME  —"
	_risk_label.text = "ENCOUNTER RISK  —"


func _travel_selected() -> void:
	if _selected.is_empty() or _travel_button.disabled:
		return
	var destination_id := StringName(_selected["id"])
	if not GameFlow.start_journey(_origin_id, destination_id):
		_status_label.text = "The selected route could not be opened."
		return
	_show_live_plan(true)


func _on_destination_pressed(location_id: StringName) -> void:
	_select_location(location_id)


func _show_live_plan(start_immediately: bool) -> void:
	_sync_live_plan()
	if start_immediately and GameFlow.travel_plan != null:
		if GameFlow.travel_plan.state == TravelPlan.State.EN_ROUTE:
			_continue_journey()


func _sync_live_plan() -> void:
	if not _has_live_plan():
		return
	_journey_timer.stop()
	var plan: TravelPlan = GameFlow.travel_plan
	_origin_id = plan.origin_id
	_selected = _location_row(plan.destination_id)
	var active_route := WorldMapRegistry.route_between(plan.origin_id, plan.destination_id)
	_map_canvas.configure(_locations, WorldMapRegistry.all_routes(), active_route)
	_apply_live_route_details(plan, active_route)
	_travel_button.visible = false
	_continue_button.visible = plan.state == TravelPlan.State.EN_ROUTE
	_cancel_button.visible = true
	_set_destination_markers_disabled(true)
	_update_party_marker(false)
	if plan.state == TravelPlan.State.AVOID_PROMPT:
		_show_encounter_prompt(_pending_encounter_id())
	else:
		_prompt_overlay.visible = false


func _apply_live_route_details(plan: TravelPlan, route: Dictionary) -> void:
	var destination := _location_row(plan.destination_id)
	_name_label.text = str(destination.get("display_name", _display_name(plan.destination_id))).to_upper()
	_description_label.text = "Journey committed."
	_distance_label.text = "PROGRESS  ·  %d / %d STEPS" % [plan.progress_step, plan.total_steps]
	_time_label.text = "TRAVEL TIME  ·  %d PHASES" % int(route.get("phases_cost", 0))
	_risk_label.text = "ENCOUNTER RISK  ·  %s" % String(route.get("risk_tier", &"unknown")).to_upper()
	var tier := clampi(int(destination.get("thinning_tier", 0)), 0, THINNING_WORDS.size() - 1)
	_integrity_label.text = "LOCAL INTEGRITY  ·  %s" % THINNING_WORDS[tier]
	_status_label.text = "JOURNEY PAUSED  ·  CONTINUE WHEN READY"


func _continue_journey() -> void:
	if GameFlow.travel_plan == null or GameFlow.travel_plan.state != TravelPlan.State.EN_ROUTE:
		return
	_prompt_overlay.visible = false
	_continue_button.visible = false
	_cancel_button.visible = true
	_status_label.text = "JOURNEY UNDERWAY"
	_journey_timer.start()


func _on_journey_tick() -> void:
	if GameFlow.travel_plan == null or GameFlow.travel_plan.state != TravelPlan.State.EN_ROUTE:
		_journey_timer.stop()
		_sync_live_plan()
		return
	var result: Dictionary = GameFlow.advance_journey(1)
	_update_party_marker(true)
	if GameFlow.travel_plan != null:
		var route := WorldMapRegistry.route_between(
			GameFlow.travel_plan.origin_id, GameFlow.travel_plan.destination_id
		)
		_apply_live_route_details(GameFlow.travel_plan, route)
	var event := StringName(result.get("event", &""))
	match event:
		&"en_route":
			_status_label.text = "JOURNEY UNDERWAY"
		&"encounter_prompt":
			_journey_timer.stop()
			_show_encounter_prompt(StringName(result.get("encounter_id", &"")))
		&"arrived":
			_journey_timer.stop()
			close()
		_:
			_journey_timer.stop()


func _show_encounter_prompt(encounter_id: StringName) -> void:
	var definition: Dictionary = EncounterCatalog.definition(encounter_id)
	_prompt_name.text = str(definition.get("display_name", _display_name(encounter_id))).to_upper()
	var route: Dictionary = {}
	if GameFlow.travel_plan != null:
		route = WorldMapRegistry.route_between(
			GameFlow.travel_plan.origin_id, GameFlow.travel_plan.destination_id
		)
	_prompt_risk.text = "ROUTE RISK  ·  %s" % String(route.get("risk_tier", &"unknown")).to_upper()
	_prompt_overlay.visible = true
	_continue_button.visible = false
	_cancel_button.visible = true
	_status_label.text = "JOURNEY INTERRUPTED"


func _resolve_encounter(avoid: bool) -> void:
	var result: Dictionary = GameFlow.resolve_encounter_prompt(avoid)
	var event := StringName(result.get("event", &""))
	if event == &"avoided":
		_prompt_overlay.visible = false
		_update_party_marker(false)
		_continue_journey()
	elif event == &"battle_started":
		_prompt_overlay.visible = false
		_journey_timer.stop()
	else:
		_sync_live_plan()


func _cancel_journey() -> void:
	_journey_timer.stop()
	if is_instance_valid(_party_tween):
		_party_tween.kill()
	GameFlow.cancel_journey()
	close()


func _update_party_marker(animate: bool) -> void:
	if _party_marker == null or _map_canvas == null or GameFlow.travel_plan == null:
		if _party_marker != null:
			_party_marker.visible = false
		return
	var plan: TravelPlan = GameFlow.travel_plan
	if plan.state not in [TravelPlan.State.EN_ROUTE, TravelPlan.State.AVOID_PROMPT]:
		_party_marker.visible = false
		return
	var origin := _location_row(plan.origin_id)
	var destination := _location_row(plan.destination_id)
	if origin.is_empty() or destination.is_empty():
		_party_marker.visible = false
		return
	var progress := clampf(float(plan.progress_step) / float(maxi(plan.total_steps, 1)), 0.0, 1.0)
	var from := Vector2(origin["map_coordinate"]) * _map_canvas.size
	var to := Vector2(destination["map_coordinate"]) * _map_canvas.size
	var target := from.lerp(to, progress) - PARTY_MARKER_SIZE * 0.5
	_party_marker.set_meta("route_progress", progress)
	_party_marker.visible = true
	if is_instance_valid(_party_tween):
		_party_tween.kill()
	if animate:
		_party_tween = create_tween()
		_party_tween.set_trans(Tween.TRANS_SINE)
		_party_tween.set_ease(Tween.EASE_IN_OUT)
		_party_tween.tween_property(_party_marker, "position", target, DS.DUR_SLOW)
	else:
		_party_marker.position = target


func _reset_journey_controls() -> void:
	_journey_timer.stop()
	_travel_button.visible = true
	_continue_button.visible = false
	_cancel_button.visible = false
	_prompt_overlay.visible = false
	_party_marker.visible = false
	_set_destination_markers_disabled(false)


func _set_destination_markers_disabled(disabled: bool) -> void:
	for location: Dictionary in _locations:
		var marker: Button = _markers.get(StringName(location["id"])) as Button
		if marker != null:
			marker.disabled = disabled or not _is_selectable(location)


func _has_live_plan() -> bool:
	return (
		GameFlow.travel_plan != null
		and GameFlow.travel_plan.state in [TravelPlan.State.EN_ROUTE, TravelPlan.State.AVOID_PROMPT]
	)


func _is_selectable(location: Dictionary) -> bool:
	if _has_live_plan() or not bool(location.get("is_discovered", false)):
		return false
	var location_id := StringName(location.get("id", &""))
	return location_id != _origin_id and not WorldMapRegistry.route_between(_origin_id, location_id).is_empty()


func _resolve_origin_id() -> StringName:
	if _has_live_plan():
		return GameFlow.travel_plan.origin_id
	var current_scene := _current_scene_path()
	for location: Dictionary in _locations:
		if str(location.get("scene_path", "")) == current_scene:
			return StringName(location["id"])
	# Directly-instanced integration scenes have no underlying gameplay scene.
	# The first discovered registry location gives those tests a deterministic origin.
	for location: Dictionary in _locations:
		if bool(location.get("is_discovered", false)):
			return StringName(location["id"])
	return &""


func _location_row(location_id: StringName) -> Dictionary:
	for location: Dictionary in _locations:
		if StringName(location.get("id", &"")) == location_id:
			return location
	return {}


func _pending_encounter_id() -> StringName:
	if GameFlow.travel_plan == null:
		return &""
	for slot: Dictionary in GameFlow.travel_plan.encounter_schedule:
		if (
			not bool(slot.get("resolved", false))
			and int(slot.get("at_step", 0)) <= GameFlow.travel_plan.progress_step
		):
			return StringName(slot.get("encounter_id", &""))
	return &""


static func _display_name(identifier: StringName) -> String:
	return String(identifier).replace("-", " ").replace("_", " ").capitalize()


func _label(node_name: String, text: String, variation: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.theme_type_variation = variation
	return label


func _current_scene_path() -> String:
	var current := get_tree().current_scene
	return current.scene_file_path if current != null else ""


class WorldRouteCanvas:
	extends Control

	var has_backdrop := false
	var _locations: Array[Dictionary] = []
	var _routes: Array[Dictionary] = []
	var _active_route: Dictionary = {}


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)


	func configure(
		locations: Array[Dictionary], routes: Array[Dictionary], active_route: Dictionary
	) -> void:
		_locations = locations
		_routes = routes
		_active_route = active_route
		queue_redraw()


	func _draw() -> void:
		if has_backdrop:
			# Wave AF: the painterly atlas plate sits beneath this canvas — a
			# translucent scrim keeps marks/routes readable without hiding it,
			# and the surveyor grid would fight the hand-inked terrain.
			draw_rect(Rect2(Vector2.ZERO, size), Color(DS.STONE_0, 0.35))
		else:
			draw_rect(Rect2(Vector2.ZERO, size), DS.STONE_0)
			for x: int in range(0, int(size.x), DS.SPACE_9):
				draw_line(Vector2(x, 0.0), Vector2(x, size.y), DS.STONE_2, DS.BORDER_TRIM_W)
			for y: int in range(0, int(size.y), DS.SPACE_9):
				draw_line(Vector2(0.0, y), Vector2(size.x, y), DS.STONE_2, DS.BORDER_TRIM_W)
		for route: Dictionary in _routes:
			var from := _point_for(StringName(route.get("origin_id", &"")))
			var to := _point_for(StringName(route.get("destination_id", &"")))
			if from == Vector2.INF or to == Vector2.INF:
				continue
			var is_active: bool = (
				not _active_route.is_empty() and route.get("id") == _active_route.get("id")
			)
			var color: Color = DS.BRONZE_3 if is_active else DS.IRON_3
			var width: float = float(DS.BORDER_TRIM_W * 2 if is_active else DS.BORDER_TRIM_W)
			draw_line(from, to, color, width, true)


	func _point_for(location_id: StringName) -> Vector2:
		for location: Dictionary in _locations:
			if StringName(location.get("id", &"")) == location_id:
				return Vector2(location["map_coordinate"]) * size
		return Vector2.INF
