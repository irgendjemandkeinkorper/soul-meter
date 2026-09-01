class_name CampaignPackageFiles
extends RefCounted
## Shared bounded, portable package discovery for campaign-owned source trees.

const MAX_DEPTH: int = 8
const MAX_FILES: int = 512


static func relative_path_is_safe(relative_path: String) -> bool:
	if (
		relative_path.begins_with("/")
		or relative_path.contains("\\")
		or relative_path.contains(":")
	):
		return false
	var segments: PackedStringArray = relative_path.split("/", true)
	if segments.is_empty():
		return false
	for segment: String in segments:
		if segment.is_empty() or segment == "." or segment == "..":
			return false
		if segment.ends_with(".") or segment.ends_with(" "):
			return false
		var stem: String = segment.get_slice(".", 0)
		if _is_windows_reserved_file_stem(stem):
			return false
	return true


static func ascii_case_fold(value: String) -> String:
	var folded: String = ""
	for index: int in value.length():
		var codepoint: int = value.unicode_at(index)
		if codepoint >= 65 and codepoint <= 90:
			folded += String.chr(codepoint + 32)
		else:
			folded += value.substr(index, 1)
	return folded


static func package_files(
	root_path: String,
	directory_path: String,
	extension: String,
	field: String,
	code_prefix: String,
	label: String,
	errors: Array[Dictionary],
	depth: int,
	discovery_state: Dictionary,
	validate_relative_paths: bool
) -> Array[String]:
	var result: Array[String] = []
	if bool(discovery_state.get("stopped", false)):
		return result
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return result
	var file_names: PackedStringArray = directory.get_files()
	file_names.sort()
	for file_name: String in file_names:
		if directory.is_link(file_name):
			continue
		var file_path: String = directory_path.path_join(file_name)
		var file_count: int = int(discovery_state.get("file_count", 0)) + 1
		discovery_state["file_count"] = file_count
		if file_count > MAX_FILES:
			add_error(
				errors,
				file_path,
				field,
				"at most %d regular files" % MAX_FILES,
				"%s_discovery_file_limit_exceeded" % code_prefix,
				"%s discovery exceeded the %d-file package limit at '%s'."
				% [label, MAX_FILES, file_path]
			)
			discovery_state["stopped"] = true
			return result
		if file_name.get_extension().to_lower() != extension:
			continue
		var relative_path: String = file_path.trim_prefix(root_path.trim_suffix("/") + "/")
		if validate_relative_paths and not relative_path_is_safe(relative_path):
			add_error(
				errors,
				file_path,
				field,
				"portable relative package path",
				"unsafe_%s_file_path" % code_prefix,
				"%s file '%s' is not a safe portable path inside the campaign package."
				% [label, relative_path]
			)
			continue
		result.append(file_path)
	var directory_names: PackedStringArray = directory.get_directories()
	directory_names.sort()
	for directory_name: String in directory_names:
		if directory.is_link(directory_name):
			continue
		var child_path: String = directory_path.path_join(directory_name)
		var child_depth: int = depth + 1
		if child_depth > MAX_DEPTH:
			add_error(
				errors,
				child_path,
				field,
				"package tree no deeper than %d directories" % MAX_DEPTH,
				"%s_discovery_depth_exceeded" % code_prefix,
				"%s discovery exceeded the depth limit at '%s'." % [label, child_path]
			)
			discovery_state["stopped"] = true
			return result
		result.append_array(
			package_files(
				root_path,
				child_path,
				extension,
				field,
				code_prefix,
				label,
				errors,
				child_depth,
				discovery_state,
				validate_relative_paths
			)
		)
		if bool(discovery_state.get("stopped", false)):
			return result
	return result


static func add_error(
	errors: Array[Dictionary],
	file_path: String,
	field: String,
	expected: String,
	code: String,
	message: String,
	line_number: int = -1
) -> void:
	var error: Dictionary = {
		"file": file_path,
		"field": field,
		"expected": expected,
		"code": code,
		"message": message,
	}
	if line_number > 0:
		error["line"] = line_number
	errors.append(error)


static func _is_windows_reserved_file_stem(stem: String) -> bool:
	var upper_stem: String = stem.to_upper()
	if upper_stem in ["CON", "PRN", "AUX", "NUL"]:
		return true
	if upper_stem.length() != 4:
		return false
	var prefix: String = upper_stem.left(3)
	var device_number: int = upper_stem.unicode_at(3)
	return (prefix == "COM" or prefix == "LPT") and device_number >= 49 and device_number <= 57
