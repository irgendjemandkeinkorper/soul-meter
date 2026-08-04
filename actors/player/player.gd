class_name Player
extends CharacterBody2D
## Field-exploration avatar for the 2D overworld (design doc §6: real-time 2D field).
## Top-down 8-direction movement. Deliberately minimal — the game-state singleton,
## interaction, and battle transition hang off this later.

## Movement speed in pixels/second.
@export var speed: float = 260.0
@export var camera_bounds := Rect2i(0, 0, 1600, 1000)

var facing_direction: Vector2 = Vector2.DOWN

@onready var _sprite := $Sprite2D as Sprite2D


func _ready() -> void:
	var camera := $Camera2D as Camera2D
	camera.limit_left = camera_bounds.position.x
	camera.limit_top = camera_bounds.position.y
	camera.limit_right = camera_bounds.end.x
	camera.limit_bottom = camera_bounds.end.y
	camera.position_smoothing_speed = 7.0


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not direction.is_zero_approx():
		facing_direction = direction.normalized()
		if absf(facing_direction.x) > 0.01:
			_sprite.flip_h = facing_direction.x < 0.0
	velocity = direction * speed
	move_and_slide()
