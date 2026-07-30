class_name TravelExit
extends Area2D
## A walk-over exit to another gameplay scene. Routes through GameFlow.travel()
## (Active -> Loading -> Active on the "travel" event) — never change_scene_to_file()
## in game code, per docs/godot-architecture.md's Flow policy.

@export var target_scene: String = ""
@export var label_text: String = "Leave"


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 100)
	shape.shape = rect
	add_child(shape)

	var label := Label.new()
	label.text = label_text
	label.theme_type_variation = "EyebrowLabel"
	label.position = Vector2(-40, -84)
	add_child(label)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not target_scene.is_empty():
		GameFlow.travel(target_scene)
