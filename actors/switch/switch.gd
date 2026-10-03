class_name InteractiveSwitch
extends SMInteractable
## A repeatable flag toggle. The inherited interaction_flag is the single
## source of truth so gates can observe GameState.flag_changed directly.

const OFF_TEXTURE_PATH := "res://assets/generated/sprites/interior/dom-interior-switch--off.png"
const ON_TEXTURE_PATH := "res://assets/generated/sprites/interior/dom-interior-switch--on.png"

@onready var _off_sprite: Sprite2D = $OffSprite
@onready var _on_sprite: Sprite2D = $OnSprite


func _init() -> void:
	# Scene authors can still opt out by setting repeatable = false in a scene.
	repeatable = true


func _ready() -> void:
	super._ready()
	_off_sprite.texture = _texture_or_placeholder(OFF_TEXTURE_PATH)
	_on_sprite.texture = _texture_or_placeholder(ON_TEXTURE_PATH)
	_refresh_visual()


func _apply_interaction() -> void:
	if interaction_flag.is_empty():
		return
	GameState.set_flag(interaction_flag, not GameState.flag_is_true(interaction_flag))
	_refresh_visual()


func _refresh_visual() -> void:
	var is_on := not interaction_flag.is_empty() and GameState.flag_is_true(interaction_flag)
	_off_sprite.visible = not is_on
	_on_sprite.visible = is_on
	$Marker.visible = _on_sprite.texture == null if is_on else _off_sprite.texture == null


func _on_flag_changed(flag: String, value: Variant) -> void:
	super._on_flag_changed(flag, value)
	if flag == interaction_flag:
		_refresh_visual()


func _texture_or_placeholder(path: String) -> Texture2D:
	# Share Godot's imported texture cache and export remapping with the scene art.
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
