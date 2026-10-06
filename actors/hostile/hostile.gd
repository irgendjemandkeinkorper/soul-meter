class_name Hostile
extends CharacterBody2D
## Persistent field actor. Battle owns admission after an alert is accepted.

signal alerted(hostile: Hostile)
## Emitted once, the moment this hostile goes DOWNED. `SpawnDirector` listens to clear its slot.
signal downed(hostile: Hostile)

enum State { IDLE, ALERTED, IN_COMBAT, DOWNED }

@export var unit_id: StringName
@export var group_id: StringName
@export var alert_radius: float = 320.0 # PROVISIONAL — F0 D4.
@export var chain_radius: float = 192.0 # PROVISIONAL — F0 D4.
## Seconds this hostile stays deaf after a session it triggered was refused for want of room
## (F0 ruling 4). Without it a party wedged in a pocket re-refuses on every physics frame.
@export var realert_cooldown: float = 2.0 # PROVISIONAL — F0 ruling 4.
## Authored gate: while this flag is false the hostile is deaf — it stands on the field, dimmed,
## but no proximity or chain alert reaches it. Replaces the legacy Enemy `required_flag` lock
## (D4): there is no press-E trigger and no locked prompt, the mob simply ignores the party
## until the flag is set, and re-checks its radius the moment it opens.
@export var required_flag: String = ""

const LOCKED_MODULATE := Color(0.6, 0.6, 0.6, 1.0)
## #412 visual tells for a wild spawn's variation tier (`EnemyDerived.Tier`). PROVISIONAL values.
## Size is the tell that works on every sprite today; the tint needs a tell mask beside the
## unit's idle frame (`<frame>--tellmask.png`, eyes and claws) and is skipped where none exists.
const TELL_SIZE_PER_TIER := 0.05
const TELL_SHADER := preload("res://actors/hostile/variation_tell.gdshader")
const TELL_MASK_SUFFIX := "--tellmask.png"
const TELL_COLORS := {
	EnemyDerived.Tier.STRONG: Color(1.0, 0.42, 0.12),
	EnemyDerived.Tier.WEAK: Color(0.62, 0.7, 0.78),
}
const SENSOR_NAME := "AlertSensor"

var combat_id: StringName
var cell: Vector2i
var state: State = State.IDLE
var _actor: BattleActor
var _cooldown_until_msec: int = 0
## True once `adopt_actor()` handed this node an actor Battle already built: a set-piece body
## spawned for a fight that is running now, not a scene-authored mob that persists between visits.
var _adopted: bool = false
## True once `spawn_into_slot()` handed this node a `SpawnDirector` roll: its `group_id` is a
## day-stamped slot group, not an `EncounterCatalog` encounter, and its actor is already built.
var _from_spawn_slot: bool = false
## `EnemyDerived.Tier` of a spawn-slot roll; TYPICAL (no tell) for everything else.
var variation_tier: int = EnemyDerived.Tier.TYPICAL


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	add_to_group(&"hostile")
	# An authored group that the ledger already recorded as beaten does not come back: the
	# same check `Enemy` makes, so `defeated_*` flags keep gating pickups and follow-up fights.
	# A set-piece body is exempt: whether its encounter runs again is its caller's gate, and the
	# actor it stands in for is already in the controller — retiring the body would leave the
	# fight with an enemy nobody can see.
	if group_id != &"" and not _adopted and not _from_spawn_slot:
		var defeated_flag := EncounterCatalog.defeated_flag(group_id)
		if not defeated_flag.is_empty() and GameState.flag_is_true(defeated_flag):
			_retire()
			return
	if combat_id.is_empty():
		var root := _field_root()
		combat_id = StringName("%s:%s" % [root.scene_file_path, root.get_path_to(self)])
	var actor := battle_actor()
	if actor != null:
		actor.combat_id = combat_id
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = load(UnitArt.texture_path(UnitArt.resolve(String(unit_id)))) as Texture2D
		sprite.offset = UnitArt.PIVOT_OFFSET
		UnitArt.apply_world_scale(sprite, get_node_or_null("Shadow"))
		_apply_variation_tell(sprite)
	if is_inside_tree():
		GridPlacement.snap_to_walkable_cell(self, global_position)
		var field := _field_map()
		if field != null:
			field.register_hostile(self)
	_configure_sensor()
	if not required_flag.is_empty():
		if not GameState.flag_changed.is_connected(_on_flag_changed):
			GameState.flag_changed.connect(_on_flag_changed)
		_refresh_lock()
	sync_cell.call_deferred()


## #412: a stronger roll stands slightly larger and its eyes and claws run hot; a weaker one is
## slightly smaller and dull. No text anywhere names the tier (owner, 2026-10-06).
func _apply_variation_tell(sprite: Sprite2D) -> void:
	if variation_tier == EnemyDerived.Tier.TYPICAL:
		return
	var factor := 1.0 + TELL_SIZE_PER_TIER * float(variation_tier)
	sprite.scale *= factor
	var shadow := get_node_or_null("Shadow") as Node2D
	if shadow != null:
		shadow.scale *= factor
	var mask_path := UnitArt.texture_path(UnitArt.resolve(String(unit_id))).trim_suffix(".png") + TELL_MASK_SUFFIX
	if not ResourceLoader.exists(mask_path):
		return
	var material := ShaderMaterial.new()
	material.shader = TELL_SHADER
	material.set_shader_parameter(&"tell_mask", load(mask_path))
	material.set_shader_parameter(&"tell_color", TELL_COLORS[variation_tier])
	sprite.material = material


## A beaten mob leaves the field: hide it, switch the sensor off, drop it out of physics, and
## free it on a later idle frame so nothing that found it this frame touches a dead object.
func _retire() -> void:
	visible = false
	remove_from_group(&"hostile")
	var sensor := get_node_or_null(NodePath(SENSOR_NAME)) as Area2D
	if sensor != null:
		sensor.set_deferred("monitoring", false)
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	queue_free.call_deferred()


## Set-piece spawn (#281 D5): this hostile stands in for an actor Battle already built from the
## encounter, so it must not build a second one. Called before `add_child`, so `_ready` finds
## the actor, its combat id and its unit art already decided.
func adopt_actor(actor: BattleActor) -> void:
	_actor = actor
	_adopted = true
	unit_id = actor.archetype_id
	combat_id = actor.combat_id


## Spawn-slot instantiation (#345): `SpawnDirector` built the actor from the archetype alone,
## because a slot group is not an encounter and must not be looked up as one. Called before
## `add_child`, like `adopt_actor()`.
func spawn_into_slot(
	actor: BattleActor,
	slot_group_id: StringName,
	slot_combat_id: StringName,
	tier: int = EnemyDerived.Tier.TYPICAL,
) -> void:
	_actor = actor
	variation_tier = tier
	_from_spawn_slot = true
	unit_id = actor.archetype_id
	group_id = slot_group_id
	combat_id = slot_combat_id
	actor.combat_id = slot_combat_id


func battle_actor() -> BattleActor:
	if _actor == null:
		_actor = EncounterCatalog.make_actor(unit_id, group_id)
		if _actor != null:
			_actor.combat_id = combat_id
	return _actor


func request_alert() -> bool:
	if state != State.IDLE or battle_actor() == null:
		return false
	if not is_unlocked():
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


func is_unlocked() -> bool:
	return required_flag.is_empty() or GameState.flag_is_true(required_flag)


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag != required_flag:
		return
	_refresh_lock()
	if is_unlocked():
		# The player may already be standing inside the radius when the gate opens.
		_check_initial_overlap.call_deferred()


## The lock owns the tint of a standing hostile only. `mark_downed()` owns a corpse's, so a
## flag that flips after the kill (a chain of gated groups falling in one session) must never
## un-dim the body on the field.
func _refresh_lock() -> void:
	if state == State.DOWNED:
		return
	modulate = Color.WHITE if is_unlocked() else LOCKED_MODULATE


func alert_cooldown_active() -> bool:
	return Time.get_ticks_msec() < _cooldown_until_msec


func mark_downed() -> void:
	var was_downed := state == State.DOWNED
	state = State.DOWNED
	var actor := battle_actor()
	if actor != null:
		actor.hp = 0
	velocity = Vector2.ZERO
	_set_sensor_enabled(false)
	# A downed mob stays on the field as a body the party can walk over (owner ruling 3:
	# corpses despawn on scene exit, not on the spot). The dim is the field-side echo of the
	# overlay's KO fade, not a new art call.
	set_collision_layer_value(1, false)
	collision_mask = 0
	modulate = Color(0.55, 0.55, 0.55, 0.7)
	if not was_downed:
		downed.emit(self)


## D7: the session closed with this hostile still standing — the party fled or fell. It goes
## back to IDLE at full HP so the next approach re-opens the fight, under the same cooldown
## a refused alert uses, so it cannot re-alert on the physics frame the field unfreezes. A
## guard raised mid-fight and any residual velocity are dropped too: the mob stands where the
## session left it, exactly as if it had never been alerted. A DOWNED hostile stays down.
func release_from_session() -> void:
	if state == State.DOWNED or state == State.IDLE:
		return
	var actor := battle_actor()
	if actor != null:
		actor.hp = actor.max_hp
		actor.guarding = false
	velocity = Vector2.ZERO
	state = State.IDLE
	_cooldown_until_msec = Time.get_ticks_msec() + int(maxf(realert_cooldown, 0.0) * 1000.0)
	_set_sensor_enabled(true)


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
		sensor.set_deferred("monitoring", enabled)


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
