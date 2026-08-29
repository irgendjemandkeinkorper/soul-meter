class_name LocationRegistry
extends RefCounted
## Central registry for gameplay location identity and safe travel targets.

const DOM: LocationDefinition = preload("res://world/locations/dom.tres")
const WILDS: LocationDefinition = preload("res://world/locations/wilds.tres")
const DORTHKOR: LocationDefinition = preload("res://world/locations/dorthkor_road.tres")
const WOUND_LIP: LocationDefinition = preload("res://world/locations/wound_lip.tres")
const REGISTRY_ARCHIVE: LocationDefinition = preload(
	"res://world/locations/interiors/registry_archive.tres"
)
const BELL_HOUSE: LocationDefinition = preload("res://world/locations/interiors/bell_house.tres")
const RIVER_SHRINE: LocationDefinition = preload(
	"res://world/locations/interiors/river_shrine.tres"
)
const IRON_COMPANIES: LocationDefinition = preload(
	"res://world/locations/interiors/iron_companies.tres"
)
const ITEM_SHOP: LocationDefinition = preload("res://world/locations/interiors/item_shop.tres")
const EQUIPMENT_SHOP: LocationDefinition = preload(
	"res://world/locations/interiors/equipment_shop.tres"
)
const TOWN_HALL: LocationDefinition = preload("res://world/locations/interiors/town_hall.tres")
const CHEFS_HOUSE: LocationDefinition = preload(
	"res://world/locations/interiors/chefs_house.tres"
)
const PLAYERS_HOUSE: LocationDefinition = preload(
	"res://world/locations/interiors/players_house.tres"
)
const TRIAL_HALL: LocationDefinition = preload("res://world/locations/interiors/trial_hall.tres")
const REGISTRY_STACKS: LocationDefinition = preload(
	"res://world/locations/interiors/registry_stacks.tres"
)
const BELL_LOFT: LocationDefinition = preload("res://world/locations/interiors/bell_loft.tres")
const SHRINE_UNDERCROFT: LocationDefinition = preload(
	"res://world/locations/interiors/shrine_undercroft.tres"
)
const GARRISON_YARD: LocationDefinition = preload(
	"res://world/locations/interiors/garrison_yard.tres"
)
const CASK_WAREHOUSE: LocationDefinition = preload(
	"res://world/locations/interiors/cask_warehouse.tres"
)
const EQUIPMENT_FORGE: LocationDefinition = preload(
	"res://world/locations/interiors/equipment_forge.tres"
)
const COUNCIL_CHAMBER: LocationDefinition = preload(
	"res://world/locations/interiors/council_chamber.tres"
)
const CHEFS_PANTRY: LocationDefinition = preload(
	"res://world/locations/interiors/chefs_pantry.tres"
)
const PLAYERS_LOFT: LocationDefinition = preload(
	"res://world/locations/interiors/players_loft.tres"
)
const LOWER_TRIAL_HALL: LocationDefinition = preload(
	"res://world/locations/interiors/lower_trial_hall.tres"
)
const DOM_TAVERN: LocationDefinition = preload(
	"res://world/locations/interiors/dom_tavern.tres"
)
const ALL: Array[LocationDefinition] = [
	DOM,
	WILDS,
	DORTHKOR,
	WOUND_LIP,
	REGISTRY_ARCHIVE,
	BELL_HOUSE,
	RIVER_SHRINE,
	IRON_COMPANIES,
	ITEM_SHOP,
	EQUIPMENT_SHOP,
	TOWN_HALL,
	CHEFS_HOUSE,
	PLAYERS_HOUSE,
	TRIAL_HALL,
	REGISTRY_STACKS,
	BELL_LOFT,
	SHRINE_UNDERCROFT,
	GARRISON_YARD,
	CASK_WAREHOUSE,
	EQUIPMENT_FORGE,
	COUNCIL_CHAMBER,
	CHEFS_PANTRY,
	PLAYERS_LOFT,
	LOWER_TRIAL_HALL,
	DOM_TAVERN,
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


## An id with no scene path resolves by id alone; when BOTH are given they must
## agree — a mismatched pair falls through to the scene lookup so a stale id
## can never silently reroute an exit.
static func resolve(scene_path: String, location_id: StringName = &"") -> LocationDefinition:
	if not location_id.is_empty():
		var by_name := by_id(location_id)
		if by_name != null and (scene_path.is_empty() or by_name.scene_path == scene_path):
			return by_name
	return by_scene(scene_path)


static func is_gameplay_scene(scene_path: String) -> bool:
	var location := by_scene(scene_path)
	return location != null and location.allowed_gameplay


## FR-506: the thinning tier of the location that owns `scene_path`
## (0 for unknown scenes and untiered interiors — town-stable by default).
static func thinning_tier_by_scene(scene_path: String) -> int:
	var location := by_scene(scene_path)
	return location.thinning_tier if location != null else 0


static func gameplay_scenes() -> Array[String]:
	var scenes: Array[String] = []
	for location in ALL:
		if location.allowed_gameplay:
			scenes.append(location.scene_path)
	return scenes
