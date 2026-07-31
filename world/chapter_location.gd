extends Node2D

@export var arrival_flag: String


func _ready() -> void:
	if not arrival_flag.is_empty():
		GameState.set_flag(arrival_flag, true)
		SaveGame.request_autosave("arrived-" + arrival_flag.trim_prefix("chapter_"))
