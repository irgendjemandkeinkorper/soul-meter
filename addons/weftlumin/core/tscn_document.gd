class_name TscnDocument
extends RefCounted

## Lossless, text-level view of a Godot text scene.
##
## This parser deliberately keeps values and complete section text opaque. Later
## surgical edits can replace only the affected spans without asking Godot to
## load or re-encode the scene.

var header: Dictionary = {}
var ext_resources: Array[Dictionary] = []
var sub_resources: Array[Dictionary] = []
var nodes: Array[Dictionary] = []
var connections: Array[Dictionary] = []
var editable_paths: Array[Dictionary] = []
var sections: Array[Dictionary] = []
var preamble: String = ""

var _source_text: String = ""


static func parse(text: String) -> TscnDocument:
	var document: TscnDocument = TscnDocument.new()
	document._source_text = text
	document._parse_sections()
	return document


func serialise() -> String:
	return _source_text


func _parse_sections() -> void:
	var current_section: Dictionary = {}
	var line_start: int = 0
	var first_section_start: int = -1
	while line_start < _source_text.length():
		var newline_at: int = _source_text.find("\n", line_start)
		var line_end: int = newline_at + 1 if newline_at >= 0 else _source_text.length()
		var line: String = _without_line_ending(_source_text.substr(line_start, line_end - line_start))
		var kind: String = _section_kind(line)
		if not kind.is_empty():
			if not current_section.is_empty():
				_finish_section(current_section, line_start)
			if first_section_start < 0:
				first_section_start = line_start
			current_section = _new_section(kind, line, line_start, line_end)
		line_start = line_end
	if not current_section.is_empty():
		_finish_section(current_section, _source_text.length())
	preamble = _source_text if first_section_start < 0 else _source_text.substr(0, first_section_start)


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
