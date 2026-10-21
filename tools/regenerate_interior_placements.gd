extends SceneTree
## Run the canonical NPC generator without changing project autoloads or
## rewriting unrelated artifacts. Every hub's roster embeds its own placement rows.


func _initialize() -> void:
	call_deferred("_regenerate")


func _regenerate() -> void:
	await process_frame
	var pandora := root.get_node("Pandora")
	if not pandora.is_loaded():
		pandora.load_data()
	var generator = load("res://tools/generate_gloot.gd").new()
	var artifacts: Dictionary = generator._npc_artifacts()
	for town_id: String in artifacts["towns"]:
		var town: Dictionary = artifacts["towns"][town_id]
		generator._write(town["roster_path"], town["roster_json"])
		generator._write(town["placements_path"], town["placements_json"])
	generator.free()
	print("INTERIOR-PLACEMENTS: regenerated roster and placements from Pandora.")
	# Allow the autoload's threaded initial-scene request to finish before exit.
	await create_timer(0.2).timeout
	quit()
