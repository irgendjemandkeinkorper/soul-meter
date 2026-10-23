class_name FastTravelRegistry
extends RefCounted
## Read-only runtime index for FR-503 fast-travel hubs.
##
## Canon location documents own hub membership and provisional costs. The bake
## writes their fast_travel facets to the location index; nothing writes back.

static var _hubs: Array[Dictionary] = []
static var _loaded: bool = _load_index()


static func all() -> Array[Dictionary]:
	return _hubs.duplicate(true)


static func by_id(hub_id: StringName) -> Dictionary:
	for hub: Dictionary in _hubs:
		if hub["id"] == hub_id:
			return hub.duplicate(true)
	return {}


static func by_scene(scene_path: String) -> Dictionary:
	for hub: Dictionary in _hubs:
		if hub["scene_path"] == scene_path:
			return hub.duplicate(true)
	return {}


static func _load_index() -> bool:
	var index: JSON = load(LocationRegistry.INDEX_PATH) as JSON
	if index == null or not index.data is Dictionary:
		push_error("FastTravelRegistry: missing or invalid location index.")
		return false
	var data: Dictionary = index.data
	if data.get("schema") != LocationRegistry.INDEX_SCHEMA:
		push_error("FastTravelRegistry: unsupported location index schema.")
		return false
	for row: Dictionary in data.get("locations", []):
		var facet: Variant = row.get("fast_travel")
		if not facet is Dictionary:
			continue
		_hubs.append({
			"id": StringName(row["id"]),
			"scene_path": String(row["scene_path"]),
			"display_name": String(row["display_name"]),
			"base_cost_gp": int(facet["base_cost_gp"]),
		})
	# Public order is dom first, then the remaining hubs by id. NpcRoster.town_ids()
	# forwards this order; unique NPC ids and display names across the town rosters
	# keep its merge unchanged (handoff §2.2).
	_hubs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["id"] == &"dom" or b["id"] == &"dom":
			return a["id"] == &"dom" and b["id"] != &"dom"
		return String(a["id"]) < String(b["id"]))
	return true


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}
	var seen_scenes: Dictionary = {}
	for hub: Dictionary in _hubs:
		var hub_id := StringName(hub.get("id", &""))
		var scene_path := str(hub.get("scene_path", ""))
		if hub_id.is_empty() or seen_ids.has(hub_id):
			errors.append("Fast-travel hub IDs must be non-empty and unique: %s" % hub_id)
		if scene_path.is_empty() or seen_scenes.has(scene_path):
			errors.append("Fast-travel hub scenes must be non-empty and unique: %s" % scene_path)
		if str(hub.get("display_name", "")).strip_edges().is_empty():
			errors.append("Fast-travel hub %s has no display name." % hub_id)
		if int(hub.get("base_cost_gp", -1)) < 0:
			errors.append("Fast-travel hub %s has a negative GP cost." % hub_id)
		var location := LocationRegistry.by_id(hub_id)
		if location == null or location.scene_path != scene_path or not location.allowed_gameplay:
			errors.append("Fast-travel hub %s does not match LocationRegistry." % hub_id)
		seen_ids[hub_id] = true
		seen_scenes[scene_path] = true
	return errors
