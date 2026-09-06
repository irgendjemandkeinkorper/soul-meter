class_name Hostile
extends CharacterBody2D
## Persistent field actor. Battle owns admission after an alert is accepted.

signal alerted(hostile: Hostile)

enum State { IDLE, ALERTED, IN_COMBAT, DOWNED }

@export var unit_id: StringName
@export var group_id: StringName
@export var alert_radius: float = 320.0 # PROVISIONAL — F0 D4.
@export var chain_radius: float = 192.0 # PROVISIONAL — F0 D4.

var combat_id: StringName
var cell: Vector2i
var state: State = State.IDLE
var _actor: BattleActor


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	add_to_group(&"hostile")
	if combat_id.is_empty():
		var root := _field_root()
		combat_id = StringName("%s:%s" % [root.scene_file_path, root.get_path_to(self)])
	var actor := battle_actor()
	if actor != null:
		actor.combat_id = combat_id
	_sync_cell.call_deferred()


func battle_actor() -> BattleActor:
	if _actor == null:
		_actor = EncounterCatalog.make_actor(unit_id, group_id)
		if _actor != null:
			_actor.combat_id = combat_id
	return _actor


func request_alert() -> bool:
	if state != State.IDLE or battle_actor() == null:
		return false
	var field := _field_map()
	if field == null or field.no_combat_zone():
		return false
	state = State.ALERTED
	alerted.emit(self)
	return true


func mark_downed() -> void:
	state = State.DOWNED
	var actor := battle_actor()
	if actor != null:
		actor.hp = 0
	velocity = Vector2.ZERO


func _sync_cell() -> void:
	var field := _field_map()
	if field != null:
		var grid := field.iso_grid()
		if grid != null:
			cell = grid.world_to_cell(global_position)


func _field_map() -> FieldMap:
	for node: Node in _field_root().find_children("*", "", true, false):
		if node is FieldMap:
			return node as FieldMap
	return null


func _field_root() -> Node:
	var root: Node = get_parent()
	var cursor: Node = root
	while cursor != null:
		if not cursor.scene_file_path.is_empty():
			root = cursor
		cursor = cursor.get_parent()
	return root
