class_name Player
extends CharacterBody2D
## Field-exploration avatar for the 2D overworld (design doc §6: real-time 2D field).
## Top-down 8-direction movement, plus Fallout-2-style click-to-move (D4, GH #162,
## docs/architecture-tactical-and-navigation.md §2.5). `ClickMoveController` (a sibling
## component, `$ClickMoveController`) owns the path queue; this script stays the only
## thing that touches `velocity` and calls `move_and_slide()` — the controller supplies
## a direction, never movement itself. WASD always wins over an in-progress click path
## (FR-607: keyboard is a debug AND accessibility path, not just a fallback).

## Movement speed in pixels/second.
@export var speed: float = 260.0
## Held-Shift sprint (the "sprint" input action) multiplies field speed by this.
@export var sprint_multiplier: float = 2.0
@export var camera_bounds := Rect2i(0, 0, 1600, 1000)

## Re-emits `ClickMoveController.move_refused` so a HUD/UI layer can surface an
## unreachable click without knowing anything about pathfinding.
signal move_refused(refusal: Dictionary)

var facing_direction: Vector2 = Vector2.DOWN

## Reachable identity data for the avatar this scene shows, mirroring how NPCs already
## expose their PartyMember (see actors/party_followers/). Chargen (#98/#129) writes
## into GameState.party[0]; this is a thin accessor, not a second source of truth —
## combat stat *usage* stays out of scope here (the battle system's job).
func party_member() -> PartyMember:
	return GameState.protagonist()

@onready var _sprite := $Sprite2D as Sprite2D
@onready var _click_controller := $ClickMoveController as ClickMoveController

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
	_click_controller.move_refused.connect(func(refusal: Dictionary) -> void: move_refused.emit(refusal))


func _physics_process(delta: float) -> void:
	var keyboard_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := keyboard_direction
	if not keyboard_direction.is_zero_approx():
		# WASD always wins: cancel any in-progress click path (FR-607).
		_click_controller.cancel_path()
	else:
		direction = _click_controller.get_steering_direction(global_position, delta)
	if not direction.is_zero_approx():
		facing_direction = direction.normalized()
		if absf(facing_direction.x) > 0.01:
			_sprite.flip_h = facing_direction.x < 0.0
	var current_speed := speed
	if InputMap.has_action("sprint") and Input.is_action_pressed("sprint"):
		current_speed *= sprint_multiplier
	velocity = direction * current_speed
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
