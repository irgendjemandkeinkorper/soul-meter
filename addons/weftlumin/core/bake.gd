class_name WeftluminBake
extends RefCounted
## The scene bake (E3.5, `docs/architecture-in-game-editor.md` §4.6.2, §4.14): a command log's
## effective `scene` stream becomes surgical `.tscn` text patches, report-only by default.
##
## Bake = load the `.tscn` text → apply the scene commands from the log → validate → write. One
## session bakes one scene. A `WeftluminTileBake` owns the `TscnDocument` and the tile ops
## (`paint_cells`, `normalize_blocking_scale`). For every other scene op a `WeftluminSceneModel`
## over a fresh out-of-tree instance of the same file is the **oracle**: it captures `pre_state`
## exactly as the live model did (the bus refuses drift), runs the model's own ownership and type
## checks, and applies the op. The session then writes into the text only the stored properties
## the op changed on the oracle, through `TscnDocument`. Nothing is packed: untouched lines stay
## byte-identical, the format stays 3 and `uid://` references stay intact.
##
## Values go through the patcher's type-aware encoder. External resources are declared once
## (with their `uid://` when the project has one); a resource with no file of its own (a resized
## collision rectangle, the layout grayscale material) becomes a `sub_resource` with a
## `<Type>_weftlumin<N>` id. Bake-created sub-resources nothing references any more are pruned.
##
## Validators run on every baked text before anything is written: the built-in ones (the text
## loads and instantiates; every section the log did not touch is byte-identical; every node the
## bake wrote reloads equal to the oracle) and the host's contract validators
## (`options.validators`: `(context: Dictionary) -> Array` of attributed errors, context keys
## `scene, source_text, baked_text, source_document, document, commands, instance`). One error
## anywhere writes nothing at all.
##
## `write` writes each changed scene to `target_root` (`res://` patches in place). A target that
## exists and is neither the bake's source text nor its output (something else was written there)
## is refused unless `force`; `force` without `write` is an argument error, as in
## `tools/bake_campaign.gd`. The load check writes one transient copy under `user://` and deletes
## it; nothing else is written in report mode.

const SCHEMA := "weftlumin.bake.v1"
const KIND_ID := "scenes"
const SCENE_KIND := WeftluminSceneModel.KIND
const SCENE_OPS: Array[String] = [
	WeftluminSceneModel.OP_SET, WeftluminSceneModel.OP_ADD, WeftluminSceneModel.OP_REMOVE,
]
const CHECK_PREFIX := "user://weftlumin_bake_check_"
const TEMP_SUFFIX := ".weftlumin-tmp"
## Stored properties that are not scene data: the script is the node's identity, metadata is
## editor bookkeeping (`layout_addition`, `weftlumin_placed`) that must not become canon.
const NOT_WRITTEN: Array[String] = ["script", "name", "owner", "resource_path"]

var scene_path: String = ""
var source_text: String = ""
var tiles: WeftluminTileBake = null
var model: WeftluminSceneModel = null
var oracle: Node = null
## Node paths whose block this bake wrote (set properties, override blocks, added nodes).
var touched: Dictionary = {}
var removed: Array[String] = []

var _detached: Array[Node] = []
var _created_sub_ids: Array[String] = []
var _error: Dictionary = {}


## Bake `entries` (a `commands.jsonl` log, undo/redo bookkeeping included) into its scenes. The
## returned dictionary is the `weftlumin.bake.v1` report. `options`: `package` (defaults to the
## log's), `validators` (`Array` of `Callable`).
static func bake(
	entries: Array, target_root: String = "res://", write: bool = false, force: bool = false,
	options: Dictionary = {},
) -> Dictionary:
	var report: Dictionary = {
		"schema": SCHEMA, "package": str(options.get("package", "")),
		"mode": "write" if write else "report",
		"planned": [], "written": [], "regenerated": [],
		"lint": {"errors": 0, "warnings": 0, "pot_delta": []},
		"refused_overlap": [], "errors": [], "skipped_ops": 0, "normalized": [], "summary": "",
	}
	var errors: Array = report["errors"]
	if force and not write:
		errors.append(_attributed("", "force", "--write", "force_without_write", "--force applies only with --write."))
	var validators: Array = options.get("validators", []) as Array
	var groups: Dictionary = {}
	var order: Array[String] = []
	# Scenes a `new_scene` in this log creates: scratch path → normalised params (E3.4).
	var created: Dictionary = {}
	var skipped: int = 0
	for data: Dictionary in WeftluminCommandBus.effective_stream(entries):
		if str(data.get("kind", "")) != SCENE_KIND:
			skipped += 1
			continue
		if str(report["package"]).is_empty():
			report["package"] = str(data.get("package", ""))
		var target: Dictionary = data.get("target", {}) as Dictionary if data.get("target") is Dictionary else {}
		var scene: String = str(target.get("scene", ""))
		if scene.is_empty():
			errors.append(_attributed("", "target.scene", "scene path", "missing_scene", "Command %s names no scene." % data.get("id", "")))
			continue
		if not groups.has(scene):
			groups[scene] = []
			order.append(scene)
		if str(data.get("op", "")) == WeftluminSceneCreator.OP_NEW_SCENE:
			var problems: Array[String] = []
			var params: Dictionary = WeftluminSceneTemplate.normalise(data.get("params", {}) as Dictionary, problems)
			if params.is_empty() or not (groups[scene] as Array).is_empty():
				errors.append(_attributed(scene, "commands", "one valid new_scene before the scene's edits", "invalid_new_scene",
					"; ".join(PackedStringArray(problems)) if not problems.is_empty() else "%s has edits before its new_scene." % scene))
				continue
			created[scene] = params
			continue
		(groups[scene] as Array).append(data)
	report["skipped_ops"] = skipped
	var outputs: Dictionary = {}
	var total_ops: int = 0
	for scene: String in order:
		# A created scene bakes from its template, rendered again from the log, onto its baked path.
		var source: String = WeftluminSceneTemplate.render(created[scene]) if created.has(scene) else ""
		var result: Dictionary = bake_scene(scene, groups[scene], validators, source)
		var scene_errors: Array = result["errors"]
		errors.append_array(scene_errors)
		(report["normalized"] as Array).append_array(result["reports"])
		var target: String = retarget(WeftluminSceneTemplate.baked_scene_path(created[scene]) if created.has(scene) else scene, target_root)
		var action: String = "refused"
		if scene_errors.is_empty():
			var baked: String = result["text"]
			var exists: bool = FileAccess.file_exists(target)
			var current: String = FileAccess.get_file_as_string(target) if exists else ""
			if not exists:
				action = "create"
			elif current == baked:
				action = "unchanged"
			elif current != str(result["source"]) and not force:
				errors.append(_attributed(
					target, "$", "a target holding the bake's source or output", "stale_target",
					"%s holds neither %s nor this bake's output; pass --force to overwrite it." % [target, scene],
				))
			else:
				action = "update"
			if action in ["create", "update"]:
				outputs[target] = baked
		total_ops += int(result["ops"])
		(report["planned"] as Array).append({
			"kind": KIND_ID, "path": scene, "target": target, "ops": int(result["ops"]), "action": action,
		})
	if write and errors.is_empty():
		for target: String in outputs:
			var written: Error = _write_atomically(target, outputs[target])
			if written != OK:
				errors.append(_attributed(target, "$", "writable target", "write_failed", "Writing failed (error %d)." % written))
				break
			(report["written"] as Array).append(target)
	report["summary"] = "%d scene ops in %d scenes, %d changed, %d written, %d errors" % [
		total_ops, order.size(), outputs.size(), (report["written"] as Array).size(), errors.size(),
	]
	return report


## Bake one scene's commands (in log order, already effective). `{source, text, ops, errors,
## reports}`; `text` is the baked scene text when `errors` is empty.
## `source`, when given, is the scene's text in place of its file (a scene `new_scene` creates).
static func bake_scene(scene: String, commands: Array, validators: Array = [], source: String = "") -> Dictionary:
	var result: Dictionary = {"source": "", "text": "", "ops": 0, "errors": [], "reports": []}
	var errors: Array = result["errors"]
	if source.is_empty() and not FileAccess.file_exists(scene):
		errors.append(_attributed(scene, "$", "an existing .tscn", "missing_scene", "No scene file at %s." % scene))
		return result
	var session := WeftluminBake.new()
	if not session._open(scene, source):
		errors.append(session._error)
		session.close()
		return result
	result["source"] = session.source_text
	var outcome: Dictionary = session.tiles.bus.replay(commands)
	if bool(outcome.get("allowed", false)):
		var flushed: Dictionary = session.tiles.flush()
		if not bool(flushed.get("allowed", false)):
			outcome = flushed
	if not bool(outcome.get("allowed", false)):
		errors.append(_attributed(
			scene, "commands", "a log that replays onto the scene file",
			str(outcome.get("blocked_by", "refused")), str(outcome.get("message", "")),
		))
	else:
		session._prune_unused_sub_resources()
		result["text"] = session.tiles.text()
		result["ops"] = (outcome.get("applied", []) as Array).size()
		errors.append_array(session.validate(result["text"], commands, validators))
	result["reports"] = session.tiles.reports.duplicate(true)
	session.close()
	return result


## Where a bake of `scene` lands under `target_root` (`res://` or empty: in place).
static func retarget(scene: String, target_root: String) -> String:
	if target_root.is_empty() or target_root == "res://":
		return scene
	var relative: String = scene.trim_prefix("res://").trim_prefix("user://")
	return target_root.path_join(relative)


## True when a report planned no change and found no error.
static func report_is_clean(report: Dictionary) -> bool:
	if not (report.get("errors", []) as Array).is_empty():
		return false
	for entry: Dictionary in report.get("planned", []):
		if str(entry.get("action", "")) != "unchanged":
			return false
	return true


func close() -> void:
	if model != null:
		model.dispose()
		model = null
	if tiles != null:
		tiles.close()
	for node: Node in _detached:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()
	_detached.clear()
	if is_instance_valid(oracle):
		oracle.free()
	oracle = null


func document() -> TscnDocument:
	return tiles.document


# --- session ----------------------------------------------------------------------------------


func _open(scene: String, source: String = "") -> bool:
	scene_path = scene
	source_text = source if not source.is_empty() else FileAccess.get_file_as_string(scene)
	tiles = WeftluminTileBake.open(source_text, scene)
	if not source.is_empty():
		var load_errors: Array[Dictionary] = []
		oracle = _load(source_text, load_errors)
		if oracle == null:
			_error = load_errors[0] if not load_errors.is_empty() else _attributed(scene, "$", "a loadable scene", "unloadable_scene", "The template does not load.")
			return false
	else:
		var packed := ResourceLoader.load(scene, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if packed == null or not packed.can_instantiate():
			_error = _attributed(scene, "$", "a loadable scene", "unloadable_scene", "%s does not load as a scene." % scene)
			return false
		oracle = packed.instantiate()
	# An ignored-cache load leaves the path unset; the model reads editable paths through it.
	oracle.scene_file_path = scene
	model = WeftluminSceneModel.new()
	model.configure(oracle, tiles.bus)
	for op: String in SCENE_OPS:
		tiles.bus.register_document_op(SCENE_KIND, op, _capture, _apply, _revert)
	return true


func _capture(command: WeftluminCommand) -> Dictionary:
	return model._capture(command)


func _revert(_command: WeftluminCommand) -> Dictionary:
	return _blocked(&"history", &"fresh_bake", "A bake never reverts; bake the log again without the command.")


func _apply(command: WeftluminCommand) -> Dictionary:
	var path: String = str(command.target.get("node", ""))
	if _painted(path, command.op == WeftluminSceneModel.OP_REMOVE):
		return _blocked(&"bake", &"separate_logs", "%s is painted earlier in this log; bake its layout edits separately." % path)
	var node: Node = model._resolve(command)
	if node == null:
		return _blocked(&"scene_boundary", &"node_in_scene", "No node at %s." % path)
	match command.op:
		WeftluminSceneModel.OP_SET:
			return _apply_set(command, node)
		WeftluminSceneModel.OP_ADD:
			return _apply_add(command, node)
		WeftluminSceneModel.OP_REMOVE:
			return _apply_remove(command, node)
	return _blocked(&"handler", &"scene_op", "Unknown scene op %s." % command.op)


func _apply_set(command: WeftluminCommand, node: Node) -> Dictionary:
	var watched: Array[Node] = [node]
	if node is Node2D:
		var sprite: Sprite2D = LayoutOverrides.find_sprite(node)
		if sprite != null and sprite != node:
			watched.append(sprite)
		var collision: CollisionShape2D = LayoutOverrides._editable_collision(node as Node2D)
		if collision != null:
			watched.append(collision)
	var before: Array[Dictionary] = []
	for watched_node: Node in watched:
		before.append(_storage(watched_node))
	var outcome: Dictionary = model._apply(command)
	if not bool(outcome.get("allowed", false)):
		return outcome
	for index: int in watched.size():
		var refusal: Dictionary = _write_changes(watched[index], before[index])
		if not refusal.is_empty():
			return refusal
	return _allowed()


func _apply_add(command: WeftluminCommand, parent: Node) -> Dictionary:
	var parent_before: Dictionary = _storage(parent)
	var outcome: Dictionary = model._apply(command)
	if not bool(outcome.get("allowed", false)):
		return outcome
	var spec: Dictionary = command.params.get("instance", command.params.get("addition", {})) as Dictionary
	var child: Node = parent.get_node_or_null(NodePath(str(spec.get("name", ""))))
	if child == null:
		return _blocked(&"bake", &"added_node", "The oracle added no %s under %s." % [spec.get("name", ""), parent.name])
	# Adding a dressing prop conforms its layer (z_index / y-sort); that is part of the edit.
	var refusal: Dictionary = _write_changes(parent, parent_before)
	if refusal.is_empty():
		refusal = _write_added(child, _path_of(parent))
	return _allowed() if refusal.is_empty() else refusal


func _apply_remove(command: WeftluminCommand, node: Node) -> Dictionary:
	var path: String = _path_of(node)
	var outcome: Dictionary = model._apply(command)
	if not bool(outcome.get("allowed", false)):
		return outcome
	_detached.append(node)
	if not document().remove_node(path):
		return _refusal(document().last_error)
	removed.append(path)
	for known: String in touched.keys():
		if TscnDocument._is_at_or_below(known, path):
			touched.erase(known)
	return _allowed()


## Whether a painted layer is `path` (or, for a removal, below it).
func _painted(path: String, subtree: bool) -> bool:
	for layer: String in tiles._states:
		if layer == path or (subtree and TscnDocument._is_at_or_below(layer, path)):
			return true
	return false


# --- text writing -----------------------------------------------------------------------------


## Write every stored property of `node` that differs from `before`.
func _write_changes(node: Node, before: Dictionary) -> Dictionary:
	var after: Dictionary = _storage(node)
	for key: String in after:
		if before.has(key) and _same(before[key], after[key]):
			continue
		var path: String = _path_of(node)
		var ensured: Dictionary = _ensure_block(path)
		if not ensured.is_empty():
			return ensured
		var text: String = _encode(after[key], path, key)
		if text.is_empty():
			return _refusal(_error)
		if not document().set_property(path, key, text):
			return _refusal(document().last_error)
		touched[path] = true
	return {}


## Write a node the oracle added (and, unless it is an instanced scene, its children): its
## stored properties that differ from a default instance of the same scene or class.
func _write_added(node: Node, parent_path: String) -> Dictionary:
	var node_name: String = String(node.name)
	var path: String = node_name if parent_path == "." else parent_path + "/" + node_name
	var instanced: bool = not node.scene_file_path.is_empty()
	var header: String = ""
	var defaults: Node = null
	if instanced:
		var packed := load(node.scene_file_path) as PackedScene
		var resource_id: String = _declare(packed) if packed != null else ""
		if resource_id.is_empty():
			return _refusal(_error if not _error.is_empty() else _attributed(path, "instance", "a scene file", "unsupported_instance", "Cannot declare %s." % node.scene_file_path))
		header = "[node name=%s parent=%s instance=ExtResource(%s)]" % [
			var_to_str(node_name), var_to_str(parent_path), var_to_str(resource_id),
		]
		defaults = packed.instantiate()
	else:
		if node.get_script() != null or not ClassDB.can_instantiate(node.get_class()):
			return _blocked(&"bake", &"plain_node", "%s is a scripted node outside an instanced scene; the bake cannot write it." % path)
		header = "[node name=%s type=%s parent=%s]" % [
			var_to_str(node_name), var_to_str(node.get_class()), var_to_str(parent_path),
		]
		defaults = ClassDB.instantiate(node.get_class()) as Node
	var base: Dictionary = _storage(defaults)
	defaults.free()
	var lines: Array[String] = []
	var values: Dictionary = _storage(node)
	for key: String in values:
		if base.has(key) and _same(values[key], base[key]):
			continue
		var text: String = _encode(values[key], path, key)
		if text.is_empty():
			return _refusal(_error)
		lines.append("%s = %s" % [key, text])
	var block: String = header + "\n" + "\n".join(lines) + ("\n" if not lines.is_empty() else "")
	if not document().add_node(block, parent_path):
		return _refusal(document().last_error)
	touched[path] = true
	if not instanced:
		for child: Node in node.get_children():
			var refusal: Dictionary = _write_added(child, path)
			if not refusal.is_empty():
				return refusal
	return {}


## An override block for `path` when the file has none (a child of an editable instance).
func _ensure_block(path: String) -> Dictionary:
	if not tiles._node(path).is_empty():
		return {}
	var slash: int = path.rfind("/")
	if path == "." or path.is_empty():
		return _blocked(&"tscn_document", &"scene_root", "The scene file has no root node.")
	var parent: String = "." if slash < 0 else path.substr(0, slash)
	var refusal: Dictionary = _ensure_block(parent)
	if not refusal.is_empty():
		return refusal
	var block: String = "[node name=%s parent=%s]\n" % [var_to_str(path.substr(slash + 1)), var_to_str(parent)]
	if not document().add_node(block, parent):
		return _refusal(document().last_error)
	return {}


## Scene syntax for `value`; "" (with `_error` set) on refusal.
func _encode(value: Variant, path: String, key: String) -> String:
	_error = {}
	if value is Resource:
		var resource: Resource = value
		if resource.resource_path.begins_with("res://") and not resource.resource_path.contains("::"):
			var resource_id: String = _declare(resource)
			return "" if resource_id.is_empty() else "ExtResource(%s)" % var_to_str(resource_id)
		return _sub_resource(resource, path, key)
	if value is Object:
		_error = _attributed(scene_path, path + ":" + key, "a value or resource", "unsupported_value", "Objects other than resources cannot be baked.")
		return ""
	var text: String = document().encode_value(value, path, key)
	if text.is_empty():
		_error = document().last_error
	return text


## The id of `resource`'s `ext_resource`, declaring it (with its `uid://`) when absent.
func _declare(resource: Resource) -> String:
	var path: String = resource.resource_path
	for section: Dictionary in document().ext_resources:
		var attributes: Dictionary = section["attributes"]
		if str(attributes.get("path", "")) == path and resource.is_class(str(attributes.get("type", ""))):
			return str(attributes.get("id", ""))
	var uid: String = ""
	var known: int = ResourceLoader.get_resource_uid(path)
	if known != ResourceUID.INVALID_ID:
		uid = ResourceUID.id_to_text(known)
	var resource_id: String = document().add_ext_resource(path, _save_class(resource), uid)
	if resource_id.is_empty():
		_error = document().last_error
	return resource_id


## The type Godot writes for a resource's declaration (textures are declared `Texture2D`).
static func _save_class(resource: Resource) -> String:
	for base: String in ["Texture2D", "Script", "PackedScene", "Shader"]:
		if resource.is_class(base):
			return base
	return resource.get_class()


## `SubResource("<id>")` for a resource with no file of its own, reusing an identical one this
## bake already created.
func _sub_resource(resource: Resource, path: String, key: String) -> String:
	var type: String = resource.get_class()
	if resource.get_script() != null or not ClassDB.can_instantiate(type):
		_error = _attributed(scene_path, path + ":" + key, "a built-in resource", "unsupported_resource", "%s cannot be written as a sub_resource." % type)
		return ""
	var defaults := ClassDB.instantiate(type) as Resource
	var lines: Array[String] = []
	var values: Dictionary = _storage(resource)
	var base: Dictionary = _storage(defaults)
	for property: String in values:
		if property.begins_with("resource_") or (base.has(property) and _same(values[property], base[property])):
			continue
		var text: String = _encode(values[property], path, key + "/" + property)
		if text.is_empty():
			return ""
		lines.append("%s = %s" % [property, text])
	var body: String = "\n".join(lines)
	for existing: String in _created_sub_ids:
		var section: Dictionary = _sub_section(existing)
		if str(section.get("type", "")) == type and "\n".join(section.get("property_lines", [])) == body:
			return "SubResource(%s)" % var_to_str(existing)
	return _insert_sub_resource(type, body)


func _insert_sub_resource(type: String, body: String) -> String:
	var text: String = document().serialise()
	var newline: String = "\r\n" if text.contains("\r\n") else "\n"
	var sequence: int = 1
	while not _sub_section("%s_weftlumin%d" % [type, sequence]).is_empty():
		sequence += 1
	var resource_id: String = "%s_weftlumin%d" % [type, sequence]
	var insert_at: int = 0
	for section: Dictionary in document().sections:
		if str(section["kind"]) not in ["gd_scene", "ext_resource", "sub_resource"]:
			break
		insert_at = int(section["end_offset"])
	var block: String = "[sub_resource type=%s id=%s]" % [var_to_str(type), var_to_str(resource_id)] + newline
	if not body.is_empty():
		block += body.replace("\n", newline) + newline
	block += newline
	if insert_at > 0 and text.substr(insert_at - 1, 1) != "\n":
		block = newline + block
	text = text.substr(0, insert_at) + block + text.substr(insert_at)
	_reparse(_shift_load_steps(text, 1))
	_created_sub_ids.append(resource_id)
	return "SubResource(%s)" % var_to_str(resource_id)


## Remove bake-created sub-resources that a later edit left unreferenced.
func _prune_unused_sub_resources() -> void:
	for resource_id: String in _created_sub_ids.duplicate():
		var text: String = document().serialise()
		if text.contains("SubResource(%s)" % var_to_str(resource_id)):
			continue
		var section: Dictionary = _sub_section(resource_id)
		text = text.substr(0, int(section["start_offset"])) + text.substr(int(section["end_offset"]))
		_reparse(_shift_load_steps(text, -1))
		_created_sub_ids.erase(resource_id)


func _sub_section(resource_id: String) -> Dictionary:
	for section: Dictionary in document().sub_resources:
		if str((section["attributes"] as Dictionary).get("id", "")) == resource_id:
			return section
	return {}


## `text` with the header's `load_steps` (when present) moved by `delta`.
func _shift_load_steps(text: String, delta: int) -> String:
	var header: Dictionary = TscnDocument.parse(text).header
	if header.is_empty():
		return text
	var expression := RegEx.create_from_string('"(?:\\\\.|[^"\\\\])*"|(?<=[ \\t])load_steps[ \\t]*=[ \\t]*([0-9]+)(?=[ \\t\\]])')
	for found: RegExMatch in expression.search_all(str(header["header_line"])):
		if found.get_start(1) >= 0:
			var start: int = int(header["start_offset"]) + found.get_start(1)
			var end: int = int(header["start_offset"]) + found.get_end(1)
			return text.substr(0, start) + str(maxi(int(found.get_string(1)) + delta, 1)) + text.substr(end)
	return text


func _reparse(text: String) -> void:
	var parsed: TscnDocument = TscnDocument.parse(text)
	parsed.source_path = scene_path
	tiles.document = parsed


# --- validation -------------------------------------------------------------------------------


## Built-in validators, then the host's. Attributed errors; empty when the bake may be written.
func validate(text: String, commands: Array, validators: Array) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var source_document: TscnDocument = TscnDocument.parse(source_text)
	var baked_document: TscnDocument = TscnDocument.parse(text)
	found.append_array(_structural_errors(source_document, baked_document))
	var instance: Node = _load(text, found)
	if instance == null:
		return found
	found.append_array(_equivalence_errors(instance))
	var context: Dictionary = {
		"scene": scene_path, "source_text": source_text, "baked_text": text,
		"source_document": source_document, "document": baked_document,
		"commands": commands.duplicate(true), "instance": instance,
	}
	for validator: Variant in validators:
		if not validator is Callable or not (validator as Callable).is_valid():
			continue
		var result: Variant = (validator as Callable).call(context)
		if result is Array:
			for entry: Variant in result:
				if entry is Dictionary:
					found.append(entry as Dictionary)
	instance.free()
	return found


## Format and header identity kept; every ext_resource declaration kept verbatim (`uid://` refs
## intact); every sub-resource, node, connection and editable path the log did not touch kept
## byte-identical.
func _structural_errors(before: TscnDocument, after: TscnDocument) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for key: String in ["format", "uid"]:
		if str(before.header["attributes"].get(key, "")) != str(after.header["attributes"].get(key, "")):
			found.append(_attributed(scene_path, "gd_scene." + key, "unchanged header", "header_changed", "The bake changed the scene's %s." % key))
	var declarations: Dictionary = {}
	for section: Dictionary in after.ext_resources:
		declarations[section["header_line"]] = true
	for section: Dictionary in before.ext_resources:
		if not declarations.has(section["header_line"]):
			found.append(_attributed(scene_path, "ext_resource", section["header_line"], "declaration_changed", "An external resource declaration changed."))
	var sub_texts: Dictionary = {}
	for section: Dictionary in after.sub_resources:
		sub_texts[section["raw_text"]] = true
	for section: Dictionary in before.sub_resources:
		if not sub_texts.has(section["raw_text"]):
			found.append(_attributed(scene_path, "sub_resource", str(section["attributes"].get("id", "")), "sub_resource_changed", "A sub-resource changed."))
	var after_nodes: Dictionary = {}
	for section: Dictionary in after.nodes:
		after_nodes[_section_path(section)] = section["raw_text"]
	for section: Dictionary in before.nodes:
		var path: String = _section_path(section)
		if touched.has(path) or _painted(path, false) or _under_removed(path):
			continue
		if after_nodes.get(path, "") != section["raw_text"]:
			found.append(_attributed(scene_path, path, "an untouched node block", "untouched_node_changed", "The bake changed %s, which the log does not edit." % path))
	var kept: Dictionary = {}
	for section: Dictionary in after.connections + after.editable_paths:
		kept[section["raw_text"]] = true
	for section: Dictionary in before.connections + before.editable_paths:
		var attributes: Dictionary = section["attributes"]
		var paths: Array[String] = [str(attributes.get("from", "")), str(attributes.get("to", "")), str(attributes.get("path", ""))]
		var dropped: bool = false
		for path: String in paths:
			dropped = dropped or (not path.is_empty() and _under_removed(path))
		if not dropped and not kept.has(section["raw_text"]):
			found.append(_attributed(scene_path, str(section["kind"]), section["header_line"], "section_changed", "A connection or editable path changed."))
	return found


## The baked text, loaded and instantiated (out of tree) from a transient copy.
func _load(text: String, found: Array[Dictionary]) -> Node:
	var check_path: String = "%s%d_%d.tscn" % [CHECK_PREFIX, get_instance_id(), Time.get_ticks_usec()]
	# A copy must not claim the source scene's uid.
	var copy: String = RegEx.create_from_string('^(\\[gd_scene[^\\n]*?) uid="uid://[^"]*"').sub(text, "$1")
	var file := FileAccess.open(check_path, FileAccess.WRITE)
	if file == null:
		found.append(_attributed(scene_path, "$", "a writable load-check copy", "load_check_failed", "Cannot write %s." % check_path))
		return null
	file.store_string(copy)
	file.close()
	var packed := ResourceLoader.load(check_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	DirAccess.remove_absolute(ProjectSettings.globalize_path(check_path))
	var instance: Node = packed.instantiate() if packed != null and packed.can_instantiate() else null
	if instance == null:
		found.append(_attributed(scene_path, "$", "a baked scene that loads and instantiates", "unloadable_bake", "The baked text does not load as a scene."))
	return instance


## Every node the bake wrote reloads with the oracle's stored values; removed nodes stay gone.
func _equivalence_errors(instance: Node) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var paths: Array = touched.keys()
	paths.sort()
	for path: String in paths:
		var expected: Node = oracle.get_node_or_null(NodePath(path))
		var actual: Node = instance.get_node_or_null(NodePath(path))
		if expected == null or actual == null:
			found.append(_attributed(scene_path, path, "the node in both the oracle and the bake", "bake_mismatch", "%s is missing from the %s." % [path, "oracle" if expected == null else "baked scene"]))
			continue
		var wanted: Dictionary = _storage(expected)
		var got: Dictionary = _storage(actual)
		for key: String in wanted:
			if not _equivalent(wanted[key], got.get(key)):
				found.append(_attributed(scene_path, path + ":" + key, var_to_str(wanted[key]) if not wanted[key] is Object else str(wanted[key]), "bake_mismatch", "%s:%s reloads differently from the replayed edit." % [path, key]))
	for path: String in removed:
		if oracle.get_node_or_null(NodePath(path)) == null and instance.get_node_or_null(NodePath(path)) != null:
			found.append(_attributed(scene_path, path, "a removed node", "bake_mismatch", "%s was removed but reloads." % path))
	return found


func _under_removed(path: String) -> bool:
	for gone: String in removed:
		if TscnDocument._is_at_or_below(path, gone):
			return true
	return false


# --- values -----------------------------------------------------------------------------------


func _path_of(node: Node) -> String:
	return String(oracle.get_path_to(node))


static func _section_path(section: Dictionary) -> String:
	var attributes: Dictionary = section["attributes"]
	if not attributes.has("parent"):
		return "."
	var parent: String = str(attributes["parent"])
	var node_name: String = str(attributes.get("name", ""))
	return node_name if parent == "." else parent + "/" + node_name


## Stored (scene-serialised) properties of `object`, minus identity and metadata.
static func _storage(object: Object) -> Dictionary:
	var values: Dictionary = {}
	for property: Dictionary in object.get_property_list():
		var property_name: String = str(property["name"])
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE == 0 or NOT_WRITTEN.has(property_name) \
				or property_name.begins_with("metadata/"):
			continue
		values[property_name] = object.get(property_name)
	return values


static func _same(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if left is Object:
		return left == right
	return var_to_str(left) == var_to_str(right)


## Equal as scene data: the same external resource, or built-in resources with equal stored values.
static func _equivalent(left: Variant, right: Variant, depth: int = 0) -> bool:
	if left is Resource and right is Resource:
		var expected: Resource = left
		var actual: Resource = right
		if expected.resource_path.begins_with("res://") and not expected.resource_path.contains("::"):
			return expected.resource_path == actual.resource_path
		if expected.get_class() != actual.get_class() or depth > 4:
			return expected.get_class() == actual.get_class()
		var wanted: Dictionary = _storage(expected)
		var got: Dictionary = _storage(actual)
		for key: String in wanted:
			if not key.begins_with("resource_") and not _equivalent(wanted[key], got.get(key), depth + 1):
				return false
		return true
	if left is Object or right is Object:
		return left == right
	return _same(left, right)


static func _write_atomically(target: String, text: String) -> Error:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if directory_error != OK and not DirAccess.dir_exists_absolute(target.get_base_dir()):
		return directory_error
	var temporary: String = target + TEMP_SUFFIX
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return DirAccess.rename_absolute(temporary, target)


func _refusal(error: Dictionary) -> Dictionary:
	return _blocked(&"tscn_document", &"writable_scene", "%s: %s" % [error.get("field", ""), error.get("message", "write refused")])


static func _attributed(file: String, field: String, expected: String, code: String, message: String) -> Dictionary:
	return {"file": file, "field": field, "expected": expected, "code": code, "message": message}


static func _allowed() -> Dictionary:
	return {"allowed": true, "blocked_by": &"", "nearest_unblock": &"", "message": ""}


static func _blocked(by: StringName, unblock: StringName, message: String) -> Dictionary:
	return {"allowed": false, "blocked_by": by, "nearest_unblock": unblock, "message": message}
