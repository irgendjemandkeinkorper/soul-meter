class_name Pickup
extends Area2D
## A passive world collectible. Walking over it adds `item_id` (a GLoot
## prototype id) to GameState.inventory and removes itself — no interact-key
## gate, since picking something up is a movement action, not a conversation.

@export var item_id: String = ""
@export var amount: int = 1
@export var required_flag: String = ""
@export var completion_flag: String = ""

var _available := true


func _ready() -> void:
	_available = required_flag.is_empty() or GameState.flag_is_true(required_flag)
	if not required_flag.is_empty():
		GameState.flag_changed.connect(_on_flag_changed)
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
	visual.modulate = Color.WHITE if _available else Color(1, 1, 1, 0.18)

	body_entered.connect(_on_body_entered)
	monitoring = _available
	monitorable = _available


func _on_body_entered(body: Node2D) -> void:
	if not _available or not (body is Player):
		return
	var item := GameState.inventory.create_and_add_item(item_id)
	if item and amount > 1:
		item.set_stack_size(amount)
	if not completion_flag.is_empty():
		GameState.set_flag(completion_flag, true)
	queue_free()


func _on_flag_changed(flag: String, value: Variant) -> void:
	if flag != required_flag or _available:
		return
	_available = bool(value)
	monitoring = _available
	monitorable = _available
	for child in get_children():
		if child is ColorRect:
			child.modulate = Color.WHITE if _available else Color(1, 1, 1, 0.18)
