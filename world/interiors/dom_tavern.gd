class_name DomTavern
extends Node2D
## The Four Arms interior. Travel stays flow-owned; only the counter opens the
## unchanged party picker overlay.

var _counter_player_in_range := false

@onready var _counter_prompt: Label = $CounterInteraction/Prompt


func _ready() -> void:
	$CounterInteraction.body_entered.connect(_on_counter_body.bind(true))
	$CounterInteraction.body_exited.connect(_on_counter_body.bind(false))
	$Exit.body_entered.connect(_on_exit_body_entered)


func _unhandled_input(event: InputEvent) -> void:
	if not _counter_player_in_range or not event.is_action_pressed("interact"):
		return
	if get_tree().paused:
		return
	get_viewport().set_input_as_handled()
	_try_open_picker()


func _on_counter_body(body: Node2D, entered: bool) -> void:
	if body is Player:
		_counter_player_in_range = entered
		_counter_prompt.visible = entered


func _try_open_picker() -> Control:
	if not _counter_player_in_range or get_tree().paused:
		return null
	return UIManager.open(UIManager.TAVERN, true)


func _on_exit_body_entered(body: Node2D) -> void:
	if body is Player:
		GameFlow.travel(GameFlow.TOWN_SCENE, &"from_tavern")
