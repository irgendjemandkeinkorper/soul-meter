class_name Chest
extends SMInteractable
## A reusable loot container. Interaction policy stays in SMInteractable; this
## class only applies the chest-specific loot and visual state.

const CLOSED_TEXTURE_PATH := "res://assets/generated/sprites/world/objects/dom-chest-wood--closed.png"
const OPEN_TEXTURE_PATH := "res://assets/generated/sprites/world/objects/dom-chest-wood--open.png"
const PLACEHOLDER_TEXTURE_PATH := "res://assets/kenney/ui/fantasy-ui-borders/PNG/Default/Panel/panel-013.png"

@export var loot: Array[Dictionary] = []
@export var container_id: String = ""

@onready var _closed_sprite: Sprite2D = $ClosedSprite
@onready var _open_sprite: Sprite2D = $OpenSprite


func _ready() -> void:
	GameState.ensure_loot_container(container_id, loot)
	repeatable = true
	super._ready()
	_closed_sprite.texture = _texture_or_placeholder(CLOSED_TEXTURE_PATH)
	_open_sprite.texture = _texture_or_placeholder(OPEN_TEXTURE_PATH)
	_refresh_visual()


func _apply_interaction() -> void:
	if not interaction_flag.is_empty():
		GameState.set_flag(interaction_flag, true)
	_used = true
	_refresh_visual()
	var remaining := GameState.loot_container_contents(container_id)
	if remaining.is_empty():
		interaction_text = "EMPTY"
		_refresh_prompt()
		return
	var panel := UIManager.open(UIManager.LOOT_PANEL, true) as LootPanel
	panel.configure(display_name, remaining, container_id)
	panel.dismissed.connect(_on_loot_panel_dismissed, CONNECT_ONE_SHOT)


func _on_loot_panel_dismissed(_remaining: Array[Dictionary]) -> void:
	if GameState.loot_container_contents(container_id).is_empty():
		interaction_text = "EMPTY"
	_refresh_prompt()


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	if not _is_unlocked():
		_prompt.text = "LOCKED — " + locked_message
	elif not container_id.is_empty() and GameState.loot_container_contents(container_id).is_empty():
		_prompt.text = "E — EMPTY"
	else:
		_prompt.text = "E — " + prompt_text


func _refresh_visual() -> void:
	var is_open := _used or (not interaction_flag.is_empty() and GameState.flag_is_true(interaction_flag))
	_closed_sprite.visible = not is_open
	_open_sprite.visible = is_open


func _texture_or_placeholder(path: String) -> Texture2D:
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	# The interactive-object art landed (dom-chest-wood--*); null now only means
	# a missing/corrupt file, and the caller keeps its drawn placeholder.
	return null
