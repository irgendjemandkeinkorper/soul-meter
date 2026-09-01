extends SceneTree
## Applies a layout-mode scratch file to a PackedScene and saves the baked scene.

const LayoutOverridesScript := preload("res://globals/layout_overrides.gd")


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.is_empty():
		arguments = OS.get_cmdline_args()
	var scene_path: String = _option(arguments, "--scene")
	var override_path: String = _option(arguments, "--overrides")
	var output_path: String = _option(arguments, "--out")
	if output_path.is_empty():
		output_path = scene_path
	if scene_path.is_empty() or override_path.is_empty():
		printerr(
			"Usage: godot --headless --script tools/bake_layout_overrides.gd "
			+ "--scene <scene> --overrides <json> [--out <scene>]"
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
	# Gate r1 finding 1: output defaults to the SOURCE scene, so an override
	# file authored for a different scene must never bake — mirror the runtime
	# scene-match rejection before anything is applied or saved.
	var declared_scene: String = str(document.get("scene", ""))
	if declared_scene != scene_path:
		printerr(
			"Layout bake refused: overrides declare scene '%s' but --scene is '%s'."
			% [declared_scene, scene_path]
		)
		quit(7)
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
	var save_error: Error = ResourceSaver.save(baked, output_path)
	scene_root.free()
	if save_error != OK:
		printerr("Layout bake could not save scene: %s" % error_string(save_error))
		quit(6)
		return
	print(
		"Layout bake summary: edits=%d deletions=%d additions=%d skipped=%d -> %s"
		% [
			int(summary["edits_applied"]),
			int(summary["deletions_applied"]),
			int(summary["additions_applied"]),
			int(summary["skipped_paths"]),
			output_path,
		]
	)
	quit(0)


func _option(arguments: PackedStringArray, name: String) -> String:
	var index: int = arguments.find(name)
	if index < 0 or index + 1 >= arguments.size():
		return ""
	return arguments[index + 1]
