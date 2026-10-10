extends RefCounted
## Test-only checks that a retired debug tool cannot reach a release build (E2.5b, #337).
##
## The five legacy debug autoloads were removed; their models now live only under
## `weftlumin/panels/models/`, which every export preset excludes. These checks replace the
## old per-autoload inert assertions with the release-build guarantee they protected: no
## autoload entry, no root singleton, no model left in a shipped directory, and the model
## path matched by every preset's `exclude_filter`.

const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const MODELS_DIR := "res://weftlumin/panels/models/"


## Autoload name is neither registered in project settings nor present under /root.
static func autoload_absent(tree: SceneTree, autoload_name: String) -> bool:
	if ProjectSettings.has_setting("autoload/%s" % autoload_name):
		return false
	return tree.root.get_node_or_null(autoload_name) == null


## Every preset in export_presets.cfg excludes `res_path`, and at least one preset exists.
static func excluded_from_every_preset(res_path: String) -> bool:
	return _excluded_by(res_path, _preset_filters())


static func _preset_filters() -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var config := ConfigFile.new()
	if config.load(EXPORT_PRESETS_PATH) != OK:
		return result
	for section: String in config.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var filters := PackedStringArray()
		for pattern: String in str(config.get_value(section, "exclude_filter", "")).split(",", false):
			filters.append(pattern.strip_edges())
		result.append(filters)
	return result


## The model exists only at its export-excluded home, not at its former shipped path.
static func model_only_in_excluded_home(model_file: String, former_path: String) -> bool:
	var home: String = MODELS_DIR + model_file
	return (
		FileAccess.file_exists(home)
		and not FileAccess.file_exists(former_path)
		and excluded_from_every_preset(home)
	)


## A shipped (non-excluded) script under res://globals, res://ui or res://addons/weftlumin
## mentions `needle`. Returns the first offending path, or "" when clean.
static func shipped_reference(needle: String) -> String:
	var presets: Array[PackedStringArray] = _preset_filters()
	for root: String in ["res://globals", "res://ui", "res://addons/weftlumin"]:
		var hit: String = _scan(root, needle, presets)
		if not hit.is_empty():
			return hit
	return ""


static func _scan(directory: String, needle: String, presets: Array[PackedStringArray]) -> String:
	for file_name: String in DirAccess.get_files_at(directory):
		var path: String = directory.path_join(file_name)
		if not (file_name.ends_with(".gd") or file_name.ends_with(".tscn")):
			continue
		if _excluded_by(path, presets):
			continue
		if FileAccess.get_file_as_string(path).contains(needle):
			return path
	for child: String in DirAccess.get_directories_at(directory):
		var hit: String = _scan(directory.path_join(child), needle, presets)
		if not hit.is_empty():
			return hit
	return ""


static func _excluded_by(res_path: String, presets: Array[PackedStringArray]) -> bool:
	if presets.is_empty():
		return false
	var relative: String = res_path.trim_prefix("res://")
	for filters: PackedStringArray in presets:
		var matched: bool = false
		for pattern: String in filters:
			if relative.match(pattern):
				matched = true
				break
		if not matched:
			return false
	return true
