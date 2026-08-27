class_name Chest
extends SMInteractable
## A reusable loot container. Interaction policy stays in SMInteractable; this
## class only applies the chest-specific loot and visual state.

const CLOSED_TEXTURE_PATH := "res://assets/generated/sprites/world/objects/dom-chest-wood--closed.png"
const OPEN_TEXTURE_PATH := "res://assets/generated/sprites/world/objects/dom-chest-wood--open.png"
const PLACEHOLDER_TEXTURE_PATH := "res://assets/kenney/ui/fantasy-ui-borders/PNG/Default/Panel/panel-013.png"

@export var loot: Array[Dictionary] = []

@onready var _closed_sprite: Sprite2D = $ClosedSprite
@onready var _open_sprite: Sprite2D = $OpenSprite


func _ready() -> void:
	super._ready()
	_closed_sprite.texture = _texture_or_placeholder(CLOSED_TEXTURE_PATH)
	_open_sprite.texture = _texture_or_placeholder(OPEN_TEXTURE_PATH)
	_refresh_visual()


func _apply_interaction() -> void:
	for row: Dictionary in loot:
		var item_id := str(row.get("item_id", ""))
		var quantity := maxi(1, int(row.get("quantity", 1)))
		if item_id.is_empty():
			continue
		var item: InventoryItem = GameState.inventory.create_and_add_item(item_id)
		if item == null:
			push_warning("Chest '%s' could not grant item '%s'." % [name, item_id])
			continue
		if quantity > 1:
			item.set_stack_size(quantity)
	if not interaction_flag.is_empty():
		GameState.set_flag(interaction_flag, true)
	if not repeatable:
		_used = true
	_refresh_visual()


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
