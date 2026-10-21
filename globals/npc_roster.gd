class_name NpcRoster
extends RefCounted
## Runtime seam for Pandora-generated NPC data.
##
## Every town owns one generated roster and one placements file
## (`tools/generate_gloot.gd`, C1 / #238): `<town>_npc_roster.json` and
## `<town>_npc_placements.json`. This reader merges them, so an NPC id is looked
## up the same way whichever town it belongs to. A town is a fast-travel hub
## (`FastTravelRegistry`, the hand-wired list) or any other baked location whose
## id names a `canon/<town>/` directory the seeder wrote a roster for (C3 / #240:
## The Long Verge is wilds with a Company camp, not a hub). A town without
## generated files simply contributes nothing.
##
## Portrait art remains data: a safe source-image path is loaded when present;
## otherwise the dialogue portrait renders the generated monogram descriptor.

const ROSTER_PATH_TEMPLATE := "res://data/generated/%s_npc_roster.json"
const PLACEMENTS_PATH_TEMPLATE := "res://data/generated/%s_npc_placements.json"
## C25 (#262): the hand-authored ambient dialogue for a roster town, one file per town under the
## generated title scheme. Optional; a town without one keeps its generated placeholder.
const LOCATION_DIALOGUE_PATH_TEMPLATE := "res://dialogue/locations/%s.dialogue"
const SAFE_PORTRAIT_EXTENSIONS := ["png", "jpg", "jpeg", "svg", "webp", "tga"]
const UNIT_PORTRAIT_TEMPLATE := "res://assets/generated/sprites/units/%s/%s--idle--se--f00.png"

static var _loaded := false
static var _npcs: Dictionary = {}
static var _placements: Dictionary = {}
static var _ids_by_display_name: Dictionary = {}


## The towns whose generated NPC artifacts this reader merges: the fast-travel hubs in
## registry order, then every other baked location with a roster file, in index order.
static func town_ids() -> Array[String]:
	var result: Array[String] = []
	for hub: Dictionary in FastTravelRegistry.all():
		result.append(String(hub["id"]))
	for location: LocationDefinition in LocationRegistry.ALL:
		var town_id := String(location.id)
		if not result.has(town_id) and FileAccess.file_exists(roster_path(town_id)):
			result.append(town_id)
	return result


static func roster_path(town_id: String) -> String:
	return ROSTER_PATH_TEMPLATE % town_id


static func placements_path(town_id: String) -> String:
	return PLACEMENTS_PATH_TEMPLATE % town_id


static func location_dialogue_path(town_id: String) -> String:
	return LOCATION_DIALOGUE_PATH_TEMPLATE % town_id


## The file a roster NPC talks from: the town's authored location dialogue when it carries the
## NPC's generated title, else `generated_path` (the `<town>_townsfolk.dialogue` that
## tools/generate_gloot.gd owns and nothing hand-edits). Read through the imported resource,
## never the source text, so an exported build routes the same way the editor does.
static func dialogue_route(town_id: String, generated_path: String, title: String) -> String:
	if title.is_empty():
		return generated_path
	var authored_path := location_dialogue_path(town_id)
	if not ResourceLoader.exists(authored_path):
		return generated_path
	var authored := load(authored_path) as DialogueResource
	if authored == null or not authored.get_cues().has(title):
		return generated_path
	return authored_path


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


## Every hub's generated placement rows, npc id -> placement, merged.
static func placements() -> Dictionary:
	_ensure_loaded()
	return _placements.duplicate(true)


## The placement rows whose `scene` is `scene_path`, npc id -> placement.
static func placements_for_scene(scene_path: String) -> Dictionary:
	_ensure_loaded()
	var result: Dictionary = {}
	for npc_id: String in _placements:
		var placement: Variant = _placements[npc_id]
		if placement is Dictionary and str((placement as Dictionary).get("scene", "")) == scene_path:
			result[npc_id] = (placement as Dictionary).duplicate(true)
	return result


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
	# ResourceLoader.exists follows export remapping (FileAccess alone misses
	# imported textures inside a PCK); FileAccess keeps unimported files
	# resolvable in the editor. Same gate as ChargenArtResolver._art_exists.
	if path.is_empty() or not is_safe_portrait_path(path):
		return null
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
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
	_placements.clear()
	_ids_by_display_name.clear()
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for town_id: String in town_ids():
		var rows: Variant = _read_rows(roster_path(town_id), "npcs")
		for npc_id: String in rows:
			var row: Variant = rows[npc_id]
			if not row is Dictionary:
				continue
			_npcs[npc_id] = (row as Dictionary).duplicate(true)
			_ids_by_display_name[str((row as Dictionary).get("display_name", ""))] = npc_id
		var placed: Dictionary = _read_rows(placements_path(town_id), "placements")
		for npc_id: String in placed:
			if placed[npc_id] is Dictionary:
				_placements[npc_id] = (placed[npc_id] as Dictionary).duplicate(true)


## The `key` dictionary of a generated JSON artifact, or `{}` when the file is absent or malformed.
static func _read_rows(path: String, key: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var rows: Variant = (parsed as Dictionary).get(key, {})
	return rows if rows is Dictionary else {}
