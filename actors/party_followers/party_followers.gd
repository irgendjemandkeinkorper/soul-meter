class_name PartyFollowers
extends Node
## Maintains a sampled history of the player's real path and places each
## presentation-only companion at a successively older point on that path.

const FOLLOWER_SCENE: PackedScene = preload(
	"res://actors/party_followers/party_follower.tscn"
)

@export var player_path: NodePath = NodePath("../Player")
@export_group("Breadcrumb trail")
@export_range(24.0, 160.0, 1.0) var follower_spacing: float = 72.0
@export_range(1.0, 24.0, 1.0) var breadcrumb_spacing: float = 8.0
@export_range(32.0, 1000.0, 1.0) var teleport_reset_distance: float = 160.0
@export_group("Follower presentation")
@export_range(0.1, 6.283, 0.01) var sway_phase_step: float = 2.1

var _player: Node2D
var _player_position: Vector2
var _breadcrumbs: Array[Vector2] = []
var _followers: Array[PartyFollower] = []


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		push_error("PartyFollowers could not find a Node2D at '%s'." % player_path)
		set_physics_process(false)
		return
	_player_position = _player.global_position
	_breadcrumbs = [_player_position]
	_sync_followers()
	if not GameState.party_changed.is_connected(_on_party_changed):
		GameState.party_changed.connect(_on_party_changed)


func _exit_tree() -> void:
	if GameState.party_changed.is_connected(_on_party_changed):
		GameState.party_changed.disconnect(_on_party_changed)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var current_position := _player.global_position
	if current_position.distance_to(_player_position) > teleport_reset_distance:
		_reset_trail(current_position)
	else:
		_player_position = current_position
		if current_position.distance_to(_breadcrumbs[0]) >= breadcrumb_spacing:
			_breadcrumbs.push_front(current_position)
		_trim_breadcrumbs()

	for index in _followers.size():
		_followers[index].follow_trail(trail_target_for(index), delta)


func follower_count() -> int:
	return _followers.size()


func followers() -> Array[PartyFollower]:
	return _followers.duplicate()


func trail_target_for(follower_index: int) -> Vector2:
	if follower_index < 0:
		return _player_position
	return _position_along_trail(float(follower_index + 1) * follower_spacing)


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
			follower.snap_to(_player_position)
		follower.configure(member, float(next_followers.size()) * sway_phase_step)
		next_followers.append(follower)

	for orphan_value: Variant in current_by_id.values():
		var orphan := orphan_value as PartyFollower
		if orphan != null:
			orphan.queue_free()

	_followers = next_followers
	for index in _followers.size():
		move_child(_followers[index], index)
	_trim_breadcrumbs()


func _reset_trail(world_position: Vector2) -> void:
	_player_position = world_position
	_breadcrumbs = [world_position]
	for follower in _followers:
		follower.snap_to(world_position)


func _trim_breadcrumbs() -> void:
	if _breadcrumbs.size() <= 1:
		return
	var keep_distance := float(_followers.size() + 1) * follower_spacing + breadcrumb_spacing
	var traversed := 0.0
	var previous := _player_position
	for index in _breadcrumbs.size():
		var point := _breadcrumbs[index]
		traversed += previous.distance_to(point)
		previous = point
		if traversed >= keep_distance:
			_breadcrumbs.resize(index + 1)
			return


func _position_along_trail(distance_from_player: float) -> Vector2:
	var remaining := maxf(distance_from_player, 0.0)
	var previous := _player_position
	for point in _breadcrumbs:
		var segment_length := previous.distance_to(point)
		if segment_length <= 0.001:
			continue
		if remaining <= segment_length:
			return previous.lerp(point, remaining / segment_length)
		remaining -= segment_length
		previous = point
	return previous
