class_name Pickup
extends Area2D
## A passive world collectible. Walking over it adds `item_id` (a GLoot
## prototype id) to GameState.inventory and removes itself — no interact-key
## gate, since picking something up is a movement action, not a conversation.

@export var item_id: String = ""
@export var amount: int = 1


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	add_child(shape)

	var visual := ColorRect.new()
	visual.color = Color(0.42, 0.62, 0.28)
	visual.size = Vector2(20, 20)
	visual.position = Vector2(-10, -10)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	var item := GameState.inventory.create_and_add_item(item_id)
	if item and amount > 1:
		item.set_stack_size(amount)
	queue_free()
