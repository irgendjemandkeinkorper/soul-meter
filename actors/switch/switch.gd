class_name InteractiveSwitch
extends SMInteractable
## A repeatable flag toggle. The inherited interaction_flag is the single
## source of truth so gates can observe GameState.flag_changed directly.

const OFF_TEXTURE_PATH := "res://assets/generated/sprites/world/objects/dom-lever-iron--off.png"
const ON_TEXTURE_PATH := "res://assets/generated/sprites/world/objects/dom-lever-iron--on.png"
const PLACEHOLDER_TEXTURE_PATH := "res://assets/kenney/ui/fantasy-ui-borders/PNG/Default/Panel/panel-013.png"

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


func _on_flag_changed(flag: String, value: Variant) -> void:
	super._on_flag_changed(flag, value)
	if flag == interaction_flag:
		_refresh_visual()


func _texture_or_placeholder(path: String) -> Texture2D:
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	# The interactive-object art landed (dom-lever-iron--*); null now only means
	# a missing/corrupt file, and the caller keeps its drawn placeholder.
	return null
