extends Node
## generate_locations.gd — the canon → artifacts generator for locations (E3.3a / #341,
## architecture §4.3.3).
##
## `canon/<hub>/locations/*.json` (`weftlumin.location.v1`) OWNS location data. This emits the
## committed artifacts, through `WeftluminLocationsKind.bake()`:
##   res://world/locations/**/*.tres          — one `LocationDefinition` per document with a
##       scene facet, at the document's `definition_path`
##   res://actors/building_door/transitions/*.tres — the enter/exit `BuildingTransitionDefinition`
##       pair for each interior document with a `transition` facet (#342 PR 3)
##   res://data/generated/location_index.json — every location (cities and scenes), by id
## Nothing here reads or writes `data.pandora`: the gazetteer facet reaches Pandora through
## `tools/seed_pandora.gd`, and this index is built from canon directly.
##
## Run ways (the autoload-tool convention of generate_gloot.gd; see
## scripts/check_generated_data.sh for the recipe):
##   - Regenerate: register as a temp autoload, run once.
##   - Drift check (CI/pre-commit): same, with env SOUL_METER_DRIFT_CHECK=1 — prints
##     "LOCATIONS-GEN: no drift." only when canon explains every artifact byte-for-byte and no
##     `.tres` under world/locations/ lacks a canon document.
##   - Promote drafts: with env SOUL_METER_LOCATION_DRAFTS=<dir> (the location panel's draft
##     directory, e.g. ~/.local/share/godot/app_userdata/<project>/weftlumin/location-drafts/
##     locations), each `<id>.json` there replaces the canon document of the same id — a draft
##     can only edit an existing location; creating one is the new-scene command's job (§4.6.5) —
##     then the artifacts regenerate. Ignored in drift-check mode.
## NOTE: judge the printed LOCATIONS-GEN line, never the raw exit code (Godot teardown aborts
## intermittently in this environment).

const DRIFT_ENV := "SOUL_METER_DRIFT_CHECK"
const DRAFTS_ENV := "SOUL_METER_LOCATION_DRAFTS"


func _ready() -> void:
	await get_tree().process_frame
	var check_only: bool = OS.get_environment(DRIFT_ENV) == "1"
	var drafts_dir: String = "" if check_only else OS.get_environment(DRAFTS_ENV)
	var result: Dictionary = generate(check_only, WeftluminLocationsKind.CANON_ROOT, "res://", drafts_dir)
	for error: Dictionary in result["errors"]:
		printerr("LOCATIONS-GEN: ERROR %s [%s] %s" % [error["file"], error["field"], error["message"]])
	if not (result["errors"] as Array).is_empty():
		printerr("LOCATIONS-GEN: refused — canon is invalid; nothing was written.")
		get_tree().quit(1)
		return
	if check_only:
		if result["drift"]:
			for entry: Dictionary in result["report"]["planned"]:
				if entry["action"] != "unchanged":
					printerr("LOCATIONS-GEN: %s %s" % [entry["action"], entry["path"]])
			for orphan: String in result["report"]["orphans"]:
				printerr("LOCATIONS-GEN: orphan %s has no canon document" % orphan)
			printerr("LOCATIONS-GEN: DRIFT — committed artifacts differ from canon. Regenerate and commit.")
			get_tree().quit(1)
			return
		print("LOCATIONS-GEN: no drift.")
	else:
		for promoted: String in result["promoted"]:
			print("LOCATIONS-GEN: promoted draft into %s" % promoted)
		for orphan: String in result["report"]["orphans"]:
			printerr("LOCATIONS-GEN: orphan %s has no canon document (left in place)" % orphan)
		print("LOCATIONS-GEN: wrote %d of %d artifacts for %d locations." % [
			(result["report"]["written"] as Array).size(),
			(result["report"]["planned"] as Array).size(),
			int(result["count"]),
		])
	get_tree().quit()


## Validates canon (plus any drafts), then bakes. Returns
## {errors, drift, count, report, promoted}; nothing is written when check_only or on errors.
static func generate(
	check_only: bool, canon_root: String = WeftluminLocationsKind.CANON_ROOT,
	target_root: String = "res://", drafts_dir: String = ""
) -> Dictionary:
	var kind := WeftluminLocationsKind.new()
	var errors: Array[Dictionary] = []
	var result: Dictionary = {"errors": errors, "drift": true, "count": 0, "report": {}, "promoted": []}
	var documents: Array[Dictionary] = WeftluminLocationsKind.load_canon(errors, canon_root)
	var promotions: Dictionary = {}
	if not drafts_dir.is_empty():
		promotions = _overlay_drafts(documents, drafts_dir, errors)
	if not errors.is_empty():
		return result
	var normalised: Array[Dictionary] = kind.validate(documents, errors)
	kind.route_documents = WeftluminRoutesKind.load_canon(errors, canon_root)
	kind.validate_routes(normalised, errors)
	if not errors.is_empty():
		return result
	if not check_only:
		for canon_path: String in promotions:
			var file := FileAccess.open(canon_path, FileAccess.WRITE)
			if file == null:
				errors.append(WeftluminLocationsKind._error(canon_path, "$", "writable canon document", "write_failed"))
				return result
			file.store_string(WeftluminLocationsKind.canon_text(promotions[canon_path]))
			file.close()
			(result["promoted"] as Array).append(canon_path)
	var report: Dictionary = kind.bake(normalised, target_root, not check_only, false)
	errors.append_array(report["errors"])
	result["report"] = report
	result["count"] = normalised.size()
	result["drift"] = not WeftluminLocationsKind.report_is_clean(report)
	return result


## Replaces canon documents in `documents` by id with the drafts in `drafts_dir`. Returns
## canon path → normalised draft for each promotion.
static func _overlay_drafts(
	documents: Array[Dictionary], drafts_dir: String, errors: Array[Dictionary]
) -> Dictionary:
	var promotions: Dictionary = {}
	if not DirAccess.dir_exists_absolute(drafts_dir):
		errors.append(WeftluminLocationsKind._error(drafts_dir, "$", "drafts directory", "missing_drafts_dir"))
		return promotions
	var filenames: PackedStringArray = DirAccess.get_files_at(drafts_dir)
	filenames.sort()
	var probe := WeftluminLocationsKind.new()
	for filename: String in filenames:
		if filename.get_extension().to_lower() != "json":
			continue
		var path: String = drafts_dir.path_join(filename)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			errors.append(WeftluminLocationsKind._error(path, "$", "one JSON object", "invalid_document"))
			continue
		var draft: Dictionary = parsed
		var target_index: int = -1
		for index: int in documents.size():
			if documents[index].get("id") == draft.get("id"):
				target_index = index
		if target_index < 0:
			errors.append(WeftluminLocationsKind._error(path, "id", "an existing canon location id", "unknown_location",
				"Draft '%s' names no canon location; new locations come from the new-scene command." % draft.get("id")))
			continue
		var canon_path: String = documents[target_index][WeftluminLocationsKind.META_FILE]
		draft[WeftluminLocationsKind.META_FILE] = path
		draft[WeftluminLocationsKind.META_HUB] = documents[target_index][WeftluminLocationsKind.META_HUB]
		var batch: Array[Dictionary] = [draft]
		var single: Array[Dictionary] = probe.validate(batch, errors)
		if single.is_empty():
			continue
		documents[target_index] = draft
		promotions[canon_path] = single[0]
	return promotions
