class_name AmbientVillager
extends Node2D
## Non-interactable background townsfolk that walk a small authored local route.

@export_group("Appearance")
@export var villager_texture: Texture2D

@export_group("Local route")
@export var local_waypoints: PackedVector2Array = PackedVector2Array(
	[Vector2.ZERO, Vector2(48.0, 0.0)]
)
@export_range(8.0, 80.0, 1.0) var wander_speed: float = 22.0
@export_range(0.25, 8.0, 0.05) var pause_duration: float = 2.0
@export_range(0.0, 8.0, 0.05) var initial_pause: float = 0.0
@export_range(0, 3, 1) var starting_waypoint: int = 0

const ARRIVAL_DISTANCE_SQUARED := 1.0

var _route_origin: Vector2
var _target_index: int = 0
var _pause_remaining: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_route_origin = position
	if villager_texture != null:
		_sprite.texture = villager_texture
	UnitArt.apply_world_scale(_sprite, get_node_or_null("Shadow"))
	if local_waypoints.is_empty():
		set_physics_process(false)
		return
	_target_index = clampi(starting_waypoint, 0, local_waypoints.size() - 1)
	# initial_pause is ADDITIVE with the first arrival pause when starting on a
	# waypoint — deliberate: per-instance values stagger the crowd so the town
	# doesn't wake in lockstep (gate r1 risk note, documented as intended).
	_pause_remaining = initial_pause


func _physics_process(delta: float) -> void:
	if _pause_remaining > 0.0:
		_pause_remaining = maxf(_pause_remaining - delta, 0.0)
		return

	var target := _route_origin + local_waypoints[_target_index]
	var movement := target - position
	if movement.length_squared() <= ARRIVAL_DISTANCE_SQUARED:
		position = target
		_target_index = (_target_index + 1) % local_waypoints.size()
		_pause_remaining = pause_duration
		return

	position = position.move_toward(target, wander_speed * delta)
	if absf(movement.x) > 0.01:
		_sprite.flip_h = movement.x < 0.0


func authored_world_bounds() -> Rect2:
	if local_waypoints.is_empty():
		return Rect2(_route_origin, Vector2.ZERO)
	var bounds := Rect2(_route_origin + local_waypoints[0], Vector2.ZERO)
	for waypoint: Vector2 in local_waypoints:
		bounds = bounds.expand(_route_origin + waypoint)
	return bounds
