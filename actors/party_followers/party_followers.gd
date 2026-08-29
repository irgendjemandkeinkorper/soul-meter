class_name PartyFollowers
extends Node
## Maintains the player's visited isometric cells and places each
## presentation-only companion at a successively older cell center.

const FOLLOWER_SCENE: PackedScene = preload(
	"res://actors/party_followers/party_follower.tscn"
)

@export var player_path: NodePath = NodePath("../Player")
@export_group("Cell trail")
@export_range(32.0, 1000.0, 1.0) var teleport_reset_distance: float = 160.0
@export_group("Follower presentation")
@export_range(0.1, 6.283, 0.01) var sway_phase_step: float = 2.1

var _player: Node2D
var _ground: TileMapLayer
var _last_player_position: Vector2
var _fallback_target: Vector2
var _player_cell: Vector2i
var _has_player_cell: bool = false
var _cell_history: Array[Vector2i] = []
var _followers: Array[PartyFollower] = []


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		push_error("PartyFollowers could not find a Node2D at '%s'." % player_path)
		set_physics_process(false)
		return
	_ground = _find_ground()
	_last_player_position = _player.global_position
	_fallback_target = _last_player_position
	if _ground != null:
		_reset_cell_trail(_world_to_cell(_last_player_position))
	_sync_followers()
	if not GameState.party_changed.is_connected(_on_party_changed):
		GameState.party_changed.connect(_on_party_changed)


func _exit_tree() -> void:
	if GameState.party_changed.is_connected(_on_party_changed):
		GameState.party_changed.disconnect(_on_party_changed)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var current_position: Vector2 = _player.global_position
	if current_position.distance_to(_last_player_position) > teleport_reset_distance:
		_reset_trail(current_position)
	else:
		_last_player_position = current_position
		if _ground == null:
			_fallback_target = current_position
		else:
			_record_cell(_world_to_cell(current_position))

	for index in _followers.size():
		_followers[index].follow_trail(trail_target_for(index), delta)


func follower_count() -> int:
	return _followers.size()


func followers() -> Array[PartyFollower]:
	return _followers.duplicate()


func trail_target_for(follower_index: int) -> Vector2:
	if _ground == null or not _has_player_cell or _cell_history.is_empty():
		return _fallback_target
	if follower_index < 0:
		return _cell_to_world(_player_cell)
	var history_index: int = mini(follower_index + 1, _cell_history.size() - 1)
	return _cell_to_world(_cell_history[history_index])


func _on_party_changed() -> void:
	_sync_followers()


func _sync_followers() -> void:
	if _player == null:
		return
	var current_by_id: Dictionary = {}
	for follower in _followers:
		if follower.party_member != null:
			current_by_id[follower.party_member.id] = follower

	var next_followers: Array[PartyFollower] = []
	var companions: Array[PartyMember] = GameState.companions()
	for member in companions:
		if member == null:
			continue
		var follower: PartyFollower = current_by_id.get(member.id) as PartyFollower
		if follower != null:
			current_by_id.erase(member.id)
		else:
			follower = FOLLOWER_SCENE.instantiate() as PartyFollower
			follower.name = "Follower_%s" % member.id.replace("-", "_")
			add_child(follower)
			follower.snap_to(trail_target_for(next_followers.size()))
		follower.configure(member, float(next_followers.size()) * sway_phase_step)
		next_followers.append(follower)

	for orphan_value: Variant in current_by_id.values():
		var orphan := orphan_value as PartyFollower
		if orphan != null:
			orphan.queue_free()

	_followers = next_followers
	for index in _followers.size():
		move_child(_followers[index], index)
	_trim_cell_history()


func _find_ground() -> TileMapLayer:
	# Search the manager's field scene, not the SceneTree root: tests and scene
	# transitions can briefly keep more than one IsometricGround alive.
	var search_root: Node = get_parent()
	if search_root == null:
		return null
	return search_root.find_child("IsometricGround", true, false) as TileMapLayer


func _record_cell(cell: Vector2i) -> void:
	if not _has_player_cell:
		_reset_cell_trail(cell)
		return
	if cell == _player_cell:
		return
	_player_cell = cell
	_cell_history.push_front(cell)
	_trim_cell_history()


func _reset_trail(world_position: Vector2) -> void:
	_last_player_position = world_position
	_fallback_target = world_position
	if _ground == null:
		for follower in _followers:
			follower.snap_to(world_position)
		return
	_reset_cell_trail(_world_to_cell(world_position))
	var center: Vector2 = _cell_to_world(_player_cell)
	for follower in _followers:
		follower.snap_to(center)


func _reset_cell_trail(cell: Vector2i) -> void:
	_player_cell = cell
	_has_player_cell = true
	_cell_history = [cell]
	_fallback_target = _cell_to_world(cell)


func _trim_cell_history() -> void:
	var maximum_history: int = maxi(_followers.size() + 1, 1)
	if _cell_history.size() > maximum_history:
		_cell_history.resize(maximum_history)


func _world_to_cell(world_position: Vector2) -> Vector2i:
	return _ground.local_to_map(_ground.to_local(world_position))


func _cell_to_world(cell: Vector2i) -> Vector2:
	return _ground.to_global(_ground.map_to_local(cell))
