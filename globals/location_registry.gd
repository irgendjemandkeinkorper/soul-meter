class_name LocationRegistry
extends RefCounted
## Central registry for gameplay location identity and safe travel targets. The set of locations
## comes from `data/generated/location_index.json` (E3.3b / #342); never hand-edit it, regenerate
## with `tools/generate_locations.gd`.

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
# Kesselford, hub 2 (C1 / #238): baked by the Weftlumin `kesselford` package.
const KESSELFORD: LocationDefinition = preload("res://world/locations/kesselford.tres")
const KESSELFORD_WAYHOUSE: LocationDefinition = preload(
	"res://world/locations/interiors/kesselford_wayhouse.tres"
)
const KESSELFORD_CHANDLERY: LocationDefinition = preload(
	"res://world/locations/interiors/kesselford_chandlery.tres"
)
# Ashlaren, hub 3 (C2 / #239): baked by the Weftlumin `ashlaren` package.
const ASHLAREN: LocationDefinition = preload("res://world/locations/ashlaren.tres")
const ASHLAREN_WEIGHING_HALL: LocationDefinition = preload(
	"res://world/locations/interiors/ashlaren_weighing_hall.tres"
)
const ASHLAREN_MILLHOUSE: LocationDefinition = preload(
	"res://world/locations/interiors/ashlaren_millhouse.tres"
)
# The Long Verge, location 7 (C3 / #240): the Companies' moor-road between Dom and Kesselford,
# baked by the Weftlumin `long-verge` package. Wilds, not a hub: no fast-travel row.
const LONG_VERGE: LocationDefinition = preload("res://world/locations/long_verge.tres")
## The baked index (`tools/generate_locations.gd`, E3.3a / #341). It owns WHICH locations exist;
## the named consts above stay for code references and resolve to the same cached resources.
const INDEX_PATH := "res://data/generated/location_index.json"
const INDEX_SCHEMA := "weftlumin.location_index.v1"
const _INTERIOR_SCENES_ROOT := "res://world/interiors/"


## Static classes cannot declare signals, so the registry's lives on one shared emitter.
class _Signals extends RefCounted:
	signal locations_changed


static var _signals: _Signals = _Signals.new()
## Emitted after `register_runtime()` changes the set of known locations (E3.3b, §4.3.3).
static var locations_changed: Signal = _signals.locations_changed
## Every baked location with a scene, in index order (E3.3b / #342): read from the index, never a
## hardcoded preload list. Runtime registrations are kept apart, in `_runtime`.
static var ALL: Array[LocationDefinition] = []
## Baked scene path -> canon `no_combat_zone`.
static var _no_combat_zones: Dictionary = {}
## In-session overlay (`register_runtime()`, P6): unbaked scenes, never written anywhere.
static var _runtime: Array[LocationDefinition] = []
## `no_combat_zone` of runtime registrations, by scene path; `LocationDefinition` carries no such field.
static var _runtime_no_combat: Dictionary = {}
static var _loaded := _load_index()


static func _load_index() -> bool:
	var index := load(INDEX_PATH) as JSON
	if index == null or not index.data is Dictionary:
		push_error("LocationRegistry: %s is missing or not a JSON object." % INDEX_PATH)
		return false
	var data: Dictionary = index.data
	if str(data.get("schema", "")) != INDEX_SCHEMA:
		push_error("LocationRegistry: %s is not %s." % [INDEX_PATH, INDEX_SCHEMA])
		return false
	for row: Variant in data.get("locations", []):
		if not row is Dictionary:
			continue
		var entry: Dictionary = row
		var definition_path := str(entry.get("definition_path", ""))
		if definition_path.is_empty():
			continue # gazetteer-only city: no scene to travel to
		var location := load(definition_path) as LocationDefinition
		if (
			location == null
			or String(location.id) != str(entry.get("id", ""))
			or location.scene_path != str(entry.get("scene_path", ""))
		):
			push_error("LocationRegistry: index row '%s' does not match %s." % [
				entry.get("id", ""), definition_path
			])
			continue
		ALL.append(location)
		_no_combat_zones[location.scene_path] = bool(entry.get("no_combat_zone", false))
	return true


## Registers an unbaked location for this session only (the overlay, P6), so a scene that exists
## only as data can be travelled to. Refuses a definition without an id or scene, or one whose id or
## scene a BAKED location already owns; re-registering a runtime id replaces it. Writes nothing.
## `no_combat_zone` is the location's canon flag (an unbaked interior's scene path cannot satisfy
## the `res://world/interiors/` prefix rule).
static func register_runtime(definition: LocationDefinition, no_combat_zone: bool = false) -> bool:
	if definition == null or definition.id.is_empty() or definition.scene_path.is_empty():
		push_error("LocationRegistry.register_runtime: a location needs an id and a scene path.")
		return false
	for location in ALL:
		if location.id == definition.id or location.scene_path == definition.scene_path:
			push_error("LocationRegistry.register_runtime: '%s' collides with baked '%s'." % [
				definition.id, location.id
			])
			return false
	for index: int in range(_runtime.size() - 1, -1, -1):
		var existing := _runtime[index]
		if existing.id == definition.id or existing.scene_path == definition.scene_path:
			_runtime_no_combat.erase(existing.scene_path)
			_runtime.remove_at(index)
	_runtime.append(definition)
	_runtime_no_combat[definition.scene_path] = no_combat_zone
	locations_changed.emit()
	return true


## Drops one runtime registration (undo of the command that registered it). False when `location_id`
## is not a runtime registration; baked locations are never removed.
static func unregister_runtime(location_id: StringName) -> bool:
	for index: int in _runtime.size():
		if _runtime[index].id == location_id:
			_runtime_no_combat.erase(_runtime[index].scene_path)
			_runtime.remove_at(index)
			locations_changed.emit()
			return true
	return false


## Drops every runtime registration. Not public API: test isolation only.
static func _clear_runtime() -> void:
	if _runtime.is_empty():
		return
	_runtime.clear()
	_runtime_no_combat.clear()
	locations_changed.emit()


static func _known() -> Array[LocationDefinition]:
	if _runtime.is_empty():
		return ALL
	var known: Array[LocationDefinition] = ALL.duplicate()
	known.append_array(_runtime)
	return known


static func by_id(location_id: StringName) -> LocationDefinition:
	for location in _known():
		if location.id == location_id:
			return location
	return null


static func by_scene(scene_path: String) -> LocationDefinition:
	for location in _known():
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


## F0 ruling 2: whether the scene at `scene_path` refuses ambient combat. Baked locations answer
## from canon `no_combat_zone`; any other scene (runtime registrations, fixtures) keeps the
## `res://world/interiors/` prefix rule the runtime used before the index was read.
static func no_combat_zone_by_scene(scene_path: String) -> bool:
	if _no_combat_zones.has(scene_path):
		return bool(_no_combat_zones[scene_path])
	if _runtime_no_combat.has(scene_path):
		return bool(_runtime_no_combat[scene_path])
	return scene_path.begins_with(_INTERIOR_SCENES_ROOT)


static func gameplay_scenes() -> Array[String]:
	var scenes: Array[String] = []
	for location in _known():
		if location.allowed_gameplay:
			scenes.append(location.scene_path)
	return scenes
