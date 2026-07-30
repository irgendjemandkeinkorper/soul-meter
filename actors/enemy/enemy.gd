class_name Enemy
extends StaticBody2D
## A field encounter trigger. Walk into range, press the interact key (E) —
## starts a Battle and hands off to GameFlow's Battle state. Stats are
## hardcoded @export fields on the scene instance (no GodotGAS, no Pandora
## Monster category yet — this is a placeholder pending real bestiary
## content). A defeated enemy sets `defeated_flag` on GameState and removes
## itself so it can't be refought.

@export var enemy_name: String = "Enemy"
@export var hp: int = 20
@export var max_hp: int = 20
@export var attack: int = 4
@export var defense: int = 1
@export var defeated_flag: String = ""

## Passed straight through to the ephemeral BattleActor — see its matching
## fields for why these are here instead of on the Enemy scene alone.
@export var win_faction: String = ""
@export var win_delta: float = 0.0
@export var win_cause: String = ""
@export var loss_faction: String = ""
@export var loss_delta: float = 0.0
@export var loss_cause: String = ""

var _player_in_range := false
var _prompt: Label


func _ready() -> void:
	if defeated_flag != "" and GameState.get_flag(defeated_flag):
		queue_free()
		return

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
	_prompt.text = "E — FIGHT"
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
		var actor := BattleActor.new()
		actor.display_name = enemy_name
		actor.hp = hp
		actor.max_hp = max_hp
		actor.attack = attack
		actor.defense = defense
		actor.defeated_flag = defeated_flag
		actor.win_faction = win_faction
		actor.win_delta = win_delta
		actor.win_cause = win_cause
		actor.loss_faction = loss_faction
		actor.loss_delta = loss_delta
		actor.loss_cause = loss_cause
		Battle.battle_ended.connect(_on_battle_ended, CONNECT_ONE_SHOT)
		Battle.start(actor)
		GameFlow.send_event("enter_battle")


func _on_battle_ended(won: bool, _fled: bool) -> void:
	if won:
		queue_free()
