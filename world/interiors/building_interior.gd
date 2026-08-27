class_name BuildingInterior
extends Node2D
## Shared structural room used by each named building interior.

const NpcScene := preload("res://actors/npc/npc.tscn")
const NpcPlacementsData: JSON = preload("res://data/generated/dom_npc_placements.json")
const VendorData := preload("res://globals/vendor_registry.gd")
const VendorIdsData := preload("res://data/generated/vendor_ids.gd")
const FALLBACK_FLOOR_TEXTURE := preload("res://assets/generated/sprites/castle-kit/ground.png")
const FALLBACK_WALL_TEXTURE := preload("res://assets/generated/sprites/castle-kit/wall.png")
const DEFAULT_FLOOR_TEXTURE_PATH := "res://assets/generated/sprites/world/objects/dom-interior-floor--wood-panel.png"
const DEFAULT_WALL_TEXTURE_PATH := "res://assets/generated/sprites/world/objects/dom-interior-wall--brick.png"

## Vendor rows carry stable town-site ids but no scene anchor. Keep that world-layer
## mapping here while stock, prices, gates, and restock remain generated data.
const VENDORS_BY_INTERIOR := {
	"res://world/interiors/bell_house.tscn": [VendorIdsData.QUIET_GEAR],
	"res://world/interiors/chefs_house.tscn": [
		VendorIdsData.FOUR_ARMS_FISH,
		VendorIdsData.HEARTHLOAF_BAKERY,
	],
	"res://world/interiors/equipment_shop.tscn": [
		VendorIdsData.IRON_AND_THREAD,
		VendorIdsData.NEEDLE_AND_HIDE,
	],
	"res://world/interiors/iron_companies.tscn": [VendorIdsData.RIVET_AND_SPUR],
	"res://world/interiors/item_shop.tscn": [
		VendorIdsData.LOAM_AND_LANTERN,
		VendorIdsData.ROOT_AND_REED,
	],
	"res://world/interiors/players_house.tscn": [VendorIdsData.WAYFARERS_MEASURE],
	"res://world/interiors/river_shrine.tscn": [VendorIdsData.HELD_FLAME_SHRINE],
	"res://world/interiors/town_hall.tscn": [VendorIdsData.ASHLINE_SCRIPTORIUM],
	"res://world/interiors/trial_hall.tscn": [VendorIdsData.UNDERSTEP_EXCHANGE],
}

const INTERIOR_INTERACTION_RADIUS := 56.0
const VENDOR_SPACING := 128.0

@export var building_name: String = "BUILDING"
@export var exit_transition_id: StringName = &""
@export var floor_color := Color(0.12, 0.12, 0.14, 1.0)
@export var accent_color := Color(0.55, 0.4, 0.22, 1.0)


func _enter_tree() -> void:
	var exit_door := get_node_or_null("ExitDoor") as BuildingDoor
	if exit_door == null:
		push_error("Building interior '%s' is missing ExitDoor." % name)
		return
	exit_door.transition_id = exit_transition_id


func _ready() -> void:
	var floor := $Floor as Polygon2D
	var floor_texture := _load_optional_texture(DEFAULT_FLOOR_TEXTURE_PATH, FALLBACK_FLOOR_TEXTURE)
	floor.color = floor_color
	floor.texture = floor_texture
	floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var wall_texture := _load_optional_texture(DEFAULT_WALL_TEXTURE_PATH, FALLBACK_WALL_TEXTURE)
	for wall_name: String in ["WallTop", "WallBottom", "WallLeft", "WallRight"]:
		var wall := get_node(wall_name) as Polygon2D
		wall.texture = wall_texture
		wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	($AccentRug as Polygon2D).color = accent_color
	($Title as Label).text = building_name.to_upper()
	_populate_townsfolk()
	_populate_vendors()


func _populate_townsfolk() -> void:
	var interior_path := _interior_scene_path()
	var root: Dictionary = NpcPlacementsData.data
	var placements: Dictionary = root.get("placements", {})
	var placement_ids: Array = placements.keys()
	placement_ids.sort()
	for value: Variant in placement_ids:
		var npc_id := str(value)
		var placement_value: Variant = placements.get(npc_id, {})
		if not placement_value is Dictionary:
			continue
		var placement: Dictionary = placement_value
		if str(placement.get("scene", "")) != interior_path:
			continue
		var row := NpcRoster.get_npc(npc_id)
		var dialogue_value: Variant = row.get("dialogue", {})
		if row.is_empty() or not dialogue_value is Dictionary:
			push_error("Indoor NPC '%s' has no generated roster row." % npc_id)
			continue
		var anchor := find_child(str(placement.get("anchor", "")), true, false) as Marker2D
		if anchor == null:
			push_error("Indoor NPC '%s' has no placement anchor in '%s'." % [npc_id, interior_path])
			continue
		var dialogue: Dictionary = dialogue_value
		var npc := NpcScene.instantiate() as NPC
		npc.name = npc_id.to_pascal_case()
		npc.npc_id = npc_id
		npc.npc_name = str(row.get("display_name", npc_id))
		npc.dialogue_path = str(dialogue.get("path", ""))
		npc.dialogue_start = str(dialogue.get("title", "start"))
		npc.interaction_radius = INTERIOR_INTERACTION_RADIUS
		npc.position = anchor.position + _placement_offset(placement.get("offset", []))
		# npc.npc_id (set above) already self-wired this NPC to its own
		# generated unit art in NPC._ready() — model_index is kept only as
		# informational placement metadata, not a texture selector.
		npc.set_meta(&"model_index", int(placement.get("model_index", 0)))
		npc.add_to_group(&"indoor_npc")
		add_child(npc)


func _populate_vendors() -> void:
	var vendor_spot := find_child("VendorSpot", true, false) as Marker2D
	if vendor_spot == null:
		push_error("Building interior '%s' is missing VendorSpot." % name)
		return
	var values: Variant = VENDORS_BY_INTERIOR.get(_interior_scene_path(), [])
	if not values is Array:
		return
	var vendor_ids: Array = values
	for index: int in vendor_ids.size():
		var vendor_id := str(vendor_ids[index])
		var row := VendorData.vendor(vendor_id)
		if row.is_empty():
			push_error("Indoor vendor '%s' has no generated vendor row." % vendor_id)
			continue
		var npc := NpcScene.instantiate() as NPC
		npc.name = ("vendor_" + vendor_id).to_pascal_case()
		npc.npc_id = str(row.get("npc_id", ""))
		npc.npc_name = str(row.get("display_name", vendor_id))
		npc.vendor_id = vendor_id
		npc.interaction_radius = INTERIOR_INTERACTION_RADIUS
		npc.position = vendor_spot.position + _vendor_offset(index, vendor_ids.size())
		npc.add_to_group(&"indoor_vendor")
		add_child(npc)


static func _placement_offset(value: Variant) -> Vector2:
	if not value is Array or value.size() < 2:
		return Vector2.ZERO
	return Vector2(float(value[0]), float(value[1]))


static func _vendor_offset(index: int, count: int) -> Vector2:
	return Vector2((float(index) - float(count - 1) * 0.5) * VENDOR_SPACING, 0.0)


func _interior_scene_path() -> String:
	var transition := String(exit_transition_id)
	if not transition.ends_with("_exit"):
		return ""
	return "res://world/interiors/%s.tscn" % transition.trim_suffix("_exit")


func _load_optional_texture(path: String, fallback: Texture2D) -> Texture2D:
	if FileAccess.file_exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			return texture
	# The dom-revamp interior textures landed; this fallback now only covers a
	# missing/corrupt import, not a planned art gap.
	return fallback
