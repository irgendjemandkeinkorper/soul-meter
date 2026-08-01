@tool
extends EditorPlugin
## Soul Meter's own tools menu (this addon is project-owned, not third-party).

const GeneratorScript := preload("res://tools/generate_gloot.gd")


func _enter_tree() -> void:
	add_tool_menu_item("Regenerate Pandora artifacts", _regenerate_data)


func _exit_tree() -> void:
	remove_tool_menu_item("Regenerate Pandora artifacts")


func _regenerate_data() -> void:
	if not Pandora.is_loaded():
		Pandora.load_data()
	var result: Dictionary = GeneratorScript.generate(false)
	print(
		(
			"Soul Meter Tools: regenerated %d items and %d encounters -> res://data/generated/"
			% [result["count"], result["encounter_count"]]
		)
	)
	EditorInterface.get_resource_filesystem().scan()
