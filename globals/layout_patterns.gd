extends RefCounted
## Reusable layout patterns — a saved group of dressing props that can be stamped anywhere,
## the way a WordPress pattern is inserted into a page.
##
## THIS FILE IS THE DURABLE HALF. The F10 layout editor is scheduled for replacement by
## Weftlumin (#337 deletes the legacy debug autoloads; #338/#339 re-host selection and the
## palette), so the pattern *format* is deliberately editor-agnostic: nothing below touches a
## Control, an input event, or the editor's selection state. A pattern is a pure document plus
## two pure transforms — `capture()` turns live nodes into one, `stamp()` turns one back into
## `layout_overrides` additions. Porting the UI does not touch this file, and patterns authored
## in F10 stay readable afterwards.
##
## Why additions and nothing else: a stamped pattern is expressed in the SAME `additions`
## records `layout_overrides.gd` already applies and `tools/bake_layout_overrides.gd` already
## bakes. There is no second apply path to keep in step, and no pattern can express an edit a
## hand-placed prop could not.
##
## Geometry: node offsets are stored in WORLD space relative to the pattern's anchor, not in
## any layer's local space. A pattern routinely spans GroundDetails, SoftDetails and SolidProps,
## and those layers are not required to share a transform — storing local coordinates would
## silently skew a pattern the first time a scene nested one of them. `stamp()` converts back
## through each destination layer's own `to_local()`.

const LayoutOverrides := preload("res://globals/layout_overrides.gd")

const SCHEMA_VERSION := 1
const PATTERN_DIRECTORY := "user://layout_patterns"
## Scratch, like layout overrides. Patterns are authoring material, so they are promoted into
## the repo deliberately (see docs/layout-mode.md) rather than written straight to res://,
## which is not writable in an exported build anyway.

## The anchor is the minimum corner of the selection's world-space positions, so every stored
## offset is non-negative and a stamp lands the pattern's top-left under the cursor. Centroid
## anchoring reads better for a single blob but makes tiled repeats drift, and tiling is the
## motivating case.


static func create_pattern(id: StringName, display_name: String) -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"id": String(id),
		"name": display_name,
		"tags": [],
		"nodes": [],
	}


## Kebab id derived from a display name, so a pattern's file name is predictable and a
## re-save under the same name overwrites the same pattern rather than accumulating copies.
static func id_for_name(display_name: String) -> StringName:
	var lowered: String = display_name.strip_edges().to_lower()
	var builder: String = ""
	for index in lowered.length():
		var character: String = lowered[index]
		if character.is_valid_identifier() or (character >= "0" and character <= "9"):
			builder += character
		elif character == "_" or character == "-" or character == " ":
			builder += "-"
	while builder.contains("--"):
		builder = builder.replace("--", "-")
	builder = builder.lstrip("-").rstrip("-")
	return StringName(builder)


static func pattern_path_for_id(id: StringName) -> String:
	return PATTERN_DIRECTORY.path_join("%s.json" % String(id))


static func to_json(pattern: Dictionary) -> String:
	if not _has_valid_schema(pattern):
		push_warning("Layout pattern has an unsupported schema.")
		return ""
	return JSON.stringify(pattern, "  ") + "\n"


static func from_json(content: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		push_warning("Layout pattern file is not a JSON object.")
		return {}
	var pattern: Dictionary = parsed as Dictionary
	if not _has_valid_schema(pattern):
		push_warning(
			"Layout pattern schema mismatch (expected %d, found %s)."
			% [SCHEMA_VERSION, str(pattern.get("schema", "missing"))]
		)
		return {}
	if String(pattern.get("id", "")).is_empty():
		push_warning("Layout pattern is missing an id.")
		return {}
	if not pattern.get("nodes", null) is Array:
		push_warning("Layout pattern is missing its nodes array.")
		return {}
	return pattern


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Layout pattern file could not be opened: %s" % path)
		return {}
	var content: String = file.get_as_text()
	file.close()
	return from_json(content)


static func save_file(
	path: String, pattern: Dictionary, _promote_for_tests: Callable = Callable()
) -> Error:
	return LayoutOverrides.save_json(path, to_json(pattern), _promote_for_tests)


## Every saved pattern, sorted by id so the library list is stable between sessions.
static func list_patterns(directory_path: String = PATTERN_DIRECTORY) -> Array[Dictionary]:
	var patterns: Array[Dictionary] = []
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return patterns
	var names: Array[String] = []
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if not directory.current_is_dir() and entry.get_extension().to_lower() == "json":
			names.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	names.sort()
	for name: String in names:
		var pattern: Dictionary = load_file(directory_path.path_join(name))
		if not pattern.is_empty():
			patterns.append(pattern)
	return patterns


static func delete_pattern(id: StringName) -> Error:
	var path: String = pattern_path_for_id(id)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Turns a live selection into a pattern document.
##
## Only nodes `layout_overrides` can already recreate are eligible — the same
## `supports_addition()` predicate the Duplicate command uses. A scene's authored NPC, facade
## or travel exit carries script state and dialogue ids that an addition record cannot express,
## so those are REFUSED BY NAME rather than silently dropped: a pattern that quietly lost half
## the selection would be discovered only after it was stamped somewhere.
##
## Returns the shared refusal shape: `{allowed, blocked_by, nearest_unblock, message}` plus
## `pattern` and `refused` (display names) on success.
static func capture(
	nodes: Array, display_name: String, tags: Array = []
) -> Dictionary:
	var trimmed: String = display_name.strip_edges()
	if trimmed.is_empty():
		return _blocked(&"name", &"pattern_name", "A pattern needs a name.")
	var id: StringName = id_for_name(trimmed)
	if String(id).is_empty():
		return _blocked(
			&"name", &"pattern_name", "That name has no letters or digits to build an id from."
		)

	var eligible: Array[Node2D] = []
	var refused: Array[String] = []
	for candidate: Variant in nodes:
		var node := candidate as Node2D
		if node == null or not is_instance_valid(node) or node.get_parent() == null:
			continue
		var layer_name := StringName(node.get_parent().name)
		if LayoutOverrides.supports_addition(node, layer_name):
			eligible.append(node)
		else:
			refused.append(String(node.name))
	if eligible.is_empty():
		return _blocked(
			&"composition",
			&"patternable_selection",
			"Nothing in this selection can be saved as a pattern. Patterns hold placed dressing "
			+ "props; authored actors carry state a pattern cannot express.",
		)

	var anchor: Vector2 = _anchor_of(eligible)
	var pattern: Dictionary = create_pattern(id, trimmed)
	for tag: Variant in tags:
		(pattern["tags"] as Array).append(String(tag))
	var records: Array = pattern["nodes"] as Array
	for node: Node2D in eligible:
		var layer_name := StringName(node.get_parent().name)
		var record: Dictionary = LayoutOverrides.capture_addition(node, layer_name)
		if record.is_empty():
			refused.append(String(node.name))
			continue
		# The stamp assigns a fresh unique name, and position is recomputed per destination
		# layer, so neither survives into the pattern.
		record.erase("name")
		record.erase("position")
		var offset: Vector2 = node.global_position - anchor
		record["offset"] = [offset.x, offset.y]
		records.append(record)
	if records.is_empty():
		return _blocked(
			&"composition", &"patternable_selection", "This selection could not be captured."
		)
	# Deterministic order, so re-saving the same props produces a byte-identical file whatever
	# order they were clicked in.
	records.sort_custom(_by_layer_then_offset)
	return _allowed({"pattern": pattern, "refused": refused})


## Turns a pattern back into `layout_overrides` additions positioned at `world_position`.
##
## `layer_resolver` maps a layer name to the destination `Node2D`, and `name_resolver` maps a
## (layer, texture path) pair to a unique node name. Both are injected rather than looked up so
## this stays free of any scene-tree assumptions and is testable without a scene.
static func stamp(
	pattern: Dictionary,
	world_position: Vector2,
	layer_resolver: Callable,
	name_resolver: Callable,
	snap_step: float = 0.0
) -> Dictionary:
	if not _has_valid_schema(pattern):
		return _blocked(&"schema", &"known_schema", "That pattern has an unsupported schema.")
	var records: Variant = pattern.get("nodes", [])
	if not records is Array or (records as Array).is_empty():
		return _blocked(&"composition", &"present_nodes", "That pattern is empty.")
	var origin: Vector2 = world_position
	if snap_step > 0.0:
		origin = (origin / snap_step).round() * snap_step

	var additions: Array = []
	var missing_layers: Array[String] = []
	# A pattern routinely repeats the same texture (three of the same crate). None of them are
	# in the tree yet, so a name resolver that only inspects the scene would hand out the same
	# name twice and the second prop would be dropped — hence the per-layer reserved list.
	var claimed: Dictionary = {}
	for entry: Variant in records as Array:
		var record: Dictionary = (entry as Dictionary).duplicate(true)
		var layer_name := StringName(str(record.get("layer", "")))
		var layer := layer_resolver.call(layer_name) as Node2D
		if layer == null:
			if not missing_layers.has(String(layer_name)):
				missing_layers.append(String(layer_name))
			continue
		var offset: Vector2 = _to_vector(record.get("offset", [0.0, 0.0]))
		var local: Vector2 = layer.to_local(origin + offset)
		record.erase("offset")
		record["position"] = [local.x, local.y]
		var reserved: PackedStringArray = claimed.get(layer_name, PackedStringArray())
		var chosen := String(name_resolver.call(layer, str(record.get("texture", "")), reserved))
		reserved.append(chosen)
		claimed[layer_name] = reserved
		record["name"] = chosen
		additions.append(record)
	if additions.is_empty():
		return _blocked(
			&"composition",
			&"present_layers",
			"This scene has none of the layers that pattern needs: %s."
			% ", ".join(missing_layers),
		)
	return _allowed({"additions": additions, "skipped_layers": missing_layers})


## Subsequence fuzzy match, the same shape an editor palette filter wants: every character of
## `query` must appear in `text` in order. Returns -1 for no match, otherwise a score where
## LOWER is better — earlier first match and tighter spread rank above a scattered one, so
## "mkt" prefers "market" over "make-a-street".
##
## Deliberately not a library: this needs to be deterministic and testable more than it needs
## to be clever, and the palette is a few hundred short strings.
static func fuzzy_score(query: String, text: String) -> int:
	var needle: String = query.strip_edges().to_lower()
	if needle.is_empty():
		return 0
	var haystack: String = text.to_lower()
	var cursor: int = 0
	var first_hit: int = -1
	var last_hit: int = -1
	for index in needle.length():
		var character: String = needle[index]
		var found: int = haystack.find(character, cursor)
		if found < 0:
			return -1
		if first_hit < 0:
			first_hit = found
		last_hit = found
		cursor = found + 1
	# Spread (how stretched the match is) dominates; position breaks ties.
	return (last_hit - first_hit) * 100 + first_hit


static func _anchor_of(nodes: Array[Node2D]) -> Vector2:
	var anchor := Vector2.INF
	for node: Node2D in nodes:
		var position: Vector2 = node.global_position
		anchor.x = position.x if anchor.x == INF else minf(anchor.x, position.x)
		anchor.y = position.y if anchor.y == INF else minf(anchor.y, position.y)
	return Vector2.ZERO if anchor == Vector2.INF else anchor


static func _by_layer_then_offset(a: Dictionary, b: Dictionary) -> bool:
	var layer_a: String = str(a.get("layer", ""))
	var layer_b: String = str(b.get("layer", ""))
	if layer_a != layer_b:
		return layer_a < layer_b
	var offset_a: Vector2 = _to_vector(a.get("offset", [0.0, 0.0]))
	var offset_b: Vector2 = _to_vector(b.get("offset", [0.0, 0.0]))
	if offset_a.y != offset_b.y:
		return offset_a.y < offset_b.y
	if offset_a.x != offset_b.x:
		return offset_a.x < offset_b.x
	return str(a.get("texture", "")) < str(b.get("texture", ""))


static func _to_vector(value: Variant) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO


static func _has_valid_schema(pattern: Dictionary) -> bool:
	var version: Variant = pattern.get("schema", null)
	return (version is int or version is float) and int(version) == SCHEMA_VERSION


static func _allowed(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"allowed": true, "blocked_by": &"", "nearest_unblock": {}, "message": ""
	}
	result.merge(extra, true)
	return result


static func _blocked(blocked_by: StringName, unblock: StringName, message: String) -> Dictionary:
	return {
		"allowed": false,
		"blocked_by": blocked_by,
		"nearest_unblock": {"type": unblock},
		"message": message,
	}
