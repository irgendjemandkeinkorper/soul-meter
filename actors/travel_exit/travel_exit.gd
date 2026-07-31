class_name TravelExit
extends Area2D
## A walk-over exit to another gameplay scene. Routes through GameFlow.travel()
## (Active -> Loading -> Active on the "travel" event) — never change_scene_to_file()
## in game code, per docs/godot-architecture.md's Flow policy.

@export var target_scene: String = ""
@export var label_text: String = "Leave"
@export var required_flag: String = ""
@export var locked_message: String = "This route is not open yet."
@export var spawn_id: StringName = &"default"

var _label: Label


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 100)
	shape.shape = rect
	add_child(shape)

	_label = Label.new()
	_label.theme_type_variation = "EyebrowLabel"
	_label.position = Vector2(-80, -84)
	_label.size = Vector2(160, 56)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)

	body_entered.connect(_on_body_entered)
	if not required_flag.is_empty():
		GameState.flag_changed.connect(_on_flag_changed)
	_refresh_lock()


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not target_scene.is_empty():
		if _is_unlocked():
			GameFlow.travel(target_scene, spawn_id)
		else:
			_label.text = locked_message


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag == required_flag:
		_refresh_lock()


func _refresh_lock() -> void:
	var unlocked := _is_unlocked()
	_label.text = label_text if unlocked else "LOCKED — " + label_text
	modulate = Color.WHITE if unlocked else Color(0.65, 0.65, 0.65, 1.0)
	monitoring = true
	monitorable = true


func _is_unlocked() -> bool:
	return required_flag.is_empty() or bool(GameState.get_flag(required_flag))
