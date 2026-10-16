extends WeftluminGameAdapter
## Shell-local host bridge until the separately scoped authoring adapter exists.


func env_flag() -> String:
	return "SOUL_METER_WEFTLUMIN"


func theme() -> Theme:
	return UIManager.ui_theme


## Field HUDs the editor hid, with the visibility each had, so close restores exactly.
var _hidden_huds: Dictionary[CanvasLayer, bool] = {}


func set_editor_open(open: bool) -> void:
	GameFlow.set_editor_open(open)
	_set_field_huds_hidden(open)


## FieldHUD sits at layer 5, under the shell, and its hotkey bar shows through the dock's open
## top edge. It hides while editing, the same way FieldMap.set_combat_mode hides it in battle.
func _set_field_huds_hidden(hidden: bool) -> void:
	if not hidden:
		for hud: CanvasLayer in _hidden_huds:
			if is_instance_valid(hud):
				hud.visible = _hidden_huds[hud]
		_hidden_huds.clear()
		return
	for node: Node in GameFlow.get_tree().root.find_children("*", "CanvasLayer", true, false):
		var hud := node as CanvasLayer
		if hud.scene_file_path == FieldMap.FIELD_HUD_SCENE and not _hidden_huds.has(hud):
			_hidden_huds[hud] = hud.visible
			hud.visible = false


## Soul Meter's tool panels (§4.1 `weftlumin/panels/`), in dock order. The directory is
## export-excluded, so each scene loads lazily and a build without it mounts none (fails closed).
const PANEL_SCENES: Array[String] = [
	"res://weftlumin/panels/scene_panel.tscn",
	"res://weftlumin/panels/console_panel.tscn",
	"res://weftlumin/panels/timeline_panel.tscn",
	"res://weftlumin/panels/combat_lab_panel.tscn",
	"res://weftlumin/panels/dialogue_panel.tscn",
	"res://weftlumin/panels/quest_panel.tscn",
	"res://weftlumin/panels/location_panel.tscn",
	"res://weftlumin/panels/spawn_panel.tscn",
	"res://weftlumin/panels/character_panel.tscn",
	# E6.2 (#350): read-only accord / weather / charge / walkability overlay.
	"res://weftlumin/panels/accord_overlay.tscn",
]


func panels() -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	for path: String in PANEL_SCENES:
		var packed: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
		if packed == null:
			push_warning("Weftlumin: panel %s is missing; its tab stays a placeholder." % path)
			continue
		result.append(packed)
	return result


## Ruling 8: the existing actor types, made placeable (§4.6.4). No new actor types. Each row is
## `[id, label, palette group, scene path or engine class, node-name stem]`; scenes load lazily.
## ZhavarTelegraph is absent: it is a plain `Node` screen overlay with no position, and the scene
## model edits `Node2D`s only.
const PLACEABLES: Array[Array] = [
	[&"npc", "NPC", "Units & NPCs", "res://actors/npc/npc.tscn", "Npc"],
	[&"hostile", "Hostile", "Units & NPCs", "res://actors/hostile/hostile.tscn", "Hostile"],
	[&"building_door", "Building door", "Doors & exits", "res://actors/building_door/building_door.tscn", "BuildingDoor"],
	[&"travel_exit", "Travel exit", "Doors & exits", "res://actors/travel_exit/travel_exit.tscn", "TravelExit"],
	[&"interactable", "Interactable", "Interactables", "res://actors/interactable/interactable.tscn", "Interactable"],
	[&"chest", "Chest", "Interactables", "res://actors/chest/chest.tscn", "Chest"],
	[&"pickup", "Pickup", "Interactables", "res://actors/pickup/pickup.tscn", "Pickup"],
	[&"switch", "Switch", "Interactables", "res://actors/switch/switch.tscn", "Switch"],
	[&"spawn_marker", "Spawn marker", "Markers", "Marker2D", "SpawnMarker"],
	# §4.10: a spawn-slot anchor. The Spawns panel names each one `SpawnSlot<PascalCase slot id>`.
	[&"spawn_slot", "Spawn slot", "Markers", "Marker2D", "SpawnSlot"],
	# The one new type (owner ruling 2026-10-11, #349): a data volume, not a trigger.
	[&"accord_zone", "Accord zone", "Markers", "res://actors/accord_zone/accord_zone.tscn", "AccordZone"],
]
## Semantic picker table; export-excluded with the panels, so a build without it has none.
const PICKERS_SCRIPT := "res://weftlumin/panels/pickers.gd"


func placeables() -> Array[WeftluminPlaceable]:
	var result: Array[WeftluminPlaceable] = []
	for row: Array in PLACEABLES:
		var source: String = row[3]
		var packed: PackedScene = null
		if source.begins_with("res://"):
			packed = load(source) as PackedScene if ResourceLoader.exists(source) else null
			if packed == null:
				push_warning("Weftlumin: placeable %s is missing." % source)
				continue
		result.append(WeftluminPlaceable.make(
			row[0], row[1], row[2], packed, &"" if packed != null else StringName(source), row[4]
		))
	return result


## Authoring kinds (§4.2). The characters kind carries Soul Meter's open registries — character
## kinds npc/archetype/recruit and stat schemas dramgid.v1/six-stat.v1 (§4.7, E5.1 / #347).
func kinds() -> Array[WeftluminKind]:
	var result: Array[WeftluminKind] = [WeftluminCharactersKind.soul_meter()]
	return result


func pickers() -> Dictionary:
	if not ResourceLoader.exists(PICKERS_SCRIPT):
		return {}
	var script: GDScript = load(PICKERS_SCRIPT) as GDScript
	return script.new().table() if script != null else {}


func gameplay_scene_root() -> Node:
	return GameFlow.get_tree().current_scene


func production_owner_live() -> bool:
	return Battle.session_active or _production_dialogue_live()


## True while a Dialogue Manager balloon is showing under the current scene. Formerly read from the
## dialogue lab's autoload, which E2.5b (#337) removed; the dialogue panel's own model still applies
## its finer lab-owned-balloon exclusion before starting a replay.
func _production_dialogue_live() -> bool:
	var current_scene: Node = null
	if DialogueManager.get_current_scene.is_valid():
		current_scene = DialogueManager.get_current_scene.call() as Node
	return current_scene != null and _contains_dialogue_balloon(current_scene)


static func _contains_dialogue_balloon(node: Node) -> bool:
	for child: Node in node.get_children():
		if child.get("dialogue_resource") is DialogueResource:
			return true
		if _contains_dialogue_balloon(child):
			return true
	return false


func capture_runtime_state() -> Dictionary:
	return SaveGame.capture_runtime_state()


func restore_runtime_state(snapshot: Dictionary) -> bool:
	return SaveGame.restore_runtime_state(snapshot)


# --- Headless CLI (E7.1, architecture §4.13) ----------------------------------------------------
# `addons/weftlumin/tools/weftlumin.gd` drives these. They run inside the CLI's `_initialize()`,
# after the autoloads exist. Nothing here writes `res://` unless the caller passes `write`.

const DEFAULT_HUB := "dom"
const CANON_ROOT := "res://canon"
const POT_FILES: Array[String] = ["res://locale/project.pot", "res://data/generated/items.pot"]
## Actor exports whose text a player reads (§2 row 15: outside the POT pipeline today).
const PLAYER_FACING_KEYS: Array[String] = [
	"display_name", "interaction_text", "label_text", "lock_failed_message", "locked_message",
	"npc_name", "pocket_caught_message", "prompt_text",
]
const QUEST_AUDIT_SCRIPT := "res://tools/quest_audit.gd"
const SEED_PANDORA_SCRIPT := "res://tools/seed_pandora.gd"
const GENERATE_GLOOT_SCRIPT := "res://tools/generate_gloot.gd"
const GENERATE_LOCATIONS_SCRIPT := "res://tools/generate_locations.gd"
const ISOMETRIC_SPRITES_SCRIPT := "res://tools/render_isometric_sprites.gd"
## Export-excluded with the panels; a build without it runs no live verb.
const LIVE_VERBS_SCRIPT := "res://weftlumin/panels/live_verbs.gd"
## Live-state verbs a log may carry: the console vocabulary, `{"kind": "console", "op": "execute",
## "params": {"command": "<console line>"}}`, run unchanged and still `[debug] `-tagged.
const LIVE_CONSOLE_KIND := "console"
const LIVE_CONSOLE_OP := "execute"
## The fixed kind → test-glob map the PR flow runs (§4.13). `canon` means the drift stages.
const DRIFT_STAGES := "scripts/check_generated_data.sh"
const AFFECTED_TESTS: Dictionary = {
	"scenes": ["test/integration/test_starting_town.gd", "test/integration/test_field_room.gd", "test/integration/test_travel_*"],
	"quests": ["test/unit/test_quest_*", "test/unit/test_campaign_*"],
	"dialogue": ["test/unit/test_quest_*", "test/unit/test_campaign_*"],
	"encounters": ["test/unit/test_encounter_*", "test/unit/test_spawn_*"],
	"spawn_tables": ["test/unit/test_encounter_*", "test/unit/test_spawn_*"],
	"characters": ["test/unit/test_party_*", "test/unit/test_npc_*", DRIFT_STAGES],
	"locations": [DRIFT_STAGES],
	"canon": [DRIFT_STAGES],
}


## Every kind a package can carry. `kinds()` stays the shell's list; the CLI reads all of them.
func cli_kinds() -> Array[WeftluminKind]:
	var result: Array[WeftluminKind] = [
		WeftluminScenesKind.new(), WeftluminLocationsKind.new(), WeftluminCharactersKind.soul_meter(),
		WeftluminSpawnTablesKind.new(), CampaignQuestLoader.QuestsKind.new(),
		CampaignEncounterLoader.EncountersKind.new(),
	]
	return result


func scene_bake_validators() -> Array[Callable]:
	return WeftluminScenesKind.new().contract_validators()


func validate_package_documents(kind: WeftluminKind, documents: Array[Dictionary], package: Dictionary) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	match String(kind.id):
		"scenes":
			pass  # The CLI validates the log itself; replay and contracts are the bake's.
		"quests", "encounters":
			# Campaign kinds validate as a whole package through the F6 loader, once.
			if String(kind.id) == "encounters" and (package.get("kinds", []) as Array).has("quests"):
				return errors
			var loaded: Dictionary = CampaignQuestLoader.load_package(str(package["dir"]), false)
			for error: Variant in loaded.get("errors", []):
				if error is Dictionary:
					errors.append(error as Dictionary)
		_:
			var merged: Dictionary = _overlay_canon(kind, documents, package, errors)
			if errors.is_empty():
				kind.validate(merged["documents"], errors)
	return errors


## Package documents overlay canon by id (a package document replaces the canon document of the
## same id, or is new); the whole set validates, and each package document bakes to its canon
## file — `canon/<hub>/<kind>/<id>.json` when new. Locations also regenerate their `.tres` and
## index through the kind's own bake. Quests and encounters have no canon target yet.
func bake_package_documents(
	kind: WeftluminKind, documents: Array[Dictionary], package: Dictionary, write: bool, force: bool,
) -> Dictionary:
	var errors: Array[Dictionary] = []
	var report: Dictionary = {
		"schema": WeftluminBake.SCHEMA, "package": package.get("id", ""), "mode": "write" if write else "report",
		"planned": [], "written": [], "regenerated": [], "errors": errors, "summary": "",
	}
	if String(kind.id) == "scenes":
		return {}  # The CLI bakes the scene log through WeftluminBake with scene_bake_validators().
	if String(kind.id) in ["quests", "encounters"]:
		report["summary"] = "%d document(s); no canon target yet (campaign kinds stay runtime packages)" % documents.size()
		return report
	var merged: Dictionary = _overlay_canon(kind, documents, package, errors)
	var normalised: Array[Dictionary] = []
	if errors.is_empty():
		normalised = kind.validate(merged["documents"], errors)
	if not errors.is_empty():
		report["summary"] = "refused: %d error(s)" % errors.size()
		return report
	var targets: Dictionary = merged["targets"]
	var changed: int = 0
	var npc_changed: bool = false
	for row: Dictionary in normalised:
		var row_id: String = str(row.get("id", ""))
		if not targets.has(row_id):
			continue
		var path: String = targets[row_id]
		var text: String = kind.call("canon_text", row)
		var action: String = "create"
		if FileAccess.file_exists(path):
			action = "unchanged" if FileAccess.get_file_as_string(path) == text else "update"
		(report["planned"] as Array).append({"kind": String(kind.id), "path": path, "action": action, "id": row_id})
		if action == "unchanged":
			continue
		changed += 1
		npc_changed = npc_changed or str(row.get("kind", "")) == "npc"
		if write:
			var written: Error = _write_text(path, text)
			if written != OK:
				errors.append(_cli_error(path, "$", "a writable canon document", "write_failed", "Writing failed (error %d)." % written))
				continue
			(report["written"] as Array).append(path)
	if String(kind.id) == "locations":
		var artifacts: Dictionary = kind.bake(normalised, "res://", write, force)
		for planned: Dictionary in artifacts.get("planned", []):
			if str(planned.get("action", "")) != "unchanged":
				(report["planned"] as Array).append(planned)
		(report["written"] as Array).append_array(artifacts.get("written", []))
		errors.append_array(artifacts.get("errors", []))
	if npc_changed:
		(report["regenerated"] as Array).append_array([
			"res://data/generated/dom_npc_roster.json", "res://data/generated/dom_npc_placements.json",
		])
	report["summary"] = "%d package document(s), %d canon change(s)" % [targets.size(), changed]
	return report


## `{documents, targets}`: canon with the package documents laid over it by id, and each package
## document's canon path.
func _overlay_canon(kind: WeftluminKind, documents: Array[Dictionary], package: Dictionary, errors: Array[Dictionary]) -> Dictionary:
	var canon: Array[Dictionary] = []
	canon.assign(kind.call("load_canon", errors))
	var hub: String = str(package.get("hub", ""))
	if hub.is_empty():
		hub = DEFAULT_HUB
	var by_id: Dictionary = {}
	for index: int in canon.size():
		by_id[str(canon[index].get("id", ""))] = index
	var targets: Dictionary = {}
	for document: Dictionary in documents:
		var row: Dictionary = document.duplicate(true)
		var row_id: String = str(row.get("id", ""))
		if row_id.is_empty():
			errors.append(_cli_error(str(row.get("$file", "")), "id", "a document id", "missing_id", "A package document names no id."))
			continue
		if by_id.has(row_id):
			var replaced: Dictionary = canon[by_id[row_id]]
			row["$hub"] = replaced.get("$hub", hub)
			targets[row_id] = str(replaced.get("$file", ""))
			canon[by_id[row_id]] = row
		else:
			row["$hub"] = hub
			targets[row_id] = CANON_ROOT.path_join(hub).path_join(kind.subdir).path_join("%s.json" % row_id)
			by_id[row_id] = canon.size()
			canon.append(row)
	return {"documents": canon, "targets": targets}


## quest_audit's static checks over the package: flag grammar (errors — a package's flags are new
## and have no save to protect), checked-response softlocks, and quest-critical phase reachability
## for package quest givers.
func lint_package(package: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	var audit: GDScript = load(QUEST_AUDIT_SCRIPT) as GDScript
	if audit == null:
		return {"errors": errors, "warnings": warnings}
	var dialogue: Dictionary = package.get("dialogue", {})
	var paths: PackedStringArray = PackedStringArray(dialogue.keys())
	var flags: Dictionary = {}
	var access: Dictionary = audit.call("scan_flag_sources", paths)
	for flag: Variant in access.get("written", []):
		flags[str(flag)] = true
	for flag: Variant in access.get("read", []):
		flags[str(flag)] = true
	var givers: PackedStringArray = []
	for quest: Variant in (package.get("documents", {}) as Dictionary).get("quests", []):
		if quest is Dictionary:
			_collect_flags(quest, flags)
			var giver: String = str((quest as Dictionary).get("giver_actor_id", ""))
			if not giver.is_empty():
				givers.append(giver)
	var flag_list: PackedStringArray = PackedStringArray(flags.keys())
	flag_list.sort()
	for violation: Dictionary in audit.call("flag_grammar_violations", flag_list):
		errors.append(_cli_error(str(package.get("dir", "")), "flag " + str(violation.get("flag", "")), "<domain>_<subject>_<predicate>", "flag_violates_grammar", str(violation.get("reason", ""))))
	for finding: Dictionary in audit.call("check_softlock_violations", dialogue):
		var row: Dictionary = _cli_error(str(finding.get("source", "")), "line %s" % finding.get("line", ""), "a checked response with both outcomes", str(finding.get("code", "")), str(finding.get("response", "")))
		row["line"] = finding.get("line", 0)
		if str(finding.get("severity", "error")) == "warning":
			warnings.append(row)
		else:
			errors.append(row)
	if not givers.is_empty():
		for violation: Dictionary in audit.call("phase_reachability_violations", givers):
			errors.append(_cli_error(str(package.get("dir", "")), "giver " + str(violation.get("npc_id", violation.get("npc", ""))), "reachable in two or more phases", "quest_critical_npc_reachable_in_fewer_than_two_phases", JSON.stringify(violation)))
	return {"errors": errors, "warnings": warnings}


static func _collect_flags(value: Variant, flags: Dictionary, key: String = "") -> void:
	if value is Dictionary:
		for child: Variant in value:
			_collect_flags((value as Dictionary)[child], flags, str(child))
	elif value is Array:
		for child: Variant in value:
			_collect_flags(child, flags, key)
	elif value is String and key.contains("flag") and not str(value).is_empty():
		flags[str(value)] = true


func pot_files() -> Array[String]:
	return POT_FILES


func player_facing_keys() -> Array[String]:
	return PLAYER_FACING_KEYS


## In-process versions of `scripts/check_generated_data.sh`'s stages. Report mode: GLOOT-GEN
## against the committed Pandora, CANON-SEED (seed in memory, compare, never save),
## LOCATIONS-GEN and ISO-SPRITE-GEN drift checks. Write mode: seed and save Pandora, then
## regenerate the GLoot/catalog artifacts and the location artifacts; the isometric renderer
## needs a GPU and stays a drift check.
func regen(write: bool) -> Dictionary:
	var stages: Array[Dictionary] = []
	var regenerated: Array[String] = []
	if not Pandora.is_loaded():
		Pandora.load_data()
	var gloot: GDScript = load(GENERATE_GLOOT_SCRIPT) as GDScript
	if not write:
		var checked: Dictionary = gloot.call("generate", true)
		stages.append({"name": "GLOOT-GEN", "ok": not bool(checked.get("drift", true)),
			"message": "no drift." if not bool(checked.get("drift", true)) else "DRIFT — committed artifacts differ from Pandora."})
	var before: String = JSON.stringify(Pandora._entity_backend.save_data()) + JSON.stringify(Pandora._id_generator.save_data())
	var seeder: Node = (load(SEED_PANDORA_SCRIPT) as GDScript).new()
	var seeded: bool = bool(seeder.call("_seed_from_canon"))
	seeder.free()
	var after: String = JSON.stringify(Pandora._entity_backend.save_data()) + JSON.stringify(Pandora._id_generator.save_data())
	if not seeded:
		stages.append({"name": "CANON-SEED", "ok": false, "message": "canon failed its seed preflight; see the errors above."})
	elif write:
		if after != before:
			Pandora.save_data()
			regenerated.append("res://data.pandora")
		stages.append({"name": "CANON-SEED", "ok": true, "message": "seeded%s." % (" and saved data.pandora" if after != before else "; data.pandora unchanged")})
		var generated: Dictionary = gloot.call("generate", false)
		regenerated.append("res://data/generated/")
		stages.append({"name": "DATA-GEN", "ok": true, "message": "wrote %d item prototypes, %d encounters, %d Dom NPCs." % [
			int(generated.get("count", 0)), int(generated.get("encounter_count", 0)), int(generated.get("npc_count", 0))]})
	else:
		stages.append({"name": "CANON-SEED", "ok": after == before,
			"message": "no drift." if after == before else "drift — re-seed Pandora from canon before committing."})
	var locations: Dictionary = (load(GENERATE_LOCATIONS_SCRIPT) as GDScript).call("generate", not write)
	var location_errors: Array = locations.get("errors", [])
	if write:
		var written: Array = (locations.get("report", {}) as Dictionary).get("written", [])
		for path: Variant in written:
			regenerated.append(str(path))
		stages.append({"name": "LOCATIONS-GEN", "ok": location_errors.is_empty(), "message": "wrote %d artifact(s)." % written.size()})
	else:
		stages.append({"name": "LOCATIONS-GEN", "ok": location_errors.is_empty() and not bool(locations.get("drift", true)),
			"message": "no drift." if location_errors.is_empty() and not bool(locations.get("drift", true)) else "DRIFT or invalid canon."})
	var sprites: Dictionary = (load(ISOMETRIC_SPRITES_SCRIPT) as GDScript).call("check_drift")
	stages.append({"name": "ISO-SPRITE-GEN", "ok": not bool(sprites.get("drift", true)),
		"message": "no drift." if not bool(sprites.get("drift", true)) else "DRIFT: %s" % ", ".join(PackedStringArray(sprites.get("errors", [])))})
	return {"stages": stages, "errors": [], "regenerated": regenerated}


## Console verbs run against the live autoloads through the console's own interpreter
## (`weftlumin/panels/live_verbs.gd`), so its provenance rules apply unchanged.
func run_live_verb(entry: Dictionary) -> Dictionary:
	if str(entry.get("kind", "")) != LIVE_CONSOLE_KIND or str(entry.get("op", "")) != LIVE_CONSOLE_OP:
		return {"handled": false, "ok": false, "output": []}
	var script: GDScript = load(LIVE_VERBS_SCRIPT) as GDScript if ResourceLoader.exists(LIVE_VERBS_SCRIPT) else null
	if script == null:
		return {"handled": true, "ok": false, "output": ["Live verbs are not in this build."]}
	return script.new().call("run_console", entry)


func affected_test_globs(kind_ids: Array[String]) -> Array[String]:
	var globs: Array[String] = []
	for kind_id: String in kind_ids:
		for glob: Variant in AFFECTED_TESTS.get(kind_id, []):
			if str(glob) not in globs:
				globs.append(str(glob))
	return globs


static func _write_text(path: String, text: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temporary: String = path + ".weftlumin-tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return DirAccess.rename_absolute(temporary, path)


static func _cli_error(file: String, field: String, expected: String, code: String, message: String) -> Dictionary:
	return {"file": file, "field": field, "expected": expected, "code": code, "message": message}
