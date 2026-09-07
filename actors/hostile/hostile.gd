class_name Hostile
extends CharacterBody2D
## Persistent field actor. Battle owns admission after an alert is accepted.

signal alerted(hostile: Hostile)

enum State { IDLE, ALERTED, IN_COMBAT, DOWNED }

@export var unit_id: StringName
@export var group_id: StringName
@export var alert_radius: float = 320.0 # PROVISIONAL — F0 D4.
@export var chain_radius: float = 192.0 # PROVISIONAL — F0 D4.
## Seconds this hostile stays deaf after a session it triggered was refused for want of room
## (F0 ruling 4). Without it a party wedged in a pocket re-refuses on every physics frame.
@export var realert_cooldown: float = 2.0 # PROVISIONAL — F0 ruling 4.

const SENSOR_NAME := "AlertSensor"

var combat_id: StringName
var cell: Vector2i
var state: State = State.IDLE
var _actor: BattleActor
var _cooldown_until_msec: int = 0


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
	_configure_sensor()
	sync_cell.call_deferred()


func battle_actor() -> BattleActor:
	if _actor == null:
		_actor = EncounterCatalog.make_actor(unit_id, group_id)
		if _actor != null:
			_actor.combat_id = combat_id
	return _actor


func request_alert() -> bool:
	if state != State.IDLE or battle_actor() == null:
		return false
	if alert_cooldown_active():
		return false
	var field := _field_map()
	if field == null or field.no_combat_zone():
		return false
	state = State.ALERTED
	_set_sensor_enabled(false)
	alerted.emit(self)
	return true


## The alert was accepted and this hostile is now in the running session. Only IN_COMBAT
## hostiles are chain-alert sources, so this is what lets a fight spread.
func mark_in_combat() -> void:
	if state == State.DOWNED:
		return
	state = State.IN_COMBAT
	_set_sensor_enabled(false)


## The session this hostile's alert would have opened was refused — no room for the party
## (F0 ruling 4). Nothing else changed, so this hostile goes back to exactly where it was,
## minus a cooldown that stops it re-refusing every frame.
func refuse_alert() -> void:
	if state != State.ALERTED:
		return
	state = State.IDLE
	_cooldown_until_msec = Time.get_ticks_msec() + int(maxf(realert_cooldown, 0.0) * 1000.0)
	_set_sensor_enabled(true)


func alert_cooldown_active() -> bool:
	return Time.get_ticks_msec() < _cooldown_until_msec


func mark_downed() -> void:
	state = State.DOWNED
	var actor := battle_actor()
	if actor != null:
		actor.hp = 0
	velocity = Vector2.ZERO
	_set_sensor_enabled(false)


## D9: an IDLE hostile does no per-frame work. Proximity is an Area2D overlap and nothing
## else, and the sensor is switched off the moment this hostile stops being able to be
## alerted. The radius is per-instance, so the shape is resized here rather than authored.
func _configure_sensor() -> void:
	var sensor := get_node_or_null(NodePath(SENSOR_NAME)) as Area2D
	if sensor == null:
		return
	var shape_node := sensor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var circle := shape_node.shape as CircleShape2D if shape_node != null else null
	if circle != null:
		circle.radius = alert_radius
	if not sensor.body_entered.is_connected(_on_alert_body_entered):
		sensor.body_entered.connect(_on_alert_body_entered)
	_check_initial_overlap.call_deferred()


## Party-only, per F1 step 5: every field body shares collision layer 1, so the type test is
## what keeps one hostile from alerting another by standing next to it. Chain spread is the
## only hostile-to-hostile path, and it runs on the combat clock, not on proximity.
func _on_alert_body_entered(body: Node2D) -> void:
	if body is Player:
		request_alert()


## `body_entered` never fires for a body that was already inside the radius when the sensor
## appeared — a hostile authored on top of the player's spawn, for one.
func _check_initial_overlap() -> void:
	if not is_inside_tree():
		return
	var sensor := get_node_or_null(NodePath(SENSOR_NAME)) as Area2D
	if sensor == null or not sensor.monitoring:
		return
	await get_tree().physics_frame
	if not is_instance_valid(sensor) or not sensor.monitoring:
		return
	for body: Node2D in sensor.get_overlapping_bodies():
		if body is Player:
			request_alert()
			return


func _set_sensor_enabled(enabled: bool) -> void:
	var sensor := get_node_or_null(NodePath(SENSOR_NAME)) as Area2D
	if sensor != null:
		sensor.monitoring = enabled


## Recomputes and returns this hostile's field cell. Admission reads it live rather than
## trusting the cached value: a hostile can be moved by anything between two alerts.
func sync_cell() -> Vector2i:
	var field := _field_map()
	if field != null:
		var grid := field.iso_grid()
		if grid != null:
			cell = grid.world_to_cell(global_position)
	return cell


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
