extends SceneTree
## Deterministic, font-free SVG rasterization using the project's own Godot build.
## godot --headless --path . --script tools/export_icons.gd

const SOURCE := "res://assets/icons/src"
const SIZES: Array[int] = [24, 64]


func _initialize() -> void:
	var entries: Array[Dictionary] = []
	for group: String in ["commands", "elements", "items"]:
		for filename: String in DirAccess.get_files_at(SOURCE.path_join(group)):
			if filename.get_extension() != "svg":
				continue
			var source := SOURCE.path_join(group).path_join(filename)
			var svg := FileAccess.get_file_as_string(source)
			var entry: Dictionary = {"source": source.trim_prefix("res://"), "exports": []}
			for size: int in SIZES:
				var image := Image.new()
				if image.load_svg_from_string(svg, float(size) / 64.0) != OK:
					push_error("Cannot rasterize %s" % source)
					quit(1)
					return
				var output := "res://assets/icons/png/%d/%s/%s.png" % [size, group, filename.get_basename()]
				DirAccess.make_dir_recursive_absolute(output.get_base_dir())
				if image.save_png(output) != OK:
					push_error("Cannot save %s" % output)
					quit(1)
					return
				entry["exports"].append({"path": output.trim_prefix("res://"), "size": size})
			entries.append(entry)
	var manifest := FileAccess.open("res://assets/icons/manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"generator": "tools/export_icons.gd", "sizes": SIZES,
		"palette_source": "ui/theme/ds.gd", "approval": "pending_owner_review", "files": entries}, "\t") + "\n")
	print("Exported %d SVG icons at 24 and 64 px" % entries.size())
	quit()
