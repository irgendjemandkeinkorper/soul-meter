extends Node2D

@export var arrival_flag: String


func _ready() -> void:
	var definition := LocationRegistry.by_scene(scene_file_path)
	if arrival_flag.is_empty() and definition != null:
		arrival_flag = definition.arrival_flag
	if not arrival_flag.is_empty():
		GameState.set_flag(arrival_flag, true)
		SaveGame.request_checkpoint(
			SaveGame.Checkpoint.LOCATION_ARRIVAL, arrival_flag.trim_prefix("chapter_")
		)
