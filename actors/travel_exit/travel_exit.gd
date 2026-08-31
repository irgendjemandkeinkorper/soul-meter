class_name TravelExit
extends Area2D
## A walk-over exit to another gameplay scene. Routes through GameFlow.travel()
## (Active -> Loading -> Active on the "travel" event) — never change_scene_to_file()
## in game code, per docs/godot-architecture.md's Flow policy.

@export var target_scene: String = ""
@export var target_location_id: StringName = &""
@export var label_text: String = "Leave"
@export var required_flag: String = ""
@export var required_flags: PackedStringArray = []
@export var locked_message: String = "This route is not open yet."
@export var spawn_id: StringName = &"default"

var _label: Label
var _location: LocationDefinition
var _barrier_shape: CollisionShape2D
@onready var _sign: Sprite2D = $SignSprite


func _ready() -> void:
	_location = LocationRegistry.resolve(target_scene, target_location_id)
	if _location == null:
		push_error("TravelExit has no registered gameplay location: %s" % target_scene)
		target_scene = ""
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 100)
	shape.shape = rect
	add_child(shape)

	# #213 (ruling: option a): the boundary walls deliberately leave a collider
	# gap where the exit sits, so a LOCKED exit must physically close it — the
	# barrier's shape is enabled exactly while locked and vanishes on unlock.
	var barrier := StaticBody2D.new()
	barrier.name = "LockedBarrier"
	_barrier_shape = CollisionShape2D.new()
	_barrier_shape.name = "CollisionShape2D"
	var barrier_rect := RectangleShape2D.new()
	barrier_rect.size = rect.size
	_barrier_shape.shape = barrier_rect
	barrier.add_child(_barrier_shape)
	add_child(barrier)

	_label = Label.new()
	_label.theme_type_variation = "EyebrowLabel"
	_label.position = Vector2(-80, -84)
	_label.size = Vector2(160, 56)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)

	body_entered.connect(_on_body_entered)
	if not required_flag.is_empty() or not required_flags.is_empty():
		GameState.flag_changed.connect(_on_flag_changed)
	_refresh_lock()
	_start_sign_pulse()


## Passive, always-on beacon so the exit reads from a distance, not just on approach.
## Ambient (not springy) per the DS motion language — DS.DUR_AMBIENT is the token for
## exactly this kind of slow, settled loop.
func _start_sign_pulse() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_sign, "self_modulate:a", 0.72, DS.DUR_AMBIENT)
	tween.tween_property(_sign, "self_modulate:a", 1.0, DS.DUR_AMBIENT)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and _location != null:
		if _is_unlocked():
			GameFlow.travel(_location.scene_path, _location.resolve_spawn(spawn_id))
		else:
			_label.text = _locked_prompt()


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag == required_flag or required_flags.has(flag):
		_refresh_lock()


func _refresh_lock() -> void:
	var unlocked := _is_unlocked()
	_label.text = label_text if unlocked else _locked_prompt()
	modulate = Color.WHITE if unlocked else Color(0.65, 0.65, 0.65, 1.0)
	monitoring = true
	monitorable = true
	if _barrier_shape != null:
		# Deferred: _refresh_lock can run from flag_changed during physics.
		_barrier_shape.set_deferred("disabled", unlocked)


func _is_unlocked() -> bool:
	if not required_flags.is_empty():
		for flag in required_flags:
			if GameState.flag_is_true(flag):
				return true
		return false
	return required_flag.is_empty() or GameState.flag_is_true(required_flag)


func _locked_prompt() -> String:
	return "LOCKED — " + locked_message
