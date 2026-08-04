class_name BuildingTransitionRegistry
extends RefCounted
## Central data registry for both sides of every building doorway.

const REGISTRY_ARCHIVE_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/registry_archive_enter.tres"
)
const REGISTRY_ARCHIVE_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/registry_archive_exit.tres"
)
const BELL_HOUSE_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/bell_house_enter.tres"
)
const BELL_HOUSE_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/bell_house_exit.tres"
)
const RIVER_SHRINE_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/river_shrine_enter.tres"
)
const RIVER_SHRINE_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/river_shrine_exit.tres"
)
const IRON_COMPANIES_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/iron_companies_enter.tres"
)
const IRON_COMPANIES_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/iron_companies_exit.tres"
)
const ITEM_SHOP_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/item_shop_enter.tres"
)
const ITEM_SHOP_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/item_shop_exit.tres"
)
const EQUIPMENT_SHOP_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/equipment_shop_enter.tres"
)
const EQUIPMENT_SHOP_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/equipment_shop_exit.tres"
)
const TOWN_HALL_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/town_hall_enter.tres"
)
const TOWN_HALL_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/town_hall_exit.tres"
)
const CHEFS_HOUSE_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/chefs_house_enter.tres"
)
const CHEFS_HOUSE_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/chefs_house_exit.tres"
)
const PLAYERS_HOUSE_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/players_house_enter.tres"
)
const PLAYERS_HOUSE_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/players_house_exit.tres"
)
const TRIAL_HALL_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/trial_hall_enter.tres"
)
const TRIAL_HALL_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/trial_hall_exit.tres"
)
const REGISTRY_STACKS_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/registry_stacks_enter.tres"
)
const REGISTRY_STACKS_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/registry_stacks_exit.tres"
)
const BELL_LOFT_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/bell_loft_enter.tres"
)
const BELL_LOFT_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/bell_loft_exit.tres"
)
const SHRINE_UNDERCROFT_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/shrine_undercroft_enter.tres"
)
const SHRINE_UNDERCROFT_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/shrine_undercroft_exit.tres"
)
const GARRISON_YARD_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/garrison_yard_enter.tres"
)
const GARRISON_YARD_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/garrison_yard_exit.tres"
)
const CASK_WAREHOUSE_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/cask_warehouse_enter.tres"
)
const CASK_WAREHOUSE_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/cask_warehouse_exit.tres"
)
const EQUIPMENT_FORGE_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/equipment_forge_enter.tres"
)
const EQUIPMENT_FORGE_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/equipment_forge_exit.tres"
)
const COUNCIL_CHAMBER_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/council_chamber_enter.tres"
)
const COUNCIL_CHAMBER_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/council_chamber_exit.tres"
)
const CHEFS_PANTRY_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/chefs_pantry_enter.tres"
)
const CHEFS_PANTRY_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/chefs_pantry_exit.tres"
)
const PLAYERS_LOFT_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/players_loft_enter.tres"
)
const PLAYERS_LOFT_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/players_loft_exit.tres"
)
const LOWER_TRIAL_HALL_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/lower_trial_hall_enter.tres"
)
const LOWER_TRIAL_HALL_EXIT: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/lower_trial_hall_exit.tres"
)

const ENTRIES: Array[BuildingTransitionDefinition] = [
	REGISTRY_ARCHIVE_ENTER,
	BELL_HOUSE_ENTER,
	RIVER_SHRINE_ENTER,
	IRON_COMPANIES_ENTER,
	ITEM_SHOP_ENTER,
	EQUIPMENT_SHOP_ENTER,
	TOWN_HALL_ENTER,
	CHEFS_HOUSE_ENTER,
	PLAYERS_HOUSE_ENTER,
	TRIAL_HALL_ENTER,
	REGISTRY_STACKS_ENTER,
	BELL_LOFT_ENTER,
	SHRINE_UNDERCROFT_ENTER,
	GARRISON_YARD_ENTER,
	CASK_WAREHOUSE_ENTER,
	EQUIPMENT_FORGE_ENTER,
	COUNCIL_CHAMBER_ENTER,
	CHEFS_PANTRY_ENTER,
	PLAYERS_LOFT_ENTER,
	LOWER_TRIAL_HALL_ENTER,
]
const EXITS: Array[BuildingTransitionDefinition] = [
	REGISTRY_ARCHIVE_EXIT,
	BELL_HOUSE_EXIT,
	RIVER_SHRINE_EXIT,
	IRON_COMPANIES_EXIT,
	ITEM_SHOP_EXIT,
	EQUIPMENT_SHOP_EXIT,
	TOWN_HALL_EXIT,
	CHEFS_HOUSE_EXIT,
	PLAYERS_HOUSE_EXIT,
	TRIAL_HALL_EXIT,
	REGISTRY_STACKS_EXIT,
	BELL_LOFT_EXIT,
	SHRINE_UNDERCROFT_EXIT,
	GARRISON_YARD_EXIT,
	CASK_WAREHOUSE_EXIT,
	EQUIPMENT_FORGE_EXIT,
	COUNCIL_CHAMBER_EXIT,
	CHEFS_PANTRY_EXIT,
	PLAYERS_LOFT_EXIT,
	LOWER_TRIAL_HALL_EXIT,
]
const ALL: Array[BuildingTransitionDefinition] = [
	REGISTRY_ARCHIVE_ENTER,
	REGISTRY_ARCHIVE_EXIT,
	BELL_HOUSE_ENTER,
	BELL_HOUSE_EXIT,
	RIVER_SHRINE_ENTER,
	RIVER_SHRINE_EXIT,
	IRON_COMPANIES_ENTER,
	IRON_COMPANIES_EXIT,
	ITEM_SHOP_ENTER,
	ITEM_SHOP_EXIT,
	EQUIPMENT_SHOP_ENTER,
	EQUIPMENT_SHOP_EXIT,
	TOWN_HALL_ENTER,
	TOWN_HALL_EXIT,
	CHEFS_HOUSE_ENTER,
	CHEFS_HOUSE_EXIT,
	PLAYERS_HOUSE_ENTER,
	PLAYERS_HOUSE_EXIT,
	TRIAL_HALL_ENTER,
	TRIAL_HALL_EXIT,
	REGISTRY_STACKS_ENTER,
	REGISTRY_STACKS_EXIT,
	BELL_LOFT_ENTER,
	BELL_LOFT_EXIT,
	SHRINE_UNDERCROFT_ENTER,
	SHRINE_UNDERCROFT_EXIT,
	GARRISON_YARD_ENTER,
	GARRISON_YARD_EXIT,
	CASK_WAREHOUSE_ENTER,
	CASK_WAREHOUSE_EXIT,
	EQUIPMENT_FORGE_ENTER,
	EQUIPMENT_FORGE_EXIT,
	COUNCIL_CHAMBER_ENTER,
	COUNCIL_CHAMBER_EXIT,
	CHEFS_PANTRY_ENTER,
	CHEFS_PANTRY_EXIT,
	PLAYERS_LOFT_ENTER,
	PLAYERS_LOFT_EXIT,
	LOWER_TRIAL_HALL_ENTER,
	LOWER_TRIAL_HALL_EXIT,
]


static func by_id(transition_id: StringName) -> BuildingTransitionDefinition:
	for transition in ALL:
		if transition.id == transition_id:
			return transition
	return null


static func entry_for(building_id: StringName) -> BuildingTransitionDefinition:
	for transition in ENTRIES:
		if transition.building_id == building_id:
			return transition
	return null


static func exit_for(building_id: StringName) -> BuildingTransitionDefinition:
	for transition in EXITS:
		if transition.building_id == building_id:
			return transition
	return null


static func entries_from(scene_path: String) -> Array[BuildingTransitionDefinition]:
	var matches: Array[BuildingTransitionDefinition] = []
	for transition in ENTRIES:
		if transition.source_scene == scene_path:
			matches.append(transition)
	return matches
