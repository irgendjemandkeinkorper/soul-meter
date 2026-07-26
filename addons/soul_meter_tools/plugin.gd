@tool
extends EditorPlugin
## Soul Meter's own tools menu (this addon is project-owned, not third-party).

const GeneratorScript := preload("res://tools/generate_gloot.gd")

func _enter_tree() -> void:
	add_tool_menu_item("Regenerate GLoot prototypes", _regenerate_gloot)


func _exit_tree() -> void:
	remove_tool_menu_item("Regenerate GLoot prototypes")


func _regenerate_gloot() -> void:
	if not Pandora.is_loaded():
		Pandora.load_data()
	var result: Dictionary = GeneratorScript.generate(false)
	print("Soul Meter Tools: regenerated %d GLoot prototypes -> res://data/generated/" % result["count"])
	EditorInterface.get_resource_filesystem().scan()
