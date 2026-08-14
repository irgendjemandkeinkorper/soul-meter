class_name RegionMapScreen
extends Screen
## FR-503 discovered-hub fast travel. This view contains no destination policy;
## registry validation, purchasing, and routing stay in their owning layers.

var _destination_list: VBoxContainer
var _status_label: Label
var _gp_label: Label


func _build() -> void:
	var content := _make_shell_window("Region Map")
	var explanation := Label.new()
	explanation.text = "Travel is available only to hubs you have visited."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(explanation)

	_gp_label = Label.new()
	_gp_label.name = "GPLabel"
	_gp_label.theme_type_variation = "EyebrowLabel"
	content.add_child(_gp_label)

	_destination_list = VBoxContainer.new()
	_destination_list.name = "DestinationList"
	_destination_list.theme_type_variation = "ScreenContentColumn"
	content.add_child(_destination_list)

	_status_label = Label.new()
	_status_label.name = "TravelStatus"
	_status_label.theme_type_variation = "EyebrowLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)
	_add_back_button(content)
	_refresh()
	if not GameFlow.last_travel_error.is_empty():
		GameFlow.last_travel_error = ""
		_status_label.text = "Travel failed. No GP was spent."


static func destinations_for(current_scene_path: String) -> Array[Dictionary]:
	var destinations: Array[Dictionary] = []
	for hub: Dictionary in FastTravelRegistry.all():
		var hub_id := StringName(hub["id"])
		if not GameState.is_fast_travel_hub_discovered(hub_id):
			continue
		var row := hub.duplicate(true)
		row["is_current"] = current_scene_path == str(hub["scene_path"])
		row["affordable"] = GameState.can_afford(int(hub["base_cost_gp"]))
		destinations.append(row)
	return destinations


func _refresh() -> void:
	_gp_label.text = "AVAILABLE  ·  %d GP" % GameState.gp
	for child: Node in _destination_list.get_children():
		child.queue_free()
	var destinations := destinations_for(_current_scene_path())
	if destinations.is_empty():
		var empty := Label.new()
		empty.name = "NoDiscoveredHubs"
		empty.text = "No travel hubs have been discovered yet."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_destination_list.add_child(empty)
		return
	for hub: Dictionary in destinations:
		_add_destination(hub)


func _add_destination(hub: Dictionary) -> void:
	var hub_id := StringName(hub["id"])
	var button := Button.new()
	button.name = "Hub_%s" % hub_id
	button.text = "%s  ·  %d GP" % [hub["display_name"], hub["base_cost_gp"]]
	if bool(hub["is_current"]):
		button.text += "  ·  CURRENT"
	button.disabled = bool(hub["is_current"]) or not bool(hub["affordable"])
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_destination_pressed.bind(hub_id))
	_destination_list.add_child(button)


func _on_destination_pressed(hub_id: StringName) -> void:
	var result: Dictionary = GameFlow.fast_travel(hub_id)
	if bool(result.get("ok", false)):
		return
	var messages := {
		"unknown_destination": "That destination is no longer available.",
		"undiscovered": "You have not discovered that hub.",
		"current_destination": "You are already at that hub.",
		"insufficient_gp": "You do not have enough GP for that journey.",
		"purchase_failed": "The travel purchase could not be completed.",
		"route_rejected": "The route could not be opened. No GP was spent.",
	}
	_status_label.text = messages.get(str(result.get("error", "")), "Travel failed. No GP was spent.")
	_refresh()


func _current_scene_path() -> String:
	var current := get_tree().current_scene
	return current.scene_file_path if current != null else ""
