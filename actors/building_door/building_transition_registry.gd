class_name BuildingTransitionRegistry
extends RefCounted
## Read-only registry for both sides of every building doorway (#342 PR 3).
##
## Canon owns the doors: each interior's location document carries a `transition` facet, and
## the locations bake writes the enter/exit `BuildingTransitionDefinition` pair under
## `actors/building_door/transitions/` (generated; never hand-edit). This registry reads the
## location index at load and loads those resources, so `load()` returns the same cached
## instances any preload of the same path does.
##
## Order is the index's: interiors sorted by location id, enter before exit in `ALL`. Runtime
## lookups go through `by_id()`, which order does not affect.

const TRANSITIONS_ROOT := "res://actors/building_door/transitions/"
## The one door code names directly: GameFlow keys the garrison permission on it.
const GARRISON_YARD_ENTER: BuildingTransitionDefinition = preload(
	"res://actors/building_door/transitions/garrison_yard_enter.tres"
)

static var ENTRIES: Array[BuildingTransitionDefinition] = []
static var EXITS: Array[BuildingTransitionDefinition] = []
static var ALL: Array[BuildingTransitionDefinition] = []
static var _loaded: bool = _load_index()


static func _load_index() -> bool:
	var index: JSON = load(LocationRegistry.INDEX_PATH) as JSON
	if index == null or not index.data is Dictionary:
		push_error("BuildingTransitionRegistry: missing or invalid location index.")
		return false
	var data: Dictionary = index.data
	if data.get("schema") != LocationRegistry.INDEX_SCHEMA:
		push_error("BuildingTransitionRegistry: unsupported location index schema.")
		return false
	for row: Dictionary in data.get("locations", []):
		var facet: Variant = row.get("transition")
		if not facet is Dictionary:
			continue
		var building_id: String = String(facet["building_id"])
		var enter := load(TRANSITIONS_ROOT + building_id + "_enter.tres") as BuildingTransitionDefinition
		var exit := load(TRANSITIONS_ROOT + building_id + "_exit.tres") as BuildingTransitionDefinition
		if enter == null or exit == null:
			push_error("BuildingTransitionRegistry: missing generated transition for %s." % building_id)
			continue
		ENTRIES.append(enter)
		EXITS.append(exit)
		ALL.append_array([enter, exit])
	return true


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
