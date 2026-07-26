class_name Player
extends CharacterBody2D
## Field-exploration avatar for the 2D overworld (design doc §6: real-time 2D field).
## Top-down 8-direction movement. Deliberately minimal — the game-state singleton,
## interaction, and battle transition hang off this later.

## Movement speed in pixels/second.
@export var speed: float = 260.0

func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
