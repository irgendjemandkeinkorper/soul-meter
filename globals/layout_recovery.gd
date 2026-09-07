extends RefCounted
## Atomic checkpoints of unsaved layout scratch; never a replacement for manual Save.

const Overrides := preload("res://globals/layout_overrides.gd")
const RECOVERY_DIRECTORY := "user://layout_overrides/recovery"
const BASE_FIELD := "_recovery_base"


static func recovery_path_for_scene(scene_path: String) -> String:
	return RECOVERY_DIRECTORY.path_join(scene_path.sha256_text() + ".json")


static func load_scene(scene_path: String) -> Dictionary:
	var saved: Dictionary = Overrides.load_file(Overrides.override_path_for_scene(scene_path))
	if saved.is_empty() or str(saved.get("scene", "")) != scene_path:
		saved = Overrides.create_document(scene_path)
	saved = _normalize(saved)
	var result := {"saved": saved.duplicate(true), "working": saved.duplicate(true), "recovered": false}
	var recovery: Dictionary = Overrides.load_file(recovery_path_for_scene(scene_path))
	if recovery.is_empty() or str(recovery.get("scene", "")) != scene_path:
		return result
	# A manual save made since the checkpoint takes precedence over stale recovery.
	var base_fingerprint: String = _fingerprint(saved)
	if str(recovery.get(BASE_FIELD, "")) != base_fingerprint:
		return result
	var working: Dictionary = _normalize(recovery)
	if working.is_empty() or _fingerprint(working) == base_fingerprint:
		return result
	result["working"] = working
	result["recovered"] = true
	return result


static func checkpoint(scene_path: String, working: Dictionary, saved: Dictionary) -> Error:
	var normalized_working: Dictionary = _normalize(working)
	var normalized_saved: Dictionary = _normalize(saved)
	if normalized_working.is_empty() or normalized_saved.is_empty() \
			or str(normalized_working.get("scene", "")) != scene_path \
			or str(normalized_saved.get("scene", "")) != scene_path:
		return ERR_INVALID_DATA
	var base_fingerprint: String = _fingerprint(normalized_saved)
	if _fingerprint(normalized_working) == base_fingerprint:
		# Undoing to the saved state must not resurrect an older dirty checkpoint.
		return clear(scene_path)
	normalized_working[BASE_FIELD] = base_fingerprint
	return Overrides.save_file(recovery_path_for_scene(scene_path), normalized_working)


static func clear(scene_path: String) -> Error:
	var path: String = recovery_path_for_scene(scene_path)
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _normalize(document: Dictionary) -> Dictionary:
	var clean: Dictionary = document.duplicate(true)
	clean.erase(BASE_FIELD)
	var content: String = Overrides.to_json(clean)
	if content.is_empty():
		return {}
	# Match the on-disk number representation (JSON parses integer fields as floats).
	return Overrides.from_json(content)


static func _fingerprint(normalized: Dictionary) -> String:
	return JSON.stringify(normalized, "", true, true).sha256_text()
