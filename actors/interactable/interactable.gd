class_name SMInteractable
extends Area2D
## Small field interaction used for signs, shrines, and other non-character events.
## It deliberately owns only durable facts and feedback; quest/reputation policy
## remains in dialogue or the relevant singleton.

@export var display_name: String = "INTERACT"
@export var prompt_text: String = "INTERACT"
@export_multiline var interaction_text: String = "You find nothing that needs doing."
@export var interaction_flag: String = ""
@export var required_flag: String = ""
@export var locked_message: String = "That is not available yet."
@export var marker_color := Color("#B8860B")
@export var repeatable := false
@export var save_point := false
@export var shop_type := ""

var _player_in_range := false
var _used := false
var _prompt: Label
var _sign: Label


func _ready() -> void:
	_used = not interaction_flag.is_empty() and GameState.flag_is_true(interaction_flag)
	_prompt = $Prompt
	_sign = $Sign
	_sign.text = display_name
	$Marker.color = marker_color
	_prompt.visible = false
	_refresh_prompt()

	var range_area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 96.0
	shape.shape = circle
	range_area.add_child(shape)
	add_child(range_area)
	range_area.body_entered.connect(_on_body.bind(true))
	range_area.body_exited.connect(_on_body.bind(false))
	GameState.flag_changed.connect(_on_flag_changed)


func _on_body(body: Node2D, entered: bool) -> void:
	if body is Player:
		_player_in_range = entered
		_prompt.visible = entered
		if entered:
			_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or not event.is_action_pressed("interact") or get_tree().paused:
		return
	get_viewport().set_input_as_handled()
	if not _is_unlocked():
		_prompt.text = "LOCKED — " + locked_message
		return
	if _used and not repeatable:
		_prompt.text = interaction_text
		return
	_apply_interaction()
	if not repeatable:
		_used = true
	_prompt.text = interaction_text
	SaveGame.request_autosave(
		("save-point-" if save_point else "town-event-") + name.to_snake_case()
	)
	if not shop_type.is_empty():
		var shop_screen := UIManager.open(UIManager.SHOP, true)
		shop_screen.call("configure_shop", shop_type)


## Override this for an interaction with a different durable effect while
## retaining this class's range, input, lock, prompt, and autosave behavior.
func _apply_interaction() -> void:
	if not interaction_flag.is_empty():
		GameState.set_flag(interaction_flag, true)


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag == required_flag:
		_refresh_prompt()


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	_prompt.text = "E — " + prompt_text if _is_unlocked() else "LOCKED — " + locked_message


func _is_unlocked() -> bool:
	return required_flag.is_empty() or GameState.flag_is_true(required_flag)
