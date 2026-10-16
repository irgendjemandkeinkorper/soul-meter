class_name WeftluminSceneCreator
extends RefCounted
## The `new_scene` document op (E3.4, §4.6.5): renders a scene template into the package scratch,
## writes the package's location document, registers the location live, and undoes all three.
##
## The op has no target node, so it lives here rather than in `WeftluminSceneModel`'s handlers
## (which resolve one); the scene model registers it on its bus. `target.scene` is the scratch
## scene path, so the new scene's later edits, which name the scene the session loaded, share its
## bake group. Travelling is the caller's step (`travel_to()`): a replay must never travel.

const OP_NEW_SCENE := "new_scene"


func register_ops(command_bus: WeftluminCommandBus) -> void:
	command_bus.register_document_op(WeftluminSceneModel.KIND, OP_NEW_SCENE, _capture, _apply, _revert)


## A `new_scene` command for `params` in `package`, or null with `errors` filled.
static func command(params: Dictionary, package: String, errors: Array[String]) -> WeftluminCommand:
	var normalised: Dictionary = WeftluminSceneTemplate.normalise(params, errors)
	if normalised.is_empty():
		return null
	var scene: String = WeftluminSceneTemplate.scratch_scene_path(package, str(normalised["id"]))
	return WeftluminCommand.make(WeftluminSceneModel.KIND, OP_NEW_SCENE, {"scene": scene}, normalised, package)


## Travel to a scene `new_scene` created (its default spawn). False when it is not registered or
## `GameFlow` refuses (it only travels from active play).
static func travel_to(location_id: String) -> bool:
	var location: LocationDefinition = LocationRegistry.by_id(StringName(location_id))
	var tree := Engine.get_main_loop() as SceneTree
	# Looked up, not named: core scripts must compile in a bare `--script` run before autoloads exist.
	var flow: Node = tree.root.get_node_or_null("GameFlow") if tree != null else null
	if location == null or flow == null:
		return false
	return bool(flow.call("travel", location.scene_path, location.default_spawn_id))


# --- bus handlers ------------------------------------------------------------------------------


func _capture(command: WeftluminCommand) -> Dictionary:
	var files: Dictionary = {}
	for path: String in _touched_paths(command):
		files[path] = {"exists": FileAccess.file_exists(path), "content": FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""}
	var id := StringName(str(command.params.get("id", "")))
	return {"files": files, "registered": LocationRegistry.by_id(id) != null}


func _apply(command: WeftluminCommand) -> Dictionary:
	var errors: Array[String] = []
	# A replayed log comes back with every number a float; normalise again.
	var params: Dictionary = WeftluminSceneTemplate.normalise(command.params, errors)
	if params.is_empty():
		return _blocked(&"schema", &"new_scene_params", "; ".join(PackedStringArray(errors)))
	var package: String = str(command.package)
	var scene: String = WeftluminSceneTemplate.scratch_scene_path(package, str(params["id"]))
	if str(command.target.get("scene", "")) != scene:
		return _blocked(&"scene_boundary", &"scratch_scene", "new_scene writes only %s." % scene)
	var baked: String = WeftluminSceneTemplate.baked_scene_path(params)
	var existing: LocationDefinition = LocationRegistry.by_id(StringName(str(params["id"])))
	if FileAccess.file_exists(baked) or (existing != null and existing.scene_path != scene):
		return _blocked(&"location", &"unused_location_id", "Location %s already exists; choose another id." % params["id"])
	var manifest: Dictionary = _manifest(package)
	if not str(manifest.get("hub", params["hub"])) in ["", str(params["hub"])]:
		return _blocked(&"package", &"package_hub", "Package %s belongs to hub %s, not %s." % [package, manifest["hub"], params["hub"]])
	manifest["schema"] = "weftlumin.package.v1"
	manifest["id"] = package
	manifest["hub"] = str(params["hub"])
	var kinds: Array = manifest.get("kinds", []) as Array
	for kind: String in ["scenes", "locations"]:
		if not kind in kinds:
			kinds.append(kind)
	manifest["kinds"] = kinds
	for write: Array in [
		[scene, WeftluminSceneTemplate.render(params)],
		[WeftluminSceneTemplate.scratch_document_path(package, str(params["id"])), JSON.stringify(WeftluminSceneTemplate.location_document(params), "  ", false) + "\n"],
		[WeftluminSceneTemplate.manifest_path(package), JSON.stringify(manifest, "  ", false) + "\n"],
	]:
		var error: Error = _write(str(write[0]), str(write[1]))
		if error != OK:
			return _blocked(&"save", &"writable_scratch", "Could not write %s: %s." % [write[0], error_string(error)])
	var interior: bool = str(params["template"]) == WeftluminSceneTemplate.INTERIOR
	if not LocationRegistry.register_runtime(WeftluminSceneTemplate.definition(params, scene), interior):
		return _blocked(&"location", &"unused_location_id", "LocationRegistry refused %s." % params["id"])
	return _allowed()


func _revert(command: WeftluminCommand) -> Dictionary:
	var files: Dictionary = command.pre_state.get("files", {}) as Dictionary
	for path: Variant in files:
		var state: Dictionary = files[path] as Dictionary
		var error: Error = OK
		if bool(state.get("exists", false)):
			error = _write(str(path), str(state.get("content", "")))
		elif FileAccess.file_exists(str(path)):
			error = DirAccess.remove_absolute(ProjectSettings.globalize_path(str(path)))
		if error != OK:
			return _blocked(&"save", &"writable_scratch", "Could not restore %s: %s." % [path, error_string(error)])
	if not bool(command.pre_state.get("registered", false)):
		LocationRegistry.unregister_runtime(StringName(str(command.params.get("id", ""))))
	return _allowed()


static func _touched_paths(command: WeftluminCommand) -> Array[String]:
	var package: String = str(command.package)
	var id: String = str(command.params.get("id", ""))
	return [
		WeftluminSceneTemplate.scratch_scene_path(package, id),
		WeftluminSceneTemplate.scratch_document_path(package, id),
		WeftluminSceneTemplate.manifest_path(package),
	]


static func _manifest(package: String) -> Dictionary:
	if not FileAccess.file_exists(WeftluminSceneTemplate.manifest_path(package)):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WeftluminSceneTemplate.manifest_path(package)))
	return parsed as Dictionary if parsed is Dictionary else {}


static func _write(path: String, text: String) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


static func _allowed() -> Dictionary:
	return {"allowed": true, "blocked_by": &"", "nearest_unblock": {}, "message": ""}


static func _blocked(by: StringName, unblock: StringName, message: String) -> Dictionary:
	return {"allowed": false, "blocked_by": by, "nearest_unblock": {"type": unblock}, "message": message}
