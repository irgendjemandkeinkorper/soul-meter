extends Quest
class_name FetchQuest
## A basic "bring me N of an item" quest. objective_completed is derived from
## GameState.inventory every time update() runs — see QuestRegistry, which
## calls update() whenever the inventory changes so dialogue guards stay live.

@export var item_id: String = ""
@export var required_amount: int = 1
@export var reward_faction: String = ""
@export var reward_amount: float = 0.0
@export var reward_cause: String = ""
@export var quest_giver: String = ""
@export var quest_location: String = ""


func update(_args: Dictionary = {}) -> void:
	var have := 0
	for item in GameState.inventory.get_items_with_prototype_id(item_id):
		have += item.get_stack_size()
	objective_completed = have >= required_amount
	super.update(_args)


func complete(args: Dictionary = {}) -> void:
	var resolution: String = args.get("resolution", "returned")
	GameState.set_flag("quest_%d_resolution" % id, resolution)
	if args.get("grant_default_reward", true) and not reward_faction.is_empty():
		Reputation.record("player", reward_faction, reward_amount, reward_cause, "field")
	super.complete(args)
