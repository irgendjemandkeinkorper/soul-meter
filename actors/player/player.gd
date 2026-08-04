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

const FOOTSTEP_SPACING: float = 78.0
const FOOTSTEP_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/footstep_grass_000.ogg"),
	preload("res://assets/audio/sfx/footstep_grass_001.ogg"),
	preload("res://assets/audio/sfx/footstep_grass_002.ogg"),
	preload("res://assets/audio/sfx/footstep_grass_003.ogg"),
	preload("res://assets/audio/sfx/footstep_grass_004.ogg"),
]

@onready var _footstep_player := $FootstepPlayer as AudioStreamPlayer

var _distance_since_footstep := 0.0
var _last_footstep_index := -1
var _footstep_rng := RandomNumberGenerator.new()


func _ready() -> void:
	var camera := $Camera2D as Camera2D
	camera.limit_left = camera_bounds.position.x
	camera.limit_top = camera_bounds.position.y
	camera.limit_right = camera_bounds.end.x
	camera.limit_bottom = camera_bounds.end.y
	camera.position_smoothing_speed = 7.0
	_footstep_rng.randomize()


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not direction.is_zero_approx():
		facing_direction = direction.normalized()
		if absf(facing_direction.x) > 0.01:
			_sprite.flip_h = facing_direction.x < 0.0
	velocity = direction * speed
	move_and_slide()
	_update_footsteps(direction)


func _update_footsteps(direction: Vector2) -> void:
	var distance_moved := get_last_motion().length()
	if direction.is_zero_approx() or distance_moved <= 0.01:
		return
	_distance_since_footstep += distance_moved
	if _distance_since_footstep < FOOTSTEP_SPACING:
		return
	_distance_since_footstep = fmod(_distance_since_footstep, FOOTSTEP_SPACING)
	_play_footstep()


func _play_footstep() -> void:
	var next_index := _footstep_rng.randi_range(0, FOOTSTEP_STREAMS.size() - 1)
	if FOOTSTEP_STREAMS.size() > 1 and next_index == _last_footstep_index:
		next_index = (next_index + _footstep_rng.randi_range(1, FOOTSTEP_STREAMS.size() - 1)) % FOOTSTEP_STREAMS.size()
	_last_footstep_index = next_index
	_footstep_player.stream = FOOTSTEP_STREAMS[next_index]
	_footstep_player.pitch_scale = _footstep_rng.randf_range(0.96, 1.04)
	_footstep_player.play()
