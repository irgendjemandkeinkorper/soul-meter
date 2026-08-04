class_name PartyFollower
extends Node2D
## A presentation-only party member. It deliberately has no CollisionObject2D,
## so it cannot block movement or enter NPC/TravelExit detection areas.

const PartyMemberVisualsScript := preload(
	"res://actors/party_followers/party_member_visuals.gd"
)

@export_group("Trail movement")
@export_range(1.0, 800.0, 1.0) var follow_speed: float = 340.0

@export_group("Sway")
@export_range(0.0, 8.0, 0.05) var sway_amplitude: float = 1.5
@export_range(0.1, 4.0, 0.05) var sway_period: float = 1.25
@export_range(0.0, 5.0, 0.05) var sway_rotation_degrees: float = 0.75
@export_range(0.0, 6.283, 0.01) var sway_phase: float = 0.0

var party_member: PartyMember
var facing_direction: Vector2 = Vector2.DOWN
var _sway_elapsed: float = 0.0
var _is_moving: bool = false

@onready var _visual := $Visual as Node2D
@onready var _sprite := $Visual/Sprite2D as Sprite2D


func _ready() -> void:
	_apply_party_member()


func configure(member: PartyMember, phase: float) -> void:
	party_member = member
	sway_phase = fposmod(phase, TAU)
	if is_node_ready():
		_apply_party_member()


func snap_to(world_position: Vector2) -> void:
	global_position = world_position
	_is_moving = false


func follow_trail(target: Vector2, delta: float) -> void:
	var previous_position := global_position
	global_position = global_position.move_toward(target, follow_speed * delta)
	var movement := global_position - previous_position
	_is_moving = movement.length_squared() > 0.0001
	if _is_moving:
		facing_direction = movement.normalized()
		if absf(facing_direction.x) > 0.01:
			_sprite.flip_h = facing_direction.x < 0.0


func _process(delta: float) -> void:
	if _visual == null:
		return
	var period := maxf(sway_period, 0.001)
	_sway_elapsed = fposmod(_sway_elapsed + delta, period)
	var wave := sin((_sway_elapsed / period) * TAU + sway_phase)
	var strength := 1.0 if _is_moving else 0.65
	_visual.position.y = wave * sway_amplitude * strength
	_visual.rotation = deg_to_rad(sway_rotation_degrees) * wave * strength


func _apply_party_member() -> void:
	if party_member == null or _sprite == null:
		return
	_sprite.texture = PartyMemberVisualsScript.ensure_portrait(party_member)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
