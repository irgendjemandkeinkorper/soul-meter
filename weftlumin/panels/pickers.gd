extends RefCounted
## Soul Meter's semantic pickers for the Weftlumin inspector (architecture §4.6.4, E3.1b).
##
## The inspector is schema-agnostic: it never names an actor field. This table is where the host
## says which exported properties mean a flag, a faction, a location, a spawn id, a dialogue
## file or title, an item or a unit. Each entry is
## `{label, properties: PackedStringArray (String.match globs), options: (node) -> PackedStringArray,
## validate: (value: String, node) -> String}`; a non-empty validation message refuses the edit.
##
## Lives under the export-excluded `weftlumin/panels/` because it reads `tools/quest_audit.gd`
## (the single flag-grammar rule) and scans source directories; the shipped adapter loads it
## lazily and fails closed to no pickers.

const QuestAudit := preload("res://tools/quest_audit.gd")
const FACTION_IDS_SCRIPT := "res://data/generated/faction_ids.gd"
const ITEM_IDS_SCRIPT := "res://data/generated/item_ids.gd"
const DIALOGUE_ROOT := "res://dialogue"
## Properties that name the location a door or exit leads to, for its spawn-id choices.
const DESTINATION_ID_PROPERTIES: Array[String] = ["destination_location_id", "target_location_id"]
const DESTINATION_SCENE_PROPERTIES: Array[String] = ["destination_scene", "target_scene"]

var _flags: PackedStringArray = PackedStringArray()
var _flags_scanned := false


func table() -> Dictionary:
	return {
		"flags": _entry("Flag", ["*_flag", "*_flags"], _flag_options, _validate_flag),
		"factions": _entry("Faction", ["*faction*"], _faction_options, _validate_known.bind(_faction_options)),
		"locations": _entry("Location", ["*location_id"], _location_options, _validate_known.bind(_location_options)),
		"spawn_ids": _entry("Spawn id", ["spawn_id"], _spawn_options, _validate_known.bind(_spawn_options)),
		"dialogue_files": _entry("Dialogue file", ["dialogue_path"], _dialogue_files, _validate_known.bind(_dialogue_files)),
		"dialogue_titles": _entry("Dialogue title", ["dialogue_start"], _dialogue_titles, _validate_title),
		"items": _entry("Item", ["item_id", "*_item_id"], _item_options, _validate_known.bind(_item_options)),
		"units": _entry("Unit", ["unit_id"], _unit_options, _validate_known.bind(_unit_options)),
	}


## Callables do not keep a RefCounted receiver alive, so each entry holds the table itself.
func _entry(label: String, globs: Array, options: Callable, validate: Callable) -> Dictionary:
	return {"label": label, "properties": PackedStringArray(globs), "options": options, "validate": validate, "source": self}


# --- flags ------------------------------------------------------------------------------------


## Flags the project's sources read or write (the quest audit's scan), plus live runtime flags.
func _flag_options(_node: Node) -> PackedStringArray:
	if not _flags_scanned:
		_flags = QuestAudit.scan_grammar_flags()
		_flags_scanned = true
	var known: Dictionary = {}
	for flag: String in _flags:
		known[flag] = true
	for flag: Variant in GameState.flags:
		known[str(flag)] = true
	return _sorted(known.keys())


## Live grammar check through `quest_audit.flag_grammar_violations`, the audit's own rule.
func _validate_flag(value: String, _node: Node) -> String:
	if value.is_empty():
		return ""
	var violations: Array[Dictionary] = QuestAudit.flag_grammar_violations(PackedStringArray([value]))
	return "" if violations.is_empty() else "%s: %s" % [value, violations[0].get("reason", "invalid flag")]


# --- catalogs ---------------------------------------------------------------------------------


func _faction_options(_node: Node) -> PackedStringArray:
	return _constant_values(FACTION_IDS_SCRIPT)


func _item_options(_node: Node) -> PackedStringArray:
	return _constant_values(ITEM_IDS_SCRIPT)


func _location_options(_node: Node) -> PackedStringArray:
	var ids: Array = []
	for location: LocationDefinition in LocationRegistry.ALL:
		ids.append(String(location.id))
	return _sorted(ids)


## Spawn ids the destination location resolves (`LocationDefinition.resolve_spawn`); every
## location's ids when the node names no destination yet.
func _spawn_options(node: Node) -> PackedStringArray:
	var destination: LocationDefinition = _destination(node)
	var ids: Dictionary = {"default": true}
	for location: LocationDefinition in [destination] if destination != null else LocationRegistry.ALL:
		for spawn: Variant in location.spawns:
			ids[str(spawn)] = true
	return _sorted(ids.keys())


## Archetype ids a `Hostile` can resolve (`EncounterCatalog.committed_archetype`).
func _unit_options(_node: Node) -> PackedStringArray:
	var ids: Dictionary = {}
	for encounter_id: StringName in EncounterCatalog.all_ids():
		var enemies: Variant = EncounterCatalog.definition(encounter_id).get("enemies", [])
		if not enemies is Array:
			continue
		for enemy: Variant in enemies:
			var unit_id: String = str((enemy as Dictionary).get("id", "")) if enemy is Dictionary else ""
			if not unit_id.is_empty() and not EncounterCatalog.committed_archetype(unit_id).is_empty():
				ids[unit_id] = true
	return _sorted(ids.keys())


# --- dialogue (§4.8: wiring only, never prose) ------------------------------------------------


func _dialogue_files(_node: Node) -> PackedStringArray:
	var paths: Array = []
	_scan(DIALOGUE_ROOT, "dialogue", paths)
	return _sorted(paths)


## Titles (`~ title` lines) of the node's own `dialogue_path`.
func _dialogue_titles(node: Node) -> PackedStringArray:
	var path: String = str(node.get("dialogue_path")) if node != null and node.get("dialogue_path") != null else ""
	var titles: Array = []
	if path.is_empty() or not FileAccess.file_exists(path):
		return PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("~ "):
			titles.append(line.substr(2).strip_edges())
	return _sorted(titles)


func _validate_title(value: String, node: Node) -> String:
	var titles: PackedStringArray = _dialogue_titles(node)
	if value.is_empty() or titles.is_empty() or titles.has(value):
		return ""
	return "%s is not a title in %s." % [value, str(node.get("dialogue_path")).get_file()]


# --- helpers ----------------------------------------------------------------------------------


func _validate_known(value: String, node: Node, options: Callable) -> String:
	if value.is_empty():
		return ""
	return "" if (options.call(node) as PackedStringArray).has(value) else "%s is not a known id." % value


func _destination(node: Node) -> LocationDefinition:
	if node == null:
		return null
	var location_id := StringName()
	for property: String in DESTINATION_ID_PROPERTIES:
		if node.get(property) != null and not str(node.get(property)).is_empty():
			location_id = StringName(str(node.get(property)))
	var scene_path := ""
	for property: String in DESTINATION_SCENE_PROPERTIES:
		if node.get(property) != null and not str(node.get(property)).is_empty():
			scene_path = str(node.get(property))
	if location_id.is_empty() and scene_path.is_empty():
		return null
	return LocationRegistry.resolve(scene_path, location_id)


static func _constant_values(script_path: String) -> PackedStringArray:
	var script: Script = load(script_path) as Script
	return _sorted(script.get_script_constant_map().values()) if script != null else PackedStringArray()


static func _scan(directory: String, extension: String, output: Array) -> void:
	for child: String in DirAccess.get_directories_at(directory):
		_scan(directory.path_join(child), extension, output)
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() == extension:
			output.append(directory.path_join(file))


static func _sorted(values: Array) -> PackedStringArray:
	var strings: Array[String] = []
	for value: Variant in values:
		strings.append(str(value))
	strings.sort()
	return PackedStringArray(strings)
