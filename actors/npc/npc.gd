class_name NPC
extends StaticBody2D
## A field NPC the player can talk to. Walk into range, press the interact key (E) —
## the configured dialogue starts via Dialogue Manager (which loads our balloon).

@export var npc_name: String = "NPC"
@export_file("*.dialogue") var dialogue_path: String
@export var dialogue_start: String = "start"

var _player_in_range := false
var _prompt: Label


func _ready() -> void:
	_apply_visual_identity()
	var range_area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 120.0
	shape.shape = circle
	range_area.add_child(shape)
	add_child(range_area)
	range_area.body_entered.connect(_on_body.bind(true))
	range_area.body_exited.connect(_on_body.bind(false))

	_prompt = Label.new()
	_prompt.text = "E — TALK"
	_prompt.theme_type_variation = "EyebrowLabel"
	_prompt.position = Vector2(-100, -108)
	_prompt.size = Vector2(200, 32)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	add_child(_prompt)


func _on_body(body: Node2D, entered: bool) -> void:
	if body is Player:
		_player_in_range = entered
		_prompt.visible = entered


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		DialogueManager.show_dialogue_balloon(load(dialogue_path), dialogue_start)


func _apply_visual_identity() -> void:
	var sprite := $Sprite2D as Sprite2D
	if npc_name == "Marshal Coiljaw":
		sprite.region_rect = Rect2(17, 102, 16, 16)
		sprite.modulate = Color(0.82, 0.68, 0.43, 1)
	else:
		sprite.region_rect = Rect2(0, 68, 16, 16)
		sprite.modulate = Color(0.55, 0.78, 0.64, 1)
