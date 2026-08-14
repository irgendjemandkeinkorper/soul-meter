class_name FastTravelRegistry
extends RefCounted
## Read-only runtime index for FR-503 fast-travel hubs.
##
## Design choice: Pandora remains canonical and nothing writes back. The current
## Pandora data has no ratified hub/travel-cost entity contract, so this registry
## deliberately duplicates the small amount of already-ratified LocationRegistry
## metadata needed by the UI. Migrate this table to generated Pandora output once
## hub entities and their vault-backed lore entries are ratified; do not hand-edit
## data.pandora to satisfy this screen.

const _HUBS: Array[Dictionary] = [
	{
		"id": &"dom",
		"scene_path": "res://world/starting_town.tscn",
		"display_name": "Dom",
		# Provisional economy tuning, not lore. Centralized for a later balance pass.
		"base_cost_gp": 25,
	},
]


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hub: Dictionary in _HUBS:
		result.append(hub.duplicate(true))
	return result


static func by_id(hub_id: StringName) -> Dictionary:
	for hub: Dictionary in _HUBS:
		if hub["id"] == hub_id:
			return hub.duplicate(true)
	return {}


static func by_scene(scene_path: String) -> Dictionary:
	for hub: Dictionary in _HUBS:
		if hub["scene_path"] == scene_path:
			return hub.duplicate(true)
	return {}


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}
	var seen_scenes: Dictionary = {}
	for hub: Dictionary in _HUBS:
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
