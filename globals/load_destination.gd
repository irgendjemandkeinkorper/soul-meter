class_name LoadDestination
extends RefCounted
## Stable, scene-agnostic request for loading a gameplay location.

var location_id: StringName
var spawn_id: StringName
var position: Vector2
var has_position: bool


func _init(
	p_location_id: StringName,
	p_spawn_id: StringName = &"default",
	p_position: Vector2 = Vector2.ZERO,
	p_has_position: bool = false
) -> void:
	location_id = p_location_id
	spawn_id = p_spawn_id
	position = p_position
	has_position = p_has_position
