class_name Pickup
extends SMInteractable
## A one-item ground pickup that requires the normal interact action.

@export var item_id: String = ""
@export var amount: int = 1
@export var completion_flag: String = ""


func _ready() -> void:
	display_name = "PICKUP"
	prompt_text = "TAKE"
	repeatable = true
	super._ready()


func _apply_interaction() -> void:
	var item: InventoryItem = GameState.inventory.create_item(item_id)
	if item == null or not item.set_stack_size(maxi(amount, 1)):
		interaction_text = "That cannot be taken."
		return
	if not GameState.inventory.add_item(item):
		interaction_text = "No room. The item remains here."
		return
	if not completion_flag.is_empty():
		GameState.set_flag(completion_flag, true)
	queue_free()
