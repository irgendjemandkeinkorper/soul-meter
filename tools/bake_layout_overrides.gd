extends SceneTree
## Applies a layout-mode scratch file to a PackedScene and saves the baked scene.

const LayoutOverridesScript := preload("res://globals/layout_overrides.gd")


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		arguments = OS.get_cmdline_args()

	var options: Dictionary = parse_arguments(arguments)
	var scene_path: String = str(options.get("scene", ""))
	var override_path: String = str(options.get("overrides", ""))
	var output_path: String = str(options.get("out", ""))
	var write: bool = bool(options.get("write", false))
	var force: bool = bool(options.get("force", false))

	if output_path.is_empty():
		output_path = scene_path

	if scene_path.is_empty() or override_path.is_empty():
		printerr(
			"Usage: godot --headless --script tools/bake_layout_overrides.gd "
			+ "--scene <scene> --overrides <json> [--out <scene>] [--write] [--force]"
		)
		quit(2)
		return

	var packed: PackedScene = ResourceLoader.load(
		scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
	) as PackedScene
	if packed == null:
		printerr("Layout bake could not load scene: %s" % scene_path)
		quit(3)
		return
	var document: Dictionary = LayoutOverridesScript.load_file(override_path)
	if document.is_empty():
		printerr("Layout bake could not load overrides: %s" % override_path)
		quit(4)
		return

	var declared_scene: String = str(document.get("scene", ""))
	if declared_scene != scene_path:
		printerr(
			"Layout bake refused: overrides declare scene '%s' but --scene is '%s'."
			% [declared_scene, scene_path]
		)
		quit(7)
		return

	if FileAccess.file_exists(output_path) and write and not force:
		printerr(
			"Layout bake refused: target file '%s' exists. Pass --force to overwrite."
			% output_path
		)
		quit(8)
		return

	var scene_root: Node = packed.instantiate()
	var summary: Dictionary = LayoutOverridesScript.apply_to_scene(scene_root, document, true)
	var baked := PackedScene.new()
	var pack_error: Error = baked.pack(scene_root)
	if pack_error != OK:
		printerr("Layout bake could not pack scene: %s" % error_string(pack_error))
		scene_root.free()
		quit(5)
		return

	if write:
		var save_error: Error = ResourceSaver.save(baked, output_path)
		scene_root.free()
		if save_error != OK:
			printerr("Layout bake could not save scene: %s" % error_string(save_error))
			quit(6)
			return
	else:
		scene_root.free()

	var mode_label: String = " (report-only)" if not write else ""
	print(
		"Layout bake summary: edits=%d deletions=%d additions=%d skipped=%d -> %s%s"
		% [
			int(summary["edits_applied"]),
			int(summary["deletions_applied"]),
			int(summary["additions_applied"]),
			int(summary["skipped_paths"]),
			output_path,
			mode_label,
		]
	)
	quit(0)


static func parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var options: Dictionary = {
		"scene": "",
		"overrides": "",
		"out": "",
		"write": false,
		"force": false,
	}
	var index: int = 0
	while index < arguments.size():
		var argument: String = arguments[index]
		if argument == "--write":
			options["write"] = true
		elif argument == "--force":
			options["force"] = true
		elif argument in ["--scene", "--overrides", "--out"]:
			if index + 1 < arguments.size():
				index += 1
				options[argument.trim_prefix("--")] = arguments[index]
		elif argument.begins_with("--scene="):
			options["scene"] = argument.trim_prefix("--scene=")
		elif argument.begins_with("--overrides="):
			options["overrides"] = argument.trim_prefix("--overrides=")
		elif argument.begins_with("--out="):
			options["out"] = argument.trim_prefix("--out=")
		index += 1
	return options
