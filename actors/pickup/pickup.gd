class_name Pickup
extends SMInteractable
## A one-item ground pickup that requires the normal interact action.

## PROVISIONAL — aligned with the project's small quest-scale reputation deltas.
const THEFT_REPUTATION_DELTA: float = -5.0

@export var item_id: String = ""
@export var amount: int = 1
@export var completion_flag: String = ""
@export var owned_by_faction: String = ""


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
	if not owned_by_faction.strip_edges().is_empty():
		Reputation.record(
			"player",
			owned_by_faction.strip_edges(),
			THEFT_REPUTATION_DELTA,
			"Took goods from %s" % display_name,
			_current_scene_path(),
		)
	if not completion_flag.is_empty():
		GameState.set_flag(completion_flag, true)
	queue_free()


func _current_scene_path() -> String:
	var current_scene: Node = get_tree().current_scene
	return current_scene.scene_file_path if current_scene != null else ""
