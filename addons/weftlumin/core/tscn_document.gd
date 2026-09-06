class_name TscnDocument
extends RefCounted

## Lossless, text-level view of a Godot text scene.
##
## Values and complete section text stay opaque. Surgical operations replace only
## affected spans without asking Godot to load or re-encode the scene. Mutations
## return false on refusal and expose an attributed last_error; source_path is
## optional provenance for errors and resolving local subresource references.

var header: Dictionary = {}
var ext_resources: Array[Dictionary] = []
var sub_resources: Array[Dictionary] = []
var nodes: Array[Dictionary] = []
var connections: Array[Dictionary] = []
var editable_paths: Array[Dictionary] = []
var sections: Array[Dictionary] = []
var preamble: String = ""
var source_path: String = ""
var last_error: Dictionary = {}

var _source_text: String = ""


static func parse(text: String) -> TscnDocument:
	var document: TscnDocument = TscnDocument.new()
	document._source_text = text
	document._parse_sections()
	return document


func serialise() -> String:
	return _source_text


## Values are scene syntax, normally produced by encode_value(). No scene is loaded.
func set_property(node_path: String, key: String, value_text: String) -> bool:
	last_error = {}
	var node: Dictionary = _find_node(node_path)
	if node.is_empty():
		return _fail(node_path, "node_not_found", "No node at this scene-relative path.")
	var key_pattern := RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_/]*$")
	if key_pattern.search(key) == null or value_text.strip_edges().is_empty():
		return _fail(node_path + ":" + key, "invalid_property", "A property key and value are required.")
	var value: String = value_text.strip_edges()
	if _value_end(value, 0, value.length()) != value.length():
		return _fail(node_path + ":" + key, "invalid_value", "Expected one scene value with matching delimiters, not additional lines or comments.")
	var properties: Array[Dictionary] = _properties(node)
	if not last_error.is_empty():
		return false
	for property: Dictionary in properties:
		if property["key"] == key:
			_replace_range(property["value_start"], property["value_end"], value)
			return true
	var insert_at: int = int(node["end_offset"])
	while insert_at > int(node["body_start_offset"]) and _source_text.substr(insert_at - 1, 1) in ["\n", "\r"]:
		insert_at -= 1
	var prefix: String = "" if insert_at == 0 or _source_text.substr(insert_at - 1, 1) == "\n" else _newline()
	_replace_range(insert_at, insert_at, prefix + key + " = " + value + _newline())
	return true


## index is the new node's sibling position; -1 appends after the parent's subtree.
func add_node(block: String, parent: String, index: int = -1) -> bool:
	last_error = {}
	var parent_node: Dictionary = _find_node(parent)
	if parent_node.is_empty():
		return _fail(parent, "node_not_found", "The new node's parent must exist.")
	var fragment: TscnDocument = TscnDocument.parse(block)
	if fragment.sections.size() != 1 or fragment.nodes.size() != 1 or not fragment.preamble.is_empty():
		return _fail(parent, "invalid_node_block", "Expected exactly one node block.")
	var node: Dictionary = fragment.nodes[0]
	var header_line: String = node["header_line"]
	if not header_line.ends_with("]") or _line_ends_in_string(header_line, false):
		return _fail(parent, "invalid_node_block", "Node header must have closed quotes and a closing bracket.")
	var name: String = str(node["attributes"].get("name", ""))
	if name.is_empty() or name != name.validate_node_name() or name.contains("\n"):
		return _fail(parent, "invalid_node_name", "Expected a nonempty node name that Godot preserves unchanged.")
	var path: String = name if parent == "." else parent + "/" + name
	fragment._properties(node)
	if not fragment.last_error.is_empty():
		return _fail(path, "invalid_node_block", "Node block contains an unterminated property value.")
	if not _find_node(path).is_empty():
		return _fail(path, "duplicate_node", "A node already exists at this path.")
	var siblings: Array[Dictionary] = []
	for existing: Dictionary in nodes:
		if existing["attributes"].get("parent", "") == parent:
			siblings.append(existing)
	if index < -1 or index > siblings.size():
		return _fail(path, "invalid_index", "Sibling index is outside the parent's children.")
	var insert_at: int = int(parent_node["end_offset"])
	if index >= 0 and index < siblings.size():
		insert_at = int(siblings[index]["start_offset"])
	else:
		for existing: Dictionary in nodes:
			if parent == "." or _is_at_or_below(_node_path(existing), parent):
				insert_at = maxi(insert_at, int(existing["end_offset"]))
	var parent_pattern := RegEx.create_from_string('(?:^|[ \\t])parent[ \\t]*=[ \\t]*"(?:\\\\.|[^"\\\\])*"')
	var parent_match: RegExMatch = parent_pattern.search(header_line)
	var assignment: String = " parent=" + var_to_str(parent)
	if parent_match != null:
		header_line = header_line.substr(0, parent_match.get_start()) + assignment + header_line.substr(parent_match.get_end())
	else:
		header_line = header_line.trim_suffix("]") + assignment + "]"
	var body: String = block.substr(int(node["body_start_offset"])).replace("\r\n", "\n")
	body = body.replace("\n", _newline())
	var inserted: String = header_line + _newline() + body
	if not inserted.ends_with(_newline()):
		inserted += _newline()
	if not inserted.ends_with(_newline() + _newline()):
		inserted += _newline()
	if insert_at > 0 and _source_text.substr(insert_at - 1, 1) != "\n":
		inserted = _newline() + inserted
	_replace_range(insert_at, insert_at, inserted)
	return true


func remove_node(node_path: String) -> bool:
	last_error = {}
	if node_path == ".":
		return _fail(node_path, "remove_root", "A scene must retain its root node.")
	if _find_node(node_path).is_empty():
		return _fail(node_path, "node_not_found", "No node at this scene-relative path.")
	var removed: Array[Dictionary] = []
	for section: Dictionary in sections:
		var attributes: Dictionary = section["attributes"]
		var matches: bool = false
		match str(section["kind"]):
			"node":
				matches = _is_at_or_below(_node_path(section), node_path)
			"connection":
				matches = _is_at_or_below(str(attributes.get("from", "")), node_path) \
					or _is_at_or_below(str(attributes.get("to", "")), node_path)
			"editable":
				matches = _is_at_or_below(str(attributes.get("path", "")), node_path)
		if matches:
			removed.append(section)
	removed.reverse()
	for section: Dictionary in removed:
		_source_text = _source_text.substr(0, int(section["start_offset"])) + _source_text.substr(int(section["end_offset"]))
	_parse_sections()
	return true


func set_packed_bytes(node_path: String, key: String, bytes: PackedByteArray) -> bool:
	last_error = {}
	var node: Dictionary = _find_node(node_path)
	if node.is_empty():
		return _fail(node_path, "node_not_found", "No node at this scene-relative path.")
	var base64_style: bool = RegEx.create_from_string('PackedByteArray\\([ \\t\\r\\n]*"').search(_source_text) != null
	var properties: Array[Dictionary] = _properties(node)
	if not last_error.is_empty():
		return false
	for property: Dictionary in properties:
		if property["key"] == key:
			var existing: String = _source_text.substr(property["value_start"], property["value_end"] - property["value_start"])
			if not existing.begins_with("PackedByteArray("):
				return _fail(node_path + ":" + key, "not_packed_bytes", "Existing property is not a PackedByteArray.")
			base64_style = existing.trim_prefix("PackedByteArray(").strip_edges().begins_with('"')
	var encoded: String = 'PackedByteArray("%s")' % Marshalls.raw_to_base64(bytes) if base64_style else var_to_str(bytes)
	return set_property(node_path, key, encoded)


static func _is_at_or_below(path: String, parent: String) -> bool:
	return path == parent or path.begins_with(parent + "/")


func _node_path(node: Dictionary) -> String:
	var attributes: Dictionary = node["attributes"]
	if not attributes.has("parent"):
		return "."
	var parent: String = str(attributes["parent"])
	return str(attributes.get("name", "")) if parent == "." else parent + "/" + str(attributes.get("name", ""))


func _find_node(node_path: String) -> Dictionary:
	for node: Dictionary in nodes:
		if _node_path(node) == node_path:
			return node
	return {}


func _properties(node: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cursor: int = int(node["body_start_offset"])
	var limit: int = int(node["end_offset"])
	var pattern := RegEx.create_from_string("^[ \\t]*([A-Za-z_][A-Za-z0-9_/]*)[ \\t]*=[ \\t]*")
	while cursor < limit:
		var newline_at: int = _source_text.find("\n", cursor)
		var line_end: int = limit if newline_at < 0 else mini(newline_at, limit)
		var match_result: RegExMatch = pattern.search(_source_text.substr(cursor, line_end - cursor))
		if match_result != null:
			var start: int = cursor + match_result.get_end()
			var end: int = _value_end(_source_text, start, limit)
			if end < start:
				_fail(_node_path(node) + ":" + match_result.get_string(1), "invalid_value", "Malformed property value in source scene.")
				return []
			result.append({"key": match_result.get_string(1), "value_start": start, "value_end": end})
			newline_at = _source_text.find("\n", end)
		cursor = limit if newline_at < 0 else newline_at + 1
	return result


## Scan a complete value, including nested arrays/dictionaries and multiline strings.
static func _value_end(text: String, start: int, limit: int) -> int:
	var in_string: bool = false
	var escaped: bool = false
	var delimiters: Array[String] = []
	var cursor: int = start
	while cursor < limit:
		var character: String = text.substr(cursor, 1)
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == '"':
				in_string = false
		elif character == '"':
			in_string = true
		elif character == ";":
			if delimiters.is_empty():
				break
			var newline_at: int = text.find("\n", cursor)
			cursor = limit if newline_at < 0 else newline_at
			continue
		elif character in ["(", "[", "{"]:
			delimiters.append(character)
		elif character in [")", "]", "}"]:
			if delimiters.is_empty() or "([{".find(delimiters.back()) != ")]}".find(character):
				return -1
			delimiters.pop_back()
		elif character in ["\n", "\r"] and delimiters.is_empty():
			break
		cursor += 1
	if in_string or not delimiters.is_empty():
		return -1
	while cursor > start and text.substr(cursor - 1, 1) in [" ", "\t"]:
		cursor -= 1
	return cursor


func _newline() -> String:
	return "\r\n" if _source_text.contains("\r\n") else "\n"


func _replace_range(start: int, end: int, text: String) -> void:
	_source_text = _source_text.substr(0, start) + text + _source_text.substr(end)
	_parse_sections()


func _fail(field: String, code: String, message: String) -> bool:
	last_error = {"file": source_path, "field": field, "expected": "supported scene operation", "code": code, "message": message}
	return false


func _parse_sections() -> void:
	header = {}
	ext_resources.clear()
	sub_resources.clear()
	nodes.clear()
	connections.clear()
	editable_paths.clear()
	sections.clear()
	var current_section: Dictionary = {}
	var line_start: int = 0
	var first_section_start: int = -1
	var in_string: bool = false
	while line_start < _source_text.length():
		var newline_at: int = _source_text.find("\n", line_start)
		var line_end: int = newline_at + 1 if newline_at >= 0 else _source_text.length()
		var line: String = _without_line_ending(_source_text.substr(line_start, line_end - line_start))
		var kind: String = "" if in_string else _section_kind(line)
		if not kind.is_empty():
			if not current_section.is_empty():
				_finish_section(current_section, line_start)
			if first_section_start < 0:
				first_section_start = line_start
			current_section = _new_section(kind, line, line_start, line_end)
		in_string = _line_ends_in_string(line, in_string)
		line_start = line_end
	if not current_section.is_empty():
		_finish_section(current_section, _source_text.length())
	preamble = _source_text if first_section_start < 0 else _source_text.substr(0, first_section_start)


## Section-looking lines inside multiline strings belong to the current property.
static func _line_ends_in_string(line: String, in_string: bool) -> bool:
	var escaped: bool = false
	for character: String in line:
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == '"':
				in_string = false
		elif character == ";":
			break
		elif character == '"':
			in_string = true
	return in_string


func _finish_section(section: Dictionary, end_offset: int) -> void:
	section["end_offset"] = end_offset
	var start_offset: int = int(section["start_offset"])
	section["raw_text"] = _source_text.substr(start_offset, end_offset - start_offset)
	var body_start: int = int(section["body_start_offset"])
	var body_text: String = _source_text.substr(body_start, end_offset - body_start)
	var body_lines: Array[String] = []
	var property_lines: Array[String] = []
	for raw_line: String in body_text.split("\n", true):
		var line: String = raw_line.trim_suffix("\r")
		body_lines.append(line)
		if not line.is_empty():
			property_lines.append(line)
	section["body_lines"] = body_lines
	section["property_lines"] = property_lines
	sections.append(section)
	match String(section["kind"]):
		"gd_scene":
			header = section
		"ext_resource":
			ext_resources.append(section)
		"sub_resource":
			sub_resources.append(section)
		"node":
			nodes.append(section)
		"connection":
			connections.append(section)
		"editable":
			editable_paths.append(section)


static func _new_section(
		kind: String, header_line: String, start_offset: int, body_start_offset: int
) -> Dictionary:
	var attributes: Dictionary = _parse_attributes(header_line)
	var section: Dictionary = {
		"kind": kind,
		"header_line": header_line,
		"attributes": attributes,
		"start_offset": start_offset,
		"body_start_offset": body_start_offset,
	}
	for key: Variant in attributes:
		section[key] = attributes[key]
	return section


static func _section_kind(line: String) -> String:
	for kind: String in [
		"gd_scene", "ext_resource", "sub_resource", "node", "connection", "editable",
	]:
		var prefix: String = "[" + kind
		if line.begins_with(prefix):
			var boundary: String = line.substr(prefix.length(), 1)
			if boundary == " " or boundary == "]":
				return kind
	return ""


static func _parse_attributes(header_line: String) -> Dictionary:
	var attributes: Dictionary = {}
	var cursor: int = 1
	while cursor < header_line.length() and not _is_space(header_line.substr(cursor, 1)):
		cursor += 1
	while cursor < header_line.length():
		while cursor < header_line.length() and _is_space(header_line.substr(cursor, 1)):
			cursor += 1
		if cursor >= header_line.length() or header_line.substr(cursor, 1) == "]":
			break
		var key_start: int = cursor
		while cursor < header_line.length():
			var key_character: String = header_line.substr(cursor, 1)
			if key_character == "=" or _is_space(key_character) or key_character == "]":
				break
			cursor += 1
		var key: String = header_line.substr(key_start, cursor - key_start)
		while cursor < header_line.length() and _is_space(header_line.substr(cursor, 1)):
			cursor += 1
		if key.is_empty() or cursor >= header_line.length() or header_line.substr(cursor, 1) != "=":
			while cursor < header_line.length() and not _is_space(header_line.substr(cursor, 1)):
				cursor += 1
			continue
		cursor += 1
		while cursor < header_line.length() and _is_space(header_line.substr(cursor, 1)):
			cursor += 1
		var value_start: int = cursor
		var nesting_depth: int = 0
		var in_quotes: bool = false
		var escaped: bool = false
		while cursor < header_line.length():
			var character: String = header_line.substr(cursor, 1)
			if in_quotes:
				if escaped:
					escaped = false
				elif character == "\\":
					escaped = true
				elif character == "\"":
					in_quotes = false
			elif character == "\"":
				in_quotes = true
			elif character in ["(", "[", "{"]:
				nesting_depth += 1
			elif character in [")", "]", "}"]:
				if character == "]" and nesting_depth == 0:
					break
				nesting_depth -= 1
			elif _is_space(character) and nesting_depth == 0:
				break
			cursor += 1
		var raw_value: String = header_line.substr(value_start, cursor - value_start)
		attributes[key] = _decode_quoted_string(raw_value)
	return attributes


static func _decode_quoted_string(raw_value: String) -> Variant:
	if raw_value.length() >= 2 and raw_value.begins_with("\"") and raw_value.ends_with("\""):
		var decoded: Variant = JSON.parse_string(raw_value)
		if decoded is String:
			return decoded
	return raw_value


static func _is_space(character: String) -> bool:
	return character == " " or character == "\t"


static func _without_line_ending(line: String) -> String:
	return line.trim_suffix("\n").trim_suffix("\r")


## Adds a declaration without loading the resource or rewriting existing IDs.
func add_ext_resource(path: String, type: String, uid: String = "") -> String:
	last_error.clear()
	if header.is_empty():
		_fail(path, "missing_header", "A gd_scene header is required before adding a resource.")
		return ""
	if not path.begins_with("res://") or path.length() <= 6 or "::" in path:
		_fail(path, "invalid_resource_path", "External resources require a res:// file path.")
		return ""
	if not type.is_valid_identifier():
		_fail(path, "invalid_resource_type", "A resource type name is required.")
		return ""
	var used_ids: Dictionary = {}
	for resource: Dictionary in ext_resources:
		var attributes: Dictionary = resource["attributes"]
		var existing_id: String = String(attributes.get("id", ""))
		used_ids[existing_id] = true
		if String(attributes.get("path", "")) == path:
			if String(attributes.get("type", "")) != type or existing_id.is_empty():
				_fail(path, "resource_conflict", "Existing resource has a different type or no ID.")
				return ""
			return existing_id
	if not uid.is_empty() and ResourceUID.text_to_id(uid) == ResourceUID.INVALID_ID:
		_fail(path, "invalid_resource_uid", "Resource UID is not a valid uid:// identifier.")
		return ""
	var load_steps_span: Vector2i = Vector2i(-1, -1)
	var load_steps: int = 0
	if header["attributes"].has("load_steps"):
		load_steps_span = _load_steps_value_span()
		if load_steps_span.x < 0:
			_fail("load_steps", "invalid_load_steps", "Existing load_steps must be a nonnegative integer.")
			return ""
		load_steps = int(header["attributes"]["load_steps"])
	var sequence: int = 1
	while used_ids.has("%d_weftlumin" % sequence):
		sequence += 1
	var resource_id: String = "%d_weftlumin" % sequence
	var declaration: String = "[ext_resource type=" + var_to_str(type)
	if not uid.is_empty():
		declaration += " uid=" + var_to_str(uid)
	declaration += " path=" + var_to_str(path) + " id=" + var_to_str(resource_id) + "]"
	var insertion: int = _source_text.length()
	for section: Dictionary in sections:
		if String(section["kind"]) not in ["gd_scene", "ext_resource"]:
			insertion = int(section["start_offset"])
			break
	var newline: String = _newline()
	var prefix: String = ""
	if insertion > 0 and _source_text.substr(insertion - 1, 1) != "\n":
		prefix = newline
	_replace_range(insertion, insertion, prefix + declaration + newline + newline)
	if load_steps_span.x >= 0:
		_replace_range(load_steps_span.x, load_steps_span.y, str(load_steps + 1))
	return resource_id


## Returns scene syntax, refusing object serialisation before any document edit.
func encode_value(value: Variant, node_path: String = "", key: String = "") -> String:
	last_error.clear()
	var field: String = node_path + ":" + key
	if value is Resource:
		var resource: Resource = value
		var path: String = resource.resource_path
		if "::" in path:
			var scene_path: String = path.get_slice("::", 0)
			var resource_id: String = path.get_slice("::", 1)
			if not source_path.is_empty() and scene_path == source_path and path.count("::") == 1:
				for section: Dictionary in sub_resources:
					var attributes: Dictionary = section["attributes"]
					if String(attributes.get("id", "")) == resource_id \
							and String(attributes.get("type", "")) == resource.get_class():
						return "SubResource(" + var_to_str(resource_id) + ")"
			_fail(field, "unsupported_resource", "Subresource is not declared in this source scene.")
			return ""
		if not path.begins_with("res://"):
			_fail(field, "unsupported_resource", "Resource has no external res:// file path.")
			return ""
		# Scene declarations may use a base type (Script for a GDScript resource).
		for section: Dictionary in ext_resources:
			var attributes: Dictionary = section["attributes"]
			if String(attributes.get("path", "")) == path:
				var existing_id: String = String(attributes.get("id", ""))
				if not existing_id.is_empty() and resource.is_class(String(attributes.get("type", ""))):
					return "ExtResource(" + var_to_str(existing_id) + ")"
				_fail(field, "resource_conflict", "Existing declaration does not match the resource type.")
				return ""
		var uid: String = ""
		var resource_uid: int = ResourceLoader.get_resource_uid(path)
		if resource_uid != ResourceUID.INVALID_ID:
			uid = ResourceUID.id_to_text(resource_uid)
		var resource_type: String = "Script" if resource is Script else resource.get_class()
		var resource_id: String = add_ext_resource(path, resource_type, uid)
		if resource_id.is_empty():
			last_error["field"] = field
			return ""
		return "ExtResource(" + var_to_str(resource_id) + ")"
	if not _can_encode_plain_value(value):
		_fail(field, "unsupported_value", "Unsupported value type or container containing objects.")
		return ""
	return var_to_str(value)


static func _can_encode_plain_value(value: Variant, depth: int = 0) -> bool:
	# Bound recursion so cyclic or excessively deep containers are refused safely.
	if depth > 64:
		return false
	if value is Array:
		var array: Array = value
		if array.is_typed() and array.get_typed_builtin() == TYPE_OBJECT:
			return false
		for element: Variant in array:
			if not _can_encode_plain_value(element, depth + 1):
				return false
		return true
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.get_typed_key_builtin() == TYPE_OBJECT \
				or dictionary.get_typed_value_builtin() == TYPE_OBJECT:
			return false
		for entry: Variant in dictionary:
			if not _can_encode_plain_value(entry, depth + 1) \
					or not _can_encode_plain_value(dictionary[entry], depth + 1):
				return false
		return true
	return typeof(value) in [
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH,
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I, TYPE_VECTOR3, TYPE_VECTOR3I,
		TYPE_TRANSFORM2D, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_PLANE, TYPE_QUATERNION, TYPE_AABB,
		TYPE_BASIS, TYPE_TRANSFORM3D, TYPE_PROJECTION, TYPE_COLOR, TYPE_PACKED_BYTE_ARRAY,
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY,
		TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY,
	]


func _load_steps_value_span() -> Vector2i:
	var expression: RegEx = RegEx.new()
	# Skip quoted attributes so a string containing "load_steps=..." cannot match.
	expression.compile('"(?:\\\\.|[^"\\\\])*"|(?<=[ \\t])load_steps[ \\t]*=[ \\t]*([0-9]+)(?=[ \\t\\]])')
	for result: RegExMatch in expression.search_all(String(header["header_line"])):
		if result.get_start(1) >= 0:
			var start: int = int(header["start_offset"]) + result.get_start(1)
			var end: int = int(header["start_offset"]) + result.get_end(1)
			return Vector2i(start, end)
	return Vector2i(-1, -1)
