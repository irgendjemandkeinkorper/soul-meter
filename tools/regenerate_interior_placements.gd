extends SceneTree
## Run the canonical NPC generator without changing project autoloads or
## rewriting unrelated artifacts. The roster embeds the same placement rows.


func _initialize() -> void:
	call_deferred("_regenerate")


func _regenerate() -> void:
	await process_frame
	var pandora := root.get_node("Pandora")
	if not pandora.is_loaded():
		pandora.load_data()
	var generator = load("res://tools/generate_gloot.gd").new()
	var artifacts: Dictionary = generator._npc_artifacts()
	generator._write(generator.DOM_NPC_ROSTER_PATH, artifacts["roster_json"])
	generator._write(generator.DOM_NPC_PLACEMENTS_PATH, artifacts["placements_json"])
	generator.free()
	print("INTERIOR-PLACEMENTS: regenerated roster and placements from Pandora.")
	# Allow the autoload's threaded initial-scene request to finish before exit.
	await create_timer(0.2).timeout
	quit()
