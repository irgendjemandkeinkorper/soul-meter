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


func _is_unlocked() -> bool:
	if not required_flags.is_empty():
		for flag in required_flags:
			if bool(GameState.get_flag(flag)):
				return true
		return false
	return required_flag.is_empty() or bool(GameState.get_flag(required_flag))


func _locked_prompt() -> String:
	return "LOCKED — " + locked_message
