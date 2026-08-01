class_name LocationRegistry
extends RefCounted
## Central registry for gameplay location identity and safe travel targets.

const DOM: LocationDefinition = preload("res://world/locations/dom.tres")
const WILDS: LocationDefinition = preload("res://world/locations/wilds.tres")
const DORTHKOR: LocationDefinition = preload("res://world/locations/dorthkor_road.tres")
const WOUND_LIP: LocationDefinition = preload("res://world/locations/wound_lip.tres")
const ALL: Array[LocationDefinition] = [DOM, WILDS, DORTHKOR, WOUND_LIP]
const GAMEPLAY_SCENES: Array[String] = [
	"res://world/starting_town.tscn",
	"res://world/test_room.tscn",
	"res://world/dorthkor_road.tscn",
	"res://world/wound_lip.tscn",
]

static func by_id(location_id: StringName) -> LocationDefinition:
	for location in ALL:
		if location.id == location_id:
			return location
	return null


static func by_scene(scene_path: String) -> LocationDefinition:
	for location in ALL:
		if location.scene_path == scene_path:
			return location
	return null


static func resolve(scene_path: String, location_id: StringName = &"") -> LocationDefinition:
	if not location_id.is_empty():
		var by_name := by_id(location_id)
		if by_name != null and by_name.scene_path == scene_path:
			return by_name
	return by_scene(scene_path)


static func is_gameplay_scene(scene_path: String) -> bool:
	var location := by_scene(scene_path)
	return location != null and location.allowed_gameplay
