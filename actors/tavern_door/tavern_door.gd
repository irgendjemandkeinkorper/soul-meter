class_name TavernDoor
extends StaticBody2D
## Walk into range, press the interact key (E) — opens the Tavern screen
## (ui/screens/tavern.gd) as a paused overlay, same as Inventory/Party. Not
## flow-owned: it's a view over GameState, not a chart state (see game_flow.gd).

var _player_in_range := false
var _prompt: Label


func _ready() -> void:
	var range_area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 100.0
	shape.shape = circle
	range_area.add_child(shape)
	add_child(range_area)
	range_area.body_entered.connect(_on_body.bind(true))
	range_area.body_exited.connect(_on_body.bind(false))

	_prompt = Label.new()
	_prompt.text = "E — ENTER"
	_prompt.theme_type_variation = "EyebrowLabel"
	_prompt.position = Vector2(-36, -84)
	_prompt.visible = false
	add_child(_prompt)


func _on_body(body: Node2D, entered: bool) -> void:
	if body is Player:
		_player_in_range = entered
		_prompt.visible = entered


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		UIManager.open(UIManager.TAVERN, true)
