class_name NpcRoster
extends RefCounted
## Runtime seam for Pandora-generated NPC data.
##
## Portrait art remains data: a safe source-image path is loaded when present;
## otherwise the dialogue portrait renders the generated monogram descriptor.

const DATA_PATH := "res://data/generated/dom_npc_roster.json"
const SAFE_PORTRAIT_EXTENSIONS := ["png", "jpg", "jpeg", "svg", "webp", "tga"]
const UNIT_PORTRAIT_TEMPLATE := "res://assets/generated/sprites/units/%s/%s--idle--se--f00.png"

static var _loaded := false
static var _npcs: Dictionary = {}
static var _ids_by_display_name: Dictionary = {}


static func all() -> Array[Dictionary]:
	_ensure_loaded()
	var ids: Array = _npcs.keys()
	ids.sort()
	var rows: Array[Dictionary] = []
	for npc_id: String in ids:
		rows.append((_npcs[npc_id] as Dictionary).duplicate(true))
	return rows


static func get_npc(npc_id: String) -> Dictionary:
	_ensure_loaded()
	if not StableIds.is_valid(StableIds.ACTOR, npc_id):
		return {}
	var row: Variant = _npcs.get(npc_id)
	if not row is Dictionary:
		return {}
	if not StableIds.is_valid_record(StableIds.ACTOR, row.get("stable_id", {})):
		return {}
	return row.duplicate(true)


static func by_display_name(display_name: String) -> Dictionary:
	_ensure_loaded()
	var npc_id := str(_ids_by_display_name.get(display_name, ""))
	return get_npc(npc_id) if not npc_id.is_empty() else {}


static func portrait_descriptor(npc_id: String) -> Dictionary:
	var row := get_npc(npc_id)
	var portrait: Variant = row.get("portrait", {})
	return portrait.duplicate(true) if portrait is Dictionary else {}


static func is_safe_portrait_path(path: String) -> bool:
	return (
		path.begins_with("res://")
		and not ".." in path
		and path.get_extension().to_lower() in SAFE_PORTRAIT_EXTENSIONS
	)


static func load_portrait_texture(path: String) -> Texture2D:
	if path.is_empty() or not is_safe_portrait_path(path) or not FileAccess.file_exists(path):
		return null
	var resource: Resource = load(path)
	return resource as Texture2D


static func unit_portrait_path(portrait_id: String) -> String:
	if portrait_id.is_empty() or portrait_id.contains("..") or portrait_id.contains("/"):
		return ""
	return UNIT_PORTRAIT_TEMPLATE % [portrait_id, portrait_id]


static func reload() -> void:
	_loaded = false
	_npcs.clear()
	_ids_by_display_name.clear()
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(DATA_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		return
	var rows: Variant = parsed.get("npcs", {})
	if not rows is Dictionary:
		return
	_npcs = rows.duplicate(true)
	for npc_id: String in _npcs:
		var row: Variant = _npcs[npc_id]
		if row is Dictionary:
			_ids_by_display_name[str(row.get("display_name", ""))] = npc_id
