class_name Player
extends CharacterBody2D
## Field-exploration avatar for the 2D overworld (design doc §6: real-time 2D field).
## Grid-bound 8-direction movement, plus Fallout-2-style click-to-move (D4, GH #162,
## docs/architecture-tactical-and-navigation.md §2.5). `ClickMoveController` (a sibling
## component, `$ClickMoveController`) owns the path queue; this script stays the only
## thing that touches `velocity` and calls `move_and_slide()` — the controller supplies
## a direction, never movement itself. WASD always wins over an in-progress click path
## (FR-607: keyboard is a debug AND accessibility path, not just a fallback).

## Movement speed in pixels/second. PROVISIONAL: field traversal balance value.
@export var speed: float = 260.0
## Held-Shift sprint (the "sprint" input action) multiplies field speed by this.
## PROVISIONAL: field traversal balance multiplier.
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
var _has_keyboard_step_target: bool = false
var _keyboard_step_target: Vector2 = Vector2.ZERO


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
	var direction: Vector2 = Vector2.ZERO
	var movement_target: Vector2 = Vector2.ZERO
	var has_movement_target: bool = false
	var target_is_keyboard_step: bool = false
	var grid: IsoGrid = _click_controller.get_iso_grid()

	if grid == null:
		# Launchable scenes without navigation keep the legacy free-movement behavior.
		_has_keyboard_step_target = false
		direction = keyboard_direction
		if not keyboard_direction.is_zero_approx():
			# WASD always wins: cancel any in-progress click path (FR-607).
			_click_controller.cancel_path()
		else:
			direction = _click_controller.get_steering_direction(global_position, delta)
	else:
		if not keyboard_direction.is_zero_approx():
			# WASD always wins: cancel any in-progress click path (FR-607).
			_click_controller.cancel_path()
			if not _has_keyboard_step_target:
				_begin_keyboard_step(grid, keyboard_direction)
		if _has_keyboard_step_target:
			movement_target = _keyboard_step_target
			has_movement_target = true
			target_is_keyboard_step = true
		elif keyboard_direction.is_zero_approx():
			var click_target: Variant = _click_controller.get_steering_target(global_position, delta)
			if click_target != null:
				movement_target = click_target as Vector2
				has_movement_target = true
		if has_movement_target:
			direction = global_position.direction_to(movement_target)
	if not direction.is_zero_approx():
		facing_direction = direction.normalized()
		if absf(facing_direction.x) > 0.01:
			_sprite.flip_h = facing_direction.x < 0.0
	var current_speed := speed
	if InputMap.has_action("sprint") and Input.is_action_pressed("sprint"):
		current_speed *= sprint_multiplier
	velocity = direction * current_speed
	if has_movement_target and delta > 0.0:
		var distance_to_target: float = global_position.distance_to(movement_target)
		velocity = direction * minf(current_speed, distance_to_target / delta)
	move_and_slide()
	if (
		has_movement_target
		and global_position.distance_to(movement_target) <= ClickMoveController.ARRIVAL_EPSILON
	):
		_complete_grid_arrival(
			movement_target,
			target_is_keyboard_step,
			grid,
			keyboard_direction
		)
	_update_footsteps(direction)


func _begin_keyboard_step(grid: IsoGrid, screen_direction: Vector2) -> void:
	_click_controller.sync_occupancy()
	var current_cell: Vector2i = grid.world_to_cell(global_position)
	var resolved_cell: Variant = grid.resolve_step_cell(current_cell, screen_direction, self)
	if resolved_cell == null:
		return
	_keyboard_step_target = grid.cell_to_world(resolved_cell as Vector2i)
	_has_keyboard_step_target = true


func _complete_grid_arrival(
	target: Vector2,
	is_keyboard_step: bool,
	grid: IsoGrid,
	keyboard_direction: Vector2
) -> void:
	# Player remains the sole authority that moves the body, including exact center snaps.
	global_position = target
	velocity = Vector2.ZERO
	if not is_keyboard_step:
		_click_controller.complete_current_waypoint(target)
		return
	_has_keyboard_step_target = false
	if not keyboard_direction.is_zero_approx():
		# Preselect now so a held key continues on the next physics tick without an idle tick.
		_begin_keyboard_step(grid, keyboard_direction)


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
