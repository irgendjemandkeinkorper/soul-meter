extends SceneTree
## P1.2 slice A: authored field opportunities, never attempts or prose mentions.
## Run: godot --headless --path . --script res://tools/audit_field_coverage.gd
## Judge the printed report, never the exit code (headless teardown can fail).
## Reads scene serialization without instantiating gameplay or loading its scripts.

const Schema := preload("res://globals/stats/dramgid_schema.gd")
const LootTables := preload("res://globals/loot_table_registry.gd")
const SceneText := preload("res://addons/weftlumin/core/tscn_document.gd")

## PROVISIONAL: R7 and item 11c, docs/owner-decisions.md §5, as quoted in the
## #531 slice-A handoff. Those answered entries and roadmap-2026-10-30.md are
## absent from this checkout. Do not turn these measuring lines into ratification.
## The old 12 skills / 3 checks line is comparison only, not the new acceptance bar.
const TARGETS: Dictionary = {
	"skills": 15, "bellow": 1, "verb": 5,
	"hub_locks": 4, "hub_pockets": 3, "hub_containers": 4,
	"wild_caches": 2, "loot_tables": 8, "items": 40,
	"superseded_skills": 12, "superseded_checks": 3,
}

## Fixed by the handoff, not inferred from fast-travel membership. The last two
## are ALSO wild locations in the shipped index; report both views, do not reclassify.
const HUB_IDS: PackedStringArray = ["dom", "ashlaren", "kesselford", "long_verge", "hollowmere"]
## Ruling 7's field verbs (skill checks on objects, lockpicking, stealing, barter, loot)
## carry the PROVISIONAL >= 5 target. The other interactions are reported for context
## only: a save point or a travel exit is not a Fallout-full field verb.
const FIELD_VERBS: PackedStringArray = [
	"lockpick", "pickpocket/steal", "loot container", "cache", "barter",
]
const INFO_VERBS: PackedStringArray = [
	"talk", "pickup", "switch", "inspect/interact", "save", "travel", "party selection",
	"damage structure",
]
const VERBS: PackedStringArray = FIELD_VERBS + INFO_VERBS
const PROPERTIES: PackedStringArray = [
	"lock_skill", "lock_id", "pocket_id", "pocket_skill", "container_id", "loot",
	"loot_table_id", "owned_by_faction", "vendor_id", "shop_type", "save_point",
	"dialogue_path", "item_id", "interaction_flag", "interaction_damage",
	"exit_transition_id", "transition_id", "destination_scene", "destination_location_id",
	"target_scene", "target_location_id",
]
const INDEX_PATH := "res://data/generated/location_index.json"
const INTERIOR_SCRIPT := "res://world/interiors/building_interior.gd"


func _initialize() -> void:
	print(report(audit()))
	quit()


static func audit() -> Dictionary:
	var tables: Dictionary = {}
	for id: StringName in LootTables.table_ids():
		tables[String(id)] = LootTables.table(id)
	var scenes := _sources("res://world", "tscn")
	scenes.merge(_sources("res://actors", "tscn"))
	var scripts := _sources("res://actors", "gd")
	scripts.merge(_sources("res://world", "gd"))
	var rosters: Dictionary = {}
	var placements: Dictionary = {}
	var locations: Array = _json(INDEX_PATH).get("locations", [])
	for location: Dictionary in locations:
		var id := String(location["id"])
		rosters.merge(_json("res://data/generated/%s_npc_roster.json" % id).get("npcs", {}))
		placements.merge(_json("res://data/generated/%s_npc_placements.json" % id).get("placements", {}))
	var vendor_ids := _string_constants(FileAccess.get_file_as_string("res://data/generated/vendor_ids.gd"))
	var vendor_sites := _dictionary_constant(String(scripts[INTERIOR_SCRIPT]), "VENDORS_BY_INTERIOR", vendor_ids)
	var result := audit_sources({
		"locations": locations, "scenes": scenes, "scripts": scripts,
		"dialogues": _sources("res://dialogue", "dialogue"), "tables": tables,
		"items": _json("res://data/generated/gloot_prototree.json"),
		"vendors": _json("res://data/generated/vendors.json"), "vendor_sites": vendor_sites,
		"rosters": rosters, "placements": placements,
	})
	var warnings: PackedStringArray = result["warnings"]
	if not FileAccess.file_exists("res://docs/roadmap-2026-10-30.md"):
		warnings.append("Source discrepancy: roadmap-2026-10-30.md is absent; targets are from the slice-A brief.")
	var decisions := FileAccess.get_file_as_string("res://docs/owner-decisions.md")
	if not decisions.contains("R7") or not decisions.contains("11c"):
		warnings.append("Source discrepancy: R7/11c answered density entries are absent; targets remain PROVISIONAL.")
	result["warnings"] = warnings
	return result


## Pure fixture seam. Scene/script/dialogue maps contain serialized source text;
## the other maps contain registry data, never live singleton state.
static func audit_sources(content: Dictionary) -> Dictionary:
	var result: Dictionary = {"skills": {}, "verbs": {}, "evidence": {}, "rows": [], "warnings": PackedStringArray()}
	for skill: String in Schema.FIELD_SKILL_IDS:
		result["skills"][skill] = 0
	for verb: String in VERBS:
		result["verbs"][verb] = 0
	var locations: Array = content.get("locations", [])
	var scenes: Dictionary = content.get("scenes", {})
	var scripts: Dictionary = content.get("scripts", {})
	var tables: Dictionary = content.get("tables", {})
	var locations_by_id: Dictionary = {}
	var locations_by_scene: Dictionary = {}
	var worlds: Dictionary = {}
	var scene_cache: Dictionary = {}
	var wild_ids: PackedStringArray = []
	for location: Dictionary in locations:
		var id := String(location["id"])
		var path := String(location.get("scene_path", ""))
		locations_by_id[id] = location
		if not path.is_empty():
			locations_by_scene[path] = location
		# Only mapped non-fast-travel locations are wilds. Unbuilt lore cities
		# with no world_map facet are not silently declared wild locations.
		if location.get("world_map") is Dictionary and not location.get("fast_travel") is Dictionary:
			wild_ids.append(id)
		# Registry-backed world roots exclude templates and world/fixtures, but
		# include world/test_room.tscn: it is the shipped location named Wilds.
		if path.begins_with("res://world/") and not path.begins_with("res://world/fixtures/") and scenes.has(path):
			worlds[path] = scene_nodes(path, scenes, scripts, scene_cache)
		if HUB_IDS.has(id) and not location.get("fast_travel") is Dictionary:
			_warn(result, "Classification discrepancy: brief hub %s has no fast-travel facet (retained in both applicable views)." % id)
	wild_ids.sort()
	var local_counts: Dictionary = {}
	for path: String in worlds:
		local_counts[path] = {"locks": 0, "pockets": 0, "containers": 0, "caches": 0}
		var location: Dictionary = locations_by_scene[path]
		var is_wild := wild_ids.has(String(location["id"]))
		for node: Dictionary in worlds[path]:
			_count_node(node, path, is_wild, tables, content.get("vendors", {}), local_counts[path], result)
	_count_spawned_npcs(content, worlds, result)
	var dialogues: Dictionary = content.get("dialogues", {})
	var dialogue_paths: Array = dialogues.keys()
	dialogue_paths.sort()
	for path: String in dialogue_paths:
		if not path.begins_with("res://dialogue/") or path.get_extension() != "dialogue":
			continue
		for check: Dictionary in dialogue_checks(String(dialogues[path])):
			_add_skill(result, check["skill"], "%s:%d" % [path, check["line"]])
	var distinct := 0
	var repeated := 0
	for skill: String in Schema.FIELD_SKILL_IDS:
		var count := int(result["skills"][skill])
		if count > 0:
			distinct += 1
		if count >= int(TARGETS["superseded_checks"]):
			repeated += 1
	result["distinct_skills"] = distinct
	result["bellow"] = int(result["skills"]["bellow"]) > 0
	result["superseded_skills"] = repeated
	var rows: Array = result["rows"]
	rows.append(measurement("Distinct field skills / %d" % Schema.FIELD_SKILL_IDS.size(), distinct, TARGETS["skills"]))
	rows.append(measurement("Bellow checks", result["skills"]["bellow"], TARGETS["bellow"]))
	for verb: String in FIELD_VERBS:
		rows.append(measurement("Verb: " + verb, result["verbs"][verb], TARGETS["verb"]))
	for verb: String in INFO_VERBS:
		rows.append(info_row("Verb (info): " + verb, result["verbs"][verb]))
	for id: String in HUB_IDS:
		var location: Dictionary = locations_by_id.get(id, {})
		var path := String(location.get("scene_path", ""))
		var counts := {"locks": 0, "pockets": 0, "containers": 0}
		for world_path: String in worlds:
			if _hub_for_scene(world_path, locations_by_scene) != id:
				continue
			for key: String in counts:
				counts[key] += int(local_counts[world_path][key])
		for key: String in counts:
			var label := "loot-table containers" if key == "containers" else key
			rows.append(measurement("Hub %s: %s" % [id, label], counts[key], TARGETS["hub_" + key], worlds.has(path)))
	for id: String in wild_ids:
		var path := String(locations_by_id[id].get("scene_path", ""))
		rows.append(measurement("Wild %s: caches" % id, local_counts.get(path, {}).get("caches", 0), TARGETS["wild_caches"], worlds.has(path)))
	rows.append(measurement("Loot tables", tables.size(), TARGETS["loot_tables"]))
	rows.append(measurement("Items", (content.get("items", {}) as Dictionary).size(), TARGETS["items"]))
	result["superseded"] = measurement("Skills with >= %d checks / %d" % [TARGETS["superseded_checks"], Schema.FIELD_SKILL_IDS.size()], repeated, TARGETS["superseded_skills"])
	result["scene_count"] = worlds.size()
	return result


static func measurement(label: String, count: int, target: int, has_scene: bool = true) -> Dictionary:
	return {"label": label, "count": count, "target": target, "pass": has_scene and count >= target,
		"gap": maxi(0, target - count), "has_scene": has_scene}


## A context row: counted and printed, never a PASS/FAIL gate.
static func info_row(label: String, count: int) -> Dictionary:
	return {"label": label, "count": count, "target": 0, "pass": true, "gap": 0,
		"has_scene": true, "info": true}


static func report(result: Dictionary) -> String:
	var lines := PackedStringArray([
		"Field coverage audit — P1.2 slice A", "Judge the printed report, never the exit code.",
		"PROVISIONAL targets: brief citing owner-decisions R7 / item 11c; not ratified here.",
		"Shipped registry world scenes: %d (templates and test fixtures excluded)." % result["scene_count"],
		"", "PROVISIONAL density measurements", "Measurement | Count | Target | Result",
	])
	for row: Dictionary in result["rows"]:
		lines.append(_report_row(row))
	lines.append("")
	lines.append("Field skill occurrences (>= 1 contributes to the %d/%d target; no quota for every skill)" % [TARGETS["skills"], Schema.FIELD_SKILL_IDS.size()])
	lines.append("Skill | Checks | Presence contribution | Result")
	for skill: String in Schema.FIELD_SKILL_IDS:
		lines.append(_report_row(measurement(Schema.skill_label(skill), result["skills"][skill], 1)))
	lines.append("")
	lines.append("SUPERSEDED comparison only: >= %d/%d skills, each checked >= %d times" % [TARGETS["superseded_skills"], Schema.FIELD_SKILL_IDS.size(), TARGETS["superseded_checks"]])
	lines.append(_report_row(result["superseded"]))
	for skill: String in Schema.FIELD_SKILL_IDS:
		lines.append(_report_row(measurement(Schema.skill_label(skill), result["skills"][skill], TARGETS["superseded_checks"])))
	lines.append("")
	lines.append("Counting rules: skill locks include force/strain; flag-only gates are not locks.")
	lines.append("Caches are Chest instances in wild scenes; hub containers require a live loot table (authored loot overrides it).")
	lines.append("Hub counts include recursively linked interiors. Pockets are NPC pockets; steal also includes owned loot/pickups.")
	lines.append("Barter counts placed vendor/shop access points; passive Sway pricing is not a rolled skill check.")
	lines.append("Loot searches count each distinct table skill once per placed container; unused tables add no checks.")
	lines.append("Dialogue counts executable check calls once per source site, not tags, prose, retries, or runtime reachability.")
	lines.append("Other verbs are explicit actor interactions; combat, automatic events, and UI-only actions are excluded.")
	for warning: String in result["warnings"]:
		lines.append("NOTE: " + warning)
	return "\n".join(lines)


static func _report_row(row: Dictionary) -> String:
	if row.get("info", false):
		return "%s | %d | — | INFO" % [row["label"], row["count"]]
	return "%s | %d%s | >= %d | %s" % [row["label"], row["count"],
		" (no scene)" if not row["has_scene"] else "", row["target"], "PASS" if row["pass"] else "FAIL"]


static func _count_node(node: Dictionary, path: String, wild: bool, tables: Dictionary,
		vendors: Dictionary, counts: Dictionary, result: Dictionary) -> void:
	var classes: PackedStringArray = node.get("classes", PackedStringArray())
	var props: Dictionary = node.get("props", {})
	var site := path + ":" + String(node["path"])
	var chest := classes.has("Chest")
	var interactable := classes.has("SMInteractable")
	var lock_id := String(props.get("lock_id", ""))
	if chest and lock_id.is_empty():
		lock_id = String(props.get("container_id", ""))
	var lock_skill := String(props.get("lock_skill", ""))
	if interactable and not lock_id.is_empty() and not lock_skill.is_empty():
		# "Lockpick" measures the code's skill-lock verb, including Strain locks.
		_add_verb(result, "lockpick", site)
		counts["locks"] += 1
		_add_skill(result, lock_skill, site + ":lock")
	var stealing := false
	if classes.has("NPC"):
		if not String(props.get("pocket_id", "")).is_empty():
			counts["pockets"] += 1
			stealing = true
			_add_skill(result, String(props.get("pocket_skill", "")), site + ":pocket")
		var vendor := String(props.get("vendor_id", ""))
		if not vendor.is_empty() and vendors.has(vendor):
			_add_verb(result, "barter", site)
		elif vendor.is_empty() and not String(props.get("dialogue_path", "")).is_empty():
			_add_verb(result, "talk", site)
	if chest:
		_add_verb(result, "loot container", site)
		stealing = not String(props.get("owned_by_faction", "")).is_empty()
		# There is no Cache class. Names/prose never select this category.
		if wild:
			_add_verb(result, "cache", site)
			counts["caches"] += 1
		var table_id := String(props.get("loot_table_id", ""))
		var loot: Array = props.get("loot", [])
		if not table_id.is_empty() and loot.is_empty():
			if tables.has(table_id):
				counts["containers"] += 1
				var skills: Dictionary = {}
				for row: Dictionary in tables[table_id].get("rows", []):
					var skill := String(row.get("skill", ""))
					if not skill.is_empty():
						skills[skill] = true
				for skill: String in skills:
					_add_skill(result, skill, site + ":search")
			else:
				_warn(result, "Unknown loot table %s at %s" % [table_id, site])
	elif classes.has("Pickup"):
		if not String(props.get("item_id", "")).is_empty():
			_add_verb(result, "pickup", site)
			stealing = not String(props.get("owned_by_faction", "")).is_empty()
	elif classes.has("InteractiveSwitch"):
		if not String(props.get("interaction_flag", "")).is_empty():
			_add_verb(result, "switch", site)
	elif classes.has("DestructibleStructure"):
		_add_verb(result, "damage structure" if int(props.get("interaction_damage", 0)) > 0 else "inspect/interact", site)
	elif interactable and not bool(props.get("save_point", false)) and String(props.get("shop_type", "")).is_empty():
		_add_verb(result, "inspect/interact", site)
	if stealing:
		_add_verb(result, "pickpocket/steal", site)
	if interactable and bool(props.get("save_point", false)):
		_add_verb(result, "save", site)
	if interactable and not String(props.get("shop_type", "")).is_empty():
		_add_verb(result, "barter", site)
	if classes.has("TravelExit") or classes.has("BuildingDoor") or classes.has("TavernDoor"):
		_add_verb(result, "travel", site)
	if classes.has("DomTavern"):
		# DomTavern owns one counter interaction and one walk-over exit in code.
		_add_verb(result, "party selection", site + ":CounterInteraction")
		_add_verb(result, "travel", site + ":Exit")


static func _count_spawned_npcs(content: Dictionary, worlds: Dictionary, result: Dictionary) -> void:
	var rosters: Dictionary = content.get("rosters", {})
	var placements: Dictionary = content.get("placements", {})
	var vendors: Dictionary = content.get("vendors", {})
	var vendor_sites: Dictionary = content.get("vendor_sites", {})
	for path: String in worlds:
		var nodes: Array = worlds[path]
		var interior := false
		var spawner := false
		var interior_path := ""
		var anchors: PackedStringArray = []
		for node: Dictionary in nodes:
			anchors.append(String(node["path"]).get_file())
			var classes: PackedStringArray = node["classes"]
			spawner = spawner or classes.has("TownNpcSpawner")
			if classes.has("BuildingInterior"):
				interior = true
				var transition := String(node["props"].get("exit_transition_id", ""))
				if transition.ends_with("_exit"):
					interior_path = "res://world/interiors/%s.tscn" % transition.trim_suffix("_exit")
		if interior or spawner:
			for id: String in placements:
				var placement: Dictionary = placements[id]
				if placement.get("scene", "") != (interior_path if interior else path):
					continue
				if not rosters.has(id) or not anchors.has(String(placement.get("anchor", ""))):
					_warn(result, "Unspawnable roster placement %s in %s" % [id, path])
					continue
				var dialogue: Dictionary = rosters[id].get("dialogue", {})
				if not String(dialogue.get("path", "")).is_empty():
					_add_verb(result, "talk", path + ":roster:" + id)
			# Spawners do NOT copy pocket fields from roster rows: no invented pockets.
		if interior and anchors.has("VendorSpot"):
			for id: String in vendor_sites.get(interior_path, []):
				if vendors.has(id):
					_add_verb(result, "barter", path + ":vendor:" + id)
				else:
					_warn(result, "Unspawnable vendor %s in %s" % [id, path])


static func _hub_for_scene(path: String, by_scene: Dictionary) -> String:
	var visited: PackedStringArray = []
	while by_scene.has(path) and not visited.has(path):
		visited.append(path)
		var row: Dictionary = by_scene[path]
		var id := String(row["id"])
		if HUB_IDS.has(id):
			return id
		var transition: Variant = row.get("transition")
		if not transition is Dictionary:
			break
		path = String(transition.get("source_scene", ""))
	return ""


static func _add_skill(result: Dictionary, skill: String, site: String) -> void:
	if not Schema.FIELD_SKILL_IDS.has(skill):
		_warn(result, "Non-field or unknown skill %s at %s (excluded from the 22)." % [skill, site])
		return
	result["skills"][skill] += 1
	_evidence(result, "skill:" + skill, site)


static func _add_verb(result: Dictionary, verb: String, site: String) -> void:
	result["verbs"][verb] += 1
	_evidence(result, "verb:" + verb, site)


static func _evidence(result: Dictionary, key: String, site: String) -> void:
	if not result["evidence"].has(key):
		result["evidence"][key] = PackedStringArray()
	result["evidence"][key].append(site)


static func _warn(result: Dictionary, message: String) -> void:
	result["warnings"].append(message)


## Parse executable dialogue syntax, not a grep of the line's prose. Strings
## and comments are tokens; check-like text inside either cannot be a call.
static func dialogue_checks(source: String) -> Array[Dictionary]:
	var checks: Array[Dictionary] = []
	var lines := source.split("\n")
	for line_index: int in lines.size():
		var line := String(lines[line_index]).strip_edges()
		if line.begins_with("#"):
			continue
		var expressions: PackedStringArray = []
		var tokens := _tokens(line)
		if not tokens.is_empty() and tokens[0] in ["if", "elif", "while", "do", "set"]:
			expressions.append(line)
		else:
			var start := -1
			for i: int in tokens.size():
				if tokens[i] == "[" and i + 1 < tokens.size() and tokens[i + 1] == "if":
					start = i + 2
				elif start >= 0 and tokens[i] == "]":
					expressions.append(" ".join(tokens.slice(start, i)))
					start = -1
		for expression: String in expressions:
			var parts := _tokens(expression)
			for i: int in maxi(0, parts.size() - 3):
				if parts[i] not in ["check", "SkillCheck.check"] or parts[i + 1] != "(" or parts[i + 3] != ",":
					continue
				if parts[i + 2].begins_with('"') or parts[i + 2].begins_with("'"):
					checks.append({"skill": _quoted_string(parts[i + 2]), "line": line_index + 1})
	return checks


## GDScript / scene lexical tokens: quoted strings remain whole, # comments
## disappear, identifiers keep dots. This never evaluates authored code.
static func _tokens(source: String) -> PackedStringArray:
	var pattern := RegEx.create_from_string("\\\"(?:\\\\.|[^\\\"\\\\])*\\\"|'(?:\\\\.|[^'\\\\])*'|\\[#[^\\]\\n]*\\]|#[^\\n]*|[A-Za-z_][A-Za-z0-9_.]*|-?[0-9]+(?:\\.[0-9]+)?|[^\\s]")
	var tokens: PackedStringArray = []
	for found: RegExMatch in pattern.search_all(source):
		var token := found.get_string()
		if not token.begins_with("#"):
			tokens.append(token)
	return tokens


## Expand inherited and nested PackedScene nodes, applying overrides by node
## path. Actor templates are expanded at each placement, never counted alone.
static func scene_nodes(path: String, scenes: Dictionary, scripts: Dictionary,
		cache: Dictionary = {}, stack: PackedStringArray = []) -> Array[Dictionary]:
	if cache.has(path):
		var cached: Array[Dictionary] = []
		cached.assign(cache[path].duplicate(true))
		return cached
	if stack.has(path) or not scenes.has(path):
		return []
	var ancestry := stack.duplicate()
	ancestry.append(path)
	var blocks := _scene_blocks(String(scenes[path]))
	var resources: Dictionary = {}
	var nodes: Dictionary = {}
	for block: Dictionary in blocks:
		var attributes: Dictionary = block["attributes"]
		if block["kind"] == "ext_resource":
			resources[attributes.get("id", "")] = attributes.get("path", "")
	for block: Dictionary in blocks:
		if block["kind"] != "node":
			continue
		var attributes: Dictionary = block["attributes"]
		var parent := String(attributes.get("parent", ""))
		var node_path := "." if parent.is_empty() else String(attributes.get("name", ""))
		if not parent.is_empty() and parent != ".":
			node_path = parent + "/" + node_path
		var instance := _resource_reference(String(attributes.get("instance", "")))
		if not instance.is_empty():
			for child: Dictionary in scene_nodes(String(resources.get(instance, "")), scenes, scripts, cache, ancestry):
				var child_path: String = child["path"]
				if node_path != ".":
					child_path = node_path if child_path == "." else node_path + "/" + child_path
				child["path"] = child_path
				nodes[child_path] = child
		var node: Dictionary = nodes.get(node_path, {"path": node_path, "props": {}, "script": ""})
		var props: Dictionary = block["props"]
		if props.has("script"):
			node["script"] = resources.get(_resource_reference(String(props["script"])), "")
		for property: String in PROPERTIES:
			if props.has(property):
				node["props"][property] = _literal(String(props[property]))
		nodes[node_path] = node
	var result: Array[Dictionary] = []
	for node: Dictionary in nodes.values():
		var info := _script_info(String(node["script"]), scripts)
		var props: Dictionary = info["defaults"].duplicate(true)
		props.merge(node["props"], true)
		node["props"] = props
		node["classes"] = info["classes"]
		result.append(node)
	cache[path] = result.duplicate(true)
	return result


static func _scene_blocks(source: String) -> Array[Dictionary]:
	# Use the existing lossless scene parser: multiline strings may contain
	# apparent [node] headers, and Godot permits tabs/whitespace around '='.
	# Its property-span reader is read-only; no vendor code or scene is mutated.
	var document := SceneText.parse(source)
	var blocks: Array[Dictionary] = []
	for section: Dictionary in document.sections:
		if section["kind"] not in ["ext_resource", "node"]:
			continue
		var props: Dictionary = {}
		for property: Dictionary in document._properties(section):
			props[property["key"]] = source.substr(property["value_start"], property["value_end"] - property["value_start"])
		blocks.append({"kind": section["kind"], "attributes": section["attributes"], "props": props})
	return blocks


static func _script_info(path: String, scripts: Dictionary, visited: PackedStringArray = []) -> Dictionary:
	var info := {"classes": PackedStringArray(), "defaults": {}}
	if not scripts.has(path) or visited.has(path):
		return info
	var ancestry := visited.duplicate()
	ancestry.append(path)
	var source := String(scripts[path])
	var parent_match := RegEx.create_from_string("(?m)^extends\\s+([^\\n]+)").search(source)
	if parent_match != null:
		var parent := parent_match.get_string(1).strip_edges()
		var parent_path := ""
		if parent.begins_with('"'):
			parent_path = String(str_to_var(parent))
			if not parent_path.begins_with("res://"):
				parent_path = path.get_base_dir().path_join(parent_path).simplify_path()
		else:
			for candidate: String in scripts:
				if _class_name(String(scripts[candidate])) == parent:
					parent_path = candidate
					break
		info = _script_info(parent_path, scripts, ancestry)
	var own_class := _class_name(source)
	if not own_class.is_empty():
		info["classes"].append(own_class)
	var export_pattern := RegEx.create_from_string("(?m)^@export[^\\n]*?\\bvar\\s+(\\w+)[^=\\n]*=([^\\n]+)")
	for found: RegExMatch in export_pattern.search_all(source):
		var key := found.get_string(1)
		if PROPERTIES.has(key):
			info["defaults"][key] = _literal(found.get_string(2))
	return info


static func _class_name(source: String) -> String:
	var found := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)").search(source)
	return found.get_string(1) if found != null else ""


static func _resource_reference(value: String) -> String:
	var found := RegEx.create_from_string('ExtResource\\(\\s*"([^\"]+)"\\s*\\)').search(value)
	return found.get_string(1) if found != null else ""


static func _literal(value: String) -> Variant:
	var tokens := _tokens(value)
	for i: int in tokens.size():
		if tokens[i].begins_with("'"):
			tokens[i] = var_to_str(_quoted_string(tokens[i]))
	var clean := " ".join(tokens)
	if clean.begins_with("Array [ Dictionary ] ("):
		clean = clean.trim_prefix("Array [ Dictionary ] (").trim_suffix(")").strip_edges()
	# Joining tokens separates a StringName's & from its quote; Variant accepts &"".
	clean = clean.replace('& "', '&"')
	return str_to_var(clean)


static func _quoted_string(token: String) -> String:
	return token.substr(1, token.length() - 2).c_unescape()


static func _dictionary_constant(source: String, name: String, symbols: Dictionary) -> Dictionary:
	var tokens := _tokens(source)
	for index: int in maxi(0, tokens.size() - 1):
		if tokens[index] != "const" or tokens[index + 1] != name:
			continue
		var start := index + 2
		while start < tokens.size() and tokens[start] != "{":
			start += 1
		var depth := 0
		var value: PackedStringArray = []
		for i: int in range(start, tokens.size()):
			var token := tokens[i]
			if token == "{":
				depth += 1
			elif token == "}":
				depth -= 1
			if token.begins_with("VendorIdsData."):
				token = var_to_str(symbols.get(token.trim_prefix("VendorIdsData."), ""))
			value.append(token)
			if depth == 0:
				var parsed: Variant = str_to_var(" ".join(value))
				return parsed if parsed is Dictionary else {}
	return {}


static func _string_constants(source: String) -> Dictionary:
	var values: Dictionary = {}
	var pattern := RegEx.create_from_string('(?m)^const (\\w+)\\s*:?=\\s*("[^"\\n]*")')
	for found: RegExMatch in pattern.search_all(source):
		values[found.get_string(1)] = str_to_var(found.get_string(2))
	return values


static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


static func _sources(directory: String, extension: String) -> Dictionary:
	var sources: Dictionary = {}
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() == extension:
			var path := directory.path_join(file)
			sources[path] = FileAccess.get_file_as_string(path)
	for child: String in DirAccess.get_directories_at(directory):
		if not child.begins_with(".") and child not in ["test", "tests", "fixtures"]:
			sources.merge(_sources(directory.path_join(child), extension))
	return sources
