class_name WeftluminScenesKind
extends WeftluminKind
## Soul Meter's `scenes` kind (E3.5, `docs/architecture-in-game-editor.md` §4.2, §4.6.2, §4.14).
##
## A package's scene documents are its command log (`commands.jsonl`, `weftlumin.command.v1`
## entries, undo/redo bookkeeping included). `bake()` hands the log to the game-agnostic
## `WeftluminBake` with Soul Meter's contract tests as validators, so a bake that would break a
## scene contract refuses with attributed errors and writes nothing:
##
## - **Ruling 9 / Dom `Blocking`.** No log may run `normalize_blocking_scale` on Dom, and a Dom
##   bake keeps `Blocking`'s transform, tile set and script lines byte-identical: Dom's layer is
##   not re-authored by a bake (`docs/weftlumin.md`, data-layer painters).
## - **Location contract.** Every spawn marker canon declares for the scene (`Spawn` + PascalCase
##   of the default spawn and each alias target, as `SaveGame` resolves them), every building
##   transition anchor and every generated NPC placement anchor in the scene still resolves.
## - **Dom contract.** The static `test/integration/test_starting_town.gd` invariants: building
##   roots with facades, the named landmarks and dressing, the hidden legacy tavern facade, a
##   y-sorted root with no `ColorRect`, no blockout waterline or `BuildingBoundaries`, and an
##   authored `Blocking` layer (tile set, script, more than 200 cells).
## - **Saturation lint** (E6.2 / #350, architecture §4.11). A *warning*, never a refusal: when a
##   baked field's `base_adjusted + max(zone_delta) + 10 > 100` or `base_adjusted +
##   min(zone_delta) - 10 < 0` (`AccordMath.saturation_warnings()`), the report carries it under
##   `warnings` and `lint.warnings` and the bake still writes.
##
## There is no runtime overlay for scenes: placements and export edits live in the live scene
## session until baked, so `register()` keeps the base refusal.

const DOM_SCENE := "res://world/starting_town.tscn"
const TownScript := preload("res://world/starting_town.gd")
const TRANSITIONS_DIR := "res://actors/building_door/transitions"
const NPC_PLACEMENTS := "res://data/generated/dom_npc_placements.json"
const BLOCKING_LINES: Array[String] = ["position", "scale", "tile_set", "script"]
## Dom's landmarks and dressing pinned by `test_starting_town.gd`.
const DOM_LANDMARKS: Array[String] = [
	"RegistryArchive", "BellHouse", "RiverShrine", "IronCompaniesBarracks", "ItemShop",
	"EquipmentShop", "TownHall", "ChefsHouse", "PlayersHouse", "HadrikVale", "TomaReedhand",
	"SellaVarn", "NoticeBoard", "BellHouseDoor", "RiverShrineMarker", "ItemShopDoor",
	"EquipmentShopDoor", "GarrisonDoor", "TownHallDoor", "ChefsHouseDoor", "PlayersHouseDoor",
	"SavePoint", "OakNorthWest", "PineNorth", "RockEast", "GrassShrine", "FieldHUD/ConsequenceNotices",
]


func _init() -> void:
	id = &"scenes"
	subdir = ""
	ext = "jsonl"
	stable_id_kind = &"scene"


## The entries of a `commands.jsonl` file; malformed lines become attributed errors.
static func load_log(path: String, errors: Array[Dictionary]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		errors.append(_error(path, "$", "a command log", "missing_log"))
		return entries
	var line_number: int = 0
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		line_number += 1
		if line.strip_edges().is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			entries.append(parsed as Dictionary)
		else:
			var error: Dictionary = _error(path, "$", "one JSON object per line", "invalid_log_line")
			error["line"] = line_number
			errors.append(error)
	return entries


## Well-formed `weftlumin.command.v1` entries, in log order.
func validate(documents: Array[Dictionary], errors: Array[Dictionary]) -> Array[Dictionary]:
	var normalised: Array[Dictionary] = []
	for index: int in documents.size():
		var document: Dictionary = documents[index]
		var field: String = "commands[%d]" % index
		if str(document.get("schema", WeftluminCommand.SCHEMA)) != WeftluminCommand.SCHEMA:
			errors.append(_error("", field + ".schema", WeftluminCommand.SCHEMA, "unsupported_command_schema"))
			continue
		var problems: PackedStringArray = WeftluminCommand.from_dict(document).validation_errors()
		if not problems.is_empty():
			errors.append(_error("", field, "a well-formed command", "invalid_command", "; ".join(problems)))
			continue
		normalised.append(document.duplicate(true))
	return normalised


func diff(previous: Array[Dictionary], next: Array[Dictionary]) -> Dictionary:
	return {"changed": JSON.stringify(previous) != JSON.stringify(next)}


func bake(normalised: Array[Dictionary], target_root: String, write: bool, force: bool) -> Dictionary:
	return WeftluminBake.bake(normalised, target_root, write, force, {"validators": contract_validators()})


func contract_validators() -> Array[Callable]:
	return [dom_blocking_ruling, location_contract, dom_contract, accord_saturation]


# --- validators: (context) -> Array[Dictionary] -----------------------------------------------


func dom_blocking_ruling(context: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if str(context["scene"]) != DOM_SCENE:
		return found
	for command: Dictionary in context["commands"]:
		if str(command.get("op", "")) == WeftluminTileBake.OP_NORMALIZE:
			found.append(_error(DOM_SCENE, "commands", "no normalize_blocking_scale on Dom", "dom_blocking_ruling",
				"Dom's Blocking is not re-authored by a bake (ruling 9); remove command %s." % command.get("id", "")))
	var before: Dictionary = _block(context["source_document"], "Blocking")
	var after: Dictionary = _block(context["document"], "Blocking")
	for key: String in BLOCKING_LINES:
		if WeftluminTileBake._property_text(before, key) != WeftluminTileBake._property_text(after, key):
			found.append(_error(DOM_SCENE, "Blocking:" + key, "unchanged", "dom_blocking_ruling",
				"Dom's Blocking %s changed; its layer is not re-authored by a bake (ruling 9)." % key))
	return found


func location_contract(context: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var scene: String = context["scene"]
	var instance: Node = context["instance"]
	var required: Dictionary = {}
	var canon_errors: Array[Dictionary] = []
	for location: Dictionary in WeftluminLocationsKind.load_canon(canon_errors):
		if str(location.get("scene_path", "")) != scene:
			continue
		var spawns: Array[String] = [str(location.get("default_spawn_id", ""))]
		var aliases: Variant = location.get("spawns", {})
		if aliases is Dictionary:
			for alias: Variant in aliases:
				spawns.append(str((aliases as Dictionary)[alias]))
		for spawn: String in spawns:
			if not spawn.is_empty():
				required["Spawn" + _pascal_case(spawn)] = "spawn %s of %s" % [spawn, location.get("id", "")]
	if DirAccess.dir_exists_absolute(TRANSITIONS_DIR):
		for filename: String in DirAccess.get_files_at(TRANSITIONS_DIR):
			if not filename.trim_suffix(".remap").ends_with(".tres"):
				continue
			var transition := load(TRANSITIONS_DIR.path_join(filename.trim_suffix(".remap"))) as BuildingTransitionDefinition
			if transition != null and transition.source_scene == scene and not transition.source_anchor.is_empty():
				required[str(transition.source_anchor)] = "transition anchor of %s" % filename
	var placements: Variant = JSON.parse_string(FileAccess.get_file_as_string(NPC_PLACEMENTS)) if FileAccess.file_exists(NPC_PLACEMENTS) else null
	if placements is Dictionary and (placements as Dictionary).get("placements") is Dictionary:
		for placement: Variant in ((placements as Dictionary)["placements"] as Dictionary).values():
			if placement is Dictionary and str((placement as Dictionary).get("scene", "")) == scene:
				required[str((placement as Dictionary).get("anchor", ""))] = "NPC placement anchor"
	var anchors: Array = required.keys()
	anchors.sort()
	for anchor: String in anchors:
		if not anchor.is_empty() and instance.get_node_or_null(NodePath(anchor)) == null:
			found.append(_error(scene, anchor, required[anchor], "location_contract", "The baked scene lost %s (%s)." % [anchor, required[anchor]]))
	return found


func dom_contract(context: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if str(context["scene"]) != DOM_SCENE:
		return found
	var town: Node = context["instance"]
	var expect: Callable = func(ok: bool, field: String, message: String) -> void:
		if not ok:
			found.append(_error(DOM_SCENE, field, "test_starting_town contract", "dom_contract", message))
	expect.call(town is Node2D and (town as Node2D).y_sort_enabled, ".", "Dom's root must stay y-sorted.")
	expect.call(town.find_children("*", "ColorRect", true, false).is_empty(), ".", "Dom must not contain ColorRect blockouts.")
	for building_name: String in TownScript.BUILDING_NAMES:
		var building: Node = town.get_node_or_null(building_name)
		expect.call(building != null and building.get_node_or_null("Facade") != null, building_name, "%s and its Facade must exist." % building_name)
	for landmark: String in DOM_LANDMARKS:
		var exists: bool = town.get_node_or_null(NodePath(landmark)) != null or town.find_child(landmark, true, false) != null
		expect.call(exists, landmark, "%s must exist." % landmark)
	var facade := town.get_node_or_null("TavernDoor/Facade") as Polygon2D
	expect.call(facade != null and not facade.visible, "TavernDoor/Facade", "The legacy tavern facade must stay hidden.")
	expect.call(town.get_node_or_null("Waterline") == null, "Waterline", "Dom must not regain the blockout waterline.")
	expect.call(town.find_child("BuildingBoundaries", true, false) == null, "BuildingBoundaries", "BuildingBoundaries must stay deleted.")
	var blocking := town.find_child("Blocking", true, false) as TileMapLayer
	expect.call(blocking != null and blocking.get_used_cells().size() > 200, "Blocking", "Blocking must keep its authored cells.")
	if blocking != null:
		expect.call(blocking.tile_set != null and blocking.tile_set.resource_path == "res://world/nav/blocking_tiles.tres", "Blocking:tile_set", "Blocking must keep its tile set.")
		var script: Script = blocking.get_script() as Script
		expect.call(script != null and script.resource_path == "res://world/nav/blocking_layer.gd", "Blocking:script", "Blocking must keep its script.")
	return found


## §4.11 saturation lint over the baked field. `base_adjusted` is the location's authored accord
## with thinning subtracted once (`SkillCheck.location_fizzle_integrity()`, as
## `FieldMap.accord_base()` computes it for the live scene); the zone range comes from the
## baked `AccordZone`s over the field's ground cells. A scene with no `FieldMap` or no location
## has no accord to lint. Entries carry `"severity": "warning"`, so they never block the write.
func accord_saturation(context: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var scene: String = context["scene"]
	var field: FieldMap = field_map_in(context["instance"] as Node)
	var location: LocationDefinition = LocationRegistry.by_scene(scene)
	if field == null or location == null:
		return found
	var base: float = SkillCheck.location_fizzle_integrity(location.harmonic_accord, scene)
	var span: Vector2 = zone_delta_range(field)
	for message: String in AccordMath.saturation_warnings(base, span.x, span.y, String(location.id)):
		var warning: Dictionary = _error(
			scene, "harmonic_accord", "base_adjusted + zone_delta ± %d within 0..100" % int(AccordMath.MAX_VARIATION),
			"accord_saturation", message,
		)
		warning["severity"] = "warning"
		found.append(warning)
	return found


## The first `FieldMap` at or under `root` (breadth-first), or null.
static func field_map_in(root: Node) -> FieldMap:
	var pending: Array[Node] = []
	if root != null:
		pending.append(root)
	while not pending.is_empty():
		var node: Node = pending.pop_front()
		if node is FieldMap:
			return node as FieldMap
		pending.append_array(node.get_children())
	return null


## Every ground cell `AccordZone`s cover, with the summed delta there: `{Vector2i: float}`.
## Read through `FieldMap` (`accord_zones()`, `zone_anchor_cell()`), the same anchors and
## coverage `FieldMap.zone_delta()` sums. Cells off the ground are dropped.
static func covered_zone_deltas(field: FieldMap) -> Dictionary:
	var deltas: Dictionary = {}
	var ground: TileMapLayer = field.ground()
	if ground == null:
		return deltas
	for zone: AccordZone in field.accord_zones():
		for cell: Vector2i in zone.covered_cells(field.zone_anchor_cell(zone)):
			if ground.get_cell_source_id(cell) != -1:
				deltas[cell] = float(deltas.get(cell, 0.0)) + float(zone.accord_delta)
	return deltas


## `Vector2(min, max)` of `zone_delta` over the field's ground cells. Uncovered ground counts as
## 0; a field with no ground cells reports `Vector2.ZERO`.
static func zone_delta_range(field: FieldMap) -> Vector2:
	var deltas: Dictionary = covered_zone_deltas(field)
	var ground: TileMapLayer = field.ground()
	var cell_count: int = ground.get_used_cells().size() if ground != null else 0
	var low: float = 0.0
	var high: float = 0.0
	var first: bool = deltas.size() >= cell_count
	for value: float in deltas.values():
		low = value if first else minf(low, value)
		high = value if first else maxf(high, value)
		first = false
	return Vector2(low, high)


static func _block(document: TscnDocument, path: String) -> Dictionary:
	for section: Dictionary in document.nodes:
		if WeftluminBake._section_path(section) == path:
			return section
	return {}


static func _pascal_case(value: String) -> String:
	var result: String = ""
	for part: String in value.replace("-", "_").split("_", false):
		result += part.capitalize().replace(" ", "")
	return result


static func _error(file: String, field: String, expected: String, code: String, message: String = "") -> Dictionary:
	return {
		"file": file, "field": field, "expected": expected, "code": code,
		"message": message if not message.is_empty() else "Expected %s for '%s'." % [expected, field],
	}
