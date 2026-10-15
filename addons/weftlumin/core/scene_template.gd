class_name WeftluminSceneTemplate
extends RefCounted
## Renders the minimum viable scene for `new_scene` (E3.4, `docs/architecture-in-game-editor.md`
## §4.6.5, Appendix C) and names everything it produces.
##
## `new_scene {hub, id, size_cells, backdrop, template}` renders into the package scratch,
## `user://weftlumin/<package>/scenes/<id>.tscn` plus `locations/<id>.json`, never into `res://`.
## The bake renders the same text again from the logged params (so it never depends on that
## scratch file existing), replays the scene's later edits onto it, and writes the baked path:
## `res://world/<id>.tscn`, or `res://world/interiors/<id>.tscn` for an interior.
##
## The field template mirrors `world/test_room.tscn`, the one field scene carrying every
## Appendix C piece: a `FieldMap` child (the field contract finds it by name), backdrop, hidden
## isometric ground/blocking/terrain layers, walls, player, party, `SpawnDefault`, HUD and the
## three dressing layers. `CombatOverlay` is omitted, as in every current scene (`FieldMap`
## supports its absence). The interior template instances `building_interior.tscn` the way
## `world/interiors/bell_loft.tscn` does: no grid, `no_combat_zone: true` (F0 ruling).

const FIELD := "field"
const INTERIOR := "interior"
const TEMPLATES: Dictionary = {
	FIELD: "res://addons/weftlumin/templates/field_scene.tscn.tmpl",
	INTERIOR: "res://addons/weftlumin/templates/interior_scene.tscn.tmpl",
}
const SCRATCH_ROOT := "user://weftlumin"
const DEFAULT_BACKDROP := "res://assets/generated/backgrounds/world/loamroot-wilds-terrain-v1.png"
## `test_room`'s 70×70 grid backs a 2000×1200 room; other sizes scale from it.
const REFERENCE_CELLS := 70
const REFERENCE_SIZE := Vector2i(2000, 1200)
const MIN_CELLS := 16
const MAX_CELLS := 200
const TILE_HALF := Vector2i(32, 16)
const SCHEMA := "weftlumin.location.v1"


## `params` checked and completed: `{hub, id, size_cells: [x, y], backdrop, template,
## display_name}`. `errors` names every problem; the dictionary is empty when there are any.
static func normalise(params: Dictionary, errors: Array[String]) -> Dictionary:
	var error_count: int = errors.size()
	var hub: String = str(params.get("hub", ""))
	var id: String = str(params.get("id", ""))
	var template: String = str(params.get("template", FIELD))
	if not _is_token(hub):
		errors.append("hub must be lowercase letters, digits, '-' or '_'.")
	if not _is_token(id) or id.contains("-"):
		errors.append("id must be lowercase letters, digits or '_' (a location id).")
	if not TEMPLATES.has(template):
		errors.append("template must be one of %s." % ", ".join(PackedStringArray(TEMPLATES.keys())))
	var size: Vector2i = Vector2i(REFERENCE_CELLS, REFERENCE_CELLS)
	var raw_size: Variant = params.get("size_cells", [REFERENCE_CELLS, REFERENCE_CELLS])
	if raw_size is Vector2i:
		size = raw_size
	elif raw_size is Array and (raw_size as Array).size() == 2:
		size = Vector2i(int((raw_size as Array)[0]), int((raw_size as Array)[1]))
	else:
		errors.append("size_cells must be [x, y].")
	if size.x < MIN_CELLS or size.y < MIN_CELLS or size.x > MAX_CELLS or size.y > MAX_CELLS:
		errors.append("size_cells must be between %d and %d on each axis." % [MIN_CELLS, MAX_CELLS])
	var backdrop: String = str(params.get("backdrop", ""))
	if backdrop.is_empty():
		backdrop = DEFAULT_BACKDROP
	if not backdrop.begins_with("res://") or not ResourceLoader.exists(backdrop, "Texture2D"):
		errors.append("backdrop must be an existing res:// texture.")
	if errors.size() != error_count:
		return {}
	var display_name: String = str(params.get("display_name", ""))
	if display_name.is_empty():
		display_name = id.capitalize()
	return {
		"hub": hub, "id": id, "template": template, "size_cells": [size.x, size.y],
		"backdrop": backdrop, "display_name": display_name,
	}


## The scene text for normalised `params`.
static func render(params: Dictionary) -> String:
	var text: String = FileAccess.get_file_as_string(TEMPLATES[str(params["template"])])
	for key: String in _values(params):
		text = text.replace("{{%s}}" % key, _values(params)[key])
	return text


static func _values(params: Dictionary) -> Dictionary:
	var cells := Vector2i(int(params["size_cells"][0]), int(params["size_cells"][1]))
	var side: int = mini(cells.x, cells.y)
	var room := Vector2i(REFERENCE_SIZE.x * side / REFERENCE_CELLS, REFERENCE_SIZE.y * side / REFERENCE_CELLS)
	var centre := room / 2
	# DIAMOND_DOWN puts cell (0, 0)'s top vertex at the layer origin; centre the diamond on the room.
	var ground := Vector2i(centre.x - (cells.x - cells.y) * TILE_HALF.x / 2, centre.y - (cells.x + cells.y) * TILE_HALF.y / 2)
	return {
		"root": root_name(params), "dressing": "%sDressing" % pascal(str(params["id"])),
		"display_name": str(params["display_name"]).c_escape(), "backdrop": str(params["backdrop"]),
		"width": str(room.x), "height": str(room.y), "center_x": str(centre.x), "center_y": str(centre.y),
		"bottom_wall": str(room.y - 20), "right_wall": str(room.x - 20),
		"ground_x": str(ground.x), "ground_y": str(ground.y), "cells_x": str(cells.x), "cells_y": str(cells.y),
	}


static func root_name(params: Dictionary) -> String:
	return pascal(str(params["id"])) + ("Interior" if str(params["template"]) == INTERIOR else "")


static func pascal(id: String) -> String:
	var result: String = ""
	for part: String in id.split("_", false):
		result += part.substr(0, 1).to_upper() + part.substr(1)
	return result


# --- paths ------------------------------------------------------------------------------------


static func package_dir(package: String) -> String:
	return SCRATCH_ROOT.path_join(package)


static func scratch_scene_path(package: String, id: String) -> String:
	return package_dir(package).path_join("scenes").path_join("%s.tscn" % id)


static func scratch_document_path(package: String, id: String) -> String:
	return package_dir(package).path_join("locations").path_join("%s.json" % id)


static func manifest_path(package: String) -> String:
	return package_dir(package).path_join("campaign.json")


static func baked_scene_path(params: Dictionary) -> String:
	var folder: String = "res://world/interiors/" if str(params["template"]) == INTERIOR else "res://world/"
	return folder + "%s.tscn" % params["id"]


static func definition_path(params: Dictionary) -> String:
	var folder: String = "res://world/locations/interiors/" if str(params["template"]) == INTERIOR else "res://world/locations/"
	return folder + "%s.tres" % params["id"]


# --- location ---------------------------------------------------------------------------------


## The package's `weftlumin.location.v1` document. It names the BAKED scene and definition paths
## (where canon will point); values beyond the template's are `LocationDefinition` defaults for
## the owner to set in the location panel.
static func location_document(params: Dictionary) -> Dictionary:
	var interior: bool = str(params["template"]) == INTERIOR
	var spawn: String = "entry" if interior else "default"
	return {
		"schema": SCHEMA, "id": str(params["id"]), "definition_path": definition_path(params),
		"scene_path": baked_scene_path(params), "allowed_gameplay": true, "default_spawn_id": spawn,
		"spawns": {spawn: spawn}, "arrival_flag": "", "arrival_checkpoint": "", "harmonic_accord": 100.0,
		"thinning_tier": 0, "weather_default": "", "no_combat_zone": interior, "respawn_policy": "limited",
	}


## The live definition `LocationRegistry.register_runtime()` takes: the document, but pointing at
## the scratch scene the session actually loads.
static func definition(params: Dictionary, scene_path: String) -> LocationDefinition:
	var document: Dictionary = location_document(params)
	var location := LocationDefinition.new()
	location.id = StringName(str(document["id"]))
	location.scene_path = scene_path
	location.allowed_gameplay = true
	location.default_spawn_id = StringName(str(document["default_spawn_id"]))
	var spawns: Dictionary = {}
	for alias: String in document["spawns"]:
		spawns[StringName(alias)] = StringName(str(document["spawns"][alias]))
	location.spawns = spawns
	location.harmonic_accord = float(document["harmonic_accord"])
	location.thinning_tier = int(document["thinning_tier"])
	location.respawn_policy = str(document["respawn_policy"])
	return location


static func _is_token(value: String) -> bool:
	if value.is_empty():
		return false
	for character: String in value:
		if not (character in "abcdefghijklmnopqrstuvwxyz0123456789-_"):
			return false
	return true
