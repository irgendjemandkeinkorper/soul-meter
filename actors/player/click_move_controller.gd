class_name ClickMoveController
extends Node
## Fallout-2-style click-to-move for the overworld (D4, GH #162,
## docs/architecture-tactical-and-navigation.md §2.5). A sibling component of
## `player.gd`: `Player` stays a `CharacterBody2D` and keeps calling
## `move_and_slide()` every physics frame. This controller never touches
## velocity or the physics body directly — it only tracks a queue of world
## waypoints and answers "which direction is the next one in?" when asked.
##
## Built on `world/nav/iso_grid.gd` (`IsoGrid`), the ONE `AStarGrid2D` shared
## with the tactical layer (§2.2). This script never talks to `AStarGrid2D`
## directly.
##
## Refusal shape (FR-606's taxonomy, extended to the overworld per the
## amendment's §2.2 and this issue's DoD): `{allowed, blocked_by,
## nearest_unblock, message}`. An unreachable click emits `move_refused`
## with a populated dictionary — never silence. `player.gd` re-emits this
## signal so a future HUD/UI listener can surface it without this controller
## knowing anything about UI.

signal move_refused(refusal: Dictionary)
signal path_started(path: Array[Vector2])
signal path_finished()

## How close (px) counts as "arrived at this waypoint".
const ARRIVAL_EPSILON: float = 6.0
## Ring search radius (cells) when looking for a walkable cell near a solid click.
const OBSTACLE_SEARCH_RADIUS: int = 6
## How often (seconds) to re-bake obstacles and re-route an in-progress path.
## Cheap per §2.5 — "the calculation is cheap. Its absence causes the classic
## symptom: the actor walks into a wall forever."
const REPATH_INTERVAL: float = 0.35
## A CharacterBody2D has width; a waypoint-to-waypoint straight line that just
## grazes a solid tile's corner can wedge the body even though the AStarGrid
## itself never "cut the corner" (that guarantee is about cell adjacency, not
## about a swept box with non-zero size). Below this much movement per second
## while a path is active counts as wedged.
const STUCK_SPEED_EPSILON: float = 12.0
## How long the player must sit below STUCK_SPEED_EPSILON before we treat it
## as wedged and skip ahead to the next waypoint.
const STUCK_TIME_THRESHOLD: float = 0.4
## The player has a non-zero collision body. Keep its centre one grid cell
## away from static collision diamonds so a legal AStar path is walkable by
## the CharacterBody2D rather than merely by a dimensionless point.
const STATIC_CLEARANCE_CELLS: int = 1

@export var enabled: bool = true

var _player: Node2D
var _iso_grid: IsoGrid
var _ground: TileMapLayer
var _blocking: TileMapLayer
var _waypoints: Array[Vector2] = []
var _final_destination: Vector2
var _has_destination: bool = false
var _repath_timer: Timer
var _last_seen_position: Vector2 = Vector2.INF
var _stuck_time: float = 0.0


func _ready() -> void:
	_player = get_parent() as Node2D
	_rebuild_grid()
	_repath_timer = Timer.new()
	_repath_timer.wait_time = REPATH_INTERVAL
	_repath_timer.one_shot = false
	_repath_timer.timeout.connect(_on_repath_timer_timeout)
	add_child(_repath_timer)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or _player == null:
		return
	var translated: Dictionary = translate_pointer_event(event, _player.get_canvas_transform())
	if not translated["accepted"]:
		return
	var world_position: Vector2 = translated["world_position"]
	request_move_to(world_position)
	get_viewport().set_input_as_handled()


## Converts a pressed primary-button event from screen space to world space.
## Rejected events return `{accepted: false}`; accepted events additionally
## include `world_position: Vector2`. Keeping this translation independent of a
## Viewport makes the headless input contract directly testable.
static func translate_pointer_event(
	event: InputEvent,
	canvas_transform: Transform2D
) -> Dictionary:
	if not event is InputEventMouseButton:
		return {"accepted": false}
	var button := event as InputEventMouseButton
	if not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return {"accepted": false}
	# Use the event's own position rather than the live mouse position. The
	# pointer can move before this handler runs, and simulated input does not
	# reliably update the live cursor in a headless run.
	return {
		"accepted": true,
		"world_position": canvas_transform.affine_inverse() * button.position,
	}


## Locates the shared IsoGrid substrate for whatever scene the player is in.
## Both `world/starting_town.tscn` and `world/test_room.tscn` (and any future
## overworld scene) place a `TileMapLayer` named `IsometricGround` and,
## optionally, one named `Blocking` somewhere under the scene root — the same
## names `test/integration/test_blocking_layer.gd` already relies on.
func _rebuild_grid() -> void:
	if _player == null:
		return
	var search_root: Node = _player.get_tree().root if _player.is_inside_tree() else null
	if search_root == null:
		_iso_grid = null
		return
	_ground = search_root.find_child("IsometricGround", true, false) as TileMapLayer
	_blocking = search_root.find_child("Blocking", true, false) as TileMapLayer
	if _ground == null:
		_iso_grid = null
		return
	_iso_grid = IsoGrid.new()
	_iso_grid.build(_ground, _blocking, STATIC_CLEARANCE_CELLS, true)
	_sync_occupancy()


## Refreshes the grid's view of where standing actors are (GH #190). Static geometry comes from
## the painted `Blocking` layer; NPCs are not in it and never will be. Both go into the same
## `IsoGrid`, so this controller still asks exactly one question about passability.
func _sync_occupancy() -> void:
	if _iso_grid == null or _ground == null:
		return
	NavOccupancy.sync(_iso_grid, _ground.get_parent(), _player)


## Requests a path to `target_world`. Returns the allowed shape
## `{allowed: true, blocked_by: &"", nearest_unblock: null, message: "",
## path: Array[Vector2]}` on success, or the refusal shape `{allowed: false,
## blocked_by: StringName, nearest_unblock: Variant, message: String}` on
## failure — and emits `move_refused` in that case. Also the entry point
## `_unhandled_input` calls on a real click, so a direct call here exercises
## the same code path production input does.
func request_move_to(target_world: Vector2) -> Dictionary:
	if _iso_grid == null:
		return _refuse(&"blocked_by_no_navigation", null, "No navigation grid is available here.")

	# Standing actors move between clicks, so their cells are re-read here rather than only on
	# the repath timer — a click is exactly when the answer has to be current.
	_sync_occupancy()

	var target_cell := _iso_grid.world_to_cell(target_world)
	# Out of the map entirely is "unreachable", not "obstructed" — two different causes must
	# keep two different `blocked_by` tags (amendment §2.2's refusal taxonomy). `is_blocked_for`
	# answers true for both, so bounds are checked first.
	if not _iso_grid.is_in_bounds(target_cell):
		return _refuse(&"blocked_by_unreachable", null, "There is no route to that spot.")
	if _iso_grid.is_blocked_for(target_cell, _player):
		var nearest: Variant = _find_nearest_open_cell(target_cell)
		return _refuse(&"blocked_by_obstacle", nearest, "Something is in the way.")

	var path := _iso_grid.path_world(_player.global_position, target_world, _player)
	if path.is_empty():
		return _refuse(&"blocked_by_unreachable", null, "There is no route to that spot.")

	_waypoints.clear()
	for point in path:
		_waypoints.append(point)
	# AStarGrid2D includes the start cell. Repaths can begin anywhere inside
	# that cell, so its centre may already be behind the moving body.
	if (
		_waypoints.size() > 1
		and _iso_grid.world_to_cell(_waypoints[0])
			== _iso_grid.world_to_cell(_player.global_position)
	):
		_waypoints.remove_at(0)

	_final_destination = target_world
	_has_destination = true
	_repath_timer.start()
	_last_seen_position = Vector2.INF
	_stuck_time = 0.0

	var accepted: Array[Vector2] = _waypoints.duplicate()
	path_started.emit(accepted)
	return {
		"allowed": true,
		"blocked_by": &"",
		"nearest_unblock": null,
		"message": "",
		"path": accepted,
	}


func has_path() -> bool:
	return not _waypoints.is_empty()


## The keyboard stepper consumes this same grid instance; it must never build a second
## AStarGrid2D for the player scene.
func get_iso_grid() -> IsoGrid:
	return _iso_grid


## Refreshes dynamic actor occupancy immediately before a keyboard step is selected.
func sync_occupancy() -> void:
	_sync_occupancy()


## Cancels any in-progress path. `player.gd` calls this the moment WASD input
## is pressed, so keyboard movement always wins over a stale click (FR-607).
func cancel_path() -> void:
	if _waypoints.is_empty() and not _has_destination:
		return
	_waypoints.clear()
	_has_destination = false
	_repath_timer.stop()
	_last_seen_position = Vector2.INF
	_stuck_time = 0.0


## Called by `player.gd` every physics frame when no keyboard input is held.
## Pops any waypoint the player has already reached, then returns a
## normalized direction toward the next one, or `Vector2.ZERO` if the path
## is finished (or there isn't one). `delta` drives the stuck-recovery timer.
func get_steering_direction(from_position: Vector2, delta: float) -> Vector2:
	_pop_reached_waypoints(from_position)
	if _waypoints.is_empty():
		_last_seen_position = Vector2.INF
		_stuck_time = 0.0
		return Vector2.ZERO
	_track_stuck(from_position, delta)
	if _waypoints.is_empty():
		return Vector2.ZERO
	return from_position.direction_to(_waypoints[0])


## Returns the exact cell-center waypoint without consuming it inside the arrival epsilon.
## `Player` uses this target to cap velocity and perform the authoritative exact snap.
func get_steering_target(from_position: Vector2, delta: float) -> Variant:
	if _waypoints.is_empty():
		_last_seen_position = Vector2.INF
		_stuck_time = 0.0
		return null
	_track_stuck(from_position, delta)
	if _waypoints.is_empty():
		return null
	return _waypoints[0]


## Consumes the waypoint only after `Player` has snapped its body to that exact center.
func complete_current_waypoint(waypoint: Vector2) -> void:
	if _waypoints.is_empty() or not _waypoints[0].is_equal_approx(waypoint):
		return
	_waypoints.remove_at(0)
	_last_seen_position = Vector2.INF
	_stuck_time = 0.0
	if _waypoints.is_empty() and _has_destination:
		_has_destination = false
		_repath_timer.stop()
		path_finished.emit()


## A waypoint-to-waypoint straight line has no width; the player's collision
## box does. When the box wedges against a corner it never truly "cut" in
## cell space, `move_and_slide()` can zero out real progress indefinitely —
## the classic symptom §2.5 warns a missing repath causes, just from a
## slightly different cause (geometry, not a changed obstacle). Recover by
## dropping the waypoint we're wedged against, same as an obstacle change.
func _track_stuck(from_position: Vector2, delta: float) -> void:
	if _last_seen_position != Vector2.INF and delta > 0.0:
		var speed := from_position.distance_to(_last_seen_position) / delta
		if speed < STUCK_SPEED_EPSILON:
			_stuck_time += delta
		else:
			_stuck_time = 0.0
	_last_seen_position = from_position
	if _stuck_time < STUCK_TIME_THRESHOLD:
		return
	_stuck_time = 0.0
	if _waypoints.size() > 1:
		_waypoints.remove_at(0)
	elif _has_destination:
		var destination := _final_destination
		_waypoints.clear()
		_has_destination = false
		request_move_to(destination)


func _pop_reached_waypoints(from_position: Vector2) -> void:
	while not _waypoints.is_empty() and _waypoint_was_reached(from_position, _waypoints[0]):
		_waypoints.remove_at(0)
	if _waypoints.is_empty() and _has_destination:
		_has_destination = false
		_repath_timer.stop()
		path_finished.emit()


func _waypoint_was_reached(from_position: Vector2, waypoint: Vector2) -> bool:
	if from_position.distance_to(waypoint) <= ARRIVAL_EPSILON:
		return true
	if _last_seen_position == Vector2.INF:
		return false
	var closest := Geometry2D.get_closest_point_to_segment(
		waypoint,
		_last_seen_position,
		from_position
	)
	return closest.distance_to(waypoint) <= ARRIVAL_EPSILON


## Re-bakes the obstacle mask and re-routes the remaining path. Wired to a
## timer while a path is active; also callable directly (tests, or a future
## door/NPC-blocking signal) to force an immediate recalculation.
func refresh_path() -> void:
	if not _has_destination or _player == null:
		return
	if _ground != null:
		_iso_grid.build(_ground, _blocking, STATIC_CLEARANCE_CELLS, true)
	var destination := _final_destination
	var result := request_move_to(destination)
	if not bool(result.get("allowed", false)):
		# The route just became impossible (e.g. an NPC now stands in the
		# only doorway). Stop in place rather than walk into the obstacle.
		_waypoints.clear()
		_has_destination = false
		_repath_timer.stop()


func _on_repath_timer_timeout() -> void:
	refresh_path()


func _find_nearest_open_cell(center: Vector2i) -> Variant:
	for radius in range(1, OBSTACLE_SEARCH_RADIUS + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var candidate := center + Vector2i(dx, dy)
				if not _iso_grid.is_blocked_for(candidate, _player):
					return _iso_grid.cell_to_world(candidate)
	return null


func _refuse(blocked_by: StringName, nearest_unblock: Variant, message: String) -> Dictionary:
	_waypoints.clear()
	_has_destination = false
	_repath_timer.stop()
	var refusal := {
		"allowed": false,
		"blocked_by": blocked_by,
		"nearest_unblock": nearest_unblock,
		"message": message,
	}
	move_refused.emit(refusal)
	return refusal
