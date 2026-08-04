class_name BuildingInterior
extends Node2D
## Shared structural room used by each named building interior.

@export var building_name: String = "BUILDING"
@export var exit_transition_id: StringName = &""
@export var floor_color := Color(0.12, 0.12, 0.14, 1.0)
@export var accent_color := Color(0.55, 0.4, 0.22, 1.0)


func _enter_tree() -> void:
	var exit_door := get_node_or_null("ExitDoor") as BuildingDoor
	if exit_door == null:
		push_error("Building interior '%s' is missing ExitDoor." % name)
		return
	exit_door.transition_id = exit_transition_id


func _ready() -> void:
	($Floor as Polygon2D).color = floor_color
	($AccentRug as Polygon2D).color = accent_color
	($Title as Label).text = building_name.to_upper()
