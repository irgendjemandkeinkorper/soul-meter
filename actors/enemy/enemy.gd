class_name Enemy
extends StaticBody2D
## A field encounter trigger. Walk into range, press the interact key (E) —
## starts the Pandora-authored encounter and hands off to GameFlow's Battle
## state. Scene instances carry only a generated encounter ID; combatants,
## Balance affinities, and consequences live in the generated catalog.

@export var encounter_id: StringName
@export var required_flag: String = ""
@export var locked_message: String = "Resolve the threat before this one."

var _player_in_range := false
var _prompt: Label


func _ready() -> void:
	var encounter := EncounterCatalog.definition(encounter_id)
	if encounter.is_empty():
		push_error("Enemy node '%s' has unknown encounter ID '%s'." % [name, encounter_id])
		queue_free()
		return
	var defeated_flag := EncounterCatalog.defeated_flag(encounter_id)
	if not defeated_flag.is_empty() and GameState.get_flag(defeated_flag):
		queue_free()
		return
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
	_prompt.theme_type_variation = "EyebrowLabel"
	_prompt.position = Vector2(-140, -116)
	_prompt.size = Vector2(280, 54)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.visible = false
	add_child(_prompt)
	if not required_flag.is_empty():
		GameState.flag_changed.connect(_on_flag_changed)
	_refresh_lock()


func _on_body(body: Node2D, entered: bool) -> void:
	if body is Player:
		_player_in_range = entered
		_prompt.visible = entered
		if entered:
			_refresh_lock()


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		if not _is_unlocked():
			_prompt.text = _locked_prompt()
			return
		Battle.battle_ended.connect(_on_battle_ended, CONNECT_ONE_SHOT)
		Battle.start(encounter_id)
		if Battle.ended:
			return
		GameFlow.send_event("enter_battle")


func _on_battle_ended(result: BattleResult) -> void:
	if result.succeeded():
		queue_free()


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if flag == required_flag:
		_refresh_lock()


func _refresh_lock() -> void:
	var encounter_name := str(
		EncounterCatalog.definition(encounter_id).get("display_name", "FIGHT")
	)
	_prompt.text = (
		"E — " + encounter_name.to_upper() if _is_unlocked() else _locked_prompt()
	)
	modulate = Color.WHITE if _is_unlocked() else Color(0.6, 0.6, 0.6, 1.0)


func _is_unlocked() -> bool:
	return required_flag.is_empty() or bool(GameState.get_flag(required_flag))


func _locked_prompt() -> String:
	return "LOCKED — " + locked_message


func _apply_visual_identity() -> void:
	var sprite := $Sprite2D as Sprite2D
	match encounter_id:
		&"dorthkor-vanguard":
			sprite.region_rect = Rect2(0, 68, 16, 16)
			sprite.modulate = Color(0.96, 0.28, 0.22, 1)
		&"dorthkor-muster":
			sprite.region_rect = Rect2(17, 102, 16, 16)
			sprite.modulate = Color(0.7, 0.62, 0.85, 1)
			sprite.scale = Vector2(4.25, 4.25)
		&"bog-wight":
			sprite.region_rect = Rect2(0, 68, 16, 16)
			sprite.modulate = Color(0.4, 0.78, 0.55, 1)
		&"loam-boar":
			sprite.region_rect = Rect2(34, 68, 16, 16)
			sprite.modulate = Color(0.66, 0.45, 0.28, 1)
