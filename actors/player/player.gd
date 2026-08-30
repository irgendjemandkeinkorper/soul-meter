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
var _keyboard_step_origin: Vector2 = Vector2.ZERO
var _keyboard_step_stuck_time: float = 0.0
var _keyboard_step_prev_distance: float = INF

## A grid step closing less than this much distance-to-target per second is wedged
## (physics can hold the body short of an open cell — see ClickMoveController's
## STUCK_SPEED_EPSILON note about non-zero-width bodies).
const STEP_STUCK_SPEED_EPSILON: float = 12.0
## How far outside the scene's camera bounds a step target may lie. One cell of
## slack keeps edge cells reachable when bounds hug the playfield exactly.
const CELL_STEP_BOUNDS_MARGIN: float = 64.0
## How long a wedged step may stall before recovery snaps the player back to the
## step's origin center and clears the target.
const STEP_STUCK_TIME_THRESHOLD: float = 0.35


func _ready() -> void:
	var camera := $Camera2D as Camera2D
	camera.limit_left = camera_bounds.position.x
	camera.limit_top = camera_bounds.position.y
	camera.limit_right = camera_bounds.end.x
	camera.limit_bottom = camera_bounds.end.y
	camera.position_smoothing_speed = 7.0
	_footstep_rng.randomize()
	_click_controller.move_refused.connect(func(refusal: Dictionary) -> void: move_refused.emit(refusal))
	# Deferred so sibling TileMapLayers are ready; normalizes authored spawn points
	# onto the grid the same way loaded positions are.
	rest_on_grid.call_deferred()


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
	elif target_is_keyboard_step:
		_track_step_wedge(delta)
	_update_footsteps(direction)


## Bounded no-progress recovery for keyboard steps: `resolve_step_cell` only proves the
## destination CELL is open — a physics body (a dynamic actor that arrived after the
## occupancy sync, or a corner seam) can still hold this body short of the center
## forever. Click paths already recover via ClickMoveController's stuck tracking;
## this is the keyboard equivalent. Recovery snaps back to the step's origin center
## (at most one cell away, and open a moment ago) so the player always rests on-grid.
func _track_step_wedge(delta: float) -> void:
	# Progress is distance actually closed toward the target this frame — not the
	# last slide motion, which understates multi-slide physics frames at low FPS.
	var distance: float = global_position.distance_to(_keyboard_step_target)
	var progress: float = _keyboard_step_prev_distance - distance
	_keyboard_step_prev_distance = distance
	if progress > STEP_STUCK_SPEED_EPSILON * delta:
		_keyboard_step_stuck_time = 0.0
		return
	_keyboard_step_stuck_time += delta
	if _keyboard_step_stuck_time < STEP_STUCK_TIME_THRESHOLD:
		return
	global_position = _keyboard_step_origin
	velocity = Vector2.ZERO
	_has_keyboard_step_target = false
	_keyboard_step_stuck_time = 0.0


func _begin_keyboard_step(grid: IsoGrid, screen_direction: Vector2) -> void:
	_click_controller.sync_occupancy()
	var current_cell: Vector2i = grid.world_to_cell(global_position)
	var resolved_cell: Variant = grid.resolve_step_cell(current_cell, screen_direction, self)
	if resolved_cell == null:
		return
	var step_target: Vector2 = grid.cell_to_world(resolved_cell as Vector2i)
	# The virtual lattice is unbounded, so movement needs explicit bounds: without
	# them, a gap in the boundary colliders (a travel-exit opening) lets held
	# movement walk into the void forever. Camera bounds alone are a VIEW rect —
	# an iso diamond's left/top corners project to negative world coordinates —
	# so the bound is their union with the painted map's world extent.
	var movement_bounds: Rect2 = (
		Rect2(camera_bounds).merge(grid.world_bounds()).grow(CELL_STEP_BOUNDS_MARGIN)
	)
	if not movement_bounds.has_point(step_target):
		var target_gap: Vector2 = (
			step_target.clamp(movement_bounds.position, movement_bounds.end) - step_target
		)
		var current_gap: Vector2 = (
			global_position.clamp(movement_bounds.position, movement_bounds.end)
			- global_position
		)
		# Escape valve: a body already outside bounds may always step back toward
		# them — refusing everything would strand it permanently.
		if target_gap.length_squared() >= current_gap.length_squared():
			return
	# The exact position the step began from — NOT the computed cell center. At a
	# wedge the body sits between centers and world_to_cell can identify a cell
	# whose center lies past the obstacle; returning to where the body actually
	# stood is the only recovery position guaranteed physically legal.
	_keyboard_step_origin = global_position
	_keyboard_step_target = step_target
	_has_keyboard_step_target = true
	_keyboard_step_stuck_time = 0.0
	_keyboard_step_prev_distance = INF


## Normalizes the avatar onto the movement grid (Wave Q: the player rests on cell
## centers). Called deferred from _ready and after SaveGame applies a loaded
## position — a save made mid-step stores an off-center position, and without this
## the player would rest between cells until the next move. No-grid scenes and
## positions with no open cell nearby keep the exact stored placement
## (GridPlacement's bounded-snap contract). The move to the center is collision
## swept: a grid-open center can still lie across a physics-only obstacle the
## lattice knows nothing about, and a stored legal position always beats
## normalizing through a wall.
func rest_on_grid() -> void:
	var target: Variant = GridPlacement.open_cell_center_near(self, global_position)
	if target == null:
		return
	var offset: Vector2 = (target as Vector2) - global_position
	if not offset.is_zero_approx() and test_move(global_transform, offset):
		return
	global_position = target as Vector2


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
